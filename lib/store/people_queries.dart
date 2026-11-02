import 'package:drift/drift.dart';

import '../domain/filing.dart';
import 'database.dart';

/// Which subset of People rows to show (spec 4.7). Exactly one active.
enum PeopleFilter { all, unread, starred, thisWeek, sent, hasAttachments, fromContacts, snoozed }

/// Order of the list (spec 4.2). Pinned rows stay on top in every order.
enum PeopleSort { newest, oldest, nameAZ, nameZA }

/// Which tab of the middle pane a row query serves (spec 4.11).
enum InboxTab { people, feeds }

/// One row of the People list (spec 4.2): a contact or a user-defined
/// group, with the newest message's preview and the unread count.
class PeopleRow {
  const PeopleRow({
    required this.ref,
    required this.title,
    required this.identityKey,
    required this.lastActivity,
    required this.previewSubject,
    required this.previewSnippet,
    required this.previewFromMe,
    required this.unread,
    required this.total,
    required this.pinned,
    required this.hasStarred,
    required this.hasAttachments,
    this.members = const [],
    this.classification = 'people',
    this.category,
    this.countsTowardUnread = false,
    this.peopleUnread = 0,
    this.feedsUnread = 0,
    this.snoozedUntil,
    this.muted = false,
    this.accountIds = const {},
    this.subtitle,
    this.onFeedsTab = false,
    this.photoPath,
  });

  final RowRef ref;
  final String title;

  /// The user's note under the sender's name; null when there is none.
  final String? subtitle;

  /// The sender's photo from their Google contact card, as a local file.
  final String? photoPath;

  /// This row was listed for the Feeds tab, so it shows its category.
  final bool onFeedsTab;

  /// Key used for the avatar color: the contact key, or `g:<id>` for groups.
  final String identityKey;

  /// Ordering timestamp: the contact's newest sent message (decision 4);
  /// for groups the newest message in the row.
  final DateTime? lastActivity;
  final String previewSubject;
  final String previewSnippet;
  final bool previewFromMe;
  final int unread;
  final int total;
  final bool pinned;
  final bool hasStarred;
  final bool hasAttachments;

  /// For group rows: (identityKey, name) of the first members.
  final List<(String, String)> members;

  bool get isGroup => ref is GroupRow;

  /// Sender bucket (`people` | `feeds`); groups are always People.
  final String classification;
  bool get isFeeds => classification == 'feeds';

  /// Sender-default Feeds category, when in Feeds.
  final String? category;

  /// Spec 4.11: a Feeds sender whose unread mail counts toward the badge.
  final bool countsTowardUnread;
  final int peopleUnread;
  final int feedsUnread;

  /// Spec 4.9: hidden from the list until this time.
  final DateTime? snoozedUntil;

  /// Spec 4.17: no notifications for this row.
  final bool muted;

  /// Accounts whose mail is in this row (spec 4.14 account indicator).
  final Set<int> accountIds;
  bool get isSnoozed => snoozedUntil != null && snoozedUntil!.isAfter(DateTime.now());
  String get rowKey => ref.key;
  String get preview => previewSnippet.isNotEmpty ? previewSnippet : previewSubject;
}

extension PeopleQueries on AppDatabase {
  /// Recomputes summaries for every row key marked dirty by the triggers.
  /// Cheap for incremental changes; a full rebuild after a first sync is a
  /// single grouped query.
  Future<void> refreshDirtyRows() async {
    await transaction(() async {
      final dirtyCount = await customSelect('SELECT COUNT(*) AS n FROM dirty_rows').getSingle();
      if ((dirtyCount.data['n'] as int) == 0) return;
      // customUpdate (not customStatement) so drift notifies streams that
      // read row_summaries.
      await customUpdate(_refreshSql, updates: {rowSummaries}, updateKind: UpdateKind.insert);
      await customUpdate(
        '''
        DELETE FROM row_summaries WHERE row_key IN (SELECT row_key FROM dirty_rows)
          AND row_key NOT IN (SELECT DISTINCT r.row_key FROM message_row_assignments r JOIN messages m ON m.id = r.message_id
                              WHERE m.is_deleted = 0 AND m.folder_id NOT IN (SELECT id FROM folders WHERE role IN ('junk','trash')))''',
        updates: {rowSummaries},
        updateKind: UpdateKind.delete,
      );
      await customUpdate('DELETE FROM dirty_rows', updates: {dirtyRows}, updateKind: UpdateKind.delete);
    });
  }

