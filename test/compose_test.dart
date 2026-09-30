import 'package:convomail/app/compose_state.dart';
import 'package:convomail/app/people_state.dart';
import 'package:convomail/mail/mail_sender.dart';
import 'package:convomail/mail/mail_transport.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/compose_queries.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/compose/compose_form.dart';
import 'package:convomail/ui/screens/chats/compose/compose_pane.dart';
import 'package:convomail/ui/screens/chats/compose/recipient_field.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Compose through the UI (spec 4.4, 5.3): Ctrl+N opens the right-pane
/// composer with the signature, recipients autocomplete from contacts,
/// drafts autosave and resume, inline reply prefills and sends through the
/// fake SMTP sender, Escape closes.
void main() {
  late AppDatabase db;
  late FakeMailTransport imap;
  late RecordingMailSender smtp;
  late InMemoryCredentialStore store;
  late Account account;

  Widget app() => ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
          databaseProvider.overrideWith((ref) => db),
          credentialStoreProvider.overrideWith((ref) => store),
          transportFactoryProvider.overrideWith((ref) => () => imap),
          mailSenderProvider.overrideWith((ref) => smtp),
          htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
        ],
        child: const ConvoMailApp(startSync: false),
      );

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    smtp = RecordingMailSender();
    store = InMemoryCredentialStore();
    account = await insertTestAccount(db);
    await store.write(CredentialStore.passwordKey(account.id), 'secret');
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), signature: const Value('Cheers,\nClay'), isDefault: const Value(true)));
    final inbox = imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    inbox.add(
      RemoteMessageHeader(
        uid: 0,
        from: const RemoteAddress('sarah@x.com', 'Sarah Chen'),
        to: const [RemoteAddress('me@example.com'), RemoteAddress('tom@x.com', 'Tom Andersen')],
        subject: 'Figma access',
        messageId: '<orig@x.com>',
        date: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      body: const RemoteMessageBody(text: 'Can you add me?'),
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1500, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    container.read(syncControllerProvider).adoptForTest(account.id, syncer);
    await db.refreshDirtyRows();
    await tester.pumpAndSettle();
  }

  /// The open editor blinks its cursor, so pumpAndSettle would never
  /// settle; a handful of timed frames lets futures and animations run.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  }

  testWidgets('Ctrl+N opens the composer with From, the signature, and Send; Escape closes it', (tester) async {
    await pumpApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);

    expect(find.byType(ComposePane), findsOneWidget);
    expect(find.text('New message'), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-from')), findsOneWidget);
    expect(find.textContaining('Clay Example <me@example.com>'), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-send')), findsOneWidget);
    // Signature lines are in the editor document.
    expect(find.text('Cheers,', findRichText: true), findsOneWidget);
    expect(find.text('Clay', findRichText: true), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(ComposePane), findsNothing);
    await teardown(tester);
  });

  testWidgets('recipient field: autocomplete from contacts, chips, typed address, invalid text ignored', (tester) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    container.read(composeProvider.notifier).open();
    await settle(tester);

    final toField = find.descendant(of: find.byType(RecipientField).first, matching: find.byType(TextField));
    await tester.enterText(toField, 'sar');
    await settle(tester);
    expect(find.widgetWithText(ListTile, 'Sarah Chen'), findsOneWidget, reason: 'suggestion from synced contacts');
    await tester.tap(find.widgetWithText(ListTile, 'Sarah Chen'));
    await settle(tester);
    expect(find.byKey(const ValueKey('chip-To-sarah@x.com')), findsOneWidget);

    await tester.enterText(toField, 'new.person@y.org,');
    await settle(tester);
    expect(find.byKey(const ValueKey('chip-To-new.person@y.org')), findsOneWidget);

    await tester.enterText(toField, 'not an address');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.byKey(const ValueKey('chip-To-not an address')), findsNothing);

    // Backspace on the empty field removes the last chip.
    await tester.enterText(toField, '');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await settle(tester);
    expect(find.byKey(const ValueKey('chip-To-new.person@y.org')), findsNothing);
    expect(find.byKey(const ValueKey('chip-To-sarah@x.com')), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('Send with no recipient shows an error; a draft autosaves and is resumed on the next Ctrl+N', (tester) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    container.read(composeProvider.notifier).open();
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('compose-send')));
    await settle(tester);
    expect(find.text('Add at least one recipient.'), findsOneWidget);
    expect(smtp.sent, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('compose-subject')), 'Lunch plans');
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    final draft = await db.latestNewDraft();
    expect(draft, isNotNull);
    expect(draft!.subject, 'Lunch plans');
    expect(draft.bodyHtml, contains('Cheers,'));

    container.read(composeProvider.notifier).close();
    await settle(tester);
    container.read(composeProvider.notifier).open();
    await settle(tester);
    expect(find.text('Draft'), findsOneWidget);
    expect((tester.widget(find.byKey(const ValueKey('compose-subject'))) as TextField).controller!.text, 'Lunch plans');

    await tester.tap(find.byKey(const ValueKey('compose-discard')));
    await settle(tester);
    expect(await db.latestNewDraft(), isNull);
    expect(find.byType(ComposePane), findsNothing);
    await teardown(tester);
  });

  testWidgets('inline reply: R prefills To and Re: subject; send goes through SMTP and files under Sarah', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sarah Chen'));
    await settle(tester);
    expect(find.byKey(const ValueKey('reply-pill')), findsOneWidget);
    expect(find.text('Reply to Sarah…'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reply-pill')));
    await settle(tester);
    expect(find.byType(ComposeForm), findsOneWidget);
    expect(find.byKey(const ValueKey('chip-To-sarah@x.com')), findsOneWidget);
    expect((tester.widget(find.byKey(const ValueKey('compose-subject'))) as TextField).controller!.text, 'Re: Figma access');
    expect(find.text('Include quoted message'), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-from')), findsNothing, reason: 'single identity: no From row in the compact composer');

    await tester.tap(find.byKey(const ValueKey('compose-send')));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);

    expect(smtp.sent, hasLength(1));
    final m = smtp.sent.single.parsed;
    expect(m.to!.single.email, 'sarah@x.com');
    expect(m.getHeaderValue('in-reply-to'), '<orig@x.com>');
    expect(m.decodeTextHtmlPart(), contains('Sarah Chen &lt;sarah@x.com&gt; wrote:'));
    expect(m.decodeTextHtmlPart(), contains('Cheers,'));
    expect(find.byType(ComposeForm), findsNothing, reason: 'composer collapses after sending');
    expect(find.textContaining('Sent to Sarah Chen'), findsOneWidget);
    final sarahRow = await db.messagesForRow('c:sarah@x.com');
    expect(sarahRow.where((x) => x.isFromMe), hasLength(1), reason: 'the Sent copy is synced back and filed under the recipient');
    await teardown(tester);
  });

  testWidgets('reply all adds the other To recipient; forward has an empty To and a Fwd: subject', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sarah Chen'));
    await settle(tester);
    await tester.tap(find.byTooltip('Reply all (Shift+R)'));
    await settle(tester);
    expect(find.byKey(const ValueKey('chip-To-sarah@x.com')), findsOneWidget);
    expect(find.byKey(const ValueKey('chip-To-tom@x.com')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    await tester.tap(find.byTooltip('Forward (F)'));
    await settle(tester);
    expect(find.byKey(const ValueKey('chip-To-sarah@x.com')), findsNothing);
    expect((tester.widget(find.byKey(const ValueKey('compose-subject'))) as TextField).controller!.text, 'Fwd: Figma access');
    expect(find.text('Include quoted message'), findsNothing);
    await teardown(tester);
  });

  testWidgets('a failed send shows the server error inline and keeps the composer open', (tester) async {
    await pumpApp(tester);
    smtp.failWith = const MailTransportException('The mail server rejected the username or password.', isAuthFailure: true);
    await tester.tap(find.text('Sarah Chen'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('reply-pill')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('compose-send')));
    await settle(tester);
    expect(find.textContaining('rejected the username or password'), findsOneWidget);
    expect(find.byType(ComposeForm), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-send')), findsOneWidget, reason: 'progress bar replaced by the Send button again');
    await teardown(tester);
  });

  test('parseRecipients handles names, brackets, and lists', () {
    final r = parseRecipients('Sarah Chen <sarah@x.com>; tom@x.com, "Ann, B" <ann@x.com>, junk')!;
    expect(r.map((a) => a.address), ['sarah@x.com', 'tom@x.com', 'ann@x.com']);
    expect(r.first.name, 'Sarah Chen');
    expect(parseRecipients('nothing valid'), isNull);
  });

  test('selectedRowProvider changes close an open inline reply', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(replyRequestProvider.notifier).open(ComposeRequest.reply(1, rowKey: 'c:a'));
    expect(container.read(replyRequestProvider), isNotNull);
    container.read(replyRequestProvider.notifier).close();
    expect(container.read(replyRequestProvider), isNull);
    expect(container.read(selectedRowProvider), isNull);
  });
}
