import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/classifier.dart';
import '../domain/piles.dart';
import 'database.dart' hide ClassificationRule;
import 'people_queries.dart';

/// Rows and aggregates the classifier needs, plus category / rule / event
/// storage (spec 4.11).
extension ClassificationQueries on AppDatabase {
  // ---- facts -----------------------------------------------------------------

  /// Sender facts for a contact: reply history, address book, bulk-header
  /// counts over messages whose signals are known, list ids, override.
  Future<SenderFacts?> senderFacts(String contactKey) async {
    final c = await (select(contacts)..where((x) => x.key.equals(contactKey))).getSingleOrNull();
    // Domain and local-part rules read one address: the one most of this
    // person's mail comes from, so a merged contact decides predictably.
    final mapped = (await (select(contactAddresses)..where((a) => a.contactKey.equals(contactKey))).get()).map((a) => a.address).toList();
    final top = await customSelect(
      'SELECT from_address AS a, COUNT(*) AS n FROM messages WHERE from_contact_key = ? AND is_from_me = 0 GROUP BY from_address ORDER BY n DESC, from_address LIMIT 1',
      variables: [Variable.withString(contactKey)],
    ).getSingleOrNull();
    final address = top?.read<String>('a') ?? (mapped.isEmpty ? contactKey : mapped.first);
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
    // Provider categories per distinct message (a message filed under two
    // Gmail labels is stored once per folder).
    final cats = await customSelect(
      '''
      SELECT cat, COUNT(*) AS n FROM (
        SELECT MAX(m.provider_category) AS cat FROM messages m
        WHERE m.from_contact_key = ? AND m.is_from_me = 0 AND m.provider_category IS NOT NULL AND m.provider_category <> ''
        GROUP BY COALESCE(m.message_id, CAST(m.id AS TEXT))
      ) GROUP BY cat
      ''',
      variables: [Variable.withString(contactKey)],
    ).get();
    final subjects = await customSelect(
      '''
      SELECT MAX(m.subject) AS subject FROM messages m
      WHERE m.from_contact_key = ? AND m.is_from_me = 0 AND m.is_deleted = 0
      GROUP BY COALESCE(m.message_id, CAST(m.id AS TEXT))
      ORDER BY MAX(COALESCE(m.date, m.internal_date)) DESC LIMIT 20
      ''',
      variables: [Variable.withString(contactKey)],
    ).get();
    return SenderFacts(
      address: address,
      otherAddresses: [for (final a in mapped) if (a != address) a],
      messagesWithTimely: await _timelyCount(contactKey),
      messagesReceived: (await customSelect('SELECT COUNT(*) AS n FROM messages WHERE from_contact_key = ? AND is_from_me = 0', variables: [Variable.withString(contactKey)]).getSingle()).read<int>('n'),
      messagesSentTo: (await customSelect(
        "SELECT COUNT(DISTINCT m.id) AS n FROM messages m JOIN message_participants p ON p.message_id = m.id WHERE m.is_from_me = 1 AND p.contact_key = ? AND p.role IN ('to','cc','bcc')",
        variables: [Variable.withString(contactKey)],
      ).getSingle()).read<int>('n'),
      repliesToAutomated: (await customSelect(
        '''
        SELECT COUNT(DISTINCT m.id) AS n FROM messages m JOIN message_participants p ON p.message_id = m.id
        WHERE m.is_from_me = 1 AND p.contact_key = ? AND p.role IN ('to','cc','bcc') AND m.in_reply_to IS NOT NULL
          AND EXISTS (SELECT 1 FROM messages o WHERE o.message_id = m.in_reply_to AND o.is_from_me = 0 AND o.classification = 'feeds')
        ''',
        variables: [Variable.withString(contactKey)],
      ).getSingle()).read<int>('n'),
      recipientNames: [
        for (final r in await customSelect(
          "SELECT DISTINCT p.name AS name FROM message_participants p JOIN messages m ON m.id = p.message_id WHERE m.is_from_me = 1 AND p.contact_key = ? AND p.name <> '' LIMIT 10",
          variables: [Variable.withString(contactKey)],
        ).get())
          r.read<String>('name'),
      ],
      name: agg.readNullable<String>('name') ?? c?.displayName ?? '',
      userHasWrittenTo: agg.read<int>('written') > 0,
      inAddressBook: c?.inAddressBook ?? false,
      messagesWithBulkHeaders: agg.read<int>('bulk'),
      messagesWithKnownSignals: agg.read<int>('known'),
      listIds: {for (final s in (agg.readNullable<String>('list_ids') ?? '').split(',')) if (s.trim().isNotEmpty) s.trim().toLowerCase()},
      override: override,
      providerCategories: {for (final r in cats) r.read<String>('cat'): r.read<int>('n')},
      subjects: [for (final r in subjects) r.readNullable<String>('subject') ?? ''],
    );
  }

