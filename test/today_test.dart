import 'package:convomail/app/conversation_state.dart';
import 'package:convomail/app/destinations.dart';
import 'package:convomail/domain/classifier.dart';
import 'package:convomail/domain/piles.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart' hide ClassificationRule;
import 'package:convomail/store/done_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/planner_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/screens/chats/people_list_pane.dart';
import 'package:convomail/ui/screens/chats/thread_actions.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:convomail/ui/shell/split_pane.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Step 1 of the Précis plan: the two piles for mail that is not from a
/// person, Done, and the Today page (without the assistant: nothing on it
/// is guessed).
void main() {
  group('piles', () {
    test('the user\'s own choice always wins', () {
      expect(pileFor(chosen: 'noise', category: FeedsCategories.receipt, total: 10, unread: 0), FeedsPile.noise);
      expect(pileFor(chosen: 'feed', category: FeedsCategories.promotion, total: 10, unread: 10), FeedsPile.feed);
    });

    test('promotions and social notices are Noise', () {
      expect(pileFor(category: FeedsCategories.promotion, total: 4, unread: 0), FeedsPile.noise, reason: 'even when opened');
      expect(pileFor(category: FeedsCategories.social, total: 4, unread: 4), FeedsPile.noise);
    });

    test('a newsletter is Feed only when it gets opened', () {
      expect(pileFor(category: FeedsCategories.newsletter, total: 10, unread: 10), FeedsPile.noise);
      expect(pileFor(category: FeedsCategories.newsletter, total: 10, unread: 8), FeedsPile.noise, reason: 'two in ten is under the line');
      expect(pileFor(category: FeedsCategories.newsletter, total: 10, unread: 7), FeedsPile.feed, reason: 'three in ten is on it');
      expect(pileFor(category: FeedsCategories.newsletter, total: 0, unread: 0), FeedsPile.noise, reason: 'nothing to go on');
    });

    test('it goes by what the sender mostly sends, not by one label on the sender', () {
      MailCount n(int total, [int unread = 0]) => (total: total, unread: unread);
      // Labeled a notification sender, but nearly all of it is promotions.
      expect(pileFor(category: FeedsCategories.notification, total: 10, unread: 0, mail: {FeedsCategories.promotion: n(8), FeedsCategories.receipt: n(2)}), FeedsPile.noise);
      // A shop: mostly receipts and deliveries, a few promotions.
      expect(pileFor(category: null, total: 10, unread: 0, mail: {FeedsCategories.receipt: n(5), 'Delivery': n(3), FeedsCategories.promotion: n(2)}), FeedsPile.feed);
      // Exactly half is not "mostly".
      expect(pileFor(category: null, total: 4, unread: 0, mail: {FeedsCategories.promotion: n(2), FeedsCategories.receipt: n(2)}), FeedsPile.feed);
      // Mostly newsletters: only those emails' opens count.
      expect(pileFor(category: null, total: 10, unread: 9, mail: {FeedsCategories.newsletter: n(8, 8), FeedsCategories.receipt: n(2, 1)}), FeedsPile.noise);
      expect(pileFor(category: null, total: 10, unread: 5, mail: {FeedsCategories.newsletter: n(8, 5), FeedsCategories.receipt: n(2, 0)}), FeedsPile.feed);
      // The user's choice still wins.
      expect(pileFor(chosen: 'feed', category: null, total: 10, unread: 10, mail: {FeedsCategories.promotion: n(10, 10)}), FeedsPile.feed);
    });

    test('everything else is Feed', () {
      for (final c in [FeedsCategories.receipt, FeedsCategories.notification, 'Delivery', 'Travel', 'OTP', 'A tag of my own', null]) {
        expect(pileFor(category: c, total: 5, unread: 5), FeedsPile.feed, reason: '$c');
      }
    });
  });

  const me = RemoteAddress('me@example.com');
  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;

  DateTime ago({int days = 0, int hours = 0}) => DateTime.now().subtract(Duration(days: days, hours: hours));

  void got(String address, String name, String subject, DateTime at, {String? id, String? replyTo}) {
    imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: RemoteAddress(address, name), to: const [me], subject: subject, messageId: id, inReplyTo: replyTo, date: at));
  }

  void sent(String to, String subject, String words, DateTime at, {String? id}) {
    imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: [RemoteAddress(to)], subject: subject, messageId: id, date: at, snippet: words));
  }

  Future<AccountSyncer> sync() async {
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
    return syncer;
  }

  Future<Message> mine(String subject) async => (await db.select(db.messages).get()).firstWhere((m) => m.isFromMe && m.subject == subject);

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    account = await insertTestAccount(db);
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), isDefault: const Value(true)));
    imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
  });

  tearDown(() => db.close());

  group('waiting on', () {
    test('I asked a person something, three or more days ago, and nothing came back', () async {
      got('sarah@x.com', 'Sarah Chen', 'Hello', ago(days: 12));
      sent('sarah@x.com', 'The contract', 'Can you send the signed copy?', ago(days: 5));
      await sync();
      final w = (await db.watchWaitingOn().first).single;
      expect(w.name, 'Sarah Chen');
      expect(w.rowKey, 'c:sarah@x.com');
      expect(w.message.subject, 'The contract');
    });

    test('not yet three days, no question asked, already answered, or too long ago: not listed', () async {
      sent('tom@x.com', 'Soon', 'Are we still on for Friday?', ago(days: 1));
      sent('ann@x.com', 'Notes', 'Here are the notes from today.', ago(days: 5));
      sent('bob@x.com', 'Price', 'What is the price?', ago(days: 6), id: '<q-bob@example.com>');
      got('bob@x.com', 'Bob', 'Re: Price', ago(days: 5), replyTo: '<q-bob@example.com>');
      sent('old@x.com', 'Long ago', 'Did you get this?', ago(days: 40));
      await sync();
      expect(await db.watchWaitingOn().first, isEmpty);
    });

    test('a question that is only in the mail quoted below my words does not count', () async {
      sent('dee@x.com', 'Re: Lunch', '', ago(days: 5));
      sent('eve@x.com', 'Re: Dinner', '', ago(days: 5));
      await sync();
      Future<void> body(String subject, String text) async {
        final id = (await mine(subject)).id;
        await (db.update(db.messages)..where((m) => m.id.equals(id))).write(MessagesCompanion(bodyText: Value(text)));
      }

      await body('Re: Lunch', 'Sounds good to me.\n\nOn Mon, Nov 2, 2026 at 9:00 AM Dee <dee@x.com> wrote:\n> Are you free on Friday?\n');
      await body('Re: Dinner', 'Sounds good. What time?\n\nOn Mon, Nov 2, 2026 at 9:00 AM Eve <eve@x.com> wrote:\n> Dinner on Friday.\n');
      final names = [for (final w in await db.watchWaitingOn().first) w.message.subject];
      expect(names, ['Re: Dinner']);
    });

    test('Done takes it off the list and puts it under Done for today; Not done brings it back', () async {
      sent('sarah@x.com', 'The contract', 'Can you send the signed copy?', ago(days: 5));
      await sync();
      final m = await mine('The contract');
      expect(await db.watchDoneToday().first, isEmpty);

      await db.setMessagesDone([m.id], true);
      expect(await db.watchWaitingOn().first, isEmpty);
      final done = (await db.watchDoneToday().first).single;
      expect(done.title, 'The contract');
      expect(done.rowKey, 'c:sarah@x.com');
      expect(await db.watchDoneToday(day: DateTime.now().add(const Duration(days: 1))).first, isEmpty, reason: 'tomorrow starts clean');

      await db.setMessagesDone([m.id], false);
      expect(await db.watchWaitingOn().first, hasLength(1));
      expect(await db.watchDoneToday().first, isEmpty);
    });

    test('my own recent emails are read in the background, so none is skipped for want of its words', () async {
      final asked = imap.folder('Sent').add(
        RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('sarah@x.com')], subject: 'The contract', date: ago(days: 5)),
        body: const RemoteMessageBody(text: 'Hi Sarah,\n\nCan you send the signed copy?\n\nClay'),
      );
      imap.folder('Sent').add(
        RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('ann@x.com')], subject: 'Notes', date: ago(days: 4)),
        body: const RemoteMessageBody(text: 'Here are the notes.'),
      );
      imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('old@x.com')], subject: 'Long ago', date: ago(days: 45)), body: const RemoteMessageBody(text: 'Did you get this?'));
      expect(asked, isPositive);
      final syncer = await sync();
      expect(await db.watchWaitingOn().first, isEmpty, reason: 'nothing can be said before the words are here');
      expect([for (final m in await db.sentWithoutWords(account.id)) m.subject], ['Notes', 'The contract'], reason: 'the last 30 days only, newest first');

      expect(await syncer.readSentForWaiting(), 2);
      expect([for (final w in await db.watchWaitingOn().first) w.message.subject], ['The contract']);
      expect(await syncer.readSentForWaiting(), 0, reason: 'nothing left to read');
      expect((await mine('Long ago')).bodyFetchedAt, isNull, reason: 'too old to matter is left alone');
    });

    test('a sent email that cannot be read is tried once, not over and over', () async {
      imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('sarah@x.com')], subject: 'The contract', date: ago(days: 5)));
      final syncer = await sync();
      imap.failFetchBody = 1;
      expect(await syncer.readSentForWaiting(), 0);
      expect(imap.failFetchBody, 0);
      expect(await syncer.readSentForWaiting(), 0, reason: 'not tried again in this run');
      expect((await mine('The contract')).bodyFetchedAt, isNull);
    });

    test('only one account\'s mail when one account is picked', () async {
      sent('sarah@x.com', 'The contract', 'Can you send the signed copy?', ago(days: 5));
      await sync();
      expect(await db.watchWaitingOn(accountId: account.id).first, hasLength(1));
      expect(await db.watchWaitingOn(accountId: account.id + 99).first, isEmpty);
    });
  });

  test('Later lists what was put off, soonest first, by name; bringing one back removes it', () async {
    got('sarah@x.com', 'Sarah Chen', 'Hello', ago(days: 2));
    got('tom@x.com', 'Tom Andersen', 'Hi', ago(days: 1));
    await sync();
    await db.snoozeRow('c:sarah@x.com', DateTime.now().add(const Duration(days: 3)));
    await db.snoozeRow('c:tom@x.com', DateTime.now().add(const Duration(hours: 4)));
    final later = await db.watchLaterRows().first;
    expect([for (final r in later) r.name], ['Tom Andersen', 'Sarah Chen']);
    await db.snoozeRow('c:tom@x.com', null);
    expect([for (final r in await db.watchLaterRows().first) r.rowKey], ['c:sarah@x.com']);
  });

  test('with nothing else asked for, the app opens on Today', () {
    expect(StartupArgs.parse(const []).opensOn, Destination.today);
    expect(StartupArgs.parse(const ['--minimized']).opensOn, Destination.today);
    expect(StartupArgs.parse(const ['--destination=noise']).opensOn, Destination.noise);
    expect(StartupArgs.parse(const ['mailto:sarah@x.com']).opensOn, Destination.chats, reason: 'writing an email happens in Chats');
  });

  group('screens', () {
    late InMemorySettingsStore settings;

    Widget app({Destination opensOn = Destination.today}) => ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWith((ref) => settings),
            databaseProvider.overrideWith((ref) => db),
            credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
            transportFactoryProvider.overrideWith((ref) => () => imap),
            htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
            destinationProvider.overrideWith(() => DestinationNotifier(initial: opensOn)),
          ],
          child: const PrecisApp(startSync: false),
        );

    Future<ProviderContainer> pumpApp(WidgetTester tester, {Destination opensOn = Destination.today}) async {
      tester.view.physicalSize = const Size(1500, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await sync();
      await tester.pumpWidget(app(opensOn: opensOn));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    }

    Future<void> teardown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    }

    setUp(() => settings = InMemorySettingsStore());

    testWidgets('Today greets, shows its six sections, and says plainly that Needs you waits for the assistant', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const ValueKey('today-date')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('today-greeting'))).data, startsWith('Good '));
      for (final id in ['needs-you', 'waiting-on', 'schedule', 'fyi', 'later', 'done']) {
        expect(find.byKey(ValueKey('today-$id')), findsOneWidget, reason: id);
      }
      expect(find.textContaining('The assistant is not connected yet'), findsOneWidget);
      expect(find.textContaining('Nobody. Everyone you asked has answered'), findsOneWidget);
      expect(find.text('Nothing marked done yet today.'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('a Waiting on line opens the email beside the page; Done moves it to Done; leaving Today closes the email', (tester) async {
      got('sarah@x.com', 'Sarah Chen', 'Hello', ago(days: 12));
      sent('sarah@x.com', 'The contract', 'Can you send the signed copy?', ago(days: 5));
      final container = await pumpApp(tester);
      final m = await mine('The contract');
      expect(find.byKey(ValueKey('waiting-${m.id}')), findsOneWidget);
      expect(find.textContaining('has not answered', findRichText: true), findsOneWidget);
      expect(find.textContaining('The contract · you wrote 5 days ago'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('waiting-${m.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-email')), findsOneWidget);
      expect(container.read(destinationProvider), Destination.today, reason: 'the page stays');

      container.read(destinationProvider.notifier).select(Destination.chats);
      await tester.pumpAndSettle();
      expect(container.read(openThreadProvider), isNull, reason: 'an email opened on Today does not follow to Chats');

      container.read(destinationProvider.notifier).select(Destination.today);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-email')), findsNothing);
      await tester.tap(find.byKey(ValueKey('waiting-done-${m.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('waiting-${m.id}')), findsNothing);
      expect((await mine('The contract')).doneAt, isNotNull);
      expect(find.descendant(of: find.byKey(const ValueKey('today-done')), matching: find.textContaining('The contract')), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('Later on Today lists what was put off; Bring back now returns it to its list', (tester) async {
      got('sarah@x.com', 'Sarah Chen', 'Hello', ago(days: 2));
      await pumpApp(tester);
      await db.snoozeRow('c:sarah@x.com', DateTime.now().add(const Duration(days: 2)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('later-row-c:sarah@x.com')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('later-back-c:sarah@x.com')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('later-row-c:sarah@x.com')), findsNothing);
      await teardown(tester);
    });

    testWidgets('Focus is empty and says why; nothing is guessed', (tester) async {
      got('sarah@x.com', 'Sarah Chen', 'Can you call me today?', ago(hours: 2));
      await pumpApp(tester, opensOn: Destination.focus);
      expect(find.byKey(const ValueKey('focus-empty')), findsOneWidget);
      expect(find.textContaining('The assistant is not connected yet'), findsOneWidget);
      expect(find.text('Sarah Chen'), findsNothing);
      await teardown(tester);
    });

    testWidgets('the thread menu marks a thread done and not done', (tester) async {
      got('sarah@x.com', 'Sarah Chen', 'Hello', ago(days: 2), id: '<h1@x.com>');
      await sync();
      Future<List<Message>> thread() async => (await db.select(db.messages).get()).where((m) => m.subject == 'Hello').toList();
      Future<void> pump() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [databaseProvider.overrideWith((ref) => db)],
          child: MaterialApp(home: Scaffold(body: Center(child: ThreadMenuButton(threadKey: 't1', messages: await tester.runAsync(thread) ?? const [])))),
        ));
        await tester.pumpAndSettle();
      }

      await pump();
      await tester.tap(find.byTooltip('Thread actions'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('thread-done-t1')));
      await tester.pumpAndSettle();
      expect((await thread()).single.doneAt, isNotNull);

      await pump();
      await tester.tap(find.byTooltip('Thread actions'));
      await tester.pumpAndSettle();
      expect(find.text('Not done'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('thread-done-t1')));
      await tester.pumpAndSettle();
      expect((await thread()).single.doneAt, isNull);
      await teardown(tester);
    });

    testWidgets('the list width you drag to is kept, and used the next time', (tester) async {
      got('sarah@x.com', 'Sarah Chen', 'Hello', ago(days: 2));
      await pumpApp(tester, opensOn: Destination.chats);
      double width() => tester.getSize(find.byType(PeopleListPane)).width;
      expect(width(), 340);

      final handle = find.descendant(of: find.byType(SplitPane), matching: find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeLeftRight));
      await tester.drag(handle, const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(width(), greaterThan(360));
      final kept = width();
      expect(settings.values['layout.middlePaneWidth'], kept.toStringAsFixed(0));

      await teardown(tester);
      await tester.pumpWidget(app(opensOn: Destination.chats));
      await tester.pumpAndSettle();
      expect(width(), double.parse(settings.values['layout.middlePaneWidth']!), reason: 'a restart keeps it');
      await teardown(tester);
    });
  });
}
