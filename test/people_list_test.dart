import 'package:convomail/app/people_state.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/merge_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/sync/classification_service.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/screens/chats/person_row.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:convomail/ui/widgets/tonal_avatar.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
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
          // No WebView2 in the test harness.
          htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
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
    expect(find.text('Figma access'), findsNothing, reason: 'rows show the sender only, no message text');
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

    await tester.tap(find.byKey(const ValueKey('filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread').last);
    await tester.pumpAndSettle();
    expect(find.text('Sarah Chen'), findsOneWidget);
    expect(find.text('Tom Andersen'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'tom');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    // Search mode (M6): Tom appears as a People match and as the sender of
    // his message hit; Sarah appears nowhere.
    expect(find.text('Tom Andersen'), findsWidgets);
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

  Future<Contact> contact(String key) => (db.select(db.contacts)..where((c) => c.key.equals(key))).getSingle();

  Future<void> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl-click picks rows; the bar moves them all to Feeds for good; Undo puts them back', (tester) async {
    await pumpList(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Sarah Chen'));
    await tester.tap(find.text('Tom Andersen'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('row-check-c:sarah@x.com')), findsOneWidget, reason: 'checkboxes show while picking');
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(selectedRowProvider), isNull, reason: 'picking does not open a conversation');

    await tester.tap(find.byKey(const ValueKey('bulk-move')));
    await tester.pumpAndSettle();
    for (final k in ['sarah@x.com', 'tom@x.com']) {
      final c = await contact(k);
      expect(c.classification, 'feeds');
      expect(c.classificationSource, 'override');
    }
    expect(find.byKey(const ValueKey('selection-bar')), findsNothing);
    expect(find.text('Sarah Chen'), findsNothing, reason: 'gone from People');
    expect(find.textContaining('2 senders moved to Feeds'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await contact('sarah@x.com')).classification, 'people');
    expect((await contact('tom@x.com')).classificationSource, isNot('override'));
    expect(find.text('Sarah Chen'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('Shift-click picks a range from the open row; a plain click then toggles; Esc clears', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text('Sarah Chen'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Tom Andersen').first);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Tom Andersen').first);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selection-bar')), findsNothing);
    await teardown(tester);
  });

  testWidgets('Ctrl+A picks every row; bulk Mark as read clears the badges', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text('Tom Andersen'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bulk-read')));
    await tester.pumpAndSettle();
    expect(find.byType(CountBadge), findsNothing);
    expect(find.byKey(const ValueKey('selection-bar')), findsNothing);
    await teardown(tester);
  });

  group('merge people', () {
    Future<void> seedSecondAddress() async {
      final folder = (await db.select(db.folders).get()).first;
      final id = await db.into(db.messages).insert(MessagesCompanion.insert(
            accountId: folder.accountId,
            folderId: folder.id,
            uid: 500,
            subject: const Value('From the other address'),
            fromAddress: const Value('sarah@work.com'),
            fromName: const Value('Sarah C'),
            fromContactKey: const Value('sarah@work.com'),
            date: Value(DateTime.now()),
          ));
      await db.into(db.messageRowAssignments).insert(MessageRowAssignmentsCompanion.insert(messageId: id, rowKey: 'c:sarah@work.com'));
      await db.into(db.contacts).insert(ContactsCompanion.insert(key: 'sarah@work.com', displayName: const Value('Sarah C')), mode: InsertMode.insertOrIgnore);
      await db.into(db.contactAddresses).insert(ContactAddressesCompanion.insert(address: 'sarah@work.com', contactKey: 'sarah@work.com'), mode: InsertMode.insertOrIgnore);
      await db.into(db.contactAddresses).insert(ContactAddressesCompanion.insert(address: 'sarah@x.com', contactKey: 'sarah@x.com'), mode: InsertMode.insertOrIgnore);
      await db.into(db.rowPrefs).insert(RowPrefsCompanion.insert(rowKey: 'c:sarah@work.com', pinned: const Value(true)));
      await db.refreshDirtyRows();
    }

    Future<List<String>> keys() async => (await db.peopleRows()).map((r) => r.rowKey).toList();

    test('rows and messages combine; the kept name stays; a later message from either address files there', () async {
      await seedSecondAddress();
      await ClassificationService(db).mergePeople('sarah@x.com', ['sarah@x.com', 'sarah@work.com']);
      await db.refreshDirtyRows();

      final all = await keys();
      expect(all, contains('c:sarah@x.com'));
      expect(all, isNot(contains('c:sarah@work.com')));
      final row = (await db.peopleRows()).firstWhere((r) => r.rowKey == 'c:sarah@x.com');
      expect(row.title, 'Sarah Chen');
      expect(row.pinned, isTrue, reason: 'preferences carry over');
      expect((await db.messagesForRow('c:sarah@x.com')).map((m) => m.subject), contains('From the other address'));
      expect((await (db.select(db.contacts)..where((c) => c.key.equals('sarah@work.com'))).get()), isEmpty);

      final identity = await db.loadIdentityResolver();
      expect(identity.contactKeyFor('sarah@work.com'), 'sarah@x.com', reason: 'future mail resolves to the merged person');
    });

    test('undo puts everything back', () async {
      await seedSecondAddress();
      final service = ClassificationService(db);
      final snapshot = await service.mergePeople('sarah@x.com', ['sarah@work.com']);
      await service.undoMerge(snapshot);
      await db.refreshDirtyRows();

      final rows = await db.peopleRows();
      expect(rows.map((r) => r.rowKey), containsAll(['c:sarah@x.com', 'c:sarah@work.com']));
      expect(rows.firstWhere((r) => r.rowKey == 'c:sarah@work.com').pinned, isTrue);
      expect((await db.messagesForRow('c:sarah@work.com')).single.subject, 'From the other address');
    });

    test('separating an address restores filing, named from its mail', () async {
      await seedSecondAddress();
      final service = ClassificationService(db);
      await service.mergePeople('sarah@x.com', ['sarah@work.com']);
      expect(await db.addressesOf('sarah@x.com'), ['sarah@x.com', 'sarah@work.com']);
      await service.separateAddress('sarah@x.com', 'sarah@work.com');
      await db.refreshDirtyRows();

      final rows = await db.peopleRows();
      expect(rows.firstWhere((r) => r.rowKey == 'c:sarah@work.com').title, 'Sarah C');
      expect((await db.messagesForRow('c:sarah@x.com')).map((m) => m.subject), isNot(contains('From the other address')));
    });

    testWidgets('picking two rows offers Merge; a dialog picks the name; Undo works', (tester) async {
      await seedSecondAddress();
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Sarah Chen'));
      await tester.pump();
      expect(find.byKey(const ValueKey('bulk-merge')), findsNothing, reason: 'one row cannot merge');
      await tester.tap(find.text('Sarah C'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('bulk-merge')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('merge-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('merge-keep-sarah@work.com')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('merge-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Sarah Chen'), findsNothing);
      expect(find.descendant(of: find.byType(PersonRow), matching: find.text('Sarah C')), findsOneWidget);
      expect(find.textContaining('Merged 2 people into Sarah C'), findsOneWidget);
      await teardown(tester);
    });
  });

  testWidgets('hover actions never cover the name, and leave the time and the row height alone', (tester) async {
    await db.setContactLabel('sarah@x.com', 'A Rather Long Sender Name That Fills The Row');
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final name = find.byKey(const ValueKey('row-name-c:sarah@x.com'));
    final before = tester.getRect(name);
    final rowBefore = tester.getRect(find.ancestor(of: name, matching: find.byType(PersonRow)));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(name));
    await tester.pumpAndSettle();

    final actions = find.byKey(const ValueKey('row-actions-c:sarah@x.com'));
    expect(actions, findsOneWidget);
    expect(find.descendant(of: actions, matching: find.byType(IconButton)), findsNWidgets(5));
    final after = tester.getRect(name);
    expect(after.width, before.width, reason: 'the name keeps all its room');
    expect(after.overlaps(tester.getRect(actions)), isFalse);
    expect(tester.getRect(find.ancestor(of: name, matching: find.byType(PersonRow))).height, rowBefore.height);
    final row = find.ancestor(of: name, matching: find.byType(PersonRow));
    expect(find.descendant(of: row, matching: find.byType(CountBadge)), findsOneWidget, reason: 'the unread badge stays');
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(actions, findsNothing);
    await teardown(tester);
  });

  testWidgets('A subtitle is optional, shows under the name, survives deleting all mail, and is searchable', (tester) async {
    await pumpList(tester);
    const subtitleKey = ValueKey('row-subtitle-c:sarah@x.com');
    expect(find.byKey(subtitleKey), findsNothing, reason: 'none until the user adds one');

    await tester.tap(find.text('Sarah Chen'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit name and subtitle…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('subtitle-field')), '  Talent agent  ');
    await tester.tap(find.byKey(const ValueKey('rename-save')));
    await tester.pumpAndSettle();

    expect(find.text('Talent agent'), findsOneWidget);
    expect((await contact('sarah@x.com')).userSubtitle, 'Talent agent');
    expect((await contact('sarah@x.com')).userLabel, 'Sarah Chen');
    final name = tester.getRect(find.byKey(const ValueKey('row-name-c:sarah@x.com')));
    final sub = tester.getRect(find.byKey(subtitleKey));
    expect(sub.top, greaterThanOrEqualTo(name.bottom), reason: 'under the name');
    expect(tester.widget<Text>(find.byKey(subtitleKey)).style!.fontSize, lessThan(tester.widget<Text>(find.byKey(const ValueKey('row-name-c:sarah@x.com'))).style!.fontSize!));

    expect((await db.peopleRows(search: 'talent')).map((r) => r.rowKey), ['c:sarah@x.com']);

    await (db.delete(db.messages)..where((m) => m.fromAddress.equals('sarah@x.com'))).go();
    await db.refreshDirtyRows();
    expect((await contact('sarah@x.com')).userSubtitle, 'Talent agent');

    await db.setContactSubtitle('sarah@x.com', ' ');
    expect((await contact('sarah@x.com')).userSubtitle, isNull, reason: 'blank removes it');
    await teardown(tester);
  });

  testWidgets('Rename a sender from the row menu; the name sticks after deleting all mail and for new mail', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text('Sarah Chen'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit name and subtitle…'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rename-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('rename-field')), 'Sarah C.');
    await tester.tap(find.byKey(const ValueKey('rename-save')));
    await tester.pumpAndSettle();
    expect(find.text('Sarah C.'), findsOneWidget);
    expect(find.text('Sarah Chen'), findsNothing);
    expect((await contact('sarah@x.com')).userLabel, 'Sarah C.');

    // Delete every message from Sarah, then a new one arrives.
    await (db.delete(db.messages)..where((m) => m.fromAddress.equals('sarah@x.com'))).go();
    await db.refreshDirtyRows();
    expect((await contact('sarah@x.com')).userLabel, 'Sarah C.');
    final folder = (await db.select(db.folders).get()).first;
    final id = await db.into(db.messages).insert(MessagesCompanion.insert(
          accountId: folder.accountId,
          folderId: folder.id,
          uid: 99,
          subject: const Value('Back again'),
          fromAddress: const Value('sarah@x.com'),
          fromName: const Value('Chen, Sarah'),
          fromContactKey: const Value('sarah@x.com'),
          date: Value(DateTime.now()),
        ));
    await db.into(db.messageRowAssignments).insert(MessageRowAssignmentsCompanion.insert(messageId: id, rowKey: 'c:sarah@x.com'));
    await db.refreshDirtyRows();
    final rows = await db.peopleRows();
    expect(rows.firstWhere((r) => r.rowKey == 'c:sarah@x.com').title, 'Sarah C.');

    // Back to the name from the headers.
    await db.setContactLabel('sarah@x.com', '');
    expect((await db.peopleRows()).firstWhere((r) => r.rowKey == 'c:sarah@x.com').title, 'Sarah Chen');
    await teardown(tester);
  });
}
