import 'package:drift/drift.dart';

import 'database.dart';
import 'people_queries.dart';

/// Marker characters FTS5 wraps around matched terms; the UI turns them
/// into styled spans.
const String hlStart = '\u0001';
const String hlEnd = '\u0002';

/// One full-text hit (spec 4.6).
class SearchHit {
  const SearchHit({required this.message, required this.rowKey, required this.subjectMarked, required this.snippetMarked, required this.rank});
  final Message message;

  /// The People-list row this message is filed in (first by key when the
  /// message is in several).
  final String rowKey;

  /// Subject and body excerpt with [hlStart]/[hlEnd] around matches.
  final String subjectMarked;
  final String snippetMarked;
  final double rank;
}

/// Full-text search over messages (plan M6). The index is maintained by
/// triggers (see `AppDatabase._createSearchIndex`).
extension SearchQueries on AppDatabase {
  /// Turns free text into an FTS5 MATCH expression: quoted phrases stay
  /// phrases, other words become prefix terms, all AND-ed. Returns null
  /// when nothing searchable remains.
  static String? ftsQuery(String input) {
    final parts = <String>[];
    final phrase = RegExp(r'"([^"]+)"');
    var rest = input;
    for (final m in phrase.allMatches(input)) {
      final p = m.group(1)!.trim();
      if (p.isNotEmpty) parts.add('"${_escape(p)}"');
    }
    rest = input.replaceAll(phrase, ' ');
    for (final w in rest.split(RegExp(r'\s+'))) {
      final t = w.replaceAll(RegExp(r'''["'*^:()\-]'''), '').trim();
      if (t.isEmpty) continue;
      parts.add('"${_escape(t)}"*');
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  static String _escape(String s) => s.replaceAll('"', '""');

  /// The plain terms of a query, for highlighting outside the index.
  static List<String> searchTerms(String input) {
    final out = <String>[];
    final phrase = RegExp(r'"([^"]+)"');
    for (final m in phrase.allMatches(input)) {
      final p = m.group(1)!.trim();
      if (p.isNotEmpty) out.add(p);
    }
    for (final w in input.replaceAll(phrase, ' ').split(RegExp(r'\s+'))) {
      final t = w.replaceAll(RegExp(r'''["'*^:()]'''), '').trim();
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  /// Messages matching [query], scoped by the active filter chip and,
  /// when [rowKey] is given, to one conversation. Ordered by relevance.
  /// [includeFeeds] is carried for spec 4.6; until People/Feeds
  /// classification lands (M8) every sender is a People row.
  Future<List<SearchHit>> searchMessages(
    String query, {
    PeopleFilter filter = PeopleFilter.all,
    String? rowKey,
    bool includeFeeds = false,
    int limit = 100,
    int? accountId,
  }) async {
    final match = ftsQuery(query);
    if (match == null) return const [];
    // FTS auxiliary functions (highlight/snippet/bm25) cannot be used under
    // GROUP BY, so the index is queried in a subquery ranked and capped on
    // its own, and the message/folder/filter conditions apply outside it.
    final where = <String>['m.is_deleted = 0', "fo.role NOT IN ('junk','trash')"];
    final vars = <Variable<Object>>[Variable.withString(match), Variable.withInt((limit * 5).clamp(500, 20000))];
    if (rowKey != null) {
      where.add('EXISTS (SELECT 1 FROM message_row_assignments rr WHERE rr.message_id = m.id AND rr.row_key = ?)');
      vars.add(Variable.withString(rowKey));
    }
    if (accountId != null) {
      where.add('m.account_id = ?');
      vars.add(Variable.withInt(accountId));
    }
    switch (filter) {
      case PeopleFilter.all:
        break;
      case PeopleFilter.unread:
        where.add('m.is_seen = 0 AND m.is_from_me = 0');
      case PeopleFilter.starred:
        where.add('m.is_flagged = 1');
      case PeopleFilter.thisWeek:
        where.add('COALESCE(m.date, m.internal_date) >= ?');
        vars.add(Variable.withInt(DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000));
      case PeopleFilter.sent:
        where.add('m.is_from_me = 1');
      case PeopleFilter.hasAttachments:
        where.add('m.has_attachments = 1');
      case PeopleFilter.fromContacts:
        where.add('EXISTS (SELECT 1 FROM contacts c WHERE c.key = m.from_contact_key AND c.in_address_book = 1)');
      case PeopleFilter.snoozed:
        where.add("EXISTS (SELECT 1 FROM row_prefs p JOIN message_row_assignments ra ON ra.row_key = p.row_key WHERE ra.message_id = m.id AND p.snoozed_until IS NOT NULL AND p.snoozed_until > strftime('%s','now'))");
    }
    vars.add(Variable.withInt(limit));
    final rows = await customSelect(
      '''
      SELECT m.*,
             (SELECT MIN(r.row_key) FROM message_row_assignments r WHERE r.message_id = m.id) AS hit_row_key,
             f.subj_hl, f.snip_hl, f.rank
      FROM (
        SELECT message_id,
               highlight(message_fts, 0, '$hlStart', '$hlEnd') AS subj_hl,
               snippet(message_fts, 2, '$hlStart', '$hlEnd', '…', 14) AS snip_hl,
               bm25(message_fts, 4.0, 2.0, 1.0) AS rank
        FROM message_fts
        WHERE message_fts MATCH ?
        ORDER BY rank
        LIMIT ?
      ) f
      JOIN messages m ON m.id = f.message_id
      JOIN folders fo ON fo.id = m.folder_id
      WHERE ${where.join(' AND ')}
      ORDER BY f.rank, COALESCE(m.date, m.internal_date) DESC
      LIMIT ?
      ''',
      variables: vars,
      readsFrom: {messages, messageRowAssignments, folders},
    ).get();
    return [
      for (final r in rows)
        SearchHit(
          message: messages.map(r.data),
          rowKey: r.read<String>('hit_row_key'),
          subjectMarked: r.readNullable<String>('subj_hl') ?? '',
          snippetMarked: r.readNullable<String>('snip_hl') ?? '',
          rank: (r.data['rank'] as num?)?.toDouble() ?? 0,
        ),
    ];
  }

  /// Ids of the messages in one row that match [query] (in-conversation
  /// search, spec 4.6).
  Future<Set<int>> searchInRow(String rowKey, String query) async {
    final hits = await searchMessages(query, rowKey: rowKey, limit: 2000);
    return {for (final h in hits) h.message.id};
  }

  /// Number of indexed messages; a sanity check for the migration backfill.
  Future<int> searchIndexSize() async => (await customSelect('SELECT COUNT(*) AS n FROM message_fts').getSingle()).read<int>('n');
}