  /// Live People rows for [filter], pinned first, then by activity.
  /// Messages in junk/trash folders and locally deleted messages are
  /// excluded. `search` matches title, address, subject or snippet.
  ///
  /// [category] narrows the Feeds list to rows with mail in that category,
  /// whether it comes from the sender's default or from a single message.
  Stream<List<PeopleRow>> watchPeopleRows({PeopleFilter filter = PeopleFilter.all, String search = '', InboxTab tab = InboxTab.people, int? accountId, String? category, PeopleSort sort = PeopleSort.newest}) {
    final q = customSelect(
      accountId == null ? _listSql : _scopedListSql,
      variables: accountId == null ? const [] : [Variable.withInt(accountId)],
      readsFrom: {rowSummaries, rowPrefs, contacts, peopleGroups, groupMembers, messages, messageRowAssignments},
    );
    return q.watch().asyncMap((rows) async {
      // Summaries may be stale right after a migration or a direct write;
      // refreshing here is a no-op when nothing is dirty.
      await refreshDirtyRows();
      return _materialize(rows, filter: filter, search: search.trim().toLowerCase(), tab: tab, category: category, sort: sort);
    });
  }

  Future<List<PeopleRow>> peopleRows({PeopleFilter filter = PeopleFilter.all, String search = '', InboxTab tab = InboxTab.people, int? accountId, String? category, PeopleSort sort = PeopleSort.newest}) async {
    await refreshDirtyRows();
    final rows = await customSelect(accountId == null ? _listSql : _scopedListSql, variables: accountId == null ? const [] : [Variable.withInt(accountId)]).get();
    return _materialize(rows, filter: filter, search: search.trim().toLowerCase(), tab: tab, category: category, sort: sort);
  }

  /// Row keys holding Feeds mail in [category].
  Future<Set<String>> _rowsInCategory(String category) async {
    final rows = await customSelect(
      '''
      SELECT DISTINCT r.row_key AS k FROM message_row_assignments r
      JOIN messages m ON m.id = r.message_id
      LEFT JOIN contacts c ON c.key = m.from_contact_key
      WHERE m.classification = 'feeds' AND m.is_deleted = 0 AND COALESCE(m.feeds_category, c.feeds_category) = ?
      ''',
      variables: [Variable.withString(category)],
    ).get();
    return {for (final r in rows) r.read<String>('k')};
  }

  /// Categories that hold Feeds mail, in their configured order. These are
  /// the filter pills on the Feeds screen.
  Stream<List<String>> watchCategoriesInUse({int? accountId}) => customSelect(
        '''
        SELECT f.name AS name FROM feeds_categories f
        WHERE EXISTS (
          SELECT 1 FROM messages m LEFT JOIN contacts c ON c.key = m.from_contact_key
          WHERE m.classification = 'feeds' AND m.is_deleted = 0 ${accountId == null ? '' : 'AND m.account_id = ?'}
            AND COALESCE(m.feeds_category, c.feeds_category) = f.name
        )
        ORDER BY f.sort_order, f.name
        ''',
        variables: [if (accountId != null) Variable.withInt(accountId)],
        readsFrom: {feedsCategoryRows, messages, contacts},
      ).watch().map((rows) => [for (final r in rows) r.read<String>('name')]);

