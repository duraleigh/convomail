import 'package:drift/drift.dart';

import '../domain/timely_extractor.dart';
import 'database.dart';

/// Stored timely items (spec 4.21) and the bookkeeping for reading mail.
extension TimelyQueries on AppDatabase {
  /// How far back the background pass reads mail.
  static const lookback = Duration(days: 30);

  /// Larger messages are skipped: a timely email is small, and the pass
  /// downloads whole messages.
  static const maxMessageSize = 2 * 1024 * 1024;

  /// Stores what was found in message [m], updating anything already known
  /// under the same key. A change of status brings a dismissed item back.
  Future<void> upsertTimely(Message m, List<TimelyFact> facts, DateTime received) async {
    await transaction(() async {
      for (final f in facts) {
        final window = TimelyWindow.of(f, received);
        final existing = await (select(timelyItems)..where((t) => t.dedupeKey.equals(f.dedupeKey))).getSingleOrNull();
        final fresh = TimelyItemsCompanion(
          type: Value(f.type.name),
          dedupeKey: Value(f.dedupeKey),
          messageId: Value(m.id),
          accountId: Value(m.accountId),
          contactKey: Value(m.fromContactKey),
          title: Value(f.title),
          detail: Value(f.detail),
          startsAt: Value(f.startsAt),
          endsAt: Value(f.endsAt),
          showFrom: Value(window.from),
          hideAfter: Value(window.until),
          actionUrl: Value(f.actionUrl),
          actionLabel: Value(f.actionLabel),
          code: Value(f.code),
          status: Value(f.status),
          updatedAt: Value(DateTime.now()),
        );
        if (existing == null) {
          await into(timelyItems).insert(fresh);
        } else {
          final statusChanged = existing.status != f.status;
          await (update(timelyItems)..where((t) => t.id.equals(existing.id))).write(fresh.copyWith(
            // A later note with less to say keeps what was already known.
            startsAt: Value(f.startsAt ?? existing.startsAt),
            actionUrl: Value(f.actionUrl ?? existing.actionUrl),
            hideAfter: Value(f.startsAt == null && existing.startsAt != null && f.status == null ? existing.hideAfter : window.until),
            showFrom: Value(f.startsAt == null && existing.startsAt != null && f.status == null ? existing.showFrom : window.from),
            dismissedAt: statusChanged ? const Value(null) : const Value.absent(),
          ));
        }
      }
    });
  }

  /// Not dismissed and not past, for mail that still exists. The caller
  /// applies the show-from time, which passes while the app runs.
  Stream<List<TimelyItem>> watchTimelyItems({int? accountId}) => customSelect(
        '''
        SELECT t.* FROM timely_items t
        JOIN messages m ON m.id = t.message_id
        WHERE t.dismissed_at IS NULL AND m.is_deleted = 0 ${accountId == null ? '' : 'AND t.account_id = ?'}
        ORDER BY t.show_from
        ''',
        variables: [if (accountId != null) Variable.withInt(accountId)],
        readsFrom: {timelyItems, messages},
      ).watch().map((rows) => [for (final r in rows) timelyItems.map(r.data)]);

  Future<void> dismissTimely(int id) => (update(timelyItems)..where((t) => t.id.equals(id))).write(TimelyItemsCompanion(dismissedAt: Value(DateTime.now())));

  /// Drops items long past, so the table stays small.
  Future<void> pruneTimely(DateTime now) => (delete(timelyItems)..where((t) => t.hideAfter.isSmallerThanValue(now.subtract(const Duration(days: 30))))).go();

  /// Recent incoming mail not yet checked, newest first.
  Future<List<Message>> messagesForTimelyCheck(int accountId, {int limit = 40, DateTime? now}) async {
    final since = (now ?? DateTime.now()).subtract(lookback);
    final rows = await customSelect(
      '''
      SELECT m.* FROM messages m
      JOIN folders f ON f.id = m.folder_id
      WHERE m.account_id = ? AND m.is_from_me = 0 AND m.is_deleted = 0 AND m.timely_checked_at IS NULL
        AND COALESCE(m.date, m.internal_date) >= ?
        AND f.role NOT IN ('junk', 'trash', 'sent')
      ORDER BY COALESCE(m.date, m.internal_date) DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(accountId), Variable.withInt(since.millisecondsSinceEpoch ~/ 1000), Variable.withInt(limit)],
    ).get();
    return [for (final r in rows) messages.map(r.data)];
  }

  Future<void> markTimelyChecked(int messageId, {required bool found}) => (update(messages)..where((m) => m.id.equals(messageId))).write(MessagesCompanion(timelyCheckedAt: Value(DateTime.now()), hasTimelyItem: Value(found)));
}
