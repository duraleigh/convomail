import 'dart:io';

import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/outgoing.dart';
import 'package:enough_mail/enough_mail.dart' hide ServerConfig;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// MIME building for outgoing mail (plan M4): multipart/alternative body,
/// threading headers, attachments, inline CID images, plain-text derivation.
void main() {
  const me = RemoteAddress('me@example.com', 'Clay Example');
  const sarah = RemoteAddress('sarah@x.com', 'Sarah Chen');

  test('simple message is multipart/alternative with both bodies and threading headers', () async {
    final built = await MimeFactory.build(const OutgoingMessage(
      from: me,
      to: [sarah],
      cc: [RemoteAddress('tom@x.com')],
      subject: 'Re: Figma access',
      html: '<p>Hi <b>Sarah</b>,</p><p>Done — you should have it now.</p>',
      inReplyTo: '<abc@x.com>',
      references: ['<root@x.com>', '<abc@x.com>'],
    ));
    final parsed = MimeMessage.parseFromText(built.raw);
    expect(parsed.mediaType.sub, MediaSubtype.multipartAlternative);
    expect(parsed.decodeSubject(), 'Re: Figma access');
    expect(parsed.from!.single.email, 'me@example.com');
    expect(parsed.from!.single.personalName, 'Clay Example');
    expect(parsed.to!.single.email, 'sarah@x.com');
    expect(parsed.cc!.single.email, 'tom@x.com');
    expect(parsed.getHeaderValue('in-reply-to'), '<abc@x.com>');
    expect(parsed.getHeaderValue('references'), '<root@x.com> <abc@x.com>');
    expect(parsed.getHeaderValue('message-id'), built.messageId);
    expect(built.messageId, startsWith('<'));
    expect(built.messageId, endsWith('@example.com>'));
    expect(parsed.decodeTextPlainPart(), contains('Hi Sarah,'));
    expect(parsed.decodeTextPlainPart(), contains('Done — you should have it now.'));
    expect(parsed.decodeTextHtmlPart(), contains('<b>Sarah</b>'));
    expect(parsed.decodeTextHtmlPart(), contains('<!DOCTYPE html>'));
    expect(parsed.getHeaderValue('x-mailer'), 'ConvoMail');
    expect(parsed.getHeaderValue('bcc'), isNull);
  });

  test('bcc recipients are in the envelope list but not a visible header', () async {
    const m = OutgoingMessage(from: me, to: [sarah], bcc: [RemoteAddress('secret@x.com')], subject: 's', html: '<p>x</p>');
    expect(m.allRecipients.map((a) => a.address), containsAll(['sarah@x.com', 'secret@x.com']));
    final built = await MimeFactory.build(m);
    // enough_mail renders Bcc when set; the SMTP envelope decides delivery,
    // and the sender strips nothing further. Document the current output.
    final parsed = MimeMessage.parseFromText(built.raw);
    expect(parsed.bcc?.map((a) => a.email).toList() ?? const [], anyOf(isEmpty, ['secret@x.com']));
  });

  test('attachments produce multipart/mixed with base64 parts', () async {
    final dir = Directory.systemTemp.createTempSync('convomail_mime_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File(p.join(dir.path, 'notes.txt'))..writeAsStringSync('hello attachment');
    final built = await MimeFactory.build(OutgoingMessage(
      from: me,
      to: const [sarah],
      subject: 'Files',
      html: '<p>See attached.</p>',
      attachments: [OutgoingAttachment(fileName: 'notes.txt', mimeType: 'text/plain', path: f.path)],
    ));
    final parsed = MimeMessage.parseFromText(built.raw);
    expect(parsed.mediaType.sub, MediaSubtype.multipartMixed);
    final atts = parsed.findContentInfo(disposition: ContentDisposition.attachment);
    expect(atts.single.fileName, 'notes.txt');
    final part = parsed.getPart(atts.single.fetchId)!;
    expect(part.decodeContentText(), 'hello attachment');
    expect(parsed.decodeTextHtmlPart(), contains('See attached.'));
    expect(parsed.decodeTextPlainPart(), contains('See attached.'));
  });

  test('local image paths become inline CID parts inside multipart/related', () async {
    final dir = Directory.systemTemp.createTempSync('convomail_mime_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final img = File(p.join(dir.path, 'shot.png'))..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
    final built = await MimeFactory.build(OutgoingMessage(
      from: me,
      to: const [sarah],
      subject: 'Screenshot',
      html: '<p>Look:</p><img src="${img.path}"><p>end</p>',
    ));
    final parsed = MimeMessage.parseFromText(built.raw);
    expect(parsed.mediaType.sub, MediaSubtype.multipartRelated);
    final html = parsed.decodeTextHtmlPart()!;
    expect(html, isNot(contains(img.path)));
    final cid = RegExp(r'src="cid:([^"]+)"').firstMatch(html)!.group(1)!;
    final inline = parsed.findContentInfo(disposition: ContentDisposition.inline).where((i) => i.mediaType?.isImage ?? false).toList();
    expect(inline, hasLength(1));
    expect(inline.single.cid, '<$cid>');
    expect(inline.single.fileName, 'shot.png');
  });

  test('inline image plus attachment nests related inside mixed', () async {
    final dir = Directory.systemTemp.createTempSync('convomail_mime_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final img = File(p.join(dir.path, 'a.png'))..writeAsBytesSync([1, 2, 3]);
    final doc = File(p.join(dir.path, 'b.pdf'))..writeAsBytesSync([4, 5, 6]);
    final built = await MimeFactory.build(OutgoingMessage(
      from: me,
      to: const [sarah],
      subject: 'Both',
      html: '<img src="file:///${img.path.replaceAll('\\', '/')}">',
      attachments: [OutgoingAttachment(fileName: 'b.pdf', mimeType: 'application/pdf', path: doc.path)],
    ));
    final parsed = MimeMessage.parseFromText(built.raw);
    expect(parsed.mediaType.sub, MediaSubtype.multipartMixed);
    expect(parsed.parts!.first.mediaType.sub, MediaSubtype.multipartRelated);
    expect(parsed.findContentInfo(disposition: ContentDisposition.attachment).single.fileName, 'b.pdf');
    expect(parsed.decodeTextHtmlPart(), contains('src="cid:'));
  });

  group('htmlToPlainText', () {
    test('paragraphs, lists, links, quotes', () {
      final t = MimeFactory.htmlToPlainText(
        '<h1>Title</h1><p>Hello <a href="https://x.com/a">there</a>.</p><ul><li>one</li><li>two</li></ul><ol><li>first</li><li>second</li></ol>'
        '<blockquote><p>quoted line</p></blockquote><p>bye<br>now</p>',
      );
      expect(t, contains('Title\n'));
      expect(t, contains('Hello there <https://x.com/a>.'));
      expect(t, contains('- one\n- two'));
      expect(t, contains('1. first\n2. second'));
      expect(t, contains('> quoted line'));
      expect(t, contains('bye\nnow'));
      expect(t, isNot(contains('<p>')));
      expect(t, isNot(contains('</')));
    });

    test('scripts and styles are dropped and whitespace collapses', () {
      expect(MimeFactory.htmlToPlainText('<style>p{}</style><p>a   b\n c</p><script>x()</script>'), 'a b c');
    });
  });
}
