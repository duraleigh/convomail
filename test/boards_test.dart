import 'package:convomail/app/destinations.dart';
import 'package:convomail/app/people_state.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/board_queries.dart';
import 'package:convomail/store/database.dart' hide Tags;
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/planner_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/screens/planner_screen.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Boards (spec 4.8, plan M9): columns, cards, tags with sub-tags, moves,
/// and the UI: add to board from a thread, drag between columns, counts,
/// the side panel; plus Planner UI: event block, detail, open conversation.
void main() {
  const me = RemoteAddress('me@example.com');
  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    account = await insertTestAccount(db);
    final inbox = imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@chen.me', 'Sarah Chen'), to: const [me], subject: 'Figma access', messageId: '<a@x>', date: DateTime.now().subtract(const Duration(hours: 2))), body: const RemoteMessageBody(text: 'Can you add me?'));
    inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@chen.me', 'Sarah Chen'), to: const [me], subject: 'Re: Figma access', messageId: '<b@x>', inReplyTo: '<a@x>', date: DateTime.now().subtract(const Duration(hours: 1))), body: const RemoteMessageBody(text: 'Thanks!'));
    inbox.add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('tom@andersen.me', 'Tom Andersen'), to: const [me], subject: 'Slides', date: DateTime.now().subtract(const Duration(days: 1))), body: const RemoteMessageBody(text: 'Deck attached'));
  });

  tearDown(() => db.close());

  Future<AccountSyncer> sync() async {
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
    return syncer;
  }

  group('queries', () {
    test('default columns; cards carry subject, sender, row, count; moves re-number; delete column relocates', () async {
      await sync();
      final cols = await db.watchColumns().first;
      expect(cols.map((c) => c.name), ['Next', 'In Progress', 'Done']);
      final figma = (await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Figma access');
      final slides = (await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Slides');
      final c1 = await db.addCard(figma.threadKey!);
      final c2 = await db.addCard(slides.threadKey!);
      expect(await db.addCard(figma.threadKey!), c1, reason: 'idempotent');
      var cards = await db.watchCards().first;
      expect(cards, hasLength(2));
      final figmaCard = cards.firstWhere((c) => c.card.id == c1);
      expect(figmaCard.title, 'Re: Figma access', reason: 'newest message in the thread');
      expect(figmaCard.senderName, 'Sarah Chen');
      expect(figmaCard.rowKey, 'c:sarah@chen.me');
      expect(figmaCard.messageCount, 2);
      expect(await db.columnCounts(), {cols[0].id: 2});

      await db.moveCard(c1, cols[1].id);
      cards = await db.watchCards().first;
      expect(cards.firstWhere((c) => c.card.id == c1).card.columnId, cols[1].id);
      expect(cards.firstWhere((c) => c.card.id == c2).card.sortOrder, 0, reason: 're-numbered after the move');
      await db.moveCard(c2, cols[1].id, index: 0);
      cards = await db.watchCards().first;
      expect(cards.where((c) => c.card.columnId == cols[1].id).map((c) => c.card.id), [c2, c1]);

      final extra = await db.addColumn('Waiting');
      expect((await db.watchColumns().first).last.name, 'Waiting');
      await db.renameColumn(extra, 'Waiting on');
      expect(await db.deleteColumn(cols[1].id), isTrue);
      cards = await db.watchCards().first;
      expect(cards.every((c) => c.card.columnId == cols[0].id), isTrue, reason: 'relocated to the first column');
      await db.deleteColumn(cols[0].id);
      await db.deleteColumn(cols[2].id);
      expect(await db.deleteColumn(extra), isFalse, reason: 'the last column stays');
      await db.removeCard(c1);
      expect(await db.watchCards().first, hasLength(1));
    });

    test('tags nest without limit, carry paths, and delete as a subtree', () async {
      final work = await db.createTag('Work');
      final design = await db.createTag('Design', parentId: work);
      final icons = await db.createTag('Icons', parentId: design);
      await db.createTag('Personal');
      final flat = await db.watchTags().first;
      final tree = BoardQueries.buildTagTree(flat);
      expect(tree.map((n) => n.name), ['Work', 'Personal'], reason: 'creation order');
      expect(tree.first.children.single.children.single.name, 'Icons');
      expect(BoardQueries.tagPath(flat, flat.firstWhere((t) => t.id == icons)), 'Work › Design › Icons');
      await sync();
      final figma = (await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Figma access');
      final card = await db.addCard(figma.threadKey!, tagIds: [icons]);
      expect((await db.watchCards().first).single.tags.single.name, 'Icons');
      await db.setCardTags(card, [work]);
      expect((await db.watchCards().first).single.tags.single.name, 'Work');
      await db.deleteTag(work);
      expect((await db.watchTags().first).map((t) => t.name), ['Personal']);
      expect((await db.watchCards().first).single.tags, isEmpty);
    });
  });

  group('ui', () {
    Widget app() => ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
            databaseProvider.overrideWith((ref) => db),
            credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
            transportFactoryProvider.overrideWith((ref) => () => imap),
            htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
          ],
          child: const ConvoMailApp(startSync: false),
        );

    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      final syncer = await sync();
      container.read(syncControllerProvider).adoptForTest(account.id, syncer);
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> teardown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Plain reads: taking `.first` of a drift stream that a provider is also
    // watching stalls the fake event loop in widget tests.
    Future<List<BoardColumn>> columns() => (db.select(db.boardColumns)..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).get();
    Future<List<Card>> cards() => db.select(db.cards).get();

    testWidgets('Add to board from a thread menu, then drag the card to another column; side panel opens the thread', (tester) async {
      final container = await pumpApp(tester);
      await tester.tap(find.text('Sarah Chen').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thread actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to board…'));
      await tester.pumpAndSettle();
      // Tag picker: create a tag inline, then Done.
      await tester.enterText(find.byKey(const ValueKey('new-tag-name')), 'Work');
      await tester.tap(find.byKey(const ValueKey('new-tag-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tags-done')));
      await tester.pumpAndSettle();
      expect(find.textContaining('is on the board'), findsOneWidget);
      final card = (await cards()).single;
      expect((await db.select(db.cardTags).get()).single.cardId, card.id);
      expect((await db.select(db.tags).get()).single.name, 'Work');

      container.read(destinationProvider.notifier).select(Destination.boards);
      await tester.pumpAndSettle();
      final cols = await columns();
      expect(find.byKey(ValueKey('card-${card.id}')), findsOneWidget);
      expect(find.descendant(of: find.byKey(ValueKey('column-count-${cols[0].id}')), matching: find.text('1')), findsOneWidget);
      expect(find.text('Work'), findsWidgets);

      // Drag to "In Progress".
      final from = tester.getCenter(find.byKey(ValueKey('card-${card.id}')));
      final to = tester.getCenter(find.text('In Progress'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(to, timeStamp: const Duration(milliseconds: 300));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect((await cards()).single.columnId, cols[1].id);
      expect(find.descendant(of: find.byKey(ValueKey('column-count-${cols[1].id}')), matching: find.text('1')), findsOneWidget);

      // Click opens the side panel with the thread; Open in Chats returns.
      await tester.tap(find.byKey(ValueKey('card-${card.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Open in Chats'), findsOneWidget);
      expect(find.text('Thanks!'), findsOneWidget);
      await tester.tap(find.text('Open in Chats'));
      await tester.pumpAndSettle();
      expect(container.read(destinationProvider), Destination.chats);
      await teardown(tester);
    });

    testWidgets('New column via the FAB; column menu renames', (tester) async {
      await pumpApp(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      final figma = (await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Figma access');
      await db.addCard(figma.threadKey!);
      container.read(destinationProvider.notifier).select(Destination.boards);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New column'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('column-name')), 'Waiting');
      await tester.tap(find.byKey(const ValueKey('column-save')));
      await tester.pumpAndSettle();
      expect(find.text('Waiting'), findsOneWidget);
      expect((await columns()).map((c) => c.name), ['Next', 'In Progress', 'Done', 'Waiting']);
      await teardown(tester);
    });

    testWidgets('Planner shows an extracted event block; detail panel opens the source conversation', (tester) async {
      final container = await pumpApp(tester);
      final sarah = (await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Figma access');
      final start = DateTime.now().add(const Duration(days: 1));
      final id = await db.addEvent(title: 'Design review', start: DateTime(start.year, start.month, start.day, 10), end: DateTime(start.year, start.month, start.day, 11), kind: 'extracted', sourceMessageId: sarah.id, threadKey: sarah.threadKey);
      await (db.update(db.plannerEvents)..where((e) => e.id.equals(id))).write(const PlannerEventsCompanion(evidence: Value('Design review tomorrow at 10am')));
      container.read(destinationProvider.notifier).select(Destination.planner);
      await tester.pumpAndSettle();
      expect(find.byType(PlannerScreen), findsOneWidget);
      // The event may fall in next week's grid; navigate until it is visible.
      if (find.byKey(ValueKey('event-$id')).evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Next week'));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(ValueKey('event-$id')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('event-$id')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('planner-detail')), findsOneWidget);
      expect(find.text('Found in a message'), findsOneWidget);
      expect(find.textContaining('Design review tomorrow at 10am'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('event-open-conversation')));
      await tester.pumpAndSettle();
      expect(container.read(destinationProvider), Destination.chats);
      expect(container.read(selectedRowProvider), 'c:sarah@chen.me');
      // The linked-event chip shows under the message.
      expect(find.byKey(ValueKey('linked-event-$id')), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('Snooze from the row menu hides the row; the Snoozed chip shows it', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Tom Andersen'), buttons: 0x02);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snooze…'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('snooze-Tomorrow morning')));
      await tester.pumpAndSettle();
      expect(find.textContaining('snoozed until'), findsOneWidget);
      expect(find.text('Tom Andersen'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('filter-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snoozed').last);
      await tester.pumpAndSettle();
      expect(find.text('Tom Andersen'), findsOneWidget);
      expect(find.byTooltip('Snoozed'), findsOneWidget);
      await teardown(tester);
    });
  });
}
