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
/// inline expansion with the sanitized body and its pictures,
/// and the cross-participant thread overlay.
void main() {
  late AppDatabase db;
  late int sarahMsg2;

  Widget app({HtmlRendererBuilder? renderer}) => ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
          databaseProvider.overrideWith((ref) => db),
          credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
          transportFactoryProvider.overrideWith((ref) => () => FakeMailTransport()),
          htmlRendererProvider.overrideWith((ref) => renderer ?? (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
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
    // Yesterday afternoon, so the thread never straddles midnight whatever
    // time the tests run.
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day).subtract(const Duration(hours: 6));
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

  Future<void> openSarah(WidgetTester tester, {HtmlRendererBuilder? renderer}) async {
    tester.view.physicalSize = const Size(1500, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(renderer: renderer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sarah Chen').first);
    await tester.pumpAndSettle();
  }

  testWidgets('opening a chat shows its newest message in full; older ones open on a click as single lines', (tester) async {
    // A newer message in the Design review thread, so its card holds an
    // older message too.
    final folder = (await db.select(db.folders).get()).first;
    final day = (await db.messageById(sarahMsg2))!.date!;
    await seedMessage(accountId: folder.accountId, folderId: folder.id, uid: 20, from: 'sarah@x.com', fromName: 'Sarah Chen', subject: 'Re: Design review', date: day.add(const Duration(hours: 3)), messageId: '<z@x>', inReplyTo: '<a@x>', text: 'Newest words here');
    await db.rebuildMissingThreads();
    await openSarah(tester);

    expect(find.textContaining('Newest words here'), findsWidgets, reason: 'the newest message is open in full');
    final older = (await db.select(db.messages).get()).firstWhere((m) => m.id == sarahMsg2);
    expect(find.byKey(ValueKey('collapsed-message-${older.id}')), findsOneWidget, reason: 'an older one in the same card is one line');
    expect(find.textContaining('Final version attached'), findsNothing);

    await tester.tap(find.byKey(ValueKey('collapsed-message-${older.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Final version attached'), findsOneWidget);

    // Collapsing the card is not undone while the chat stays open.
    await tester.tap(find.descendant(of: find.byType(ConversationPane), matching: find.text('Re: Design review')).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Newest words here'), findsNothing);
    await teardown(tester);
  });

  testWidgets('clicking the sender line shows the sending address and every recipient with name and address', (tester) async {
    await openSarah(tester);
    final lunch = (await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Lunch?');
    expect(find.byKey(ValueKey('message-details-${lunch.id}')), findsNothing);
    await tester.tap(find.byKey(ValueKey('message-details-toggle-${lunch.id}')));
    await tester.pumpAndSettle();
    final details = find.byKey(ValueKey('message-details-${lunch.id}'));
    expect(details, findsOneWidget);
    String all() => tester.widgetList<SelectableText>(find.descendant(of: details, matching: find.byType(SelectableText))).map((t) => t.textSpan?.toPlainText() ?? t.data ?? '').join(' | ');
    expect(all(), contains('sarah@x.com'));
    expect(all(), contains('me@example.com'));
    expect(find.descendant(of: details, matching: find.text('To')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('message-details-toggle-${lunch.id}')));
    await tester.pumpAndSettle();
    expect(details, findsNothing);
    await teardown(tester);
  });

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

  testWidgets('mail from people shows its pictures at once, with no pictures notice', (tester) async {
    await openSarah(tester);
    await tester.tap(find.text('Re: Design review'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Final version attached'), findsOneWidget);
    expect(find.textContaining('The mockups are ready'), findsOneWidget, reason: "both of Sarah's messages in the thread expand");
    expect(find.textContaining('remote images'), findsNothing);
    expect(find.textContaining('Remote images'), findsNothing);
    expect(find.text('Load images'), findsNothing);
    expect(find.text('Image blocked'), findsNothing);

    // Expanding marks Sarah's unread messages read.
    final m2 = await db.messageById(sarahMsg2);
    expect(m2!.isSeen, isTrue);

    // Recorded as loaded, for the Privacy page.
    final events = await db.select(db.trackerEvents).get();
    expect(events.where((e) => e.messageId == sarahMsg2).map((e) => e.host).toSet(), {'cdn.figma.example', 'open.mailtrack.io'});
    expect(events.every((e) => !e.blocked), isTrue);
    await teardown(tester);
  });

  test('Feeds mail still keeps its pictures blocked until asked', () async {
    Future<bool> loaded() async {
      final container = ProviderContainer(overrides: [
        settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
        databaseProvider.overrideWith((ref) => db),
        credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
      ]);
      final sub = container.listen(renderedBodyProvider(sarahMsg2), (_, _) {});
      try {
        return (await container.read(renderedBodyProvider(sarahMsg2).future)).sanitized.allowedRemote;
      } finally {
        sub.close();
        container.dispose();
      }
    }

    expect(await loaded(), isTrue, reason: 'from a person: shown');
    await (db.update(db.messages)..where((m) => m.id.equals(sarahMsg2))).write(const MessagesCompanion(classification: Value('feeds')));
    expect(await loaded(), isFalse, reason: 'a feed: blocked');
    await db.setImagesAllowed(sarahMsg2, true);
    expect(await loaded(), isTrue, reason: 'a feed after Load images');
  });

  testWidgets('"N more in this thread" opens the whole thread: every participant, including my reply', (tester) async {
    // Tom joins the thread; his message lives in his own chat, not Sarah's.
    final folder = (await db.select(db.folders).get()).first;
    final base = (await db.select(db.messages).get()).firstWhere((m) => m.messageId == '<a@x>').date!;
    await seedMessage(accountId: folder.accountId, folderId: folder.id, uid: 9, from: 'tom@x.com', fromName: 'Tom', subject: 'Re: Design review', date: base.add(const Duration(minutes: 30)), messageId: '<t@x>', inReplyTo: '<a@x>', text: 'Count me in');
    await db.rebuildMissingThreads();
    await openSarah(tester);
    expect(find.textContaining('more in this thread'), findsNothing, reason: 'collapsed');
    await tester.tap(find.descendant(of: find.byType(ConversationPane), matching: find.text('Re: Design review')));
    await tester.pumpAndSettle();
    expect(find.text('1 more in this thread'), findsWidgets, reason: "only Tom's message is outside Sarah's chat");
    await tester.tap(find.textContaining('more in this thread').first);
    await tester.pumpAndSettle();

    expect(find.byType(ThreadViewPanel), findsOneWidget);
    expect(find.descendant(of: find.byType(ThreadViewPanel), matching: find.textContaining('Count me in')), findsWidgets);
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

  testWidgets("a reply shows only what was written that time; 'Show earlier mail' brings back the copy", (tester) async {
    final folder = (await db.select(db.folders).get()).first;
    final day = (await db.messageById(sarahMsg2))!.date!;
    final id = await seedMessage(
      accountId: folder.accountId,
      folderId: folder.id,
      uid: 21,
      from: 'sarah@x.com',
      fromName: 'Sarah Chen',
      subject: 'Re: Design review',
      date: day.add(const Duration(hours: 4)),
      messageId: '<q@x>',
      inReplyTo: '<c@x>',
      html: '<div>Newest words here</div><div class="gmail_quote gmail_quote_container"><div class="gmail_attr">On Mon, Me wrote:</div><blockquote class="gmail_quote">Copied older words</blockquote></div>',
    );
    await db.rebuildMissingThreads();
    await openSarah(tester);
    expect(find.textContaining('Newest words here', findRichText: true), findsWidgets);
    expect(find.textContaining('Copied older words', findRichText: true), findsNothing);

    await tester.tap(find.byKey(ValueKey('earlier-mail-$id')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Copied older words', findRichText: true), findsWidgets);
    expect(find.text('Hide earlier mail'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('earlier-mail-$id')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Copied older words', findRichText: true), findsNothing);
    await teardown(tester);
  });

  testWidgets('a plain-text message renders escaped, and opening the chat reads its newest message', (tester) async {
    expect((await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Lunch?').isSeen, isFalse);
    await openSarah(tester);
    expect(find.textContaining('Free at noon?'), findsWidgets, reason: 'Lunch? is the newest, so it opens with the chat');
    expect((await db.select(db.messages).get()).firstWhere((m) => m.subject == 'Lunch?').isSeen, isTrue);
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(selectedRowProvider), 'c:sarah@x.com');
    await teardown(tester);
  });

  testWidgets('an open email is kept, not built again, when the chat redraws', (tester) async {
    // Each time a card was built from scratch its email loaded again: on
    // screen, a flash.
    await openSarah(tester);
    await tester.tap(find.text('Re: Design review'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Final version attached'), findsOneWidget);
    final card = find.byKey(ValueKey('message-card-$sarahMsg2'));
    final before = tester.element(card);

    // Starred, and another message changing: both redraw the chat.
    await (db.update(db.messages)..where((m) => m.id.equals(sarahMsg2))).write(const MessagesCompanion(isFlagged: Value(true)));
    await tester.pumpAndSettle();
    await (db.update(db.messages)..where((m) => m.subject.equals('Lunch?'))).write(const MessagesCompanion(isSeen: Value(false)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Final version attached'), findsOneWidget);
    expect(identical(tester.element(card), before), isTrue, reason: 'the same card, kept');
    await teardown(tester);
  });

  test('each page load is marked so older pages are ignored', () {
    expect(tagMailPage('<!DOCTYPE html><html><head></head><body>Hi</body></html>', '7'), '<!DOCTYPE html><html data-cm="7"><head></head><body>Hi</body></html>');
    expect(tagMailPage('<p>Hi</p>', '8'), contains('<html data-cm="8">'));
  });
}
