import 'dart:convert';

import 'package:convomail/app/destinations.dart';
import 'package:convomail/app/mail_state.dart';
import 'package:convomail/app/people_state.dart';
import 'package:convomail/app/timely_state.dart';
import 'package:convomail/domain/classifier.dart';
import 'package:convomail/domain/piles.dart';
import 'package:convomail/domain/timely_extractor.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/classification_queries.dart';
import 'package:convomail/store/database.dart' hide ClassificationRule;
import 'package:convomail/store/helper_queries.dart';
import 'package:convomail/store/mail_queries.dart';
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
import 'package:drift/drift.dart' show Value, Variable;
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
/// split into Chats, Feed and Noise, and corrections propose a rule.
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
      expect(msgs.firstWhere((m) => m.subject.contains('verification')).feedsCategory, 'OTP', reason: 'a code, unlike the rest of the bank mail');
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

    test('mail Gmail files a little late moves to Feeds on the next check, not the next start', () async {
      imap.capabilities = const ['X-GM-EXT-1'];
      final inbox = imap.folder('INBOX');
      for (final uid in inbox.messages.keys) {
        inbox.categories.putIfAbsent(uid, () => 'primary');
      }
      await sync();
      // A support desk writing from a plain address, no list headers, no
      // name; Gmail has not filed the message yet when it is first read.
      final fi = inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('googlefi-support@google.example'), to: const [me], subject: 'Your Fi Support case', date: DateTime.now()));
      await sync();
      expect((await contact('googlefi-support@google.example')).classification, 'people', reason: 'nothing to go on yet');

      inbox.categories[fi] = 'updates';
      await sync();
      expect((await contact('googlefi-support@google.example')).classification, 'feeds');
      final m = (await db.messagesFromSender('googlefi-support@google.example')).single;
      expect(m.providerCategory, 'updates');
      expect(m.classification, 'feeds');
    });

    test('new mail is not listed until it is sorted', () async {
      await sync();
      final inbox = await (db.select(db.folders)..where((f) => f.role.equals('inbox'))).getSingle();
      final filing = await db.loadFilingRule();
      final before = (await db.peopleRows()).map((r) => r.rowKey).toSet();
      await db.whileSorting(() async {
        await db.upsertHeaders(inbox.accountId, inbox.id, [
          RemoteMessageHeader(uid: 9001, from: const RemoteAddress('alerts@shop.example'), to: const [me], subject: 'Your order shipped', date: DateTime.now(), signals: const BulkSignals(listUnsubscribe: true, listId: true)),
        ], filing);
        expect((await db.peopleRows()).map((r) => r.rowKey).toSet(), before, reason: 'not in Chats while unsorted');
        await ClassificationService(db).classifySenders(['alerts@shop.example']);
      });
      expect((await db.peopleRows()).map((r) => r.rowKey), isNot(contains('c:alerts@shop.example')));
      expect((await db.peopleRows(tab: InboxTab.feeds)).map((r) => r.rowKey), contains('c:alerts@shop.example'));
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

      test('a delivered package stays until the end of the day it came, also one stored by an older version', () {
        final came = DateTime(2026, 11, 2, 10, 30);
        // As an older version stored it: off its card the moment it was delivered.
        final old = TimelyItem(id: 1, type: 'delivery', dedupeKey: 'p', contactKey: '', title: 'Acme', detail: '', status: 'delivered', showFrom: came, hideAfter: came, mailAt: came, updatedAt: came);
        expect(timelyDue([old], DateTime(2026, 11, 2, 12)).map((i) => i.id), [1]);
        expect(timelyDue([old], DateTime(2026, 11, 2, 23, 59)).map((i) => i.id), [1]);
        expect(timelyDue([old], DateTime(2026, 11, 3)), isEmpty, reason: 'gone at midnight');
        // Anything else still ends when its window does.
        final code = TimelyItem(id: 2, type: 'code', dedupeKey: 'c', contactKey: '', title: '', detail: '', showFrom: came, hideAfter: came, updatedAt: came);
        expect(timelyDue([code], DateTime(2026, 11, 2, 12)), isEmpty);
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
        expect(brief.bodyFetchedAt, isNotNull, reason: 'its words are fetched ahead of time, so opening it never waits on a download');
        expect(brief.isSeen, isFalse, reason: 'and that marks nothing read');
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

      test('the same cards on every device: what is found here is told to the helper; what another device found shows here; the newer email wins in any order', () async {
        await sync();
        await db.setHelperConnected(true);
        final m = (await db.select(db.messages).get()).firstWhere((x) => !x.isFromMe);
        await db.customStatement("UPDATE messages SET message_id = '<parcel-1@x>' WHERE id = ?", [m.id]);
        final mail = (await db.select(db.messages).get()).firstWhere((x) => x.id == m.id);
        Future<List<String>> waiting(String kind) async => [for (final r in await db.customSelect('SELECT k, data FROM helper_outbox WHERE kind = ? ORDER BY id', variables: [Variable.withString(kind)]).get()) '${r.read<String>('k')} ${r.read<String>('data')}'];
        int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
        final monday = DateTime(2026, 11, 9, 9);
        final tuesday = DateTime(2026, 11, 10, 9);
        final arrives = DateTime(2026, 11, 12);
        final arrivesLater = DateTime(2026, 11, 13);

        // Found here, in Tuesday's email: told to the helper as it stands, with how new its email is.
        await db.upsertTimely(mail, [TimelyFact(type: TimelyType.delivery, dedupeKey: 'parcel:1Z9', title: 'Acme', startsAt: arrivesLater, actionUrl: 'https://track.example/1Z9', actionLabel: 'Track')], tuesday);
        final told = jsonDecode((await waiting('timely')).single.substring('parcel:1Z9 '.length)) as Map;
        expect([told['type'], told['title'], told['starts'], told['url'], told['mat'], told['mid'], told['from']], ['delivery', 'Acme', secs(arrivesLater), 'https://track.example/1Z9', secs(tuesday), '<parcel-1@x>', mail.fromContactKey]);
        // A sign-in code is never told: the helper keeps no copy of one.
        await db.upsertTimely(mail, [const TimelyFact(type: TimelyType.code, dedupeKey: 'code:1', title: 'Acme', code: '482913')], tuesday);
        expect((await waiting('timely')).length, 1);
        await db.delete(db.helperOutbox).go();

        // Monday's email about the same parcel, read afterwards (here, or on another device): the newer email's word stands.
        await db.upsertTimely(mail, [TimelyFact(type: TimelyType.delivery, dedupeKey: 'parcel:1Z9', title: 'Acme', startsAt: arrives)], monday);
        await db.applyingFromHelper(() => db.applyHelperItem('timely', 'parcel:1Z9', {'type': 'delivery', 'title': 'Acme', 'detail': '', 'starts': secs(arrives), 'mat': secs(monday), 'mid': '<parcel-0@x>', 'from': mail.fromContactKey}, deleted: false));
        var item = (await db.select(db.timelyItems).get()).firstWhere((t) => t.dedupeKey == 'parcel:1Z9');
        expect(item.startsAt, arrivesLater);
        expect(await waiting('timely'), isEmpty, reason: 'nothing changed, so nothing is told');

        // Another device found a payment in an email this device does not hold: it shows here all the same.
        final due = DateTime.now().add(const Duration(days: 2));
        final bill = {'type': 'bill', 'title': 'Power Co', 'detail': r'$84.12 due', 'starts': secs(due), 'mat': secs(DateTime.now().subtract(const Duration(days: 8))), 'mid': '<not-here@x>', 'from': 'billing@power.example', 'until': secs(due) + 86400};
        await db.applyingFromHelper(() => db.applyHelperItem('timely', 'bill:power:1', bill, deleted: false));
        final shown = timelyDue(await db.watchTimelyItems().first, DateTime.now(), card: FyiCard.payments);
        expect([for (final t in shown) '${t.title} ${t.detail}'], [r'Power Co $84.12 due']);
        expect(shown.single.messageId, isNull);
        expect(await waiting('timely'), isEmpty, reason: 'what the helper said is not said back to it');
        // Told the same again (the whole list is taken in again after an upgrade): nothing is written.
        final before = (await db.select(db.timelyItems).get()).firstWhere((t) => t.dedupeKey == 'bill:power:1').updatedAt;
        await db.applyingFromHelper(() => db.applyHelperItem('timely', 'bill:power:1', bill, deleted: false));
        expect((await db.select(db.timelyItems).get()).firstWhere((t) => t.dedupeKey == 'bill:power:1').updatedAt, before);

        // Dismissed here: every device is told. Dismissed elsewhere: gone here too. Put off elsewhere: the same.
        item = (await db.select(db.timelyItems).get()).firstWhere((t) => t.dedupeKey == 'parcel:1Z9');
        await db.dismissTimely(item.id);
        expect(await waiting('cardfix'), ['timely:parcel:1Z9 {"off":true}']);
        await db.undismissTimely(item.id);
        expect(await waiting('cardfix'), ['timely:parcel:1Z9 {"off":false}']);
        await db.applyingFromHelper(() => db.applyHelperItem('cardfix', 'timely:bill:power:1', {'off': true}, deleted: false));
        expect(timelyDue(await db.watchTimelyItems().first, DateTime.now(), card: FyiCard.payments), isEmpty);
        final later = DateTime.now().add(const Duration(hours: 5));
        await db.applyingFromHelper(() => db.applyHelperItem('cardfix', 'timely:bill:power:1', {'off': false, 'later': secs(later)}, deleted: false));
        final back = (await db.select(db.timelyItems).get()).firstWhere((t) => t.dedupeKey == 'bill:power:1');
        expect([back.dismissedAt, secs(back.laterUntil!)], [null, secs(later)]);
        // A code's dismissal stays on the device it was dismissed on.
        await db.delete(db.helperOutbox).go();
        await db.dismissTimely((await db.select(db.timelyItems).get()).firstWhere((t) => t.type == 'code').id);
        expect(await waiting('cardfix'), isEmpty);
        // Forgotten by the helper once it is long past: forgotten here.
        await db.applyingFromHelper(() => db.applyHelperItem('timely', 'bill:power:1', const {}, deleted: true));
        expect((await db.select(db.timelyItems).get()).where((t) => t.dedupeKey == 'bill:power:1'), isEmpty);
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

    test('an older install gets Delivery, Travel and OTP after Receipt, once', () async {
      for (final n in ['Delivery', 'Travel', 'OTP']) {
        final c = (await db.watchCategories().first).where((c) => c.name == n).firstOrNull;
        if (c != null) await db.deleteCategory(c.id);
      }
      await db.addTravelDeliveryOtpCategories();
      await db.addTravelDeliveryOtpCategories();
      final names = await db.categoryNames();
      final r = names.indexOf('Receipt');
      expect(names.sublist(r, r + 4), ['Receipt', 'Delivery', 'Travel', 'OTP']);
      expect(names.where((n) => n == 'OTP'), hasLength(1));
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
          child: const PrecisApp(startSync: false),
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

    testWidgets('the OTP card shows a code to copy without opening the email; the Feed row offers it too; the x dismisses; Chats carries no strip', (tester) async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      String? copied;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final container = await pumpApp(tester);
      final bank = (await db.select(db.messages).get()).firstWhere((m) => m.fromAddress == 'noreply@bank.com');
      await db.upsertTimely(bank, const [TimelyFact(type: TimelyType.code, dedupeKey: 'code:bank', title: 'First Bank', code: '482913')], DateTime.now());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timely-strip')), findsNothing, reason: 'the strip left Chats for Today');

      container.read(destinationProvider.notifier).select(Destination.today);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-otp')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('today-otp')), matching: find.text('OTP')), findsOneWidget);
      expect(find.byKey(const ValueKey('timely-strip-otp')), findsOneWidget);
      expect(find.text('482913'), findsOneWidget);
      for (final other in ['travel', 'bookings', 'deliveries', 'payments', 'fyi']) {
        expect(find.byKey(ValueKey('today-$other')), findsNothing, reason: 'a card with nothing in it is not drawn: $other');
      }

      final item = (await db.select(db.timelyItems).get()).single;
      await tester.tap(find.byKey(ValueKey('timely-copy-${item.id}')));
      await tester.pumpAndSettle();
      expect(copied, '482913');
      expect(find.textContaining('Code copied'), findsOneWidget);
      expect(container.read(selectedRowProvider), isNull, reason: 'copying does not open the email');

      container.read(destinationProvider.notifier).select(Destination.feed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('row-code-c:noreply@bank.com')), findsOneWidget);
      expect(find.byKey(const ValueKey('timely-strip')), findsNothing, reason: 'no strip on Feed either');

      container.read(destinationProvider.notifier).select(Destination.today);
      await tester.pumpAndSettle();
      // The small x shows only while the mouse is over the line.
      double x() => tester.widget<Opacity>(find.ancestor(of: find.byKey(ValueKey('timely-dismiss-${item.id}')), matching: find.byType(Opacity)).first).opacity;
      expect(x(), 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('timely-title-${item.id}'))));
      await tester.pumpAndSettle();
      expect(x(), 1);
      await tester.tap(find.byKey(ValueKey('timely-dismiss-${item.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timely-strip-otp')), findsNothing);
      expect(find.byKey(const ValueKey('today-otp')), findsNothing, reason: 'the card goes with its last item');
      await teardown(tester);
    });

    testWidgets('what the rules find sits on its own card: Deliveries holds a delivery, Payments holds a bill, OTP holds "confirm your email address" with its button; each item has the menu', (tester) async {
      final container = await pumpApp(tester);
      final all = await db.select(db.messages).get();
      final bank = all.firstWhere((m) => m.fromAddress == 'noreply@bank.com');
      final now = DateTime.now();
      await db.upsertTimely(bank, [
        TimelyFact(type: TimelyType.delivery, dedupeKey: 'track:1', title: 'Acme Shop', startsAt: now.add(const Duration(days: 1))),
        TimelyFact(type: TimelyType.bill, dedupeKey: 'bill:1', title: 'Power Co', startsAt: now.add(const Duration(days: 2)), detail: r'$84.12'),
        const TimelyFact(type: TimelyType.confirm, dedupeKey: 'confirm:1', title: 'Acme Shop', actionUrl: 'https://acme.example/confirm?t=abc', actionLabel: 'Confirm'),
      ], now);
      container.read(destinationProvider.notifier).select(Destination.today);
      await tester.pumpAndSettle();
      final items = {for (final t in await db.select(db.timelyItems).get()) t.type: t};

      // Deliveries: the assistant is not on here, so nothing says what is inside: it is headed by who sent it, with the day it comes on the right.
      final deliveries = find.byKey(const ValueKey('today-deliveries'));
      expect(find.descendant(of: deliveries, matching: find.text('DELIVERIES')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(ValueKey('timely-title-${items['delivery']!.id}'))).data, 'Acme Shop');
      expect(find.byKey(ValueKey('timely-under-${items['delivery']!.id}')), findsNothing);
      expect(tester.widget<Text>(find.descendant(of: deliveries, matching: find.byKey(ValueKey('timely-when-${items['delivery']!.id}')))).data, 'Tomorrow');
      // Payments: who is owed, when it is due, and the amount on the right.
      final bill = items['bill']!;
      expect(find.descendant(of: find.byKey(const ValueKey('today-payments')), matching: find.byKey(ValueKey('timely-${bill.id}'))), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(ValueKey('timely-title-${bill.id}'))).data, 'Power Co');
      expect(tester.widget<Text>(find.byKey(ValueKey('timely-under-${bill.id}'))).data, startsWith('Due '));
      expect(tester.widget<Text>(find.byKey(ValueKey('timely-when-${bill.id}'))).data, r'$84.12');
      // OTP: confirm your email address, with the button that goes to the email's own link.
      final otp = find.byKey(const ValueKey('today-otp'));
      expect(find.descendant(of: otp, matching: find.text('Confirm your email address')), findsOneWidget);
      expect(find.descendant(of: otp, matching: find.text('for Acme Shop')), findsOneWidget);
      expect(find.descendant(of: otp, matching: find.widgetWithText(FilledButton, 'Confirm')), findsOneWidget);
      for (final none in ['travel', 'bookings', 'fyi']) {
        expect(find.byKey(ValueKey('today-$none')), findsNothing, reason: none);
      }

      // The menu on an item: Dismiss, Later, Does not belong here.
      final delivery = items['delivery']!;
      await tester.tap(find.byKey(ValueKey('timely-${delivery.id}')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-dismiss')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-reject')), findsOneWidget);
      // Later: off the card until then, and Undo brings it straight back.
      await tester.tap(find.byKey(const ValueKey('menu-later')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('snooze-Tomorrow morning')));
      await tester.pumpAndSettle();
      expect(deliveries, findsNothing);
      expect(find.textContaining('It comes back to Deliveries then'), findsOneWidget);
      expect((await db.select(db.timelyItems).get()).firstWhere((t) => t.id == delivery.id).laterUntil, isNotNull);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(deliveries, findsOneWidget);
      // A press and hold opens the same menu; Dismiss takes it off, with Undo.
      await tester.longPress(find.byKey(ValueKey('timely-${delivery.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-dismiss')));
      await tester.pumpAndSettle();
      expect(deliveries, findsNothing);
      expect(find.text('Taken off Deliveries.'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('tag pills show on Feed for the mail in it, filter the list, follow a tag set on one email, and clear', (tester) async {
      final container = await pumpApp(tester);
      expect(find.byKey(const ValueKey('feeds-pill-all')), findsNothing, reason: 'not on Chats');

      container.read(destinationProvider.notifier).select(Destination.feed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feeds-pill-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('feeds-pill-Receipt')), findsOneWidget);
      expect(find.byKey(const ValueKey('feeds-pill-Delivery')), findsOneWidget);
      expect(find.byKey(const ValueKey('feeds-pill-Newsletter')), findsNothing, reason: 'the newsletter is in Noise');
      expect(find.byKey(const ValueKey('feeds-pill-Social')), findsNothing, reason: 'no mail with that tag');
      expect(find.text('First Bank'), findsWidgets, reason: 'a row for each of its emails');
      expect(find.text('Shop Orders'), findsWidgets);
      expect(find.text('The Daily Brief'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('feeds-pill-Receipt')));
      await tester.pumpAndSettle();
      expect(find.text('First Bank'), findsOneWidget, reason: 'its statement is a receipt; its code is not');
      expect(find.text('Shop Orders'), findsNothing);

      // One email of the shop's tagged as a receipt shows under Receipts; its others do not.
      final shop = (await db.select(db.messages).get()).firstWhere((m) => m.fromAddress == 'noreply@shop.com' && m.subject.contains('shipped'));
      await ClassificationService(db).setMessageCategory(shop.id, 'Receipt');
      await tester.pumpAndSettle();
      expect(find.text('Shop Orders'), findsOneWidget);
      expect(find.byKey(ValueKey('category-pill-${shop.id}')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('feeds-pill-all')));
      await tester.pumpAndSettle();
      expect(container.read(mailTagProvider('feed')), isNull);

      // A tag that empties shows everything again.
      container.read(mailTagProvider('feed').notifier).select('OTP');
      await tester.pumpAndSettle();
      expect(find.text('Shop Orders'), findsNothing);
      final cats = await db.select(db.feedsCategoryRows).get();
      await db.deleteCategory(cats.firstWhere((c) => c.name == 'OTP').id);
      await tester.pumpAndSettle();
      expect(find.text('Shop Orders'), findsWidgets);

      // Noise lists its own mail, by sender.
      container.read(destinationProvider.notifier).select(Destination.noise);
      await tester.pumpAndSettle();
      expect(find.text('The Daily Brief'), findsOneWidget);
      expect(find.text('First Bank'), findsNothing);
      await teardown(tester);
    });

    testWidgets('the Feed icon shows a plain dot for mail new since Feed was last open, and no count; Noise never lights it', (tester) async {
      final container = await pumpApp(tester);
      final badge = find.descendant(of: find.byType(NavigationRail), matching: find.byKey(const ValueKey('feeds-badge')));
      Badge widget() => tester.widget<Badge>(badge);
      Future<void> arrive(String address, String name, String subject, {BulkSignals? signals}) async {
        imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: RemoteAddress(address, name), to: const [me], subject: subject, date: DateTime.now().add(const Duration(minutes: 1)), signals: signals ?? const BulkSignals()));
        await sync();
        await tester.pumpAndSettle();
      }

      expect(widget().isLabelVisible, isFalse, reason: 'what was already there on the first day is not new');
      expect(widget().label, isNull, reason: 'a dot, not a number');

      await arrive('hello@dailybrief.com', 'The Daily Brief', 'Daily Brief #103', signals: const BulkSignals(listUnsubscribe: true, listId: true, listIdValue: 'brief.dailybrief.com'));
      expect(widget().isLabelVisible, isFalse, reason: 'Noise has no dot');

      await arrive('noreply@bank.com', 'First Bank', 'A new sign-in to your account');
      expect(widget().isLabelVisible, isTrue, reason: 'new in Feed since it was last open');
      expect(widget().label, isNull);

      container.read(destinationProvider.notifier).select(Destination.feed);
      await tester.pumpAndSettle();
      container.read(destinationProvider.notifier).select(Destination.chats);
      await tester.pumpAndSettle();
      expect(widget().isLabelVisible, isFalse, reason: 'seen');
      expect(await db.getSetting('feed.seenAt'), isNotNull, reason: 'kept, so the dot stays off after a restart');
      await teardown(tester);
    });

    testWidgets('Chats, Feed and Noise each remember what was open; openRow lands in the right one', (tester) async {
      final container = await pumpApp(tester);
      await tester.tap(find.text('Sarah Chen'));
      await tester.pumpAndSettle();
      expect(container.read(selectedRowProvider), 'c:sarah@x.com');

      container.read(destinationProvider.notifier).select(Destination.feed);
      await tester.pumpAndSettle();
      expect(container.read(openMailProvider('feed')), isNull);
      final statement = (await db.messagesFromSender('noreply@bank.com')).firstWhere((m) => m.subject.contains('statement'));
      await tester.tap(find.byKey(ValueKey('mail-row-${statement.id}')));
      await tester.pumpAndSettle();
      expect(container.read(openMailProvider('feed')), statement.id);
      expect(find.text('Sarah Chen'), findsNothing);

      container.read(destinationProvider.notifier).select(Destination.noise);
      await tester.pumpAndSettle();
      expect(container.read(openNoiseGroupProvider), isNull);

      container.read(destinationProvider.notifier).select(Destination.chats);
      await tester.pumpAndSettle();
      expect(container.read(selectedRowProvider), 'c:sarah@x.com');

      container.read(destinationProvider.notifier).select(Destination.feed);
      await tester.pumpAndSettle();
      expect(container.read(openMailProvider('feed')), statement.id);

      // A sender opened from elsewhere lands in its list, on its row.
      await openRow(container.read, 'c:hello@dailybrief.com');
      await tester.pumpAndSettle();
      expect(container.read(destinationProvider), Destination.noise);
      expect(container.read(openNoiseGroupProvider), 's:hello@dailybrief.com');

      container.read(openMailProvider('feed').notifier).open(null);
      await openRow(container.read, 'c:noreply@bank.com');
      await tester.pumpAndSettle();
      expect(container.read(destinationProvider), Destination.feed);
      final bankIds = {for (final m in await db.messagesFromSender('noreply@bank.com')) m.id};
      expect(bankIds, contains(container.read(openMailProvider('feed'))), reason: 'the sender\'s newest email is opened');

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

    testWidgets('Chats hides senders that are not people and shows the filed banner; Feed and Noise show their mail with its tag', (tester) async {
      final container = await pumpApp(tester);
      expect(find.text('Sarah Chen'), findsOneWidget);
      expect(find.text('The Daily Brief'), findsNothing);
      expect(find.text('First Bank'), findsNothing);
      expect(find.byKey(const ValueKey('feeds-banner')), findsOneWidget);
      expect(find.textContaining('filed to Feed and Noise this week'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('feeds-banner')));
      await tester.pumpAndSettle();
      expect(container.read(destinationProvider), Destination.feed);
      expect(find.text('First Bank'), findsWidgets);
      expect(find.text('Worth knowing. Nothing here needs a reply.'), findsOneWidget);
      expect(find.byTooltip('Receipt'), findsWidgets, reason: 'the tag is a colored dot, named on hover');
      expect(find.text('Sarah Chen'), findsNothing);
      expect(find.text('The Daily Brief'), findsNothing, reason: 'a newsletter is Noise until something says otherwise');

      container.read(destinationProvider.notifier).select(Destination.noise);
      await tester.pumpAndSettle();
      expect(find.text('The Daily Brief'), findsOneWidget, reason: 'one row for the sender, however many emails');
      expect(find.textContaining('3 this week'), findsOneWidget);
      expect(find.byTooltip('Newsletter'), findsOneWidget);
      expect(find.byKey(const ValueKey('noise-header')), findsOneWidget);
      expect(find.text('First Bank'), findsNothing);
      await teardown(tester);
    });

    testWidgets('one email moved to Feed by hand shows in Feed; the rest of that sender\'s mail stays in Noise', (tester) async {
      final container = await pumpApp(tester);
      final brief = await db.messagesFromSender('hello@dailybrief.com');
      await db.setEmailPile(brief.first.id, FeedsPile.feed);
      container.read(destinationProvider.notifier).select(Destination.feed);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('mail-row-${brief.first.id}')), findsOneWidget);
      expect(find.text('The Daily Brief'), findsOneWidget, reason: 'only the one moved');
      container.read(destinationProvider.notifier).select(Destination.noise);
      await tester.pumpAndSettle();
      expect(find.text('The Daily Brief'), findsOneWidget);
      expect(find.textContaining('2 this week'), findsOneWidget, reason: 'the other two are still here');
      await teardown(tester);
    });

    testWidgets('a sender is moved between Chats, Feed and Noise for good; Undo puts it back; Counts toward unread shows the bell', (tester) async {
      final container = await pumpApp(tester);
      container.read(destinationProvider.notifier).select(Destination.noise);
      await tester.pumpAndSettle();

      // Noise to Feed: the user's choice, kept.
      await tester.tap(find.byKey(const ValueKey('noise-row-s:hello@dailybrief.com')));
      await tester.pumpAndSettle();
      expect(find.text('Why this is in Noise'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('noise-to-feed')));
      await tester.pumpAndSettle();
      expect((await contact('hello@dailybrief.com')).feedsPile, 'feed');
      expect((await contact('hello@dailybrief.com')).classification, 'feeds');
      expect(find.textContaining('moved to Feed'), findsOneWidget);
      expect(find.byKey(const ValueKey('noise-row-s:hello@dailybrief.com')), findsNothing, reason: 'gone from Noise');

      // Undo: back to where the app had it.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect((await contact('hello@dailybrief.com')).feedsPile, isNull);
      expect(find.byKey(const ValueKey('noise-row-s:hello@dailybrief.com')), findsOneWidget);

      // On a Feed email: its sender counts toward unread, then goes to Noise.
      container.read(destinationProvider.notifier).select(Destination.feed);
      await tester.pumpAndSettle();
      final statement = (await db.messagesFromSender('noreply@bank.com')).firstWhere((m) => m.subject.contains('statement'));
      await tester.tap(find.byKey(ValueKey('mail-row-${statement.id}')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Move this one to Noise'), findsOneWidget);
      await tester.tap(find.text('Counts toward unread'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Counts toward unread'), findsWidgets);
      await tester.tap(find.byKey(ValueKey('mail-row-${statement.id}')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Always Noise for this sender'));
      await tester.pumpAndSettle();
      expect((await contact('noreply@bank.com')).feedsPile, 'noise');
      expect(find.text('First Bank'), findsNothing);
      // New mail from it does not move it back.
      imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('noreply@bank.com', 'First Bank'), to: const [me], subject: 'Another statement', date: DateTime.now()));
      await sync();
      await tester.pumpAndSettle();
      expect((await contact('noreply@bank.com')).feedsPile, 'noise');
      expect(find.text('First Bank'), findsNothing);

      // Noise to Chats.
      container.read(destinationProvider.notifier).select(Destination.noise);
      await tester.pumpAndSettle();
      // Let the earlier message about the move go first.
      ScaffoldMessenger.of(tester.element(find.byType(AppShell))).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('noise-row-s:hello@dailybrief.com')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('noise-person')));
      await tester.pumpAndSettle();
      expect((await contact('hello@dailybrief.com')).classificationSource, 'override');
      expect((await contact('hello@dailybrief.com')).classification, 'people');
      expect(find.textContaining('moved to Chats'), findsOneWidget);
      container.read(destinationProvider.notifier).select(Destination.chats);
      await tester.pumpAndSettle();
      expect(find.text('The Daily Brief'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('Noise says what it is and how much came this week; Archive all asks first, then clears the pile; Undo brings it back', (tester) async {
      final container = await pumpApp(tester);
      container.read(destinationProvider.notifier).select(Destination.noise);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('noise-header')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('noise-header')), matching: find.textContaining('3')), findsOneWidget, reason: 'three came this week');

      await tester.tap(find.byKey(const ValueKey('noise-archive-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('noise-archive-confirm')), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('The Daily Brief'), findsOneWidget, reason: 'nothing happens without a yes');

      await tester.tap(find.byKey(const ValueKey('noise-archive-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('noise-archive-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('The Daily Brief'), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('The Daily Brief'), findsOneWidget, reason: 'one Undo brings it all back');

      container.read(destinationProvider.notifier).select(Destination.feed);
      await tester.pumpAndSettle();
      expect(find.text('First Bank'), findsWidgets, reason: 'Feed is not touched');
      expect(find.byKey(const ValueKey('noise-header')), findsNothing);
      await teardown(tester);
    });

    testWidgets('an email\'s menu → "This is not a person" opens the "?"; "Always" moves the sender for good, and Undo puts it back', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Sarah Chen'));
      await tester.pumpAndSettle();
      // The newest message (Lunch?) opens with the chat.
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('This is not a person'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('why-dialog')), findsOneWidget);
      expect(find.text('Why this is in Chats'), findsOneWidget);
      expect(find.byKey(const ValueKey('proposal-text')), findsNothing, reason: 'the old four-button pop-up is gone');
      await tester.tap(find.byKey(const ValueKey('why-not-person')));
      await tester.pumpAndSettle();
      expect((await contact('sarah@x.com')).classification, 'feeds');
      expect((await contact('sarah@x.com')).classificationSource, 'override');
      expect(await db.loadRules(), isEmpty, reason: 'a move, not a written rule');
      expect(find.textContaining('moved to Feed or Noise'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect((await contact('sarah@x.com')).classification, 'people');
      await teardown(tester);
    });

    testWidgets('"This one is not from a person" changes only that email', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Sarah Chen'));
      await tester.pumpAndSettle();
      // The newest message (Lunch?) opens with the chat.
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('This is not a person'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('why-not-person-one')));
      await tester.pumpAndSettle();
      expect(await db.loadRules(), isEmpty);
      expect((await contact('sarah@x.com')).classification, 'people');
      expect((await db.messagesFromSender('sarah@x.com')).single.classification, 'feeds');
      await teardown(tester);
    });

    testWidgets('a tag is set for just one email, or always for its sender: two choices, no rule pop-up', (tester) async {
      final container = await pumpApp(tester);
      container.read(destinationProvider.notifier).select(Destination.feed);
      await tester.pumpAndSettle();
      final shipped = (await db.messagesFromSender('noreply@shop.com')).firstWhere((m) => m.subject.contains('shipped'));
      await tester.tap(find.byKey(ValueKey('mail-row-${shipped.id}')));
      await tester.pumpAndSettle();
      Future<void> tag(String name, Key choice) async {
        await tester.tap(find.byTooltip('More').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Change category…'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(SimpleDialogOption, name));
        await tester.pumpAndSettle();
        expect(find.text('Tag as $name'), findsOneWidget);
        await tester.tap(find.byKey(choice));
        await tester.pumpAndSettle();
      }

      await tag('Receipt', const ValueKey('tag-once'));
      expect((await db.messageById(shipped.id))!.feedsCategory, 'Receipt');
      expect((await contact('noreply@shop.com')).feedsCategory, isNot('Receipt'), reason: 'only this email');
      await tag('Travel', const ValueKey('tag-always'));
      expect((await contact('noreply@shop.com')).feedsCategory, 'Travel');
      expect(await db.loadRules(), isEmpty);
      await teardown(tester);
    });
  });
}
