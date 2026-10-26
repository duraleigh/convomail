import 'dart:io';

import 'package:convomail/app/settings.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/platform/single_instance.dart';
import 'package:convomail/store/classification_queries.dart';
import 'package:convomail/store/database.dart' hide Tags;
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/planner_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/notification_center.dart';
import 'package:convomail/sync/schedule_service.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Notifications and Windows integration (spec 4.17, plan M10): which new
/// mail notifies, mutes, badge counting, notices becoming toasts, the
/// sync hook that only fires after the first download, and the
/// single-instance handshake.
void main() {
  const me = RemoteAddress('me@example.com');
  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;
  late RecordingNotificationSink sink;
  late ProviderContainer container;

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    account = await insertTestAccount(db);
    sink = RecordingNotificationSink();
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
      databaseProvider.overrideWith((ref) => db),
      credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
      transportFactoryProvider.overrideWith((ref) => () => imap),
      notificationSinkProvider.overrideWith((ref) => sink),
    ]);
    imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  AccountSyncer syncer({void Function(List<int>)? onNew}) =>
      AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'), onNewMessages: onNew);

  int addMail(String from, String name, String subject, {bool seen = false, BulkSignals signals = BulkSignals.none}) =>
      imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: RemoteAddress(from, name), to: const [me], subject: subject, date: DateTime.now(), flags: MessageFlagsState(seen: seen), signals: signals));

  test('the first download never notifies; later arrivals in INBOX do, grouped by sender', () async {
    addMail('sarah@chen.me', 'Sarah Chen', 'Old one');
    final batches = <List<int>>[];
    final s = syncer(onNew: batches.add);
    await s.syncOnce();
    expect(batches, isEmpty, reason: 'initial sync is silent');

    addMail('sarah@chen.me', 'Sarah Chen', 'Lunch?');
    addMail('sarah@chen.me', 'Sarah Chen', 'Re: Lunch?');
    addMail('tom@andersen.me', 'Tom Andersen', 'Slides');
    await s.syncOnce();
    expect(batches, hasLength(1));
    expect(batches.single, hasLength(3));

    final shown = await container.read(notificationCenterProvider).onNewMessages(batches.single);
    expect(shown, hasLength(2), reason: 'one notification per sender');
    final sarah = shown.firstWhere((n) => n.title.startsWith('Sarah'));
    expect(sarah.title, 'Sarah Chen · 2 new');
    expect(sarah.body, 'Lunch? · Re: Lunch?');
    expect(sarah.rowKey, 'c:sarah@chen.me');
    expect(shown.firstWhere((n) => n.title == 'Tom Andersen').body, 'Slides');
    expect(sink.shown, hasLength(2));
  });

  test('seen mail, my own mail, muted accounts, muted rows, snoozed rows, and Feeds senders are skipped', () async {
    addMail('x@y.com', 'X', 'warmup');
    final s = syncer();
    await s.syncOnce();
    final seen = addMail('sarah@chen.me', 'Sarah Chen', 'Read already', seen: true);
    final muted = addMail('tom@andersen.me', 'Tom Andersen', 'Muted row');
    final snoozed = addMail('joann@lee.me', 'Joann Lee', 'Snoozed row');
    final feeds = addMail('noreply@shop.com', 'Shop', 'Order shipped', signals: const BulkSignals(listUnsubscribe: true));
    final counting = addMail('digest@paper.com', 'Paper', 'Morning edition', signals: const BulkSignals(listUnsubscribe: true, listId: true));
    final ok = addMail('mike@r.me', 'Mike R', 'Hello');
    expect([seen, muted, snoozed, feeds, counting, ok], everyElement(greaterThan(0)));
    await s.syncOnce();
    await db.into(db.rowPrefs).insertOnConflictUpdate(const RowPrefsCompanion(rowKey: Value('c:tom@andersen.me'), muted: Value(true)));
    await db.snoozeRow('c:joann@lee.me', DateTime.now().add(const Duration(hours: 1)));
    await db.setCountsTowardUnread('digest@paper.com', true);
    final ids = (await db.select(db.messages).get()).map((m) => m.id).toList();

    final shown = await container.read(notificationCenterProvider).onNewMessages(ids);
    expect(shown.map((n) => n.title).toSet(), {'Mike R', 'Paper', 'X'}, reason: 'Paper counts toward unread; X is the warm-up human');

    // Badge scope on: the shop receipt notifies too.
    await container.read(settingsProvider.notifier).setBadgeIncludeFeeds(true);
    sink.shown.clear();
    final shown2 = await container.read(notificationCenterProvider).onNewMessages(ids);
    expect(shown2.map((n) => n.title), contains('Shop'));

    // Global switch off: nothing.
    await container.read(settingsProvider.notifier).setNotificationsEnabled(false);
    expect(await container.read(notificationCenterProvider).onNewMessages(ids), isEmpty);
    await container.read(settingsProvider.notifier).setNotificationsEnabled(true);
    await container.read(settingsProvider.notifier).setAccountMuted(account.id, true);
    expect(await container.read(notificationCenterProvider).onNewMessages(ids), isEmpty, reason: 'account muted');
  });

  test('badge count: People unread, counting Feeds senders, scope setting, snoozed rows excluded', () async {
    addMail('sarah@chen.me', 'Sarah Chen', 'a');
    addMail('sarah@chen.me', 'Sarah Chen', 'b');
    addMail('tom@andersen.me', 'Tom Andersen', 'c', seen: true);
    addMail('noreply@shop.com', 'Shop', 'd', signals: const BulkSignals(listUnsubscribe: true));
    addMail('digest@paper.com', 'Paper', 'e', signals: const BulkSignals(listUnsubscribe: true));
    await syncer().syncOnce();
    await db.refreshDirtyRows();
    final center = container.read(notificationCenterProvider);
    expect(await center.badgeCount(), 2, reason: 'Sarah unread only');
    await db.setCountsTowardUnread('digest@paper.com', true);
    expect(await center.badgeCount(), 3);
    await container.read(settingsProvider.notifier).setBadgeIncludeFeeds(true);
    expect(await center.badgeCount(), 4);
    await db.snoozeRow('c:sarah@chen.me', DateTime.now().add(const Duration(hours: 1)));
    expect(await center.badgeCount(), 2);
  });

  test('snooze-ended and reminder notices become toasts once', () async {
    addMail('sarah@chen.me', 'Sarah Chen', 'a');
    await syncer().syncOnce();
    await db.refreshDirtyRows();
    container.read(notificationCenterProvider).start();
    await db.snoozeRow('c:sarah@chen.me', DateTime.now().subtract(const Duration(minutes: 1)));
    await db.addReminder(title: 'Call Sarah', dueAt: DateTime.now().subtract(const Duration(minutes: 1)));
    await container.read(scheduleServiceProvider).tick(DateTime.now());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sink.shown.map((n) => n.title).toSet(), {'Back from snooze', 'Reminder'});
    await container.read(scheduleServiceProvider).tick(DateTime.now());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sink.shown, hasLength(2), reason: 'not repeated');
  });

  test('single instance: the second launch forwards its arguments and the first receives them', () async {
    final dir = Directory.systemTemp.createTempSync('convomail_si_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final primary = SingleInstance(dir);
    expect(await primary.forwardToRunning(['mailto:a@b.c']), isFalse, reason: 'nobody listening yet');
    final received = <List<String>>[];
    await primary.becomePrimary(received.add);
    expect(primary.port, greaterThan(0));

    final second = SingleInstance(dir);
    expect(await second.forwardToRunning(['mailto:sarah@x.com?subject=Hi']), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(received.single, ['mailto:sarah@x.com?subject=Hi']);

    await primary.close();
    expect(await second.forwardToRunning(['x']), isFalse, reason: 'lock file removed');
    // A stale lock file (dead port) is ignored.
    File('${dir.path}/instance.json').writeAsStringSync('{"port": 1, "pid": 0}');
    expect(await second.forwardToRunning(['x']), isFalse);
  });
}
