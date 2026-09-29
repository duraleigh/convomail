import 'package:convomail/mail/mail_transport.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/sync_queries.dart';
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

  test('folders that disappear on the server are removed locally', () async {
    server.folder('INBOX', role: FolderRole.inbox);
    server.folder('Projects');
    await syncer.syncOnce();
    expect((await db.foldersForAccount(account.id)).map((f) => f.path).toSet(), {'INBOX', 'Projects'});
    server.folders.remove('Projects');
    await syncer.syncOnce();
    expect((await db.foldersForAccount(account.id)).map((f) => f.path).toSet(), {'INBOX'});
  });

  test('accounts can be soft-checked for message counts', () async {
    server.folder('INBOX', role: FolderRole.inbox).add(hdr(from: 'a@x.com'));
    await syncer.syncOnce();
    expect(await db.messageCountForAccount(account.id), 1);
    await (db.update(db.accounts)..where((a) => a.id.equals(account.id))).write(const AccountsCompanion(displayName: Value('Me')));
    expect((await db.accountById(account.id))!.displayName, 'Me');
  });
}
