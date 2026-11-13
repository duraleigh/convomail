import 'package:drift/drift.dart';

import '../domain/timely_extractor.dart';
import 'database.dart';
import 'helper_queries.dart';

/// Whether an item of this kind is the same on every device. A sign-in
/// code and a "confirm your email address" link are not: the helper keeps
/// no copy of either, so each device finds its own.
bool timelyShared(String type) => type != TimelyType.code.name && type != TimelyType.confirm.name;

/// Stored timely items (spec 4.21) and the bookkeeping for reading mail.
///
/// What one device finds in the mail (a delivery, a payment coming due) is
/// told to the helper, so every device shows the same cards. When two
/// emails about one thing disagree, the newer email wins, on every device,
/// in whatever order they were read. Taking an item off its card, or
/// putting it off, on one device does so on all of them.
extension TimelyQueries on AppDatabase {
  /// How far back the background pass reads mail.
  static const lookback = Duration(days: 30);

  /// Larger messages are skipped: a timely email is small, and the pass
  /// downloads whole messages.
  static const maxMessageSize = 2 * 1024 * 1024;

  /// Stores what was found in message [m], updating anything already known
  /// under the same key. A change of status brings a dismissed item back.
  Future<void> upsertTimely(Message m, List<TimelyFact> facts, DateTime received) async {
    final told = <String>[];
    final back = <String>[];
    await transaction(() async {
      for (final f in facts) {
        final r = await _putTimely(f, messageId: m.id, accountId: m.accountId, contactKey: m.fromContactKey, received: received);
        if (r.changed && timelyShared(f.type.name)) told.add(f.dedupeKey);
        if (r.broughtBack && timelyShared(f.type.name)) back.add(f.dedupeKey);
      }
    });
    for (final key in told) {
      final data = await timelyForHelper(key);
      if (data != null) await noteForHelper('timely', key, data);
    }
    for (final key in back) {
      await noteForHelper('cardfix', 'timely:$key', {'off': false});
    }
  }

