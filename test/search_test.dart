import 'package:convomail/app/conversation_state.dart';
import 'package:convomail/app/people_state.dart';
import 'package:convomail/app/search_state.dart';
import 'package:convomail/app/settings.dart';
import 'package:convomail/domain/html_sanitizer.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/search_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/conversation_pane.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/screens/chats/search_results_view.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Search (spec 4.6, plan M6): FTS5 index kept by triggers, query parsing,
/// filter-chip scoping, highlighting, in-conversation search, the results
/// view, and the 50k-message timing criterion.
void main() {
  group('queries', () {
    late AppDatabase db;
    late int accountId;
    late int folderId;
    var nextUid = 0;

    Future<int> seed({required String from, String fromName = '', required String subject, String? text, DateTime? date, bool fromMe = false, bool seen = true, bool flagged = false, bool attachments = false}) async {
      final id = await db.into(db.messages).insert(MessagesCompanion.insert(
            accountId: accountId,
            folderId: folderId,
            uid: ++nextUid,
            subject: Value(subject),
            fromAddress: Value(from),
            fromName: Value(fromName),
            fromContactKey: Value(fromMe ? 'me' : from),
            isFromMe: Value(fromMe),
            isSeen: Value(seen),
            isFlagged: Value(flagged),
            hasAttachments: Value(attachments),
            date: Value(date ?? DateTime(2026, 10, 1)),
            bodyText: Value(text),
            snippet: Value(text ?? ''),
          ));
      await db.into(db.messageRowAssignments).insert(MessageRowAssignmentsCompanion.insert(messageId: id, rowKey: fromMe ? 'c:someone@x.com' : 'c:$from'));
      return id;
    }

    setUp(() async {
      db = testDatabase();
      accountId = (await insertTestAccount(db)).id;
      folderId = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: accountId, path: 'INBOX', name: 'INBOX', role: const Value('inbox')));
    });

    tearDown(() => db.close());

    test('ftsQuery: words become prefix terms, quoted phrases stay phrases, punctuation is dropped', () {
      expect(SearchQueries.ftsQuery('figma access'), '"figma"* "access"*');
      expect(SearchQueries.ftsQuery('"next week" offer'), '"next week" "offer"*');
      expect(SearchQueries.ftsQuery('  (re): budget-2026 '), '"re"* "budget2026"*');
      expect(SearchQueries.ftsQuery('***'), isNull);
      expect(SearchQueries.searchTerms('"next week" Offer'), ['next week', 'Offer']);
    });

    test('index follows inserts, body updates, and deletes', () async {
      final id = await seed(from: 'sarah@x.com', fromName: 'Sarah Chen', subject: 'Figma access', text: null);
      expect(await db.searchIndexSize(), 1);
      expect((await db.searchMessages('figma')).single.message.id, id);
      expect(await db.searchMessages('dashboard'), isEmpty);

      await db.storeBody(id, const RemoteMessageBody(html: '<p>Can you share the <b>dashboard</b> file?</p>'));
      final hit = (await db.searchMessages('dashboard')).single;
      expect(hit.message.id, id);
      expect(hit.snippetMarked, contains('${hlStart}dashboard$hlEnd'));
      expect((await db.messageById(id))!.bodyText, 'Can you share the dashboard file?');

      await (db.delete(db.messages)..where((m) => m.id.equals(id))).go();
      expect(await db.searchIndexSize(), 0);
    });

    test('matches sender name and address; subject hits are marked; ranked by relevance', () async {
      final a = await seed(from: 'sarah@x.com', fromName: 'Sarah Chen', subject: 'Lunch?', text: 'Lunch on Friday?');
      final b = await seed(from: 'tom@x.com', fromName: 'Tom Andersen', subject: 'Sarah said hi', text: 'Passing along a note from Sarah.');
      final byName = await db.searchMessages('sarah');
      expect(byName.map((h) => h.message.id).toSet(), {a, b});
      final lunch = (await db.searchMessages('lunch')).single;
      expect(lunch.subjectMarked, '${hlStart}Lunch$hlEnd?');
      expect(lunch.rowKey, 'c:sarah@x.com');
      expect((await db.searchMessages('andersen')).single.message.id, b);
    });

    test('filter chips scope results per message', () async {
      final unread = await seed(from: 'a@x.com', subject: 'report draft', seen: false);
      final starred = await seed(from: 'b@x.com', subject: 'report final', flagged: true);
      final sent = await seed(from: 'me@example.com', subject: 'report sent', fromMe: true);
      final old = await seed(from: 'c@x.com', subject: 'report old', date: DateTime(2025, 1, 1));
      final withFile = await seed(from: 'd@x.com', subject: 'report attached', attachments: true);
      await seed(from: 'e@x.com', fromName: 'Known', subject: 'report known');
      await db.into(db.contacts).insert(ContactsCompanion.insert(key: 'e@x.com', displayName: const Value('Known'), inAddressBook: const Value(true)));

      Future<Set<int>> ids(PeopleFilter f) async => (await db.searchMessages('report', filter: f)).map((h) => h.message.id).toSet();
      expect(await ids(PeopleFilter.all), hasLength(6));
      expect(await ids(PeopleFilter.unread), {unread});
      expect(await ids(PeopleFilter.starred), {starred});
      expect(await ids(PeopleFilter.sent), {sent});
      expect(await ids(PeopleFilter.hasAttachments), {withFile});
      final week = await ids(PeopleFilter.thisWeek);
      expect(week, isNot(contains(old)));
      expect((await ids(PeopleFilter.fromContacts)).length, 1);
    });

    test('in-conversation search returns only that row\'s matching ids', () async {
      final s1 = await seed(from: 'sarah@x.com', subject: 'budget v1', text: 'first pass');
      await seed(from: 'sarah@x.com', subject: 'lunch', text: 'no budget talk');
      await seed(from: 'tom@x.com', subject: 'budget v2');
      final ids = await db.searchInRow('c:sarah@x.com', 'budget');
      expect(ids, hasLength(2));
      expect(ids, contains(s1));
      expect(await db.searchInRow('c:sarah@x.com', 'v2'), isEmpty);
    });

    test('junk/trash and deleted messages are excluded', () async {
      final trash = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: accountId, path: 'Trash', name: 'Trash', role: const Value('trash')));
      final id = await seed(from: 'x@x.com', subject: 'secret plans');
      expect(await db.searchMessages('secret'), hasLength(1));
      await (db.update(db.messages)..where((m) => m.id.equals(id))).write(MessagesCompanion(folderId: Value(trash)));
      expect(await db.searchMessages('secret'), isEmpty);
    });

    test('50k messages: a full-text query answers in under 200 ms', () async {
      const words = ['invoice', 'figma', 'budget', 'standup', 'contract', 'photos', 'flight', 'renewal', 'dashboard', 'lunch'];
      await db.batch((b) {
        for (var i = 0; i < 50000; i++) {
          final w = words[i % words.length];
          b.insert(
            db.messages,
            MessagesCompanion.insert(
              accountId: accountId,
              folderId: folderId,
              uid: i + 1,
              subject: Value('$w update $i'),
              fromAddress: Value('p${i % 5000}@x.com'),
              fromName: Value('Person ${i % 5000}'),
              fromContactKey: Value('p${i % 5000}@x.com'),
              date: Value(DateTime(2026, 1, 1).add(Duration(minutes: i))),
              bodyText: Value('About the ${words[(i * 7) % words.length]} for project ${i % 97}; the $w numbers look fine.'),
            ),
          );
        }
      });
      final rows = await (db.selectOnly(db.messages)..addColumns([db.messages.id, db.messages.fromContactKey])).get();
      await db.batch((b) {
        for (final r in rows) {
          b.insert(db.messageRowAssignments, MessageRowAssignmentsCompanion.insert(messageId: r.read(db.messages.id)!, rowKey: 'c:${r.read(db.messages.fromContactKey)}'));
        }
      });
      expect(await db.searchIndexSize(), 50000);
      final timings = <int>[];
      for (final q in ['figma', 'quarterly budget', 'Person 42', 'dash']) {
        final sw = Stopwatch()..start();
        final hits = await db.searchMessages(q);
        sw.stop();
        timings.add(sw.elapsedMilliseconds);
        if (q == 'figma') expect(hits, hasLength(100), reason: 'capped at the limit');
      }
      // ignore: avoid_print
      print('search over 50k: $timings ms');
      expect(timings.reduce((a, b) => a > b ? a : b), lessThan(200));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('sanitizer highlight', () {
    test('wraps matches in <mark>, case-insensitively, outside style blocks', () {
      const sanitizer = HtmlSanitizer();
      final out = sanitizer.sanitize('<style>.Budget{}</style><p>The BUDGET and the budget-2026 plan.</p>', highlight: ['budget']);
      expect(out.bodyInner, contains('<mark class="cm-hl">BUDGET</mark>'));
      expect(out.bodyInner, contains('<mark class="cm-hl">budget</mark>-2026'));
      expect(out.bodyInner, isNot(contains('<mark class="cm-hl">Budget</mark>{}')));
      expect(out.html, contains('mark.cm-hl'));
    });

    test('markTerms and markedSpan round-trip', () {
      final marked = markTerms('Figma access for figma', ['figma']);
      expect(marked, '\u0001Figma\u0002 access for \u0001figma\u0002');
      final span = markedSpan(marked, const TextStyle(), const TextStyle(fontWeight: FontWeight.bold));
      expect(span.children, hasLength(3));
      expect((span.children![1] as TextSpan).text, ' access for ');
      expect((span.children![2] as TextSpan).style!.fontWeight, FontWeight.bold);
    });
  });

  group('ui', () {
    late AppDatabase db;
    late FakeMailTransport imap;
    late Account account;

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

    setUp(() async {
      db = testDatabase();
      imap = FakeMailTransport();
      account = await insertTestAccount(db);
      final inbox = imap.folder('INBOX', role: FolderRole.inbox);
      inbox.add(
        RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah Chen'), to: const [RemoteAddress('me@example.com')], subject: 'Figma access', date: DateTime.now().subtract(const Duration(hours: 3))),
        body: const RemoteMessageBody(text: 'Can you add me to the Figma team?'),
      );
      inbox.add(
        RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah Chen'), to: const [RemoteAddress('me@example.com')], subject: 'Lunch Friday', date: DateTime.now().subtract(const Duration(hours: 2))),
        body: const RemoteMessageBody(text: 'Tacos?'),
      );
      inbox.add(
        RemoteMessageHeader(uid: 0, from: const RemoteAddress('tom@x.com', 'Tom Andersen'), to: const [RemoteAddress('me@example.com')], subject: 'Slides', date: DateTime.now().subtract(const Duration(days: 1))),
        body: const RemoteMessageBody(text: 'Figma link inside'),
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
      // Bodies: header sync only stores the snippet; fetch so bodies are indexed.
      for (final m in await (db.select(db.messages)).get()) {
        await syncer.fetchBody(m.id);
      }
      await db.refreshDirtyRows();
      await tester.pumpAndSettle();
    }

    Future<void> teardown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      await db.close();
    }

    testWidgets('typing in the search bar shows People and Message hits; opening a hit selects the row, expands, and highlights', (tester) async {
      await pumpApp(tester);
      await tester.enterText(find.byType(SearchBar).first, 'figma');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(SearchResultsView), findsOneWidget);
      expect(find.byKey(const ValueKey('include-feeds')), findsOneWidget);
      expect(find.textContaining('PEOPLE'), findsOneWidget, reason: 'Sarah matches by subject preview');
      expect(find.textContaining('MESSAGES · 2'), findsOneWidget, reason: 'Sarah subject + Tom body');
      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      final hits = container.read(searchHitsProvider).value!;
      final tomHit = hits.firstWhere((h) => h.message.fromAddress == 'tom@x.com');
      expect(tomHit.snippetMarked, contains('\u0001Figma\u0002'));

      await tester.tap(find.byKey(ValueKey('search-hit-${tomHit.message.id}')));
      await tester.pumpAndSettle();
      expect(container.read(selectedRowProvider), 'c:tom@x.com');
      expect(container.read(conversationSearchProvider), 'figma');
      expect(container.read(expandedMessagesProvider), contains(tomHit.message.id));
      expect(find.byKey(const ValueKey('conversation-search-field')), findsOneWidget);
      expect(find.text('1 match'), findsOneWidget);
      final rendered = container.read(renderedBodyProvider(tomHit.message.id)).value;
      expect(rendered?.html, contains('<mark class="cm-hl">Figma</mark>'));
      await teardown(tester);
    });

    testWidgets('filter chip scopes search; Include Feeds switch persists', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('filter-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unread').last);
      await tester.pumpAndSettle();
      // Mark Sarah's Figma message read; the unread-scoped search then finds only Tom.
      final sarahFigma = (await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Figma access');
      await (db.update(db.messages)..where((m) => m.id.equals(sarahFigma.id))).write(const MessagesCompanion(isSeen: Value(true)));
      await db.refreshDirtyRows();
      await tester.enterText(find.byType(SearchBar).first, 'figma');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.textContaining('MESSAGES · 1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('include-feeds')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      expect(container.read(settingsProvider).searchIncludeFeeds, isTrue);
      await teardown(tester);
    });

    testWidgets('in-conversation search filters cards, counts matches, Esc closes', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Sarah Chen').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('conversation-search-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('conversation-search-field')), 'tacos');
      await tester.pumpAndSettle();
      expect(find.text('1 match'), findsOneWidget);
      expect(find.descendant(of: find.byType(ConversationPane), matching: find.text('Lunch Friday', findRichText: true)), findsOneWidget);
      expect(find.descendant(of: find.byType(ConversationPane), matching: find.text('Figma access', findRichText: true)), findsNothing, reason: 'non-matching card hidden');

      await tester.enterText(find.byKey(const ValueKey('conversation-search-field')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matches here'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('conversation-search-field')), findsNothing);
      expect(find.descendant(of: find.byType(ConversationPane), matching: find.text('Figma access', findRichText: true)), findsOneWidget);
      await teardown(tester);
    });
  });
}
