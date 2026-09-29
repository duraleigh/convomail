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
  /// Live People rows for [filter], pinned first, then by activity.
  /// Messages in junk/trash folders and locally deleted messages are
  /// excluded. `search` matches title, address, subject or snippet.
  Stream<List<PeopleRow>> watchPeopleRows({PeopleFilter filter = PeopleFilter.all, String search = ''}) {
    final q = customSelect(
      _peopleRowsSql,
      variables: [Variable.withDateTime(DateTime.now().subtract(const Duration(days: 7)))],
      readsFrom: {messages, messageRowAssignments, folders, contacts, rowPrefs, peopleGroups, groupMembers, messageParticipants},
    );
    return q.watch().asyncMap((rows) => _materialize(rows, filter: filter, search: search.trim().toLowerCase()));
  }

  Future<List<PeopleRow>> peopleRows({PeopleFilter filter = PeopleFilter.all, String search = ''}) async {
    final rows = await customSelect(
      _peopleRowsSql,
      variables: [Variable.withDateTime(DateTime.now().subtract(const Duration(days: 7)))],
    ).get();
    return _materialize(rows, filter: filter, search: search.trim().toLowerCase());
  }

  /// Messages belonging to a row, newest first. Used by the interim
  /// message list (M2) and the conversation view (M3).
  Stream<List<Message>> watchMessagesForRow(String rowKey) {
    final q = customSelect(
      '''
      SELECT m.* FROM messages m
      JOIN message_row_assignments r ON r.message_id = m.id
      JOIN folders f ON f.id = m.folder_id
      WHERE r.row_key = ? AND m.is_deleted = 0 AND f.role NOT IN ('junk','trash')
      ORDER BY COALESCE(m.date, m.internal_date) DESC
      ''',
      variables: [Variable.withString(rowKey)],
      readsFrom: {messages, messageRowAssignments, folders},
    );
    return q.watch().map((rows) => rows.map((r) => messages.map(r.data)).toList());
  }

  Future<List<Message>> messagesForRow(String rowKey) async {
    final rows = await customSelect(
      '''
      SELECT m.* FROM messages m
      JOIN message_row_assignments r ON r.message_id = m.id
      JOIN folders f ON f.id = m.folder_id
      WHERE r.row_key = ? AND m.is_deleted = 0 AND f.role NOT IN ('junk','trash')
      ORDER BY COALESCE(m.date, m.internal_date) DESC
      ''',
      variables: [Variable.withString(rowKey)],
    ).get();
    return rows.map((r) => messages.map(r.data)).toList();
  }

  Future<void> setPinned(String rowKey, bool pinned) => into(rowPrefs).insertOnConflictUpdate(
        RowPrefsCompanion(rowKey: Value(rowKey), pinned: Value(pinned), updatedAt: Value(DateTime.now())),
      );

  Future<RowPref?> rowPref(String rowKey) => (select(rowPrefs)..where((p) => p.rowKey.equals(rowKey))).getSingleOrNull();

  /// One aggregate row per row_key. The window-function subquery picks the
  /// newest message for the preview; the aggregate computes counts and the
  /// contact's newest sent message for ordering (decision 4).
  static const _peopleRowsSql = '''
  WITH visible AS (
    SELECT m.id, m.subject, m.snippet, m.is_from_me, m.is_seen, m.is_flagged, m.has_attachments,
           COALESCE(m.date, m.internal_date) AS ts, r.row_key
    FROM messages m
    JOIN message_row_assignments r ON r.message_id = m.id
    JOIN folders f ON f.id = m.folder_id
    WHERE m.is_deleted = 0 AND f.role NOT IN ('junk','trash')
  ),
  agg AS (
    SELECT row_key,
           COUNT(*) AS total,
           SUM(CASE WHEN is_seen = 0 AND is_from_me = 0 THEN 1 ELSE 0 END) AS unread,
           MAX(CASE WHEN is_from_me = 0 THEN ts END) AS last_received,
           MAX(ts) AS last_any,
           MAX(is_flagged) AS has_starred,
           MAX(has_attachments) AS has_attachments,
           MAX(is_from_me) AS has_sent,
           MAX(CASE WHEN ts >= ?1 THEN 1 ELSE 0 END) AS this_week
    FROM visible GROUP BY row_key
  ),
  newest AS (
    SELECT row_key, subject, snippet, is_from_me,
           ROW_NUMBER() OVER (PARTITION BY row_key ORDER BY ts DESC, id DESC) AS rn
    FROM visible
  )
  SELECT a.row_key, a.total, a.unread, a.last_received, a.last_any, a.has_starred, a.has_attachments, a.has_sent, a.this_week,
         n.subject AS p_subject, n.snippet AS p_snippet, n.is_from_me AS p_from_me,
         COALESCE(p.pinned, 0) AS pinned,
         c.display_name AS c_name, COALESCE(c.in_address_book, 0) AS c_in_book,
         g.name AS g_name
  FROM agg a
  LEFT JOIN newest n ON n.row_key = a.row_key AND n.rn = 1
  LEFT JOIN row_prefs p ON p.row_key = a.row_key
  LEFT JOIN contacts c ON a.row_key = 'c:' || c.key
  LEFT JOIN people_groups g ON a.row_key = 'g:' || CAST(g.id AS TEXT)
  ''';

  Future<List<PeopleRow>> _materialize(List<QueryRow> rows, {required PeopleFilter filter, required String search}) async {
    // Group members for stacked avatars, loaded once per materialization.
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

    final out = <PeopleRow>[];
    for (final r in rows) {
      final rowKey = r.read<String>('row_key');
      final ref = RowRef.parse(rowKey);
      final lastReceived = r.readNullable<DateTime>('last_received');
      final lastAny = r.readNullable<DateTime>('last_any');
      final unread = r.read<int>('unread');
      final hasStarred = r.read<int>('has_starred') == 1;
      final hasAttachments = r.read<int>('has_attachments') == 1;
      final hasSent = r.read<int>('has_sent') == 1;
      final thisWeek = r.read<int>('this_week') == 1;
      final inBook = r.read<int>('c_in_book') == 1;

      final passes = switch (filter) {
        PeopleFilter.all => true,
        PeopleFilter.unread => unread > 0,
        PeopleFilter.starred => hasStarred,
        PeopleFilter.thisWeek => thisWeek,
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
          final name = r.readNullable<String>('c_name') ?? '';
          title = contactKey == 'me' ? 'You' : (name.isNotEmpty ? name : contactKey);
          identityKey = contactKey;
        case GroupRow(:final groupId):
          title = r.readNullable<String>('g_name') ?? 'Group';
          identityKey = rowKey;
          members = await membersFor(groupId);
      }

      final subject = r.readNullable<String>('p_subject') ?? '';
      final snippet = r.readNullable<String>('p_snippet') ?? '';
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
        previewFromMe: (r.readNullable<int>('p_from_me') ?? 0) == 1,
        unread: unread,
        total: r.read<int>('total'),
        pinned: r.read<int>('pinned') == 1,
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
}
