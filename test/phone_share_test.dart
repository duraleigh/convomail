import 'dart:io';

import 'package:convomail/app/compose_state.dart';
import 'package:convomail/app/destinations.dart';
import 'package:convomail/mail/mail_sender.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/android_bridge.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/platform/phone_share.dart';
import 'package:convomail/store/compose_queries.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/schedule_service.dart';
import 'package:convomail/ui/screens/chats/compose/compose_pane.dart';
import 'package:convomail/ui/screens/chats/compose/recipient_field.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Précis in the phone's Share menu: what another app hands over opens a
/// new email with it. (The phone side that takes the share in is Kotlin;
/// these check everything from the moment it reaches the app.)
void main() {
  late AppDatabase db;
  late Account account;

  setUp(() async {
    db = testDatabase();
    account = await insertTestAccount(db);
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), isDefault: const Value(true)));
  });

  test('what the phone side hands over is read; nothing in it is nothing', () {
    final s = SharedIn.parse('{"text":"https://example.com/a","subject":"A page","files":["/x/photo.jpg",""],"skipped":1,"big":2}')!;
    expect(s.text, 'https://example.com/a');
    expect(s.subject, 'A page');
    expect(s.files, ['/x/photo.jpg']);
    expect(s.skipped, 1);
    expect(s.big, 2);
    expect(SharedIn.parse(null), isNull);
    expect(SharedIn.parse(''), isNull);
    expect(SharedIn.parse('not json'), isNull);
    expect(SharedIn.parse('{"text":"  ","subject":"","files":[]}'), isNull);
    expect(SharedIn.parse('{"files":[],"big":1}'), isNotNull, reason: 'a file left out for size is still told to the user');
  });

  test('words alone open a new email on Chats; files that could not come are told', () async {
    final container = ProviderContainer(overrides: [databaseProvider.overrideWith((ref) => db)]);
    addTearDown(container.dispose);
    container.read(destinationProvider.notifier).select(Destination.feed);

    await container.read(phoneShareProvider).receive(const SharedIn(text: ' Call the caterer \n', skipped: 2));
    final request = container.read(composeProvider)!;
    expect(request.isNew && request.isPrefilled, isTrue);
    expect(request.body, 'Call the caterer');
    expect(request.to, isEmpty, reason: 'who it goes to is the user\'s to pick');
    expect(container.read(destinationProvider), Destination.chats);
    expect(container.read(appNoticesProvider).single.title, 'Not everything was added');
    expect(container.read(appNoticesProvider).single.body, '2 files could not be read.');
    await db.close();
  });

  test('only a file too big to email: no empty email opens, and the user is told', () async {
    final container = ProviderContainer(overrides: [databaseProvider.overrideWith((ref) => db)]);
    addTearDown(container.dispose);
    await container.read(phoneShareProvider).receive(const SharedIn(big: 1));
    expect(container.read(composeProvider), isNull);
    expect(container.read(appNoticesProvider).single.title, 'Nothing to share');
    expect(container.read(appNoticesProvider).single.body, 'One file was too big to email.');
    await db.close();
  });

  test('a phone that has not joined yet: nothing opens', () async {
    await (db.delete(db.identities)).go();
    await (db.delete(db.accounts)).go();
    final container = ProviderContainer(overrides: [databaseProvider.overrideWith((ref) => db)]);
    addTearDown(container.dispose);
    await container.read(phoneShareProvider).receive(const SharedIn(text: 'hello'));
    expect(container.read(composeProvider), isNull);
    expect(container.read(appNoticesProvider), isEmpty);
    await db.close();
  });

  testWidgets('a shared link and picture open a new email holding them; it is not put aside for an older draft, and it is not started over when it is saved', (tester) async {
    final imap = FakeMailTransport();
    imap.folder('INBOX', role: FolderRole.inbox);
    final store = InMemoryCredentialStore();
    tester.view.physicalSize = const Size(1500, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
        databaseProvider.overrideWith((ref) => db),
        credentialStoreProvider.overrideWith((ref) => store),
        transportFactoryProvider.overrideWith((ref) => () => imap),
        mailSenderProvider.overrideWith((ref) => RecordingMailSender()),
        htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
      ],
      child: const PrecisApp(startSync: false),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    TextField subject() => tester.widget(find.byKey(const ValueKey('compose-subject'))) as TextField;

    // An unsent new email from earlier.
    container.read(composeProvider.notifier).open();
    await settle();
    await tester.enterText(find.byKey(const ValueKey('compose-subject')), 'Old one');
    await tester.pump(const Duration(seconds: 2));
    await settle();
    container.read(composeProvider.notifier).close();
    await settle();
    expect((await db.latestNewDraft())!.subject, 'Old one');

    final dir = Directory.systemTemp.createTempSync('precis-share-test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = File('${dir.path}${Platform.pathSeparator}photo.jpg')..writeAsBytesSync(List.filled(2048, 7));

    await container.read(phoneShareProvider).receive(SharedIn(
          text: 'https://example.com/a\n\nSecond part\nits next line',
          subject: 'A page',
          files: [photo.path, '${dir.path}${Platform.pathSeparator}gone.pdf'],
        ));
    await settle();

    expect(find.byType(ComposePane), findsOneWidget);
    expect(find.text('New message'), findsOneWidget, reason: 'its own email, not the older draft');
    expect(subject().controller!.text, 'A page');
    expect(find.textContaining('photo.jpg'), findsOneWidget);
    expect(find.textContaining('gone.pdf'), findsNothing, reason: 'a file that is no longer there is left out');
    expect(find.text('https://example.com/a', findRichText: true), findsOneWidget);
    expect(find.textContaining('Second part', findRichText: true), findsOneWidget);

    // The user picks who it goes to. Its draft is saved while they write,
    // and that must not start the form over.
    final toField = find.descendant(of: find.byType(RecipientField).first, matching: find.byType(TextField));
    await tester.enterText(toField, 'new.person@y.org,');
    await settle();
    expect(find.byKey(const ValueKey('chip-To-new.person@y.org')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await settle();
    final saved = (await db.latestNewDraft())!;
    expect(saved.subject, 'A page');
    expect(saved.recipientsTo, contains('new.person@y.org'));
    expect(saved.attachmentsJson, contains('photo.jpg'));
    expect(saved.bodyHtml, contains('https://example.com/a'));
    await tester.pump(const Duration(seconds: 2));
    await settle();
    expect(find.byKey(const ValueKey('chip-To-new.person@y.org')), findsOneWidget, reason: 'still the same form after its draft was saved');
    expect(subject().controller!.text, 'A page');
    expect(find.textContaining('photo.jpg'), findsOneWidget);
    expect(await db.watchDraftCount().first, 2, reason: 'the older draft is still there, and this one was saved once');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });
}