  /// Marks rows stale so the next refresh recomputes them.
  /// The user's own name for a sender (spec 4.2). It replaces the name from
  /// the mail headers everywhere the contact is shown and stays for all
  /// future mail from any of the sender's addresses, even after every
  /// message is deleted. Null or blank goes back to the header name.
  Future<void> setContactLabel(String contactKey, String? label) async {
    final v = label?.trim();
    await (update(contacts)..where((c) => c.key.equals(contactKey))).write(ContactsCompanion(userLabel: Value(v == null || v.isEmpty ? null : v)));
  }

  /// The user's optional note under a sender's name (spec 4.2). Null or
  /// blank removes it. Kept like the name: contacts outlive their messages.
  Future<void> setContactSubtitle(String contactKey, String? subtitle) async {
    final v = subtitle?.trim();
    await (update(contacts)..where((c) => c.key.equals(contactKey))).write(ContactsCompanion(userSubtitle: Value(v == null || v.isEmpty ? null : v)));
  }

  Future<void> markRowsDirty(Iterable<String> rowKeys) async {
    for (final k in rowKeys) {
      await customStatement('INSERT OR IGNORE INTO dirty_rows(row_key) VALUES (?)', [k]);
    }
  }

  /// Messages belonging to a row, newest first. Used by the interim
  /// message list (M2) and the conversation view (M3).
  Stream<List<Message>> watchMessagesForRow(String rowKey, {int? accountId}) {
    final q = customSelect(
      accountId == null ? _rowMessagesSql : _rowMessagesSql.replaceFirst('WHERE r.row_key = ?', 'WHERE r.row_key = ? AND m.account_id = ?'),
      variables: [Variable.withString(rowKey), if (accountId != null) Variable.withInt(accountId)],
      readsFrom: {messages, messageRowAssignments, folders},
    );
    return q.watch().map((rows) => rows.map((r) => messages.map(r.data)).toList());
  }

  Future<List<Message>> messagesForRow(String rowKey) async {
    final rows = await customSelect(_rowMessagesSql, variables: [Variable.withString(rowKey)]).get();
    return rows.map((r) => messages.map(r.data)).toList();
  }

  Future<void> setPinned(String rowKey, bool pinned) => into(rowPrefs).insertOnConflictUpdate(
        RowPrefsCompanion(rowKey: Value(rowKey), pinned: Value(pinned), updatedAt: Value(DateTime.now())),
      );

  Future<RowPref?> rowPref(String rowKey) => (select(rowPrefs)..where((p) => p.rowKey.equals(rowKey))).getSingleOrNull();

  static const _rowMessagesSql = '''
    SELECT m.* FROM messages m
    JOIN message_row_assignments r ON r.message_id = m.id
    JOIN folders f ON f.id = m.folder_id
    WHERE r.row_key = ? AND m.is_deleted = 0 AND f.role NOT IN ('junk','trash')
    ORDER BY COALESCE(m.date, m.internal_date) DESC, m.id DESC
  ''';

