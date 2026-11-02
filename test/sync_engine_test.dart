import 'package:convomail/domain/classifier.dart';
import 'package:convomail/mail/mail_transport.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/store/thread_queries.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeMailTransport server;
  late Account account;
  late AccountSyncer syncer;
  final statuses = <SyncStatus>[];

  setUp(() async {
    db = testDatabase();
    server = FakeMailTransport();
    account = await insertTestAccount(db);
    statuses.clear();
    syncer = AccountSyncer(
      db: db,
      transport: server,
      account: account,
      credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'),
      pageSize: 3,
      onStatus: statuses.add,
      sleep: (_) async {},
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<Message>> allMessages() => db.select(db.messages).get();

  test('first sync stores headers, participants, contacts and row assignments', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'sarah@x.com', fromName: 'Sarah Chen', subject: 'Design review', messageId: '<a@x>'));
    inbox.add(hdr(from: 'simon@x.com', to: ['me@example.com', 'joann@x.com'], subject: 'Agenda'));
    server.folder('Junk', role: FolderRole.junk).add(hdr(from: 'spam@spam.com'));

    await syncer.syncOnce();

    final msgs = await allMessages();
    expect(msgs.length, 2, reason: 'junk is not synced');
    final sarah = msgs.firstWhere((m) => m.fromAddress == 'sarah@x.com');
    expect(sarah.subject, 'Design review');
    expect(sarah.messageId, '<a@x>');
    expect(sarah.fromContactKey, 'sarah@x.com');
    expect(sarah.isFromMe, isFalse);

    final parts = await db.select(db.messageParticipants).get();
    expect(parts.where((p) => p.messageId == sarah.id).map((p) => p.role).toSet(), {'from', 'to'});

    final contacts = await db.select(db.contacts).get();
    expect(contacts.map((c) => c.key).toSet(), {'sarah@x.com', 'simon@x.com', 'joann@x.com'});
    expect(contacts.firstWhere((c) => c.key == 'sarah@x.com').displayName, 'Sarah Chen');

    final rows = await db.select(db.messageRowAssignments).get();
    expect(rows.map((r) => r.rowKey).toSet(), {'c:sarah@x.com', 'c:simon@x.com'});

    final folder = (await db.foldersForAccount(account.id)).firstWhere((f) => f.path == 'INBOX');
    expect(folder.lastSyncedUid, 2);
    expect(folder.uidValidity, 1);
    expect(statuses.last.phase, SyncPhase.idle);
  });

  test('incremental sync fetches only new UIDs and pages from the top', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    for (var i = 0; i < 7; i++) {
      inbox.add(hdr(from: 'p$i@x.com', subject: 'm$i'));
    }
    await syncer.syncOnce();
    expect((await allMessages()).length, 7);
    // page size 3 over 7 UIDs → 3 header calls (7-5, 4-2, 1-1), newest first
    expect(server.log.where((l) => l.startsWith('fetchHeaders')).toList(), ['fetchHeaders 5-7', 'fetchHeaders 2-4', 'fetchHeaders 1-1']);

    server.log.clear();
    inbox.add(hdr(from: 'new@x.com', subject: 'm8'));
    await syncer.syncOnce();
    expect((await allMessages()).length, 8);
    expect(server.log.where((l) => l.startsWith('fetchHeaders')).toList(), ['fetchHeaders 8-8']);
  });

  test('messages deleted elsewhere are removed; flag changes are mirrored', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    final u1 = inbox.add(hdr(from: 'a@x.com'));
    final u2 = inbox.add(hdr(from: 'b@x.com'));
    await syncer.syncOnce();

    inbox.remove(u1);
    inbox.setFlags(u2, const MessageFlagsState(seen: true, flagged: true));
    await syncer.syncOnce();

    final msgs = await allMessages();
    expect(msgs.length, 1);
    expect(msgs.single.uid, u2);
    expect(msgs.single.isSeen, isTrue);
    expect(msgs.single.isFlagged, isTrue);
  });

  test('UIDVALIDITY change wipes and re-syncs the folder without duplicates', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'a@x.com', messageId: '<1@x>'));
    inbox.add(hdr(from: 'b@x.com', messageId: '<2@x>'));
    await syncer.syncOnce();

    // Server rebuilt the mailbox: same mail, new UIDs.
    inbox.uidValidity = 99;
    inbox.messages.clear();
    inbox.nextUid = 500;
    inbox.add(hdr(from: 'a@x.com', messageId: '<1@x>'));
    inbox.add(hdr(from: 'b@x.com', messageId: '<2@x>'));
    await syncer.syncOnce();

    final msgs = await allMessages();
    expect(msgs.length, 2);
    expect(msgs.map((m) => m.uid).toSet(), {500, 501});
    expect(msgs.map((m) => m.messageId).toSet(), {'<1@x>', '<2@x>'});
  });

  test('sent mail files under each recipient; group match wins for both directions', () async {
    // A user-defined group Simon & Joann.
    final gid = await db.into(db.peopleGroups).insert(PeopleGroupsCompanion.insert(name: 'Simon & Joann'));
    await db.into(db.groupMembers).insert(GroupMembersCompanion.insert(groupId: gid, contactKey: 'simon@x.com'));
    await db.into(db.groupMembers).insert(GroupMembersCompanion.insert(groupId: gid, contactKey: 'joann@x.com'));

    final sent = server.folder('Sent', role: FolderRole.sent);
    sent.add(hdr(from: 'me@example.com', to: ['sarah@x.com', 'tom@x.com'], subject: 'to two people'));
    sent.add(hdr(from: 'me@example.com', to: ['simon@x.com', 'joann@x.com'], subject: 'to the group'));
    server.folder('INBOX', role: FolderRole.inbox).add(hdr(from: 'joann@x.com', to: ['me@example.com', 'simon@x.com'], subject: 'from the group'));
    await syncer.syncOnce();

    final rows = await db.select(db.messageRowAssignments).get();
    final byMessage = <int, Set<String>>{};
    for (final r in rows) {
      byMessage.putIfAbsent(r.messageId, () => {}).add(r.rowKey);
    }
    final msgs = await allMessages();
    final toTwo = msgs.firstWhere((m) => m.subject == 'to two people');
    final toGroup = msgs.firstWhere((m) => m.subject == 'to the group');
    final fromGroup = msgs.firstWhere((m) => m.subject == 'from the group');
    expect(byMessage[toTwo.id], {'c:sarah@x.com', 'c:tom@x.com'});
    expect(byMessage[toGroup.id], {'g:$gid'});
    expect(byMessage[fromGroup.id], {'g:$gid'});
    expect(toTwo.isFromMe, isTrue);
    expect(fromGroup.isFromMe, isFalse);
  });

  test('body fetch stores text, html, attachments and a snippet', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    final uid = inbox.add(
      hdr(from: 'a@x.com', subject: 'With attachment'),
      body: const RemoteMessageBody(
        text: 'The   mockups are ready\nfor review.',
        html: '<p>The mockups are ready for review.</p>',
        attachments: [RemoteAttachment(partId: '2', fileName: 'Dashboard.png', mimeType: 'image/png', size: 1900)],
      ),
    );
    await syncer.syncOnce();
    final m = (await allMessages()).single;
    expect(m.bodyText, isNull);

    await syncer.fetchBody(m.id);
    final after = await db.messageById(m.id);
    expect(after!.bodyText, contains('mockups'));
    expect(after.snippet, 'The mockups are ready for review.');
    expect(after.hasAttachments, isTrue);
    expect(after.uid, uid);
    final atts = await db.select(db.attachments).get();
    expect(atts.single.fileName, 'Dashboard.png');
  });

  test('setFlags pushes to the server and mirrors locally', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    final uid = inbox.add(hdr(from: 'a@x.com'));
    await syncer.syncOnce();
    final folder = (await db.foldersForAccount(account.id)).firstWhere((f) => f.path == 'INBOX');

    await syncer.setFlags(folder.id, [uid], seen: true, flagged: true);
    expect(inbox.messages[uid]!.flags.seen, isTrue);
    expect((await allMessages()).single.isFlagged, isTrue);
  });

  test('a wrong password reports an auth failure and does not retry', () async {
    server.folder('INBOX', role: FolderRole.inbox);
    final bad = AccountSyncer(
      db: db,
      transport: server,
      account: account,
      credentials: () async => const MailCredentials(username: 'me@example.com', password: 'wrong'),
      onStatus: statuses.add,
      sleep: (_) async {},
    );
    await expectLater(bad.syncOnce(), throwsA(isA<MailTransportException>().having((e) => e.isAuthFailure, 'isAuthFailure', isTrue)));
    expect(statuses.last.phase, SyncPhase.error);
    final acct = await db.accountById(account.id);
    expect(acct!.lastError, contains('rejected'));
  });

  test('run() recovers from a dropped connection with backoff and re-syncs on push', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'a@x.com'));
    server.failNextConnect = true;

    final running = syncer.run();
    // Wait until the syncer is idling after the retry.
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return syncer.status.phase != SyncPhase.waitingForMail;
    }).timeout(const Duration(seconds: 5));
    expect(server.connectCount, 2);
    expect(statuses.any((s) => s.phase == SyncPhase.backoff), isTrue);

    inbox.add(hdr(from: 'b@x.com'));
    server.push(const NewMailEvent());
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return (await allMessages()).length < 2;
    }).timeout(const Duration(seconds: 5));

    await syncer.stop();
    await running.timeout(const Duration(seconds: 5));
    expect(syncer.status.phase, SyncPhase.stopped);
  });

  group('on-demand work has its own connection', () {
    late FakeMailTransport second;
    late AccountSyncer two;

    setUp(() {
      second = server.secondConnection();
      two = AccountSyncer(
        db: db,
        transport: server,
        onDemandTransport: second,
        account: account,
        credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'),
        onStatus: statuses.add,
        sleep: (_) async {},
      );
    });

    Future<void> untilWaiting() => Future.doWhile(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return two.status.phase != SyncPhase.waitingForMail;
        }).timeout(const Duration(seconds: 5));

    test('opening, flags, archive and delete all work while sync waits for new mail', () async {
      final inbox = server.folder('INBOX', role: FolderRole.inbox);
      for (var i = 0; i < 4; i++) {
        inbox.add(hdr(from: 'a@x.com', subject: 'm$i'), body: RemoteMessageBody(text: 'body $i'));
      }
      server.failDuringIdle = true;
      final running = two.run();
      await untilWaiting();
      expect(server.idling, isTrue);

      final msgs = await allMessages();
      await two.fetchBody(msgs[0].id).timeout(const Duration(seconds: 2));
      expect((await db.messageById(msgs[0].id))!.bodyText, 'body 0');
      await two.setFlags(msgs[0].folderId, [msgs[0].uid], flagged: true);
      await two.trashOnServer(msgs[1].folderId, [msgs[1].uid]);
      await two.archiveOnServer(msgs[2].folderId, [msgs[2].uid]);

      expect(server.idling, isTrue, reason: 'still waiting for new mail, undisturbed');
      expect(second.connectCount, 1, reason: 'one connection reused');
      expect(two.status.phase, isNot(SyncPhase.error));
      await two.stop();
      await running.timeout(const Duration(seconds: 5));
      expect(second.isConnected, isFalse, reason: 'stop closes both');
    });

    test('operations stay in order, so a folder select and its command stay together', () async {
      final inbox = server.folder('INBOX', role: FolderRole.inbox);
      final sent = server.folder('Sent', role: FolderRole.sent);
      inbox.add(hdr(from: 'a@x.com', subject: 'in'), body: const RemoteMessageBody(text: 'inbox body'));
      sent.add(hdr(from: 'me@example.com', to: ['a@x.com'], subject: 'out'), body: const RemoteMessageBody(text: 'sent body'));
      await two.syncOnce();
      final msgs = await allMessages();
      final inMsg = msgs.firstWhere((m) => m.subject == 'in');
      final outMsg = msgs.firstWhere((m) => m.subject == 'out');
      expect(inMsg.uid, outMsg.uid, reason: 'same UID in two folders: the wrong folder gives the wrong body');

      await Future.wait([two.fetchBody(inMsg.id), two.fetchBody(outMsg.id)]);
      expect((await db.messageById(inMsg.id))!.bodyText, 'inbox body');
      expect((await db.messageById(outMsg.id))!.bodyText, 'sent body');
    });

    test('a dropped connection is replaced once, and a persistent failure reaches the caller', () async {
      final inbox = server.folder('INBOX', role: FolderRole.inbox);
      inbox.add(hdr(from: 'a@x.com'), body: const RemoteMessageBody(text: 'one'));
      inbox.add(hdr(from: 'a@x.com'), body: const RemoteMessageBody(text: 'two'));
      await two.syncOnce();
      final msgs = await allMessages();

      second.failFetchBody = 1;
      await two.fetchBody(msgs[0].id);
      expect(second.connectCount, 2, reason: 'reconnected for the retry');

      second.failFetchBody = 2;
      await expectLater(two.fetchBody(msgs[1].id), throwsA(isA<MailTransportException>()));
      await two.fetchBody(msgs[1].id);
      expect((await db.messageById(msgs[1].id))!.bodyText, 'two', reason: 'the queue survives a failure');
    });

    test('a sent copy syncs through the waiting loop, which then goes back to waiting', () async {
      server.folder('INBOX', role: FolderRole.inbox);
      final sent = server.folder('Sent', role: FolderRole.sent);
      server.failDuringIdle = true;
      final running = two.run();
      await untilWaiting();

      sent.add(hdr(from: 'me@example.com', to: ['a@x.com'], subject: 'just sent'));
      expect(await two.storeSentCopy('raw', appendCopy: false), isTrue);
      expect((await allMessages()).map((m) => m.subject), contains('just sent'));

      await untilWaiting();
      expect(server.idling, isTrue);
      await two.stop();
      await running.timeout(const Duration(seconds: 5));
    });
  });

  test('a merge holds across later syncs, and mail synced under the old rule is filed again', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'andrea@one.com', fromName: 'Andrea Johnson', subject: 'first'));
    inbox.add(hdr(from: 'andrea@two.com', fromName: 'Andrea Johnson', subject: 'second'));
    await syncer.syncOnce();
    await syncer.classification.mergePeople('andrea@one.com', ['andrea@two.com']);

    inbox.add(hdr(from: 'andrea@two.com', fromName: 'Andrea Johnson', subject: 'third'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();

    final rows = (await db.peopleRows()).where((r) => r.title == 'Andrea Johnson').toList();
    expect(rows, hasLength(1));
    expect((await db.messagesForRow('c:andrea@one.com')).map((m) => m.subject).toSet(), {'first', 'second', 'third'});
  });

  group('filing the user\'s mail', () {
    test("Johnny's case: a thread with Gina, Johnny on CC, never reaches Johnny's chat; his own mail does", () async {
      final inbox = server.folder('INBOX', role: FolderRole.inbox);
      final sent = server.folder('Sent', role: FolderRole.sent);
      inbox.add(hdr(from: 'gina@x.com', fromName: 'Gina Orr', to: ['me@example.com'], cc: ['johnny@x.com'], subject: 'Plans', messageId: '<g1@x>'));
      sent.add(hdr(from: 'me@example.com', to: ['gina@x.com'], cc: ['johnny@x.com'], subject: 'Re: Plans', messageId: '<m1@x>', inReplyTo: '<g1@x>'));
      sent.add(hdr(from: 'me@example.com', to: ['gina@x.com'], cc: ['johnny@x.com'], subject: 'New idea', messageId: '<m2@x>'));
      inbox.add(hdr(from: 'johnny@x.com', fromName: 'Johnny Wright', to: ['me@example.com', 'gina@x.com'], subject: 'Re: Plans', messageId: '<j1@x>', inReplyTo: '<m1@x>'));
      sent.add(hdr(from: 'me@example.com', to: ['johnny@x.com', 'gina@x.com'], subject: 'Re: Plans', messageId: '<m3@x>', inReplyTo: '<j1@x>'));
      await syncer.syncOnce();
      await db.refreshDirtyRows();

      final johnny = (await db.messagesForRow('c:johnny@x.com')).map((m) => m.messageId).toSet();
      expect(johnny, {'<j1@x>', '<m3@x>'}, reason: 'what he wrote, and the answer to him');
      final gina = (await db.messagesForRow('c:gina@x.com')).map((m) => m.messageId).toSet();
      expect(gina, {'<g1@x>', '<m1@x>', '<m2@x>'});
    });

    test('a reply synced before the mail it answers is filed again when that mail arrives', () async {
      final sent = server.folder('Sent', role: FolderRole.sent);
      sent.add(hdr(from: 'me@example.com', to: ['someone@else.com', 'gina@x.com'], subject: 'Re: Old', messageId: '<m9@x>', inReplyTo: '<g9@x>'));
      await syncer.syncOnce();
      expect((await db.messagesForRow('c:someone@else.com')).map((m) => m.messageId), ['<m9@x>'], reason: 'first To until the original is known');

      server.folder('Archive', role: FolderRole.archive).add(hdr(from: 'gina@x.com', to: ['me@example.com'], subject: 'Old', messageId: '<g9@x>'));
      await syncer.syncOnce();
      await db.refreshDirtyRows();
      expect((await db.messagesForRow('c:gina@x.com')).map((m) => m.messageId), containsAll(['<m9@x>']));
      expect(await db.messagesForRow('c:someone@else.com'), isEmpty);
    });

    test('machine addresses the user wrote to get no chat; a first email to a person does', () async {
      final sent = server.folder('Sent', role: FolderRole.sent);
      sent.add(hdr(from: 'me@example.com', to: ['3lvdfzhakdwmhpphmfqx7k2q@scoutcamp.bounces.google.com'], subject: 'Re: Return to sender'));
      sent.add(hdr(from: 'me@example.com', to: ['bounces+20442786-ca12@em.sendgrid.net'], subject: 'Unsubscribe'));
      sent.add(hdr(from: 'me@example.com', to: ['msprvs1=19963nkdjii2=bounces-123@bounces.example.com'], subject: 'x'));
      sent.add(hdr(from: 'me@example.com', to: ['nyt@service.newyorktimes.com'], subject: 'Stop'));
      sent.add(hdr(from: 'me@example.com', to: ['new.person@company.com'], subject: 'Hello for the first time'));
      sent.add(hdr(from: 'me@example.com', to: ['friend@gmail.com'], subject: 'Lunch?'));
      await syncer.syncOnce();
      await db.refreshDirtyRows();

      final chats = (await db.peopleRows()).map((r) => r.rowKey).toSet();
      expect(chats, {'c:new.person@company.com', 'c:friend@gmail.com'});
      expect((await db.peopleRows(tab: InboxTab.feeds)), isEmpty, reason: 'nobody\'s conversation in Feeds either');
      final why = (await (db.select(db.contacts)..where((c) => c.key.equals('nyt@service.newyorktimes.com'))).getSingle()).classReasons;
      expect(why, contains('Automated address'));
    });

    test('a reply to automated mail sits with that sender, not in Chats; a manual move to Chats wins', () async {
      final inbox = server.folder('INBOX', role: FolderRole.inbox);
      final sent = server.folder('Sent', role: FolderRole.sent);
      inbox.add(hdr(from: 'noreply@shop.example', to: ['me@example.com'], subject: 'Your receipt', messageId: '<r1@x>', signals: const BulkSignals(listUnsubscribe: true, listId: true)));
      sent.add(hdr(from: 'me@example.com', to: ['help.desk.person@shop.example'], subject: 'Re: Your receipt', messageId: '<m5@x>', inReplyTo: '<r1@x>'));
      sent.add(hdr(from: 'me@example.com', to: ['bounces+123456abc@em.sendgrid.net'], subject: 'Unsubscribe'));
      await syncer.syncOnce();
      await db.refreshDirtyRows();
      expect((await db.peopleRows()).map((r) => r.rowKey), isEmpty);
      expect((await db.messagesForRow('c:noreply@shop.example')).map((m) => m.messageId), containsAll(['<r1@x>', '<m5@x>']));

      await syncer.classification.moveSender('bounces+123456abc@em.sendgrid.net', Bucket.people);
      await db.refreshDirtyRows();
      expect((await db.peopleRows()).map((r) => r.rowKey), contains('c:bounces+123456abc@em.sendgrid.net'));
    });
  });

  group('reconciliation', () {
    test('a list read from the wrong folder deletes nothing', () async {
      final inbox = server.folder('INBOX', role: FolderRole.inbox);
      for (var i = 0; i < 80; i++) {
        inbox.add(hdr(from: 'a$i@x.com'));
      }
      await syncer.syncOnce();
      expect(await allMessages(), hasLength(80));

      server.wrongExistingOnce = {1, 2, 3};
      await syncer.syncOnce();
      expect(await allMessages(), hasLength(80));
    });

    test('a real mass deletion on the server is confirmed and applied', () async {
      final inbox = server.folder('INBOX', role: FolderRole.inbox);
      for (var i = 0; i < 80; i++) {
        inbox.add(hdr(from: 'a$i@x.com'));
      }
      await syncer.syncOnce();
      inbox.messages.removeWhere((uid, _) => uid > 10);
      await syncer.syncOnce();
      expect(await allMessages(), hasLength(10));
    });

    test('rows lost locally are downloaded again, without notifications', () async {
      final notified = <int>[];
      final s = AccountSyncer(
        db: db,
        transport: server,
        account: account,
        credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'),
        pageSize: 3,
        sleep: (_) async {},
        onNewMessages: notified.addAll,
      );
      final inbox = server.folder('INBOX', role: FolderRole.inbox);
      for (var i = 0; i < 12; i++) {
        inbox.add(hdr(from: 'a$i@x.com', subject: 's$i'));
      }
      await s.syncOnce();
      await db.customStatement('DELETE FROM messages WHERE uid BETWEEN 2 AND 10');
      expect(await allMessages(), hasLength(3));

      await s.syncOnce();
      final msgs = await allMessages();
      expect(msgs, hasLength(12));
      expect(msgs.map((m) => m.subject).toSet(), {for (var i = 0; i < 12; i++) 's$i'});
      expect(notified, isEmpty, reason: 'restored mail is not new mail');
    });
  });

  test('folders that disappear on the server are removed locally', () async {
    server.folder('INBOX', role: FolderRole.inbox);
    server.folder('Projects');
    await syncer.syncOnce();
    expect((await db.foldersForAccount(account.id)).map((f) => f.path).toSet(), {'INBOX', 'Projects'});
    server.folders.remove('Projects');
    await syncer.syncOnce();
    expect((await db.foldersForAccount(account.id)).map((f) => f.path).toSet(), {'INBOX'});
  });

  test('send-as aliases are discovered from the Sent folder and mail is re-filed', () async {
    // The user (me@example.com) also sends as me@mydomain.com. A reply to
    // that alias arrived in INBOX first, before Sent was synced.
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'sarah@x.com', to: ['me@mydomain.com'], subject: 'Re: hello'));
    inbox.add(hdr(from: 'me@mydomain.com', to: ['me@example.com'], subject: 'note to self'));
    final sent = server.folder('Sent', role: FolderRole.sent);
    sent.add(hdr(from: 'me@mydomain.com', fromName: 'Me Alias', to: ['sarah@x.com'], subject: 'hello'));
    sent.add(hdr(from: 'me@mydomain.com', to: ['tom@x.com'], subject: 'hi tom'));

    await syncer.syncOnce();

    final ids = await db.select(db.identities).get();
    expect(ids.map((i) => i.email), contains('me@mydomain.com'));
    expect(ids.firstWhere((i) => i.email == 'me@mydomain.com').discovered, isTrue);
    expect(ids.firstWhere((i) => i.email == 'me@mydomain.com').name, 'Me Alias');

    final msgs = await allMessages();
    final fromAlias = msgs.where((m) => m.fromAddress == 'me@mydomain.com').toList();
    expect(fromAlias.length, 3);
    expect(fromAlias.every((m) => m.isFromMe && m.fromContactKey == 'me'), isTrue, reason: 'alias resolves to me after discovery');

    final rows = await db.select(db.messageRowAssignments).get();
    final keys = <int, Set<String>>{};
    for (final r in rows) {
      keys.putIfAbsent(r.messageId, () => {}).add(r.rowKey);
    }
    final hello = msgs.firstWhere((m) => m.subject == 'hello');
    final hiTom = msgs.firstWhere((m) => m.subject == 'hi tom');
    final noteToSelf = msgs.firstWhere((m) => m.subject == 'note to self');
    expect(keys[hello.id], {'c:sarah@x.com'}, reason: 'sent mail files under the recipient');
    expect(keys[hiTom.id], {'c:tom@x.com'});
    expect(keys[noteToSelf.id], {'c:me'});
    expect(rows.any((r) => r.rowKey == 'c:me@mydomain.com'), isFalse, reason: 'no row for my own alias');

    final contacts = await db.select(db.contacts).get();
    expect(contacts.map((c) => c.key), isNot(contains('me@mydomain.com')));
    expect(contacts.map((c) => c.key), containsAll(['sarah@x.com', 'tom@x.com']));

    // The "to" participant on Sarah's reply is now marked as me.
    final parts = await (db.select(db.messageParticipants)..where((p) => p.address.equals('me@mydomain.com'))).get();
    expect(parts.every((p) => p.isMe && p.contactKey == 'me'), isTrue);

    // A second sync discovers nothing new and does not re-file.
    expect(await db.discoverIdentitiesFromSent(account.id, (await db.foldersForAccount(account.id)).firstWhere((f) => f.role == 'sent').id), 0);
  });

  test('synced replies join their parent thread; unrelated mail does not (spec 4.20)', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'sarah@x.com', subject: 'Plan', messageId: '<a@x>'));
    inbox.add(hdr(from: 'tom@x.com', subject: 'Other', messageId: '<z@x>'));
    await syncer.syncOnce();
    // Later: a reply from Joann to Sarah's message, and a header-less "Re:" from Sarah.
    inbox.add(hdr(from: 'joann@x.com', to: ['me@example.com', 'sarah@x.com'], subject: 'Re: Plan', messageId: '<b@x>', inReplyTo: '<a@x>'));
    inbox.add(hdr(from: 'sarah@x.com', subject: 'Re: Plan', messageId: '<c@x>'));
    await syncer.syncOnce();

    final msgs = await allMessages();
    String keyOf(String mid) => msgs.firstWhere((m) => m.messageId == mid).threadKey!;
    expect(keyOf('<a@x>'), '<a@x>');
    expect(keyOf('<b@x>'), '<a@x>', reason: 'In-Reply-To links it');
    expect(keyOf('<c@x>'), '<a@x>', reason: 'subject fallback: Re: prefix, shared participant, inside 30 days');
    expect(keyOf('<z@x>'), '<z@x>');
    expect(await db.threadCounts(['<a@x>', '<z@x>']), {'<a@x>': 3, '<z@x>': 1});
    expect((await db.threadMessages('<a@x>')).map((m) => m.messageId).toList(), ['<a@x>', '<b@x>', '<c@x>']);
  });

  test('accounts can be soft-checked for message counts', () async {
    server.folder('INBOX', role: FolderRole.inbox).add(hdr(from: 'a@x.com'));
    await syncer.syncOnce();
    expect(await db.messageCountForAccount(account.id), 1);
    await (db.update(db.accounts)..where((a) => a.id.equals(account.id))).write(const AccountsCompanion(displayName: Value('Me')));
    expect((await db.accountById(account.id))!.displayName, 'Me');
  });
}
