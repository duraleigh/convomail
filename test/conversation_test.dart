import 'package:convomail/app/conversation_state.dart';
import 'package:convomail/app/people_state.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/store/thread_queries.dart';
import 'package:convomail/ui/screens/chats/conversation_pane.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/screens/chats/thread_view_panel.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Conversation view through the UI (spec 4.3, 4.13, 4.20): thread cards,
/// inline expansion with the sanitized body, privacy strip and Load images,
/// and the cross-participant thread overlay.
void main() {
  late AppDatabase db;
  late int sarahMsg2;

  Widget app() => ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
          databaseProvider.overrideWith((ref) => db),
          credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
          transportFactoryProvider.overrideWith((ref) => () => FakeMailTransport()),
          htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
        ],
        child: const ConvoMailApp(startSync: false),
      );

  Future<int> seedMessage({
    required int accountId,
    required int folderId,
    required int uid,
    required String from,
    required String fromName,
    required String subject,
    required DateTime date,
    String? messageId,
    String? inReplyTo,
    String? html,
    String? text,
    bool fromMe = false,
    List<String> to = const ['me@example.com'],
  }) async {
    final id = await db.into(db.messages).insert(MessagesCompanion.insert(
          accountId: accountId,
          folderId: folderId,
          uid: uid,
          messageId: Value(messageId),
          inReplyTo: Value(inReplyTo),
          referencesHeader: Value(inReplyTo),
          subject: Value(subject),
          fromAddress: Value(from),
          fromName: Value(fromName),
          fromContactKey: Value(fromMe ? 'me' : from),
          isFromMe: Value(fromMe),
          date: Value(date),
          bodyHtml: Value(html),
          bodyText: Value(text),
          bodyFetchedAt: Value(html == null && text == null ? null : date),
        ));
    await db.into(db.messageParticipants).insert(MessageParticipantsCompanion.insert(messageId: id, role: 'from', address: from, name: Value(fromName), contactKey: fromMe ? 'me' : from, isMe: Value(fromMe)));
    for (final t in to) {
      final isMe = t == 'me@example.com';
      await db.into(db.messageParticipants).insert(MessageParticipantsCompanion.insert(messageId: id, role: 'to', address: t, contactKey: isMe ? 'me' : t, isMe: Value(isMe)));
    }
    // Filing: sent → each recipient; received → sender.
    final rowKeys = fromMe ? to.where((t) => t != 'me@example.com').map((t) => 'c:$t') : ['c:$from'];
    for (final k in rowKeys) {
      await db.into(db.messageRowAssignments).insert(MessageRowAssignmentsCompanion.insert(messageId: id, rowKey: k));
    }
    if (!fromMe) await db.into(db.contacts).insert(ContactsCompanion.insert(key: from, displayName: Value(fromName)), mode: InsertMode.insertOrIgnore);
    return id;
  }

  setUp(() async {
    db = AppDatabase.memory();
    final account = await insertTestAccount(db);
    final inbox = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: account.id, path: 'INBOX', name: 'INBOX', role: const Value('inbox')));
    final now = DateTime.now();
    // A thread: Sarah → me, I reply, Sarah replies (with a tracking pixel and a remote image).
    await seedMessage(accountId: account.id, folderId: inbox, uid: 1, from: 'sarah@x.com', fromName: 'Sarah Chen', subject: 'Design review', date: now.subtract(const Duration(hours: 5)), messageId: '<a@x>', html: '<p>The mockups are ready for review.</p>');
    await seedMessage(accountId: account.id, folderId: inbox, uid: 2, from: 'me@example.com', fromName: 'Me', subject: 'Re: Design review', date: now.subtract(const Duration(hours: 4)), messageId: '<b@x>', inReplyTo: '<a@x>', text: 'Looks great, shipping it.', fromMe: true, to: ['sarah@x.com']);
    sarahMsg2 = await seedMessage(accountId: account.id, folderId: inbox, uid: 3, from: 'sarah@x.com', fromName: 'Sarah Chen', subject: 'Re: Design review', date: now.subtract(const Duration(hours: 3)), messageId: '<c@x>', inReplyTo: '<b@x>', html: '<p>Thanks! Final version attached.</p><img src="https://cdn.figma.example/final.png" width="400"><img src="https://open.mailtrack.io/p.gif" width="1" height="1">');
    // An unrelated single message from Sarah.
    await seedMessage(accountId: account.id, folderId: inbox, uid: 4, from: 'sarah@x.com', fromName: 'Sarah Chen', subject: 'Lunch?', date: now.subtract(const Duration(hours: 1)), messageId: '<d@x>', text: 'Free at noon?');
    await db.rebuildMissingThreads();
  });

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
    await db.close();
  }

  Future<void> openSarah(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1500, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sarah Chen').first);
    await tester.pumpAndSettle();
  }

  testWidgets('threads are grouped: two cards for Sarah, count pill on the 3-message thread', (tester) async {
    await openSarah(tester);
    // Sarah's row holds her 2 thread messages + Lunch; the thread has 3 across participants.
    final pane = find.byType(ConversationPane);
    expect(find.descendant(of: pane, matching: find.text('Re: Design review')), findsOneWidget, reason: 'one collapsed card for the thread (newest subject)');
    expect(find.descendant(of: pane, matching: find.text('Lunch?')), findsOneWidget);
    expect(find.descendant(of: pane, matching: find.text('3')), findsOneWidget, reason: 'thread count pill');
    final threadKey = (await db.select(db.messages).get()).firstWhere((m) => m.id == sarahMsg2).threadKey;
    expect(threadKey, '<a@x>');
    await teardown(tester);
  });

  testWidgets('expanding a card shows the sanitized body, privacy strip, and Load images works', (tester) async {
    await openSarah(tester);
    await tester.tap(find.text('Re: Design review'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Final version attached'), findsOneWidget);
    expect(find.textContaining('The mockups are ready'), findsOneWidget, reason: 'both of Sarah\'s messages in the thread expand');
    expect(find.textContaining('remote images blocked'), findsOneWidget);
    expect(find.textContaining('1 tracker'), findsOneWidget);

    // Expanding marks Sarah's unread messages read.
    final m2 = await db.messageById(sarahMsg2);
    expect(m2!.isSeen, isTrue);

    // Tracker events recorded as blocked.
    var events = await db.select(db.trackerEvents).get();
    expect(events.where((e) => e.messageId == sarahMsg2).map((e) => e.host).toSet(), {'cdn.figma.example', 'open.mailtrack.io'});
    expect(events.every((e) => e.blocked), isTrue);

    await tester.tap(find.text('Blocked hosts'));
    await tester.pumpAndSettle();
    expect(find.text('open.mailtrack.io'), findsOneWidget);

    await tester.tap(find.text('Load images'));
    await tester.pumpAndSettle();
    expect((await db.messageById(sarahMsg2))!.imagesAllowed, isTrue);
    expect(find.textContaining('Remote images loaded'), findsOneWidget);
    events = await db.select(db.trackerEvents).get();
    expect(events.where((e) => e.messageId == sarahMsg2).every((e) => !e.blocked), isTrue);

    final stats = await db.privacyStats();
    expect(stats.sendersWhoKnowYouRead, 1);
    await teardown(tester);
  });

  testWidgets('View thread opens the overlay with every participant, including my reply', (tester) async {
    await openSarah(tester);
    await tester.tap(find.descendant(of: find.byType(ConversationPane), matching: find.text('Re: Design review')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View thread · 3').first);
    await tester.pumpAndSettle();

    expect(find.byType(ThreadViewPanel), findsOneWidget);
    expect(find.descendant(of: find.byType(ThreadViewPanel), matching: find.textContaining('Looks great, shipping it')), findsWidgets, reason: 'my reply is visible in the thread view');
    expect(find.descendant(of: find.byType(ThreadViewPanel), matching: find.textContaining('The mockups are ready')), findsWidgets);
    expect(find.text('You'), findsWidgets);
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(openThreadProvider), '<a@x>');

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ThreadViewPanel), findsNothing);
    await teardown(tester);
  });

  testWidgets('a plain-text message renders escaped and marks read on expand', (tester) async {
    await openSarah(tester);
    expect((await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Lunch?').isSeen, isFalse);
    await tester.tap(find.descendant(of: find.byType(ConversationPane), matching: find.text('Lunch?')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Free at noon?'), findsWidgets);
    expect((await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Lunch?').isSeen, isTrue);
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(selectedRowProvider), 'c:sarah@x.com');
    await teardown(tester);
  });
}
