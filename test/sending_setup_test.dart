import 'package:convomail/mail/mail_sender.dart';
import 'package:convomail/mail/mail_transport.dart';
import 'package:convomail/mail/sending_route.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/compose_queries.dart';
import 'package:convomail/store/database.dart';
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
