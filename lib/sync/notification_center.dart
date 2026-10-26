import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/settings.dart';
import '../store/database.dart';
import '../store/people_queries.dart';
import 'schedule_service.dart';

/// What gets shown to the user outside the window: a toast with a title,
/// body, and what to open when clicked.
class OutgoingNotification {
  const OutgoingNotification({required this.id, required this.title, required this.body, this.rowKey, this.messageId});
  final String id;
  final String title;
  final String body;
  final String? rowKey;
  final int? messageId;
}

/// Platform sink for notifications (Windows toasts in the app, a recorder
/// in tests).
abstract interface class NotificationSink {
  Future<void> show(OutgoingNotification n);
}

class RecordingNotificationSink implements NotificationSink {
  final List<OutgoingNotification> shown = [];
  @override
  Future<void> show(OutgoingNotification n) async => shown.add(n);
}

final notificationSinkProvider = Provider<NotificationSink>((ref) => RecordingNotificationSink());

/// Called with the clicked notification; the shell opens the row.
final notificationClickProvider = NotifierProvider<NotificationClickNotifier, OutgoingNotification?>(NotificationClickNotifier.new);

class NotificationClickNotifier extends Notifier<OutgoingNotification?> {
  @override
  OutgoingNotification? build() => null;
  void clicked(OutgoingNotification n) => state = n;
  void clear() => state = null;
}

final notificationCenterProvider = Provider<NotificationCenter>((ref) {
  final c = NotificationCenter(ref);
  ref.onDispose(c.dispose);
  return c;
});

/// Decides what deserves a notification (spec 4.17): new People mail
/// (or mail from a Feeds sender marked "counts toward unread") that is
/// unread, not from the user, not from a muted account or a muted row;
/// plus snooze wake-ups and reminders. Groups a batch by sender.
class NotificationCenter {
  NotificationCenter(this._ref);
  final Ref _ref;
  StreamSubscription<List<AppNotice>>? _noticeSub;
  final Set<String> _seenNotices = {};

  AppDatabase get _db => _ref.read(databaseProvider);

  /// Starts forwarding in-app notices (snooze ended, reminder due) to toasts.
  void start() {
    _ref.listen<List<AppNotice>>(appNoticesProvider, (prev, next) {
      for (final n in next) {
        if (_seenNotices.add(n.id)) {
          unawaited(_ref.read(notificationSinkProvider).show(OutgoingNotification(id: n.id, title: n.title, body: n.body, rowKey: n.rowKey, messageId: n.messageId)));
        }
      }
    }, fireImmediately: false);
  }

  void dispose() {
    _noticeSub?.cancel();
  }

  /// New messages just synced (local ids). Returns the notifications shown.
  Future<List<OutgoingNotification>> onNewMessages(List<int> messageIds) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.notificationsEnabled || messageIds.isEmpty) return const [];
    final msgs = await (_db.select(_db.messages)..where((m) => m.id.isIn(messageIds))).get();
    final bySender = <String, List<Message>>{};
    for (final m in msgs) {
      if (m.isFromMe || m.isSeen || m.isDeleted) continue;
      if (settings.mutedAccounts.contains(m.accountId)) continue;
      final contact = await (_db.select(_db.contacts)..where((c) => c.key.equals(m.fromContactKey))).getSingleOrNull();
      final feeds = m.classification == 'feeds';
      if (feeds && !(contact?.countsTowardUnread ?? false) && !settings.badgeIncludeFeeds) continue;
      final rowKeys = (await (_db.select(_db.messageRowAssignments)..where((r) => r.messageId.equals(m.id))).get()).map((r) => r.rowKey).toList();
      var muted = false;
      for (final k in rowKeys) {
        final pref = await _db.rowPref(k);
        if (pref?.muted == true || (pref?.snoozedUntil != null && pref!.snoozedUntil!.isAfter(DateTime.now()))) muted = true;
      }
      if (muted) continue;
      bySender.putIfAbsent(m.fromContactKey, () => []).add(m);
    }
    final out = <OutgoingNotification>[];
    final sink = _ref.read(notificationSinkProvider);
    for (final e in bySender.entries) {
      final first = e.value.first;
      final sender = first.fromName.isNotEmpty ? first.fromName : first.fromAddress;
      final rowKey = (await (_db.select(_db.messageRowAssignments)..where((r) => r.messageId.equals(first.id))..limit(1)).getSingleOrNull())?.rowKey;
      final n = e.value.length == 1
          ? OutgoingNotification(id: 'mail:${first.id}', title: sender, body: first.subject.isEmpty ? '(no subject)' : first.subject, rowKey: rowKey, messageId: first.id)
          : OutgoingNotification(id: 'mail:${first.id}:${e.value.length}', title: '$sender · ${e.value.length} new', body: e.value.map((m) => m.subject).where((s) => s.isNotEmpty).take(3).join(' · '), rowKey: rowKey, messageId: first.id);
      out.add(n);
      await sink.show(n);
    }
    return out;
  }

  /// Unread total for the taskbar badge and tray tooltip (spec 4.17): People
  /// unread, plus Feeds unread when the scope setting is on, plus unread
  /// from Feeds senders marked "counts toward unread". Muted rows excluded.
  Future<int> badgeCount() async {
    final settings = _ref.read(settingsProvider);
    final rows = await _db.peopleRows();
    final feedsRows = await _db.peopleRows(tab: InboxTab.feeds);
    var n = 0;
    for (final r in rows) {
      if (!r.isSnoozed) n += r.peopleUnread;
    }
    for (final r in feedsRows) {
      if (settings.badgeIncludeFeeds || r.countsTowardUnread) n += r.feedsUnread;
    }
    return n;
  }
}