  /// Recomputes summaries for the dirty keys only. The newest message is
  /// found by an ordered correlated subquery: with several aggregates in
  /// the outer query SQLite's bare-column rule does not apply.
  static const _refreshSql = '''
    INSERT OR REPLACE INTO row_summaries
      (row_key, total, unread, last_received, last_any, has_starred, has_attachments, has_sent, newest_message_id, updated_at,
       people_total, people_unread, feeds_total, feeds_unread, last_people, last_feeds, newest_people_id, newest_feeds_id)
    SELECT v.row_key,
           COUNT(*),
           SUM(CASE WHEN v.is_seen = 0 AND v.is_from_me = 0 THEN 1 ELSE 0 END),
           MAX(CASE WHEN v.is_from_me = 0 THEN v.ts END),
           MAX(v.ts),
           MAX(v.is_flagged),
           MAX(v.has_attachments),
           MAX(v.is_from_me),
           (SELECT m2.id FROM message_row_assignments r2 JOIN messages m2 ON m2.id = r2.message_id
              WHERE r2.row_key = v.row_key AND m2.is_deleted = 0
                AND m2.folder_id NOT IN (SELECT id FROM folders WHERE role IN ('junk','trash'))
              ORDER BY COALESCE(m2.date, m2.internal_date) DESC, m2.id DESC LIMIT 1),
           strftime('%s','now'),
           SUM(CASE WHEN v.cls <> 'feeds' THEN 1 ELSE 0 END),
           SUM(CASE WHEN v.cls <> 'feeds' AND v.is_seen = 0 AND v.is_from_me = 0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN v.cls = 'feeds' THEN 1 ELSE 0 END),
           SUM(CASE WHEN v.cls = 'feeds' AND v.is_seen = 0 AND v.is_from_me = 0 THEN 1 ELSE 0 END),
           MAX(CASE WHEN v.cls <> 'feeds' AND v.is_from_me = 0 THEN v.ts END),
           MAX(CASE WHEN v.cls = 'feeds' THEN v.ts END),
           (SELECT m2.id FROM message_row_assignments r2 JOIN messages m2 ON m2.id = r2.message_id
              WHERE r2.row_key = v.row_key AND m2.is_deleted = 0 AND m2.classification <> 'feeds'
                AND m2.folder_id NOT IN (SELECT id FROM folders WHERE role IN ('junk','trash'))
              ORDER BY COALESCE(m2.date, m2.internal_date) DESC, m2.id DESC LIMIT 1),
           (SELECT m2.id FROM message_row_assignments r2 JOIN messages m2 ON m2.id = r2.message_id
              WHERE r2.row_key = v.row_key AND m2.is_deleted = 0 AND m2.classification = 'feeds'
                AND m2.folder_id NOT IN (SELECT id FROM folders WHERE role IN ('junk','trash'))
              ORDER BY COALESCE(m2.date, m2.internal_date) DESC, m2.id DESC LIMIT 1)
    FROM (
      SELECT m.id, m.is_seen, m.is_flagged, m.has_attachments, m.is_from_me, m.classification AS cls,
             COALESCE(m.date, m.internal_date) AS ts, r.row_key
      FROM dirty_rows d
      JOIN message_row_assignments r ON r.row_key = d.row_key
      JOIN messages m ON m.id = r.message_id
      WHERE m.is_deleted = 0
        AND m.folder_id NOT IN (SELECT id FROM folders WHERE role IN ('junk','trash'))
    ) v
    GROUP BY v.row_key
  ''';

  /// The list: one summary row joined to its newest message, prefs,
  /// contact or group. All joins are primary-key lookups.
  static const _listSql = '''
    SELECT s.row_key, s.total, s.unread, s.last_received, s.last_any, s.has_starred, s.has_attachments, s.has_sent,
           s.people_total, s.people_unread, s.feeds_total, s.feeds_unread, s.last_people, s.last_feeds,
           m.subject AS p_subject, m.snippet AS p_snippet, m.is_from_me AS p_from_me,
           mp.subject AS pp_subject, mp.snippet AS pp_snippet, mp.is_from_me AS pp_from_me,
           mf.subject AS pf_subject, mf.snippet AS pf_snippet, mf.is_from_me AS pf_from_me,
           COALESCE(p.pinned, 0) AS pinned, p.snoozed_until AS snoozed_until, p.resurfaced_at AS resurfaced_at, COALESCE(p.muted, 0) AS muted,
           COALESCE(NULLIF(c.user_label, ''), c.display_name) AS c_name, NULLIF(c.user_subtitle, '') AS c_subtitle, c.photo_path AS c_photo, COALESCE(c.in_address_book, 0) AS c_in_book,
           COALESCE(c.classification, 'people') AS c_class, c.feeds_category AS c_category, COALESCE(c.counts_toward_unread, 0) AS c_counts,
           g.name AS g_name,
           (SELECT GROUP_CONCAT(DISTINCT mm.account_id) FROM message_row_assignments rr JOIN messages mm ON mm.id = rr.message_id WHERE rr.row_key = s.row_key AND mm.is_deleted = 0) AS account_ids
    FROM row_summaries s
    LEFT JOIN messages m ON m.id = s.newest_message_id
    LEFT JOIN messages mp ON mp.id = s.newest_people_id
    LEFT JOIN messages mf ON mf.id = s.newest_feeds_id
    LEFT JOIN row_prefs p ON p.row_key = s.row_key
    LEFT JOIN contacts c ON substr(s.row_key, 1, 2) = 'c:' AND c.key = substr(s.row_key, 3)
    LEFT JOIN people_groups g ON substr(s.row_key, 1, 2) = 'g:' AND g.id = CAST(substr(s.row_key, 3) AS INTEGER)
  ''';

