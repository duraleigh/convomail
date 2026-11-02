import 'package:convomail/app/destinations.dart';
import 'package:convomail/app/people_state.dart';
import 'package:convomail/app/timely_state.dart';
import 'package:convomail/domain/classifier.dart';
import 'package:convomail/domain/timely_extractor.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/classification_queries.dart';
import 'package:convomail/store/database.dart' hide ClassificationRule;
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/store/timely_queries.dart';
import 'package:convomail/sync/classification_service.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/sync/timely_service.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/screens/chats/people_list_pane.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    test('Gmail categories: read per page, stored per message, and decisive for senders without headers', () async {
      imap.capabilities = const ['X-GM-EXT-1'];
      final inbox = imap.folder('INBOX');
      final t = DateTime.now().subtract(const Duration(hours: 1));
      // A store that sends plain mail from an ordinary address: no list headers, nothing in the address.
      final a = inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('mark@vendorco.com', 'Mark at Vendorco'), to: const [me], subject: 'Checking in', date: t));
      final b = inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('mark@vendorco.com', 'Mark at Vendorco'), to: const [me], subject: 'New styles', date: t.add(const Duration(minutes: 5))));
      inbox.categories..[a] = 'updates'..[b] = 'promotions';
      for (final uid in inbox.messages.keys) {
        inbox.categories.putIfAbsent(uid, () => 'primary');
      }
      await sync();
      final vendor = await contact('mark@vendorco.com');
      expect(vendor.classification, 'feeds');
      expect(vendor.classReasons, contains('Gmail files this sender under'));
      expect((await contact('sarah@x.com')).classification, 'people');
      final stored = await (db.select(db.messages)..where((m) => m.fromAddress.equals('mark@vendorco.com'))).get();
      expect(stored.map((m) => m.providerCategory).toSet(), {'updates', 'promotions'});
      expect(imap.log.where((l) => l.startsWith('search ') && l.contains('X-GM-RAW')), isNotEmpty);
      expect(imap.log.where((l) => l.startsWith('search ') && l.contains('Sent')), isEmpty);
    });

    test('Gmail categories backfill once for mail synced before they were read', () async {
      await sync();
      expect((await db.select(db.messages).get()).every((m) => m.providerCategory == null), isTrue, reason: 'not a Gmail server');
      imap.capabilities = const ['X-GM-EXT-1'];
      for (final uid in imap.folder('INBOX').messages.keys) {
        imap.folder('INBOX').categories[uid] = 'updates';
      }
      imap.log.clear();
      await sync();
      final inbox = await (db.select(db.folders)..where((f) => f.role.equals('inbox'))).getSingle();
      final inboxMsgs = await (db.select(db.messages)..where((m) => m.folderId.equals(inbox.id))).get();
      expect(inboxMsgs.every((m) => m.providerCategory == 'updates'), isTrue);
      final searches = imap.log.where((l) => l.startsWith('search ')).length;
      imap.log.clear();
      await sync();
      expect(imap.log.where((l) => l.startsWith('search ')).length, lessThan(searches), reason: 'nothing left to backfill');
    });

    test('a re-decision cut short is finished by the next sync, without touching manual moves', () async {
      imap.capabilities = const ['X-GM-EXT-1'];
      await sync();
      final service = ClassificationService(db);
      await service.moveSender('hello@dailybrief.com', Bucket.people);
      // What storing categories for the backfill leaves behind when the pass
      // after it never runs.
      final inbox = (await db.select(db.folders).get()).firstWhere((f) => f.role == 'inbox');
      final uids = (await (db.select(db.messages)..where((m) => m.folderId.equals(inbox.id))).get()).map((m) => m.uid).toList()..sort();
      await db.storeProviderCategories(inbox.id, (uids.first, uids.last), {'updates': uids.toSet()}, redecide: true);
      expect((await contact('sarah@x.com')).classReasons, isEmpty);
      expect((await contact('hello@dailybrief.com')).classReasons, 'Moved by you');

      await sync();
      expect((await contact('sarah@x.com')).classReasons, isNotEmpty);
      expect((await contact('hello@dailybrief.com')).classification, 'people');
    });

    test('your own mail does not keep a Feeds sender in People; a reply to you still does', () async {
      imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('sarah@x.com')], subject: 'Hello', messageId: '<mine-2@example.com>', date: DateTime.now()));
      await sync();
      final service = ClassificationService(db);
      await service.moveSender('sarah@x.com', Bucket.feeds);
      await db.refreshDirtyRows();
      await db.customStatement("UPDATE messages SET classification = 'feeds' WHERE from_contact_key = 'sarah@x.com'");
      await db.markRowsDirty(['c:sarah@x.com']);
      await db.refreshDirtyRows();

      final people = await db.peopleRows();
      expect(people.map((r) => r.rowKey), isNot(contains('c:sarah@x.com')));
      final feeds = await db.peopleRows(tab: InboxTab.feeds);
      expect(feeds.firstWhere((r) => r.rowKey == 'c:sarah@x.com').onFeedsTab, isTrue);

      final messages = await (db.select(db.messageRowAssignments)..where((a) => a.rowKey.equals('c:sarah@x.com'))).get();
      final ids = messages.map((a) => a.messageId).toSet();
      final mine = (await db.select(db.messages).get()).where((m) => m.isFromMe && ids.contains(m.id));
      expect(mine, hasLength(1), reason: 'your sent message stays in that conversation');

      // The Shop's reply to the user is a People message on a Feeds sender.
      final rows = await db.peopleRows();
      final shop = rows.firstWhere((r) => r.rowKey == 'c:noreply@shop.com');
      expect(shop.isFeeds, isTrue);
      expect(shop.onFeedsTab, isFalse, reason: 'no category pill on People');
    });

    test('Gmail Updates mail gets a category of its own, not Newsletter for having bulk headers', () async {
      final inbox = imap.folder('INBOX');
      for (var i = 0; i < 2; i++) {
        final uid = inbox.add(RemoteMessageHeader(
          uid: 0,
          from: const RemoteAddress('support@tool.example', 'Tool'),
          to: const [me],
          subject: 'Your project status ${i + 1}',
          date: DateTime.now(),
          signals: const BulkSignals(listUnsubscribe: true),
        ));
        inbox.categories[uid] = 'updates';
      }
      imap.capabilities = const ['X-GM-EXT-1'];
      await sync();
      final c = await contact('support@tool.example');
      expect(c.classification, 'feeds');
      expect(c.feedsCategory, 'Updates');
      expect((await db.categoryNames()), contains('Updates'));
    });

    test('the upgrade to version 4 redoes chosen categories and keeps ones the user set', () async {
      await sync();
      final service = ClassificationService(db);
      await service.setSenderCategory('hello@dailybrief.com', 'Promotion');
      await db.customStatement("UPDATE contacts SET feeds_category = 'Social' WHERE key = 'noreply@bank.com'");
      await db.putSetting(ClassificationService.versionKey, '3');
      expect(await service.upgradeIfNeeded(), isTrue);
      while (await service.classifyPending() > 0) {}
      expect((await contact('hello@dailybrief.com')).feedsCategory, 'Promotion');
      expect((await contact('noreply@bank.com')).feedsCategory, 'Notification');
    });

    group('timely information', () {
      test('windows: only what is due shows, most urgent first', () {
        TimelyItem item(int id, String type, DateTime from, DateTime until, {DateTime? starts}) => TimelyItem(
              id: id, type: type, dedupeKey: '$id', contactKey: '', title: '', detail: '', showFrom: from, hideAfter: until, startsAt: starts, updatedAt: from,
            );
        final now = DateTime(2026, 11, 2, 12);
        final items = [
          item(1, 'delivery', now.subtract(const Duration(hours: 1)), now.add(const Duration(days: 1)), starts: now.add(const Duration(days: 1))),
          item(2, 'flight', now.subtract(const Duration(hours: 1)), now.add(const Duration(days: 1)), starts: now.add(const Duration(hours: 5))),
          item(3, 'code', now.subtract(const Duration(minutes: 1)), now.add(const Duration(minutes: 14))),
          item(4, 'bill', now.add(const Duration(days: 1)), now.add(const Duration(days: 3))),
          item(5, 'code', now.subtract(const Duration(hours: 1)), now.subtract(const Duration(minutes: 45))),
        ];
        expect(timelyDue(items, now).map((i) => i.id), [3, 2, 1]);
      });

      test('the waiting loop reads recent mail in the background, marks nothing read, and files automated senders to Feeds', () async {
        imap.capabilities = const [];
        final inbox = imap.folder('INBOX');
        final uid = inbox.add(
          RemoteMessageHeader(uid: 0, from: const RemoteAddress('mailer@acme.example', 'Acme'), to: const [me], subject: 'Your verification code', date: DateTime.now(), flags: const MessageFlagsState(seen: false)),
          body: const RemoteMessageBody(text: 'Your verification code is 482913.'),
        );
        final boring = inbox.add(
          RemoteMessageHeader(uid: 0, from: const RemoteAddress('friend@x.com', 'Friend'), to: const [me], subject: 'Lunch soon?', date: DateTime.now()),
          body: const RemoteMessageBody(text: 'Hi there'),
        );
        final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'), sleep: (_) async {});
        final running = syncer.run();
        await Future.doWhile(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return syncer.status.phase != SyncPhase.waitingForMail;
        }).timeout(const Duration(seconds: 5));
        await syncer.stop();
        await running.timeout(const Duration(seconds: 5));

        final item = (await db.select(db.timelyItems).get()).firstWhere((i) => i.contactKey == 'mailer@acme.example');
        expect(item.type, 'code');
        expect(item.code, '482913');
        final msgs = await db.select(db.messages).get();
        final code = msgs.firstWhere((m) => m.uid == uid && m.fromAddress == 'mailer@acme.example');
        expect(code.isSeen, isFalse, reason: 'reading in the background is not reading');
        expect(code.hasTimelyItem, isTrue);
        expect((await contact('mailer@acme.example')).classification, 'feeds');
        expect((await contact('mailer@acme.example')).classReasons, contains('Sends codes, shipping or travel updates'));
        expect(msgs.firstWhere((m) => m.uid == boring && m.fromAddress == 'friend@x.com').timelyCheckedAt, isNotNull);
        final brief = msgs.firstWhere((m) => m.fromAddress == 'hello@dailybrief.com');
        expect(brief.bodyFetchedAt, isNull, reason: 'an ordinary subject in Feeds is not downloaded');
        expect(brief.timelyCheckedAt, isNotNull);
        expect(msgs.where((m) => m.timelyCheckedAt == null && !m.isFromMe && (m.date?.isAfter(DateTime.now().subtract(const Duration(days: 29))) ?? false)), isEmpty);
      });

      test('mail from someone you write to is left alone, even with a code-shaped line', () async {
        await sync();
        final sarah = (await db.select(db.messages).get()).firstWhere((m) => m.fromAddress == 'sarah@x.com');
        await db.into(db.messageParticipants).insert(MessageParticipantsCompanion.insert(messageId: (await db.select(db.messages).get()).firstWhere((m) => m.isFromMe).id, address: 'sarah@x.com', contactKey: 'sarah@x.com', role: 'to'));
        await db.storeBody(sarah.id, const RemoteMessageBody(text: 'Your verification code is 112233, as a joke'));
        final service = TimelyService(db, ClassificationService(db));
        expect(await service.processMessage(sarah.id), 0);
        expect((await contact('sarah@x.com')).classification, 'people');
      });

      test('later mail updates the same item; a new status brings a dismissed one back', () async {
        await sync();
        final m = (await db.select(db.messages).get()).first;
        const key = 'parcel:1Z';
        await db.upsertTimely(m, const [TimelyFact(type: TimelyType.delivery, dedupeKey: key, title: 'Acme')], DateTime(2026, 11, 2));
        final first = (await db.select(db.timelyItems).get()).single;
        await db.dismissTimely(first.id);
        await db.upsertTimely(m, const [TimelyFact(type: TimelyType.delivery, dedupeKey: key, title: 'Acme')], DateTime(2026, 11, 2));
        expect((await db.select(db.timelyItems).get()).single.dismissedAt, isNotNull);
        await db.upsertTimely(m, const [TimelyFact(type: TimelyType.delivery, dedupeKey: key, title: 'Acme', status: 'out-for-delivery')], DateTime(2026, 11, 3));
        final now = (await db.select(db.timelyItems).get()).single;
        expect(now.dismissedAt, isNull);
        expect(now.status, 'out-for-delivery');
      });

      test('a greeting does not make a Gmail Updates or timely message personal', () {
        const c = Classifier(rules: [], userFirstNames: {'clay'});
        expect(c.isPersonalException(const MessageFacts(from: 'a@b.c', snippet: 'Hi Clay, your order shipped')), isTrue, reason: 'no other evidence');
        expect(c.isPersonalException(const MessageFacts(from: 'a@b.c', snippet: 'Hi Clay, your order shipped', providerCategory: 'updates')), isFalse);
        expect(c.isPersonalException(const MessageFacts(from: 'a@b.c', snippet: 'Hi Clay, your code', hasTimelyItem: true)), isFalse);
      });
    });

    test('a classifier upgrade redoes automatic decisions once and keeps manual moves', () async {
      await sync();
      final service = ClassificationService(db);
      await service.moveSender('hello@dailybrief.com', Bucket.people);
      expect(await service.upgradeIfNeeded(), isTrue);
      expect((await contact('noreply@bank.com')).classReasons, isEmpty);
      expect((await contact('hello@dailybrief.com')).classReasons, 'Moved by you');
      expect(await service.upgradeIfNeeded(), isFalse, reason: 'only once');
      while (await service.classifyPending() > 0) {}
      expect((await contact('noreply@bank.com')).classification, 'feeds');
      expect((await contact('hello@dailybrief.com')).classification, 'people');
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

    testWidgets('the strip shows a code to copy without opening; Feeds rows offer it; X dismisses; nothing timely takes no room', (tester) async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      String? copied;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final container = await pumpApp(tester);
      expect(find.byKey(const ValueKey('timely-strip')), findsNothing);

      final bank = (await db.select(db.messages).get()).firstWhere((m) => m.fromAddress == 'noreply@bank.com');
      await db.upsertTimely(bank, const [TimelyFact(type: TimelyType.code, dedupeKey: 'code:bank', title: 'First Bank', code: '482913')], DateTime.now());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timely-strip')), findsOneWidget);
      expect(find.text('482913'), findsOneWidget);

      final item = (await db.select(db.timelyItems).get()).single;
      await tester.tap(find.byKey(ValueKey('timely-copy-${item.id}')));
      await tester.pumpAndSettle();
      expect(copied, '482913');
      expect(find.textContaining('Code copied'), findsOneWidget);
      expect(container.read(selectedRowProvider), isNull, reason: 'copying does not open the email');

      container.read(destinationProvider.notifier).select(Destination.feeds);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('row-code-c:noreply@bank.com')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('timely-dismiss-${item.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timely-strip')), findsNothing);
      await teardown(tester);
    });

    testWidgets('category pills show on Feeds only, filter the list, count per-message exceptions, and clear', (tester) async {
      final container = await pumpApp(tester);
      expect(find.byKey(const ValueKey('feeds-pill-all')), findsNothing, reason: 'not on Chats');

      container.read(destinationProvider.notifier).select(Destination.feeds);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feeds-pill-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('feeds-pill-Newsletter')), findsOneWidget);
      expect(find.byKey(const ValueKey('feeds-pill-Social')), findsNothing, reason: 'no mail in that category');
      expect(find.text('The Daily Brief'), findsOneWidget);
      expect(find.text('First Bank'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('feeds-pill-Newsletter')));
      await tester.pumpAndSettle();
      expect(find.text('The Daily Brief'), findsOneWidget);
      expect(find.text('First Bank'), findsNothing);

      // One message of the bank's filed as Newsletter brings the bank in too.
      final bank = (await db.select(db.messages).get()).firstWhere((m) => m.fromAddress == 'noreply@bank.com');
      await ClassificationService(db).setMessageCategory(bank.id, 'Newsletter');
      await tester.pumpAndSettle();
      expect(find.text('First Bank'), findsOneWidget);
      expect(find.byKey(const ValueKey('category-pill-c:noreply@bank.com')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('feeds-pill-all')));
      await tester.pumpAndSettle();
      expect(container.read(feedsCategoryFilterProvider), isNull);

      // A category that empties falls back to All.
      container.read(feedsCategoryFilterProvider.notifier).select('Notification');
      await tester.pumpAndSettle();
      final cats = await db.select(db.feedsCategoryRows).get();
      await db.deleteCategory(cats.firstWhere((c) => c.name == 'Notification').id);
      await tester.pumpAndSettle();
      expect(container.read(feedsCategoryFilterProvider), isNull);
      await teardown(tester);
    });

    testWidgets('the Feeds rail badge counts unread Feeds mail and hides at zero', (tester) async {
      await pumpApp(tester);
      final badge = find.descendant(of: find.byType(NavigationRail), matching: find.byKey(const ValueKey('feeds-badge')));
      Badge widget() => tester.widget<Badge>(badge);
      final unread = (await db.select(db.messages).get()).where((m) => m.classification == 'feeds' && !m.isSeen && !m.isFromMe).length;
      expect(unread, greaterThan(0));
      expect(widget().isLabelVisible, isTrue);
      expect(find.descendant(of: badge, matching: find.text('$unread')), findsOneWidget);

      await db.update(db.messages).write(const MessagesCompanion(isSeen: Value(true)));
      await db.refreshDirtyRows();
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(widget().isLabelVisible, isFalse);
      await teardown(tester);
    });

    testWidgets('Chats and Feeds each remember their open conversation; openRow lands in the right one', (tester) async {
      final container = await pumpApp(tester);
      await tester.tap(find.text('Sarah Chen'));
      await tester.pumpAndSettle();
      expect(container.read(selectedRowProvider), 'c:sarah@x.com');

      container.read(destinationProvider.notifier).select(Destination.feeds);
      await tester.pumpAndSettle();
      expect(container.read(selectedRowProvider), isNull);
      await tester.tap(find.text('The Daily Brief'));
      await tester.pumpAndSettle();
      expect(find.text('Sarah Chen'), findsNothing);

      container.read(destinationProvider.notifier).select(Destination.chats);
      await tester.pumpAndSettle();
      expect(container.read(selectedRowProvider), 'c:sarah@x.com');

      await openRow(container.read, 'c:noreply@bank.com');
      await tester.pumpAndSettle();
      expect(container.read(destinationProvider), Destination.feeds);
      expect(container.read(selectedRowProvider), 'c:noreply@bank.com');

      await openRow(container.read, 'c:sarah@x.com');
      await tester.pumpAndSettle();
      expect(container.read(destinationProvider), Destination.chats);
      await teardown(tester);
    });

    testWidgets('the filed banner can be dismissed until next week, and that survives a restart', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const ValueKey('feeds-banner')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('feeds-banner-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feeds-banner')), findsNothing);
      expect(await db.getSetting(feedsBannerDismissedKey), feedsBannerWeek(DateTime.now()));

      await teardown(tester);
      await pumpApp(tester);
      expect(find.byKey(const ValueKey('feeds-banner')), findsNothing, reason: 'same week, still dismissed');

      await teardown(tester);
      await db.putSetting(feedsBannerDismissedKey, '2020-01-06');
      await pumpApp(tester);
      expect(find.byKey(const ValueKey('feeds-banner')), findsOneWidget, reason: 'a new week brings it back');
      await teardown(tester);
    });

    test('banner weeks run Monday to Sunday', () {
      expect(feedsBannerWeek(DateTime(2026, 11, 1, 23)), '2026-10-26', reason: 'a Sunday belongs to the week before');
      expect(feedsBannerWeek(DateTime(2026, 11, 2, 0, 1)), '2026-11-02');
      expect(feedsBannerWeek(DateTime(2026, 11, 8)), '2026-11-02');
      expect(feedsBannerWeek(DateTime(2027, 1, 1)), '2026-12-28', reason: 'across a year end');
    });

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
      container.read(destinationProvider.notifier).select(Destination.feeds);
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
      container.read(destinationProvider.notifier).select(Destination.chats);
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
