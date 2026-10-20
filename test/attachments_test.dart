import 'dart:convert';
import 'dart:io';

import 'package:convomail/app/conversation_state.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/attachment_queries.dart';
import 'package:convomail/store/attachment_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/attachment_service.dart';
import 'package:convomail/sync/sync_controller.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/conversation_pane.dart';
import 'package:convomail/ui/screens/chats/files/attachment_preview.dart';
import 'package:convomail/ui/screens/chats/files/attachment_ui.dart';
import 'package:convomail/ui/screens/chats/files/files_panel.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Attachments (spec 4.5, plan M5): on-demand download into the local
/// store, inline CID images embedded in rendered bodies, the per-person
/// Files panel in list and grid modes, and the quick-look preview.
void main() {
  // A valid 1×1 PNG.
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
  final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 fake'));

  late AppDatabase db;
  late FakeMailTransport imap;
  late Directory storeDir;
  late Account account;
  late int uidPhoto;
  late int uidPdf;
  late int uidInline;

  List<Override> overrides() => [
        settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
        databaseProvider.overrideWith((ref) => db),
        credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
        transportFactoryProvider.overrideWith((ref) => () => imap),
        attachmentStoreProvider.overrideWith((ref) => AttachmentStore(() async => storeDir)),
        htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
      ];

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    storeDir = Directory.systemTemp.createTempSync('convomail_att_');
    account = await insertTestAccount(db);
    final inbox = imap.folder('INBOX', role: FolderRole.inbox);
    uidPhoto = inbox.add(
      RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah Chen'), to: const [RemoteAddress('me@example.com')], subject: 'Dashboard shot', date: DateTime(2026, 9, 20, 10), hasAttachments: true),
      body: const RemoteMessageBody(html: '<p>Here it is</p>', attachments: [RemoteAttachment(partId: '2', fileName: 'dashboard.png', mimeType: 'image/png', size: 70)]),
    );
    inbox.parts[uidPhoto] = {'2': png};
    uidPdf = inbox.add(
      RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah Chen'), to: const [RemoteAddress('me@example.com')], subject: 'Contract', date: DateTime(2026, 10, 1, 9), hasAttachments: true),
      body: const RemoteMessageBody(text: 'Signed copy attached', attachments: [RemoteAttachment(partId: '2', fileName: 'contract.pdf', mimeType: 'application/pdf', size: 13)]),
    );
    inbox.parts[uidPdf] = {'2': pdfBytes};
    uidInline = inbox.add(
      RemoteMessageHeader(uid: 0, from: const RemoteAddress('sarah@x.com', 'Sarah Chen'), to: const [RemoteAddress('me@example.com')], subject: 'Logo inline', date: DateTime(2026, 10, 2, 9)),
      body: const RemoteMessageBody(
        html: '<p>Our logo:</p><img src="cid:logo@x.com" width="40" height="40">',
        attachments: [RemoteAttachment(partId: '1.2', fileName: 'logo.png', mimeType: 'image/png', size: 70, contentId: '<logo@x.com>', isInline: true)],
      ),
    );
    inbox.parts[uidInline] = {'1.2': png};
  });

  tearDown(() {
    if (storeDir.existsSync()) storeDir.deleteSync(recursive: true);
  });

  Future<(ProviderContainer, AccountSyncer)> containerWithSync() async {
    final container = ProviderContainer(overrides: overrides());
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    container.read(syncControllerProvider).adoptForTest(account.id, syncer);
    await db.refreshDirtyRows();
    return (container, syncer);
  }

  group('service', () {
    test('ensureLocal downloads once into the store and records the path', () async {
      final (container, syncer) = await containerWithSync();
      addTearDown(container.dispose);
      addTearDown(db.close);
      final msg = (await db.messagesForRow('c:sarah@x.com')).firstWhere((m) => m.subject == 'Dashboard shot');
      await syncer.fetchBody(msg.id);
      final a = (await db.attachmentsForMessage(msg.id)).single;
      expect(a.localPath, isNull);

      final service = container.read(attachmentServiceProvider);
      final path = await service.ensureLocal(a.id);
      expect(File(path).readAsBytesSync(), png);
      expect(p.isWithin(storeDir.path, path), isTrue);
      expect(p.basename(path), '2_dashboard.png');
      expect((await db.attachmentById(a.id))!.localPath, path);
      expect(imap.log.where((l) => l.startsWith('parts')), hasLength(1));

      await service.ensureLocal(a.id);
      expect(imap.log.where((l) => l.startsWith('parts')), hasLength(1), reason: 'cached on disk, no second fetch');
    });

    test('dataUriFor matches ids with or without brackets and cid: prefix', () {
      final f = File(p.join(storeDir.path, 'x.png'))..writeAsBytesSync(png);
      final a = Attachment(id: 1, messageId: 1, partId: '2', fileName: 'x.png', mimeType: 'image/png', size: 70, contentId: '<Logo@X.com>', isInline: true, localPath: f.path);
      expect(AttachmentService.dataUriFor([a], 'logo@x.com'), startsWith('data:image/png;base64,'));
      expect(AttachmentService.dataUriFor([a], 'cid:<logo@x.com>'), isNotNull);
      expect(AttachmentService.dataUriFor([a], 'other@x.com'), isNull);
    });

    test('row attachments list non-inline files newest first; discovery fetches unopened bodies', () async {
      final (container, _) = await containerWithSync();
      addTearDown(container.dispose);
      addTearDown(db.close);
      expect(await db.watchAttachmentsForRow('c:sarah@x.com').first, isEmpty, reason: 'nothing fetched yet');
      expect(await db.rowMessagesNeedingAttachmentFetch('c:sarah@x.com'), hasLength(2));

      await container.read(attachmentServiceProvider).discoverForRow('c:sarah@x.com');
      final files = await db.watchAttachmentsForRow('c:sarah@x.com').first;
      expect(files.map((f) => f.attachment.fileName), ['contract.pdf', 'dashboard.png']);
      expect(files.first.senderLabel, 'Sarah Chen');
      expect(files.first.isImage, isFalse);
      expect(files.last.isImage, isTrue);
      expect(await db.rowMessagesNeedingAttachmentFetch('c:sarah@x.com'), isEmpty);
    });

    test('safeFileName strips path separators and reserved characters', () {
      expect(AttachmentStore.safeFileName(r'..\..\evil:name?.txt'), '.._.._evil_name_.txt');
      expect(AttachmentStore.safeFileName(''), 'attachment');
      expect(AttachmentStore.safeFileName('report (final).pdf'), 'report (final).pdf');
    });

    test('FileTypeStyle maps common types', () {
      expect(FileTypeStyle.of('application/pdf', 'a.pdf').label, 'PDF');
      expect(FileTypeStyle.of('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'a.xlsx').label, 'XLS');
      expect(FileTypeStyle.of('image/jpeg', 'a.jpg').label, 'JPG');
      expect(FileTypeStyle.of('application/octet-stream', 'archive.zip').label, 'ZIP');
      expect(canPreviewInApp(const Attachment(id: 0, messageId: 0, partId: '1', fileName: 'x.svg', mimeType: 'image/svg+xml', size: 1, isInline: false)), isFalse);
    });
  });

  group('ui', () {
    Widget app() => ProviderScope(overrides: overrides(), child: const ConvoMailApp(startSync: false));

    Future<void> openSarah(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1500, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
      await syncer.syncOnce();
      container.read(syncControllerProvider).adoptForTest(account.id, syncer);
      await db.refreshDirtyRows();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sarah Chen').first);
      await tester.pumpAndSettle();
    }

    /// Timed frames for states that animate (download spinners, image loads).
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    Future<void> teardown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
      await db.close();
    }

    testWidgets('Files button opens the panel: featured newest file, grouped list, grid of photos, Esc closes', (tester) async {
      await openSarah(tester);
      await tester.tap(find.byKey(const ValueKey('files-button')));
      await tester.pumpAndSettle();
      expect(find.byType(FilesPanel), findsOneWidget);
      expect(find.textContaining('Files · Sarah Chen'), findsOneWidget);
      // Discovery fetched both bodies; the newest attachment is featured.
      expect(find.byKey(const ValueKey('files-featured')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('files-featured')), matching: find.text('contract.pdf')), findsOneWidget);
      expect(find.text('MOST RECENT'), findsOneWidget);
      expect(find.text('SEPTEMBER 2026'), findsOneWidget);
      expect(find.text('dashboard.png'), findsOneWidget);
      expect(find.text('2 files'), findsOneWidget);

      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('photo-${(await db.watchAttachmentsForRow('c:sarah@x.com').first).last.attachment.id}')), findsOneWidget);
      expect(find.text('1 non-image file shown in List view'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(FilesPanel), findsNothing);
      await teardown(tester);
    });

    testWidgets('tapping an image chip downloads it and opens the quick-look preview with Save as', (tester) async {
      await openSarah(tester);
      await tester.tap(find.text('Dashboard shot'));
      await tester.pumpAndSettle();
      final chip = find.byType(AttachmentChip);
      expect(chip, findsOneWidget);
      expect(find.descendant(of: chip, matching: find.text('dashboard.png')), findsOneWidget);

      // The download writes a file; real I/O only completes inside runAsync.
      await tester.runAsync(() async {
        await tester.tap(chip);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await settle(tester);
      expect(find.byType(AttachmentPreviewDialog), findsOneWidget);
      expect(find.byKey(const ValueKey('preview-save-as')), findsOneWidget);
      expect(find.text('PNG · 70 B'), findsOneWidget);
      final msg = (await db.messagesForRow('c:sarah@x.com')).firstWhere((m) => m.subject == 'Dashboard shot');
      expect((await db.attachmentsForMessage(msg.id)).single.localPath, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(AttachmentPreviewDialog), findsNothing);
      await teardown(tester);
    });

    testWidgets('inline cid images are fetched and embedded as data URIs in the rendered body', (tester) async {
      await openSarah(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      final msg = (await db.messagesForRow('c:sarah@x.com')).firstWhere((m) => m.subject == 'Logo inline');
      // Expanding the card fetches the body and renders it; the inline part
      // downloads in the background (file I/O needs runAsync).
      await tester.tap(find.descendant(of: find.byType(ConversationPane), matching: find.text('Logo inline')));
      await settle(tester);
      // Each real wait lets one file I/O step complete; the pumps between
      // them run its continuation. Creating and writing the file takes several.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await settle(tester);
      }
      final inline = (await db.attachmentsForMessage(msg.id)).single;
      expect(inline.isInline, isTrue);
      expect(inline.localPath, isNotNull, reason: 'cid part downloaded automatically');
      await settle(tester);
      final rendered = container.read(renderedBodyProvider(msg.id)).value!;
      expect(rendered.html, contains('src="data:image/png;base64,${base64Encode(png)}"'));
      expect(rendered.sanitized.remote, isEmpty, reason: 'cid images are not remote content');
      await teardown(tester);
    });

    testWidgets('selecting another row closes the Files panel', (tester) async {
      await openSarah(tester);
      await tester.tap(find.byKey(const ValueKey('files-button')));
      await tester.pumpAndSettle();
      expect(find.byType(FilesPanel), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      container.read(filesPanelOpenProvider.notifier).close();
      await tester.pumpAndSettle();
      expect(find.byType(FilesPanel), findsNothing);
      await teardown(tester);
    });
  });
}
