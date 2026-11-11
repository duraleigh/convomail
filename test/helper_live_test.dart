import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convomail/domain/classifier.dart';
import 'package:convomail/helper/helper_client.dart';
import 'package:convomail/helper/helper_sync.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/classification_queries.dart';
import 'package:convomail/store/database.dart' hide ClassificationRule;
import 'package:convomail/store/done_queries.dart';
import 'package:convomail/store/helper_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/sync/classification_service.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// The app and the real helper program, talking over a real connection on
/// this computer. Nothing here reaches the internet: the helper runs from
/// helper/ with a scratch folder and a scratch database, and no mailbox is
/// connected to it.
///
/// Needs PHP on this computer; without it these checks are skipped.
List<String> _php() {
  const ext = 'C:/PHP/ext';
  return ['php', if (Directory(ext).existsSync()) ...['-d', 'extension_dir=$ext'], '-d', 'extension=pdo_sqlite', '-d', 'extension=sqlite3'];
}

bool _phpWorks() {
  try {
    final php = _php();
    final r = Process.runSync(php.first, [...php.skip(1), '-r', 'echo in_array("sqlite", PDO::getAvailableDrivers()) ? "ok" : "no";']);
    return r.exitCode == 0 && '${r.stdout}'.trim() == 'ok';
  } on ProcessException {
    return false;
  }
}

