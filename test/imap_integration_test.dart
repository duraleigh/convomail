@Tags(['integration'])
library;

import 'dart:io';

import 'package:convomail/mail/imap_transport.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_db.dart';

/// Drives the real [ImapTransport] and [AccountSyncer] against a local
/// pymap server (pure-Python IMAP with IDLE). Skipped when pymap is not
/// installed. Run with: flutter test --tags integration
///
/// pymap: pip install pymap. On Windows it is started through
/// tool/pymap_win.py (see that file for why).
void main() {
  final launcher = _findPymap();
  final port = 1143 + (DateTime.now().millisecondsSinceEpoch % 1000);

  Process? server;
  late AppDatabase db;

  setUpAll(() async {
    if (launcher == null) return;
    server = await Process.start(launcher.executable, [...launcher.args, '--port', '$port', '--no-tls', 'dict', '--demo-data']);
    server!.stderr.listen((_) {});
    server!.stdout.listen((_) {});
    // Wait for the port to accept connections.
    for (var i = 0; i < 50; i++) {
      try {
        final s = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 200));
        await s.close();
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  });

  tearDownAll(() async {
    server?.kill();
  });

  setUp(() {
    db = testDatabase();
  });

  tearDown(() => db.close());

  test('connects, lists folders, syncs demo mailbox, fetches a body, round-trips a flag', () async {
    final t = ImapTransport();
    await t.connect(ServerConfig(host: '127.0.0.1', port: port, security: ConnectionSecurity.none), const MailCredentials(username: 'demouser', password: 'demopass'));
    expect(t.isConnected, isTrue);

    final folders = await t.listFolders();
    expect(folders.map((f) => f.path), contains('INBOX'));
    expect(folders.firstWhere((f) => f.path == 'INBOX').role, FolderRole.inbox);

    final account = await insertTestAccount(db, email: 'demouser@example.com');
    final statuses = <SyncStatus>[];
    final syncer = AccountSyncer(
      db: db,
      transport: t,
      account: account,
      credentials: () async => const MailCredentials(username: 'demouser', password: 'demopass'),
      onStatus: statuses.add,
      sleep: (_) async {},
    );
    await syncer.syncOnce();
    expect(statuses.last.phase, SyncPhase.idle, reason: statuses.last.error);

    final msgs = await db.select(db.messages).get();
    expect(msgs, isNotEmpty, reason: 'pymap demo data has messages in INBOX');
    final first = msgs.first;
    expect(first.fromAddress, isNotEmpty);
    expect(first.subject, isNotEmpty);

    // Second sync is a no-op for headers (no new UIDs) and keeps counts stable.
    final before = msgs.length;
    await syncer.syncOnce();
    expect((await db.select(db.messages).get()).length, before);

    // Body on demand.
    final body = await syncer.fetchBody(first.id);
    expect((body.text ?? body.html ?? ''), isNotEmpty);
    expect((await db.messageById(first.id))!.bodyFetchedAt, isNotNull);

    // Flag round trip through the server.
    final inbox = (await db.foldersForAccount(account.id)).firstWhere((f) => f.path == 'INBOX');
    await syncer.setFlags(inbox.id, [first.uid], flagged: true);
    expect((await db.messageById(first.id))!.isFlagged, isTrue);
    await syncer.syncOnce();
    expect((await db.messageById(first.id))!.isFlagged, isTrue);

    await t.disconnect();
    expect(t.isConnected, isFalse);
  }, skip: launcher == null ? 'pymap not installed' : false, timeout: const Timeout(Duration(minutes: 2)));

  test('a wrong password is reported as an authentication failure', () async {
    final t = ImapTransport();
    await expectLater(
      t.connect(ServerConfig(host: '127.0.0.1', port: port, security: ConnectionSecurity.none), const MailCredentials(username: 'demouser', password: 'nope')),
      throwsA(predicate((e) => e.toString().contains('rejected') || e.toString().contains('MailTransportException'))),
    );
  }, skip: launcher == null ? 'pymap not installed' : false);

  test('IDLE returns when new mail arrives', () async {
    final t = ImapTransport();
    final cfg = ServerConfig(host: '127.0.0.1', port: port, security: ConnectionSecurity.none);
    const creds = MailCredentials(username: 'demouser', password: 'demopass');
    await t.connect(cfg, creds);
    await t.selectFolder('INBOX');

    // A second connection appends a message while the first idles.
    final other = ImapTransport();
    await other.connect(cfg, creds);
    final idleFuture = t.idle(timeout: const Duration(seconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await other.appendForTest('INBOX', 'From: idle@example.com\r\nTo: demouser@example.com\r\nSubject: idle test\r\nMessage-ID: <idle-${DateTime.now().millisecondsSinceEpoch}@example.com>\r\n\r\nhello\r\n');
    final event = await idleFuture;
    expect(event, isA<NewMailEvent>());
    await other.disconnect();
    await t.disconnect();
  }, skip: launcher == null ? 'pymap not installed' : false, timeout: const Timeout(Duration(minutes: 1)));
}

class _Launcher {
  const _Launcher(this.executable, this.args);
  final String executable;
  final List<String> args;
}

/// On Windows, pymap runs through tool/pymap_win.py with the system Python;
/// elsewhere the pymap script itself. Null when pymap is not importable.
_Launcher? _findPymap() {
  if (Platform.isWindows) {
    final wrapper = File('tool/pymap_win.py');
    if (!wrapper.existsSync()) return null;
    final check = Process.runSync('python', ['-c', 'import pymap']);
    if (check.exitCode != 0) return null;
    return _Launcher('python', [wrapper.absolute.path]);
  }
  for (final c in ['/usr/local/bin/pymap', '${Platform.environment['HOME']}/.local/bin/pymap']) {
    if (File(c).existsSync()) return _Launcher(c, const []);
  }
  return null;
}
