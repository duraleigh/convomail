import 'package:convomail/app/compose_state.dart';
import 'package:convomail/app/destinations.dart';
import 'package:convomail/app/mail_state.dart';
import 'package:convomail/domain/classifier.dart';
import 'package:convomail/domain/email_pile.dart';
import 'package:convomail/domain/piles.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/classification_queries.dart';
import 'package:convomail/store/database.dart' hide ClassificationRule;
import 'package:convomail/store/done_queries.dart';
import 'package:convomail/store/helper_queries.dart';
import 'package:convomail/store/mail_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/compose/compose_form.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/screens/mail/mail_widgets.dart';
import 'package:convomail/ui/screens/noise_screen.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:convomail/ui/widgets/reading_line.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Step 3 of the Précis plan on this PC: Feed or Noise decided for each
/// email, the assistant's readings, and the Focus, Feed and Noise lists.
void main() {
  group('Feed or Noise for one email', () {
    test('your word, then the kind of mail, then the helper, then the tag alone', () {
      expect(emailPile(fix: 'noise', senderChosen: 'feed', tag: FeedsCategories.receipt, helper: 'feed'), (pile: FeedsPile.noise, by: PileBy.you));
      expect(emailPile(senderChosen: 'feed', tag: FeedsCategories.promotion, gmailTab: 'promotions', helper: 'noise'), (pile: FeedsPile.feed, by: PileBy.sender));
      expect(emailPile(tag: FeedsCategories.receipt, gmailTab: 'promotions', helper: 'noise'), (pile: FeedsPile.feed, by: PileBy.kind));
      expect(emailPile(tag: FeedsCategories.promotion, helper: 'feed'), (pile: FeedsPile.noise, by: PileBy.kind));
      expect(emailPile(tag: FeedsCategories.newsletter, gmailTab: 'social', helper: 'feed'), (pile: FeedsPile.noise, by: PileBy.kind));
      expect(emailPile(tag: FeedsCategories.newsletter, gmailTab: 'updates', helper: 'noise', readByAssistant: true), (pile: FeedsPile.noise, by: PileBy.assistant));
      expect(emailPile(tag: FeedsCategories.notification, helper: 'feed', readByAssistant: true), (pile: FeedsPile.feed, by: PileBy.assistant));
      expect(emailPile(tag: FeedsCategories.newsletter, helper: 'feed'), (pile: FeedsPile.feed, by: PileBy.usual));
      // With no helper at all: a newsletter is Noise, the rest Feed.
      expect(emailPile(tag: FeedsCategories.newsletter), (pile: FeedsPile.noise, by: PileBy.usual));
      expect(emailPile(tag: FeedsCategories.notification), (pile: FeedsPile.feed, by: PileBy.usual));
      expect(emailPile(), (pile: FeedsPile.feed, by: PileBy.usual));
    });

    test('the "?" gives a plain sentence for each way an email is placed', () {
      expect(pileReason(FeedsPile.noise, PileBy.kind, gmailTab: 'promotions'), contains('Gmail files it under Promotions'));
      expect(pileReason(FeedsPile.feed, PileBy.kind, tag: FeedsCategories.receipt), contains('receipt'));
      expect(pileReason(FeedsPile.noise, PileBy.you), 'You moved this email to Noise.');
      expect(pileReason(FeedsPile.feed, PileBy.sender), contains('everything from this sender'));
    });
  });

  group('a "by" time', () {
    test('reads the way a person would say it', () {
      final now = DateTime(2026, 11, 11, 9);
      expect(dueLabel(DateTime(2026, 11, 11, 15), now: now), '3:00 PM');
      expect(dueLabel(DateTime(2026, 11, 12, 9, 30), now: now), 'tomorrow 9:30 AM');
      expect(dueLabel(DateTime(2026, 11, 13, 17), now: now), 'Fri 5:00 PM');
      expect(dueLabel(DateTime(2027, 3, 14, 17), now: now), 'Mar 14');
    });
  });

  const me = RemoteAddress('me@example.com');
  const brief = BulkSignals(listUnsubscribe: true, listId: true, listIdValue: 'brief.dailybrief.com');
  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;

  DateTime ago({int days = 0, int hours = 0}) => DateTime.now().subtract(Duration(days: days, hours: hours));

  String got(String address, String name, String subject, {required String id, BulkSignals signals = BulkSignals.none, DateTime? at}) {
    imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: RemoteAddress(address, name), to: const [me], subject: subject, messageId: id, date: at ?? ago(hours: 3), signals: signals));
    return id;
  }

  Future<void> sync() async {
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
  }

  Future<Message> message(String messageId) async => (await (db.select(db.messages)..where((m) => m.messageId.equals(messageId))).get()).first;

  /// What the helper would send down: an email's place, and its reading.
  Future<void> helperSays(String kind, String messageId, Map<String, Object?> data) => db.applyingFromHelper(() => db.applyHelperItem(kind, messageId, data, deleted: false));

  Future<void> reading(String messageId, String line, {bool focus = false, String ask = '', DateTime? due, List<String> why = const [], bool answered = false}) =>
      helperSays('read', messageId, {'line': line, 'focus': focus, 'ask': ask, 'due': due == null ? null : due.millisecondsSinceEpoch ~/ 1000, 'why': why, 'answered': answered, 'at': 1});

  /// This PC follows a helper whose assistant is on.
  Future<void> assistantOn() async {
    await db.setHelperConnected(true);
    await db.putSetting('helper.assistantOn', '1');
  }

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    account = await insertTestAccount(db);
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), isDefault: const Value(true)));
    imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    // A person, a newsletter that sends two kinds of email, a bank, a shop that advertises.
    imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('renee@booking.example')], subject: 'Spring dates', messageId: '<mine@example.com>', date: ago(days: 3)));
    got('renee@booking.example', 'Renee Calloway', 'Re: Spring dates', id: '<renee@x>', at: ago(hours: 2));
    got('news@pollstar.example', 'Pollstar Daily', 'Daily #1', id: '<daily-1@x>', signals: brief, at: ago(hours: 4));
    got('news@pollstar.example', 'Pollstar Daily', 'Your subscription renews Friday', id: '<daily-2@x>', signals: brief, at: ago(days: 1, hours: 1));
    got('alerts@bank.example', 'First Citizens Bank', 'Your automatic payment did not go through', id: '<bank@x>', at: ago(days: 2));
    got('deals@flash.example', 'FlashDeals', '70% off, today only', id: '<flash-1@x>', signals: brief, at: ago(hours: 5));
    got('deals@flash.example', 'FlashDeals', 'Last chance: free shipping', id: '<flash-2@x>', signals: brief, at: ago(days: 1));
    await sync();
    // Gmail files the shop's mail under Promotions.
    await db.customStatement("UPDATE messages SET provider_category = 'promotions' WHERE from_contact_key = 'deals@flash.example'");
  });

  tearDown(() => db.close());

  Future<Map<String, MailItem>> other() async => {for (final i in await db.watchOtherMail().first) i.messageId!: i};

  group('the lists', () {
    test('one sender, two emails, two places: Feed or Noise is settled for each email', () async {
      await assistantOn();
      await helperSays('sort', '<daily-1@x>', {'cls': 'feeds', 'cat': 'Newsletter', 'pile': 'noise'});
      await helperSays('sort', '<daily-2@x>', {'cls': 'feeds', 'cat': 'Newsletter', 'pile': 'feed'});
      await reading('<daily-1@x>', 'Five stories, one about spring theater tours.', why: ['It is a general newsletter sent to a list.']);
      await reading('<daily-2@x>', 'Your subscription renews Friday.', why: ['It is about your own account.']);
      final mail = await other();
      expect(mail['<daily-1@x>']!.pile, FeedsPile.noise);
      expect(mail['<daily-1@x>']!.by, PileBy.assistant);
      expect(mail['<daily-2@x>']!.pile, FeedsPile.feed);
      expect(mail['<daily-2@x>']!.line, 'Your subscription renews Friday.', reason: 'the row says what the email is');
      // Mail Gmail files under Promotions is Noise by a fixed rule, read or not.
      expect(mail['<flash-1@x>']!.pile, FeedsPile.noise);
      expect(mail['<flash-1@x>']!.by, PileBy.kind);
      expect(mail['<flash-1@x>']!.line, '70% off, today only', reason: 'never read by the assistant: the subject stands in');
      // Mail from a person is not in these lists at all.
      expect(mail.containsKey('<renee@x>'), isFalse);
    });

    test('your own move wins, for one email and for a whole sender, and is told to the helper', () async {
      await assistantOn();
      await helperSays('sort', '<daily-1@x>', {'cls': 'feeds', 'cat': 'Newsletter', 'pile': 'noise'});
      final one = await message('<daily-1@x>');
      await db.setEmailPile(one.id, FeedsPile.feed);
      expect((await other())['<daily-1@x>']!.pile, FeedsPile.feed);
      expect((await other())['<daily-1@x>']!.by, PileBy.you);
      final noted = await db.customSelect("SELECT data FROM helper_outbox WHERE kind = 'msgfix' AND k = '<daily-1@x>'").get();
      expect(noted.single.read<String>('data'), contains('"pile":"feed"'));
      // The whole sender to Noise: everything follows, except the one moved by hand.
      await db.setSenderPile('news@pollstar.example', FeedsPile.noise);
      final mail = await other();
      expect(mail['<daily-2@x>']!.pile, FeedsPile.noise);
      expect(mail['<daily-2@x>']!.by, PileBy.sender);
      expect(mail['<daily-1@x>']!.pile, FeedsPile.feed);
    });

    test('Focus: what the assistant says needs you, until you answer, mark it done, or say otherwise', () async {
      await assistantOn();
      final due = DateTime.now().add(const Duration(hours: 4));
      await reading('<renee@x>', 'Renee needs your yes or no on Charlotte, March 14.', focus: true, ask: 'Say yes or no to Charlotte, March 14.', due: due, why: ['It asks you for a yes or no.']);
      await reading('<bank@x>', 'The \$240 insurance payment failed.', focus: true, ask: 'Update the card on file.', why: ['A payment failed.']);
      await reading('<daily-1@x>', 'Five stories.', focus: false);
      // Something in Noise never reaches Focus, whatever was said about it.
      await reading('<flash-1@x>', 'A sale.', focus: true, ask: 'Buy now');
      Future<List<String>> focus() async => [for (final i in await db.watchFocus().first) i.messageId!];
      expect(await focus(), ['<renee@x>', '<bank@x>'], reason: 'newest first; mail from a company is here because it asks something');
      final first = (await db.watchFocus().first).first;
      expect(first.ask, 'Say yes or no to Charlotte, March 14.');
      expect(first.reading!.due!.difference(due).inSeconds.abs(), lessThan(2));
      expect(first.person, isTrue);

      // Done: it leaves Focus and shows under Done today.
      final bank = await message('<bank@x>');
      await db.setMessagesDone([bank.id], true);
      expect(await focus(), ['<renee@x>']);
      expect([for (final i in await db.watchFocusDoneToday().first) i.messageId], ['<bank@x>']);
      await db.setMessagesDone([bank.id], false);

      // "Not Focus": it leaves, and the helper is told.
      await db.setFocusFix(bank.id, false);
      expect(await focus(), ['<renee@x>']);
      expect((await db.customSelect("SELECT data FROM helper_outbox WHERE kind = 'msgfix' AND k = '<bank@x>'").get()).single.read<String>('data'), contains('"focus":false'));

      // "This needs me" on an email the assistant passed over.
      final daily = await message('<daily-1@x>');
      await db.setFocusFix(daily.id, true);
      expect(await focus(), ['<renee@x>', '<daily-1@x>']);

      // Answered: the helper says so, and it leaves.
      await reading('<renee@x>', 'Renee needs your yes or no.', focus: true, ask: 'Say yes or no.', answered: true);
      expect(await focus(), ['<daily-1@x>']);
    });

    test('Later: a Focus email put off until a time is out of Focus until then, and comes back by itself', () async {
      await assistantOn();
      await reading('<renee@x>', 'Renee needs your yes or no.', focus: true, ask: 'Say yes or no.');
      await reading('<bank@x>', 'A payment failed.', focus: true, ask: 'Update the card.');
      Future<List<String>> focus() async => [for (final i in await db.watchFocus().first) i.messageId!];
      Future<List<String>> later() async => [for (final i in await db.watchFocusLater().first) i.messageId!];
      final renee = await message('<renee@x>');
      final until = DateTime.now().add(const Duration(hours: 5));
      await db.setLaterUntil(renee.id, until);
      expect(await focus(), ['<bank@x>']);
      expect(await later(), ['<renee@x>']);
      expect((await db.watchFocusLater().first).single.laterUntil!.difference(until).inSeconds.abs(), lessThan(2));
      expect((await db.customSelect("SELECT data FROM helper_outbox WHERE kind = 'msgfix' AND k = '<renee@x>'").get()).single.read<String>('data'), contains('"later":${until.millisecondsSinceEpoch ~/ 1000}'));

      // Its time has come: it is in Focus again, with nothing else changed.
      await db.setLaterUntil(renee.id, DateTime.now().subtract(const Duration(minutes: 1)));
      expect(await focus(), ['<renee@x>', '<bank@x>']);
      expect(await later(), isEmpty);

      // Put off, then brought back by hand.
      await db.setLaterUntil(renee.id, until);
      await db.setLaterUntil(renee.id, null);
      expect(await focus(), ['<renee@x>', '<bank@x>']);
      // Done while put off: it is finished, not waiting to come back.
      await db.setLaterUntil(renee.id, until);
      await db.setMessagesDone([renee.id], true);
      expect(await later(), isEmpty);
      // Put off on another device: it is out of Focus here too.
      await helperSays('msgfix', '<bank@x>', {'later': until.millisecondsSinceEpoch ~/ 1000});
      expect(await focus(), isEmpty);
      expect(await later(), ['<bank@x>']);
    });

    test('the helper is told your last word, whatever came before it', () async {
      await assistantOn();
      final renee = await message('<renee@x>');
      final until = DateTime(2030, 1, 1, 8);
      Future<List<String>> waiting() async => [for (final r in await db.customSelect("SELECT data FROM helper_outbox WHERE kind = 'msgfix' AND k = '<renee@x>' ORDER BY id").get()) r.read<String>('data')];
      // Later, Undo, Later again at the same time, before anything was sent.
      await db.setLaterUntil(renee.id, until);
      await db.setLaterUntil(renee.id, null);
      await db.setLaterUntil(renee.id, until);
      expect(await waiting(), ['{"later":${until.millisecondsSinceEpoch ~/ 1000}}']);
      // Not Focus, Undo, Not Focus: the same. And one kind of word does not push out another.
      await db.setFocusFix(renee.id, false);
      await db.setFocusFix(renee.id, null);
      await db.setFocusFix(renee.id, false);
      expect(await waiting(), ['{"later":${until.millisecondsSinceEpoch ~/ 1000}}', '{"focus":false}']);
    });

    test('Waiting on: with the assistant on, its reading of what you sent decides; without one, the plain rule does', () async {
      DateTime ago2({int days = 0}) => DateTime.now().subtract(Duration(days: days));
      void sent(String to, String subject, String words, String id) =>
          imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: [RemoteAddress(to)], subject: subject, messageId: id, date: ago2(days: 5), snippet: words));
      // Three people the user has heard from, so they are people.
      for (final p in ['ann', 'bob', 'cy']) {
        got('$p@x.example', p, 'Hello', id: '<in-$p@x>', at: ago2(days: 12));
      }
      sent('ann@x.example', 'The contract', 'Please send the signed copy when you can.', '<s-ann@x>');
      sent('bob@x.example', 'Thanks', 'Thanks, does that sound right?', '<s-bob@x>');
      sent('cy@x.example', 'Price', 'What is the price?', '<s-cy@x>');
      await sync();
      Future<Map<String, String>> waiting() async => {for (final w in await db.watchWaitingOn().first) w.message.messageId!: w.asked};
      // No assistant: the plain rule lists the two with a question mark.
      expect((await waiting()).keys.toSet(), {'<s-bob@x>', '<s-cy@x>'});

      await assistantOn();
      // The assistant read two of them: Ann's does ask (with no question mark); Bob's does not.
      await helperSays('read', '<s-ann@x>', {'line': 'You asked Ann to send the signed copy.', 'focus': false, 'ask': 'The signed copy.', 'why': <String>[], 'answered': false, 'at': 1, 'sent': true, 'asks': true});
      await helperSays('read', '<s-bob@x>', {'line': 'You thanked Bob.', 'focus': false, 'ask': '', 'why': <String>[], 'answered': false, 'at': 1, 'sent': true, 'asks': false});
      final w = await waiting();
      expect(w.keys.toSet(), {'<s-ann@x>', '<s-cy@x>'}, reason: 'Ann by the reading, Cy by the plain rule (not read yet), Bob dropped by the reading');
      expect(w['<s-ann@x>'], 'The signed copy.');
      expect(w['<s-cy@x>'], '');
      // Switched off: back to the plain rule alone.
      await db.putSetting('helper.assistantOn', '0');
      expect((await waiting()).keys.toSet(), {'<s-bob@x>', '<s-cy@x>'});
    });

    test('what you set on another device arrives here too', () async {
      await assistantOn();
      await reading('<bank@x>', 'A payment failed.', focus: true, ask: 'Update the card.');
      await helperSays('msgfix', '<bank@x>', {'focus': false});
      await helperSays('msgfix', '<daily-1@x>', {'pile': 'feed'});
      expect(await db.watchFocus().first, isEmpty);
      expect((await other())['<daily-1@x>']!.by, PileBy.you);
      // Nothing that came from the helper is sent back to it.
      expect(await db.customSelect("SELECT 1 FROM helper_outbox WHERE kind = 'msgfix'").get(), isEmpty);
    });

    test('with the assistant off, its sentences and Focus go quiet, and mail is still sorted', () async {
      await assistantOn();
      await reading('<renee@x>', 'Renee needs your yes or no.', focus: true, ask: 'Say yes or no.');
      await reading('<daily-2@x>', 'Your subscription renews Friday.');
      await helperSays('sort', '<daily-2@x>', {'cls': 'feeds', 'cat': 'Newsletter', 'pile': 'feed'});
      expect(await db.watchFocus().first, hasLength(1));
      await db.putSetting('helper.assistantOn', '0');
      expect(await db.watchFocus().first, isEmpty);
      final mail = await other();
      expect(mail['<daily-2@x>']!.reading, isNull);
      expect(mail['<daily-2@x>']!.line, 'Your subscription renews Friday', reason: 'the subject, as before there was an assistant');
      expect(mail['<daily-2@x>']!.pile, FeedsPile.feed);
      expect(mail['<flash-1@x>']!.pile, FeedsPile.noise);
    });

    test('emails are grouped by day, then by week', () {
      MailItem at(DateTime t) => MailItem(id: t.millisecondsSinceEpoch, accountId: 1, messageId: null, threadKey: null, rowKey: 'c:a', senderKey: 'a', senderName: 'A', subject: 's', at: t, unread: false, person: false);
      final now = DateTime(2026, 11, 11, 12); // a Wednesday
      final labels = [
        for (final g in groupByDay([at(DateTime(2026, 11, 11, 8)), at(DateTime(2026, 11, 10, 8)), at(DateTime(2026, 11, 9, 8)), at(DateTime(2026, 11, 5, 8)), at(DateTime(2026, 10, 20, 8)), at(DateTime(2025, 12, 1, 8))], now: now)) g.label,
      ];
      expect(labels, ['Today', 'Yesterday', 'Earlier this week', 'Last week', 'October', 'December 2025']);
    });

    test('Noise: one row per sender; single emails of one kind are gathered', () {
      var n = 0;
      MailItem from(String key, {String? tag, int daysAgo = 0}) =>
          MailItem(id: ++n, accountId: 1, messageId: null, threadKey: null, rowKey: 'c:$key', senderKey: key, senderName: key, subject: 's', at: DateTime(2026, 11, 11, 12).subtract(Duration(days: daysAgo, hours: n)), unread: false, person: false, tag: tag, pile: FeedsPile.noise);
      final groups = noiseGroups(
        [from('flash', tag: 'Promotion'), from('flash', tag: 'Promotion'), from('flash', tag: 'Promotion', daysAgo: 20), from('a', tag: 'Promotion'), from('b', tag: 'Promotion'), from('c', tag: 'Promotion'), from('d', tag: 'Social'), from('weekly', tag: 'Newsletter'), from('weekly', tag: 'Newsletter')],
        now: DateTime(2026, 11, 11, 13),
      );
      expect([for (final g in groups) '${g.title}:${g.items.length}:${g.senders}'], ['Other promotions:3:3', 'flash:3:1', 'weekly:2:1', 'd:1:1']);
      expect(groups.first.many, isTrue);
      expect(groups[1].since(DateTime(2026, 11, 4, 13)), 2);
    });
  });

  group('screens', () {
    late InMemorySettingsStore settings;

    Widget app(Destination opensOn) => ProviderScope(
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

    Future<ProviderContainer> pumpApp(WidgetTester tester, Destination opensOn) async {
      tester.view.physicalSize = const Size(1500, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(opensOn));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    }

    Future<void> teardown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    }

    /// The readings a helper with the assistant on would have sent.
    Future<void> filled() async {
      await assistantOn();
      await helperSays('sort', '<daily-1@x>', {'cls': 'feeds', 'cat': 'Newsletter', 'pile': 'noise'});
      await helperSays('sort', '<daily-2@x>', {'cls': 'feeds', 'cat': 'Newsletter', 'pile': 'feed'});
      await reading('<renee@x>', 'Renee needs your yes or no on Charlotte, March 14.', focus: true, ask: 'Say yes or no to Charlotte, March 14.', due: DateTime.now().add(const Duration(days: 1)), why: ['It asks you for a yes or no.', 'The venue releases the date tomorrow.']);
      await reading('<bank@x>', 'The \$240 insurance payment failed because the card expired.', focus: true, ask: 'Update the card on file.', why: ['A payment failed.']);
      await reading('<daily-1@x>', 'Five stories, one about spring theater tours.', why: ['It is a general newsletter sent to a list.']);
      await reading('<daily-2@x>', 'Your subscription renews Friday.', why: ['It is about your own account.']);
    }

    setUp(() => settings = InMemorySettingsStore());

    testWidgets('Reply, Reply all and Forward under an email in Focus open the reply box right there', (tester) async {
      await tester.runAsync(filled);
      final renee = await tester.runAsync(() => message('<renee@x>'));
      final bank = await tester.runAsync(() => message('<bank@x>'));
      final c = await pumpApp(tester, Destination.focus);
      await tester.tap(find.byKey(ValueKey('mail-row-${renee!.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('thread-reply')), findsNothing);

      // The Reply button under the email.
      await tester.tap(find.widgetWithText(TextButton, 'Reply'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('thread-reply')), findsOneWidget, reason: 'Reply opens the reply box under the email');
      expect(find.byType(ComposeForm), findsOneWidget);
      expect(find.byKey(const ValueKey('compose-send')), findsOneWidget);
      expect(c.read(destinationProvider), Destination.focus, reason: 'it stays in Focus');
      expect(find.textContaining('Reply · Spring dates'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Forward, then Reply all: the box changes to what was asked.
      await tester.tap(find.widgetWithText(TextButton, 'Forward'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Forward · Spring dates'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Reply all'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reply all'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reply all · Spring dates'), findsOneWidget);

      // The arrow at the top does the same; nothing jumps to Chats.
      await tester.tap(find.byTooltip('Close (Esc)'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('thread-reply')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('mail-reply')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('thread-reply')), findsOneWidget);
      expect(c.read(destinationProvider), Destination.focus);

      // Opening another email leaves the reply behind: it does not follow.
      await tester.tap(find.byKey(ValueKey('mail-row-${bank!.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('thread-reply')), findsNothing);
      expect(c.read(replyRequestProvider), isNull);
      await teardown(tester);
    });

    testWidgets('Focus lists emails, not people: who, what is asked, and by when; the rail shows how many', (tester) async {
      await tester.runAsync(filled);
      final renee = await tester.runAsync(() => message('<renee@x>'));
      await pumpApp(tester, Destination.focus);
      expect(find.textContaining('2 emails need you'), findsOneWidget);
      expect(find.text('Say yes or no to Charlotte, March 14.'), findsOneWidget);
      expect(find.text('Update the card on file.'), findsOneWidget);
      expect(find.text('Renee Calloway'), findsOneWidget);
      expect(find.byKey(ValueKey('mail-due-${renee!.id}')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('focus-badge')), matching: find.text('2')), findsWidgets);
      expect(find.text('Today'), findsWidgets, reason: 'grouped by when it came');

      // Opening one shows the email with its sentence and its "?".
      await tester.tap(find.byKey(ValueKey('mail-row-${renee.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('reading-${renee.id}')), findsOneWidget);
      expect(find.text('Renee needs your yes or no on Charlotte, March 14.'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('why-${renee.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Why this is in Focus'), findsOneWidget);
      expect(find.text('It asks you for a yes or no.'), findsOneWidget);
      // One tap takes it out; the email itself stays in its chat.
      await tester.tap(find.byKey(const ValueKey('why-not-focus')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 email needs you'), findsOneWidget);
      expect(find.text('Say yes or no to Charlotte, March 14.'), findsNothing);
      final c = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      expect((c.read(focusMailProvider).value ?? []).map((i) => i.messageId), ['<bank@x>']);
      await teardown(tester);
    });

    testWidgets('Done on a Focus email moves it under Done today and lowers the count', (tester) async {
      await tester.runAsync(filled);
      final bank = await tester.runAsync(() => message('<bank@x>'));
      await pumpApp(tester, Destination.focus);
      await tester.tap(find.byKey(ValueKey('mail-row-${bank!.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mail-done')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 email needs you'), findsOneWidget);
      expect(find.text('Done today'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('a Focus row is dealt with where it sits: point at it for Done and Not Focus, or swipe; Undo brings it back', (tester) async {
      await tester.runAsync(filled);
      final renee = (await tester.runAsync(() => message('<renee@x>')))!;
      final bank = (await tester.runAsync(() => message('<bank@x>')))!;
      final container = await pumpApp(tester, Destination.focus);
      expect(find.byKey(ValueKey('quick-done-${renee.id}')), findsNothing, reason: 'the buttons show only on the row pointed at');

      // Point at a row: Done and Not Focus appear on it. Nothing is opened.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('mail-row-${renee.id}'))));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('quick-done-${renee.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('quick-ignore-${renee.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('quick-done-${bank.id}')), findsNothing);

      // Done, right there.
      await tester.tap(find.byKey(ValueKey('quick-done-${renee.id}')));
      await tester.pumpAndSettle();
      expect(container.read(openMailProvider('focus')), isNull, reason: 'the email was never opened');
      expect(find.textContaining('1 email needs you'), findsOneWidget);
      expect(find.text('Done today'), findsOneWidget);
      expect((await tester.runAsync(() => message('<renee@x>')))!.doneAt, isNotNull);

      // Undo brings it back.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 emails need you'), findsOneWidget);
      expect((await tester.runAsync(() => message('<renee@x>')))!.doneAt, isNull);

      // Not Focus, right there: the assistant is told this one did not need you.
      ScaffoldMessenger.of(tester.element(find.byType(AppShell))).clearSnackBars();
      await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('mail-row-${bank.id}'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('quick-ignore-${bank.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('mail-row-${bank.id}')), findsNothing);
      expect((await tester.runAsync(() => message('<bank@x>')))!.focusFix, 'no');
      expect(find.textContaining('Taken out of Focus'), findsOneWidget);
      await mouse.moveTo(const Offset(1400, 900));

      // Swiping a row right is Done.
      await tester.drag(find.byKey(ValueKey('mail-row-${renee.id}')), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing needs you'), findsOneWidget);
      expect((await tester.runAsync(() => message('<renee@x>')))!.doneAt, isNotNull);
      await teardown(tester);
    });

    testWidgets('Later on a Focus row: pick a time, it leaves Focus, shows under Later, and can be brought back', (tester) async {
      await tester.runAsync(filled);
      final renee = (await tester.runAsync(() => message('<renee@x>')))!;
      final container = await pumpApp(tester, Destination.focus);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('mail-row-${renee.id}'))));
      await tester.pumpAndSettle();
      // Three buttons on the row: Done, Later, Not Focus.
      expect(find.byKey(ValueKey('quick-done-${renee.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('quick-ignore-${renee.id}')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('quick-later-${renee.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Later, until'), findsOneWidget, reason: 'the same choices Later offers in Chats');
      await tester.tap(find.byKey(const ValueKey('snooze-Tomorrow morning')));
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(1400, 900));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 email needs you'), findsOneWidget);
      expect(find.textContaining('Put off until tomorrow 8:00 AM'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget, reason: 'its own group at the bottom of Focus');
      expect(tester.widget<Text>(find.byKey(ValueKey('mail-note-${renee.id}'))).data, 'back tomorrow 8:00 AM');
      expect(find.descendant(of: find.byKey(const ValueKey('focus-badge')), matching: find.text('1')), findsWidgets, reason: 'the count on the rail goes down');
      expect(container.read(openMailProvider('focus')), isNull, reason: 'nothing was opened');

      // Today lists it under Later, and brings it back with one press.
      container.read(destinationProvider.notifier).select(Destination.today);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('later-mail-${renee.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('needs-${renee.id}')), findsNothing, reason: 'not under Needs you while it is put off');
      await tester.tap(find.byKey(ValueKey('later-mail-back-${renee.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('needs-${renee.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('later-mail-${renee.id}')), findsNothing);

      // On the open email, Later sits beside Done; Undo takes it back.
      container.read(destinationProvider.notifier).select(Destination.focus);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('mail-row-${renee.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mail-done')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mail-later')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('snooze-Next Monday')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 email needs you'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 emails need you'), findsOneWidget);
      expect((await tester.runAsync(() => message('<renee@x>')))!.laterUntil, isNull);
      await teardown(tester);
    });

    testWidgets('swiping a Focus row left is Not Focus', (tester) async {
      await tester.runAsync(filled);
      final renee = (await tester.runAsync(() => message('<renee@x>')))!;
      await pumpApp(tester, Destination.focus);
      await tester.drag(find.byKey(ValueKey('mail-row-${renee.id}')), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('mail-row-${renee.id}')), findsNothing);
      expect((await tester.runAsync(() => message('<renee@x>')))!.focusFix, 'no');
      expect(find.textContaining('1 email needs you'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('with no assistant, Focus is empty and says why; nothing is guessed', (tester) async {
      await pumpApp(tester, Destination.focus);
      expect(find.byKey(const ValueKey('focus-empty')), findsOneWidget);
      expect(find.textContaining('The assistant is not on'), findsOneWidget);
      expect(find.text('Renee Calloway'), findsNothing);
      await teardown(tester);
    });

    testWidgets('Feed is a list of emails by day; each row says what the email is; one sender can be in Feed and in Noise', (tester) async {
      await tester.runAsync(filled);
      await pumpApp(tester, Destination.feed);
      expect(find.text('Worth knowing. Nothing here needs a reply.'), findsOneWidget);
      expect(find.text('Your subscription renews Friday.'), findsOneWidget, reason: 'the assistant\'s line, not the subject');
      expect(find.text('Five stories, one about spring theater tours.'), findsNothing, reason: 'that one is in Noise');
      expect(find.text('70% off, today only'), findsNothing);
      expect(find.text('Yesterday'), findsWidgets, reason: 'the day heading (and the time on the row)');
      expect(find.text('First Citizens Bank'), findsOneWidget);
      // Open one: its words, its sentence.
      final daily = await tester.runAsync(() => message('<daily-2@x>'));
      await tester.tap(find.byKey(ValueKey('mail-row-${daily!.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('reading-${daily.id}')), findsOneWidget);
      // The "?" moves this one email to Noise; its sender's other mail is not touched.
      await tester.tap(find.byKey(ValueKey('why-${daily.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Why this is in Feed'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('why-move-one')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('mail-row-${daily.id}')), findsNothing);
      await teardown(tester);
    });

    testWidgets('Noise is one row per sender with how many came; it says why and offers the ways out', (tester) async {
      await tester.runAsync(filled);
      await pumpApp(tester, Destination.noise);
      expect(find.textContaining('3 emails kept out of your way'), findsOneWidget);
      expect(find.text('FlashDeals'), findsOneWidget);
      expect(find.textContaining('2 this week'), findsOneWidget);
      expect(find.text('Pollstar Daily'), findsOneWidget, reason: 'its one Noise email; the other is in Feed');
      await tester.tap(find.byKey(const ValueKey('noise-row-s:deals@flash.example')));
      await tester.pumpAndSettle();
      expect(find.text('Why this is in Noise'), findsOneWidget);
      expect(find.textContaining('Gmail files it under Promotions'), findsOneWidget);
      expect(find.text('Last chance: free shipping'), findsOneWidget);
      expect(find.byKey(const ValueKey('noise-archive-group')), findsOneWidget);
      // Move to Feed: the sender's mail goes to Feed for good.
      await tester.tap(find.byKey(const ValueKey('noise-to-feed')));
      await tester.pumpAndSettle();
      expect(find.text('FlashDeals'), findsNothing);
      final flash = await tester.runAsync(() async => (await db.watchOtherMail().first).where((i) => i.senderKey == 'deals@flash.example').map((i) => i.pile).toSet());
      expect(flash, {FeedsPile.feed});
      await teardown(tester);
    });

    testWidgets('Today, in full: the sentence on top says when it was written; each Needs you line says what, why, who, by when, with Done and Later', (tester) async {
      await tester.runAsync(filled);
      final wrote = DateTime.now().subtract(const Duration(minutes: 5));
      await tester.runAsync(() => helperSays('day', 'today', {'text': 'Renee needs your yes or no on Charlotte by tomorrow, and the bank payment failed.', 'at': wrote.millisecondsSinceEpoch ~/ 1000, 'after': 14}));
      final renee = (await tester.runAsync(() => message('<renee@x>')))!;
      await pumpApp(tester, Destination.today);
      expect(tester.widget<Text>(find.byKey(const ValueKey('today-sentence-text'))).data, 'Renee needs your yes or no on Charlotte by tomorrow, and the bank payment failed.');
      final when = tester.widget<Text>(find.byKey(const ValueKey('today-sentence-when'))).data!;
      expect(when, startsWith('Written '));
      expect(when, endsWith(', after 14 new emails'));
      expect(tester.getTopLeft(find.byKey(const ValueKey('today-sentence'))).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('today-needs-you'))).dy), reason: 'above the cards');

      // The line: what to do, why, who and which email, by when.
      expect(find.text('Say yes or no to Charlotte, March 14.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(ValueKey('needs-why-${renee.id}'))).data, 'Renee needs your yes or no on Charlotte, March 14.');
      expect(find.text('Renee Calloway · Re: Spring dates'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(ValueKey('needs-by-${renee.id}'))).data, startsWith('by tomorrow'));
      expect(find.textContaining('Draft'), findsNothing, reason: 'nothing is drafted');

      // Later on the line: it moves down to Later.
      await tester.tap(find.byKey(ValueKey('needs-later-${renee.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('snooze-Tomorrow morning')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('needs-${renee.id}')), findsNothing);
      expect(find.byKey(ValueKey('later-mail-${renee.id}')), findsOneWidget);
      // Done on the line.
      final bank = (await tester.runAsync(() => message('<bank@x>')))!;
      await tester.tap(find.byKey(ValueKey('needs-done-${bank.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('needs-${bank.id}')), findsNothing);
      await teardown(tester);
    });

    testWidgets('the sentence on Today can be dismissed: it stays away until a new one is written, and the other devices are told', (tester) async {
      await tester.runAsync(filled);
      final wrote = DateTime.now().subtract(const Duration(minutes: 5));
      final at = wrote.millisecondsSinceEpoch ~/ 1000;
      await tester.runAsync(() => helperSays('day', 'today', {'text': 'Two things need you.', 'at': at, 'after': 3}));
      await pumpApp(tester, Destination.today);
      expect(find.byKey(const ValueKey('today-sentence')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('today-sentence-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-sentence')), findsNothing);
      expect(find.byKey(const ValueKey('today-needs-you')), findsOneWidget, reason: 'the rest of Today is untouched');
      final noted = await tester.runAsync(() => db.customSelect("SELECT data FROM helper_outbox WHERE kind = 'pref' AND k = 'day'").get());
      expect(noted!.single.read<String>('data'), '{"dismissed":$at}');
      // The same sentence arriving again stays away.
      await tester.runAsync(() => helperSays('day', 'today', {'text': 'Two things need you.', 'at': at, 'after': 3}));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-sentence')), findsNothing);
      // A new one shows.
      await tester.runAsync(() => helperSays('day', 'today', {'text': 'One thing needs you now.', 'at': at + 1500, 'after': 1}));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('today-sentence-text'))).data, 'One thing needs you now.');
      // Dismissed on another device: gone here too. Undone there: back here.
      await tester.runAsync(() => helperSays('pref', 'day', {'dismissed': at + 1500}));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-sentence')), findsNothing);
      await tester.runAsync(() => helperSays('pref', 'day', {'dismissed': 0}));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-sentence')), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('with the assistant off there is no sentence; an empty one is not shown either', (tester) async {
      await tester.runAsync(filled);
      await tester.runAsync(() => helperSays('day', 'today', {'text': '', 'at': DateTime.now().millisecondsSinceEpoch ~/ 1000, 'after': 0}));
      await pumpApp(tester, Destination.today);
      expect(find.byKey(const ValueKey('today-sentence')), findsNothing);
      await tester.runAsync(() => helperSays('day', 'today', {'text': 'Two things need you.', 'at': DateTime.now().millisecondsSinceEpoch ~/ 1000, 'after': 0}));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-sentence')), findsOneWidget);
      await tester.runAsync(() => db.putSetting('helper.assistantOn', '0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-sentence')), findsNothing);
      expect(find.byKey(const ValueKey('today-up-to-date')), findsNothing, reason: 'this check has no helper to be in step with');
      await teardown(tester);
    });

    testWidgets('a person with an email in Focus gets a small pink dot on their row in Chats; it goes when the email is done', (tester) async {
      await tester.runAsync(filled);
      final renee = (await tester.runAsync(() => message('<renee@x>')))!;
      await pumpApp(tester, Destination.chats);
      expect(find.byKey(const ValueKey('focus-dot-c:renee@booking.example')), findsOneWidget);
      expect(find.byTooltip('Has an email in Focus'), findsOneWidget, reason: 'one person, one dot');
      await tester.runAsync(() => db.setMessagesDone([renee.id], true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('focus-dot-c:renee@booking.example')), findsNothing);
      await teardown(tester);
    });

    testWidgets('Today lists what needs you, straight from Focus', (tester) async {
      await tester.runAsync(filled);
      await pumpApp(tester, Destination.today);
      expect(find.text('Say yes or no to Charlotte, March 14.'), findsOneWidget);
      expect(find.text('Update the card on file.'), findsOneWidget);
      await teardown(tester);
    });
  });
}
