import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:convomail/domain/signature.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/outgoing.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/compose_queries.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/sync/signature_service.dart';
import 'package:convomail/ui/screens/chats/compose/compose_editor.dart';
import 'package:convomail/ui/screens/settings/signature_editor.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' hide Element;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_db.dart';

/// Signatures with pictures: copied from the Gmail signature in sent mail,
/// put into new messages, swapped with the From address, and sent with the
/// picture inside the message.
void main() {
  // A 1×1 GIF.
  final gif = base64Decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7');

  const gmailBody = '<div dir="ltr">Thanks!<br clear="all"><div><br></div><span class="gmail_signature_prefix">-- </span><br>'
      '<div dir="ltr" class="gmail_signature" data-smartmail="gmail_signature"><div dir="ltr"><b>Clay Aiken</b><div>'
      '<a href="https://clayaiken.com">clayaiken.com</a></div><div><img src="cid:ii_sig1" width="200" height="50"></div></div></div></div>'
      '<div class="gmail_quote"><blockquote><div class="gmail_signature">Someone Else</div></blockquote></div>';

  group('reading a Gmail signature', () {
    test("finds the sender's own signature, not one in the quoted mail", () {
      final sig = gmailSignatureHtml(gmailBody)!;
      expect(sig, contains('Clay Aiken'));
      expect(sig, isNot(contains('Someone Else')));
      expect(gmailSignatureHtml('<div>No signature here</div>'), isNull);
    });

    test('keeps text, bold, links and pictures with their size', () {
      final nodes = signatureNodesFromHtml(gmailSignatureHtml(gmailBody)!, image: (src) => src == 'cid:ii_sig1' ? r'C:\sig\a.gif' : null);
      expect(nodes.map((n) => n.type), [ParagraphBlockKeys.type, ParagraphBlockKeys.type, ImageBlockKeys.type]);
      expect(nodes[0].delta!.toPlainText(), 'Clay Aiken');
      expect((nodes[0].delta!.first as TextInsert).attributes?[AppFlowyRichTextKeys.bold], true);
      expect((nodes[1].delta!.first as TextInsert).attributes?[AppFlowyRichTextKeys.href], 'https://clayaiken.com');
      expect(nodes[2].attributes[ImageBlockKeys.url], r'C:\sig\a.gif');
      expect(nodes[2].attributes[ImageBlockKeys.width], 200);
      expect(nodes[2].attributes[ImageBlockKeys.align], 'left');
    });

    test('a picture that cannot be had is left out', () {
      final nodes = signatureNodesFromHtml('<div>Clay</div><img src="cid:gone">', image: (_) => null);
      expect(nodes.map((n) => n.type), [ParagraphBlockKeys.type]);
    });
  });

  group('stored signatures', () {
    late AppDatabase db;
    late ProviderContainer container;
    late Directory dir;
    late Account account;
    late Identity identity;

    setUp(() async {
      db = testDatabase();
      dir = await Directory.systemTemp.createTemp('sig');
      container = ProviderContainer(overrides: [
        settingsStoreProvider.overrideWith((ref) => InMemorySettingsStore()),
        databaseProvider.overrideWith((ref) => db),
        credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
        signatureImagesDirProvider.overrideWith((ref) async => dir),
      ]);
      account = await insertTestAccount(db, email: 'clayaiken1130@gmail.com');
      final id = await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'ca@clayaiken.com', discovered: const Value(true)));
      identity = (await db.identityById(id))!;
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      await dir.delete(recursive: true);
    });

    testWidgets('the Settings editor shows the signature in a scrolling page and can clear it', (tester) async {
      await tester.runAsync(() => db.updateIdentity(identity.id, signature: 'Clay Aiken'));
      final fresh = (await tester.runAsync(() => db.identityById(identity.id)))!;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: ListView(children: [SignatureEditor(identity: fresh)]))),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Clay Aiken', findRichText: true), findsWidgets);
      expect(find.text('Add picture'), findsOneWidget);
      expect(find.text('Use my Gmail signature'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('signature-clear-${identity.id}')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      final cleared = (await tester.runAsync(() => db.identityById(identity.id)))!;
      expect(cleared.signature, '');
      expect(cleared.signatureJson, isNull);
      await tester.pumpWidget(const SizedBox());
    });

    test('an old plain-text signature still works', () async {
      await db.updateIdentity(identity.id, signature: 'Best,\nClay');
      final nodes = signatureNodes((await db.identityById(identity.id))!);
      expect(nodes.map((n) => n.delta!.toPlainText()), ['Best,', 'Clay']);
    });

    test('the Gmail signature is copied from sent mail, its picture kept locally', () async {
      final sent = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: account.id, path: '[Gmail]/Sent Mail', name: 'Sent', role: const Value('sent')));
      final msg = await db.into(db.messages).insert(MessagesCompanion.insert(
            accountId: account.id,
            folderId: sent,
            uid: 7,
            fromAddress: const Value('ca@clayaiken.com'),
            bodyHtml: const Value(gmailBody),
            bodyFetchedAt: Value(DateTime(2026, 11)),
          ));
      final part = File(p.join(dir.path, 'part.gif'))..writeAsBytesSync(gif);
      await db.into(db.attachments).insert(AttachmentsCompanion.insert(
            messageId: msg,
            partId: '2',
            fileName: const Value('sig.gif'),
            mimeType: const Value('image/gif'),
            contentId: const Value('<ii_sig1>'),
            isInline: const Value(true),
            localPath: Value(part.path),
          ));

      final result = await container.read(signatureServiceProvider).importFromGmail(identity);
      expect(result, GmailSignatureResult.imported);

      final saved = (await db.identityById(identity.id))!;
      expect(saved.signature, 'Clay Aiken\nclayaiken.com');
      final picture = signatureNodes(saved).singleWhere((n) => n.type == ImageBlockKeys.type);
      final path = picture.attributes[ImageBlockKeys.url] as String;
      expect(p.isWithin(dir.path, path), isTrue);
      expect(p.extension(path), '.gif');
      expect(File(path).readAsBytesSync(), gif);
    });

    test('no Gmail signature in sent mail says so and changes nothing', () async {
      await db.updateIdentity(identity.id, signature: 'Keep me');
      final result = await container.read(signatureServiceProvider).importFromGmail(identity);
      expect(result, GmailSignatureResult.notFound);
      expect((await db.identityById(identity.id))!.signature, 'Keep me');
    });

    test('a picked GIF is copied in and survives the original moving', () async {
      final original = File(p.join(dir.path, 'wave.gif'))..writeAsBytesSync(gif);
      final kept = await container.read(signatureServiceProvider).keepPicture(original.path);
      original.deleteSync();
      expect(File(kept).readAsBytesSync(), gif);
      expect(p.extension(kept), '.gif');
    });
  });

  group('in a message', () {
    test('a new message starts with the signature, and changing From swaps it', () async {
      final controller = ComposeEditorController(signature: [paragraphNode(text: 'Clay Aiken'), imageNode(url: r'C:\sig\a.gif', align: 'left')]);
      expect(controller.plainText(), contains('Clay Aiken'));
      expect(controller.toHtml(), contains(r'C:\sig\a.gif'));

      await controller.replaceSignature([paragraphNode(text: 'Cheryl')]);
      expect(controller.plainText(), contains('Cheryl'));
      expect(controller.plainText(), isNot(contains('Clay Aiken')));
      expect(controller.toHtml(), isNot(contains('a.gif')));

      await controller.replaceSignature(const []);
      expect(controller.plainText(), isNot(contains('Cheryl')));
      controller.dispose();
    });

    test('the GIF goes inside the sent message as itself', () async {
      final dir = await Directory.systemTemp.createTemp('sigsend');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'wave.gif'))..writeAsBytesSync(gif);
      final controller = ComposeEditorController(html: '<p>Hi</p>', signature: [imageNode(url: file.path, align: 'left', width: 200)]);
      final built = await MimeFactory.build(OutgoingMessage(
        from: const RemoteAddress('ca@clayaiken.com', 'Clay Aiken'),
        to: const [RemoteAddress('someone@example.com', '')],
        subject: 'Hi',
        html: controller.toHtml(),
      ));
      controller.dispose();
      expect(built.raw, contains('image/gif'));
      final html = built.message.decodeTextHtmlPart()!;
      expect(html, contains('src="cid:'));
      expect(html, contains('width="200"'));
      expect(html, isNot(contains(file.path)));
    });
  });
}
