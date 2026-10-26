import 'package:drift/drift.dart';

import '../domain/classifier.dart';
import 'database.dart' hide ClassificationRule;

/// Rows and aggregates the classifier needs, plus category / rule / event
/// storage (spec 4.11).
extension ClassificationQueries on AppDatabase {
  // ---- facts -----------------------------------------------------------------

  /// Sender facts for a contact: reply history, address book, bulk-header
  /// counts over messages whose signals are known, list ids, override.
  Future<SenderFacts?> senderFacts(String contactKey) async {
    final c = await (select(contacts)..where((x) => x.key.equals(contactKey))).getSingleOrNull();
    final addr = await (select(contactAddresses)..where((a) => a.contactKey.equals(contactKey))..limit(1)).getSingleOrNull();
    final address = addr?.address ?? contactKey;
    final agg = await customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM messages m WHERE m.from_contact_key = ? AND m.bulk_signals IS NOT NULL) AS known,
        (SELECT COUNT(*) FROM messages m WHERE m.from_contact_key = ? AND m.bulk_signals IS NOT NULL AND m.bulk_signals <> '') AS bulk,
        (SELECT COUNT(*) FROM messages m JOIN message_participants p ON p.message_id = m.id
           WHERE m.is_from_me = 1 AND p.contact_key = ? AND p.role IN ('to','cc')) AS written,
        (SELECT GROUP_CONCAT(DISTINCT substr(m.bulk_signals, instr(m.bulk_signals, ';') + 1)) FROM messages m
           WHERE m.from_contact_key = ? AND instr(COALESCE(m.bulk_signals, ''), ';') > 0) AS list_ids,
        (SELECT from_name FROM messages m WHERE m.from_contact_key = ? AND from_name <> '' ORDER BY COALESCE(m.date, m.internal_date) DESC LIMIT 1) AS name
      ''',
      variables: [for (var i = 0; i < 5; i++) Variable.withString(contactKey)],
    ).getSingle();
    final override = c?.classificationSource == 'override' ? (c!.classification == 'feeds' ? Bucket.feeds : Bucket.people) : null;
    return SenderFacts(
      address: address,
      name: agg.readNullable<String>('name') ?? c?.displayName ?? '',
      userHasWrittenTo: agg.read<int>('written') > 0,
      inAddressBook: c?.inAddressBook ?? false,
      messagesWithBulkHeaders: agg.read<int>('bulk'),
      messagesWithKnownSignals: agg.read<int>('known'),
      listIds: {for (final s in (agg.readNullable<String>('list_ids') ?? '').split(',')) if (s.trim().isNotEmpty) s.trim().toLowerCase()},
      override: override,
    );
  }

  /// Message-IDs of mail the user sent, for the reply-to-me exception.
  Future<bool> isReplyToMine(String? inReplyTo) async {
    if (inReplyTo == null || inReplyTo.isEmpty) return false;
    final r = await (select(messages)..where((m) => m.isFromMe.equals(true) & m.messageId.equals(inReplyTo))..limit(1)).getSingleOrNull();
    return r != null;
  }

  Future<void> writeSenderDecision(String contactKey, SenderDecision d, {bool keepSource = false}) async {
    final existing = await (select(contacts)..where((c) => c.key.equals(contactKey))).getSingleOrNull();
    await (update(contacts)..where((c) => c.key.equals(contactKey))).write(ContactsCompanion(
      classification: Value(d.bucket.name),
      classificationSource: keepSource ? const Value.absent() : Value(d.source),
      feedsCategory: existing?.feedsCategory != null ? const Value.absent() : Value(d.bucket == Bucket.feeds ? d.category : null),
      classReasons: Value(d.reasons.join(' · ')),
    ));
  }

  Future<void> writeMessageClassification(int messageId, Bucket bucket, {String? category}) =>
      (update(messages)..where((m) => m.id.equals(messageId))).write(MessagesCompanion(classification: Value(bucket.name), feedsCategory: Value(category)));

  Future<List<Message>> messagesFromSender(String contactKey) => (select(messages)..where((m) => m.fromContactKey.equals(contactKey))).get();

  /// Contact keys of senders with at least one message whose signals are
  /// known but who were never classified (class_reasons empty), newest
  /// activity first.
  Future<List<String>> unclassifiedSenders({int limit = 200}) async {
    final rows = await customSelect(
      '''
      SELECT c.key AS key FROM contacts c
      WHERE c.is_me = 0 AND c.class_reasons = ''
        AND EXISTS (SELECT 1 FROM messages m WHERE m.from_contact_key = c.key AND m.bulk_signals IS NOT NULL)
      ORDER BY c.last_seen_at DESC LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
    ).get();
    return rows.map((r) => r.read<String>('key')).toList();
  }

  /// Messages in a folder whose list headers were never fetched.
  Future<List<int>> uidsMissingSignals(int folderId, {int pageSize = 500}) async {
    final rows = await (selectOnly(messages)
          ..addColumns([messages.uid])
          ..where(messages.folderId.equals(folderId) & messages.bulkSignals.isNull())
          ..orderBy([OrderingTerm.desc(messages.uid)])
          ..limit(pageSize))
        .get();
    return rows.map((r) => r.read(messages.uid)!).toList();
  }

  Future<Set<String>> storeSignals(int folderId, Map<int, BulkSignals> signals) async {
    final senders = <String>{};
    await transaction(() async {
      for (final e in signals.entries) {
        await (update(messages)..where((m) => m.folderId.equals(folderId) & m.uid.equals(e.key))).write(MessagesCompanion(bulkSignals: Value(e.value.encode())));
        final m = await (select(messages)..where((m) => m.folderId.equals(folderId) & m.uid.equals(e.key))).getSingleOrNull();
        if (m != null) senders.add(m.fromContactKey);
      }
    });
    return senders;
  }

  // ---- overrides and per-sender settings ---------------------------------------

  Future<void> setSenderOverride(String contactKey, Bucket? bucket) => (update(contacts)..where((c) => c.key.equals(contactKey))).write(ContactsCompanion(
        classification: bucket == null ? const Value.absent() : Value(bucket.name),
        classificationSource: Value(bucket == null ? 'auto' : 'override'),
        classReasons: Value(bucket == null ? '' : 'Moved by you'),
      ));

  Future<void> setCountsTowardUnread(String contactKey, bool on) => (update(contacts)..where((c) => c.key.equals(contactKey))).write(ContactsCompanion(countsTowardUnread: Value(on)));

  Future<void> setSenderCategory(String contactKey, String? category) => (update(contacts)..where((c) => c.key.equals(contactKey))).write(ContactsCompanion(feedsCategory: Value(category)));

  Future<void> setMessageCategory(int messageId, String? category) => (update(messages)..where((m) => m.id.equals(messageId))).write(MessagesCompanion(feedsCategory: Value(category)));

  Stream<List<Contact>> watchOverriddenSenders() => (select(contacts)..where((c) => c.classificationSource.equals('override'))..orderBy([(c) => OrderingTerm.desc(c.lastSeenAt)])).watch();

  Stream<List<Contact>> watchCountingSenders() => (select(contacts)..where((c) => c.countsTowardUnread.equals(true))..orderBy([(c) => OrderingTerm.desc(c.lastSeenAt)])).watch();

  // ---- categories --------------------------------------------------------------

  Stream<List<FeedsCategoryRow>> watchCategories() => (select(feedsCategoryRows)..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.id)])).watch();

  Future<List<String>> categoryNames() async => (await (select(feedsCategoryRows)..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.id)])).get()).map((c) => c.name).toList();

  Future<int> addCategory(String name) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Category name is empty');
    final count = (await select(feedsCategoryRows).get()).length;
    return into(feedsCategoryRows).insert(FeedsCategoryRowsCompanion.insert(name: n, sortOrder: Value(count)), mode: InsertMode.insertOrIgnore);
  }

  /// Renames everywhere it is referenced (senders, messages, rules).
  Future<void> renameCategory(int id, String newName) async {
    final n = newName.trim();
    final row = await (select(feedsCategoryRows)..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null || n.isEmpty || n == row.name) return;
    await transaction(() async {
      await (update(feedsCategoryRows)..where((c) => c.id.equals(id))).write(FeedsCategoryRowsCompanion(name: Value(n)));
      await (update(contacts)..where((c) => c.feedsCategory.equals(row.name))).write(ContactsCompanion(feedsCategory: Value(n)));
      await (update(messages)..where((m) => m.feedsCategory.equals(row.name))).write(MessagesCompanion(feedsCategory: Value(n)));
      await (update(classificationRules)..where((r) => r.category.equals(row.name))).write(ClassificationRulesCompanion(category: Value(n)));
    });
  }

  /// Deleting clears the category from senders, messages, and rules.
  Future<void> deleteCategory(int id) async {
    final row = await (select(feedsCategoryRows)..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await transaction(() async {
      await (delete(feedsCategoryRows)..where((c) => c.id.equals(id))).go();
      await (update(contacts)..where((c) => c.feedsCategory.equals(row.name))).write(const ContactsCompanion(feedsCategory: Value(null)));
      await (update(messages)..where((m) => m.feedsCategory.equals(row.name))).write(const MessagesCompanion(feedsCategory: Value(null)));
      await (update(classificationRules)..where((r) => r.category.equals(row.name))).write(const ClassificationRulesCompanion(category: Value(null)));
    });
  }

  // ---- rules ---------------------------------------------------------------------

  Future<List<ClassificationRule>> loadRules() async => [
        for (final r in await (select(classificationRules)..orderBy([(r) => OrderingTerm.asc(r.id)])).get())
          ClassificationRule(id: r.id, field: r.field, pattern: r.pattern, bucket: r.bucket == null ? null : Bucket.values.byName(r.bucket!), category: r.category),
      ];

  Stream<List<ClassificationRule>> watchRules() => (select(classificationRules)..orderBy([(r) => OrderingTerm.asc(r.id)])).watch().map((rows) => [
        for (final r in rows) ClassificationRule(id: r.id, field: r.field, pattern: r.pattern, bucket: r.bucket == null ? null : Bucket.values.byName(r.bucket!), category: r.category),
      ]);

  Future<int> insertRule(ClassificationRule r) => into(classificationRules).insert(ClassificationRulesCompanion.insert(
        field: r.field,
        pattern: r.pattern.trim().toLowerCase(),
        bucket: Value(r.bucket?.name),
        category: Value(r.category),
      ));

  Future<void> updateRule(ClassificationRule r) => (update(classificationRules)..where((x) => x.id.equals(r.id!))).write(ClassificationRulesCompanion(
        field: Value(r.field),
        pattern: Value(r.pattern.trim().toLowerCase()),
        bucket: Value(r.bucket?.name),
        category: Value(r.category),
      ));

  Future<void> deleteRule(int id) => (delete(classificationRules)..where((r) => r.id.equals(id))).go();

  // ---- events --------------------------------------------------------------------

  Future<void> logClassification({int? messageId, required String contactKey, required Bucket decision, String? category, List<String> reasons = const [], required String source}) =>
      into(classificationEvents).insert(ClassificationEventsCompanion.insert(
        messageId: Value(messageId),
        contactKey: contactKey,
        decision: decision.name,
        category: Value(category),
        reasons: Value(reasons.join(' · ')),
        source: source,
      ));

  /// Messages filed to Feeds since [since] (the "N filed" banner).
  Stream<int> watchFeedsFiledSince(DateTime since) => customSelect(
        "SELECT COUNT(*) AS n FROM messages WHERE classification = 'feeds' AND is_from_me = 0 AND is_deleted = 0 AND COALESCE(date, internal_date) >= ?",
        variables: [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
        readsFrom: {messages},
      ).watchSingle().map((r) => r.read<int>('n'));
}
