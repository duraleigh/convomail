import 'package:convomail/app/people_state.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:convomail/ui/widgets/tonal_avatar.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// The People list through the UI: rows render from the database, selection
/// shows the row's messages, keyboard and hover actions work.
void main() {
  late AppDatabase db;

  Widget app() => ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
          databaseProvider.overrideWith((ref) => db),
          credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
          transportFactoryProvider.overrideWith((ref) => () => FakeMailTransport()),
        ],
        child: const ConvoMailApp(startSync: false),
      );

  Future<void> seed() async {
    final account = await insertTestAccount(db);
    final inbox = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: account.id, path: 'INBOX', name: 'INBOX', role: const Value('inbox')));
    Future<void> msg(int uid, String from, String name, String subject, DateTime date, {bool seen = false, bool fromMe = false}) async {
      final id = await db.into(db.messages).insert(MessagesCompanion.insert(
            accountId: account.id,
            folderId: inbox,
            uid: uid,
            subject: Value(subject),
            fromAddress: Value(from),
            fromName: Value(name),
            fromContactKey: Value(fromMe ? 'me' : from),
            isFromMe: Value(fromMe),
            date: Value(date),
            isSeen: Value(seen),
          ));
      await db.into(db.messageRowAssignments).insert(MessageRowAssignmentsCompanion.insert(messageId: id, rowKey: 'c:$from'));
      await db.into(db.contacts).insert(ContactsCompanion.insert(key: from, displayName: Value(name)), mode: InsertMode.insertOrIgnore);
    }

    final now = DateTime.now();
    await msg(1, 'sarah@x.com', 'Sarah Chen', 'Design review', now.subtract(const Duration(hours: 2)));
    await msg(2, 'sarah@x.com', 'Sarah Chen', 'Figma access', now.subtract(const Duration(hours: 1)));
    await msg(3, 'tom@x.com', 'Tom Andersen', 'Slides', now.subtract(const Duration(days: 1)), seen: true);
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
    await db.close();
  }

  setUp(() async {
    db = AppDatabase.memory();
    await seed();
  });

  testWidgets('rows render newest first with unread badge; selecting shows messages', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Sarah Chen'), findsOneWidget);
    expect(find.text('Tom Andersen'), findsOneWidget);
    expect(find.text('Figma access'), findsOneWidget, reason: 'newest message is the preview');
    expect(find.widgetWithText(CountBadge, '2'), findsOneWidget);
    // Sarah (2h ago) sorts above Tom (yesterday).
    expect(tester.getTopLeft(find.text('Sarah Chen')).dy, lessThan(tester.getTopLeft(find.text('Tom Andersen')).dy));

    await tester.tap(find.text('Tom Andersen'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(selectedRowProvider), 'c:tom@x.com');
    expect(find.text('Slides'), findsWidgets);
    expect(find.text('1 message'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('arrow keys move the selection; P pins the row to the top', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sarah Chen'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(selectedRowProvider), 'c:tom@x.com');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pumpAndSettle();
    expect((await db.rowPref('c:tom@x.com'))!.pinned, isTrue);
    // The selected row's title also appears in the right pane header; the
    // list row is the first match in tree order.
    expect(tester.getTopLeft(find.text('Tom Andersen').first).dy, lessThan(tester.getTopLeft(find.text('Sarah Chen').first).dy), reason: 'pinned first');
    await teardown(tester);
  });

  testWidgets('Unread filter hides fully-read rows; search narrows by name', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Unread'));
    await tester.pumpAndSettle();
    expect(find.text('Sarah Chen'), findsOneWidget);
    expect(find.text('Tom Andersen'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'tom');
    await tester.pumpAndSettle();
    expect(find.text('Tom Andersen'), findsOneWidget);
    expect(find.text('Sarah Chen'), findsNothing);
    await teardown(tester);
  });

  testWidgets('hover reveals actions; Mark all as read clears the badge', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Sarah Chen')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mark all as read'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CountBadge, '2'), findsNothing);
    await teardown(tester);
  });
}
