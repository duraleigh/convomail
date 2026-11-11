import 'package:convomail/helper/helper_sync.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/helper_queries.dart';
import 'package:convomail/ui/screens/settings/devices_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_helper.dart';
import 'support/test_db.dart';

/// Lets the work started by a tap run to its end, redrawing as it goes.
/// (Not pumpAndSettle: a progress bar shows while the work runs, and a
/// moving bar never "settles".)
Future<void> settle(WidgetTester tester, ProviderContainer container) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
}

Future<void> close(WidgetTester tester, ProviderContainer container) async {
  await settle(tester, container);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50));
}

/// Settings → Your devices, against a stand-in helper.
void main() {
  late AppDatabase db;
  late FakeHelper helper;

  setUp(() {
    db = testDatabase();
    helper = FakeHelper();
  });

  tearDown(() => db.close());

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) => db),
        credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
        helperHttpProvider.overrideWith((ref) => helper.call),
      ],
      child: const MaterialApp(home: Scaffold(body: Padding(padding: EdgeInsets.all(16), child: DevicesDetail()))),
    ));
    final container = ProviderScope.containerOf(tester.element(find.byType(DevicesDetail)));
    await settle(tester, container);
    return ProviderScope.containerOf(tester.element(find.byType(DevicesDetail)));
  }

  testWidgets('not following: says what the helper is, offers the address and a code, and shows a wrong code plainly', (tester) async {
    final container = await pump(tester);
    expect(find.textContaining('This PC does not follow one yet'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('devices-address'))).controller!.text, defaultHelperAddress);
    expect(find.textContaining('It does not send your mail'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('devices-address')), 'localhost');
    await tester.enterText(find.byKey(const ValueKey('devices-code')), 'nope-nope');
    await tester.tap(find.byKey(const ValueKey('devices-join')));
    await settle(tester, container);
    expect(find.byKey(const ValueKey('devices-error')), findsOneWidget);
    expect(find.textContaining('not right'), findsOneWidget);
    expect(find.byKey(const ValueKey('devices-join')), findsOneWidget, reason: 'still the join form');
    await close(tester, container);
  });

  testWidgets('joining shows the helper, its mailbox and timer, and every device; a code can be made for the next one', (tester) async {
    final container = await pump(tester);
    await tester.enterText(find.byKey(const ValueKey('devices-address')), 'localhost');
    await tester.enterText(find.byKey(const ValueKey('devices-code')), 'good-code');
    await tester.tap(find.byKey(const ValueKey('devices-join')));
    await settle(tester, container);
    await settle(tester, container);

    expect(find.text('Following localhost'), findsOneWidget);
    expect(find.byKey(const ValueKey('devices-mailbox-me@example.com')), findsOneWidget);
    expect(find.textContaining('First read of 30 days: 200 emails so far'), findsOneWidget);
    expect(find.textContaining('It looks every minute'), findsOneWidget);
    expect(find.text('Its every-minute timer is running'), findsOneWidget);
    expect(find.textContaining('(this PC)'), findsOneWidget);
    expect(find.byKey(const ValueKey('devices-signout-1')), findsNothing, reason: 'this PC is left with Stop, not Sign out');
    expect(await tester.runAsync(db.helperConnected), isTrue);

    await tester.tap(find.byKey(const ValueKey('devices-new-code')));
    await settle(tester, container);
    expect(find.textContaining('NEXTCODE', findRichText: true), findsOneWidget);

    // Another device joined with it; it can be signed out from here.
    helper.tokens[2] = '2.other-device';
    helper.names[2] = 'Clay phone';
    await tester.tap(find.byKey(const ValueKey('devices-sync-now')));
    await settle(tester, container);
    expect(find.text('Clay phone'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('devices-signout-2')));
    await settle(tester, container);
    expect(find.text('Clay phone'), findsNothing);
    expect(helper.tokens.keys, [1]);
    await close(tester, container);
  });

  testWidgets('stopping asks first, then goes back to the join form and tells the helper', (tester) async {
    final container = await pump(tester);
    await tester.enterText(find.byKey(const ValueKey('devices-address')), 'localhost');
    await tester.enterText(find.byKey(const ValueKey('devices-code')), 'good-code');
    await tester.tap(find.byKey(const ValueKey('devices-join')));
    await settle(tester, container);

    await tester.ensureVisible(find.byKey(const ValueKey('devices-leave')));
    await settle(tester, container);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('devices-leave')), matching: find.text('Stop')));
    await settle(tester, container);
    await tester.tap(find.text('Cancel'));
    await settle(tester, container);
    expect(find.text('Following localhost'), findsOneWidget, reason: 'nothing happens without a yes');

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('devices-leave')), matching: find.text('Stop')));
    await settle(tester, container);
    await tester.tap(find.byKey(const ValueKey('devices-leave-confirm')));
    await settle(tester, container);
    expect(find.byKey(const ValueKey('devices-join')), findsOneWidget);
    expect(helper.tokens, isEmpty);
    expect(await tester.runAsync(db.helperConnected), isFalse);
    await close(tester, container);
  });
}