  /// Same shape as [_listSql], but the summary is computed on the fly for
  /// one account's messages (spec 4.14 per-account view). Slower than the
  /// trigger-maintained table, which is why the unified view does not use it.
  static final _scopedListSql = _listSql.replaceFirst('FROM row_summaries s', '''
    FROM (
      SELECT v.row_key,
             COUNT(*) AS total,
             SUM(CASE WHEN v.is_seen = 0 AND v.is_from_me = 0 THEN 1 ELSE 0 END) AS unread,
             MAX(CASE WHEN v.is_from_me = 0 THEN v.ts END) AS last_received,
             MAX(v.ts) AS last_any,
             MAX(v.is_flagged) AS has_starred,
             MAX(v.has_attachments) AS has_attachments,
             MAX(v.is_from_me) AS has_sent,
             (SELECT m2.id FROM message_row_assignments r2 JOIN messages m2 ON m2.id = r2.message_id
                WHERE r2.row_key = v.row_key AND m2.is_deleted = 0 AND m2.account_id = v.account_id
                  AND m2.folder_id NOT IN (SELECT id FROM folders WHERE role IN ('junk','trash'))
                ORDER BY COALESCE(m2.date, m2.internal_date) DESC, m2.id DESC LIMIT 1) AS newest_message_id,
             SUM(CASE WHEN v.cls <> 'feeds' THEN 1 ELSE 0 END) AS people_total,
             SUM(CASE WHEN v.cls <> 'feeds' AND v.is_seen = 0 AND v.is_from_me = 0 THEN 1 ELSE 0 END) AS people_unread,
             SUM(CASE WHEN v.cls = 'feeds' THEN 1 ELSE 0 END) AS feeds_total,
             SUM(CASE WHEN v.cls = 'feeds' AND v.is_seen = 0 AND v.is_from_me = 0 THEN 1 ELSE 0 END) AS feeds_unread,
             MAX(CASE WHEN v.cls <> 'feeds' AND v.is_from_me = 0 THEN v.ts END) AS last_people,
             MAX(CASE WHEN v.cls = 'feeds' THEN v.ts END) AS last_feeds,
             (SELECT m2.id FROM message_row_assignments r2 JOIN messages m2 ON m2.id = r2.message_id
                WHERE r2.row_key = v.row_key AND m2.is_deleted = 0 AND m2.account_id = v.account_id AND m2.classification <> 'feeds'
                  AND m2.folder_id NOT IN (SELECT id FROM folders WHERE role IN ('junk','trash'))
                ORDER BY COALESCE(m2.date, m2.internal_date) DESC, m2.id DESC LIMIT 1) AS newest_people_id,
             (SELECT m2.id FROM message_row_assignments r2 JOIN messages m2 ON m2.id = r2.message_id
                WHERE r2.row_key = v.row_key AND m2.is_deleted = 0 AND m2.account_id = v.account_id AND m2.classification = 'feeds'
                  AND m2.folder_id NOT IN (SELECT id FROM folders WHERE role IN ('junk','trash'))
                ORDER BY COALESCE(m2.date, m2.internal_date) DESC, m2.id DESC LIMIT 1) AS newest_feeds_id
      FROM (
        SELECT m.id, m.is_seen, m.is_flagged, m.has_attachments, m.is_from_me, m.classification AS cls, m.account_id,
               COALESCE(m.date, m.internal_date) AS ts, r.row_key
        FROM message_row_assignments r
        JOIN messages m ON m.id = r.message_id
        WHERE m.account_id = ? AND m.is_deleted = 0
          AND m.folder_id NOT IN (SELECT id FROM folders WHERE role IN ('junk','trash'))
      ) v
      GROUP BY v.row_key
    ) s
''');

