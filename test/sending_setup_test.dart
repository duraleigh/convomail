import 'package:convomail/mail/mail_sender.dart';
import 'package:convomail/mail/mail_transport.dart';
import 'package:convomail/mail/sending_route.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/compose_queries.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/ui/screens/settings/add_address_dialog.dart';
import 'package:convomail/ui/screens/settings/sending_setup_dialog.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_db.dart';

/// Setting up an address to send through its own server: the password is
/// checked against the server before anything is saved.
void main() {
  late AppDatabase db;
  late RecordingMailSender smtp;
  late InMemoryCredentialStore store;
  late Account account;
  late Identity alias;

  setUp(() async {
    db = testDatabase();
    smtp = RecordingMailSender();
    store = InMemoryCredentialStore();
    account = await insertTestAccount(db);
    final id = await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'ca@clayaiken.com', discovered: const Value(true)));
    alias = (await db.identityById(id))!;
  });

  tearDown(() => db.close());

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWith((ref) => db), credentialStoreProvider.overrideWith((ref) => store), mailSenderProvider.overrideWith((ref) => smtp)],
        child: MaterialApp(
          home: Scaffold(body: SendingSetupDialog(identity: alias)),
        ),
      ),
    );
  }

  test('an alias on another domain needs setting up; the account address does not', () async {
    expect(needsSendingSetup(alias, account), isTrue);
    final own = (await db.identitiesForAccount(account.id)).where((i) => i.email == account.email);
    for (final i in own) {
      expect(needsSendingSetup(i, account), isFalse);
    }
    expect(suggestedServerFor('ca@clayaiken.com').host, 'smtp.forwardemail.net');
    expect(suggestedServerFor('caiken@mac.com').host, 'smtp.mail.me.com');
  });

  testWidgets('a password the server accepts is saved and the address can send', (tester) async {
    await pumpDialog(tester);
    await tester.enterText(find.byKey(const ValueKey('sending-password')), 'alias-secret');
    await tester.tap(find.byKey(const ValueKey('sending-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(smtp.verified.single.$1.host, 'smtp.forwardemail.net');
    expect(smtp.verified.single.$2.username, 'ca@clayaiken.com');
    expect(await store.read(CredentialStore.identityPasswordKey(alias.id)), 'alias-secret');
    final saved = (await tester.runAsync(() => db.identityById(alias.id)))!;
    expect(saved.smtpHost, 'smtp.forwardemail.net');
    expect(needsSendingSetup(saved, account), isFalse);
  });

  testWidgets('one domain password covers the other addresses on that domain', (tester) async {
    final cheryl = await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'cheryl@clayaiken.com', discovered: const Value(true)));
    final other = await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'clay@duraleigh.com', discovered: const Value(true)));
    await pumpDialog(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('Also use it for cheryl@clayaiken.com'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('sending-password')), 'domain-secret');
    await tester.tap(find.byKey(const ValueKey('sending-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(await store.read(CredentialStore.identityPasswordKey(cheryl)), 'domain-secret');
    final saved = (await tester.runAsync(() => db.identityById(cheryl)))!;
    expect(saved.smtpHost, 'smtp.forwardemail.net');
    expect(saved.smtpUsername, isNull, reason: 'each address signs in as itself');
    expect(await store.read(CredentialStore.identityPasswordKey(other)), isNull);
    expect((await tester.runAsync(() => db.identityById(other)))!.smtpHost, isNull);
  });

  testWidgets('an iCloud address is pointed to Apple for its password', (tester) async {
    final mac = await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'caiken@mac.com', discovered: const Value(true)));
    alias = (await db.identityById(mac))!;
    await pumpDialog(tester);
    expect(find.byKey(const ValueKey('sending-provider-help')), findsOneWidget);
    expect(find.text('Open appleid.apple.com'), findsOneWidget);
    expect(find.text('Server: smtp.mail.me.com'), findsOneWidget);
  });

  test('a removed address is gone from the list, stays gone after sync, and hands on the default', () async {
    final remarkable = await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'my@remarkable.com', discovered: const Value(true)));
    await db.setDefaultIdentity(account.id, remarkable);

    await db.removeIdentity(remarkable);

    final left = await db.identitiesForAccount(account.id);
    expect(left.map((i) => i.email), isNot(contains('my@remarkable.com')));
    expect(left.where((i) => i.isDefault), hasLength(1));
    expect((await db.watchAllIdentities().first).map((i) => i.email), isNot(contains('my@remarkable.com')));

    // Sync finds it again in Sent; it is not added back.
    final sent = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: account.id, path: 'Sent', name: 'Sent', role: const Value('sent')));
    await db.into(db.messages).insert(MessagesCompanion.insert(accountId: account.id, folderId: sent, uid: 1, fromAddress: const Value('my@remarkable.com')));
    await db.discoverIdentitiesFromSent(account.id, sent);
    expect((await db.identitiesForAccount(account.id)).map((i) => i.email), isNot(contains('my@remarkable.com')));
  });

  test('a new address on a set-up domain gets its password, once the server takes it', () async {
    // ca@ already sends with the domain-wide password.
    await store.write(CredentialStore.identityPasswordKey(alias.id), 'domain-secret');
    await db.setIdentityServer(alias.id, suggestedServerFor(alias.email));

    final contact = (await db.identityById(await db.addIdentity(account.id, 'Contact@ClayAiken.com', name: 'Contact')))!;
    expect(contact.email, 'contact@clayaiken.com');
    expect(await reuseDomainSending(db: db, store: store, sender: smtp, identity: contact), isTrue);
    expect(smtp.verified.single.$2.username, 'contact@clayaiken.com');
    expect(await store.read(CredentialStore.identityPasswordKey(contact.id)), 'domain-secret');
    expect(needsSendingSetup((await db.identityById(contact.id))!, account), isFalse);

    // A domain with nothing set up, or a refused password, leaves it to set up.
    final other = (await db.identityById(await db.addIdentity(account.id, 'cheryl@duraleigh.com')))!;
    expect(await reuseDomainSending(db: db, store: store, sender: smtp, identity: other), isFalse);
    smtp.failWith = const MailTransportException('no', isAuthFailure: true);
    final refused = (await db.identityById(await db.addIdentity(account.id, 'new@clayaiken.com')))!;
    expect(await reuseDomainSending(db: db, store: store, sender: smtp, identity: refused), isFalse);
    expect(await store.read(CredentialStore.identityPasswordKey(refused.id)), isNull);
  });

  test('adding a removed address brings it back', () async {
    await db.removeIdentity(alias.id);
    expect(await db.addIdentity(account.id, 'ca@clayaiken.com'), alias.id);
    expect((await db.identitiesForAccount(account.id)).map((i) => i.email), contains('ca@clayaiken.com'));
  });

  testWidgets('a password the server refuses is not saved and says so', (tester) async {
    smtp.failWith = const MailTransportException('The mail server rejected the username or password.', isAuthFailure: true);
    await pumpDialog(tester);
    await tester.enterText(find.byKey(const ValueKey('sending-password')), 'wrong');
    await tester.tap(find.byKey(const ValueKey('sending-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('That password was not accepted. Check it and try again.'), findsOneWidget);
    expect(await store.read(CredentialStore.identityPasswordKey(alias.id)), isNull);
    final saved = (await tester.runAsync(() => db.identityById(alias.id)))!;
    expect(saved.smtpHost, isNull);
  });
}
