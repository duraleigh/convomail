import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart' hide Tags;
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/planner_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/schedule_service.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Later (snooze) and reminders: nothing is added from mail, a row put off
/// hides and comes back on top, and reminders fire once.
void main() {
  const me = RemoteAddress('me@example.com');
  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    account = await insertTestAccount(db);
    imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
  });

  tearDown(() => db.close());

  Future<AccountSyncer> sync() async {
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
    return syncer;
  }

  group('no guesses', () {
    test('mail with dates and invitations adds nothing to the Planner', () async {
      final inbox = imap.folder('INBOX');
      final uid = inbox.add(
        RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah'), to: const [me], subject: 'Lunch Tuesday at 12:30?', date: DateTime(2026, 11, 2, 9)),
        body: const RemoteMessageBody(text: 'Can we meet Tuesday at 12:30pm at Cafe Rio?', calendar: r'BEGIN:VCALENDAR\nMETHOD:REQUEST\nBEGIN:VEVENT\nUID:ev-1@cal\nDTSTART:20261105T150000\nDTEND:20261105T160000\nSUMMARY:Design review\nEND:VEVENT\nEND:VCALENDAR'),
      );
      final syncer = await sync();
      final m = (await db.select(db.messages).get()).firstWhere((m) => m.uid == uid);
      await syncer.fetchBody(m.id);
      expect(await db.select(db.plannerEvents).get(), isEmpty);
    });
  });

  group('snooze and reminders', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: [
        settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
        databaseProvider.overrideWith((ref) => db),
        credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
        transportFactoryProvider.overrideWith((ref) => () => imap),
      ]);
    });

    tearDown(() => container.dispose());

    Future<void> seedTwoPeople() async {
      imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@chen.me', 'Sarah Chen'), to: const [me], subject: 'Older', date: DateTime.now().subtract(const Duration(days: 3))));
      imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('tom@andersen.me', 'Tom Andersen'), to: const [me], subject: 'Newer', date: DateTime.now().subtract(const Duration(hours: 1))));
      await sync();
    }

    test('a snoozed row leaves the list, shows under the Snoozed filter, and resurfaces on top with a notice', () async {
      await seedTwoPeople();
      expect((await db.peopleRows()).map((r) => r.title), ['Tom Andersen', 'Sarah Chen']);
      final until = DateTime.now().add(const Duration(hours: 2));
      await db.snoozeRow('c:sarah@chen.me', until);
      expect((await db.peopleRows()).map((r) => r.title), ['Tom Andersen']);
      final snoozed = await db.peopleRows(filter: PeopleFilter.snoozed);
      expect(snoozed.single.title, 'Sarah Chen');
      expect(snoozed.single.isSnoozed, isTrue);

      final service = container.read(scheduleServiceProvider);
      expect(await service.tick(DateTime.now()), isEmpty, reason: 'not due yet');
      final raised = await service.tick(until.add(const Duration(minutes: 1)));
      expect(raised.single.title, 'Back from snooze');
      expect(raised.single.rowKey, 'c:sarah@chen.me');
      expect(container.read(appNoticesProvider).single.body, 'Sarah Chen');
      // Sorted as if newly received: Sarah (resurfaced now) above Tom (1h ago).
      final rows = await db.peopleRows();
      expect(rows.map((r) => r.title), ['Sarah Chen', 'Tom Andersen']);
      expect(rows.first.isSnoozed, isFalse);
      expect(await db.peopleRows(filter: PeopleFilter.snoozed), isEmpty);
    });

    test('unsnoozing clears the hide; presets land on sensible times', () async {
      await seedTwoPeople();
      await db.snoozeRow('c:sarah@chen.me', DateTime.now().add(const Duration(days: 1)));
      await db.snoozeRow('c:sarah@chen.me', null);
      expect((await db.peopleRows()).map((r) => r.title), contains('Sarah Chen'));
      final wed = DateTime(2026, 11, 4, 14, 20); // Wednesday afternoon
      expect(SnoozePresets.tomorrowMorning(wed), DateTime(2026, 11, 5, 8));
      expect(SnoozePresets.nextMondayMorning(wed), DateTime(2026, 11, 9, 8));
      expect(SnoozePresets.thisEvening(wed), DateTime(2026, 11, 4, 18));
      expect(SnoozePresets.thisEvening(DateTime(2026, 11, 4, 19)), DateTime(2026, 11, 5, 18));
      expect(SnoozePresets.nextWeekend(wed), DateTime(2026, 11, 7, 9));
    });

    test('a reminder fires once at its time without hiding anything', () async {
      await seedTwoPeople();
      final msg = (await db.select(db.messages).get()).first;
      final due = DateTime.now().add(const Duration(minutes: 30));
      final id = await db.addReminder(title: 'Reply to Sarah', dueAt: due, messageId: msg.id, rowKey: 'c:sarah@chen.me');
      expect((await db.peopleRows()).length, 2, reason: 'reminders do not hide rows');
      final service = container.read(scheduleServiceProvider);
      expect(await service.tick(DateTime.now()), isEmpty);
      final raised = await service.tick(due.add(const Duration(seconds: 1)));
      expect(raised.single.title, 'Reminder');
      expect(raised.single.body, 'Reply to Sarah');
      expect(raised.single.messageId, msg.id);
      expect((await db.select(db.reminders).get()).single.firedAt, isNotNull);
      expect(await service.tick(due.add(const Duration(hours: 1))), isEmpty, reason: 'fires once');
      await db.setReminderDone(id, true);
      expect(await db.watchReminders().first, isEmpty);
      expect(await db.watchRemindersForMessage(msg.id).first, isEmpty);
    });
  });
}
