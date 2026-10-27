import 'dart:io';

import 'package:convomail/app/app_log.dart';
import 'package:convomail/app/onboarding.dart';
import 'package:convomail/app/update_check.dart';
import 'package:convomail/app/version.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart' hide Tags;
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Plan M12: local-only log, version/update check, first-run onboarding,
/// and screen-reader labels.
void main() {
  group('AppLog', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('convomail-log-test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('writes dated files, prunes old ones, reports size, clears', () async {
      var now = DateTime(2026, 10, 26, 9);
      final log = AppLog(Directory(p.join(tmp.path, 'logs')), keepDays: 7, clock: () => now);
      await log.init();
      // Pretend-old files, one inside and one outside the window.
      log.fileFor(DateTime(2026, 10, 1)).writeAsStringSync('old\n');
      log.fileFor(DateTime(2026, 10, 22)).writeAsStringSync('recent\n');
      File(p.join(log.dir.path, 'unrelated.txt')).writeAsStringSync('keep me');
      log.error('boom', StateError('bad'), StackTrace.current);
      log.info('hello');
      await log.prune();

      expect(log.fileFor(DateTime(2026, 10, 1)).existsSync(), isFalse, reason: 'older than 7 days');
      expect(log.fileFor(DateTime(2026, 10, 22)).existsSync(), isTrue);
      expect(File(p.join(log.dir.path, 'unrelated.txt')).existsSync(), isTrue, reason: 'only our own files are pruned');
      final today = log.todayFile.readAsStringSync();
      expect(today, contains('ERROR boom | Bad state: bad'));
      expect(today, contains('INFO hello'));
      expect(today, contains('polish_test.dart'), reason: 'stack trace recorded');
      expect(await log.totalBytes(), greaterThan(today.length));

      now = DateTime(2026, 10, 27, 9);
      log.info('next day');
      expect((await log.files()).map((f) => p.basename(f.path)), containsAll(['convomail-2026-10-26.log', 'convomail-2026-10-27.log']));
      await log.clear();
      expect(await log.files(), isEmpty);
    });
  });

  group('version and updates', () {
    test('appVersion matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'^version:\s*([\d.]+)\+(\d+)', multiLine: true).firstMatch(pubspec)!;
      expect(appVersion, m.group(1));
      expect(appBuild, int.parse(m.group(2)!));
      final msix = RegExp(r'^\s*msix_version:\s*([\d.]+)', multiLine: true).firstMatch(pubspec)!;
      expect(msix.group(1), '$appVersion.0');
    });

    test('version comparison', () {
      expect(UpdateChecker.compareVersions('1.10.0', '1.9.3'), greaterThan(0));
      expect(UpdateChecker.compareVersions('1.0.0', '1.0'), 0);
      expect(UpdateChecker.compareVersions('1.0.0+5', '1.0.0+1'), 0);
      expect(UpdateChecker.compareVersions('0.9.9', '1.0.0'), lessThan(0));
      expect(UpdateChecker.compareVersions('2.0.0-beta', '1.99.99'), greaterThan(0));
    });

    test('check reports available, up to date, and failures', () async {
      String body = '{"version":"1.1.0","url":"https://example.com/convomail-1.1.0.msix","notes":"Bug fixes"}';
      final checker = UpdateChecker(fetch: (uri) async => body);
      final feed = Uri.parse('https://example.com/latest.json');
      final r1 = await checker.check(feed, current: '1.0.0');
      expect(r1, isA<UpdateAvailable>());
      expect((r1 as UpdateAvailable).info.notes, 'Bug fixes');

      body = '{"version":"1.0.0","url":"https://example.com/x.msix"}';
      expect(await checker.check(feed, current: '1.0.0'), isA<UpToDate>());

      body = 'not json';
      expect(await checker.check(feed), isA<UpdateCheckFailed>());
      body = '{"url":"https://example.com/x.msix"}';
      expect(await checker.check(feed), isA<UpdateCheckFailed>());

      final failing = UpdateChecker(fetch: (uri) async => throw const SocketException('offline'));
      final r = await failing.check(feed);
      expect(r, isA<UpdateCheckFailed>());
      expect((r as UpdateCheckFailed).message, contains('offline'));
    });
  });

  group('onboarding and accessibility', () {
    late AppDatabase db;
    late FakeMailTransport imap;
    setUp(() {
      db = testDatabase();
      imap = FakeMailTransport();
    });
    tearDown(() => db.close());

    Widget app({bool onboarding = true}) => ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
            databaseProvider.overrideWith((ref) => db),
            credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
            transportFactoryProvider.overrideWith((ref) => () => imap),
            htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
            showOnboardingProvider.overrideWith((ref) => onboarding),
          ],
          child: const ConvoMailApp(startSync: false),
        );

    testWidgets('first run shows the welcome screen until dismissed; it never shows once an account exists', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ConvoMail'), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget, reason: 'the shell hosts the onboarding screen');
      expect(find.text('Chats'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ConvoMail'), findsNothing);
      expect(find.text('No conversations yet'), findsOneWidget);

      // A fresh start with an account skips onboarding even when not dismissed.
      await insertTestAccount(db);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ConvoMail'), findsNothing);
      expect(find.text('Chats'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Add your account opens Settings → Accounts with the add panel', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding-add-account')));
      // Timed pumps: the add panel focuses a text field (cursor blink never settles).
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Welcome to ConvoMail'), findsNothing);
      expect(find.text('Email address'), findsOneWidget, reason: 'add-account panel is open');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('People rows expose a combined screen-reader label', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      final account = await insertTestAccount(db);
      imap.folder('INBOX', role: FolderRole.inbox);
      const me = RemoteAddress('me@example.com');
      imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@chen.me', 'Sarah Chen'), to: const [me], subject: 'Hi', date: DateTime.now()));
      imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@chen.me', 'Sarah Chen'), to: const [me], subject: 'Again', date: DateTime.now()));
      final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
      await syncer.syncOnce();
      await db.refreshDirtyRows();

      await tester.pumpWidget(app(onboarding: false));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      container.read(syncControllerProvider).adoptForTest(account.id, syncer);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'^Sarah Chen, 2 unread')), findsOneWidget);
      expect(find.byTooltip('All accounts'), findsOneWidget, reason: 'account switcher is labelled');
      expect(find.byTooltip('New message (Ctrl+N)'), findsOneWidget);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
