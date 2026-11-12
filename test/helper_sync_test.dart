import 'package:convomail/domain/classifier.dart';
import 'package:convomail/domain/piles.dart';
import 'package:convomail/helper/helper_client.dart';
import 'package:convomail/helper/helper_sync.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/classification_queries.dart';
import 'package:convomail/store/database.dart' hide ClassificationRule;
import 'package:convomail/store/done_queries.dart';
import 'package:convomail/store/helper_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/planner_queries.dart';
import 'package:convomail/sync/classification_service.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_helper.dart';
import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Step 2 of the Précis plan, the PC's side: joining the helper, sending up
/// what this PC knows, sending up what the user changes, and following what
/// the helper decides. The helper here is a stand-in; nothing leaves the test.
void main() {
  const me = RemoteAddress('me@example.com');
  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;
  late FakeHelper helper;
  late InMemoryCredentialStore vault;
  late ProviderContainer container;

  DateTime ago({int days = 0, int hours = 0}) => DateTime.now().subtract(Duration(days: days, hours: hours));

  String got(String address, String name, String subject, {String? id, String? replyTo, BulkSignals signals = BulkSignals.none, DateTime? at}) {
    final messageId = id ?? '<${subject.hashCode}-${imap.folder('INBOX').nextUid}@mail.example>';
    imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: RemoteAddress(address, name), to: const [me], subject: subject, messageId: messageId, inReplyTo: replyTo, date: at ?? ago(hours: 3), signals: signals));
    return messageId;
  }

  Future<void> sync() async {
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
  }

  Future<Contact> contact(String key) => (db.select(db.contacts)..where((c) => c.key.equals(key))).getSingle();
  Future<Message> message(String messageId) async => (await (db.select(db.messages)..where((m) => m.messageId.equals(messageId))).get()).first;
  HelperSync link() => container.read(helperProvider.notifier);
  HelperLink state() => container.read(helperProvider);
  ClassificationService service() => container.read(classificationServiceProvider);

  /// Joins and waits until this PC and the stand-in agree.
  Future<void> join() async {
    await link().connect('localhost', 'good-code', name: 'Test PC');
    await link().idle();
    expect(link().lastFailure, isNull);
  }

  const brief = BulkSignals(listUnsubscribe: true, listId: true, listIdValue: 'brief.dailybrief.com');

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    helper = FakeHelper();
    vault = InMemoryCredentialStore();
    account = await insertTestAccount(db);
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), isDefault: const Value(true)));
    imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) => db),
      credentialStoreProvider.overrideWith((ref) => vault),
      helperHttpProvider.overrideWith((ref) => helper.call),
    ]);
    // Typical mail: a person, a newsletter, a bank.
    got('sarah@x.com', 'Sarah Chen', 'Lunch?', id: '<lunch@x.com>');
    for (var i = 0; i < 3; i++) {
      got('hello@dailybrief.com', 'The Daily Brief', 'Daily Brief #$i', id: '<brief-$i@dailybrief.com>', signals: brief);
    }
    got('noreply@bank.com', 'First Bank', 'Your statement is ready', id: '<statement@bank.com>');
    imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('sarah@x.com')], subject: 'Re: Lunch?', messageId: '<mine-1@example.com>', date: ago(hours: 2)));
    await sync();
  });

  tearDown(() async {
    await container.read(helperProvider.notifier).idle();
    expect(container.read(helperProvider.notifier).lastFailure, isNull, reason: 'keeping in step failed along the way');
    container.dispose();
    await db.close();
  });

  group('joining', () {
    test('a wrong code joins nothing; the right one does, and the token is kept in the vault only', () async {
      await link().load();
      expect(state().connected, isFalse);
      await expectLater(link().connect('localhost', 'WRONG', name: 'Test PC'), throwsA(isA<HelperException>()));
      expect(state().connected, isFalse);
      expect(state().error, contains('not right'));
      expect(await db.helperConnected(), isFalse);
      expect(await vault.read(HelperSync.tokenKey), isNull);

      await link().connect('localhost', 'good-code', name: 'Test PC');
      expect(state().connected, isTrue);
      expect(state().address, 'https://localhost');
      expect(state().deviceName, 'Test PC');
      expect(await db.helperConnected(), isTrue);
      final token = await vault.read(HelperSync.tokenKey);
      expect(token, helper.tokens[1]);
      final settings = await db.select(db.settings).get();
      expect(settings.any((s) => s.value.contains(token!)), isFalse, reason: 'the token must not sit in the settings table');
    });

    test('only https, except to this same computer', () {
      expect(HelperClient.normalizeBase('precis.example.com').toString(), 'https://precis.example.com');
      expect(HelperClient.normalizeBase(' https://precis.example.com/some/page ').toString(), 'https://precis.example.com');
      expect(HelperClient.normalizeBase('http://127.0.0.1:8080').toString(), 'http://127.0.0.1:8080');
      expect(() => HelperClient.normalizeBase('http://precis.example.com'), throwsA(isA<HelperException>()));
      expect(() => HelperClient.normalizeBase('  '), throwsA(isA<HelperException>()));
    });

    test('an address that is not a helper, or cannot be reached, says so and joins nothing', () async {
      helper.unreachable = true;
      await expectLater(link().connect('localhost', 'good-code'), throwsA(isA<HelperException>().having((e) => e.unreachable, 'unreachable', isTrue)));
      expect(state().connected, isFalse);
      expect(await db.helperConnected(), isFalse);
    });
  });

  group('the first sending-up', () {
    test('this PC sends what it knows: its own addresses and name, tags, and every sender with the facts behind it', () async {
      await db.snoozeRow('c:sarah@x.com', DateTime.now().add(const Duration(days: 1)));
      await db.setMessagesDone([(await message('<statement@bank.com>')).id], true);
      await db.addReminder(title: 'Call the bank', dueAt: DateTime.now().add(const Duration(hours: 5)));
      await join();

      expect(state().sentUp, isTrue);
      expect(helper.item('me', 'me@example.com'), isNotNull);
      expect(helper.item('names', 'user')!['first'], ['clay']);
      expect(helper.item('tag', 'Newsletter'), isNotNull);
      expect(helper.item('rowpref', 'c:sarah@x.com')!['snoozed'], isA<int>());
      expect(helper.item('done', '<statement@bank.com>'), isNotNull);
      expect(helper.pushedOf('reminder').single['data'], containsPair('title', 'Call the bank'));
      expect(helper.myIds, contains('<mine-1@example.com>'));

      final keys = {for (final s in helper.seeded) s['k']};
      expect(keys, containsAll(['sarah@x.com', 'hello@dailybrief.com', 'noreply@bank.com']));
      expect(keys, isNot(contains('me')));
      final news = helper.seeded.firstWhere((s) => s['k'] == 'hello@dailybrief.com');
      expect((news['item']! as Map)['cls'], 'feeds');
      final facts = (news['facts']! as Map).cast<String, Object?>();
      expect(facts['messagesReceived'], 3);
      expect(facts['messagesWithBulkHeaders'], 3);
      expect(facts['listIds'], ['brief.dailybrief.com']);
      expect((facts['mail']! as Map)['Newsletter'], {'total': 3, 'unread': 3});
      final sarah = helper.seeded.firstWhere((s) => s['k'] == 'sarah@x.com');
      expect(((sarah['facts']! as Map)['userHasWrittenTo']), isTrue);
      expect(await db.helperOutboxCount(), 0, reason: 'nothing left waiting');
    });

    test('no email text goes up: only names, addresses, subjects and counts', () async {
      final m = await message('<lunch@x.com>');
      await (db.update(db.messages)..where((x) => x.id.equals(m.id))).write(const MessagesCompanion(bodyText: Value('THE-BODY-OF-THE-EMAIL'), snippet: Value('THE-SNIPPET')));
      await join();
      final sent = '${helper.seeded}${helper.pushed}';
      expect(sent, isNot(contains('THE-BODY-OF-THE-EMAIL')));
      expect(sent, isNot(contains('THE-SNIPPET')));
      expect(sent, isNot(contains('secret')));
    });

    test('stopped part-way, it picks up where it left off', () async {
      for (var i = 0; i < 250; i++) {
        got('p$i@x.com', 'Person $i', 'Hello $i', id: '<p$i@x.com>');
      }
      await sync();
      helper.failSeedAfter = 1;
      await link().connect('localhost', 'good-code', name: 'Test PC');
      await link().sendUpEverything();
      expect(state().sentUp, isFalse);
      expect(helper.seeded, hasLength(100));
      expect(state().error, contains('carries on by itself'));

      helper.failSeedAfter = null;
      await link().sendUpEverything();
      expect(state().sentUp, isTrue);
      expect({for (final s in helper.seeded) s['k']}.length, greaterThanOrEqualTo(253), reason: 'every sender went up');
      expect(helper.seeded.length, lessThan(360), reason: 'and the first hundred were not sent again');
      expect(state().sendingDone, state().sendingTotal);
    });
  });

  group('what the user changes here goes up', () {
    setUp(join);

    test('nothing is noted for a helper when this PC follows none', () async {
      await link().disconnect();
      await service().moveSender('sarah@x.com', Bucket.feeds);
      await db.snoozeRow('c:sarah@x.com', DateTime.now().add(const Duration(days: 1)));
      await db.addReminder(title: 'x', dueAt: DateTime.now());
      expect(await db.helperOutboxCount(), 0);
    });

    test('a sender moved by hand, its pile, its tag and whether it rings', () async {
      helper.pushed.clear();
      await service().moveSender('sarah@x.com', Bucket.feeds);
      await db.setSenderPile('sarah@x.com', FeedsPile.noise);
      await service().setSenderCategory('sarah@x.com', 'Receipt');
      await service().setCountsTowardUnread('sarah@x.com', true);
      await link().syncNow();
      final item = helper.item('sender', 'sarah@x.com')!;
      expect(item, containsPair('cls', 'feeds'));
      expect(item, containsPair('src', 'override'));
      expect(item, containsPair('pile', 'noise'));
      expect(item, containsPair('cat', 'Receipt'));
      expect(item, containsPair('counts', true));
      expect(helper.pushedOf('sender').where((p) => p['k'] == 'sarah@x.com'), hasLength(1), reason: 'four edits to one sender go up as one');

      await service().moveSender('sarah@x.com', null);
      await link().syncNow();
      expect(helper.item('sender', 'sarah@x.com'), isNot(containsPair('src', 'override')));
    });

    test('rules: added and removed', () async {
      final id = await service().acceptRule(const ClassificationRule(field: 'domain', pattern: 'bank.com', bucket: Bucket.people));
      await link().syncNow();
      final rule = helper.pushedOf('rule').single;
      expect(rule['data'], allOf(containsPair('field', 'domain'), containsPair('pattern', 'bank.com'), containsPair('bucket', 'people')));
      final uid = rule['k']! as String;
      expect(uid, hasLength(24));
      await service().deleteRule(id);
      await link().syncNow();
      expect(helper.gone('rule', uid), isTrue);
    });

    test('tags: added, renamed as one action, removed as one action', () async {
      helper.pushed.clear();
      await db.addCategory('Mine');
      await link().syncNow();
      expect(helper.item('tag', 'Mine'), isNotNull);
      final cats = await db.watchCategories().first;
      await db.renameCategory(cats.firstWhere((c) => c.name == 'Newsletter').id, 'Reading');
      await link().syncNow();
      expect(helper.pushed.where((p) => p['op'] == 'rename-tag').single, allOf(containsPair('from', 'Newsletter'), containsPair('to', 'Reading')));
      expect(helper.item('sender', 'hello@dailybrief.com'), containsPair('cat', 'Reading'));
      await db.deleteCategory(cats.firstWhere((c) => c.name == 'Mine').id);
      await link().syncNow();
      expect(helper.pushed.where((p) => p['op'] == 'delete-tag').single, containsPair('name', 'Mine'));
      final order = [for (final p in helper.pushed) p['op'] ?? p['kind']];
      expect(order.indexOf('rename-tag'), lessThan(order.lastIndexOf('sender')), reason: 'the action goes before the rows it changed');
    });

    test('done and not done, by the email\'s own Message-ID', () async {
      final m = await message('<lunch@x.com>');
      await db.setMessagesDone([m.id], true);
      await link().syncNow();
      expect(helper.item('done', '<lunch@x.com>')!['at'], isA<int>());
      await db.setMessagesDone([m.id], false);
      await link().syncNow();
      expect(helper.gone('done', '<lunch@x.com>'), isTrue);
    });

    test('Later, pins, and reminders made, finished and removed', () async {
      final until = DateTime.now().add(const Duration(days: 2));
      await db.snoozeRow('c:sarah@x.com', until);
      await db.setPinned('c:noreply@bank.com', true);
      final id = await db.addReminder(title: 'Call back', dueAt: until, messageId: (await message('<lunch@x.com>')).id, rowKey: 'c:sarah@x.com');
      await link().syncNow();
      expect(helper.item('rowpref', 'c:sarah@x.com'), containsPair('snoozed', until.millisecondsSinceEpoch ~/ 1000));
      expect(helper.item('rowpref', 'c:noreply@bank.com'), containsPair('pinned', true));
      final uid = helper.pushedOf('reminder').last['k']! as String;
      expect(helper.item('reminder', uid), allOf(containsPair('title', 'Call back'), containsPair('mid', '<lunch@x.com>'), containsPair('row', 'c:sarah@x.com'), containsPair('done', false)));
      await db.setReminderDone(id, true);
      await link().syncNow();
      expect(helper.item('reminder', uid), containsPair('done', true));
      await db.deleteReminder(id);
      await db.snoozeRow('c:sarah@x.com', null);
      await link().syncNow();
      expect(helper.gone('reminder', uid), isTrue);
      expect(helper.item('rowpref', 'c:sarah@x.com'), containsPair('snoozed', null));
    });

    test('a fix to one email', () async {
      final m = await message('<statement@bank.com>');
      await service().setMessageCategory(m.id, 'Newsletter');
      await service().setMessageBucket((await message('<brief-0@dailybrief.com>')).id, Bucket.people);
      await link().syncNow();
      expect(helper.item('msgfix', '<statement@bank.com>'), {'cat': 'Newsletter'});
      expect(helper.item('msgfix', '<brief-0@dailybrief.com>'), {'cls': 'people'});
      // The fix stands here at once, even through a re-sort, before the helper says it back.
      await service().classifySenders(['hello@dailybrief.com'], log: false);
      expect((await message('<brief-0@dailybrief.com>')).classification, 'people');
    });

    test('one change the helper refuses does not hold up the rest', () async {
      helper.refuse.add('rowpref');
      await db.snoozeRow('c:sarah@x.com', DateTime.now().add(const Duration(days: 1)));
      await db.setMessagesDone([(await message('<lunch@x.com>')).id], true);
      await link().syncNow();
      expect(helper.item('done', '<lunch@x.com>'), isNotNull);
      expect(helper.item('rowpref', 'c:sarah@x.com'), isNull);
      expect(await db.helperOutboxCount(), 0, reason: 'the refused one is dropped, not retried forever');
    });
  });

  group('what the helper says is followed here', () {
    setUp(join);

    test('the helper decides who is a person: its answer is taken, kept through new mail, and not sent back', () async {
      expect((await contact('noreply@bank.com')).classification, 'feeds');
      helper.put('sender', 'noreply@bank.com', {'cls': 'people', 'src': 'auto', 'cat': null, 'reasons': 'Gmail files this sender under Primary'});
      helper.pushed.clear();
      await link().syncNow();
      var c = await contact('noreply@bank.com');
      expect(c.classification, 'people');
      expect(c.classReasons, 'Gmail files this sender under Primary');
      expect((await message('<statement@bank.com>')).classification, 'people');
      expect((await db.watchPeopleRows(tab: InboxTab.people).first).map((r) => r.rowKey), contains('c:noreply@bank.com'));

      // New mail arrives; this PC's own rules would say "not a person".
      got('noreply@bank.com', 'First Bank', 'A new sign-in', id: '<signin@bank.com>');
      await sync();
      c = await contact('noreply@bank.com');
      expect(c.classification, 'people', reason: 'the helper is the one that decides');
      await link().syncNow();
      expect(helper.pushedOf('sender'), isEmpty, reason: 'what came from the helper is not sent back');
      expect(await db.helperOutboxCount(), 0);
    });

    test('the user\'s own move still wins over the helper\'s answer', () async {
      helper.put('sender', 'noreply@bank.com', {'cls': 'people', 'src': 'auto', 'cat': null, 'reasons': 'x'});
      await link().syncNow();
      await service().moveSender('noreply@bank.com', Bucket.feeds);
      expect((await contact('noreply@bank.com')).classification, 'feeds');
      got('noreply@bank.com', 'First Bank', 'Another', id: '<another@bank.com>');
      await sync();
      expect((await contact('noreply@bank.com')).classification, 'feeds');
      expect((await contact('noreply@bank.com')).classificationSource, 'override');
    });

    test('a sender moved on another device is moved here, pile and tag and all', () async {
      helper.put('sender', 'hello@dailybrief.com', {'cls': 'feeds', 'src': 'auto', 'cat': 'Reading', 'pile': 'feed', 'counts': true, 'label': 'The Brief', 'reasons': 'x'}, origin: 99);
      helper.put('sender', 'sarah@x.com', {'cls': 'feeds', 'src': 'override', 'cat': null, 'reasons': 'Moved by you'}, origin: 99);
      await link().syncNow();
      final news = await contact('hello@dailybrief.com');
      expect([news.feedsCategory, news.feedsPile, news.countsTowardUnread, news.userLabel], ['Reading', 'feed', true, 'The Brief']);
      expect((await db.watchPeopleRows(tab: InboxTab.feed).first).map((r) => r.rowKey), contains('c:hello@dailybrief.com'));
      final sarah = await contact('sarah@x.com');
      expect([sarah.classification, sarah.classificationSource], ['feeds', 'override']);
      expect((await message('<lunch@x.com>')).classification, 'feeds');
      expect(await db.helperOutboxCount(), 0);
    });

    test('a move made by hand on another device holds on a device that learns of the sender only later (a phone that just joined), and is never sent back as this device\'s own guess', () async {
      // The helper says: moved by hand to "not a person". This device has no mail from them yet.
      helper.put('sender', 'pat@agency.example', {'cls': 'feeds', 'src': 'override', 'cat': null, 'reasons': 'Moved by you'}, origin: 99);
      await link().syncNow();
      helper.pushed.clear();
      // Their mail arrives. By this device's own rules it is plain mail from a person.
      got('pat@agency.example', 'Pat Agent', 'Hello', id: '<pat-1@x>');
      await sync();
      final c = await contact('pat@agency.example');
      expect([c.classification, c.classificationSource], ['feeds', 'override'], reason: 'the move is the user\'s, here too');
      expect((await message('<pat-1@x>')).classification, 'feeds');
      await link().syncNow();
      for (final p in helper.pushedOf('sender').where((p) => p['k'] == 'pat@agency.example')) {
        expect((p['data'] as Map)['src'], 'override', reason: 'never sent up as this device\'s own guess');
      }
      expect(helper.item('sender', 'pat@agency.example'), containsPair('src', 'override'));
      // More mail, more sorting: it stays.
      got('pat@agency.example', 'Pat Agent', 'Again', id: '<pat-2@x>');
      await sync();
      await link().syncNow();
      expect((await contact('pat@agency.example')).classificationSource, 'override');
      expect(helper.item('sender', 'pat@agency.example'), containsPair('src', 'override'));
    });

    test('taking a move back is said to the helper in so many words; moved again before it is sent, it is not said', () async {
      await service().moveSender('sarah@x.com', Bucket.feeds);
      await link().syncNow();
      expect(helper.item('sender', 'sarah@x.com'), containsPair('src', 'override'));
      helper.pushed.clear();
      await service().moveSender('sarah@x.com', null);
      await link().syncNow();
      expect(helper.pushed.where((p) => p['op'] == 'unmove').single, containsPair('k', 'sarah@x.com'));
      expect((await contact('sarah@x.com')).classificationSource, isNot('override'));
      expect(helper.item('sender', 'sarah@x.com'), isNot(containsPair('src', 'override')));
      // Moved, taken back and moved again while nothing could be sent: only the move goes up.
      helper.pushed.clear();
      await service().moveSender('sarah@x.com', Bucket.feeds);
      await link().syncNow();
      helper.pushed.clear();
      helper.unreachable = true;
      await service().moveSender('sarah@x.com', null);
      await service().moveSender('sarah@x.com', Bucket.feeds);
      helper.unreachable = false;
      await link().syncNow();
      expect(helper.pushed.where((p) => p['op'] == 'unmove'), isEmpty);
      expect((await contact('sarah@x.com')).classificationSource, 'override');
      expect(helper.item('sender', 'sarah@x.com'), containsPair('src', 'override'));
    });

    test('the helper\'s answer for one email applies, even when it arrives before the email does', () async {
      helper.put('sort', '<statement@bank.com>', {'cls': 'people', 'cat': null});
      helper.put('sort', '<not-here-yet@bank.com>', {'cls': 'feeds', 'cat': 'OTP'});
      await link().syncNow();
      expect((await message('<statement@bank.com>')).classification, 'people');
      got('noreply@bank.com', 'First Bank', 'Hello from the bank', id: '<not-here-yet@bank.com>');
      await sync();
      final late = await message('<not-here-yet@bank.com>');
      expect([late.classification, late.feedsCategory], ['feeds', 'OTP']);
    });

    test('rules, tags, Later, reminders and done from another device arrive here and are not sent back', () async {
      final due = DateTime.now().add(const Duration(hours: 3)).millisecondsSinceEpoch ~/ 1000;
      helper.put('rule', 'rule-from-phone', {'uid': 'rule-from-phone', 'field': 'sender', 'pattern': 'x@y.com', 'bucket': 'feeds', 'category': null, 'at': 5}, origin: 99);
      helper.put('tag', 'From phone', {'pos': 42, 'builtin': false}, origin: 99);
      helper.put('rowpref', 'c:sarah@x.com', {'snoozed': due, 'pinned': true, 'muted': false, 'resurfaced': null}, origin: 99);
      helper.put('reminder', 'rem-from-phone', {'title': 'From the phone', 'due': due, 'done': false, 'fired': null, 'mid': '<lunch@x.com>', 'thread': null, 'row': 'c:sarah@x.com'}, origin: 99);
      helper.put('done', '<statement@bank.com>', {'at': due - 9000}, origin: 99);
      helper.pushed.clear();
      await link().syncNow();

      expect((await db.loadRules()).single.pattern, 'x@y.com');
      expect(await db.categoryNames(), contains('From phone'));
      final pref = await (db.select(db.rowPrefs)..where((p) => p.rowKey.equals('c:sarah@x.com'))).getSingle();
      expect(pref.pinned, isTrue);
      expect(pref.snoozedUntil!.millisecondsSinceEpoch ~/ 1000, due);
      expect((await db.watchLaterRows().first).single.rowKey, 'c:sarah@x.com');
      final reminder = (await db.watchReminders().first).single;
      expect([reminder.title, reminder.rowKey, reminder.messageId], ['From the phone', 'c:sarah@x.com', (await message('<lunch@x.com>')).id]);
      expect((await message('<statement@bank.com>')).doneAt, isNotNull);

      await link().syncNow();
      expect(helper.pushed, isEmpty, reason: 'nothing that came down goes back up');
      expect(await db.helperOutboxCount(), 0);

      // And removals.
      helper.remove('rule', 'rule-from-phone', origin: 99);
      helper.remove('reminder', 'rem-from-phone', origin: 99);
      helper.remove('done', '<statement@bank.com>', origin: 99);
      await link().syncNow();
      expect(await db.loadRules(), isEmpty);
      expect(await db.watchReminders().first, isEmpty);
      expect((await message('<statement@bank.com>')).doneAt, isNull);
    });

    test('a reminder rings by this PC\'s own clock: the helper marking it rung does not silence it here', () async {
      final id = await db.addReminder(title: 'Ring me', dueAt: DateTime.now().subtract(const Duration(seconds: 5)));
      await link().syncNow();
      final uid = helper.pushedOf('reminder').last['k']! as String;
      helper.put('reminder', uid, {...helper.item('reminder', uid)!, 'fired': DateTime.now().millisecondsSinceEpoch ~/ 1000});
      await link().syncNow();
      expect((await db.dueReminders(DateTime.now())).map((r) => r.id), [id], reason: 'still due to ring here');
    });
  });

  group('when things go wrong', () {
    setUp(join);

    test('the helper cannot be reached: Précis carries on, keeps what waits, and catches up later', () async {
      helper.unreachable = true;
      await db.setMessagesDone([(await message('<lunch@x.com>')).id], true);
      await link().syncNow();
      expect(state().connected, isTrue);
      expect(state().error, contains('carries on by itself'));
      expect(await db.helperOutboxCount(), 1);
      // Sorting still works by this PC's own rules.
      got('new@shop.com', 'Shop', 'Your order has shipped', id: '<shipped@shop.com>', signals: const BulkSignals(listUnsubscribe: true));
      await sync();
      expect((await contact('new@shop.com')).classification, 'feeds');

      helper.unreachable = false;
      await link().syncNow();
      expect(state().error, isNull);
      expect(helper.item('done', '<lunch@x.com>'), isNotNull);
      expect(await db.helperOutboxCount(), 0);
    });

    test('signed out from another device: this PC stops following and keeps everything it has', () async {
      helper.put('sender', 'noreply@bank.com', {'cls': 'people', 'src': 'auto', 'cat': null, 'reasons': 'x'});
      await link().syncNow();
      helper.signOut(1);
      await link().syncNow();
      expect(state().connected, isFalse);
      expect(state().error, contains('signed out of the helper'));
      expect(await db.helperConnected(), isFalse);
      expect(await vault.read(HelperSync.tokenKey), isNull);
      expect((await contact('noreply@bank.com')).classification, 'people', reason: 'what it had stays');
      expect(await db.select(db.messages).get(), isNotEmpty);
    });

    test('stopping here signs this PC out at the helper, forgets its token, and goes back to sorting by itself', () async {
      helper.put('sender', 'noreply@bank.com', {'cls': 'people', 'src': 'auto', 'cat': null, 'reasons': 'x'});
      await link().syncNow();
      await link().disconnect();
      expect(state().connected, isFalse);
      expect(helper.tokens, isEmpty);
      expect(await vault.read(HelperSync.tokenKey), isNull);
      expect(await db.select(db.helperSenders).get(), isEmpty);
      // New mail: this PC's own rules decide again.
      got('noreply@bank.com', 'First Bank', 'A new sign-in', id: '<signin@bank.com>');
      await sync();
      expect((await contact('noreply@bank.com')).classification, 'feeds');
      // A restart still knows it follows nothing.
      await link().load();
      expect(state().connected, isFalse);
    });

    test('after a restart it is still following, and does not send everything up again', () async {
      await link().idle();
      container.dispose();
      final seededBefore = helper.seeded.length;
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) => db),
        credentialStoreProvider.overrideWith((ref) => vault),
        helperHttpProvider.overrideWith((ref) => helper.call),
      ]);
      await link().load();
      expect(state().connected, isTrue);
      expect(state().sentUp, isTrue);
      expect(state().deviceName, 'Test PC');
      await link().syncNow();
      expect(helper.seeded.length, seededBefore);
    });
  });

  test('Settings can show the helper\'s state and devices, make a code, and sign a device out', () async {
    await join();
    await link().refreshStatus();
    expect((state().status!['accounts']! as List).single, containsPair('email', 'me@example.com'));
    expect(state().devices.single, containsPair('name', 'Test PC'));
    expect(await link().newDeviceCode(), 'NEXTCODE');
    helper.tokens[2] = '2.other';
    helper.names[2] = 'Phone';
    await link().signOutDevice(2);
    expect(state().devices.map((d) => d['name']), ['Test PC']);
  });
}
