import 'dart:convert';
import 'dart:io';

import 'package:convomail/app/settings.dart';
import 'package:convomail/helper/device_join.dart';
import 'package:convomail/helper/helper_client.dart';
import 'package:convomail/helper/helper_pass.dart';
import 'package:convomail/helper/helper_sync.dart';
import 'package:convomail/helper/sending_sync.dart';
import 'package:convomail/mail/mail_sender.dart';
import 'package:convomail/mail/mail_transport.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/compose_queries.dart';
import 'package:convomail/store/database.dart' hide ClassificationRule;
import 'package:convomail/store/helper_queries.dart';
import 'package:convomail/store/merge_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/sync/contacts_sync.dart';
import 'package:convomail/sync/schedule_service.dart';
import 'package:convomail/sync/send_service.dart';
import 'package:convomail/sync/sent_sound.dart';
import 'package:convomail/sync/signature_service.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/sync/waiting_sends.dart';
import 'package:drift/drift.dart' show Value;
import 'package:enough_mail/enough_mail.dart' show MimeMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_helper.dart';
import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Catches what a send would sign in with, then stops the send (or, when
/// told to, lets it through, or fails the way no signal does).
class _CatchingSender implements MailSender {
  ServerConfig? server;
  MailCredentials? credentials;

  /// 'stop': refuse every send. 'offline': fail as with no signal. 'ok': send.
  String mode = 'stop';
  final List<String> sentSubjects = [];

  @override
  Future<void> send(ServerConfig server, MailCredentials credentials, MimeMessage message, {required RemoteAddress from, required List<RemoteAddress> recipients}) async {
    this.server = server;
    this.credentials = credentials;
    if (mode == 'offline') throw const MailTransportException('Could not reach the mail server.', offline: true);
    if (mode == 'stop') throw const MailTransportException('stopped by the check');
    sentSubjects.add(message.decodeSubject() ?? '');
  }

  @override
  Future<void> verify(ServerConfig server, MailCredentials credentials) async {}
}

/// One device in a check: its own notes, its own locked store, its own
/// files, all talking to the same stand-in helper.
class _Device {
  _Device(this.helper, this.files) {
    db = testDatabase();
    vault = InMemoryCredentialStore();
    imap = FakeMailTransport();
    imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) => db),
      settingsStoreProvider.overrideWith((ref) => db),
      credentialStoreProvider.overrideWith((ref) => vault),
      helperHttpProvider.overrideWith((ref) => helper.call),
      transportFactoryProvider.overrideWith((ref) => () => imap),
      mailSenderProvider.overrideWith((ref) => sender),
      sentSoundProvider.overrideWith((ref) => () async {
            sounds++;
          }),
      appFilesDirProvider.overrideWith((ref) => () async => files),
      signatureImagesDirProvider.overrideWith((ref) async => Directory(p.join(files.path, 'signature-images'))..createSync(recursive: true)),
      // As the real app is wired: a joined device wipes when signed out.
      signedOutHandlerProvider.overrideWith((ref) => () => ref.read(deviceJoinProvider).signedOut()),
    ]);
  }

  final FakeHelper helper;
  final Directory files;
  late final AppDatabase db;
  late final InMemoryCredentialStore vault;
  late final FakeMailTransport imap;
  late final ProviderContainer container;
  final sender = _CatchingSender();

  /// How many times the "sent" sound would have played.
  int sounds = 0;

  HelperSync get link => container.read(helperProvider.notifier);
  HelperLink get state => container.read(helperProvider);
  SendingSync get sending => container.read(sendingSyncProvider);
  DeviceJoin get joiner => container.read(deviceJoinProvider);

  /// One full round with the helper, then the sending addresses.
  Future<void> inStep() async {
    await link.syncNow();
    await link.idle();
    await sending.run();
    await link.syncNow();
    await link.idle();
  }

  Future<Account?> account() async => (await db.allAccounts()).firstOrNull;

  /// Fetches mail the way the app does, with whatever the account signs in with.
  Future<void> fetchMail() async {
    final a = (await account())!;
    final syncer = AccountSyncer(db: db, transport: imap, account: a, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
  }

  Future<void> close() async {
    await link.idle();
    // Anything still reading this device's notes finishes first.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    container.dispose();
    await db.close();
  }
}

