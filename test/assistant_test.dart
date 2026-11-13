import 'package:convomail/app/compose_state.dart';
import 'package:convomail/app/destinations.dart';
import 'package:convomail/app/layout.dart';
import 'package:convomail/app/mail_state.dart';
import 'package:convomail/app/settings_navigation.dart';
import 'package:convomail/app/time_format.dart';
import 'package:convomail/domain/classifier.dart';
import 'package:convomail/domain/email_pile.dart';
import 'package:convomail/domain/piles.dart';
import 'package:convomail/domain/timely_extractor.dart';
import 'package:convomail/helper/helper_sync.dart';
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
import 'package:convomail/store/timely_queries.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/compose/compose_form.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/screens/mail/mail_widgets.dart';
import 'package:convomail/ui/screens/noise_screen.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:convomail/ui/widgets/reading_line.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
    test('good to know: the newest word on one thing only; never Noise, never what needs you, never what is done', () async {
      await assistantOn();
      Future<void> says(String id, String line, {bool focus = false, String thing = ''}) =>
          helperSays('read', id, {'line': line, 'focus': focus, 'ask': focus ? 'Answer.' : '', 'why': <String>[], 'answered': false, 'at': 1, 'know': true, 'thing': thing});
      await helperSays('sort', '<daily-1@x>', {'cls': 'feeds', 'cat': 'Delivery', 'pile': 'feed'});
      await helperSays('sort', '<daily-2@x>', {'cls': 'feeds', 'cat': 'Delivery', 'pile': 'feed'});
      await says('<daily-1@x>', 'Your hard case was delivered and left at the front door.', thing: 'Amazon hard case');
      await says('<daily-2@x>', 'Your hard case is out for delivery.', thing: 'amazon hard case');
      await says('<flash-1@x>', 'A sale.', thing: 'Sale');
      await says('<renee@x>', 'Renee needs a yes or no.', focus: true, thing: 'Charlotte');
      final since = DateTime.now().subtract(const Duration(days: 3));
      var list = await db.watchGoodToKnow(since: since).first;
      expect([for (final i in list) i.messageId], ['<daily-1@x>'], reason: 'the delivery, once: arrived replaces out for delivery');
      expect(list.single.reading!.thing, 'Amazon hard case');
      expect(await db.watchGoodToKnow(since: DateTime.now().subtract(const Duration(hours: 1))).first, isEmpty, reason: 'only what came since then');
      // Done takes it off; the older word on the same thing does not come back in its place for long: it is its own email.
      await db.setMessagesDone([(await message('<daily-1@x>')).id, (await message('<daily-2@x>')).id], true);
      expect(await db.watchGoodToKnow(since: since).first, isEmpty);
      // With the assistant off there is nothing to show.
      await db.setMessagesDone([(await message('<daily-1@x>')).id], false);
      await db.putSetting('helper.assistantOn', '0');
      list = await db.watchGoodToKnow(since: since).first;
      expect(list, isEmpty);
    });

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

    Widget app(Destination opensOn, {List<Override> more = const []}) => ProviderScope(
          overrides: [
            ...more,
            settingsStoreProvider.overrideWith((ref) => settings),
            databaseProvider.overrideWith((ref) => db),
            credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
            transportFactoryProvider.overrideWith((ref) => () => imap),
            htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
            destinationProvider.overrideWith(() => DestinationNotifier(initial: opensOn)),
          ],
          child: const PrecisApp(startSync: false),
        );

    Future<ProviderContainer> pumpApp(WidgetTester tester, Destination opensOn, {List<Override> more = const []}) async {
      tester.view.physicalSize = const Size(1500, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(opensOn, more: more));
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
      // Reply all under the email is a button with its name on it.
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Reply all'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Reply all'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reply all · Spring dates'), findsOneWidget);
      // And it sits at the top of the email too, next to Reply.
      await tester.tap(find.byTooltip('Close (Esc)'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const ValueKey('mail-reply-all'))).dx, greaterThan(tester.getTopLeft(find.byKey(const ValueKey('mail-reply'))).dx));
      expect((tester.getCenter(find.byKey(const ValueKey('mail-reply-all'))).dy - tester.getCenter(find.byKey(const ValueKey('mail-reply'))).dy).abs(), lessThan(1));
      await tester.tap(find.byKey(const ValueKey('mail-reply-all')));
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
      expect(find.descendant(of: find.byKey(const ValueKey('today-sentence')), matching: find.text('THE LEDE')), findsOneWidget, reason: 'the sentence is labeled');
      // Light: plain words beside a thin line, not a filled block.
      final lede = tester.widget<Container>(find.byKey(const ValueKey('today-sentence'))).decoration! as BoxDecoration;
      expect(lede.color, isNull);
      expect((lede.border! as Border).left.width, 3);
      expect(tester.widget<Text>(find.byKey(const ValueKey('today-sentence-text'))).style!.fontWeight, FontWeight.w400);
      expect(find.byKey(const ValueKey('today-title')), findsNothing, reason: 'the page is named on the rail only');
      expect(find.text('Précis'), findsOneWidget);
      final when = tester.widget<Text>(find.byKey(const ValueKey('today-sentence-when'))).data!;
      expect(when, startsWith('Written '));
      expect(when, endsWith(', after 14 new emails'));
      expect(tester.getTopLeft(find.byKey(const ValueKey('today-sentence'))).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('today-needs-you'))).dy), reason: 'above the cards');

      // The line: what to do in bold; who, by when and why under it. (The subject shows when the email is opened.)
      expect(find.text('Say yes or no to Charlotte, March 14.'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Say yes or no to Charlotte, March 14.')).style!.fontWeight, FontWeight.w700);
      expect(tester.widget<Text>(find.byKey(ValueKey('needs-why-${renee.id}'))).data, 'Renee needs your yes or no on Charlotte, March 14.');
      expect(tester.widget<Text>(find.byKey(ValueKey('needs-who-${renee.id}'))).data, 'Renee Calloway');
      // Every group is named by a small label over its card, in capitals, with how many.
      expect(find.descendant(of: find.byKey(const ValueKey('today-needs-you')), matching: find.text('NEEDS YOU')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('today-label-needs-you'))).style!.fontSize, 10.5);
      expect(tester.widget<Text>(find.byKey(const ValueKey('today-count-needs-you'))).data, '2');
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

    testWidgets('an email opened from the Précis page has a way back: "Back to Précis" shows until you go somewhere yourself', (tester) async {
      await tester.runAsync(filled);
      final renee = (await tester.runAsync(() => message('<renee@x>')))!;
      final c = await pumpApp(tester, Destination.today);
      expect(find.byKey(const ValueKey('back-to-today')), findsNothing);
      await tester.tap(find.byKey(ValueKey('needs-${renee.id}')));
      await tester.pumpAndSettle();
      expect(c.read(destinationProvider), Destination.focus);
      expect(find.byKey(const ValueKey('back-to-today')), findsOneWidget);
      expect(find.text('Back to Précis'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('back-to-today')));
      await tester.pumpAndSettle();
      expect(c.read(destinationProvider), Destination.today);
      expect(find.byKey(const ValueKey('back-to-today')), findsNothing);
      // Going to Focus by the rail is not coming from Today.
      c.read(destinationProvider.notifier).select(Destination.focus);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('back-to-today')), findsNothing);
      await teardown(tester);
    });

    testWidgets('the clock: 3:00 PM or 15:00, one setting, everywhere a time is written, the assistant\'s own words included', (tester) async {
      addTearDown(() => use24Hour = false);
      await tester.runAsync(filled);
      await tester.runAsync(() => reading('<bank@x>', 'The bank wants a call before 3:00 PM.', focus: true, ask: 'Call the bank by 3 PM.', due: DateTime.now().add(const Duration(days: 1))));
      await tester.runAsync(() => helperSays('day', 'today', {'text': 'The bank wants a call by 3:00 p.m. and Renee is waiting.', 'at': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60, 'after': 2}));
      final bank = (await tester.runAsync(() => message('<bank@x>')))!;
      final c = await pumpApp(tester, Destination.today);
      expect(find.text('Call the bank by 3 PM.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('today-sentence-text'))).data, 'The bank wants a call by 3:00 p.m. and Renee is waiting.');
      expect(tester.widget<Text>(find.byKey(ValueKey('needs-by-${bank.id}'))).data, matches(RegExp(r'^by tomorrow \d{1,2}:\d\d [AP]M$')));

      // Chosen in Settings, Appearance.
      c.read(settingsSectionProvider.notifier).select(SettingsSection.appearance);
      c.read(destinationProvider.notifier).select(Destination.settings);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15:00'));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => db.getSetting(kClockFormat)), '24');
      final noted = await tester.runAsync(() => db.customSelect("SELECT data FROM helper_outbox WHERE kind = 'pref' AND k = 'clock'").get());
      expect(noted!.single.read<String>('data'), '{"h24":true}', reason: 'the other devices are told');

      c.read(destinationProvider.notifier).select(Destination.today);
      await tester.pumpAndSettle();
      expect(find.text('Call the bank by 15:00.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('today-sentence-text'))).data, 'The bank wants a call by 15:00 and Renee is waiting.');
      expect(tester.widget<Text>(find.byKey(ValueKey('needs-why-${bank.id}'))).data, 'The bank wants a call before 15:00.');
      expect(tester.widget<Text>(find.byKey(ValueKey('needs-by-${bank.id}'))).data, matches(RegExp(r'^by tomorrow \d\d:\d\d$')));
      expect(find.textContaining(RegExp(r'\d [AP]M')), findsNothing, reason: 'no 12-hour time is left anywhere on Today');

      // Chosen on another device: this one follows, with the page already open.
      await tester.runAsync(() => helperSays('pref', 'clock', {'h24': false}));
      await tester.pumpAndSettle();
      expect(find.text('Call the bank by 3 PM.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(ValueKey('needs-by-${bank.id}'))).data, matches(RegExp(r'^by tomorrow \d{1,2}:\d\d [AP]M$')));
      await teardown(tester);
    });

    testWidgets('"Up to date" on Today is a button: it checks mail and the helper right now', (tester) async {
      await tester.runAsync(filled);
      final helper = _InStepHelper();
      await pumpApp(tester, Destination.today, more: [helperProvider.overrideWith(() => helper)]);
      final pill = find.byKey(const ValueKey('today-up-to-date'));
      expect(pill, findsOneWidget);
      expect(find.descendant(of: pill, matching: find.textContaining('Up to date · 3:05 PM')), findsOneWidget);
      expect(find.byTooltip('Check for new mail now'), findsOneWidget);
      final before = helper.rounds;
      await tester.tap(pill);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(helper.rounds, greaterThan(before), reason: 'the helper was asked right away');
      expect(find.byKey(const ValueKey('today-checking')), findsNothing, reason: 'it settles back');
      expect(find.descendant(of: pill, matching: find.textContaining('Up to date')), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('on a phone the top of the page is the date with a small "Up to date" beside it, then the greeting on one line', (tester) async {
      await tester.runAsync(filled);
      final helper = _InStepHelper();
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(Destination.today, more: [helperProvider.overrideWith(() => helper), forceCompactProvider.overrideWith((ref) => true)]));
      await tester.pumpAndSettle();
      final pill = find.byKey(const ValueKey('today-up-to-date'));
      final date = find.byKey(const ValueKey('today-date'));
      final greeting = find.byKey(const ValueKey('today-greeting'));
      expect(find.descendant(of: pill, matching: find.textContaining('Up to date · 3:05 PM')), findsOneWidget);
      // The pill sits on the date's row, to its right, and is small.
      expect((tester.getCenter(pill).dy - tester.getCenter(date).dy).abs(), lessThan(6));
      expect(tester.getTopLeft(pill).dx, greaterThan(tester.getTopLeft(date).dx));
      expect(tester.getSize(pill).height, lessThan(24));
      // The greeting has the full width under them: one line, a little larger.
      expect(tester.widget<Text>(greeting).data, startsWith('Good '));
      expect(tester.widget<Text>(greeting).softWrap, isFalse, reason: 'never wrapped, whatever the name');
      expect(tester.getTopLeft(greeting).dy, greaterThan(tester.getBottomLeft(pill).dy - 1));
      expect(tester.getSize(greeting).height, lessThan(tester.widget<Text>(greeting).style!.fontSize! * 1.6), reason: 'one line');
      // Whatever the hour's greeting and the name, it is held to the width of the page (it shrinks before it would wrap or run off).
      expect(tester.getSize(find.ancestor(of: greeting, matching: find.byType(FittedBox)).first).width, lessThanOrEqualTo(376), reason: 'it fits the width of the page');
      expect(find.byKey(const ValueKey('today-title')), findsNothing);
      expect(tester.takeException(), isNull);
      await teardown(tester);
    });

    testWidgets('Good to know on Today: what matters though nothing is asked, named for what it is; a click opens it with a way back; Done takes it off', (tester) async {
      await tester.runAsync(filled);
      await tester.runAsync(() => helperSays('sort', '<daily-1@x>', {'cls': 'feeds', 'cat': 'Delivery', 'pile': 'feed'}));
      await tester.runAsync(() => helperSays('read', '<daily-1@x>', {'line': 'Your hard case was delivered at 15:10 and left at the front door.', 'focus': false, 'ask': '', 'why': <String>[], 'answered': false, 'at': 1, 'know': true, 'thing': 'Amazon hard case'}));
      // It came a minute ago (today, whatever the hour this check runs at).
      await tester.runAsync(() => db.customStatement('UPDATE messages SET date = ? WHERE message_id = ?', [DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60, '<daily-1@x>']));
      final parcel = (await tester.runAsync(() => message('<daily-1@x>')))!;
      final renee = (await tester.runAsync(() => message('<renee@x>')))!;
      final c = await pumpApp(tester, Destination.today);
      expect(find.byKey(const ValueKey('today-good-to-know')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('today-good-to-know')), matching: find.text('GOOD TO KNOW')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(ValueKey('know-line-${parcel.id}'))).data, 'Your hard case was delivered at 3:10 PM and left at the front door.');
      expect(tester.widget<Text>(find.byKey(ValueKey('know-from-${parcel.id}'))).data, startsWith('Pollstar Daily · Amazon hard case · '));
      expect(find.byKey(ValueKey('know-${renee.id}')), findsNothing, reason: 'what needs you is under Needs you, not here too');
      expect(tester.getTopLeft(find.byKey(const ValueKey('today-good-to-know'))).dy, greaterThan(tester.getTopLeft(find.byKey(const ValueKey('today-needs-you'))).dy), reason: 'right under Needs you');

      // A click opens the email where it lives, and offers the way back.
      await tester.tap(find.byKey(ValueKey('know-line-${parcel.id}')));
      await tester.pumpAndSettle();
      expect(c.read(destinationProvider), Destination.feed);
      expect(c.read(openMailProvider('feed')), parcel.id);
      await tester.tap(find.byKey(const ValueKey('back-to-today')));
      await tester.pumpAndSettle();

      // Done: off the card.
      await tester.tap(find.byKey(ValueKey('know-done-${parcel.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('know-${parcel.id}')), findsNothing);
      expect(find.byKey(const ValueKey('today-good-to-know')), findsNothing, reason: 'with nothing left in it the card goes');
      expect((await tester.runAsync(() => message('<daily-1@x>')))!.doneAt, isNotNull);
      await teardown(tester);
    });

    testWidgets('a right-click on any Today item (a press and hold on a phone) opens its menu: Dismiss, Later, Does not belong here; a plain click still opens it', (tester) async {
      await tester.runAsync(filled);
      Future<void> says(String id, String line, String thing) =>
          helperSays('read', id, {'line': line, 'focus': false, 'ask': '', 'why': <String>[], 'answered': false, 'at': 1, 'know': true, 'thing': thing});
      await tester.runAsync(() async {
        await helperSays('sort', '<daily-1@x>', {'cls': 'feeds', 'cat': 'Notification', 'pile': 'feed'});
        await helperSays('sort', '<daily-2@x>', {'cls': 'feeds', 'cat': 'Notification', 'pile': 'feed'});
        await says('<daily-1@x>', 'Your statement is ready.', 'Statement');
        await says('<daily-2@x>', 'Last month\'s statement is ready.', 'statement');
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await db.customStatement('UPDATE messages SET date = ? WHERE message_id = ?', [now - 60, '<daily-1@x>']);
        await db.customStatement('UPDATE messages SET date = ? WHERE message_id = ?', [now - 120, '<daily-2@x>']);
        await db.delete(db.helperOutbox).go();
      });
      final statement = (await tester.runAsync(() => message('<daily-1@x>')))!;
      final older = (await tester.runAsync(() => message('<daily-2@x>')))!;
      final renee = (await tester.runAsync(() => message('<renee@x>')))!;
      final bank = (await tester.runAsync(() => message('<bank@x>')))!;
      final c = await pumpApp(tester, Destination.today);
      expect(find.byKey(ValueKey('know-${statement.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('know-${older.id}')), findsNothing, reason: 'the newest word on one thing only');

      // Good to know: the three choices.
      await tester.tap(find.byKey(ValueKey('know-line-${statement.id}')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(c.read(destinationProvider), Destination.today, reason: 'a right-click does not open the email');
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Later…'), findsOneWidget);
      expect(find.text('Does not belong here'), findsOneWidget);
      // "Does not belong here": it goes, the older one about the same thing does not take its place, and the helper is told.
      await tester.tap(find.byKey(const ValueKey('menu-reject')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('know-${statement.id}')), findsNothing);
      expect(find.byKey(ValueKey('know-${older.id}')), findsNothing);
      expect(find.textContaining('to learn what kind of thing does not belong here'), findsOneWidget);
      var noted = await tester.runAsync(() => db.customSelect("SELECT k, data FROM helper_outbox WHERE kind = 'msgfix'").get());
      expect([for (final n in noted!) '${n.read<String>('k')} ${n.read<String>('data')}'], ['<daily-1@x> {"know":false}']);
      expect((await tester.runAsync(() => message('<daily-1@x>')))!.doneAt, isNull, reason: 'turned down is not the same as done');
      // Undo brings that one back.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('know-${statement.id}')), findsOneWidget);

      // Later: it leaves the card, waits under Later, and can be brought back from there.
      await tester.tap(find.byKey(ValueKey('know-line-${statement.id}')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-later')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('snooze-Tomorrow morning')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('know-${statement.id}')), findsNothing);
      expect(find.textContaining('It comes back to Good to know then'), findsOneWidget);
      expect(find.byKey(ValueKey('later-mail-${statement.id}')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('later-mail-${statement.id}')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('know-${statement.id}')), findsOneWidget);

      // Dismiss: off the card, and that is all. Not done (the check mark does that), and nothing is taught.
      await tester.runAsync(() => db.delete(db.helperOutbox).go());
      await tester.tap(find.byKey(ValueKey('know-line-${statement.id}')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('know-${statement.id}')), findsNothing);
      expect(find.byKey(ValueKey('know-${older.id}')), findsNothing, reason: 'the older word on the same thing does not come back in its place');
      expect(find.textContaining('It is not marked done'), findsOneWidget);
      expect((await tester.runAsync(() => message('<daily-1@x>')))!.doneAt, isNull);
      expect(find.byKey(const ValueKey('today-done')), findsNothing, reason: 'nothing was marked done, so there is no Done card');
      noted = await tester.runAsync(() => db.customSelect("SELECT k, data FROM helper_outbox WHERE kind = 'msgfix'").get());
      expect([for (final n in noted!) '${n.read<String>('k')} ${n.read<String>('data')}'], ['<daily-1@x> {"off":true}']);
      // Undo puts it back; dismissed again for the rest of this check.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('know-${statement.id}')), findsOneWidget);
      // The check mark on the item is what marks it done.
      await tester.tap(find.byKey(ValueKey('know-done-${statement.id}')));
      await tester.pumpAndSettle();
      expect((await tester.runAsync(() => message('<daily-1@x>')))!.doneAt, isNotNull);

      // Dismiss on Needs you: off Needs you and out of Focus, not done; Undo brings it back.
      await tester.tap(find.byKey(ValueKey('needs-${bank.id}')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('needs-${bank.id}')), findsNothing);
      expect((await tester.runAsync(() => message('<bank@x>')))!.doneAt, isNull);
      expect([for (final i in (await tester.runAsync(() => db.watchFocus().first))!) i.messageId], isNot(contains('<bank@x>')));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('needs-${bank.id}')), findsOneWidget);

      // Needs you has the same menu; a press and hold opens it too. "Does not belong here" is "this does not need me".
      await tester.longPress(find.byKey(ValueKey('needs-${renee.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-dismiss')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-later')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('menu-reject')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('needs-${renee.id}')), findsNothing);
      expect((await tester.runAsync(() => message('<renee@x>')))!.focusFix, 'no');
      noted = await tester.runAsync(() => db.customSelect("SELECT data FROM helper_outbox WHERE kind = 'msgfix' AND k = '<renee@x>'").get());
      expect(noted!.single.read<String>('data'), '{"focus":false}');

      // And a plain click still opens the email, as before.
      await tester.tap(find.byKey(ValueKey('needs-${bank.id}')));
      await tester.pumpAndSettle();
      expect(c.read(destinationProvider), Destination.focus);
      await teardown(tester);
    });

    testWidgets('the Travel card: one line for each leg, the first drawn large; the check-in link, a delay and a cancellation show as they should', (tester) async {
      await tester.runAsync(filled);
      int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
      final out = DateTime.now().add(const Duration(days: 2));
      final back = DateTime.now().add(const Duration(days: 4));
      Map<String, Object?> leg(String number, String fc, String fcity, String tc, String tcity, DateTime dep, {String state = 'confirmed', String wasDep = '', String wasArr = '', String checkin = '', String dep0 = '2026-11-16T19:57', String arr0 = '2026-11-16T22:00'}) => {
            'mode': 'flight', 'carrier': 'American Airlines', 'number': number, 'fc': fc, 'fcity': fcity, 'tc': tc, 'tcity': tcity,
            'dep': dep0, 'arr': arr0, 'dep_at': secs(dep), 'arr_at': secs(dep.add(const Duration(hours: 2, minutes: 3))), 'loc': 'HEYLVT',
            'state': state, 'news_at': 0, 'was_dep': wasDep, 'was_arr': wasArr, 'checkin': checkin, 'mid': '<daily-2@x>', 'missing': <String>[],
          };
      const a = 'AA4704|2026-11-16|RDU|LGA';
      const b = 'AA1187|2026-11-18|LGA|RDU';
      await tester.runAsync(() async {
        await helperSays('leg', a, leg('AA4704', 'RDU', 'Raleigh/Durham', 'LGA', 'New York LaGuardia', out));
        await helperSays('leg', b, leg('AA1187', 'LGA', 'New York LaGuardia', 'RDU', 'Raleigh/Durham', back, dep0: '2026-11-18T08:15', arr0: '2026-11-18T10:04'));
        // One that landed an hour ago is not on the card.
        await helperSays('leg', 'AA9|x|RDU|CLT', leg('AA9', 'RDU', 'Raleigh/Durham', 'CLT', 'Charlotte', DateTime.now().subtract(const Duration(hours: 4))));
      });
      final c = await pumpApp(tester, Destination.today);
      final card = find.byKey(const ValueKey('today-travel'));
      expect(card, findsOneWidget);
      String text(String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      // The first leg, large: the route, the day, the two codes, the times under them, how long, the confirmation, the carrier and number.
      expect(find.byKey(const ValueKey('leg-large-leg:$a')), findsOneWidget, reason: 'it leaves within two days');
      expect(text('leg-heading-leg:$a'), 'UPCOMING');
      expect(text('leg-route-leg:$a'), 'Raleigh/Durham to New York LaGuardia');
      expect(text('leg-day-leg:$a'), 'Mon, Nov 16');
      expect([text('leg-from-leg:$a'), text('leg-to-leg:$a')], ['RDU', 'LGA']);
      expect([text('leg-dep-leg:$a'), text('leg-arr-leg:$a')], ['7:57 PM', '10:00 PM']);
      expect(text('leg-length-leg:$a'), '2h 3m');
      expect(tester.widget<SelectableText>(find.byKey(const ValueKey('leg-conf-leg:$a'))).data, 'HEYLVT');
      expect(tester.widget<SelectableText>(find.byKey(const ValueKey('leg-number-leg:$a'))).data, 'AA4704');
      expect(find.descendant(of: card, matching: find.text('American Airlines')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('leg-from-leg:$a'))).style!.fontSize!, greaterThan(30), reason: 'the codes are drawn large');
      // The leg after it: a compact boarding pass, with every detail, smaller.
      expect(find.byKey(const ValueKey('leg-pass-leg:$b')), findsOneWidget);
      expect([text('leg-from-leg:$b'), text('leg-to-leg:$b')], ['LGA', 'RDU']);
      expect(text('leg-route-leg:$b'), 'New York LaGuardia to Raleigh/Durham');
      expect([text('leg-day-leg:$b'), text('leg-dep-leg:$b'), text('leg-arr-leg:$b')], ['Wed, Nov 18', '8:15 AM', '10:04 AM']);
      expect([text('leg-number-leg:$b'), text('leg-carrier-leg:$b')], ['AA1187', 'American Airlines']);
      expect(tester.widget<SelectableText>(find.byKey(const ValueKey('leg-conf-leg:$b'))).data, 'HEYLVT');
      expect(tester.widget<Text>(find.byKey(const ValueKey('leg-from-leg:$b'))).style!.fontSize!, lessThan(tester.widget<Text>(find.byKey(const ValueKey('leg-from-leg:$a'))).style!.fontSize!));
      expect(tester.getSize(find.byKey(const ValueKey('leg-leg:$b'))).height, lessThan(tester.getSize(find.byKey(const ValueKey('leg-leg:$a'))).height), reason: 'a pass takes less room than the large picture');
      expect(find.byKey(const ValueKey('leg-leg:AA9|x|RDU|CLT')), findsNothing, reason: 'landed');
      Material section() => tester.widget<Material>(find.byKey(const ValueKey('today-card-travel')));
      expect((section().shape! as RoundedRectangleBorder).side, BorderSide.none);

      // The invitation to check in came: a button that goes where the email's own button goes.
      expect(find.byKey(const ValueKey('leg-checkin-leg:$a')), findsNothing);
      await tester.runAsync(() => helperSays('leg', a, leg('AA4704', 'RDU', 'Raleigh/Durham', 'LGA', 'New York LaGuardia', out, state: 'checkin', checkin: 'https://aa.example/checkin?r=HEYLVT')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('leg-checkin-leg:$a')), findsOneWidget);
      expect(text('leg-heading-leg:$a'), 'UPCOMING');
      await tester.runAsync(() => helperSays('leg', a, leg('AA4704', 'RDU', 'Raleigh/Durham', 'LGA', 'New York LaGuardia', out, state: 'checked', checkin: 'https://aa.example/checkin?r=HEYLVT')));
      await tester.pumpAndSettle();
      expect(text('leg-heading-leg:$a'), 'CHECKED IN');
      expect(find.byKey(const ValueKey('leg-checkin-leg:$a')), findsNothing);

      // A delay: the card turns yellow; the old times are struck through with the new ones beside them.
      await tester.runAsync(() => helperSays('leg', a, leg('AA4704', 'RDU', 'Raleigh/Durham', 'LGA', 'New York LaGuardia', out, state: 'delayed', dep0: '2026-11-16T21:10', arr0: '2026-11-16T23:15', wasDep: '2026-11-16T19:57', wasArr: '2026-11-16T22:00')));
      await tester.pumpAndSettle();
      expect(text('leg-heading-leg:$a'), 'DELAYED');
      expect((section().shape! as RoundedRectangleBorder).side.color, const Color(0xFFFFCA28));
      expect([text('leg-dep-leg:$a-was'), text('leg-dep-leg:$a'), text('leg-arr-leg:$a-was'), text('leg-arr-leg:$a')], ['7:57 PM', '9:10 PM', '10:00 PM', '11:15 PM']);
      expect(tester.widget<Text>(find.byKey(const ValueKey('leg-dep-leg:$a-was'))).style!.decoration, TextDecoration.lineThrough);
      expect(tester.widget<Text>(find.byKey(const ValueKey('leg-dep-leg:$a'))).style!.color, const Color(0xFFFFCA28));

      // A cancellation: red, and drawn large at once, however far off it is.
      await tester.runAsync(() => helperSays('leg', b, leg('AA1187', 'LGA', 'New York LaGuardia', 'RDU', 'Raleigh/Durham', back, state: 'cancelled')));
      await tester.pumpAndSettle();
      expect(text('leg-heading-leg:$b'), 'CANCELLED');
      expect(find.byKey(const ValueKey('leg-large-leg:$b')), findsOneWidget);
      expect((section().shape! as RoundedRectangleBorder).side.color, const Color(0xFFEF5350));

      // A click on a leg opens the newest email about it, with the way back.
      await tester.tap(find.byKey(const ValueKey('leg-route-leg:$a')));
      await tester.pumpAndSettle();
      expect(c.read(destinationProvider), Destination.feed);
      expect(c.read(openMailProvider('feed')), (await tester.runAsync(() => message('<daily-2@x>')))!.id);
      expect(find.text('Back to Précis'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await teardown(tester);
    });

    testWidgets('the Bookings card: a hotel and a car with a driver, each with its details; the x and the menu take one off on every device', (tester) async {
      await tester.runAsync(filled);
      int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
      final start = DateTime.now().add(const Duration(days: 3));
      await tester.runAsync(() async {
        await helperSays('booking', 'hotel|88412207', {
          'type': 'hotel', 'name': 'The Joule', 'starts': '2026-11-20T15:00', 'ends': '2026-11-22T11:00', 'start_at': secs(start), 'end_at': secs(start.add(const Duration(days: 2))),
          'place': 'Dallas', 'to': '', 'address': '1530 Main St, Dallas, TX', 'conf': '88412207', 'phone': '214-555-0100', 'person': '', 'party': '', 'state': 'confirmed', 'news_at': 0, 'mid': '<daily-2@x>',
        });
        await helperSays('booking', 'car_service|cr-5521', {
          'type': 'car_service', 'name': 'Carey', 'starts': '2026-11-20T09:30', 'ends': '', 'start_at': secs(start.subtract(const Duration(hours: 5))), 'end_at': null,
          'place': 'DFW Terminal C', 'to': 'The Joule', 'address': '', 'conf': 'CR-5521', 'phone': '800-555-0199', 'person': 'Luis M.', 'party': '', 'state': 'confirmed', 'news_at': 0, 'mid': '<daily-2@x>',
        });
        await db.delete(db.helperOutbox).go();
      });
      await pumpApp(tester, Destination.today);
      final card = find.byKey(const ValueKey('today-bookings'));
      expect(find.descendant(of: card, matching: find.text('BOOKINGS')), findsOneWidget);
      String text(String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      const hotel = 'booking:hotel|88412207';
      const car = 'booking:car_service|cr-5521';
      expect(find.byKey(const ValueKey('booking-heading-$hotel')), findsNothing, reason: 'a heading only when it is news: just confirmed, changed, cancelled');
      expect(text('booking-title-$hotel'), 'The Joule · Dallas');
      expect(text('booking-when-$hotel'), 'Check-in Fri, Nov 20 3:00 PM · Check-out Sun, Nov 22 11:00 AM');
      expect(text('booking-rest-$hotel'), '1530 Main St, Dallas, TX · Confirmation 88412207 · 214-555-0100');
      // A stay says its days on the right.
      expect(text('booking-day-$hotel'), startsWith('to '));
      expect(text('booking-title-$car'), 'Carey · Driver Luis M.');
      // One start: the time on the right with its day under it, and the full date on the line.
      expect(text('booking-at-$car'), '9:30 AM');
      expect(text('booking-when-$car'), 'Pick-up Fri, Nov 20');
      expect(text('booking-rest-$car'), 'DFW Terminal C → The Joule · Confirmation CR-5521 · 800-555-0199');
      expect(tester.getTopLeft(find.byKey(const ValueKey('booking-$car'))).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('booking-$hotel'))).dy), reason: 'soonest first');

      // The small x shows only while the mouse is over the line; it takes the booking off, and the helper is told.
      double x() => tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('booking-dismiss-$car')), matching: find.byType(Opacity)).first).opacity;
      expect(x(), 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('booking-title-$car'))));
      await tester.pumpAndSettle();
      expect(x(), 1);
      await tester.tap(find.byKey(const ValueKey('booking-dismiss-$car')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('booking-$car')), findsNothing);
      var noted = await tester.runAsync(() => db.customSelect("SELECT k, data FROM helper_outbox WHERE kind = 'cardfix'").get());
      expect([for (final n in noted!) '${n.read<String>('k')} ${n.read<String>('data')}'], ['$car {"off":true}']);

      // The menu: "Does not belong here" takes it off and tells the assistant what it was.
      await tester.tap(find.byKey(const ValueKey('booking-$hotel')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-dismiss')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-later')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('menu-reject')));
      await tester.pumpAndSettle();
      expect(card, findsNothing, reason: 'with nothing left in it the card goes');
      noted = await tester.runAsync(() => db.customSelect("SELECT data FROM helper_outbox WHERE kind = 'cardfix' AND k = '$hotel'").get());
      expect(noted!.single.read<String>('data'), '{"no":true,"what":"Hotel: The Joule"}');
      // Dismissed on another device: gone here too.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('booking-$hotel')), findsOneWidget);
      await tester.runAsync(() => helperSays('cardfix', hotel, {'off': true}));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('booking-$hotel')), findsNothing);
      await teardown(tester);
    });

    testWidgets('travel someone booked with details missing: their email is under Needs you with "Review draft", which opens the reply box with the email already written', (tester) async {
      await tester.runAsync(filled);
      const draft = 'Hi Renee,\n\nCould you send me these for the Dallas trip?\n- the confirmation code\n- the flight number for the flight home\n\nThank you,\nClay';
      await tester.runAsync(() => helperSays('read', '<renee@x>', {'line': 'Renee sent your Dallas travel.', 'focus': true, 'ask': 'Ask Renee for the travel details that are missing.', 'why': ['Details the travel card needs were not in this email.'], 'answered': false, 'at': 1, 'know': false, 'thing': 'Dallas trip', 'draft': draft}));
      final renee = (await tester.runAsync(() => message('<renee@x>')))!;
      final bank = (await tester.runAsync(() => message('<bank@x>')))!;
      final c = await pumpApp(tester, Destination.today);
      expect(find.descendant(of: find.byKey(ValueKey('needs-${renee.id}')), matching: find.text('Ask Renee for the travel details that are missing.')), findsOneWidget);
      expect(find.byKey(ValueKey('needs-draft-${bank.id}')), findsNothing, reason: 'no other email ever carries one');
      await tester.tap(find.byKey(ValueKey('needs-draft-${renee.id}')));
      await tester.pumpAndSettle();
      expect(c.read(destinationProvider), Destination.focus);
      expect(find.byType(ComposeForm), findsOneWidget);
      expect(c.read(replyRequestProvider)!.body, draft);
      // The words are in the box, to change or send; nothing has gone anywhere.
      expect(find.textContaining('Could you send me these for the Dallas trip?', findRichText: true), findsWidgets);
      expect(find.textContaining('the flight number for the flight home', findRichText: true), findsWidgets);
      expect(find.byKey(const ValueKey('compose-send')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await teardown(tester);
    });

    testWidgets('a delivery is headed by what is inside, with who sent it underneath, how far along it is, and when it comes', (tester) async {
      await tester.runAsync(filled);
      await tester.runAsync(() async {
        await helperSays('read', '<daily-1@x>', {'line': 'Your order is on its way.', 'focus': false, 'ask': '', 'why': <String>[], 'answered': false, 'at': 1, 'know': false, 'thing': 'Hard case and more'});
        await db.upsertTimely(await message('<daily-1@x>'), [TimelyFact(type: TimelyType.delivery, dedupeKey: 'track:9', title: 'Pollstar Shop', startsAt: DateTime.now().add(const Duration(days: 1)))], DateTime.now().subtract(const Duration(minutes: 1)));
      });
      await pumpApp(tester, Destination.today);
      final item = (await tester.runAsync(() => db.select(db.timelyItems).get()))!.single;
      // A later email about the same package, as any device learns of it.
      Future<void> later(String status, int secondsAgo) => helperSays('timely', 'track:9', {
            'type': 'delivery', 'title': 'Pollstar Shop', 'detail': '', 'starts': null, 'ends': null, 'url': null, 'label': null, 'status': status,
            'mat': DateTime.now().millisecondsSinceEpoch ~/ 1000 - secondsAgo, 'mid': '<daily-1@x>', 'from': item.contactKey,
          });
      final card = find.byKey(const ValueKey('today-deliveries'));
      expect(tester.widget<Text>(find.descendant(of: card, matching: find.byKey(ValueKey('timely-title-${item.id}')))).data, 'Hard case and more');
      expect(tester.widget<Text>(find.descendant(of: card, matching: find.byKey(ValueKey('timely-under-${item.id}')))).data, 'Pollstar Shop');
      final title = tester.widget<Text>(find.byKey(ValueKey('timely-title-${item.id}'))).style!.fontSize!;
      expect(tester.widget<Text>(find.byKey(ValueKey('timely-under-${item.id}'))).style!.fontSize!, lessThan(title), reason: 'smaller print');
      // On its way: the first of three steps; the day it comes on the right.
      expect(tester.widget<Semantics>(find.byKey(ValueKey('timely-steps-${item.id}'))).properties.label, 'On its way');
      expect(tester.widget<Text>(find.byKey(ValueKey('timely-when-${item.id}'))).data, 'Tomorrow');

      // Out for delivery: the second step, and it says so.
      await tester.runAsync(() => later('out-for-delivery', 30));
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(find.byKey(ValueKey('timely-steps-${item.id}'))).properties.label, 'Out for delivery');
      expect(tester.widget<Text>(find.byKey(ValueKey('timely-under-${item.id}'))).data, 'Out for delivery · Pollstar Shop');
      expect(tester.widget<Text>(find.byKey(ValueKey('timely-when-${item.id}'))).data, 'Today');

      // Delivered: it stays on the card, marked "Delivered" in green, with the time.
      await tester.runAsync(() => later('delivered', 10));
      await tester.pumpAndSettle();
      expect(find.descendant(of: card, matching: find.byKey(ValueKey('timely-${item.id}'))), findsOneWidget, reason: 'it stays until midnight');
      expect(tester.widget<Semantics>(find.byKey(ValueKey('timely-steps-${item.id}'))).properties.label, 'Delivered');
      final delivered = tester.widget<Text>(find.byKey(ValueKey('timely-when-${item.id}')));
      expect([delivered.data, delivered.style!.color], ['Delivered', const Color(0xFF5FBF6B)]);
      expect(find.byKey(ValueKey('timely-at-${item.id}')), findsOneWidget);
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

/// A helper this device is in step with, that counts how often it is asked.
class _InStepHelper extends HelperSync {
  int rounds = 0;

  @override
  HelperLink build() => HelperLink(loaded: true, address: 'https://helper.test', deviceId: 1, deviceName: 'This PC', inStepAt: DateTime(2026, 11, 12, 15, 5));

  @override
  Future<void> syncNow() async {
    rounds++;
  }
}
