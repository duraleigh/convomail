import 'package:convomail/app/destinations.dart';
import 'package:convomail/app/settings.dart';
import 'package:convomail/main.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:convomail/ui/theme/app_theme.dart';
import 'package:convomail/ui/widgets/connected_button_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real app root (watches settings, applies the theme) with an
/// in-memory settings store and database, and no background sync.
Widget _app(InMemorySettingsStore store) => ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWith((ref) => store),
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase.memory();
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: const PrecisApp(startSync: false),
    );


/// Disposes the tree inside the test so drift's stream cleanup timer fires
/// before the framework checks for pending timers.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  setUp(() {
    // Desktop-sized window so the three-pane layout has room.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('shell renders rail with all destinations and the compose FAB', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(InMemorySettingsStore()));
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Précis'), findsOneWidget, reason: 'named on the rail only, not again on the page');
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Noise'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Search people and mail'), findsNothing, reason: 'no search box until asked for');
    await tester.tap(find.byKey(const ValueKey('search-button')));
    await tester.pumpAndSettle();
    expect(find.text('Search people and mail'), findsOneWidget, reason: 'the search icon opens the bar');
    await tester.tap(find.byKey(const ValueKey('top-search-close')));
    await tester.pumpAndSettle();
    expect(find.text('Search people and mail'), findsNothing);
    // Ctrl+F opens it too, ready to type; Esc closes it.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Search people and mail'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Search people and mail'), findsNothing);
    expect(find.text('Pick a person'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('tapping a rail destination switches content', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(InMemorySettingsStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Précis').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-greeting')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-needs-you')), findsNothing, reason: 'Needs you has nothing until the assistant is on, and an empty card is not drawn');

    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-empty')), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsWidgets);
    await _teardown(tester);
  });

  testWidgets('Ctrl+1 to Ctrl+6 open Today, Focus, Chats, Feed, Noise and Settings', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(InMemorySettingsStore()));
    await tester.pumpAndSettle();

    Future<void> ctrl(LogicalKeyboardKey digit) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(digit);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await ctrl(LogicalKeyboardKey.digit1);
    expect(find.byKey(const ValueKey('today-greeting')), findsOneWidget);
    await ctrl(LogicalKeyboardKey.digit2);
    expect(find.byKey(const ValueKey('focus-empty')), findsOneWidget);
    await ctrl(LogicalKeyboardKey.digit3);
    expect(find.text('Pick a person'), findsOneWidget);
    await ctrl(LogicalKeyboardKey.digit4);
    expect(find.text('Nothing in Feed'), findsOneWidget);
    await ctrl(LogicalKeyboardKey.digit5);
    expect(find.text('Nothing in Noise'), findsOneWidget);
    await ctrl(LogicalKeyboardKey.digit6);
    expect(find.text('Appearance'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('the rail is Today, Focus, Chats, Feed, Noise, Attachments; Boards and Planner are gone', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(InMemorySettingsStore()));
    await tester.pumpAndSettle();

    expect(Destination.rail, [Destination.today, Destination.focus, Destination.chats, Destination.feed, Destination.noise, Destination.attachments]);
    expect(find.text('Boards'), findsNothing);
    expect(find.text('Planner'), findsNothing);
    expect(find.text('People'), findsNothing);
    expect(find.text('No conversations yet'), findsOneWidget);
    await tester.tap(find.text('Feed').first);
    await tester.pumpAndSettle();
    expect(find.text('Nothing in Feed'), findsOneWidget);
    await tester.tap(find.text('Noise').first);
    await tester.pumpAndSettle();
    expect(find.text('Nothing in Noise'), findsOneWidget);
    await tester.tap(find.text('Précis').first);
    await tester.pumpAndSettle();
    // With no mail, only Schedule shows: a card with nothing in it is not drawn.
    expect(find.text('SCHEDULE'), findsOneWidget);
    for (final empty in ['NEEDS YOU', 'GOOD TO KNOW', 'WAITING ON', 'FYI', 'LATER', 'DONE']) {
      expect(find.text(empty), findsNothing, reason: empty);
    }
    await tester.tap(find.text('Focus').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-empty')), findsOneWidget);
    await tester.tap(find.text('Chats').first);
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('theme choice persists to the settings store', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = InMemorySettingsStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Dark'));
    await tester.pumpAndSettle();

    expect(store.values['appearance.themeMode'], 'dark');
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
    await _teardown(tester);
  });

  testWidgets('settings load from the store on start', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = InMemorySettingsStore();
    await store.putSetting('appearance.themeMode', 'dark');
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
    expect(container.read(destinationProvider), Destination.chats);
    // The real root applies the loaded mode to the MaterialApp.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    await _teardown(tester);
  });

  test('startup args pick the initial destination', () {
    final a = StartupArgs.parse(['--destination=settings']);
    expect(a.destination, Destination.settings);
    expect(a.overrides.length, 1);
    expect(StartupArgs.parse(['--inbox=feed']).destination, Destination.feed);
    expect(StartupArgs.parse(['--inbox=noise']).destination, Destination.noise);
    expect(StartupArgs.parse(['--destination=today']).destination, Destination.today);

    final b = StartupArgs.parse(['--destination=nonsense', 'other']);
    expect(b.destination, isNull);
    expect(b.opensOn, Destination.today, reason: 'nothing usable asked for: the front page');
    expect(b.overrides, hasLength(1));
  });

  testWidgets('ConnectedButtonGroup reports selection', (tester) async {
    var selected = 'a';
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: ConnectedButtonGroup<String>(
            selected: selected,
            onSelected: (v) => setState(() => selected = v),
            items: const [
              ButtonGroupItem(value: 'a', label: 'Alpha'),
              ButtonGroupItem(value: 'b', label: 'Beta'),
            ],
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(selected, 'b');
    await _teardown(tester);
  });
}