/// Step 5 of the Précis plan: a phone or second PC that joins with a code
/// and no Gmail sign-in, and does everything the first PC does.
void main() {
  const me = RemoteAddress('me@example.com');
  late FakeHelper helper;
  late Directory temp;
  final devices = <_Device>[];

  DateTime ago({int days = 0, int hours = 0}) => DateTime.now().subtract(Duration(days: days, hours: hours));

  _Device device(String name) {
    final d = _Device(helper, Directory(p.join(temp.path, name))..createSync(recursive: true));
    devices.add(d);
    return d;
  }

  /// The PC that set Précis up: its own mailbox with a password, already following the helper.
  Future<_Device> firstPc() async {
    final pc = device('pc');
    helper.code = 'GOODCODE';
    final account = await insertTestAccount(pc.db);
    await pc.vault.write(CredentialStore.passwordKey(account.id), 'the-gmail-app-password');
    await pc.db.into(pc.db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), isDefault: const Value(true)));
    await pc.link.connect('localhost', 'good-code', name: 'Clay PC');
    await pc.link.idle();
    return pc;
  }

  /// A phone that joins with the next code.
  Future<_Device> phone({String name = 'phone'}) async {
    final ph = device(name);
    helper.code = 'NEXTCODE';
    await ph.joiner.join('localhost', 'next-code', name: 'My phone');
    await ph.link.idle();
    return ph;
  }

  setUp(() {
    helper = FakeHelper();
    temp = Directory.systemTemp.createTempSync('precis-devices-');
  });

  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('joining with a code and no Gmail sign-in', () {
    test('the helper says whose mailbox it is, and the device sets it up with no password anywhere on it', () async {
      final ph = await phone();
      final account = (await ph.account())!;
      expect(account.email, 'me@example.com');
      expect(account.authMethod, kHelperAuth);
      expect(account.imapHost, 'imap.gmail.com');
      expect(account.smtpHost, 'smtp.gmail.com');
      expect(account.providerId, 'gmail');
      final identity = (await ph.db.identitiesForAccount(account.id)).single;
      expect(identity.email, 'me@example.com');
      expect(identity.isDefault, isTrue);
      expect(await ph.vault.read(CredentialStore.passwordKey(account.id)), isNull, reason: 'a joined device holds no mailbox password');
      expect(await ph.vault.read(HelperSync.tokenKey), isNotNull);
      expect(await ph.joiner.joined, isTrue);
      expect(ph.container.read(settingsProvider).onboardingDone, isTrue);
      expect(ph.container.read(joinNoticeProvider), isNull);
      // It took nothing up: a fresh device has nothing of its own to send.
      expect(helper.seeded, isEmpty);
      expect(helper.pushed, isEmpty);
      expect(ph.state.sentUp, isTrue);
    });

    test('a wrong code joins nothing', () async {
      final ph = device('phone');
      await expectLater(ph.joiner.join('localhost', 'WRONG'), throwsA(isA<HelperException>()));
      expect(await ph.account(), isNull);
      expect(await ph.joiner.joined, isFalse);
    });

    test('while Google has not allowed the helper full mail access, the device says what to do and sets nothing up; after, it carries on by itself', () async {
      helper.grantsMail = false;
      final ph = await phone();
      expect(await ph.account(), isNull);
      expect(ph.container.read(joinNoticeProvider), contains('Connect Google again'));
      helper.grantsMail = true;
      await ph.joiner.setUpMailbox();
      expect((await ph.account())!.authMethod, kHelperAuth);
      expect(ph.container.read(joinNoticeProvider), isNull);
    });

    test('a device that already has a mailbox does not join this way', () async {
      final pc = await firstPc();
      helper.code = 'NEXTCODE';
      await expectLater(pc.joiner.join('localhost', 'next-code'), throwsA(isA<HelperException>()));
      expect(await pc.joiner.joined, isFalse);
    });
  });

  group('the pass to the mailbox', () {
    test('a joined device signs in with a pass from the helper, kept only while it lasts', () async {
      final ph = await phone();
      final pass = ph.container.read(helperPassProvider);
      final first = await pass.credentials('me@example.com');
      expect(first.pass, isTrue);
      expect(first.username, 'me@example.com');
      expect(first.password, 'pass-1');
      expect((await pass.credentials('me@example.com')).password, 'pass-1', reason: 'the same pass while it has time left');
      expect(helper.passes, 1);
      pass.forget();
      expect((await pass.credentials('me@example.com')).password, 'pass-2');
      // A pass about to run out is not kept.
      helper.passSeconds = 100;
      pass.forget();
      await pass.access();
      await pass.access();
      expect(helper.passes, 4);
      expect('$first', isNot(contains('pass-1')), reason: 'a pass never shows in a log line');
    });

    test('a helper out of reach is not a wrong password: the mail engine waits and tries again', () async {
      final ph = await phone();
      helper.unreachable = true;
      await expectLater(ph.container.read(helperPassProvider).credentials('me@example.com'), throwsA(isA<MailTransportException>().having((e) => e.isAuthFailure, 'isAuthFailure', isFalse)));
      helper.unreachable = false;
      helper.grantsMail = false;
      await expectLater(
        ph.container.read(helperPassProvider).credentials('me@example.com'),
        throwsA(isA<MailTransportException>().having((e) => e.message, 'message', contains('Connect Google again')).having((e) => e.isAuthFailure, 'isAuthFailure', isFalse)),
      );
    });

    test('sending from a joined device uses the pass; the first PC still uses its own password', () async {
      final ph = await phone();
      final account = (await ph.account())!;
      const mail = ComposeSubmission(accountId: 0, identityId: null, to: [RemoteAddress('sarah@x.com')], subject: 'Hello', bodyHtml: '<p>Hi</p>');
      await expectLater(
        ph.container.read(sendServiceProvider).send(ComposeSubmission(accountId: account.id, identityId: null, to: mail.to, subject: mail.subject, bodyHtml: mail.bodyHtml), token: 't1'),
        throwsA(isA<MailTransportException>()),
      );
      expect(ph.sender.credentials!.pass, isTrue);
      expect(ph.sender.credentials!.password, startsWith('pass-'));
      expect(ph.sender.server!.host, 'smtp.gmail.com');

      final pc = await firstPc();
      final own = (await pc.account())!;
      await expectLater(
        pc.container.read(sendServiceProvider).send(ComposeSubmission(accountId: own.id, identityId: null, to: mail.to, subject: mail.subject, bodyHtml: mail.bodyHtml), token: 't2'),
        throwsA(isA<MailTransportException>()),
      );
      expect(pc.sender.credentials!.pass, isFalse);
      expect(pc.sender.credentials!.password, 'the-gmail-app-password');
    });

    test('calendar and contacts reach Google with the same pass on a joined device, and never on the first PC', () async {
      final ph = await phone();
      final google = ph.container.read(googleOAuthProvider);
      expect(await google.isConnected, isTrue);
      expect(await google.hasCalendar, isTrue);
      expect(await google.accessToken(), startsWith('pass-'));
      helper.grantsCalendar = false;
      ph.container.read(helperPassProvider).forget();
      expect(await google.hasCalendar, isFalse);

      final pc = await firstPc();
      final own = pc.container.read(googleOAuthProvider);
      expect(await own.usesHelper, isFalse);
      expect(await own.isConnected, isFalse, reason: 'the first PC has its own Google sign-in or none');
    });
  });

  group('the addresses you send from', () {
    /// The first PC with a second address that sends through its own server,
    /// with a password in the PC's locked store and a picture in its signature.
    Future<(_Device, Identity)> pcWithAddresses() async {
      final pc = await firstPc();
      final account = (await pc.account())!;
      final id = await pc.db.addIdentity(account.id, 'ca@clayaiken.example', name: 'Clay Aiken');
      await pc.db.setIdentityServer(id, const ServerConfig(host: 'smtp.forwardemail.example', port: 465, security: ConnectionSecurity.ssl));
      await pc.vault.write(CredentialStore.identityPasswordKey(id), 'send-password-123');
      final picture = File(p.join(pc.files.path, 'signature-images', 'logo1234.png'))..createSync(recursive: true);
      picture.writeAsBytesSync([1, 2, 3, 4, 5]);
      final doc = {
        'document': {
          'type': 'page',
          'children': [
            {'type': 'paragraph', 'data': {'delta': [{'insert': 'Clay Aiken'}]}},
            {'type': 'image', 'data': {'url': picture.path, 'align': 'left'}},
          ],
        },
      };
      await pc.db.setIdentitySignature(id, json: jsonEncode(doc), plainText: 'Clay Aiken');
      return (pc, (await pc.db.identityById(id))!);
    }

    test('the first PC hands them to the helper once; a phone that joins can send from every one, nothing typed', () async {
      final (pc, ca) = await pcWithAddresses();
      await pc.inStep();
      expect(helper.sending.keys, unorderedEquals(['me@example.com', 'ca@clayaiken.example']));
      expect(helper.sending['ca@clayaiken.example']!['password'], 'send-password-123');
      expect(helper.sending['ca@clayaiken.example']!['host'], 'smtp.forwardemail.example');
      expect('${helper.sending['ca@clayaiken.example']!['signatureJson']}', contains('pic:logo1234.png'));
      expect('${helper.sending['ca@clayaiken.example']!['signatureJson']}', isNot(contains(pc.files.path.replaceAll(r'\', r'\\'))), reason: 'no path from the PC travels');
      expect(helper.sending['me@example.com']!.containsKey('password'), isFalse, reason: 'an address that sends through Gmail has no password of its own');

      final ph = await phone();
      await ph.inStep();
      final account = (await ph.account())!;
      final there = {for (final i in await ph.db.identitiesForAccount(account.id)) i.email: i};
      expect(there.keys, unorderedEquals(['me@example.com', 'ca@clayaiken.example']));
      final theirs = there['ca@clayaiken.example']!;
      expect(theirs.name, 'Clay Aiken');
      expect(theirs.smtpHost, 'smtp.forwardemail.example');
      expect(theirs.smtpPort, 465);
      expect(await ph.vault.read(CredentialStore.identityPasswordKey(theirs.id)), 'send-password-123');
      // The signature arrived with its picture, as a file of the phone's own.
      final picture = File(p.join(ph.files.path, 'signature-images', 'logo1234.png'));
      expect(picture.readAsBytesSync(), [1, 2, 3, 4, 5]);
      expect(theirs.signatureJson, contains(jsonEncode(picture.path).replaceAll('"', '')));
      expect(theirs.signature, 'Clay Aiken');
      expect(there['me@example.com']!.isDefault, isTrue);
      expect(there['me@example.com']!.name, 'Clay Example');

      // The phone sends from that address through its own server, with its own login.
      await expectLater(
        ph.container.read(sendServiceProvider).send(ComposeSubmission(accountId: account.id, identityId: theirs.id, to: const [RemoteAddress('sarah@x.com')], subject: 'Hello', bodyHtml: '<p>Hi</p>'), token: 't'),
        throwsA(isA<MailTransportException>()),
      );
      expect(ph.sender.server!.host, 'smtp.forwardemail.example');
      expect(ph.sender.credentials!.username, 'ca@clayaiken.example');
      expect(ph.sender.credentials!.password, 'send-password-123');
      expect(ph.sender.credentials!.pass, isFalse);
      expect(ca.email, 'ca@clayaiken.example');
    });

    test('two devices never send an address back and forth', () async {
      final (pc, _) = await pcWithAddresses();
      await pc.inStep();
      final ph = await phone();
      await ph.inStep();
      final rev = helper.sendingRev;
      final puts = helper.sendingPuts;
      for (var i = 0; i < 3; i++) {
        await pc.inStep();
        await ph.inStep();
      }
      expect(helper.sendingRev, rev);
      expect(helper.sendingPuts, puts, reason: 'nothing changed, so nothing was sent');
    });

    test('a signature changed on the phone reaches the PC; a new address added on the PC reaches the phone', () async {
      final (pc, ca) = await pcWithAddresses();
      await pc.inStep();
      final ph = await phone();
      await ph.inStep();
      final onPhone = (await ph.db.select(ph.db.identities).get()).firstWhere((i) => i.email == 'ca@clayaiken.example');
      await ph.db.setIdentitySignature(onPhone.id, json: null, plainText: 'Sent from my phone');
      await ph.inStep();
      await pc.inStep();
      final onPc = (await pc.db.identityById(ca.id))!;
      expect(onPc.signature, 'Sent from my phone');
      expect(onPc.signatureJson, isNull);
      expect(await pc.vault.read(CredentialStore.identityPasswordKey(ca.id)), 'send-password-123', reason: 'the PC keeps its password');

      final account = (await pc.account())!;
      await pc.db.addIdentity(account.id, 'booking@clayaiken.example', name: 'Booking');
      await pc.inStep();
      await ph.inStep();
      expect((await ph.db.select(ph.db.identities).get()).map((i) => i.email), contains('booking@clayaiken.example'));
    });

    test('a password is never removed because another device has none', () async {
      final (pc, ca) = await pcWithAddresses();
      await pc.inStep();
      // The helper somehow holds the address without its password (a phone whose locked store failed).
      helper.sending['ca@clayaiken.example'] = {...helper.sending['ca@clayaiken.example']!}..remove('password');
      helper.sendingRev++;
      await pc.inStep();
      expect(await pc.vault.read(CredentialStore.identityPasswordKey(ca.id)), 'send-password-123');
    });

    test('with no helper, nothing about an address leaves the device', () async {
      final pc = device('alone');
      final account = await insertTestAccount(pc.db);
      await pc.db.into(pc.db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com'));
      await pc.sending.run();
      expect(helper.calls, 0);
    });
  });

  group('what was set on one device waits for the mail on the other', () {
    Future<void> says(_Device d, String kind, String k, Map<String, Object?> data, {bool deleted = false}) => d.db.applyingFromHelper(() => d.db.applyHelperItem(kind, k, data, deleted: deleted));
    Future<Message> message(_Device d, String id) async => (await (d.db.select(d.db.messages)..where((m) => m.messageId.equals(id))).get()).first;
    void arrives(_Device d, String address, String name, String subject, String id) =>
        d.imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: RemoteAddress(address, name), to: const [me], subject: subject, messageId: id, date: ago(hours: 1)));

    test('done, later, and not-Focus pressed elsewhere apply to an email that lands afterwards', () async {
      final ph = await phone();
      final until = DateTime.now().add(const Duration(hours: 5));
      await says(ph, 'done', '<done@x>', {'at': 1794000000});
      await says(ph, 'msgfix', '<later@x>', {'later': until.millisecondsSinceEpoch ~/ 1000});
      await says(ph, 'msgfix', '<nofocus@x>', {'focus': false});
      await says(ph, 'msgfix', '<noise@x>', {'pile': 'noise'});
      arrives(ph, 'renee@booking.example', 'Renee', 'One', '<done@x>');
      arrives(ph, 'renee@booking.example', 'Renee', 'Two', '<later@x>');
      arrives(ph, 'renee@booking.example', 'Renee', 'Three', '<nofocus@x>');
      arrives(ph, 'news@pollstar.example', 'Pollstar', 'Four', '<noise@x>');
      arrives(ph, 'renee@booking.example', 'Renee', 'Five', '<plain@x>');
      await ph.fetchMail();
      expect((await message(ph, '<done@x>')).doneAt, isNotNull);
      expect((await message(ph, '<later@x>')).laterUntil!.difference(until).inSeconds.abs(), lessThan(2));
      expect((await message(ph, '<nofocus@x>')).focusFix, 'no');
      expect((await message(ph, '<noise@x>')).pileFix, 'noise');
      final plain = await message(ph, '<plain@x>');
      expect(plain.doneAt, isNull);
      expect(plain.focusFix, isNull);
      // Taken back elsewhere, after the mail is here: it follows.
      await says(ph, 'done', '<done@x>', {}, deleted: true);
      expect((await message(ph, '<done@x>')).doneAt, isNull);
    });

    test('a name you gave a sender on the PC is on the phone once that sender\'s mail lands', () async {
      final ph = await phone();
      await says(ph, 'sender', 'renee@booking.example', {'cls': 'people', 'src': 'override', 'label': 'Renee (venue)', 'subtitle': 'Charlotte', 'counts': true, 'pile': null});
      arrives(ph, 'renee@booking.example', 'Renee Calloway', 'Dates', '<r1@x>');
      await ph.fetchMail();
      final c = await (ph.db.select(ph.db.contacts)..where((c) => c.key.equals('renee@booking.example'))).getSingle();
      expect(c.userLabel, 'Renee (venue)');
      expect(c.userSubtitle, 'Charlotte');
    });

    test('two addresses joined into one person on the PC are one person on the phone, before or after their mail lands', () async {
      final ph = await phone();
      // Before any mail from either address.
      await says(ph, 'addr', 'sarah@home.example', {'key': 'sarah@x.com'});
      arrives(ph, 'sarah@x.com', 'Sarah Chen', 'Lunch?', '<s1@x>');
      arrives(ph, 'sarah@home.example', 'Sarah', 'From home', '<s2@x>');
      await ph.fetchMail();
      expect((await message(ph, '<s2@x>')).fromContactKey, 'sarah@x.com');
      expect(await (ph.db.select(ph.db.contacts)..where((c) => c.key.equals('sarah@home.example'))).getSingleOrNull(), isNull);
      expect(await ph.db.addressesOf('sarah@x.com'), ['sarah@x.com', 'sarah@home.example']);

      // After: two separate people here, then joined on the PC.
      arrives(ph, 'dan@work.example', 'Dan Ortiz', 'Budget', '<d1@x>');
      arrives(ph, 'dan@home.example', 'Dan', 'Weekend', '<d2@x>');
      await ph.fetchMail();
      expect((await message(ph, '<d2@x>')).fromContactKey, 'dan@home.example');
      await says(ph, 'addr', 'dan@home.example', {'key': 'dan@work.example'});
      await ph.db.refreshDirtyRows();
      expect(await ph.db.addressesOf('dan@work.example'), ['dan@work.example', 'dan@home.example']);
      expect(await (ph.db.select(ph.db.contacts)..where((c) => c.key.equals('dan@home.example'))).getSingleOrNull(), isNull);
      // Taken apart again on the PC.
      await says(ph, 'addr', 'dan@home.example', {}, deleted: true);
      expect(await ph.db.addressesOf('dan@work.example'), ['dan@work.example']);
      expect(await (ph.db.select(ph.db.contacts)..where((c) => c.key.equals('dan@home.example'))).getSingleOrNull(), isNotNull);
      // None of this is sent back up as if the phone had done it.
      expect(await ph.db.customSelect("SELECT COUNT(*) AS n FROM helper_outbox WHERE kind = 'addr'").map((r) => r.read<int>('n')).getSingle(), 0);
    });

    test('quiet hours set on one device hold on the other', () async {
      final pc = await firstPc();
      final ph = await phone();
      const quiet = {'on': true, 'from': '21:30', 'to': '06:45'};
      await pc.db.putSetting(kQuietHours, jsonEncode(quiet));
      await pc.db.noteForHelper('pref', 'quiet', quiet);
      await pc.inStep();
      expect(helper.item('pref', 'quiet'), quiet);
      await ph.inStep();
      expect(jsonDecode((await ph.db.getSetting(kQuietHours))!), quiet);
    });
  });

  group('a lost device', () {
    test('signed out from another device, a joined device removes its copy: mail, people, files, passwords', () async {
      final pc = await firstPc();
      final account = (await pc.account())!;
      final id = await pc.db.addIdentity(account.id, 'ca@clayaiken.example');
      await pc.db.setIdentityServer(id, const ServerConfig(host: 'smtp.forwardemail.example', port: 465, security: ConnectionSecurity.ssl));
      await pc.vault.write(CredentialStore.identityPasswordKey(id), 'send-password-123');
      await pc.inStep();

      final ph = await phone();
      await ph.inStep();
      ph.imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah Chen'), to: const [me], subject: 'Lunch?', messageId: '<s1@x>', date: ago(hours: 1)));
      await ph.fetchMail();
      File(p.join(ph.files.path, 'attachments', 'a.pdf'))
        ..createSync(recursive: true)
        ..writeAsStringSync('a file');
      final theirs = (await ph.db.select(ph.db.identities).get()).firstWhere((i) => i.email == 'ca@clayaiken.example');
      expect(await ph.vault.read(CredentialStore.identityPasswordKey(theirs.id)), isNotNull);
      expect(await ph.db.select(ph.db.messages).get(), isNotEmpty);

      // The PC signs the phone out.
      final phoneId = helper.tokens.keys.last;
      await pc.link.signOutDevice(phoneId);
      await ph.link.syncNow();
      await ph.link.idle();

      expect(ph.state.connected, isFalse);
      expect(ph.state.error, contains('Its copy of your mail was removed'));
      expect(await ph.db.select(ph.db.messages).get(), isEmpty);
      expect(await ph.db.select(ph.db.accounts).get(), isEmpty);
      expect(await ph.db.select(ph.db.identities).get(), isEmpty);
      expect(await ph.db.select(ph.db.contacts).get(), isEmpty);
      expect(await ph.db.select(ph.db.helperSenders).get(), isEmpty);
      expect(await ph.db.getSetting(DeviceJoin.joinedKey), isNull);
      expect(await ph.vault.read(HelperSync.tokenKey), isNull);
      expect(await ph.vault.read(CredentialStore.identityPasswordKey(theirs.id)), isNull);
      expect(Directory(p.join(ph.files.path, 'attachments')).existsSync(), isFalse);
      expect(Directory(p.join(ph.files.path, 'signature-images')).existsSync(), isFalse);
      expect(await ph.joiner.joined, isFalse);
      // It can no longer get a pass.
      await expectLater(ph.container.read(helperPassProvider).access(), throwsA(isA<HelperException>()));
      // A clean app: it can join again with a new code.
      helper.code = 'AGAIN';
      await ph.joiner.join('localhost', 'again', name: 'My phone');
      await ph.link.idle();
      expect((await ph.account())!.authMethod, kHelperAuth);

      // The PC that set Précis up is untouched by any of it.
      expect(await pc.vault.read(CredentialStore.identityPasswordKey(id)), 'send-password-123');
      expect((await pc.account())!.email, 'me@example.com');
    });

    test('the first PC, signed out, keeps everything and carries on by itself', () async {
      final pc = await firstPc();
      pc.imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah Chen'), to: const [me], subject: 'Lunch?', messageId: '<s1@x>', date: ago(hours: 1)));
      await pc.fetchMail();
      helper.signOut(1);
      await pc.link.syncNow();
      await pc.link.idle();
      expect(pc.state.connected, isFalse);
      expect(pc.state.error, contains('carries on by itself'));
      expect(await pc.db.select(pc.db.messages).get(), isNotEmpty);
      expect((await pc.account())!.email, 'me@example.com');
      expect(await pc.vault.read(CredentialStore.passwordKey((await pc.account())!.id)), 'the-gmail-app-password');
    });
  });

  group('with no signal', () {
    ComposeSubmission mail(int accountId, String subject, {int? draftId}) =>
        ComposeSubmission(accountId: accountId, identityId: null, to: const [RemoteAddress('sarah@x.com', 'Sarah Chen')], subject: subject, bodyHtml: '<p>Hi</p>', draftId: draftId);

    test('a message written with no signal waits, and goes by itself when the signal returns', () async {
      final pc = await firstPc();
      final account = (await pc.account())!;
      final waiting = pc.container.read(waitingSendsProvider);
      final draft = await pc.db.saveDraft(DraftsCompanion.insert(accountId: account.id, subject: const Value('Lunch Friday?')));
      pc.sender.mode = 'offline';
      // The compose box tries, hears there is no signal, and hands the message over to wait.
      final message = mail(account.id, 'Lunch Friday?', draftId: draft);
      await expectLater(pc.container.read(sendServiceProvider).send(message, token: 't'), throwsA(isA<MailTransportException>().having((e) => e.offline, 'offline', isTrue)));
      await waiting.keep(message);
      expect(WaitingSends.decode(await pc.db.getSetting(WaitingSends.key)), hasLength(1));
      expect(await pc.db.draftById(draft), isNull, reason: 'the waiting copy is the message now: it cannot go twice');
      // Still no signal: it keeps waiting, however often Précis tries.
      await waiting.sendNow();
      await waiting.sendNow();
      expect(WaitingSends.decode(await pc.db.getSetting(WaitingSends.key)), hasLength(1));
      expect(pc.sender.sentSubjects, isEmpty);
      expect(pc.sounds, 0);
      // The signal is back.
      pc.sender.mode = 'ok';
      await waiting.sendNow();
      expect(pc.sender.sentSubjects, ['Lunch Friday?']);
      expect(WaitingSends.decode(await pc.db.getSetting(WaitingSends.key)), isEmpty);
      expect(pc.container.read(lastSentProvider)?.to, 'Sarah Chen', reason: 'the app says "Sent to Sarah Chen"');
      expect(pc.container.read(appNoticesProvider), isEmpty, reason: 'a message that went is not a Windows alert');
      expect(pc.sounds, 1, reason: 'the sent sound plays once it has gone, not before');
      // And it is never sent a second time.
      await waiting.sendNow();
      expect(pc.sender.sentSubjects, ['Lunch Friday?']);
    });

    test('a waiting message the server then refuses is told to you and goes back to your drafts, never tried again', () async {
      final pc = await firstPc();
      final account = (await pc.account())!;
      final waiting = pc.container.read(waitingSendsProvider);
      pc.sender.mode = 'offline';
      await waiting.keep(mail(account.id, 'The contract'));
      await waiting.keep(mail(account.id, 'Second one'));
      pc.sender.mode = 'stop';
      await waiting.sendNow();
      expect(WaitingSends.decode(await pc.db.getSetting(WaitingSends.key)), isEmpty);
      final notices = pc.container.read(appNoticesProvider);
      expect(notices.map((n) => n.title), ['Not sent', 'Not sent']);
      expect(notices.first.body, contains('The contract'));
      expect(notices.first.body, contains('back in your drafts'));
      final drafts = await pc.db.select(pc.db.drafts).get();
      expect(drafts.map((d) => d.subject), unorderedEquals(['The contract', 'Second one']));
      expect(AddressJson.decode(drafts.first.recipientsTo).single.address, 'sarah@x.com');
    });

    test('a message that was being sent when the app was closed is never sent twice: it goes back to drafts and you are told to look in Sent', () async {
      final pc = await firstPc();
      final account = (await pc.account())!;
      final waiting = pc.container.read(waitingSendsProvider);
      await waiting.keep(mail(account.id, 'The contract'), to: 'Sarah Chen');
      // As it stood when the app was closed mid-send.
      final list = WaitingSends.decode(await pc.db.getSetting(WaitingSends.key));
      await pc.db.putSetting(WaitingSends.key, jsonEncode([{...list.single, 'trying': 1}]));
      pc.sender.mode = 'ok';
      waiting.start(every: const Duration(hours: 1));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await waiting.sendNow();
      waiting.stop();
      expect(pc.sender.sentSubjects, isEmpty, reason: 'it may already have gone: it is not sent again');
      expect((await pc.db.select(pc.db.drafts).get()).map((d) => d.subject), ['The contract']);
      final notice = pc.container.read(appNoticesProvider).single;
      expect(notice.title, 'Check your Sent mail');
      expect(notice.body, contains('Sarah Chen'));
    });

    test('pressing Send hands the message over and sending carries on behind: the copy in Sent is filed afterwards', () async {
      final pc = await firstPc();
      final account = (await pc.account())!;
      pc.sender.mode = 'ok';
      final waiting = pc.container.read(waitingSendsProvider);
      await waiting.submit(mail(account.id, 'Quick one'), to: 'Sarah Chen');
      // Handed over: it is written down before anything is sent.
      await waiting.sendNow();
      await pc.container.read(sendServiceProvider).settled();
      expect(pc.sender.sentSubjects, ['Quick one']);
      expect(WaitingSends.decode(await pc.db.getSetting(WaitingSends.key)), isEmpty);
      expect(pc.container.read(lastSentProvider)?.to, 'Sarah Chen');
      expect(pc.sounds, 1);
    });

    test('on a joined device, a helper out of reach counts as no signal too', () async {
      final ph = await phone();
      final account = (await ph.account())!;
      helper.unreachable = true;
      ph.container.read(helperPassProvider).forget();
      await expectLater(
        ph.container.read(sendServiceProvider).send(mail(account.id, 'From the train'), token: 't'),
        throwsA(isA<MailTransportException>().having((e) => e.offline, 'offline', isTrue)),
      );
      helper.unreachable = false;
    });
  });

  group('one alert, not three', () {
    test('a device tells the helper when Précis is open in front of the user, and not otherwise', () async {
      var front = false;
      final pc = device('pc');
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) => pc.db),
        credentialStoreProvider.overrideWith((ref) => pc.vault),
        helperHttpProvider.overrideWith((ref) => helper.call),
        appInFrontProvider.overrideWith((ref) => () => front),
      ]);
      addTearDown(container.dispose);
      final link = container.read(helperProvider.notifier);
      await link.connect('localhost', 'good-code', name: 'Clay PC', fresh: true);
      await link.idle();
      expect(helper.inFront, isEmpty);
      front = true;
      await link.syncNow();
      await link.idle();
      expect(helper.inFront, {1});
    });
  });
}
