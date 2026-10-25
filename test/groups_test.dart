import 'package:convomail/app/destinations.dart';
import 'package:convomail/app/settings.dart';
import 'package:convomail/app/settings_navigation.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/platform/mailto_registration.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/group_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:convomail/ui/widgets/tonal_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// User-defined groups (spec 4.19, plan M7) against a seeded mailbox: the
/// Simon / Joann / Sarah examples, exclusivity, re-filing on create / edit /
/// delete, validation, the Settings UI, and mailto: parsing.
void main() {
  const me = RemoteAddress('me@example.com');
  const simon = RemoteAddress('simon@x.com', 'Simon Park');
  const joann = RemoteAddress('joann@x.com', 'Joann Lee');
  const sarah = RemoteAddress('sarah@x.com', 'Sarah Chen');

  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;

  /// Seeds the spec's scenarios (uids returned in order):
  /// 1 Simon → me, Joann            (group when {Simon, Joann} exists)
  /// 2 Joann → me, Simon, Sarah     (never a group match)
  /// 3 me → Simon, Joann            (sent; group row only)
  /// 4 Simon → me                   (sender-only)
  /// 5 Sarah → me, cc Joann         (no group)
  Future<void> seed() async {
    final inbox = imap.folder('INBOX', role: FolderRole.inbox);
    final sent = imap.folder('Sent', role: FolderRole.sent);
    var t = DateTime(2026, 10, 1, 9);
    DateTime next() => t = t.add(const Duration(hours: 1));
    inbox.add(RemoteMessageHeader(uid: 0, from: simon, to: const [me, joann], subject: 'Trip dates', date: next()));
    inbox.add(RemoteMessageHeader(uid: 0, from: joann, to: const [me, simon, sarah], subject: 'Adding Sarah', date: next()));
    sent.add(RemoteMessageHeader(uid: 0, from: me, to: const [simon, joann], subject: 'Re: Trip dates', date: next()));
    inbox.add(RemoteMessageHeader(uid: 0, from: simon, to: const [me], subject: 'Just you', date: next()));
    inbox.add(RemoteMessageHeader(uid: 0, from: sarah, to: const [me], cc: const [joann], subject: 'Lunch', date: next()));
  }

  Future<AccountSyncer> sync() async {
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
    return syncer;
  }

  Future<Map<String, List<String>>> rowsBySubject() async {
    final rows = await db.peopleRows();
    final out = <String, List<String>>{};
    for (final r in rows) {
      for (final m in await db.messagesForRow(r.rowKey)) {
        out.putIfAbsent(m.subject, () => []).add(r.title);
      }
    }
    return out;
  }

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    account = await insertTestAccount(db);
    await seed();
  });

  tearDown(() => db.close());

  group('filing', () {
    test('without a group everything files by sender; my message files under each recipient', () async {
      await sync();
      final by = await rowsBySubject();
      expect(by['Trip dates'], ['Simon Park']);
      expect(by['Adding Sarah'], ['Joann Lee']);
      expect(by['Re: Trip dates']!.toSet(), {'Simon Park', 'Joann Lee'});
      expect(by['Just you'], ['Simon Park']);
      expect(by['Lunch'], ['Sarah Chen']);
    });

    test('creating "Simon & Joann" re-files cached mail: exact matches move to the group row only', () async {
      await sync();
      final id = await db.createGroup('Simon & Joann', ['simon@x.com', 'joann@x.com']);
      final by = await rowsBySubject();
      expect(by['Trip dates'], ['Simon & Joann'], reason: 'Simon → me + Joann is exactly the group');
      expect(by['Re: Trip dates'], ['Simon & Joann'], reason: 'my mail to exactly the members files in the group only');
      expect(by['Adding Sarah'], ['Joann Lee'], reason: 'an extra participant means no match');
      expect(by['Just you'], ['Simon Park'], reason: 'a missing member means no match');
      expect(by['Lunch'], ['Sarah Chen']);

      final rows = await db.peopleRows();
      final groupRow = rows.firstWhere((r) => r.rowKey == 'g:$id');
      expect(groupRow.isGroup, isTrue);
      expect(groupRow.title, 'Simon & Joann');
      expect(groupRow.members.map((m) => m.$2).toSet(), {'Simon Park', 'Joann Lee'});
      expect(groupRow.total, 2);
      expect((await db.watchGroups().first).single.filedCount, 2);
    });

    test('a group that exists before sync files new mail as it arrives', () async {
      await db.createGroup('Simon & Joann', ['simon@x.com', 'joann@x.com']);
      await sync();
      final by = await rowsBySubject();
      expect(by['Trip dates'], ['Simon & Joann']);
      expect(by['Just you'], ['Simon Park']);
    });

    test('editing members re-files: {Joann, Sarah} matches the CC case instead', () async {
      await sync();
      final id = await db.createGroup('Pair', ['simon@x.com', 'joann@x.com']);
      expect((await rowsBySubject())['Trip dates'], ['Pair']);
      await db.setGroupMembers(id, ['joann@x.com', 'sarah@x.com']);
      final by = await rowsBySubject();
      expect(by['Trip dates'], ['Simon Park'], reason: 'no longer matches, back to sender');
      expect(by['Lunch'], ['Pair'], reason: 'Sarah → me, cc Joann is exactly {Sarah, Joann}');
      expect(by['Re: Trip dates']!.toSet(), {'Simon Park', 'Joann Lee'});
    });

    test('deleting the group returns its messages to sender-only filing and removes the row', () async {
      await sync();
      final id = await db.createGroup('Simon & Joann', ['simon@x.com', 'joann@x.com']);
      await db.setPinned('g:$id', true);
      await db.deleteGroup(id);
      final by = await rowsBySubject();
      expect(by['Trip dates'], ['Simon Park']);
      expect(by['Re: Trip dates']!.toSet(), {'Simon Park', 'Joann Lee'});
      expect((await db.peopleRows()).where((r) => r.isGroup), isEmpty);
      expect(await db.rowPref('g:$id'), isNull);
      expect(await db.watchGroups().first, isEmpty);
    });

    test('validation: name, at least two members, never the user', () async {
      await sync();
      expect(() => db.createGroup('   ', ['simon@x.com', 'joann@x.com']), throwsA(isA<GroupValidationException>()));
      expect(() => db.createGroup('Solo', ['simon@x.com']), throwsA(isA<GroupValidationException>()));
      expect(() => db.createGroup('With me', ['simon@x.com', 'me@example.com']), throwsA(isA<GroupValidationException>()));
      expect(() => db.createGroup('Dup', ['simon@x.com', 'Simon@X.com']), throwsA(isA<GroupValidationException>()), reason: 'same person twice is one member');
    });

    test('three-member group: all three must be present, in any role', () async {
      imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: sarah, to: const [me, simon], cc: const [joann], subject: 'All three', date: DateTime(2026, 10, 2)));
      await sync();
      await db.createGroup('Trio', ['simon@x.com', 'joann@x.com', 'sarah@x.com']);
      final by = await rowsBySubject();
      expect(by['All three'], ['Trio']);
      expect(by['Adding Sarah'], ['Trio'], reason: 'Joann → me, Simon, Sarah is also exactly the trio');
      expect(by['Trip dates'], ['Simon Park']);
    });
  });

  group('settings ui', () {
    Widget app() => ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
            databaseProvider.overrideWith((ref) => db),
            credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
            transportFactoryProvider.overrideWith((ref) => () => imap),
            htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
            mailtoRegistrationProvider.overrideWith((ref) => const NoopMailtoRegistration()),
          ],
          child: const ConvoMailApp(startSync: false),
        );

    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1500, 950);
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

    testWidgets('create a group in Settings → People Groups; it shows as a stacked-avatar row in Chats', (tester) async {
      final container = await pumpApp(tester);
      container.read(settingsSectionProvider.notifier).select(SettingsSection.peopleGroups);
      container.read(destinationProvider.notifier).select(Destination.settings);
      await tester.pumpAndSettle();
      expect(find.text('No groups yet'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('new-group')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('group-name')), 'Simon & Joann');
      await tester.enterText(find.byKey(const ValueKey('group-member-picker')), 'sim');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Simon Park'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('member-simon@x.com')), findsOneWidget);

      // Only one member: validation message, nothing created.
      await tester.tap(find.byKey(const ValueKey('group-save')));
      await tester.pumpAndSettle();
      expect(find.text('A group needs at least two people.'), findsOneWidget);
      expect(await db.watchGroups().first, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('group-member-picker')), 'joa');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Joann Lee'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('group-save')));
      await tester.pumpAndSettle();

      final groups = await db.watchGroups().first;
      expect(groups.single.name, 'Simon & Joann');
      expect(groups.single.filedCount, 2);
      expect(find.textContaining('2 conversations filed'), findsOneWidget);
      expect(find.byType(StackedAvatars), findsWidgets);

      // The group row appears in Chats with the stacked avatar.
      container.read(destinationProvider.notifier).select(Destination.chats);
      await tester.pumpAndSettle();
      expect(find.text('Simon & Joann'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('notifications settings persist; default-app page renders', (tester) async {
      final container = await pumpApp(tester);
      container.read(settingsSectionProvider.notifier).select(SettingsSection.notifications);
      container.read(destinationProvider.notifier).select(Destination.settings);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('badge-include-feeds')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('notify-account-${account.id}')));
      await tester.pumpAndSettle();
      final settings = container.read(settingsProvider);
      expect(settings.badgeIncludeFeeds, isTrue);
      expect(settings.mutedAccounts, {account.id});

      container.read(settingsSectionProvider.notifier).select(SettingsSection.defaultApp);
      await tester.pumpAndSettle();
      expect(find.text('Not registered yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('mailto-register')), findsOneWidget);
      await teardown(tester);
    });
  });

  group('mailto', () {
    test('parses addresses, cc, subject, and body', () {
      final l = MailtoLink.parse('mailto:a@x.com,b@x.com?subject=Hello%20there&cc=c@x.com&body=Line1%0ALine2')!;
      expect(l.to, ['a@x.com', 'b@x.com']);
      expect(l.cc, ['c@x.com']);
      expect(l.subject, 'Hello there');
      expect(l.body, 'Line1\nLine2');
      expect(MailtoLink.parse('MAILTO:?to=z@x.com')!.to, ['z@x.com']);
      expect(MailtoLink.parse('https://x.com'), isNull);
    });

    test('a mailto: launch argument opens the composer prefilled', () {
      final args = StartupArgs.parse(['mailto:sarah@x.com?subject=Hi']);
      expect(args.destination, Destination.chats);
      expect(args.overrides, isNotEmpty);
    });
  });
}