void main() {
  final skip = _phpWorks() ? null : 'PHP with SQLite is not on this computer';
  const me = RemoteAddress('me@example.com');
  late Directory home;
  late Process server;
  late String base;
  late Map<String, String> env;

  Future<String> newCode() async {
    final php = _php();
    final r = await Process.run(php.first, [...php.skip(1), 'helper/tests/make_code.php'], environment: env);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return '${r.stdout}'.trim();
  }

  setUpAll(() async {
    if (skip != null) return;
    home = await Directory.systemTemp.createTemp('precis-live-');
    File('${home.path}/setup.key').writeAsStringSync('live-setup-key');
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    base = 'http://127.0.0.1:$port';
    env = {...Platform.environment, 'PRECIS_HOME': home.path, 'PRECIS_ROOT': Directory('helper').absolute.path};
    final php = _php();
    server = await Process.start(php.first, [...php.skip(1), '-S', '127.0.0.1:$port', 'helper/public/index.php'], environment: env);
    unawaited(server.stderr.drain<void>());
    unawaited(server.stdout.drain<void>());
    // Wait until it answers.
    final client = HttpClient();
    for (var i = 0; i < 80; i++) {
      try {
        final r = await (await client.getUrl(Uri.parse('$base/api/ping'))).close();
        await r.drain<void>();
        break;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    // Set it up through its own setup page, as the owner would.
    final request = await client.postUrl(Uri.parse('$base/setup'));
    request.followRedirects = false;
    request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.write(Uri(queryParameters: {'key': 'live-setup-key', 'db_name': 'sqlite_live', 'db_user': '', 'db_pass': '', 'db_host': 'localhost', 'pass': 'a passphrase for the test', 'pass2': 'a passphrase for the test'}).query);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    expect(response.statusCode, 303, reason: body);
    client.close(force: true);
  });

  tearDownAll(() async {
    if (skip != null) return;
    server.kill();
    await server.exitCode;
    try {
      home.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold the database file a moment longer; it is in the temp folder.
    }
  });

  test('a real helper is at the address, set up, and refuses a device it does not know', () async {
    final client = HelperClient(base);
    expect(await client.ping(), isNotEmpty);
    await expectLater(client.withToken('1.${'x' * 43}').status(), throwsA(isA<HelperException>().having((e) => e.signedOut, 'signedOut', isTrue)));
    await expectLater(client.pair('WRONGONE', name: 'x', kind: 'windows'), throwsA(isA<HelperException>().having((e) => e.message, 'message', contains('not right'))));
    expect(File('${home.path}/setup.key').existsSync(), isFalse, reason: 'the setup link is used up');
    expect(File('${home.path}/master.key').existsSync(), isTrue);
  }, skip: skip);

  test('the app joins the real helper, sends up what it knows, and the two keep each other in step', () async {
    final db = testDatabase();
    final imap = FakeMailTransport();
    final vault = InMemoryCredentialStore();
    final account = await insertTestAccount(db);
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), isDefault: const Value(true)));
    final inbox = imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    final t = DateTime.now().subtract(const Duration(hours: 5));
    inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah Chen'), to: const [me], subject: 'Lunch?', messageId: '<lunch@x.com>', date: t));
    for (var i = 0; i < 3; i++) {
      inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('hello@dailybrief.com', 'The Daily Brief'), to: const [me], subject: 'Daily Brief #$i', messageId: '<brief-$i@dailybrief.com>', date: t, signals: const BulkSignals(listUnsubscribe: true, listId: true, listIdValue: 'brief.dailybrief.com')));
    }
    imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('sarah@x.com')], subject: 'Re: Lunch?', messageId: '<mine-1@example.com>', date: t));
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) => db),
      credentialStoreProvider.overrideWith((ref) => vault),
    ]);
    final link = container.read(helperProvider.notifier);
    Future<Contact> contact(String key) => (db.select(db.contacts)..where((c) => c.key.equals(key))).getSingle();

    await link.connect(base, await newCode(), name: 'Live test PC');
    await link.idle();
    expect(link.lastFailure, isNull);
    expect(container.read(helperProvider).error, isNull);
    expect(container.read(helperProvider).sentUp, isTrue);

    // A second device, to see what the helper now holds.
    final other = HelperClient(base);
    final second = other.withToken((await other.pair(await newCode(), name: 'Second', kind: 'android')).token);
    final all = <String, Map<String, Object?>>{};
    var cursor = 0;
    Future<void> pullAll() async {
      while (true) {
        final page = await second.changes(cursor);
        for (final i in page.items) {
          all['${i['kind']}|${i['k']}'] = i;
        }
        cursor = page.next;
        if (!page.more) break;
      }
    }

    await pullAll();
    expect((all['sender|sarah@x.com']!['data']! as Map)['cls'], 'people');
    expect((all['sender|hello@dailybrief.com']!['data']! as Map)['cls'], 'feeds');
    expect((all['names|user']!['data']! as Map)['first'], ['clay']);
    expect(all.keys, contains('me|me@example.com'));
    expect(all.keys, contains('tag|Newsletter'));
    final status = await second.status();
    expect(status['accounts'], isEmpty, reason: 'no mailbox is connected in this check');

    // A move made here reaches the other device through the helper.
    final service = container.read(classificationServiceProvider);
    await service.moveSender('hello@dailybrief.com', Bucket.people);
    final m = await (db.select(db.messages)..where((x) => x.messageId.equals('<lunch@x.com>'))).getSingle();
    await db.setMessagesDone([m.id], true);
    await link.syncNow();
    await pullAll();
    final moved = (all['sender|hello@dailybrief.com']!['data']! as Map).cast<String, Object?>();
    expect([moved['cls'], moved['src']], ['people', 'override']);
    expect(all['done|<lunch@x.com>']!['deleted'], isFalse);

    // A rule made on the other device: the real helper sorts Sarah again
    // by it, and this PC follows.
    await second.push([
      {'kind': 'rule', 'k': 'rule-from-phone', 'data': {'uid': 'rule-from-phone', 'field': 'sender', 'pattern': 'sarah@x.com', 'bucket': 'feeds', 'category': null, 'at': 5}},
    ]);
    await link.syncNow();
    expect(link.lastFailure, isNull);
    final sarah = await contact('sarah@x.com');
    expect([sarah.classification, sarah.classificationSource], ['feeds', 'rule']);
    expect(sarah.classReasons, 'Mail from sarah@x.com → Feed or Noise');
    expect((await db.loadRules()).single.pattern, 'sarah@x.com');
    expect((await db.watchPeopleRows(tab: InboxTab.people).first).map((r) => r.rowKey), isNot(contains('c:sarah@x.com')));
    expect(await db.helperOutboxCount(), 0, reason: 'nothing that came down is waiting to go back up');

    // Removing the rule there hands Sarah back to Chats here.
    await second.push([
      {'kind': 'rule', 'k': 'rule-from-phone', 'deleted': true},
    ]);
    await link.syncNow();
    expect((await contact('sarah@x.com')).classification, 'people');
    expect(await db.loadRules(), isEmpty);

    // Signing this PC out from the other device stops it following.
    final devices = await second.devices();
    final mine = devices.devices.firstWhere((d) => d['name'] == 'Live test PC');
    await second.signOut((mine['id']! as num).toInt());
    await link.syncNow();
    expect(container.read(helperProvider).connected, isFalse);
    expect(await vault.read(HelperSync.tokenKey), isNull);

    await link.idle();
    container.dispose();
    await db.close();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
