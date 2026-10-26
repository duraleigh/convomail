import 'package:convomail/domain/event_extractor.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart' hide Tags;
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/planner_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/planner_service.dart';
import 'package:convomail/sync/schedule_service.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Planner, snooze, and reminders (spec 4.9, 4.10, plan M9): extraction
/// through sync (invitation part and text), de-duplication, the recent
/// pass, snooze hide/resurface with re-sort, reminders firing, to-dos.
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

  group('extraction through sync', () {
    test('an invitation part becomes an invite event when the body is fetched; an update moves it', () async {
      final uid = imap.folder('INBOX').add(
        RemoteMessageHeader(uid: 0, from: const RemoteAddress('calendar-notification@google.com', 'Google Calendar'), to: const [me], subject: 'Invitation: Design review', date: DateTime.now(), signals: const BulkSignals(autoSubmitted: true)),
        body: const RemoteMessageBody(text: 'You have been invited', calendar: 'BEGIN:VCALENDAR\nMETHOD:REQUEST\nBEGIN:VEVENT\nUID:ev-1@cal\nDTSTART:20261105T150000\nDTEND:20261105T160000\nSUMMARY:Design review\nLOCATION:Room 4\nEND:VEVENT\nEND:VCALENDAR'),
      );
      final syncer = await sync();
      final msg = (await db.select(db.messages).get()).single;
      expect((await db.select(db.plannerEvents).get()), isEmpty, reason: 'nothing until the body is read');
      await syncer.fetchBody(msg.id);
      final events = await db.select(db.plannerEvents).get();
      expect(events, hasLength(1));
      expect(events.single.kind, 'invite');
      expect(events.single.title, 'Design review');
      expect(events.single.startAt, DateTime(2026, 11, 5, 15));
      expect(events.single.location, 'Room 4');
      expect(events.single.sourceMessageId, msg.id);
      expect(events.single.uid, 'ev-1@cal');

      // An updated invitation (same UID) moves the event instead of adding one.
      final uid2 = imap.folder('INBOX').add(
        RemoteMessageHeader(uid: 0, from: const RemoteAddress('calendar-notification@google.com'), to: const [me], subject: 'Updated: Design review', date: DateTime.now()),
        body: const RemoteMessageBody(text: 'moved', calendar: 'BEGIN:VEVENT\nUID:ev-1@cal\nDTSTART:20261106T150000\nDTEND:20261106T160000\nSUMMARY:Design review\nEND:VEVENT'),
      );
      expect(uid2, greaterThan(uid));
      await syncer.syncOnce();
      final m2 = (await db.select(db.messages).get()).firstWhere((m) => m.subject.startsWith('Updated'));
      await syncer.fetchBody(m2.id);
      final after = await db.select(db.plannerEvents).get();
      expect(after, hasLength(1));
      expect(after.single.startAt, DateTime(2026, 11, 6, 15));
    });

    test('text extraction runs for People mail only; the recent pass fetches unopened bodies', () async {
      final soon = DateTime.now().add(const Duration(days: 2));
      imap.folder('INBOX').add(
        RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@chen.me', 'Sarah Chen'), to: const [me], subject: 'Catch up', date: DateTime.now()),
        body: RemoteMessageBody(text: 'Hi! Coffee on ${_weekday(soon)} at 10am at Blue Bottle?'),
      );
      imap.folder('INBOX').add(
        RemoteMessageHeader(uid: 0, from: const RemoteAddress('noreply@deals.com', 'Deals'), to: const [me], subject: 'Sale', date: DateTime.now(), signals: const BulkSignals(listUnsubscribe: true)),
        body: RemoteMessageBody(text: 'Flash sale on ${_weekday(soon)} at 10am! Meeting your needs.'),
      );
      await sync(); // syncOnce runs the recent pass, which fetches Sarah's body
      final events = await db.select(db.plannerEvents).get();
      expect(events, hasLength(1), reason: 'the newsletter never contributes text events');
      expect(events.single.kind, 'extracted');
      expect(events.single.title, 'Coffee');
      expect(events.single.startAt!.hour, 10);
      expect(events.single.location, 'Blue Bottle');
      expect(events.single.confidence, greaterThan(0.8));
      final sarah = (await db.select(db.messages).get()).firstWhere((m) => m.fromAddress == 'sarah@chen.me');
      expect(sarah.bodyFetchedAt, isNotNull);
      expect(sarah.extractedAt, isNotNull);
      // Re-running extraction does not duplicate.
      await PlannerService(db).extractFromMessage(sarah.id);
      expect(await db.select(db.plannerEvents).get(), hasLength(1));
    });

    test('dismissed events stay dismissed across re-extraction; confirm turns extracted into manual', () async {
      imap.folder('INBOX').add(
        RemoteMessageHeader(uid: 0, from: const RemoteAddress('tom@andersen.me', 'Tom'), to: const [me], subject: 'Plan', date: DateTime.now()),
        body: const RemoteMessageBody(text: 'Demo tomorrow at 3pm.'),
      );
      await sync();
      final e = (await db.select(db.plannerEvents).get()).single;
      await db.dismissEvent(e.id);
      final tom = (await db.select(db.messages).get()).single;
      await PlannerService(db).extractFromMessage(tom.id);
      final all = await db.select(db.plannerEvents).get();
      expect(all, hasLength(1));
      expect(all.single.dismissed, isTrue);
      expect(await db.watchEventsBetween(DateTime.now().subtract(const Duration(days: 7)), DateTime.now().add(const Duration(days: 7))).first, isEmpty);
      await db.confirmEvent(e.id);
      expect((await db.eventById(e.id))!.kind, 'manual');
    });
  });

  group('events and to-dos', () {
    test('week query includes overlapping timed events and all-day items; to-dos are separate', () async {
      final mon = DateTime(2026, 11, 2);
      final a = await db.addEvent(title: 'Inside', start: mon.add(const Duration(hours: 10)), end: mon.add(const Duration(hours: 11)));
      await db.addEvent(title: 'Before', start: mon.subtract(const Duration(hours: 2)), end: mon.subtract(const Duration(hours: 1)));
      final spanning = await db.addEvent(title: 'Spanning', start: mon.subtract(const Duration(hours: 1)), end: mon.add(const Duration(hours: 1)));
      final allDay = await db.addEvent(title: 'Offsite', start: mon.add(const Duration(days: 3)), allDay: true);
      final todo = await db.addEvent(title: 'Send slides', kind: 'todo', start: mon.add(const Duration(days: 1)));
      final week = await db.watchEventsBetween(mon, mon.add(const Duration(days: 7))).first;
      expect(week.map((e) => e.id).toSet(), {a, spanning, allDay});
      expect((await db.watchTodos().first).single.id, todo);
      await db.setEventDone(todo, true);
      expect((await db.watchTodos().first).single.done, isTrue);
      await db.updateEvent(a, title: 'Renamed', colorKey: 'work');
      expect((await db.eventById(a))!.title, 'Renamed');
      await db.deleteEvent(a);
      expect(await db.eventById(a), isNull);
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

  test('ExtractedEvent from ics via the service handles cancelled invitations by adding nothing', () async {
    final id = await db.into(db.messages).insert(MessagesCompanion.insert(
      accountId: account.id,
      folderId: await db.into(db.folders).insert(FoldersCompanion.insert(accountId: account.id, path: 'INBOX', name: 'INBOX', role: const Value('inbox'))),
      uid: 1,
      subject: const Value('Cancelled'),
      fromAddress: const Value('x@y.com'),
      fromContactKey: const Value('x@y.com'),
      date: Value(DateTime.now()),
      icsText: const Value('BEGIN:VCALENDAR\nMETHOD:CANCEL\nBEGIN:VEVENT\nUID:z\nDTSTART:20261105T150000\nSUMMARY:Gone\nEND:VEVENT\nEND:VCALENDAR'),
    ));
    expect(await PlannerService(db).extractFromMessage(id), 0);
    expect(const EventExtractor().fromICalendar('BEGIN:VEVENT\nDTSTART:20261105T150000\nSUMMARY:Ok\nEND:VEVENT'), hasLength(1));
  });
}

String _weekday(DateTime d) => const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d.weekday - 1];