  /// What the helper said another device found (or changed). Never told
  /// back to the helper.
  Future<void> applyTimelyFromHelper(String key, Map<String, Object?> data) async {
    final type = TimelyType.values.where((t) => t.name == data['type']).firstOrNull;
    if (type == null || !timelyShared(type.name)) return;
    DateTime? t(Object? v) => v is num && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000) : null;
    final mid = (data['mid'] as String?) ?? '';
    // The email it came from, when this device has it (it may not yet).
    final m = mid.isEmpty ? null : await (select(messages)..where((x) => x.messageId.equals(mid) & x.isDeleted.equals(false))..limit(1)).getSingleOrNull();
    await _putTimely(
      TimelyFact(
        type: type,
        dedupeKey: key,
        title: (data['title'] as String?) ?? '',
        detail: (data['detail'] as String?) ?? '',
        startsAt: t(data['starts']),
        endsAt: t(data['ends']),
        actionUrl: data['url'] as String?,
        actionLabel: data['label'] as String?,
        status: data['status'] as String?,
      ),
      messageId: m?.id,
      accountId: m?.accountId,
      contactKey: (data['from'] as String?) ?? m?.fromContactKey ?? '',
      received: t(data['mat']) ?? DateTime.now(),
      fromHelper: true,
    );
  }

  /// One item as the helper keeps it; null when it is not one every device shares.
  Future<Map<String, Object?>?> timelyForHelper(String key) async {
    final t = await (select(timelyItems)..where((x) => x.dedupeKey.equals(key))).getSingleOrNull();
    if (t == null || !timelyShared(t.type)) return null;
    final m = t.messageId == null ? null : await (select(messages)..where((x) => x.id.equals(t.messageId!))).getSingleOrNull();
    int? s(DateTime? d) => d == null ? null : d.millisecondsSinceEpoch ~/ 1000;
    return {
      'type': t.type,
      'title': t.title,
      'detail': t.detail,
      'starts': s(t.startsAt),
      'ends': s(t.endsAt),
      'url': t.actionUrl,
      'label': t.actionLabel,
      'status': t.status,
      'mat': s(t.mailAt ?? m?.date ?? m?.internalDate ?? t.updatedAt),
      'mid': m?.messageId ?? '',
      'from': t.contactKey,
      'until': s(t.hideAfter),
    };
  }

  /// Writes one fact. An older email never changes what a newer one said,
  /// so every device ends on the same thing in whatever order it reads.
  Future<({bool changed, bool broughtBack})> _putTimely(TimelyFact f, {int? messageId, int? accountId, required String contactKey, required DateTime received, bool fromHelper = false}) async {
    final existing = await (select(timelyItems)..where((t) => t.dedupeKey.equals(f.dedupeKey))).getSingleOrNull();
    final known = existing?.mailAt;
    if (existing != null && known != null && received.isBefore(known)) return (changed: false, broughtBack: false);
    final window = TimelyWindow.of(f, received);
    if (existing == null) {
      await into(timelyItems).insert(TimelyItemsCompanion(
        type: Value(f.type.name),
        dedupeKey: Value(f.dedupeKey),
        messageId: Value(messageId),
        accountId: Value(accountId),
        contactKey: Value(contactKey),
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
        mailAt: Value(received),
        updatedAt: Value(DateTime.now()),
      ));
      return (changed: true, broughtBack: false);
    }
    // A later note with less to say keeps what was already known.
    final keepsTimes = f.startsAt == null && existing.startsAt != null && f.status == null;
    final starts = f.startsAt ?? existing.startsAt;
    final url = f.actionUrl ?? existing.actionUrl;
    final from = keepsTimes ? existing.showFrom : window.from;
    final until = keepsTimes ? existing.hideAfter : window.until;
    final statusChanged = existing.status != f.status;
    bool same(DateTime? a, DateTime? b) => a?.millisecondsSinceEpoch == b?.millisecondsSinceEpoch;
    final nothingNew = existing.type == f.type.name &&
        existing.title == f.title &&
        existing.detail == f.detail &&
        same(existing.startsAt, starts) &&
        same(existing.endsAt, f.endsAt) &&
        existing.actionUrl == url &&
        existing.actionLabel == f.actionLabel &&
        existing.code == f.code &&
        !statusChanged &&
        same(existing.showFrom, from) &&
        same(existing.hideAfter, until) &&
        (messageId == null || existing.messageId == messageId);
    // Told again what is already known: nothing is written.
    if (nothingNew && same(known, received)) return (changed: false, broughtBack: false);
    await (update(timelyItems)..where((t) => t.id.equals(existing.id))).write(TimelyItemsCompanion(
      type: Value(f.type.name),
      // Another device may know the item before this one has its email.
      messageId: messageId == null ? const Value.absent() : Value(messageId),
      accountId: accountId == null ? const Value.absent() : Value(accountId),
      contactKey: contactKey.isEmpty ? const Value.absent() : Value(contactKey),
      title: Value(f.title),
      detail: Value(f.detail),
      startsAt: Value(starts),
      endsAt: Value(f.endsAt),
      showFrom: Value(from),
      hideAfter: Value(until),
      actionUrl: Value(url),
      actionLabel: Value(f.actionLabel),
      code: Value(f.code),
      status: Value(f.status),
      mailAt: Value(received),
      updatedAt: Value(DateTime.now()),
      dismissedAt: statusChanged ? const Value(null) : const Value.absent(),
    ));
    return (changed: !nothingNew, broughtBack: statusChanged && existing.dismissedAt != null && !fromHelper);
  }

  /// Not dismissed and not past, for mail that still exists. The caller
  /// applies the show-from time, which passes while the app runs. An item
  /// another device found shows here even before its email has arrived.
  Stream<List<TimelyItem>> watchTimelyItems({int? accountId}) => customSelect(
        '''
        SELECT t.* FROM timely_items t
        LEFT JOIN messages m ON m.id = t.message_id
        WHERE t.dismissed_at IS NULL AND (m.id IS NULL OR m.is_deleted = 0) ${accountId == null ? '' : 'AND (t.account_id = ? OR t.account_id IS NULL)'}
        ORDER BY t.show_from
        ''',
        variables: [if (accountId != null) Variable.withInt(accountId)],
        readsFrom: {timelyItems, messages},
      ).watch().map((rows) => [for (final r in rows) timelyItems.map(r.data)]);

  /// Tells the helper what the user did to an item, when it is one every device shares.
  Future<void> _tellFix(int id, Map<String, Object?> fix) async {
    final t = await (select(timelyItems)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (t != null && timelyShared(t.type)) await noteForHelper('cardfix', 'timely:${t.dedupeKey}', fix);
  }

  /// Takes an item off its card, on every device.
  Future<void> dismissTimely(int id) async {
    await (update(timelyItems)..where((t) => t.id.equals(id))).write(TimelyItemsCompanion(dismissedAt: Value(DateTime.now())));
    await _tellFix(id, {'off': true});
  }

  /// Puts an item off its card until [until], on every device; null brings it back.
  Future<void> setTimelyLater(int id, DateTime? until) async {
    await (update(timelyItems)..where((t) => t.id.equals(id))).write(TimelyItemsCompanion(laterUntil: Value(until)));
    await _tellFix(id, {'later': until == null ? 0 : until.millisecondsSinceEpoch ~/ 1000});
  }

  /// Brings back an item taken off its card.
  Future<void> undismissTimely(int id) async {
    await (update(timelyItems)..where((t) => t.id.equals(id))).write(const TimelyItemsCompanion(dismissedAt: Value(null)));
    await _tellFix(id, {'off': false});
  }

  /// What the user did to a shared item on another device.
  Future<void> applyTimelyFix(String key, Map<String, Object?> data) async {
    final off = data['off'];
    final hasLater = data.containsKey('later');
    final later = data['later'];
    if (off is! bool && !hasLater) return;
    final t = await (select(timelyItems)..where((x) => x.dedupeKey.equals(key))).getSingleOrNull();
    if (t == null) return;
    final until = later is num && later > 0 ? DateTime.fromMillisecondsSinceEpoch(later.toInt() * 1000) : null;
    final offNow = t.dismissedAt != null;
    final sameOff = off is! bool || off == offNow;
    final sameLater = !hasLater || t.laterUntil?.millisecondsSinceEpoch == until?.millisecondsSinceEpoch;
    if (sameOff && sameLater) return;
    await (update(timelyItems)..where((x) => x.id.equals(t.id))).write(TimelyItemsCompanion(
      dismissedAt: off is bool && !sameOff ? Value(off ? DateTime.now() : null) : const Value.absent(),
      laterUntil: hasLater ? Value(until) : const Value.absent(),
    ));
  }

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
