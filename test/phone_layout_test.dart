import 'package:convomail/app/destinations.dart';
import 'package:convomail/app/layout.dart';
import 'package:convomail/app/mail_state.dart';
import 'package:convomail/app/people_state.dart';
import 'package:convomail/helper/helper_sync.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart' hide ClassificationRule;
import 'package:convomail/store/helper_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/compose/compose_editor.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_helper.dart';
import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Step 5 of the Précis plan: the phone's layout. One screen at a time, a
/// bar along the bottom, Back to return, swipes on Focus rows. The same
/// screens as the PC, laid out for a phone.
void main() {
  const me = RemoteAddress('me@example.com');
  const brief = BulkSignals(listUnsubscribe: true, listId: true, listIdValue: 'brief.dailybrief.com');
  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;
  late InMemorySettingsStore settings;
  late FakeHelper helper;

  DateTime ago({int days = 0, int hours = 0}) => DateTime.now().subtract(Duration(days: days, hours: hours));

  void got(String address, String name, String subject, {required String id, BulkSignals signals = BulkSignals.none, DateTime? at}) =>
      imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: RemoteAddress(address, name), to: const [me], subject: subject, messageId: id, date: at ?? ago(hours: 3), signals: signals));

  Future<void> says(String kind, String messageId, Map<String, Object?> data) => db.applyingFromHelper(() => db.applyHelperItem(kind, messageId, data, deleted: false));
  Future<Message> message(String messageId) async => (await (db.select(db.messages)..where((m) => m.messageId.equals(messageId))).get()).first;

  ProviderContainer scope(Destination opensOn, {bool phone = true}) => ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWith((ref) => settings),
          databaseProvider.overrideWith((ref) => db),
          credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
          transportFactoryProvider.overrideWith((ref) => () => imap),
          helperHttpProvider.overrideWith((ref) => helper.call),
          htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
          destinationProvider.overrideWith(() => DestinationNotifier(initial: opensOn)),
          forceCompactProvider.overrideWith((ref) => phone ? true : null),
          isTouchDeviceProvider.overrideWith((ref) => phone),
        ],
      );

  /// Shows the app at a phone's size. With [joined], the device has joined
  /// the stand-in helper first, as a phone does when it is set up.
  Future<ProviderContainer> pump(WidgetTester tester, Destination opensOn, {Size size = const Size(412, 915), bool phone = true, bool joined = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = scope(opensOn, phone: phone);
    addTearDown(c.dispose);
    if (joined) {
      await tester.runAsync(() async {
        await c.read(helperProvider.notifier).connect('localhost', 'good-code', name: 'My phone', fresh: true);
        await c.read(helperProvider.notifier).idle();
      });
    }
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const PrecisApp(startSync: false)));
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// The phone's own Back button.
  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    settings = InMemorySettingsStore();
    helper = FakeHelper();
    account = await insertTestAccount(db);
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), isDefault: const Value(true)));
    imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('renee@booking.example')], subject: 'Spring dates', messageId: '<mine@example.com>', date: ago(days: 3)));
    got('renee@booking.example', 'Renee Calloway', 'Re: Spring dates', id: '<renee@x>', at: ago(hours: 2));
    got('alerts@bank.example', 'First Citizens Bank', 'Your automatic payment did not go through', id: '<bank@x>', at: ago(days: 2));
    got('news@pollstar.example', 'Pollstar Daily', 'Daily #1', id: '<daily-1@x>', signals: brief, at: ago(hours: 4));
    got('deals@flash.example', 'FlashDeals', '70% off, today only', id: '<flash-1@x>', signals: brief, at: ago(hours: 5));
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
    // This device follows a helper whose assistant is on, and it has read the mail.
    await db.setHelperConnected(true);
    await db.putSetting('helper.assistantOn', '1');
    await says('sort', '<daily-1@x>', {'cls': 'feeds', 'cat': 'Newsletter', 'pile': 'feed'});
    await says('sort', '<flash-1@x>', {'cls': 'feeds', 'cat': 'Promotion', 'pile': 'noise'});
    await says('read', '<renee@x>', {'line': 'Renee needs your yes or no on Charlotte.', 'focus': true, 'ask': 'Say yes or no to Charlotte.', 'due': null, 'why': ['It asks you for a yes or no.'], 'answered': false, 'at': 1});
    await says('read', '<bank@x>', {'line': 'A payment failed.', 'focus': true, 'ask': 'Update the card on file.', 'due': null, 'why': ['A payment failed.'], 'answered': false, 'at': 1});
    await db.refreshDirtyRows();
  });

  tearDown(() async => db.close());

  testWidgets('a phone shows one screen at a time, with Précis, Focus, Chats, Feed and More along the bottom', (tester) async {
    await pump(tester, Destination.today);
    final bar = find.byKey(const ValueKey('compact-bar'));
    expect(bar, findsOneWidget);
    for (final label in ['Précis', 'Focus', 'Chats', 'Feed', 'More']) {
      expect(find.descendant(of: bar, matching: find.text(label)), findsOneWidget, reason: label);
    }
    expect(find.descendant(of: bar, matching: find.text('Noise')), findsNothing);
    expect(find.byType(NavigationRail), findsNothing, reason: 'no side rail on a phone');
    // The one number on the bar: how many emails need you.
    expect(find.descendant(of: find.byKey(const ValueKey('focus-badge')), matching: find.text('2')), findsWidgets);
    expect(find.byKey(const ValueKey('compact-compose')), findsOneWidget);
    // Chats shows a plain dot while a chat has unread mail from a person, so it is never out of sight.
    expect(tester.widget<Badge>(find.byKey(const ValueKey('chats-badge')).first).isLabelVisible, isTrue);
    expect(tester.widget<Badge>(find.byKey(const ValueKey('chats-badge')).first).label, isNull, reason: 'a dot, not a number');
    expect(tester.takeException(), isNull, reason: 'Today fits a phone without running off the edge');
    // The top of the page: the date, then the greeting on one line of its own, never wrapped.
    expect(find.byKey(const ValueKey('today-title')), findsNothing, reason: 'the page is named on the bar only');
    final greeting = find.byKey(const ValueKey('today-greeting'));
    final style = tester.widget<Text>(greeting).style!;
    expect(tester.widget<Text>(greeting).maxLines, 1);
    expect(tester.getSize(greeting).height, lessThan(style.fontSize! * 1.6), reason: 'one line');
    expect(style.fontSize, greaterThan(Theme.of(tester.element(greeting)).textTheme.headlineMedium!.fontSize!), reason: 'a little larger than before');
    expect(tester.getTopLeft(greeting).dy, greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('today-date'))).dy - 1), reason: 'under the date');
    await teardown(tester);
  });

  testWidgets('the write button on the Précis page is smaller, steps out of the way while the page is moved, and comes back when it rests', (tester) async {
    // Enough on the page for it to scroll.
    for (var n = 0; n < 8; n++) {
      got('person$n@x.example', 'Person $n', 'Question $n', id: '<q$n@x>');
    }
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    for (var n = 0; n < 8; n++) {
      await says('read', '<q$n@x>', {'line': 'Person $n asks a question.', 'focus': true, 'ask': 'Answer question $n.', 'due': null, 'why': ['It asks.'], 'answered': false, 'at': 1});
    }
    await db.refreshDirtyRows();
    await pump(tester, Destination.today);
    final button = find.byKey(const ValueKey('compact-compose'));
    double scale() => tester.widget<AnimatedScale>(find.byKey(const ValueKey('compact-compose-tuck'))).scale;
    expect(tester.getSize(button), const Size(48, 48), reason: 'smaller than on the other pages');
    expect(scale(), 1);
    // The last card clears the button: the page can be moved up past it.
    final page = find.byKey(const PageStorageKey('today-scroll'));
    expect((tester.widget<SingleChildScrollView>(page).padding! as EdgeInsets).bottom, greaterThanOrEqualTo(80));

    // A finger moves the page: the button goes.
    final finger = await tester.startGesture(tester.getCenter(page));
    await finger.moveBy(const Offset(0, -40));
    await finger.moveBy(const Offset(0, -120));
    await tester.pump();
    expect(scale(), 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<IgnorePointer>(find.ancestor(of: button, matching: find.byType(IgnorePointer)).first).ignoring, isTrue);
    // Let go: it comes back once the page has rested a moment.
    await finger.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(scale(), 1);

    // On the other pages it is as it was.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('compact-bar')), matching: find.text('Chats')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compact-compose-tuck')), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('compact-compose'))).width, greaterThan(48));
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('Focus: the list fills the phone; an email opened fills it instead, and Back returns to the list', (tester) async {
    final renee = await tester.runAsync(() => message('<renee@x>'));
    final c = await pump(tester, Destination.focus);
    expect(find.textContaining('2 emails need you'), findsOneWidget);
    expect(find.text('Pick an email on the left to read it here.'), findsNothing, reason: 'no second pane on a phone');
    await tester.tap(find.byKey(ValueKey('mail-row-${renee!.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('reading-${renee.id}')), findsOneWidget);
    expect(find.textContaining('2 emails need you'), findsNothing, reason: 'the open email has the whole screen');
    expect(find.byKey(const ValueKey('compact-bar')), findsNothing, reason: 'the bar steps aside for what is open');
    expect(find.byKey(const ValueKey('compact-compose')), findsNothing);
    expect(tester.takeException(), isNull);
    // The arrow goes back.
    await tester.tap(find.byKey(const ValueKey('compact-back')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 emails need you'), findsOneWidget);
    expect(c.read(openMailProvider('focus')), isNull);
    // So does the phone's own Back button.
    await tester.tap(find.byKey(ValueKey('mail-row-${renee.id}')));
    await tester.pumpAndSettle();
    await back(tester);
    expect(find.textContaining('2 emails need you'), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-bar')), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('when the open email leaves Focus (you answered it), the list is back with its bar, and Back works as usual', (tester) async {
    final renee = await tester.runAsync(() => message('<renee@x>'));
    final c = await pump(tester, Destination.focus);
    await tester.tap(find.byKey(ValueKey('mail-row-${renee!.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compact-bar')), findsNothing);
    // You answer it (from here or anywhere): the helper says so, and it leaves Focus.
    await tester.runAsync(() => says('read', '<renee@x>', {'line': 'Renee needs your yes or no on Charlotte.', 'focus': true, 'ask': 'Say yes or no to Charlotte.', 'due': null, 'why': <String>[], 'answered': true, 'at': 2}));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 email needs you'), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-bar')), findsOneWidget, reason: 'the list is showing, so the bar is too');
    expect(find.byKey(const ValueKey('compact-compose')), findsOneWidget);
    expect(c.read(openMailProvider('focus')), isNull, reason: 'nothing is open any more');
    expect(c.read(compactDetailProvider), isFalse);
    // Back, with nothing open, steps out of Focus to Today (and only from Today does it leave Précis).
    await back(tester);
    expect(c.read(destinationProvider), Destination.today);
    expect(find.byKey(const ValueKey('compact-bar')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('compact-bar')), matching: find.text('Focus')));
    await tester.pumpAndSettle();
    // The bar works: Chats opens, and coming back to Focus shows the list.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('compact-bar')), matching: find.text('Chats')));
    await tester.pumpAndSettle();
    expect(c.read(destinationProvider), Destination.chats);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('compact-bar')), matching: find.text('Focus')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 email needs you'), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-bar')), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('Focus rows on a phone: swipe right is Done, swipe left asks until when (Later); a long press opens the menu', (tester) async {
    final renee = await tester.runAsync(() => message('<renee@x>'));
    final bank = await tester.runAsync(() => message('<bank@x>'));
    await pump(tester, Destination.focus);
    // Left: Later. The row stays until a time is picked.
    await tester.drag(find.byKey(ValueKey('mail-row-${bank!.id}')), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(find.text('Later today'), findsWidgets, reason: 'swiping left asks until when');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Update the card on file.'), findsOneWidget, reason: 'nothing was picked, so nothing changed');
    expect((await tester.runAsync(() => message('<bank@x>')))!.focusFix, isNull, reason: 'left is not "Not Focus" on a phone');
    // Right: Done.
    await tester.drag(find.byKey(ValueKey('mail-row-${renee!.id}')), const Offset(320, 0));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(() => message('<renee@x>')))!.doneAt, isNotNull);
    expect(find.textContaining('1 email needs you'), findsOneWidget);
    // A long press is the phone's right click.
    await tester.longPress(find.byKey(ValueKey('mail-row-${bank.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsWidgets);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await teardown(tester);
  });

  testWidgets('replying on a phone: the name in To is whole and in line with its label; one arrow opens Cc, Bcc and the subject; the title has the full width', (tester) async {
    final renee = await tester.runAsync(() => message('<renee@x>'));
    await pump(tester, Destination.focus);
    await tester.tap(find.byKey(ValueKey('mail-row-${renee!.id}')));
    await tester.pumpAndSettle();
    // The heading: the title runs the width of the screen, with Done, Later and Reply under it.
    final title = find.text('Spring dates');
    expect(tester.getSize(title).width, greaterThan(250), reason: 'the title is not squeezed by the buttons');
    expect(tester.getTopLeft(find.byKey(const ValueKey('mail-done'))).dy, greaterThan(tester.getBottomLeft(title).dy - 1), reason: 'Done sits under the title');

    await tester.tap(find.byKey(const ValueKey('mail-reply')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The reply has the whole screen: the email's heading and list step aside.
    expect(find.byKey(const ValueKey('mail-done')), findsNothing);
    final send = find.byKey(const ValueKey('compose-send'));
    expect(tester.getBottomLeft(send).dy, lessThanOrEqualTo(915));
    final editorTall = tester.getSize(find.byType(ComposeEditor)).height;
    expect(editorTall, greaterThan(300), reason: 'the writing area takes the room there is');
    // The keyboard comes up: the writing area gives way, and Send and what is being typed stay above it.
    tester.view.viewInsets = const FakeViewPadding(bottom: 420);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'nothing runs off the screen with the keyboard up');
    expect(tester.getBottomLeft(send).dy, lessThanOrEqualTo(915 - 420), reason: 'Send is behind the keyboard');
    final editorBox = tester.getRect(find.byType(ComposeEditor));
    expect(editorBox.bottom, lessThanOrEqualTo(915 - 420), reason: 'the writing area runs behind the keyboard');
    expect(editorBox.height, greaterThan(60), reason: 'there is still room to see what is typed');
    expect(editorBox.height, lessThan(editorTall));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    final chip = find.byKey(const ValueKey('chip-To-renee@booking.example'));
    expect(chip, findsOneWidget);
    final name = tester.renderObject<RenderParagraph>(find.descendant(of: chip, matching: find.text('Renee Calloway')));
    // The name has the row to itself up to the arrow (the checks' own letters are far wider than real ones, so a long name still ends in dots here).
    expect(name.size.width, greaterThan(120), reason: 'the name in To is squeezed');
    // "To" and the name sit on one line.
    final label = find.descendant(of: find.byKey(const ValueKey('thread-reply')), matching: find.text('To'));
    expect((tester.getCenter(label).dy - tester.getCenter(chip).dy).abs(), lessThan(7), reason: '"To" and the name are out of line');
    // The To row is one line: the space for typing another name is folded away until the row is tapped.
    final typing = find.byKey(const ValueKey('recipient-typing-To'));
    expect(tester.getSize(typing).width, 24);
    expect((tester.getCenter(typing).dy - tester.getCenter(chip).dy).abs(), lessThan(3), reason: 'no empty band under the name');
    final toField = find.descendant(of: typing, matching: find.byType(TextField));
    expect(tester.widget<TextField>(toField).focusNode!.hasFocus, isFalse, reason: 'in a reply the cursor is in the message, not in To');
    // One small arrow at the end of the row, in line with it too, and no word links crowding the name.
    final more = find.byKey(const ValueKey('compose-show-more'));
    expect(more, findsOneWidget);
    expect(find.text('Cc/Bcc'), findsNothing);
    expect((tester.getCenter(more).dy - tester.getCenter(chip).dy).abs(), lessThan(9));
    expect(tester.getTopRight(chip).dx, lessThanOrEqualTo(tester.getTopLeft(more).dx + 0.5));
    // It opens Cc, Bcc and the subject, each on a line of its own, labels in one column.
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compose-subject')), findsOneWidget);
    final reply = find.byKey(const ValueKey('thread-reply'));
    final lefts = {for (final l in ['To', 'Cc', 'Bcc', 'Subject']) tester.getTopLeft(find.descendant(of: reply, matching: find.text(l)).first).dx.round()};
    expect(lefts.length, 1, reason: 'the labels start at different places: $lefts');
    expect(find.byKey(const ValueKey('compose-show-more')), findsNothing);
    // Tapping the To row opens the space to type another name; it folds away again when left.
    await tester.tap(typing);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(toField).focusNode!.hasFocus, isTrue);
    expect(tester.getSize(typing).width, greaterThanOrEqualTo(72));
    await tester.enterText(toField, 'sam@x.example ');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chip-To-sam@x.example')), findsOneWidget, reason: 'a second name can still be added on a phone');
    expect(tester.takeException(), isNull);
    // Back closes the reply first (the email stays open), then the email.
    await back(tester);
    expect(find.byKey(const ValueKey('thread-reply')), findsNothing);
    expect(find.byKey(const ValueKey('mail-done')), findsOneWidget, reason: 'the email is still open');
    await back(tester);
    expect(find.textContaining('2 emails need you'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('Chats: the list of people, then one conversation with a way back', (tester) async {
    final c = await pump(tester, Destination.chats);
    expect(find.text('Renee Calloway'), findsOneWidget);
    expect(find.text('Pick a person'), findsNothing, reason: 'no empty second pane on a phone');
    await tester.tap(find.text('Renee Calloway'));
    await tester.pumpAndSettle();
    expect(c.read(selectedRowProvider), 'c:renee@booking.example');
    expect(find.byKey(const ValueKey('compact-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-bar')), findsNothing);
    expect(tester.takeException(), isNull, reason: 'a conversation fits a phone');
    // Replying in a chat: the reply has the screen, and with the keyboard up Send stays above it.
    await tester.tap(find.byKey(const ValueKey('reply-pill')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 420);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'nothing runs off the screen with the keyboard up');
    expect(tester.getBottomLeft(find.byKey(const ValueKey('compose-send'))).dy, lessThanOrEqualTo(915 - 420), reason: 'Send is behind the keyboard');
    expect(tester.getRect(find.byType(ComposeEditor)).height, greaterThan(60));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    // Back closes the reply first; the conversation is still open.
    await back(tester);
    expect(find.byKey(const ValueKey('compose-send')), findsNothing);
    expect(c.read(selectedRowProvider), 'c:renee@booking.example');
    await back(tester);
    expect(c.read(selectedRowProvider), isNull);
    expect(find.byKey(const ValueKey('compact-bar')), findsOneWidget);
    // The compose button opens a new message, full screen; Back closes it.
    await tester.tap(find.byKey(const ValueKey('compact-compose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compact-back')), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'writing a message fits a phone');
    await tester.tap(find.byKey(const ValueKey('compact-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compact-bar')), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('More holds Noise, Done, Sent and Settings; Back steps out the way you came in', (tester) async {
    final c = await pump(tester, Destination.today, joined: true);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('compact-bar')), matching: find.text('More')));
    await tester.pumpAndSettle();
    for (final key in ['noise', 'done', 'sent', 'settings']) {
      expect(find.byKey(ValueKey('more-$key')), findsOneWidget, reason: key);
    }
    // Noise.
    await tester.tap(find.byKey(const ValueKey('more-noise')));
    await tester.pumpAndSettle();
    expect(c.read(destinationProvider), Destination.noise);
    expect(find.text('FlashDeals'), findsWidgets);
    expect(tester.takeException(), isNull);
    await back(tester);
    expect(find.byKey(const ValueKey('more-noise')), findsOneWidget, reason: 'Back from Noise returns to More');
    // Done.
    await tester.tap(find.byKey(const ValueKey('more-done')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing marked done yet today.'), findsOneWidget);
    await back(tester);
    expect(find.byKey(const ValueKey('more-done')), findsOneWidget);
    // Sent: Chats, showing the people you wrote to.
    await tester.tap(find.byKey(const ValueKey('more-sent')));
    await tester.pumpAndSettle();
    expect(c.read(destinationProvider), Destination.chats);
    expect(c.read(peopleFilterProvider), PeopleFilter.sent);
    // Settings: its list first, then one page, then back to the list, then to More.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('compact-bar')), matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('more-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-row-devices')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-row-keyboard')), findsNothing, reason: 'a phone has no keyboard shortcuts page');
    expect(find.byKey(const ValueKey('settings-row-defaultApp')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-row-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('Alerts on your phones'), findsOneWidget);
    expect(find.byKey(const ValueKey('alerts-quiet')), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-bar')), findsNothing);
    expect(tester.takeException(), isNull);
    await back(tester);
    expect(find.byKey(const ValueKey('settings-row-devices')), findsOneWidget);
    await back(tester);
    expect(find.byKey(const ValueKey('more-settings')), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('quiet hours set here are kept, and noted for every device', (tester) async {
    await pump(tester, Destination.settings, joined: true);
    await tester.tap(find.byKey(const ValueKey('settings-row-notifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alerts-quiet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('alerts-quiet-from')), findsOneWidget);
    final kept = await tester.runAsync(() => db.getSetting(kQuietHours));
    expect(kept, contains('"on":true'));
    final noted = await tester.runAsync(() => db.customSelect("SELECT data FROM helper_outbox WHERE kind = 'pref' AND k = 'quiet'").get());
    expect(noted!.single.read<String>('data'), contains('"from":"22:00"'));
    await teardown(tester);
  });

  testWidgets('a tablet turned sideways, and every PC, get the side-by-side layout', (tester) async {
    await pump(tester, Destination.focus, size: const Size(1400, 900), phone: false);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-bar')), findsNothing);
    // The PC's side rail has the same dot on Chats; it goes when the chat is read.
    expect(tester.widget<Badge>(find.byKey(const ValueKey('chats-badge')).first).isLabelVisible, isTrue);
    await tester.runAsync(() => db.customStatement('UPDATE messages SET is_seen = 1'));
    await tester.runAsync(() => db.customStatement('INSERT OR IGNORE INTO dirty_rows(row_key) SELECT DISTINCT row_key FROM message_row_assignments'));
    await tester.runAsync(db.refreshDirtyRows);
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byKey(const ValueKey('chats-badge')).first).isLabelVisible, isFalse);
    expect(find.text('Pick an email on the left to read it here.'), findsOneWidget);
    await teardown(tester);
  });
}