  Future<List<PeopleRow>> _materialize(List<QueryRow> rows, {required PeopleFilter filter, required String search, InboxTab tab = InboxTab.people, String? category, PeopleSort sort = PeopleSort.newest}) async {
    final inCategory = category == null ? null : await _rowsInCategory(category);
    Map<int, List<(String, String)>>? membersByGroup;
    Future<List<(String, String)>> membersFor(int groupId) async {
      if (membersByGroup == null) {
        final members = await select(groupMembers).get();
        final contactRows = {for (final c in await select(contacts).get()) c.key: c};
        membersByGroup = {};
        for (final m in members) {
          final c = contactRows[m.contactKey];
          membersByGroup!.putIfAbsent(m.groupId, () => []).add((m.contactKey, c?.shownName ?? m.contactKey));
        }
      }
      return membersByGroup![groupId] ?? const [];
    }

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final out = <PeopleRow>[];
    for (final r in rows) {
      final d = r.data;
      final rowKey = d['row_key'] as String;
      final ref = RowRef.parse(rowKey);
      final isGroupRow = ref is GroupRow;
      final peopleTotal = (d['people_total'] as int?) ?? 0;
      final feedsTotal = (d['feeds_total'] as int?) ?? 0;
      final peopleUnread = (d['people_unread'] as int?) ?? 0;
      final feedsUnread = (d['feeds_unread'] as int?) ?? 0;
      final classification = isGroupRow ? 'people' : ((d['c_class'] as String?) ?? 'people');
      // Spec 4.11: a row shows under People when it has People messages and
      // under Feeds when it is a Feeds sender. The user's own mail does not
      // keep a Feeds sender in People: only incoming mail filed there does (a
      // reply to the user, for example). `last_people` is set only by that.
      final feedsSender = !isGroupRow && classification == 'feeds';
      final inboundPeople = d['last_people'] != null;
      final inPeople = isGroupRow || (feedsSender ? inboundPeople : peopleTotal > 0);
      // A Feeds contact the user only wrote to (a bounce address, say) is
      // nobody's conversation: it shows in neither list.
      final inFeeds = feedsSender && (feedsTotal > 0 || (!inPeople && d['last_received'] != null));
      if (tab == InboxTab.people ? !inPeople : !inFeeds) continue;
      if (inCategory != null && !inCategory.contains(rowKey)) continue;
      final feedsTab = tab == InboxTab.feeds;
      final lastReceived = feedsTab ? _dt(d['last_feeds']) : (_dt(d['last_people']) ?? _dt(d['last_received']));
      final lastAny = _dt(d['last_any']);
      final unread = feedsTab ? feedsUnread : peopleUnread;
      final hasStarred = d['has_starred'] == 1;
      final hasAttachments = d['has_attachments'] == 1;
      final hasSent = d['has_sent'] == 1;
      final inBook = d['c_in_book'] == 1;

      final snoozedUntil = _dt(d['snoozed_until']);
      final snoozed = snoozedUntil != null && snoozedUntil.isAfter(DateTime.now());
      if (filter == PeopleFilter.snoozed ? !snoozed : snoozed) continue;
      final resurfacedAt = _dt(d['resurfaced_at']);
      final passes = switch (filter) {
        PeopleFilter.all => true,
        PeopleFilter.snoozed => true,
        PeopleFilter.unread => unread > 0,
        PeopleFilter.starred => hasStarred,
        PeopleFilter.thisWeek => lastAny != null && !lastAny.isBefore(weekAgo),
        PeopleFilter.sent => hasSent,
        PeopleFilter.hasAttachments => hasAttachments,
        PeopleFilter.fromContacts => inBook,
      };
      if (!passes) continue;

      String title;
      String identityKey;
      List<(String, String)> members = const [];
      switch (ref) {
        case ContactRow(:final contactKey):
          final name = (d['c_name'] as String?) ?? '';
          title = contactKey == 'me' ? 'You' : (name.isNotEmpty ? name : contactKey);
          identityKey = contactKey;
        case GroupRow(:final groupId):
          title = (d['g_name'] as String?) ?? 'Group';
          identityKey = rowKey;
          members = await membersFor(groupId);
      }

      final previewPrefix = feedsTab ? 'pf' : (isGroupRow ? 'p' : 'pp');
      final subject = (d['${previewPrefix}_subject'] as String?) ?? (d['p_subject'] as String?) ?? '';
      final snippet = (d['${previewPrefix}_snippet'] as String?) ?? (d['p_snippet'] as String?) ?? '';
      final subtitle = ref is ContactRow ? d['c_subtitle'] as String? : null;
      if (search.isNotEmpty) {
        final hay = '${title.toLowerCase()} ${(subtitle ?? '').toLowerCase()} ${identityKey.toLowerCase()} ${subject.toLowerCase()} ${snippet.toLowerCase()}';
        if (!hay.contains(search)) continue;
      }

      out.add(PeopleRow(
        ref: ref,
        title: title,
        subtitle: subtitle,
        photoPath: ref is ContactRow ? d['c_photo'] as String? : null,
        onFeedsTab: feedsTab,
        identityKey: identityKey,
        lastActivity: _later(ref is GroupRow ? lastAny : (lastReceived ?? lastAny), resurfacedAt),
        previewSubject: subject,
        previewSnippet: snippet,
        previewFromMe: (d['${previewPrefix}_from_me'] ?? d['p_from_me']) == 1,
        unread: unread,
        total: feedsTab ? feedsTotal : (isGroupRow ? ((d['total'] as int?) ?? 0) : peopleTotal),
        pinned: d['pinned'] == 1,
        hasStarred: hasStarred,
        hasAttachments: hasAttachments,
        members: members,
        classification: classification,
        // Filtered by a category, the row shows why it is there.
        category: category ?? d['c_category'] as String?,
        countsTowardUnread: d['c_counts'] == 1,
        peopleUnread: peopleUnread,
        feedsUnread: feedsUnread,
        snoozedUntil: snoozedUntil,
        muted: d['muted'] == 1,
        accountIds: {for (final s in ((d['account_ids'] as String?) ?? '').split(',')) if (int.tryParse(s) != null) int.parse(s)},
      ));
    }

    out.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final at = a.lastActivity?.millisecondsSinceEpoch ?? 0;
      final bt = b.lastActivity?.millisecondsSinceEpoch ?? 0;
      final an = a.title.toLowerCase();
      final bn = b.title.toLowerCase();
      return switch (sort) {
        PeopleSort.newest => bt.compareTo(at),
        PeopleSort.oldest => at.compareTo(bt),
        PeopleSort.nameAZ => an == bn ? bt.compareTo(at) : an.compareTo(bn),
        PeopleSort.nameZA => an == bn ? bt.compareTo(at) : bn.compareTo(an),
      };
    });
    return out;
  }

  static DateTime? _later(DateTime? a, DateTime? b) => a == null ? b : (b == null ? a : (b.isAfter(a) ? b : a));

  /// drift stores DateTime columns as Unix seconds.
  static DateTime? _dt(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as int) * 1000);
}
