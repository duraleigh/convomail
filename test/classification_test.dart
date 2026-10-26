import 'package:convomail/app/destinations.dart';
import 'package:convomail/domain/classifier.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/classification_queries.dart';
import 'package:convomail/store/database.dart' hide ClassificationRule;
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/classification_service.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Classification wired into sync and the UI (spec 4.11, plan M8): senders
/// are classified as headers land, overrides persist across re-syncs, the
/// signal backfill covers pre-M8 mail, rules apply retroactively, rows
/// split into the People and Feeds tabs, and corrections propose a rule.
void main() {
  const me = RemoteAddress('me@example.com');
  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;

  Future<void> seed() async {
    final inbox = imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    var t = DateTime.now().subtract(const Duration(days: 2));
    DateTime next() => t = t.add(const Duration(hours: 1));
    // Newsletter with list headers.
    for (var i = 0; i < 3; i++) {
      inbox.add(RemoteMessageHeader(
        uid: 0,
        from: const RemoteAddress('hello@dailybrief.com', 'The Daily Brief'),
        to: const [me],
        subject: 'Daily Brief #${100 + i}',
        date: next(),
        flags: const MessageFlagsState(seen: false),
        signals: const BulkSignals(listUnsubscribe: true, listId: true, listIdValue: 'brief.dailybrief.com'),
      ));
    }
    // Bank noreply: statement + verification code.
    inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('noreply@bank.com', 'First Bank'), to: const [me], subject: 'Your statement is ready', date: next()));
    inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('noreply@bank.com', 'First Bank'), to: const [me], subject: 'Your verification code is 482913', date: next(), flags: const MessageFlagsState(seen: false)));
    // A person.
    inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah Chen'), to: const [me], subject: 'Lunch?', date: next(), flags: const MessageFlagsState(seen: false)));
    // Support agent at a feeds sender replying to my mail (personal exception).
    imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('help@shop.com')], subject: 'Order problem', messageId: '<mine-1@example.com>', date: next()));
    inbox.add(RemoteMessageHeader(
      uid: 0,
      from: const RemoteAddress('noreply@shop.com', 'Shop Orders'),
      to: const [me],
      subject: 'Re: Order problem',
      inReplyTo: '<mine-1@example.com>',
      date: next(),
      flags: const MessageFlagsState(seen: false),
    ));
    inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('noreply@shop.com', 'Shop Orders'), to: const [me], subject: 'Your order has shipped', date: next()));
  }

  Future<AccountSyncer> sync() async {
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
    return syncer;
  }

  Future<Contact> contact(String key) => (db.select(db.contacts)..where((c) => c.key.equals(key))).getSingle();

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    account = await insertTestAccount(db);
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), isDefault: const Value(true)));
    await seed();
  });

  tearDown(() => db.close());

  group('sync', () {
    test('senders are classified as headers land; categories inferred; people stay people', () async {
      await sync();
      final brief = await contact('hello@dailybrief.com');
      expect(brief.classification, 'feeds');
      expect(brief.feedsCategory, 'Newsletter');
      expect(brief.classReasons, contains('Bulk-mail headers'));
      final bank = await contact('noreply@bank.com');
      expect(bank.classification, 'feeds');
      expect(bank.feedsCategory, 'Notification');
      expect((await contact('sarah@x.com')).classification, 'people');
      // Message-level category differs from the sender default for the statement.
      final msgs = await db.messagesFromSender('noreply@bank.com');
      final statement = msgs.firstWhere((m) => m.subject.contains('statement'));
      expect(statement.feedsCategory, 'Receipt');
      expect(msgs.firstWhere((m) => m.subject.contains('verification')).feedsCategory, isNull, reason: 'same as sender default');
      expect((await db.select(db.classificationEvents).get()).where((e) => e.source == 'auto'), isNotEmpty);
    });

    test('a reply to my mail from a Feeds sender is a People message; the sender stays in Feeds', () async {
      await sync();
      expect((await contact('noreply@shop.com')).classification, 'feeds');
      final msgs = await db.messagesFromSender('noreply@shop.com');
      expect(msgs.firstWhere((m) => m.subject.startsWith('Re:')).classification, 'people');
      expect(msgs.firstWhere((m) => m.subject.startsWith('Your order')).classification, 'feeds');
      // The row shows in both tabs: People for the reply, Feeds for the receipt.
      final people = await db.peopleRows();
      final feeds = await db.peopleRows(tab: InboxTab.feeds);
      expect(people.where((r) => r.rowKey == 'c:noreply@shop.com').single.total, 1);
      expect(feeds.where((r) => r.rowKey == 'c:noreply@shop.com').single.total, 1);
    });

    test('People and Feeds tabs: rows, unread per bucket, sender-default category on the row', () async {
      await sync();
      final people = await db.peopleRows();
      final feeds = await db.peopleRows(tab: InboxTab.feeds);
      expect(people.map((r) => r.rowKey), isNot(contains('c:hello@dailybrief.com')));
      expect(people.map((r) => r.rowKey), contains('c:sarah@x.com'));
      final brief = feeds.firstWhere((r) => r.rowKey == 'c:hello@dailybrief.com');
      expect(brief.isFeeds, isTrue);
      expect(brief.category, 'Newsletter');
      expect(brief.unread, 3);
      expect(feeds.map((r) => r.rowKey), isNot(contains('c:sarah@x.com')));
    });

    test('a manual move is permanent across re-syncs and new mail; clearing it lets rules decide again', () async {
      await sync();
      final service = ClassificationService(db);
      await service.moveSender('hello@dailybrief.com', Bucket.people);
      expect((await contact('hello@dailybrief.com')).classificationSource, 'override');
      expect((await db.peopleRows()).map((r) => r.rowKey), contains('c:hello@dailybrief.com'));

      imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('hello@dailybrief.com'), to: const [me], subject: 'Daily Brief #200', date: DateTime.now(), signals: const BulkSignals(listUnsubscribe: true)));
      await sync();
      expect((await contact('hello@dailybrief.com')).classification, 'people');
      expect((await db.messagesFromSender('hello@dailybrief.com')).every((m) => m.classification == 'people'), isTrue);

      await service.moveSender('hello@dailybrief.com', null);
      expect((await contact('hello@dailybrief.com')).classification, 'feeds');
      expect((await db.select(db.classificationEvents).get()).where((e) => e.source == 'override'), hasLength(2));
    });

    test('signals backfill: pre-M8 messages (no signals stored) get them fetched and their senders classified', () async {
      await sync();
      // Simulate rows synced before M8: wipe signals and classification.
      await db.customStatement("UPDATE messages SET bulk_signals = NULL, classification = 'people'");
      await db.customStatement("UPDATE contacts SET classification = 'people', class_reasons = '', feeds_category = NULL");
      expect((await contact('hello@dailybrief.com')).classification, 'people');
      await sync();
      expect(imap.log.where((l) => l.startsWith('signals')), isNotEmpty, reason: 'backfill fetched list headers');
      expect((await contact('hello@dailybrief.com')).classification, 'feeds');
      expect((await db.select(db.messages).get()).every((m) => m.bulkSignals != null), isTrue);
    });

    test('rules: a domain rule to People applies retroactively; a subject rule tags OTPs; deleting re-evaluates', () async {
      await sync();
      final service = ClassificationService(db);
      await service.acceptRule(const ClassificationRule(field: 'domain', pattern: 'bank.com', bucket: Bucket.people));
      expect((await contact('noreply@bank.com')).classification, 'people');
      expect((await contact('noreply@bank.com')).classificationSource, 'rule');

      await db.addCategory('OTP');
      await service.acceptRule(const ClassificationRule(field: 'subject', pattern: 'verification code|passcode', category: 'OTP'));
      // Bank is People now, so tag the newsletter-free shop sender instead: re-point the bank to Feeds first.
      await service.deleteRule((await db.loadRules()).first.id!);
      expect((await contact('noreply@bank.com')).classification, 'feeds');
      final otp = (await db.messagesFromSender('noreply@bank.com')).firstWhere((m) => m.subject.contains('verification'));
      expect(otp.feedsCategory, 'OTP');
    });

    test('counts toward unread and sender category are per-sender settings', () async {
      await sync();
      final service = ClassificationService(db);
      await service.setCountsTowardUnread('hello@dailybrief.com', true);
      await service.setSenderCategory('hello@dailybrief.com', 'Promotion');
      final row = (await db.peopleRows(tab: InboxTab.feeds)).firstWhere((r) => r.rowKey == 'c:hello@dailybrief.com');
      expect(row.countsTowardUnread, isTrue);
      expect(row.category, 'Promotion');
    });

    test('categories: rename propagates, delete clears', () async {
      await sync();
      final cats = await db.watchCategories().first;
      final notification = cats.firstWhere((c) => c.name == 'Notification');
      await db.renameCategory(notification.id, 'Alerts');
      expect((await contact('noreply@bank.com')).feedsCategory, 'Alerts');
      await db.deleteCategory(notification.id);
      expect((await contact('noreply@bank.com')).feedsCategory, isNull);
      expect((await db.categoryNames()), isNot(contains('Alerts')));
    });
  });

  group('ui', () {
    Widget app() => ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
            databaseProvider.overrideWith((ref) => db),
            credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
            transportFactoryProvider.overrideWith((ref) => () => imap),
            htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
          ],
          child: const ConvoMailApp(startSync: false),
        );

    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1500, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      final syncer = await sync();
      container.read(syncControllerProvider).adoptForTest(account.id, syncer);
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> teardown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('People tab hides feeds senders and shows the filed banner; Feeds tab shows pills', (tester) async {
      final container = await pumpApp(tester);
      expect(find.text('Sarah Chen'), findsOneWidget);
      expect(find.text('The Daily Brief'), findsNothing);
      expect(find.byKey(const ValueKey('feeds-banner')), findsOneWidget);
      expect(find.textContaining('filed to Feeds this week'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('feeds-banner')));
      await tester.pumpAndSettle();
      expect(container.read(inboxModeProvider), InboxMode.feeds);
      expect(find.text('The Daily Brief'), findsOneWidget);
      expect(find.byKey(const ValueKey('category-pill-c:hello@dailybrief.com')), findsOneWidget);
      expect(find.text('Newsletter'), findsOneWidget);
      expect(find.text('Sarah Chen'), findsNothing);
      await teardown(tester);
    });

    testWidgets('right-click → Move to People is permanent; Counts toward unread shows the bell', (tester) async {
      final container = await pumpApp(tester);
      container.read(inboxModeProvider.notifier).select(InboxMode.feeds);
      await tester.pumpAndSettle();
      await tester.tap(find.text('The Daily Brief'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Counts toward unread'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Counts toward unread'), findsOneWidget);

      await tester.tap(find.text('The Daily Brief'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to People'));
      await tester.pumpAndSettle();
      expect((await contact('hello@dailybrief.com')).classificationSource, 'override');
      expect(find.textContaining('moved to People'), findsOneWidget);
      container.read(inboxModeProvider.notifier).select(InboxMode.people);
      await tester.pumpAndSettle();
      expect(find.text('The Daily Brief'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('message overflow → "This is a feed" proposes a rule; Accept creates it and moves the sender', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Sarah Chen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunch?').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('This is a feed'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('proposal-text')), findsOneWidget);
      expect(find.text('Mail from sarah@x.com → Feeds'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('proposal-accept')));
      await tester.pumpAndSettle();
      expect((await db.loadRules()).single.describe(), 'Mail from sarah@x.com → Feeds');
      expect((await contact('sarah@x.com')).classification, 'feeds');
      expect((await contact('sarah@x.com')).classificationSource, 'rule');
      await teardown(tester);
    });

    testWidgets('"Just this once" changes only the message and writes no rule', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Sarah Chen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunch?').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('This is a feed'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('proposal-once')));
      await tester.pumpAndSettle();
      expect(await db.loadRules(), isEmpty);
      expect((await contact('sarah@x.com')).classification, 'people');
      expect((await db.messagesFromSender('sarah@x.com')).single.classification, 'feeds');
      await teardown(tester);
    });
  });
}
