import 'package:convomail/helper/helper_sync.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/ui/screens/settings/assistant_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_helper.dart';
import 'support/test_db.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
}

/// Settings → The assistant and its cost, against a stand-in helper.
void main() {
  late AppDatabase db;
  late FakeHelper helper;

  setUp(() {
    db = testDatabase();
    helper = FakeHelper();
  });

  tearDown(() => db.close());

  Future<ProviderContainer> pump(WidgetTester tester, {bool join = true}) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) => db),
      credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
      helperHttpProvider.overrideWith((ref) => helper.call),
    ]);
    addTearDown(container.dispose);
    if (join) {
      await tester.runAsync(() async {
        await container.read(helperProvider.notifier).connect('localhost', 'good-code', name: 'Test PC');
        await container.read(helperProvider.notifier).idle();
      });
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: Padding(padding: EdgeInsets.all(16), child: AssistantDetail()))),
    ));
    await settle(tester);
    return container;
  }

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() => container.read(helperProvider.notifier).idle());
  }

  testWidgets('money reads as dollars and cents, and under a cent in full', (tester) async {
    expect(dollars(2700000), '\$2.70');
    expect(dollars(0), '\$0.00');
    expect(dollars(2900), '\$0.0029');
  });

  testWidgets('not following a helper: says the assistant lives there', (tester) async {
    final container = await pump(tester, join: false);
    expect(find.byKey(const ValueKey('assistant-no-helper')), findsOneWidget);
    await close(tester, container);
  });

  testWidgets('no key yet: says where the key goes, and that it is never typed into the app', (tester) async {
    final container = await pump(tester);
    expect(find.byKey(const ValueKey('assistant-no-key')), findsOneWidget);
    expect(find.textContaining('never typed into this app'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'no box to type a key into');
    await close(tester, container);
  });

  testWidgets('on: the reader, this month\'s cost, the ceiling, what it read, and how often it was corrected; the switch turns it off', (tester) async {
    helper.assistant = {...helper.assistant, 'hasKey': true, 'on': true, 'model': 'claude-sonnet-5-5', 'modelName': 'Claude Sonnet 5.5', 'ceiling': 15000000, 'month': 2720000, 'today': 310000, 'read': 561, 'waiting': 2, 'focus': 4, 'made7': 561, 'fixed7': 3};
    final container = await pump(tester);
    expect(find.text('On'), findsOneWidget);
    expect(find.textContaining('Reading with Claude Sonnet 5.5'), findsOneWidget);
    expect(find.text('\$2.72 this month'), findsOneWidget);
    expect(find.text('Ceiling: \$15.00 a month'), findsOneWidget);
    expect(find.text('561 emails read'), findsOneWidget);
    expect(find.text('This past week you corrected 3 of the 561 lines it made'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('assistant-switch')));
    await settle(tester);
    expect(helper.assistant['on'], false, reason: 'off for every device, at the helper');
    expect(find.text('Off'), findsOneWidget);
    expect(await tester.runAsync(() => db.getSetting(kAssistantOn)), '0', reason: 'its sentences hide here at once');

    // A new ceiling.
    await tester.enterText(find.byKey(const ValueKey('assistant-ceiling-field')), '9.50');
    await tester.tap(find.byKey(const ValueKey('assistant-ceiling-save')));
    await settle(tester);
    expect(helper.assistant['ceiling'], 9500000);
    expect(find.text('Ceiling: \$9.50 a month'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('assistant-ceiling-field')), 'lots');
    await tester.tap(find.byKey(const ValueKey('assistant-ceiling-save')));
    await settle(tester);
    expect(find.byKey(const ValueKey('assistant-error')), findsOneWidget);
    expect(helper.assistant['ceiling'], 9500000);
    await close(tester, container);
  });

  testWidgets('paused: says why, in the helper\'s words', (tester) async {
    helper.assistant = {...helper.assistant, 'hasKey': true, 'on': true, 'modelName': 'Claude Sonnet 5.5', 'model': 'claude-sonnet-5-5', 'problem': 'This month\'s ceiling of \$15.00 was reached. Mail keeps being sorted by the fixed rules.', 'problemKind': 'ceiling'};
    final container = await pump(tester);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.textContaining('ceiling of \$15.00 was reached'), findsOneWidget);
    await close(tester, container);
  });
}
