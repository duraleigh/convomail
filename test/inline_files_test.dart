import 'package:convomail/mail/imap_transport.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/sync_queries.dart';
import 'package:drift/drift.dart' show Value;
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_db.dart';

/// A file is a file however it was sent. Apple Mail, forwarding an email
/// with PDFs, writes the email as pieces of text with each PDF in between,
/// and marks the PDFs "inline". Those PDFs were kept out of the email's list
/// of files, and only the first piece of text was kept. (An email of
/// November 13, 2026 that forwarded three invoices showed none of them.)
void main() {
  const pdf = 'JVBERi0xLjQKJcfsj6IKNSAwIG9iago8PC9MZW5ndGggNiAwIFI+PgpzdHJlYW0K';

  /// An email built the way Apple Mail builds a forward with files in it.
  String appleForward() => [
        'From: Matt <matt@x.example>',
        'To: me@example.com',
        'Subject: Fwd: Commercial invoices',
        'Message-ID: <fwd-1@x.example>',
        'MIME-Version: 1.0',
        'Content-Type: multipart/alternative; boundary="ALT"',
        '',
        '--ALT',
        'Content-Type: text/plain; charset=utf-8',
        '',
        'See the three invoices below.',
        '',
        '--ALT',
        'Content-Type: multipart/mixed; boundary="MIX"',
        '',
        '--MIX',
        'Content-Type: text/html; charset=utf-8',
        '',
        '<html><head></head><body><div>See the three invoices below.</div><div>Begin forwarded message:</div></body></html>',
        '--MIX',
        'Content-Disposition: inline; filename="Invoice 1.pdf"',
        'Content-Type: application/pdf; name="Invoice 1.pdf"',
        'Content-Transfer-Encoding: base64',
        '',
        pdf,
        '--MIX',
        'Content-Type: text/html; charset=utf-8',
        '',
        '<html><head></head><body><div>Second invoice follows.</div></body></html>',
        '--MIX',
        'Content-Disposition: inline; filename="Invoice 2.pdf"',
        'Content-Type: application/pdf; name="Invoice 2.pdf"',
        'Content-Transfer-Encoding: base64',
        '',
        pdf,
        '--MIX',
        'Content-Type: text/html; charset=utf-8',
        '',
        '<html><head></head><body><div>Thanks, Paul</div><img src="cid:logo-1@x"></body></html>',
        '--MIX',
        'Content-Disposition: inline; filename="logo.png"',
        'Content-Type: image/png; name="logo.png"',
        'Content-ID: <logo-1@x>',
        'Content-Transfer-Encoding: base64',
        '',
        'iVBORw0KGgo=',
        '--MIX',
        'Content-Disposition: inline; filename="photo.jpg"',
        'Content-Type: image/jpeg; name="photo.jpg"',
        'Content-Transfer-Encoding: base64',
        '',
        '/9j/4AAQSkZJRg==',
        '--MIX',
        'Content-Type: application/pdf; name="Invoice 3.pdf"',
        'Content-Transfer-Encoding: base64',
        '',
        pdf,
        '--MIX--',
        '',
        '--ALT--',
        '',
      ].join('\r\n');

  test('files sent "inline", and files with no mark at all, are files; only a picture the words show in place is not', () {
    final body = ImapTransport.bodyFromMime(MimeMessage.parseFromText(appleForward()));
    final files = {for (final a in body.attachments) a.fileName: a};
    expect(files.keys, containsAll(['Invoice 1.pdf', 'Invoice 2.pdf', 'Invoice 3.pdf', 'photo.jpg', 'logo.png']));
    for (final name in ['Invoice 1.pdf', 'Invoice 2.pdf', 'Invoice 3.pdf']) {
      expect(files[name]!.isInline, isFalse, reason: '$name is a file to open');
      expect(files[name]!.mimeType, 'application/pdf');
      expect(files[name]!.partId, isNotEmpty);
    }
    expect(files['photo.jpg']!.isInline, isFalse, reason: 'a picture the words do not show in place is offered as a file');
    expect(files['logo.png']!.isInline, isTrue, reason: 'a picture the words show in place is part of the words');
    // Each file can be fetched by the id it was listed under.
    final mime = MimeMessage.parseFromText(appleForward());
    final got = ImapTransport.partsFromMime(mime, [files['Invoice 2.pdf']!.partId]);
    expect(got[files['Invoice 2.pdf']!.partId], isNotNull);
    expect(String.fromCharCodes(got[files['Invoice 2.pdf']!.partId]!.take(4)), '%PDF');
  });

  test('an email written in several pieces is read in full, in order', () {
    final body = ImapTransport.bodyFromMime(MimeMessage.parseFromText(appleForward()));
    final html = body.html!;
    final at = [for (final words in ['See the three invoices below.', 'Begin forwarded message:', 'Second invoice follows.', 'Thanks, Paul']) html.indexOf(words)];
    expect(at.every((i) => i >= 0), isTrue, reason: 'every piece is there');
    expect(at, [...at]..sort(), reason: 'in the order they were written');
    expect(RegExp('<body', caseSensitive: false).allMatches(html).length, 1, reason: 'one document, not three glued together');
    expect(RegExp('</html>', caseSensitive: false).allMatches(html).length, 1);
    expect(body.text!.trim(), 'See the three invoices below.');
  });

  test('an ordinary email is read exactly as before', () {
    final body = ImapTransport.bodyFromMime(MimeMessage.parseFromText([
      'From: a@x.example',
      'Subject: Hello',
      'MIME-Version: 1.0',
      'Content-Type: multipart/mixed; boundary="M"',
      '',
      '--M',
      'Content-Type: multipart/alternative; boundary="A"',
      '',
      '--A',
      'Content-Type: text/plain; charset=utf-8',
      '',
      'Plain words.',
      '--A',
      'Content-Type: text/html; charset=utf-8',
      '',
      '<p>Rich words.</p>',
      '--A--',
      '--M',
      'Content-Type: text/plain; name="notes.txt"',
      'Content-Disposition: attachment; filename="notes.txt"',
      '',
      'NOTES',
      '--M--',
      '',
    ].join('\r\n')));
    expect(body.text!.trim(), 'Plain words.');
    expect(body.html!.trim(), '<p>Rich words.</p>');
    expect([for (final a in body.attachments) '${a.fileName} ${a.isInline}'], ['notes.txt false'], reason: 'a text file that is attached is a file, not the words');
  });

  test('pieces of HTML are joined inside the first one', () {
    expect(ImapTransport.joinHtmlPieces(['<p>one</p>']), '<p>one</p>');
    expect(ImapTransport.joinHtmlPieces(['<html><body class="a"><p>one</p></body></html>', '<html><BODY><p>two</p></BODY></html>', '<p>three</p>']),
        '<html><body class="a"><p>one</p><div><p>two</p></div><div><p>three</p></div></body></html>');
    expect(ImapTransport.joinHtmlPieces(['<p>one</p>', '<p>two</p>']), '<p>one</p><div><p>two</p></div>');
  });

  test('mail already kept is repaired on upgrade: its inline PDFs become files, and it is read again', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final account = await insertTestAccount(db);
    final folder = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: account.id, path: 'INBOX', name: 'Inbox', role: const Value('inbox')));
    Future<int> mail(String id) => db.into(db.messages).insert(MessagesCompanion.insert(accountId: account.id, folderId: folder, uid: id.hashCode & 0xffff, messageId: Value(id), bodyFetchedAt: Value(DateTime(2026, 11, 13)), hasAttachments: const Value(false)));
    final forward = await mail('<fwd@x>');
    final plain = await mail('<plain@x>');
    Future<void> file(int message, String name, String type, {required bool inline, String? cid}) =>
        db.into(db.attachments).insert(AttachmentsCompanion.insert(messageId: message, partId: name, fileName: Value(name), mimeType: Value(type), isInline: Value(inline), contentId: Value(cid)));
    await file(forward, 'Invoice 1.pdf', 'application/pdf', inline: true);
    await file(forward, 'logo.png', 'image/png', inline: true, cid: '<logo@x>');
    await file(plain, 'sig.png', 'image/png', inline: true, cid: '<sig@x>');

    await db.repairInlineFiles();

    final files = {for (final a in await db.select(db.attachments).get()) a.fileName: a.isInline};
    expect(files, {'Invoice 1.pdf': false, 'logo.png': true, 'sig.png': true});
    final after = {for (final m in await db.select(db.messages).get()) m.messageId: m};
    expect(after['<fwd@x>']!.hasAttachments, isTrue);
    expect(after['<fwd@x>']!.bodyFetchedAt, isNull, reason: 'read again, so the pieces after the first are not lost');
    expect(after['<plain@x>']!.hasAttachments, isFalse);
    expect(after['<plain@x>']!.bodyFetchedAt, isNotNull, reason: 'an email with nothing wrong is left alone');
  });
}