  Future<int> _timelyCount(String contactKey) async {
    final r = await customSelect(
      'SELECT COUNT(*) AS n FROM messages WHERE from_contact_key = ? AND is_from_me = 0 AND has_timely_item = 1',
      variables: [Variable.withString(contactKey)],
    ).getSingle();
    return r.read<int>('n');
  }

  // ---- provider categories (Gmail) ---------------------------------------------

  /// Lowest and highest UID in [folderId] whose provider category was never
  /// read; null when there are none.
  Future<(int, int)?> uidRangeMissingProviderCategory(int folderId) async {
    final r = await customSelect(
      'SELECT MIN(uid) AS lo, MAX(uid) AS hi FROM messages WHERE folder_id = ? AND provider_category IS NULL',
      variables: [Variable.withInt(folderId)],
      readsFrom: {messages},
    ).getSingle();
    final lo = r.readNullable<int>('lo');
    final hi = r.readNullable<int>('hi');
    return lo == null || hi == null ? null : (lo, hi);
  }

  /// UIDs in [folderId] of mail from the last while ([since]) that the
  /// provider had not filed under any category when it was read, and that
  /// sits in Chats. Gmail can file a message a little after it arrives, so
  /// these are asked about again.
  Future<(int, int)?> uidRangeUnfiledSince(int folderId, DateTime since) async {
    final r = await customSelect(
      "SELECT MIN(uid) AS lo, MAX(uid) AS hi FROM messages WHERE folder_id = ? AND provider_category = '' "
      "AND is_from_me = 0 AND is_deleted = 0 AND classification <> 'feeds' AND COALESCE(date, internal_date) >= ?",
      variables: [Variable.withInt(folderId), Variable.withDateTime(since)],
      readsFrom: {messages},
    ).getSingle();
    final lo = r.readNullable<int>('lo');
    final hi = r.readNullable<int>('hi');
    return lo == null || hi == null ? null : (lo, hi);
  }

  /// Stores the provider category for messages in [folderId]: [byCategory]
  /// maps a category to the UIDs the provider returned for it; every other
  /// message in `lo..hi` that is still unread gets `''` (searched, none).
  /// Returns the senders whose messages changed.
  /// With [redecide] the range's senders are marked undecided as well, in
  /// the same transaction (manual moves excepted).
  Future<Set<String>> storeProviderCategories(int folderId, (int, int) range, Map<String, Set<int>> byCategory, {bool redecide = false}) async {
    final (lo, hi) = range;
    final senders = <String>{};
    await transaction(() async {
      for (final e in byCategory.entries) {
        final uids = e.value.where((u) => u >= lo && u <= hi).toList();
        for (var i = 0; i < uids.length; i += 500) {
          final chunk = uids.sublist(i, i + 500 > uids.length ? uids.length : i + 500);
          await (update(messages)..where((m) => m.folderId.equals(folderId) & m.uid.isIn(chunk))).write(MessagesCompanion(providerCategory: Value(e.key)));
        }
      }
      await customUpdate(
        "UPDATE messages SET provider_category = '' WHERE folder_id = ? AND uid BETWEEN ? AND ? AND provider_category IS NULL",
        variables: [Variable.withInt(folderId), Variable.withInt(lo), Variable.withInt(hi)],
        updates: {messages},
      );
      final rows = await customSelect(
        'SELECT DISTINCT from_contact_key AS k FROM messages WHERE folder_id = ? AND uid BETWEEN ? AND ? AND is_from_me = 0',
        variables: [Variable.withInt(folderId), Variable.withInt(lo), Variable.withInt(hi)],
      ).get();
      senders.addAll(rows.map((r) => r.read<String>('k')));
      if (redecide) {
        await customUpdate(
          "UPDATE contacts SET class_reasons = '' WHERE classification_source <> 'override' "
          'AND key IN (SELECT from_contact_key FROM messages WHERE folder_id = ? AND uid BETWEEN ? AND ? AND is_from_me = 0)',
          variables: [Variable.withInt(folderId), Variable.withInt(lo), Variable.withInt(hi)],
          updates: {contacts},
        );
      }
    });
    return senders;
  }

  /// Adds Delivery, Travel and OTP (classifier 6) after Receipt, for
  /// installs made before they existed. Names the user already has are left.
  Future<void> addTravelDeliveryOtpCategories() => transaction(() async {
        final receipt = (await (select(feedsCategoryRows)..where((c) => c.name.equals('Receipt'))).getSingleOrNull())?.sortOrder;
        final at = receipt == null ? (await select(feedsCategoryRows).get()).length : receipt + 1;
        const added = ['Delivery', 'Travel', 'OTP'];
        final missing = [for (final n in added) if ((await (select(feedsCategoryRows)..where((c) => c.name.equals(n))).getSingleOrNull()) == null) n];
        if (missing.isEmpty) return;
        await customUpdate('UPDATE feeds_categories SET sort_order = sort_order + ? WHERE sort_order >= ?', variables: [Variable.withInt(missing.length), Variable.withInt(at)], updates: {feedsCategoryRows});
        for (final (i, n) in missing.indexed) {
          await into(feedsCategoryRows).insert(FeedsCategoryRowsCompanion.insert(name: n, builtin: const Value(true), sortOrder: Value(at + i)), mode: InsertMode.insertOrIgnore);
        }
      });

