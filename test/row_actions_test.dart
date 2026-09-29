import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/sync/row_actions.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeMailTransport server;
  late ProviderContainer container;
  late Account account;
  late AccountSyncer syncer;

  setUp(() async {
    db = testDatabase();
    server = FakeMailTransport();
    account = await insertTestAccount(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) => db),
      credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
      transportFactoryProvider.overrideWith((ref) => () => server),
      rowActionsProvider.overrideWith((ref) => RowActions(ref, undoWindow: const Duration(milliseconds: 150))),
    ]);
    syncer = AccountSyncer(
      db: db,
      transport: server,
      account: account,
      credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'),
      sleep: (_) async {},
    );
    // Register the syncer with the controller so actions can reach the server.
    container.read(syncControllerProvider).adoptForTest(account.id, syncer);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('archive hides locally at once, commits to the server after the undo window (Gmail: expunge)', () async {
    await (db.update(db.accounts)..where((a) => a.id.equals(account.id))).write(const AccountsCompanion(providerId: Value('gmail')));
    account = (await db.accountById(account.id))!;
    syncer = AccountSyncer(db: db, transport: server, account: account, credentials: () async => const MailCredentials(username: 'x', password: 'secret'), sleep: (_) async {});
    container.read(syncControllerProvider).adoptForTest(account.id, syncer);

    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'a@x.com', subject: 'one'));
    inbox.add(hdr(from: 'a@x.com', subject: 'two'));
    inbox.add(hdr(from: 'b@x.com', subject: 'keep'));
    await syncer.syncOnce();

    final actions = container.read(rowActionsProvider);
    final pending = await actions.archiveRow('c:a@x.com');
    expect(pending, isNotNull);
    expect(container.read(pendingActionsProvider).length, 1);
    expect((await db.peopleRows()).map((r) => r.identityKey).toList(), ['b@x.com'], reason: 'hidden immediately');
    expect(inbox.messages.length, 3, reason: 'server untouched inside the undo window');

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(container.read(pendingActionsProvider), isEmpty);
    expect(inbox.messages.length, 1, reason: 'expunged from INBOX on Gmail');
    expect(server.log.any((l) => l.startsWith('delete')), isTrue);
    expect((await db.select(db.messages).get()).length, 1);
  });

  test('undo restores the rows and never touches the server', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'a@x.com', subject: 'one'));
    await syncer.syncOnce();

    final actions = container.read(rowActionsProvider);
    final pending = (await actions.archiveRow('c:a@x.com'))!;
    expect(await db.peopleRows(), isEmpty);
    await actions.undo(pending);
    expect((await db.peopleRows()).length, 1);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(inbox.messages.length, 1);
    expect(server.log.where((l) => l.startsWith('delete') || l.startsWith('move')), isEmpty);
  });

  test('trash with selective keep moves only the chosen messages to Trash', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    final trash = server.folder('Trash', role: FolderRole.trash);
    final u1 = inbox.add(hdr(from: 'a@x.com', subject: 'delete me'));
    final u2 = inbox.add(hdr(from: 'a@x.com', subject: 'keep me'));
    await syncer.syncOnce();
    final msgs = await db.messagesForRow('c:a@x.com');
    final deleteMe = msgs.firstWhere((m) => m.subject == 'delete me');

    await container.read(rowActionsProvider).trashRow('c:a@x.com', messageIds: [deleteMe.id]);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(inbox.messages.keys.toSet(), {u2});
    expect(trash.messages.values.single.subject, 'delete me');
    expect(inbox.messages.containsKey(u1), isFalse);
    final remaining = await db.messagesForRow('c:a@x.com');
    expect(remaining.single.subject, 'keep me');
  });

  test('archive on a non-Gmail server moves to Archive, creating it if missing', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'a@x.com', subject: 'one'));
    await syncer.syncOnce();
    expect(server.folders.containsKey('Archive'), isFalse);

    await container.read(rowActionsProvider).archiveRow('c:a@x.com');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(server.folders['Archive']!.messages.length, 1);
    expect(inbox.messages, isEmpty);
    expect(server.log, contains('create Archive'));
  });

  test('mark row read applies locally and on the server; pin toggles', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    final uid = inbox.add(hdr(from: 'a@x.com', subject: 'one'));
    await syncer.syncOnce();
    final actions = container.read(rowActionsProvider);

    await actions.markRowRead('c:a@x.com');
    expect((await db.peopleRows()).single.unread, 0);
    expect(inbox.messages[uid]!.flags.seen, isTrue);

    await actions.togglePin('c:a@x.com');
    expect((await db.peopleRows()).single.pinned, isTrue);
    await actions.togglePin('c:a@x.com');
    expect((await db.peopleRows()).single.pinned, isFalse);
  });

  test('a failed server commit restores the messages locally', () async {
    final inbox = server.folder('INBOX', role: FolderRole.inbox);
    inbox.add(hdr(from: 'a@x.com', subject: 'one'));
    await syncer.syncOnce();
    await syncer.stop(); // disconnected: server ops will throw
    server.failNextConnect = true;

    await container.read(rowActionsProvider).archiveRow('c:a@x.com');
    expect(await db.peopleRows(), isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect((await db.peopleRows()).length, 1, reason: 'restored after the server call failed');
  });
}
