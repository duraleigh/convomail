import 'package:convomail/app/shortcuts.dart';
import 'package:convomail/app/web_selection.dart';
import 'package:convomail/domain/simple_mail.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/screens/chats/simple_mail_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text highlighted in an open email can be copied: with Ctrl+C, and from
/// the menu a right-click brings up.
void main() {
  late String? copied;

  setUp(() {
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  /// The body as it sits in the app: under the app's own shortcuts, inside
  /// a scrolling list, in a card.
  Widget app(Widget body) => ProviderScope(
        child: MaterialApp(
          home: AppShortcutScope(
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(40),
                children: [
                  Material(child: InkWell(onTap: () {}, child: const Padding(padding: EdgeInsets.all(12), child: Text('SETH RUDETSKY')))),
                  body,
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> highlight(WidgetTester tester, Finder words) async {
    final box = tester.getRect(words);
    final mouse = await tester.startGesture(box.centerLeft + const Offset(1, 0), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 60));
    await mouse.moveTo(box.center);
    await tester.pump(const Duration(milliseconds: 60));
    await mouse.moveTo(box.centerRight - const Offset(1, 0));
    await tester.pump(const Duration(milliseconds: 60));
    await mouse.up();
    await tester.pumpAndSettle();
  }

  Future<void> ctrlC(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('a simple email: highlight, then Ctrl+C copies', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final blocks = simpleMailBlocks('<p>Are you going to be in New York this month?</p><p>It would be fun to get together.</p>')!;
    await tester.pumpWidget(app(SimpleMailBody(blocks: blocks)));
    await tester.pumpAndSettle();
    await highlight(tester, find.textContaining('Are you going to be in New York'));
    await ctrlC(tester);
    expect(copied, contains('going to be in New York'));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a simple email: right-click on highlighted words offers Copy', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final blocks = simpleMailBlocks('<p>Are you going to be in New York this month?</p>')!;
    await tester.pumpWidget(app(SimpleMailBody(blocks: blocks)));
    await tester.pumpAndSettle();
    final words = find.textContaining('Are you going to be in New York');
    await highlight(tester, words);
    await tester.tapAt(tester.getCenter(words), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, contains('going to be in New York'));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a designed email (shown in the browser box): what is highlighted in it is copied with Ctrl+C', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    var cleared = 0;
    final box = Object();
    await tester.pumpWidget(app(const PlainTextBody(text: 'Some other words in the app.')));
    await tester.pumpAndSettle();
    // The page reports what the mouse highlighted in it.
    WebSelection.report(box, 'Check-in: 4:00 PM', () => cleared++);
    await ctrlC(tester);
    expect(copied, 'Check-in: 4:00 PM');

    // A highlight in a second email replaces the first, and clears it there.
    final other = Object();
    WebSelection.report(other, 'Confirmation 84412207', () {});
    expect(cleared, 1);
    await ctrlC(tester);
    expect(copied, 'Confirmation 84412207');

    // Once nothing is highlighted in a designed email, Ctrl+C is ordinary
    // copying again: what is selected in the app's own text.
    WebSelection.report(other, '', () {});
    expect(WebSelection.text, isNull);
    copied = null;
    await highlight(tester, find.byKey(const ValueKey('plain-body')));
    await ctrlC(tester);
    expect(copied, contains('other words'));
    debugDefaultTargetPlatformOverride = null;
  });

  test('a click elsewhere lets go of what was highlighted in a designed email', () {
    var cleared = 0;
    final box = Object();
    WebSelection.report(box, 'Gate B12', () => cleared++);
    expect(WebSelection.text, 'Gate B12');
    WebSelection.clear();
    expect(WebSelection.text, isNull);
    expect(cleared, 1, reason: 'the highlight is removed in the page too');
    // An email that closes takes its highlight with it, and only its own.
    final a = Object();
    final b = Object();
    WebSelection.report(a, 'one', () {});
    WebSelection.drop(b);
    expect(WebSelection.text, 'one');
    WebSelection.drop(a);
    expect(WebSelection.text, isNull);
  });

  testWidgets('a plain-text email: highlight, then Ctrl+C copies', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(app(const PlainTextBody(text: 'They will hold it until three today.')));
    await tester.pumpAndSettle();
    await highlight(tester, find.byKey(const ValueKey('plain-body')));
    await ctrlC(tester);
    expect(copied, contains('hold it until three'));
    debugDefaultTargetPlatformOverride = null;
  });
}
