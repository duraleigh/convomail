import 'package:convomail/app/destinations.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';

/// End-to-end through the UI: add an account against a fake IMAP server,
/// see it listed, remove it. No real network, no real credential store.
void main() {
  late FakeMailTransport server;
  late InMemoryCredentialStore creds;
  late AppDatabase db;

  Widget app() => ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
          databaseProvider.overrideWith((ref) => db),
          credentialStoreProvider.overrideWith((ref) => creds),
          transportFactoryProvider.overrideWith((ref) => () => server),
        ],
        child: const ConvoMailApp(startSync: false),
      );

  setUp(() {
    server = FakeMailTransport(password: 'app-password-123');
    server.folder('INBOX', role: FolderRole.inbox);
    creds = InMemoryCredentialStore();
    db = AppDatabase.memory();
  });

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
    await db.close();
  }

  testWidgets('Add account from the empty inbox: detect Gmail, test, save, list, remove', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Empty inbox deep-links to Settings → Accounts with the panel open.
    await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
    await tester.pumpAndSettle();
    expect(find.text('Email address'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email address'), 'someone@gmail.com');
    await tester.pumpAndSettle();
    // Gmail profile recognized: app-password help and label.
    expect(find.textContaining('app password', findRichText: true), findsWidgets);
    expect(find.text('App password'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name (shown on sent mail)'), 'Some One');
    await tester.enterText(find.widgetWithText(TextFormField, 'App password'), 'app-password-123');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();

    // Saved: listed, password in the credential store, identity created.
    expect(find.text('someone@gmail.com'), findsWidgets);
    final accounts = await db.allAccounts();
    expect(accounts.single.imapHost, 'imap.gmail.com');
    expect(accounts.single.providerId, 'gmail');
    expect(accounts.single.displayName, 'Some One');
    expect(creds.contains(CredentialStore.passwordKey(accounts.single.id)), isTrue);
    expect(await creds.read(CredentialStore.passwordKey(accounts.single.id)), 'app-password-123');
    expect((await db.select(db.identities).get()).single.email, 'someone@gmail.com');

    // Remove with confirmation.
    await tester.tap(find.byTooltip('Remove account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(await db.allAccounts(), isEmpty);
    expect(creds.contains(CredentialStore.passwordKey(accounts.single.id)), isFalse);

    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(destinationProvider), Destination.settings);
    await teardown(tester);
  });

  testWidgets('A wrong password shows the server error and saves nothing', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email address'), 'x@corp.example');
    await tester.pumpAndSettle();
    expect(find.text('Password'), findsOneWidget, reason: 'unknown provider: plain password label');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(find.textContaining('rejected the username or password'), findsOneWidget);
    expect(await db.allAccounts(), isEmpty);
    // Auth failure stops after the first host; guesses are not retried.
    expect(server.connectCount, 1);
    await teardown(tester);
  });
}
