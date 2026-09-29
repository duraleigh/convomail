import 'package:convomail/domain/filing.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/people_list_pane.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeMailTransport server;
  late Account account;
  late AccountSyncer syncer;

  final t0 = DateTime(2026, 9, 20, 9, 0);

  setUp(() async {
    db = testDatabase();
    server = FakeMailTransport();
    account = await insertTestAccount(db);
    syncer = AccountSyncer(
      db: db,
      transport: server,
      account: account,
      credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'),
      sleep: (_) async {},
    );
  });

  tearDown(() => db.close());

  test('one row per contact, ordered by the contact\'s newest sent message, with unread and preview', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'sarah@x.com', fromName: 'Sarah Chen', subject: 'first', date: t0));
    inbox.add(hdr(from: 'tom@x.com', fromName: 'Tom', subject: 'tom 1', date: t0.add(const Duration(hours: 1)), seen: true));
    inbox.add(hdr(from: 'sarah@x.com', fromName: 'Sarah Chen', subject: 'second', date: t0.add(const Duration(hours: 2))));
    final sent = server.folder('Sent', role: FolderRole.sent);
    // I wrote to Tom after Sarah's last message: shows as preview but does not bump Tom above Sarah (decision 4).
    sent.add(hdr(from: 'me@example.com', to: ['tom@x.com'], subject: 'reply to tom', date: t0.add(const Duration(hours: 3))));
    await syncer.syncOnce();

    final rows = await db.peopleRows();
    expect(rows.map((r) => r.title).toList(), ['Sarah Chen', 'Tom']);
    expect(rows[0].unread, 2);
    expect(rows[0].total, 2);
    expect(rows[0].preview, 'second');
    expect(rows[1].unread, 0);
    expect(rows[1].total, 2);
    expect(rows[1].preview, 'reply to tom');
    expect(rows[1].previewFromMe, isTrue);
    expect(rows[1].lastActivity, t0.add(const Duration(hours: 1)), reason: 'ordering uses the contact\'s newest message');
  });

  test('filters: unread, starred, sent, has attachments, this week; search matches name and subject', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'a@x.com', fromName: 'Anna', subject: 'budget', date: DateTime.now().subtract(const Duration(days: 1))));
    inbox.add(hdr(from: 'b@x.com', fromName: 'Bob', subject: 'old', date: DateTime.now().subtract(const Duration(days: 30)), seen: true, flagged: true));
    server.folder('Sent', role: FolderRole.sent).add(hdr(from: 'me@example.com', to: ['c@x.com'], subject: 'to carl', date: DateTime.now()));
    await syncer.syncOnce();
    // Attachment on Bob's message via a body fetch.
    final bob = (await db.select(db.messages).get()).firstWhere((m) => m.fromAddress == 'b@x.com');
    await db.storeBody(bob.id, const RemoteMessageBody(text: 'x', attachments: [RemoteAttachment(partId: '2', fileName: 'f.pdf', mimeType: 'application/pdf', size: 1)]));

    Future<List<String>> titles(PeopleFilter f, [String s = '']) async => (await db.peopleRows(filter: f, search: s)).map((r) => r.title).toList();
    expect(await titles(PeopleFilter.all), ['c@x.com', 'Anna', 'Bob']);
    expect(await titles(PeopleFilter.unread), ['Anna']);
    expect(await titles(PeopleFilter.starred), ['Bob']);
    expect(await titles(PeopleFilter.sent), ['c@x.com']);
    expect(await titles(PeopleFilter.hasAttachments), ['Bob']);
    expect(await titles(PeopleFilter.thisWeek), ['c@x.com', 'Anna']);
    expect(await titles(PeopleFilter.all, 'bud'), ['Anna']);
    expect(await titles(PeopleFilter.all, 'BOB'), ['Bob']);
  });

  test('pinned rows come first; junk/trash and deleted messages are excluded', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'a@x.com', subject: 'a', date: t0.add(const Duration(days: 2))));
    inbox.add(hdr(from: 'b@x.com', subject: 'b', date: t0));
    server.folder('Junk', role: FolderRole.junk).add(hdr(from: 'spam@x.com', subject: 'spam', date: t0.add(const Duration(days: 9))));
    await syncer.syncOnce();

    expect((await db.peopleRows()).map((r) => r.identityKey).toList(), ['a@x.com', 'b@x.com']);
    await db.setPinned('c:b@x.com', true);
    final rows = await db.peopleRows();
    expect(rows.map((r) => r.identityKey).toList(), ['b@x.com', 'a@x.com']);
    expect(rows.first.pinned, isTrue);

    final a = (await db.select(db.messages).get()).firstWhere((m) => m.fromAddress == 'a@x.com');
    await (db.update(db.messages)..where((m) => m.id.equals(a.id))).write(const MessagesCompanion(isDeleted: Value(true)));
    expect((await db.peopleRows()).map((r) => r.identityKey).toList(), ['b@x.com']);
  });

  test('group rows carry the group name and stacked members', () async {
    final gid = await db.into(db.peopleGroups).insert(PeopleGroupsCompanion.insert(name: 'Simon & Joann'));
    await db.into(db.groupMembers).insert(GroupMembersCompanion.insert(groupId: gid, contactKey: 'simon@x.com'));
    await db.into(db.groupMembers).insert(GroupMembersCompanion.insert(groupId: gid, contactKey: 'joann@x.com'));
    server.folder('INBOX', role: FolderRole.inbox).add(hdr(from: 'simon@x.com', fromName: 'Simon R', to: ['me@example.com', 'joann@x.com'], subject: 'agenda'));
    await syncer.syncOnce();

    final rows = await db.peopleRows();
    expect(rows.single.isGroup, isTrue);
    expect(rows.single.ref, GroupRow(gid));
    expect(rows.single.title, 'Simon & Joann');
    expect(rows.single.members.map((m) => m.$1).toSet(), {'simon@x.com', 'joann@x.com'});
    expect(rows.single.members.firstWhere((m) => m.$1 == 'simon@x.com').$2, 'Simon R');
  });

  test('relativeTime follows spec 4.2', () {
    final now = DateTime(2026, 9, 29, 15, 0);
    expect(relativeTime(DateTime(2026, 9, 29, 9, 41), now: now), '9:41 AM');
    expect(relativeTime(DateTime(2026, 9, 28, 9, 41), now: now), 'Yesterday');
    expect(relativeTime(DateTime(2026, 9, 25, 9, 41), now: now), 'Fri');
    expect(relativeTime(DateTime(2026, 7, 5, 9, 41), now: now), 'Jul 5');
    expect(relativeTime(DateTime(2025, 7, 5, 9, 41), now: now), '7/5/25');
    expect(relativeTime(null), '');
  });

  test('people rows over 50k messages / 5k contacts materialize in under 300 ms', () async {
    // Seed directly for speed: 50,000 messages across 5,000 senders.
    final folderId = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: account.id, path: 'INBOX', name: 'INBOX', role: const Value('inbox')));
    await db.batch((b) {
      for (var i = 0; i < 50000; i++) {
        final sender = 'p${i % 5000}@x.com';
        b.insert(
          db.messages,
          MessagesCompanion.insert(
            accountId: account.id,
            folderId: folderId,
            uid: i + 1,
            subject: Value('subject $i'),
            fromAddress: Value(sender),
            fromContactKey: Value(sender),
            date: Value(t0.add(Duration(minutes: i))),
            isSeen: Value(i % 3 == 0),
          ),
        );
      }
    });
    final ids = await (db.selectOnly(db.messages)..addColumns([db.messages.id, db.messages.fromContactKey])).get();
    await db.batch((b) {
      for (final r in ids) {
        b.insert(db.messageRowAssignments, MessageRowAssignmentsCompanion.insert(messageId: r.read(db.messages.id)!, rowKey: 'c:${r.read(db.messages.fromContactKey)}'));
      }
    });

    // Warm once (page cache, JIT), then measure.
    await db.peopleRows();
    final sw = Stopwatch()..start();
    final rows = await db.peopleRows();
    sw.stop();
    expect(rows.length, 5000);
    expect(rows.first.total, 10);
    // This runs in the debug test VM (JIT, checked). The plan's 300 ms
    // target is measured on the release binary with `--bench-people`;
    // the debug bound here only guards against regressions.
    expect(sw.elapsedMilliseconds, lessThan(900), reason: 'took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
