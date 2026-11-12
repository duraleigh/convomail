import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convomail/app/destinations.dart';
import 'package:convomail/app/people_state.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/attachment_queries.dart';
import 'package:convomail/store/attachment_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/attachments_screen.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:convomail/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// The Attachments page: every file in the mailbox in one place.
void main() {
  const me = RemoteAddress('me@example.com');
  const sarah = RemoteAddress('sarah@x.com', 'Sarah Chen');
  const shop = RemoteAddress('orders@shop.example', 'The Shop');
  const bulk = BulkSignals(listUnsubscribe: true, listId: true, listIdValue: 'orders.shop.example');
  final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 fake'));

  late AppDatabase db;
  late FakeMailTransport imap;
  late Directory storeDir;
  late Account account;
  late int uidContract;

  RemoteAttachment file(String part, String name, String mime, int size, {String? cid, bool inline = false}) =>
      RemoteAttachment(partId: part, fileName: name, mimeType: mime, size: size, contentId: cid, isInline: inline);

  Future<AccountSyncer> sync() async {
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
    return syncer;
  }

  setUp(() async {
    db = testDatabase();
    imap = FakeMailTransport();
    storeDir = Directory.systemTemp.createTempSync('precis_attachments_');
    account = await insertTestAccount(db);
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com'));
    final inbox = imap.folder('INBOX', role: FolderRole.inbox);
    final sent = imap.folder('Sent', role: FolderRole.sent);
    // The user writes to Sarah, so she is a person.
    sent.add(
      RemoteMessageHeader(uid: 0, from: me, to: const [sarah], subject: 'Budget for spring', messageId: '<budget@me>', date: DateTime(2026, 9, 1, 9), hasAttachments: true),
      body: RemoteMessageBody(text: 'Here is the budget.', attachments: [file('2', 'Spring budget.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 48000)]),
    );
    uidContract = inbox.add(
      RemoteMessageHeader(uid: 0, from: sarah, to: const [me], subject: 'Contract', messageId: '<contract@x>', date: DateTime(2026, 10, 1, 9), hasAttachments: true),
      body: RemoteMessageBody(
        text: 'Signed copy attached',
        attachments: [
          file('2', 'contract.pdf', 'application/pdf', 240000),
          // Her signature's logo and a social icon come along as "attachments".
          file('3', 'image001.png', 'image/png', 2100, cid: '<image001@x>'),
          file('4', 'linkedin.png', 'image/png', 900),
          // A picture that sits inside the email is not a file at all.
          file('1.2', 'banner.png', 'image/png', 60000, cid: '<banner@x>', inline: true),
        ],
      ),
    );
    inbox.parts[uidContract] = {'2': pdfBytes};
    inbox.add(
      RemoteMessageHeader(uid: 0, from: sarah, to: const [me], subject: 'Photos from the venue', messageId: '<photos@x>', date: DateTime(2026, 10, 5, 9), hasAttachments: true),
      body: RemoteMessageBody(text: 'Two shots', attachments: [file('2', 'stage-left.jpg', 'image/jpeg', 1800000), file('3', 'stage-right.jpg', 'image/jpeg', 2100000)]),
    );
    inbox.add(
      RemoteMessageHeader(uid: 0, from: shop, to: const [me], subject: 'Your invoice', messageId: '<invoice@shop>', date: DateTime(2026, 10, 3, 9), hasAttachments: true, signals: bulk),
      body: RemoteMessageBody(text: 'Invoice attached', attachments: [file('2', 'Invoice 1042.pdf', 'application/pdf', 91000)]),
    );
    inbox.add(RemoteMessageHeader(uid: 0, from: sarah, to: const [me], subject: 'No files here', messageId: '<plain@x>', date: DateTime(2026, 10, 6, 9)), body: const RemoteMessageBody(text: 'Just words'));
  });

  tearDown(() async {
    await db.close();
    if (storeDir.existsSync()) storeDir.deleteSync(recursive: true);
  });

  Future<List<String>> names() async => [for (final f in await db.watchAllAttachments().first) f.attachment.fileName];

  group('finding the files', () {
    test('the files of every email are listed without fetching the emails: old mail and sent mail too', () async {
      final syncer = await sync();
      expect(await names(), isEmpty, reason: 'checking for mail brings no list of files');
      expect(await syncer.listAttachmentsAhead(), 4, reason: 'the four emails said to carry files');
      expect(await names(), ['stage-left.jpg', 'stage-right.jpg', 'Invoice 1042.pdf', 'contract.pdf', 'image001.png', 'linkedin.png', 'Spring budget.xlsx'], reason: 'newest first; the picture inside an email is not a file');
      expect((await db.select(db.messages).get()).every((m) => m.bodyFetchedAt == null), isTrue, reason: 'no email was downloaded for it');
      expect(await syncer.listAttachmentsAhead(), 0, reason: 'asked once');
      expect(imap.attachmentListCalls, 2, reason: 'one question per folder');
    });

    test('a file already downloaded stays downloaded when its email is opened later', () async {
      final syncer = await sync();
      await syncer.listAttachmentsAhead();
      final contract = (await db.watchAllAttachments().first).firstWhere((f) => f.attachment.fileName == 'contract.pdf');
      await db.setAttachmentLocalPath(contract.attachment.id, r'C:\somewhere\contract.pdf');
      await syncer.fetchBody(contract.message.id);
      final again = (await db.watchAllAttachments().first).firstWhere((f) => f.attachment.fileName == 'contract.pdf');
      expect(again.attachment.localPath, r'C:\somewhere\contract.pdf');
      expect(await names(), hasLength(7), reason: 'and nothing is listed twice');
    });

    test('who it is from: a person or the user (Chats), or not a person (Feed); and where to find its email', () async {
      final syncer = await sync();
      await syncer.listAttachmentsAhead();
      final files = {for (final f in await db.watchAllAttachments().first) f.attachment.fileName: f};
      expect(files['contract.pdf']!.fromPerson, isTrue);
      expect(files['contract.pdf']!.senderLabel, 'Sarah Chen');
      expect(files['contract.pdf']!.rowKey, 'c:sarah@x.com');
      expect(files['Spring budget.xlsx']!.fromPerson, isTrue);
      expect(files['Spring budget.xlsx']!.senderLabel, 'You');
      expect(files['Invoice 1042.pdf']!.fromPerson, isFalse);
    });
  });

  group('arranging them', () {
    late List<FoundFile> all;
    setUp(() async {
      final syncer = await sync();
      await syncer.listAttachmentsAhead();
      all = await db.watchAllAttachments().first;
    });
    List<String> shown({String search = '', FileSource source = FileSource.all, FileKind kind = FileKind.all, FileOrder order = FileOrder.newest, bool hide = true}) =>
        [for (final f in arrangeFiles(all, search: search, source: source, kind: kind, order: order, hideDecoration: hide)) f.attachment.fileName];

    test('logos, signature pictures and social icons are left out unless asked for', () {
      expect(shown(), ['stage-left.jpg', 'stage-right.jpg', 'Invoice 1042.pdf', 'contract.pdf', 'Spring budget.xlsx']);
      expect(shown(hide: false), contains('image001.png'));
      expect(shown(hide: false), contains('linkedin.png'));
      expect(looksLikeDecoration(all.firstWhere((f) => f.attachment.fileName == 'stage-left.jpg').attachment), isFalse, reason: 'a real photo is kept');
      expect(looksLikeDecoration(all.firstWhere((f) => f.attachment.fileName == 'contract.pdf').attachment), isFalse);
    });

    test('search by sender, by file name, by subject; several words narrow it', () {
      expect(shown(search: 'sarah'), ['stage-left.jpg', 'stage-right.jpg', 'contract.pdf']);
      expect(shown(search: 'invoice'), ['Invoice 1042.pdf']);
      expect(shown(search: 'venue'), ['stage-left.jpg', 'stage-right.jpg']);
      expect(shown(search: 'sarah pdf'), ['contract.pdf']);
      expect(shown(search: 'shop.example'), ['Invoice 1042.pdf']);
      expect(shown(search: 'nothing like this'), isEmpty);
    });

    test('Chats or Feed', () {
      expect(shown(source: FileSource.chats), ['stage-left.jpg', 'stage-right.jpg', 'contract.pdf', 'Spring budget.xlsx']);
      expect(shown(source: FileSource.feed), ['Invoice 1042.pdf']);
    });

    test('by kind of file', () {
      expect(shown(kind: FileKind.pdf), ['Invoice 1042.pdf', 'contract.pdf']);
      expect(shown(kind: FileKind.pictures), ['stage-left.jpg', 'stage-right.jpg']);
      expect(shown(kind: FileKind.sheets), ['Spring budget.xlsx']);
      expect(shown(kind: FileKind.media), isEmpty);
    });

    test('in order: oldest, name, size, sender, kind', () {
      expect(shown(order: FileOrder.oldest).first, 'Spring budget.xlsx');
      expect(shown(order: FileOrder.name), ['contract.pdf', 'Invoice 1042.pdf', 'Spring budget.xlsx', 'stage-left.jpg', 'stage-right.jpg']);
      expect(shown(order: FileOrder.largest).take(2), ['stage-right.jpg', 'stage-left.jpg']);
      expect(shown(order: FileOrder.sender), ['stage-left.jpg', 'stage-right.jpg', 'contract.pdf', 'Invoice 1042.pdf', 'Spring budget.xlsx'], reason: 'Sarah Chen, The Shop, You');
      expect(shown(order: FileOrder.kind).take(3), ['stage-left.jpg', 'stage-right.jpg', 'Invoice 1042.pdf'], reason: 'JPG, then PDF, then XLS');
    });
  });

  testWidgets('Attachments is a tab on the rail: the list, a search, the filters, the grid, and the way to the email', (tester) async {
    await tester.runAsync(() async {
      final syncer = await sync();
      await syncer.listAttachmentsAhead();
    });
    tester.view.physicalSize = const Size(1500, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
        databaseProvider.overrideWith((ref) => db),
        credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
        transportFactoryProvider.overrideWith((ref) => () => imap),
        attachmentStoreProvider.overrideWith((ref) => AttachmentStore(() async => storeDir)),
        htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
        destinationProvider.overrideWith(() => DestinationNotifier(initial: Destination.today)),
      ],
      child: const PrecisApp(startSync: false),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(AppShell)));

    await tester.tap(find.text('Attachments'));
    await tester.pumpAndSettle();
    expect(c.read(destinationProvider), Destination.attachments);
    expect(tester.widget<Text>(find.byKey(const ValueKey('attachments-count'))).data, '5 files');
    expect(find.text('contract.pdf'), findsOneWidget);
    expect(find.text('image001.png'), findsNothing);
    expect(find.textContaining('Sarah Chen · 234 KB'), findsOneWidget);

    // Search by sender.
    await tester.enterText(find.byKey(const ValueKey('attachments-search')), 'shop');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('attachments-count'))).data, '1 file');
    expect(find.text('Invoice 1042.pdf'), findsOneWidget);
    expect(find.text('contract.pdf'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('attachments-search')), '');
    await tester.pumpAndSettle();

    // Chats or Feed.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('attachments-source')), matching: find.text('Feed')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('attachments-count'))).data, '1 file');
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('attachments-source')), matching: find.text('All')));
    await tester.pumpAndSettle();

    // The kind of file.
    await tester.tap(find.byKey(const ValueKey('attachments-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF').last);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('attachments-count'))).data, '2 files');
    await tester.tap(find.byKey(const ValueKey('attachments-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All kinds').last);
    await tester.pumpAndSettle();

    // Logos and signature pictures, when asked for.
    await tester.tap(find.byKey(const ValueKey('attachments-hide-decoration')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('attachments-count'))).data, '7 files');
    expect(find.text('image001.png'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('attachments-hide-decoration')));
    await tester.pumpAndSettle();

    // As a grid, and back.
    await tester.tap(find.byKey(const ValueKey('attachments-view')));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('contract.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('attachments-view')));
    await tester.pumpAndSettle();

    // The email it came with.
    final contract = (await tester.runAsync(() async => (await db.watchAllAttachments().first).firstWhere((f) => f.attachment.fileName == 'contract.pdf')))!;
    await tester.tap(find.byKey(ValueKey('attachment-email-${contract.attachment.id}')));
    await tester.pumpAndSettle();
    expect(c.read(destinationProvider), Destination.chats);
    expect(c.read(selectedRowProvider), 'c:sarah@x.com');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