  /// Forgets every automatic sender decision so the classifier redoes them
  /// (after a classifier upgrade). Manual moves are kept.
  ///
  /// [feedsOnly] redoes only Feeds senders: for an upgrade that changed how
  /// Feeds categories are chosen and nothing about who is in Feeds.
  Future<void> resetAutoClassifications({bool feedsOnly = false}) => customUpdate(
        "UPDATE contacts SET class_reasons = '' WHERE classification_source <> 'override'${feedsOnly ? " AND classification = 'feeds'" : ''}",
        updates: {contacts},
      );

  /// Forgets categories the rules chose, so they are chosen again. Categories
  /// the user set (logged as corrections) stay. Message categories are read
  /// from history, as the rows themselves do not say who set them.
  Future<void> resetAutoCategories() async {
    await customUpdate(
      "UPDATE contacts SET feeds_category = NULL WHERE classification_source <> 'override' "
      "AND key NOT IN (SELECT contact_key FROM classification_events WHERE source = 'correction' AND message_id IS NULL AND contact_key IS NOT NULL)",
      updates: {contacts},
    );
    await customUpdate(
      'UPDATE messages SET feeds_category = NULL WHERE feeds_category IS NOT NULL '
      "AND id NOT IN (SELECT message_id FROM classification_events WHERE source = 'correction' AND message_id IS NOT NULL)",
      updates: {messages},
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
      WHERE c.is_me = 0 AND c.class_reasons = '' AND c.key <> 'me'
        AND (EXISTS (SELECT 1 FROM messages m WHERE m.from_contact_key = c.key AND m.bulk_signals IS NOT NULL)
          -- Addresses the user only wrote to are decided too: a chat only
          -- for a real person.
          OR (NOT EXISTS (SELECT 1 FROM messages m WHERE m.from_contact_key = c.key AND m.is_from_me = 0)
              AND EXISTS (SELECT 1 FROM message_participants p JOIN messages m ON m.id = p.message_id
                          WHERE p.contact_key = c.key AND m.is_from_me = 1 AND p.role IN ('to','cc','bcc'))))
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

  Future<void> setSenderOverride(String contactKey, Bucket? bucket) async {
    await (update(contacts)..where((c) => c.key.equals(contactKey))).write(ContactsCompanion(
      classification: bucket == null ? const Value.absent() : Value(bucket.name),
      classificationSource: Value(bucket == null ? 'auto' : 'override'),
      classReasons: Value(bucket == null ? '' : 'Moved by you'),
    ));
    if (bucket == null) {
      // The move is taken back. The helper is told in so many words (a
      // sender merely sent up without its move never undoes one), and what
      // this device holds from the helper stops saying "moved by hand".
      await customStatement("UPDATE helper_senders SET src = 'auto' WHERE key = ? AND src = 'override'", [contactKey]);
      await customStatement(
        "INSERT OR REPLACE INTO helper_outbox (kind, k, data) SELECT 'op', ?, ? FROM helper_state WHERE id = 1 AND connected = 1 AND applying = 0",
        ['unmove:$contactKey', jsonEncode({'op': 'unmove', 'k': contactKey})],
      );
    } else {
      // Moved again before the taking-back was sent: it is not sent after all.
      await customStatement("DELETE FROM helper_outbox WHERE kind = 'op' AND k = ?", ['unmove:$contactKey']);
    }
  }

  Future<void> setCountsTowardUnread(String contactKey, bool on) => (update(contacts)..where((c) => c.key.equals(contactKey))).write(ContactsCompanion(countsTowardUnread: Value(on)));

  Future<void> setSenderCategory(String contactKey, String? category) => (update(contacts)..where((c) => c.key.equals(contactKey))).write(ContactsCompanion(feedsCategory: Value(category)));

  Future<void> setMessageCategory(int messageId, String? category) => (update(messages)..where((m) => m.id.equals(messageId))).write(MessagesCompanion(feedsCategory: Value(category)));

  /// Senders the user placed by hand: moved between Chats and the rest, or
  /// given a pile (Feed or Noise).
  Stream<List<Contact>> watchMovedSenders() => (select(contacts)..where((c) => c.classificationSource.equals('override') | c.feedsPile.isNotNull())..orderBy([(c) => OrderingTerm.desc(c.lastSeenAt)])).watch();

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
      await _noteTagAction('rename-tag:${row.name}', {'op': 'rename-tag', 'from': row.name, 'to': n});
      await (update(feedsCategoryRows)..where((c) => c.id.equals(id))).write(FeedsCategoryRowsCompanion(name: Value(n)));
      await (update(contacts)..where((c) => c.feedsCategory.equals(row.name))).write(ContactsCompanion(feedsCategory: Value(n)));
      await (update(messages)..where((m) => m.feedsCategory.equals(row.name))).write(MessagesCompanion(feedsCategory: Value(n)));
      await (update(classificationRules)..where((r) => r.category.equals(row.name))).write(ClassificationRulesCompanion(category: Value(n)));
    });
  }

  /// Renaming or removing a tag is told to the helper as one action, so it
  /// does the same everywhere at once. Noted only while this device follows
  /// a helper.
  Future<void> _noteTagAction(String key, Map<String, Object?> action) => customStatement(
        "INSERT OR IGNORE INTO helper_outbox (kind, k, data) SELECT 'op', ?, ? FROM helper_state WHERE id = 1 AND connected = 1 AND applying = 0",
        [key, jsonEncode(action)],
      );

  /// Deleting clears the category from senders, messages, and rules.
  Future<void> deleteCategory(int id) async {
    final row = await (select(feedsCategoryRows)..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await transaction(() async {
      await _noteTagAction('delete-tag:${row.name}', {'op': 'delete-tag', 'name': row.name});
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

  /// The newest incoming Feeds message, by arrival (ids only grow), across
  /// accounts: the rail shows a dot when it is newer than the one seen.
  Stream<int> watchNewestFeedsId() => customSelect(
        "SELECT COALESCE(MAX(id), 0) AS n FROM messages WHERE classification = 'feeds' AND is_from_me = 0 AND is_deleted = 0 "
        "AND folder_id NOT IN (SELECT id FROM folders WHERE role IN ('junk','trash'))",
        readsFrom: {messages, folders},
      ).watchSingle().map((r) => r.read<int>('n'));

  /// The user's own choice of pile for a sender that is not a person.
  /// Null hands the choice back to the app.
  Future<void> setSenderPile(String contactKey, FeedsPile? pile) => (update(contacts)..where((c) => c.key.equals(contactKey))).write(ContactsCompanion(feedsPile: Value(pile?.name)));

  /// Senders whose pile the user chose.
  Stream<List<Contact>> watchPileChosenSenders() => (select(contacts)..where((c) => c.feedsPile.isNotNull() & c.classification.equals('feeds'))..orderBy([(c) => OrderingTerm.desc(c.lastSeenAt)])).watch();

  /// Feed or Noise for a row that [rowBelongsToFeeds]; null otherwise.
  Future<FeedsPile?> rowPile(String rowKey) async {
    if (!await rowBelongsToFeeds(rowKey)) return null;
    final r = await customSelect(
      'SELECT c.feeds_pile AS pile, c.feeds_category AS cat, COALESCE(s.feeds_total, 0) AS total, COALESCE(s.feeds_unread, 0) AS unread FROM contacts c LEFT JOIN row_summaries s ON s.row_key = ? WHERE c.key = ?',
      variables: [Variable.withString(rowKey), Variable.withString(rowKey.substring(2))],
    ).getSingleOrNull();
    if (r == null) return null;
    return pileFor(chosen: r.readNullable<String>('pile'), category: r.readNullable<String>('cat'), total: r.read<int>('total'), unread: r.read<int>('unread'), mail: (await rowMailByCategory(rowKey: rowKey))[rowKey]);
  }

  /// Whether a row is listed on Feeds and not on Chats: a Feeds sender with
  /// no incoming mail filed under People (the same rule as the two lists).
  Future<bool> rowBelongsToFeeds(String rowKey) async {
    if (!rowKey.startsWith('c:')) return false;
    final r = await customSelect(
      'SELECT c.classification AS cls, s.last_people AS last_people FROM contacts c LEFT JOIN row_summaries s ON s.row_key = ? WHERE c.key = ?',
      variables: [Variable.withString(rowKey), Variable.withString(rowKey.substring(2))],
    ).getSingleOrNull();
    return r != null && r.read<String>('cls') == 'feeds' && r.readNullable<int>('last_people') == null;
  }

  /// Messages filed to Feeds since [since] (the "N filed" banner).
  Stream<int> watchFeedsFiledSince(DateTime since) => customSelect(
        "SELECT COUNT(*) AS n FROM messages WHERE classification = 'feeds' AND is_from_me = 0 AND is_deleted = 0 AND COALESCE(date, internal_date) >= ?",
        variables: [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
        readsFrom: {messages},
      ).watchSingle().map((r) => r.read<int>('n'));
}
