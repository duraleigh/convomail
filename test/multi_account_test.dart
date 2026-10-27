import 'package:convomail/app/account_scope.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart' hide Tags;
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/search_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:convomail/store/thread_queries.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/screens/chats/message_card.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Multi-account (spec 4.14, plan M11): two accounts synced from two fake
/// servers. The same contact writing to both addresses is one row, a
/// thread spanning both accounts is one thread, the per-account view
/// scopes rows and messages, and account markers appear in the unified
/// view.
void main() {
  late AppDatabase db;
  late FakeMailTransport workImap;
  late FakeMailTransport homeImap;
  late Account work;
  late Account home;

  setUp(() async {
    db = testDatabase();
    workImap = FakeMailTransport();
    homeImap = FakeMailTransport();
    work = await insertTestAccount(db, email: 'clay@work.com');
    home = await insertTestAccount(db, email: 'clay@home.net');
    for (final t in [workImap, homeImap]) {
      t.folder('INBOX', role: FolderRole.inbox);
      t.folder('Sent', role: FolderRole.sent);
    }
    const workMe = RemoteAddress('clay@work.com');
    const homeMe = RemoteAddress('clay@home.net');
    const sarah = RemoteAddress('sarah@chen.me', 'Sarah Chen');
    // Sarah writes to the work address, then replies land on the home address.
    workImap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: sarah, to: const [workMe], subject: 'Project kickoff', messageId: '<k1@chen.me>', date: DateTime.now().subtract(const Duration(days: 2))));
    homeImap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: homeMe, to: const [sarah], subject: 'Re: Project kickoff', messageId: '<k2@home.net>', inReplyTo: '<k1@chen.me>', date: DateTime.now().subtract(const Duration(days: 1))));
    homeImap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: sarah, to: const [homeMe], subject: 'Re: Project kickoff', messageId: '<k3@chen.me>', inReplyTo: '<k2@home.net>', date: DateTime.now().subtract(const Duration(hours: 5))));
    // A work-only sender and a home-only sender.
    workImap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('boss@work.com', 'The Boss'), to: const [workMe], subject: 'Budget', date: DateTime.now().subtract(const Duration(hours: 3))));
    homeImap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('mom@family.org', 'Mom'), to: const [homeMe], subject: 'Sunday?', date: DateTime.now().subtract(const Duration(hours: 1))));
  });

  tearDown(() => db.close());

  Future<(AccountSyncer, AccountSyncer)> syncBoth() async {
    final w = AccountSyncer(db: db, transport: workImap, account: work, credentials: () async => const MailCredentials(username: 'w', password: 'secret'));
    final h = AccountSyncer(db: db, transport: homeImap, account: home, credentials: () async => const MailCredentials(username: 'h', password: 'secret'));
    await w.syncOnce();
    await h.syncOnce();
    await db.refreshDirtyRows();
    return (w, h);
  }

  group('queries', () {
    test('one contact across two accounts is one row; the cross-account thread is one thread', () async {
      await syncBoth();
      final rows = await db.peopleRows();
      final sarahRows = rows.where((r) => r.title == 'Sarah Chen').toList();
      expect(sarahRows, hasLength(1), reason: 'merged across accounts');
      expect(sarahRows.single.accountIds, {work.id, home.id});
      expect(sarahRows.single.total, 3, reason: 'two received + my reply from the other account');
      final msgs = await db.messagesForRow('c:sarah@chen.me');
      expect(msgs.map((m) => m.threadKey).toSet(), hasLength(1), reason: 'Message-IDs join the thread across accounts');
      expect(await db.threadMessages(msgs.first.threadKey!), hasLength(3));
      expect(rows.firstWhere((r) => r.title == 'The Boss').accountIds, {work.id});
    });

    test('the per-account view scopes rows, messages, and search', () async {
      await syncBoth();
      final workRows = await db.peopleRows(accountId: work.id);
      expect(workRows.map((r) => r.title).toSet(), {'Sarah Chen', 'The Boss'});
      expect(workRows.firstWhere((r) => r.title == 'Sarah Chen').total, 1);
      final homeRows = await db.peopleRows(accountId: home.id);
      expect(homeRows.map((r) => r.title).toSet(), {'Sarah Chen', 'Mom'});
      expect(homeRows.firstWhere((r) => r.title == 'Sarah Chen').total, 2);
      expect(await db.watchMessagesForRow('c:sarah@chen.me', accountId: work.id).first, hasLength(1));
      expect(await db.searchMessages('kickoff', accountId: work.id), hasLength(1));
      expect(await db.searchMessages('kickoff'), hasLength(3));
    });

    test('accounts can be reordered and paused', () async {
      expect((await db.allAccounts()).map((a) => a.email), ['clay@work.com', 'clay@home.net']);
      await db.moveAccount(home.id, -1);
      expect((await db.allAccounts()).map((a) => a.email), ['clay@home.net', 'clay@work.com']);
      await db.moveAccount(home.id, -1);
      expect((await db.allAccounts()).first.email, 'clay@home.net', reason: 'already first');
      await db.setAccountEnabled(work.id, false);
      expect((await db.accountById(work.id))!.enabled, isFalse);
    });
  });

  group('ui', () {
    Widget app() => ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
            databaseProvider.overrideWith((ref) => db),
            credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
            transportFactoryProvider.overrideWith((ref) => () => workImap),
            htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
          ],
          child: const ConvoMailApp(startSync: false),
        );

    testWidgets('unified view shows account dots; the switcher scopes the list and the headline', (tester) async {
      tester.view.physicalSize = const Size(1500, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      final (w, h) = await syncBoth();
      container.read(syncControllerProvider).adoptForTest(work.id, w);
      container.read(syncControllerProvider).adoptForTest(home.id, h);
      await tester.pumpAndSettle();

      expect(find.text('Sarah Chen'), findsOneWidget);
      expect(find.byKey(ValueKey('account-dot-c:sarah@chen.me-${work.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('account-dot-c:sarah@chen.me-${home.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('account-dot-c:boss@work.com-${home.id}')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('account-switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('clay@work.com').last);
      await tester.pumpAndSettle();
      expect(container.read(accountScopeProvider), work.id);
      expect(find.byKey(const ValueKey('scope-chip')), findsOneWidget);
      expect(find.text('The Boss'), findsOneWidget);
      expect(find.text('Mom'), findsNothing);
      expect(find.byKey(ValueKey('account-dot-c:sarah@chen.me-${work.id}')), findsNothing, reason: 'no dots in a scoped view');

      // Sarah's row in work scope shows only the work message.
      await tester.tap(find.text('Sarah Chen'));
      await tester.pumpAndSettle();
      // The row preview and the thread card both carry the subject; expand the card.
      await tester.tap(find.text('Project kickoff').last);
      await tester.pumpAndSettle();
      expect(find.byType(MessageCard), findsOneWidget, reason: 'only the work-account message in work scope');
      expect(find.textContaining('via clay@work.com'), findsOneWidget);

      // Clear the scope from the chip.
      await tester.tap(find.byTooltip('Show all accounts'));
      await tester.pumpAndSettle();
      expect(container.read(accountScopeProvider), isNull);
      expect(find.text('Mom'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  test('identity resolution treats every account address as me', () async {
    await syncBoth();
    final resolver = await db.loadIdentityResolver();
    expect(resolver.resolve('clay@work.com').isMe, isTrue);
    expect(resolver.resolve('Clay@Home.net').isMe, isTrue);
    final reply = (await db.select(db.messages).get()).firstWhere((m) => m.messageId == '<k2@home.net>');
    expect(reply.isFromMe, isTrue);
    expect(reply.accountId, home.id);
    // Contact row keyed once, regardless of which account saw it first.
    final contacts = await (db.select(db.contacts)..where((c) => c.key.equals('sarah@chen.me'))).get();
    expect(contacts, hasLength(1));
    await (db.update(db.contacts)..where((c) => c.key.equals('sarah@chen.me'))).write(const ContactsCompanion(displayName: Value('Sarah C.')));
    expect((await db.peopleRows()).firstWhere((r) => r.rowKey == 'c:sarah@chen.me').title, 'Sarah C.');
  });
}
