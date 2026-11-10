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
      child: const ConvoMailApp(startSync: false),
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
    expect(find.text('Boards'), findsOneWidget);
    expect(find.text('Planner'), findsOneWidget);
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

    await tester.tap(find.text('Boards'));
    await tester.pumpAndSettle();
    expect(find.text('No cards yet'), findsOneWidget);

    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('planner-today')), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsWidgets);
    await _teardown(tester);
  });

  testWidgets('Ctrl+3 jumps to Boards and Ctrl+1 back to Chats', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(InMemorySettingsStore()));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('No cards yet'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Pick a person'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('Feeds sits in the rail after Chats, with no People/Feeds switch on the list', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(InMemorySettingsStore()));
    await tester.pumpAndSettle();

    expect(Destination.rail, [Destination.chats, Destination.feeds, Destination.boards, Destination.planner]);
    expect(find.text('People'), findsNothing);
    expect(find.text('No conversations yet'), findsOneWidget);
    await tester.tap(find.text('Feeds').first);
    await tester.pumpAndSettle();
    expect(find.text('Nothing in Feeds'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
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
    expect(StartupArgs.parse(['--inbox=feeds']).destination, Destination.feeds);
    expect(StartupArgs.parse(['--destination=feeds']).destination, Destination.feeds);

    final b = StartupArgs.parse(['--destination=nonsense', 'other']);
    expect(b.destination, isNull);
    expect(b.overrides, isEmpty);
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
