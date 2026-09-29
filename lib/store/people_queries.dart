import 'package:drift/drift.dart';

import '../domain/filing.dart';
import 'database.dart';

/// Which subset of People rows to show (spec 4.7). Exactly one active.
enum PeopleFilter { all, unread, starred, thisWeek, sent, hasAttachments, fromContacts }

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
  });

  final RowRef ref;
  final String title;

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
  Stream<List<PeopleRow>> watchPeopleRows({PeopleFilter filter = PeopleFilter.all, String search = ''}) {
    final q = customSelect(
      _listSql,
      readsFrom: {rowSummaries, rowPrefs, contacts, peopleGroups, groupMembers, messages},
    );
    return q.watch().asyncMap((rows) async {
      // Summaries may be stale right after a migration or a direct write;
      // refreshing here is a no-op when nothing is dirty.
      await refreshDirtyRows();
      return _materialize(rows, filter: filter, search: search.trim().toLowerCase());
    });
  }

  Future<List<PeopleRow>> peopleRows({PeopleFilter filter = PeopleFilter.all, String search = ''}) async {
    await refreshDirtyRows();
    final rows = await customSelect(_listSql).get();
    return _materialize(rows, filter: filter, search: search.trim().toLowerCase());
  }

  /// Messages belonging to a row, newest first. Used by the interim
  /// message list (M2) and the conversation view (M3).
  Stream<List<Message>> watchMessagesForRow(String rowKey) {
    final q = customSelect(
      _rowMessagesSql,
      variables: [Variable.withString(rowKey)],
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
      (row_key, total, unread, last_received, last_any, has_starred, has_attachments, has_sent, newest_message_id, updated_at)
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
           strftime('%s','now')
    FROM (
      SELECT m.id, m.is_seen, m.is_flagged, m.has_attachments, m.is_from_me,
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
           m.subject AS p_subject, m.snippet AS p_snippet, m.is_from_me AS p_from_me,
           COALESCE(p.pinned, 0) AS pinned,
           c.display_name AS c_name, COALESCE(c.in_address_book, 0) AS c_in_book,
           g.name AS g_name
    FROM row_summaries s
    LEFT JOIN messages m ON m.id = s.newest_message_id
    LEFT JOIN row_prefs p ON p.row_key = s.row_key
    LEFT JOIN contacts c ON substr(s.row_key, 1, 2) = 'c:' AND c.key = substr(s.row_key, 3)
    LEFT JOIN people_groups g ON substr(s.row_key, 1, 2) = 'g:' AND g.id = CAST(substr(s.row_key, 3) AS INTEGER)
  ''';

  Future<List<PeopleRow>> _materialize(List<QueryRow> rows, {required PeopleFilter filter, required String search}) async {
    Map<int, List<(String, String)>>? membersByGroup;
    Future<List<(String, String)>> membersFor(int groupId) async {
      if (membersByGroup == null) {
        final members = await select(groupMembers).get();
        final contactRows = {for (final c in await select(contacts).get()) c.key: c};
        membersByGroup = {};
        for (final m in members) {
          final c = contactRows[m.contactKey];
          membersByGroup!.putIfAbsent(m.groupId, () => []).add((m.contactKey, c?.displayName.isNotEmpty == true ? c!.displayName : m.contactKey));
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
      final lastReceived = _dt(d['last_received']);
      final lastAny = _dt(d['last_any']);
      final unread = (d['unread'] as int?) ?? 0;
      final hasStarred = d['has_starred'] == 1;
      final hasAttachments = d['has_attachments'] == 1;
      final hasSent = d['has_sent'] == 1;
      final inBook = d['c_in_book'] == 1;

      final passes = switch (filter) {
        PeopleFilter.all => true,
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

      final subject = (d['p_subject'] as String?) ?? '';
      final snippet = (d['p_snippet'] as String?) ?? '';
      if (search.isNotEmpty) {
        final hay = '${title.toLowerCase()} ${identityKey.toLowerCase()} ${subject.toLowerCase()} ${snippet.toLowerCase()}';
        if (!hay.contains(search)) continue;
      }

      out.add(PeopleRow(
        ref: ref,
        title: title,
        identityKey: identityKey,
        lastActivity: ref is GroupRow ? lastAny : (lastReceived ?? lastAny),
        previewSubject: subject,
        previewSnippet: snippet,
        previewFromMe: d['p_from_me'] == 1,
        unread: unread,
        total: (d['total'] as int?) ?? 0,
        pinned: d['pinned'] == 1,
        hasStarred: hasStarred,
        hasAttachments: hasAttachments,
        members: members,
      ));
    }

    out.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final at = a.lastActivity?.millisecondsSinceEpoch ?? 0;
      final bt = b.lastActivity?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });
    return out;
  }

  /// drift stores DateTime columns as Unix seconds.
  static DateTime? _dt(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as int) * 1000);
}
