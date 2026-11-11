import 'package:drift/drift.dart';

import '../domain/quoted_mail.dart';
import 'database.dart';

/// An email the user is waiting on an answer to.
class WaitingItem {
  const WaitingItem({required this.message, required this.rowKey, required this.name, required this.sentAt});

  /// The user's own email that has had no answer.
  final Message message;
  final String rowKey;

  /// Who it went to, as shown in Chats.
  final String name;
  final DateTime sentAt;
}

/// Something marked done today, for Today's Done list.
class DoneItem {
  const DoneItem({required this.title, required this.who, required this.at, this.rowKey, this.threadKey});
  final String title;
  final String who;
  final DateTime at;
  final String? rowKey;
  final String? threadKey;
}

/// A row put off until later.
class LaterRow {
  const LaterRow({required this.rowKey, required this.name, required this.until});
  final String rowKey;
  final String name;
  final DateTime until;
}

/// Done, and what Today shows that needs no reading for meaning: who the
/// user is waiting on, what was put off, and what was finished today.
extension DoneQueries on AppDatabase {
  /// Marks emails done or open again. Done only says "I have dealt with
  /// this": the email stays where it is.
  Future<void> setMessagesDone(Iterable<int> ids, bool done) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (update(messages)..where((m) => m.id.isIn(list))).write(MessagesCompanion(doneAt: Value(done ? DateTime.now() : null)));
  }

  /// How long the user waits before an unanswered email shows, and how far
  /// back the list looks.
  static const waitingAfter = Duration(days: 3);
  static const waitingWindow = Duration(days: 30);

  /// The user wrote last, to a person, asked something, and has had no
  /// answer for [waitingAfter]. Newest first. No reading for meaning: an
  /// email counts as asking when its own words hold a question mark.
  Stream<List<WaitingItem>> watchWaitingOn({DateTime? now, int? accountId}) {
    final at = now ?? DateTime.now();
    final newest = at.subtract(waitingAfter).millisecondsSinceEpoch ~/ 1000;
    final oldest = at.subtract(waitingWindow).millisecondsSinceEpoch ~/ 1000;
    return customSelect(
      '''
      SELECT x.*, (SELECT COALESCE(NULLIF(c.user_label, ''), NULLIF(c.display_name, ''), c.key) FROM contacts c WHERE c.key = substr(x.w_row, 3)) AS w_name
      FROM (
      SELECT m.*, MIN(r.row_key) AS w_row
      FROM messages m
      JOIN message_row_assignments r ON r.message_id = m.id
      JOIN folders f ON f.id = m.folder_id
      LEFT JOIN contacts c ON c.key = substr(r.row_key, 3)
      WHERE m.is_from_me = 1 AND m.is_deleted = 0 AND m.is_draft = 0 AND m.done_at IS NULL
        ${accountId == null ? '' : 'AND m.account_id = ?'}
        AND f.role NOT IN ('junk', 'trash', 'drafts')
        AND substr(r.row_key, 1, 2) = 'c:' AND substr(r.row_key, 3) <> 'me'
        AND COALESCE(c.classification, 'people') = 'people'
        AND COALESCE(m.date, m.internal_date) BETWEEN ? AND ?
        AND NOT EXISTS (
          SELECT 1 FROM messages n JOIN message_row_assignments rn ON rn.message_id = n.id
          WHERE rn.row_key = r.row_key AND n.is_deleted = 0 AND n.id <> m.id
            AND COALESCE(n.date, n.internal_date) > COALESCE(m.date, m.internal_date))
      GROUP BY m.id
      ) x
      ORDER BY COALESCE(x.date, x.internal_date) DESC
      LIMIT 60
      ''',
      variables: [if (accountId != null) Variable.withInt(accountId), Variable.withInt(oldest), Variable.withInt(newest)],
      readsFrom: {messages, messageRowAssignments, contacts, folders},
    ).watch().map((rows) {
      final out = <WaitingItem>[];
      for (final r in rows) {
        final m = messages.map(r.data);
        if (!_asks(m)) continue;
        out.add(WaitingItem(message: m, rowKey: r.read<String>('w_row'), name: r.readNullable<String>('w_name') ?? '', sentAt: m.date ?? m.internalDate ?? at));
      }
      return out;
    });
  }

  /// The user's own recent emails whose words are not on this device yet.
  /// "Waiting on" needs them: it cannot tell whether an email asked
  /// something without its words. Newest first.
  Future<List<Message>> sentWithoutWords(int accountId, {int limit = 20, DateTime? now}) async {
    final since = (now ?? DateTime.now()).subtract(waitingWindow).millisecondsSinceEpoch ~/ 1000;
    final rows = await customSelect(
      '''
      SELECT m.* FROM messages m
      JOIN folders f ON f.id = m.folder_id
      WHERE m.account_id = ? AND m.is_from_me = 1 AND m.is_deleted = 0 AND m.is_draft = 0
        AND m.body_fetched_at IS NULL
        AND COALESCE(m.date, m.internal_date) >= ?
        AND f.role NOT IN ('junk', 'trash', 'drafts')
      ORDER BY COALESCE(m.date, m.internal_date) DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(accountId), Variable.withInt(since), Variable.withInt(limit)],
    ).get();
    return [for (final r in rows) messages.map(r.data)];
  }

  static final _attribution = RegExp(r'\bOn .{5,120}? wrote:', dotAll: true);

  /// Whether the user's own words in [m] (not the mail quoted below them)
  /// hold a question.
  static bool _asks(Message m) {
    final body = (m.bodyText ?? '').trim();
    var own = body.isNotEmpty ? splitQuotedText(body, subject: m.subject).fresh : m.snippet;
    final cut = _attribution.firstMatch(own);
    if (cut != null) own = own.substring(0, cut.start);
    return own.contains('?');
  }

  /// Rows put off until later, soonest first.
  Stream<List<LaterRow>> watchLaterRows({DateTime? now}) {
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return customSelect(
      '''
      SELECT p.row_key AS k, p.snoozed_until AS u,
             COALESCE(NULLIF(c.user_label, ''), NULLIF(c.display_name, ''), c.key, g.name, p.row_key) AS n
      FROM row_prefs p
      LEFT JOIN contacts c ON substr(p.row_key, 1, 2) = 'c:' AND c.key = substr(p.row_key, 3)
      LEFT JOIN people_groups g ON substr(p.row_key, 1, 2) = 'g:' AND g.id = CAST(substr(p.row_key, 3) AS INTEGER)
      WHERE p.snoozed_until IS NOT NULL AND p.snoozed_until > ?
      ORDER BY p.snoozed_until
      ''',
      variables: [Variable.withInt(at)],
      readsFrom: {rowPrefs, contacts, peopleGroups},
    ).watch().map((rows) => [for (final r in rows) LaterRow(rowKey: r.read<String>('k'), name: r.read<String>('n'), until: DateTime.fromMillisecondsSinceEpoch(r.read<int>('u') * 1000))]);
  }

  /// What was marked done since the start of [day] (today by default):
  /// one line per thread, newest first.
  Stream<List<DoneItem>> watchDoneToday({DateTime? day}) {
    final d = day ?? DateTime.now();
    final start = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;
    return customSelect(
      '''
      SELECT x.*, (SELECT COALESCE(NULLIF(c.user_label, ''), NULLIF(c.display_name, ''), c.key) FROM contacts c WHERE c.key = substr(x.row_key, 3)) AS who
      FROM (
      SELECT COALESCE(NULLIF(m.thread_key, ''), 'm:' || m.id) AS t, MAX(m.done_at) AS at, m.subject AS subject, m.thread_key AS thread_key,
             MIN(r.row_key) AS row_key
      FROM messages m
      LEFT JOIN message_row_assignments r ON r.message_id = m.id
      WHERE m.done_at IS NOT NULL AND m.done_at >= ? AND m.is_deleted = 0
      GROUP BY t
      ) x
      ORDER BY x.at DESC
      ''',
      variables: [Variable.withInt(start)],
      readsFrom: {messages, messageRowAssignments, contacts},
    ).watch().map((rows) => [
          for (final r in rows)
            DoneItem(
              title: (r.readNullable<String>('subject') ?? '').isEmpty ? '(no subject)' : r.read<String>('subject'),
              who: r.readNullable<String>('who') ?? '',
              at: DateTime.fromMillisecondsSinceEpoch(r.read<int>('at') * 1000),
              rowKey: r.readNullable<String>('row_key'),
              threadKey: r.readNullable<String>('thread_key'),
            ),
        ]);
  }
}
