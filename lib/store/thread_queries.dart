import 'package:drift/drift.dart';

import '../domain/threading.dart';
import 'database.dart';

/// Thread assignment and thread reads (spec 4.20).
extension ThreadQueries on AppDatabase {
  /// Assigns thread keys to [messageIds] using the hybrid model, considering
  /// every already-threaded message that shares a Message-ID reference,
  /// provider thread id, or normalized subject with them. Updates existing
  /// messages whose threads merged as a result.
  Future<void> assignThreads(List<int> messageIds) async {
    if (messageIds.isEmpty) return;
    final incomingRows = await (select(messages)..where((m) => m.id.isIn(messageIds))).get();
    if (incomingRows.isEmpty) return;

    // Candidate existing messages: anything referenced by, referencing, or
    // sharing subject/provider-thread with the incoming set.
    final ids = <String>{};
    final subjects = <String>{};
    final providerIds = <String>{};
    for (final m in incomingRows) {
      if (m.messageId != null) ids.add(m.messageId!);
      if (m.inReplyTo != null) ids.add(m.inReplyTo!);
      if (m.referencesHeader != null) ids.addAll(m.referencesHeader!.split(' ').where((s) => s.isNotEmpty));
      final norm = normalizeSubject(m.subject).normalized;
      if (norm.isNotEmpty) subjects.add(norm);
      if (m.providerThreadId != null) providerIds.add(m.providerThreadId!);
    }
    final incomingIds = incomingRows.map((m) => m.id).toSet();

    final candidates = <Message>[];
    if (ids.isNotEmpty) {
      candidates.addAll(await (select(messages)..where((m) => m.messageId.isIn(ids) | m.inReplyTo.isIn(ids))).get());
      // Messages whose References mention any of our ids.
      for (final chunk in _chunks(ids.toList(), 50)) {
        final likes = chunk.map((id) => messages.referencesHeader.like('%$id%')).reduce((a, b) => a | b);
        candidates.addAll(await (select(messages)..where((m) => likes)).get());
      }
    }
    if (providerIds.isNotEmpty) candidates.addAll(await (select(messages)..where((m) => m.providerThreadId.isIn(providerIds))).get());
    if (subjects.isNotEmpty) {
      // Subject candidates: same normalized subject. Normalization happens in
      // Dart, so fetch by a LIKE on the core subject text and filter.
      for (final subj in subjects.take(20)) {
        if (subj.length < 3) continue;
        final rows = await (select(messages)
              ..where((m) => m.subject.lower().like('%${subj.replaceAll('%', '')}%'))
              ..limit(500))
            .get();
        candidates.addAll(rows.where((r) => normalizeSubject(r.subject).normalized == subj));
      }
    }
    final existing = <int, Message>{for (final c in candidates) if (!incomingIds.contains(c.id)) c.id: c};

    final participants = await _participantsFor([...incomingIds, ...existing.keys]);
    ThreadInput toInput(Message m) => ThreadInput(
          id: m.id,
          accountId: m.accountId,
          ts: m.date ?? m.internalDate,
          participantKeys: participants[m.id] ?? {m.fromContactKey},
          messageId: m.messageId,
          inReplyTo: m.inReplyTo,
          references: m.referencesHeader?.split(' ').where((s) => s.isNotEmpty).toList() ?? const [],
          subject: m.subject,
          providerThreadId: m.providerThreadId,
        );

    // Existing threaded messages keep their keys unless a merge happens.
    final existingKeyed = existing.values.where((m) => m.threadKey != null).toList();
    final existingKeys = {for (final m in existingKeyed) m.id: m.threadKey!};
    // Existing but never-threaded messages (pre-migration) are threaded now too.
    final unthreaded = existing.values.where((m) => m.threadKey == null).toList();

    final result = ThreadBuilder().assignIncremental(
      existingKeyed.map(toInput),
      existingKeys,
      [...incomingRows, ...unthreaded].map(toInput),
    );

    // A merge may rename an existing thread: propagate to every message of
    // the old thread, not just the candidates we loaded.
    await transaction(() async {
      final renames = <String, String>{};
      for (final e in result.entries) {
        final old = existingKeys[e.key];
        if (old != null && old != e.value) renames[old] = e.value;
      }
      for (final r in renames.entries) {
        await (update(messages)..where((m) => m.threadKey.equals(r.key))).write(MessagesCompanion(threadKey: Value(r.value)));
      }
      for (final e in result.entries) {
        await (update(messages)..where((m) => m.id.equals(e.key))).write(MessagesCompanion(threadKey: Value(e.value)));
      }
    });
  }

  /// Threads every message that has no thread key yet (post-migration).
  Future<int> rebuildMissingThreads({int batch = 2000}) async {
    var total = 0;
    while (true) {
      final ids = await (selectOnly(messages)
            ..addColumns([messages.id])
            ..where(messages.threadKey.isNull())
            ..limit(batch))
          .map((r) => r.read(messages.id)!)
          .get();
      if (ids.isEmpty) return total;
      await assignThreads(ids);
      total += ids.length;
    }
  }

  Future<Map<int, Set<String>>> _participantsFor(Iterable<int> messageIds) async {
    final out = <int, Set<String>>{};
    for (final chunk in _chunks(messageIds.toList(), 500)) {
      final rows = await (select(messageParticipants)..where((p) => p.messageId.isIn(chunk))).get();
      for (final p in rows) {
        out.putIfAbsent(p.messageId, () => {}).add(p.contactKey);
      }
    }
    return out;
  }

  /// All messages in a thread across every row and account, oldest first.
  Stream<List<Message>> watchThread(String threadKey) => (select(messages)
        ..where((m) => m.threadKey.equals(threadKey) & m.isDeleted.equals(false))
        ..orderBy([(m) => OrderingTerm.asc(m.date), (m) => OrderingTerm.asc(m.id)]))
      .watch();

  Future<List<Message>> threadMessages(String threadKey) => (select(messages)
        ..where((m) => m.threadKey.equals(threadKey) & m.isDeleted.equals(false))
        ..orderBy([(m) => OrderingTerm.asc(m.date), (m) => OrderingTerm.asc(m.id)]))
      .get();

  /// Message count per thread key, for "View thread (N)".
  Future<Map<String, int>> threadCounts(Iterable<String> threadKeys) async {
    final keys = threadKeys.toSet().toList();
    if (keys.isEmpty) return const {};
    final out = <String, int>{};
    for (final chunk in _chunks(keys, 500)) {
      final rows = await customSelect(
        'SELECT thread_key, COUNT(*) AS n FROM messages WHERE is_deleted = 0 AND thread_key IN (${List.filled(chunk.length, '?').join(',')}) GROUP BY thread_key',
        variables: [for (final k in chunk) Variable.withString(k)],
      ).get();
      for (final r in rows) {
        out[r.data['thread_key'] as String] = r.data['n'] as int;
      }
    }
    return out;
  }

  static Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }
}
