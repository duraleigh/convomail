import 'dart:convert';

import 'package:convomail/domain/html_sanitizer.dart';
import 'package:convomail/domain/simple_mail.dart';
import 'package:convomail/ui/screens/chats/simple_mail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simple emails are drawn straight into the conversation; designed ones
/// keep the browser box.
void main() {
  // A 1×1 GIF.
  final gif = base64Decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7');
  List<MailBlock>? blocks(String html, {bool allowRemote = false, List<String> highlight = const []}) =>
      simpleMailBlocks(const HtmlSanitizer().sanitize(html, allowRemoteImages: allowRemote, highlight: highlight).bodyInner);

  group('simple mail becomes lines', () {
    test('a Gmail reply: lines, a blank line, bold, a link, and the quoted mail', () {
      final b = blocks('<div dir="ltr"><div>Hi Cassie,</div><div><br></div><div>Sounds <b>great</b>, see <a href="https://x.com/a">this</a>.</div>'
          '<div><br></div><div>Clay</div></div><br><div class="gmail_quote"><div dir="ltr" class="gmail_attr">On Mon, Cassie wrote:<br></div>'
          '<blockquote class="gmail_quote" style="margin:0px 0px 0px 0.8ex;border-left:1px solid rgb(204,204,204);padding-left:1ex"><div dir="ltr">Earlier words</div></blockquote></div>')!;
      expect(mailBlocksText(b), 'Hi Cassie,\n\nSounds great, see this.\n\nClay\n\nOn Mon, Cassie wrote:\n> Earlier words');
      final line = b[2] as MailText;
      expect(line.spans.firstWhere((s) => s.text == 'great').bold, isTrue);
      expect(line.spans.firstWhere((s) => s.text == 'this').href, 'https://x.com/a');
      expect(b.last, isA<MailQuote>());
    });

    test('Outlook lines have no gaps between them; real paragraphs do', () {
      final outlook = blocks('<div class="WordSection1"><p class="MsoNormal">Line one<o:p></o:p></p><p class="MsoNormal">Line two<o:p></o:p></p><p class="MsoNormal"><o:p>&nbsp;</o:p></p><p class="MsoNormal">Thanks<o:p></o:p></p></div>')!;
      expect(mailBlocksText(outlook), 'Line one\nLine two\n\nThanks');
      expect(outlook.whereType<MailText>().any((t) => t.spaceAfter), isFalse);
      final paras = blocks('<p>First</p><p>Second</p>')!;
      expect((paras.first as MailText).spaceAfter, isTrue);
    });

    test('lists, headings and line breaks', () {
      final b = blocks('<h2>Plan</h2><ul><li>One</li><li>Two</li></ul><ol start="3"><li>Three</li></ol><div>a<br>b</div>')!;
      expect(mailBlocksText(b), 'Plan\n• One\n• Two\n3. Three\na\nb');
      expect((b.first as MailText).heading, 2);
    });

    test('pictures: inside the message kept as bytes, blocked ones marked, trackers and emoji handled', () {
      final data = 'data:image/gif;base64,${base64Encode(gif)}';
      final b = blocks('<div>Hello <img data-emoji="👋" alt="👋" src="https://fonts.gstatic.com/e.png" width="20" height="20"></div>'
          '<div><img src="$data" width="200" height="50"></div>'
          '<div><img src="https://cdn.example/photo.jpg" width="300"></div>'
          '<img src="https://open.mailtrack.io/p.gif" width="1" height="1">')!;
      expect(mailBlocksText(b), startsWith('Hello 👋'));
      final images = [for (final t in b.whereType<MailText>()) for (final s in t.spans) if (s.image != null) s.image!];
      expect(images, hasLength(2), reason: 'the tracking pixel is left out');
      expect(images[0].bytes, gif);
      expect(images[0].width, 200);
      expect(images[1].blocked, isTrue);
      expect(images[1].url, isNull, reason: 'nothing is fetched while blocked');

      final allowed = blocks('<div><img src="https://cdn.example/photo.jpg" width="300"></div>', allowRemote: true)!;
      expect((allowed.single as MailText).spans.single.image!.url, 'https://cdn.example/photo.jpg');
    });

    test('search matches are marked', () {
      final b = blocks('<div>The budget is ready</div>', highlight: ['budget'])!;
      expect((b.single as MailText).spans.firstWhere((s) => s.text == 'budget').mark, isTrue);
    });

    test('hidden text is left out', () {
      expect(mailBlocksText(blocks('<div style="display:none">preview text</div><div>Shown</div>')!), 'Shown');
    });
  });

  group('designed mail keeps its own look', () {
    test('columns, coloured panels, fixed widths, centring', () {
      expect(blocks('<table><tr><td>A</td><td>B</td><td>C</td><td>D</td></tr></table>'), isNull, reason: 'four columns: a page layout');
      expect(blocks('<table><tr><td>${'Long story. ' * 60}</td><td>Side</td></tr></table>'), isNull, reason: 'a big two-column page');
      expect(blocks('<table><tr><td><table><tr><td>${'Story. ' * 40}</td></tr></table></td><td>y</td></tr></table>'), isNull, reason: 'tables inside tables');
      expect(blocks('<div style="background-color:#1a73e8;padding:20px">Sale!</div>'), isNull);
      expect(blocks('<table width="600"><tr><td>Hi</td></tr></table>'), isNull);
      expect(blocks('<div style="width:640px">Hi</div>'), isNull);
      expect(blocks('<center>Hi</center>'), isNull);
      expect(blocks('<table><tr><td bgcolor="#eeeeee">Hi</td></tr></table>'), isNull);
    });

    test('a one-column table and a highlighted word are still simple', () {
      expect(blocks('<table><tr><td>Just text</td></tr></table>'), isNotNull);
      expect(blocks('<div>A <span style="background-color:yellow">marked</span> word</div>'), isNotNull);
    });

    test('see-through and white backgrounds, and inline-block, change nothing', () {
      expect(blocks('<p style="background:rgba(0, 0, 0, 0)">Hi</p>'), isNotNull);
      expect(blocks('<div style="background:none transparent">Hi</div>'), isNotNull);
      expect(blocks('<div style="background:0% 0% repeat white">Hi</div>'), isNotNull);
      expect(blocks('<div style="background-color:rgb(255, 255, 255)">Hi</div>'), isNotNull);
      expect(blocks('<div style="display:inline-block">Hi</div>'), isNotNull);
      expect(blocks('<div style="background:lightgrey">Hi</div>'), isNotNull, reason: 'pale: a banner, not a panel');
      expect(blocks('<table style="background-color:#EFF6FC"><tr><td>Note</td></tr></table>'), isNotNull);
      expect(blocks('<div style="background:#3e3e3e">Hi</div>'), isNull);
    });

    test('a reply with emoji and a quoted newsletter below is still simple', () {
      final emoji = [for (var i = 0; i < 12; i++) '<img data-emoji="😀" alt="😀" src="https://fonts.gstatic.com/e$i.png" width="20" height="20">'].join();
      final icons = [for (var i = 0; i < 4; i++) '<a href="https://social.example/$i"><img src="https://cdn.example/i$i.png" width="19" height="19"></a>'].join();
      const quotedNewsletter = '<div class="gmail_quote"><blockquote class="gmail_quote"><table bgcolor="#04689b" width="600"><tr><td>A</td><td>B</td><td>C</td><td>D</td></tr></table></blockquote></div>';
      expect(blocks('<div>Fine with Thursday $emoji</div><div>$icons</div>$quotedNewsletter'), isNotNull);
      const outlook = '<div>Sounds good</div><hr><div id="divRplyFwdMsg">From: Sam</div><div style="background:#260559;width:600px">Old newsletter</div>';
      expect(blocks(outlook), isNotNull, reason: "Outlook's quoted mail follows divRplyFwdMsg");
      expect(blocks('<div>See this</div><table class="lp-rich-link" bgcolor="#E6E6E6" style="width:300px"><tr><td>Preview</td></tr></table>'), isNotNull);
      expect(blocks('<ul style="display:flex"><li>One</li></ul>'), isNotNull, reason: 'Outlook lists are flex boxes');
    });

    test('an empty HTML part has no content; the plain text is shown instead', () {
      expect(htmlHasContent('<div dir="auto"></div>'), isFalse);
      expect(htmlHasContent('<div>Hi</div>'), isTrue);
      expect(htmlHasContent('<img src="cid:x">'), isTrue);
    });

    test('a signature with the logo beside the name is drawn as columns', () {
      final data = 'data:image/gif;base64,${base64Encode(gif)}';
      final b = blocks('<div>Thanks!</div><table><tr><td><img src="$data" width="60" height="60"></td><td><b>Cassie Petrey</b><br>Crowd Surf</td></tr></table>')!;
      expect(b.first, isA<MailText>());
      final cols = b.last as MailColumns;
      expect(cols.cells, hasLength(2));
      expect(mailBlocksText(cols.cells[1]), 'Cassie Petrey\nCrowd Surf');
    });
  });

  testWidgets('drawn in the app: text, a link, a quote, and a picture', (tester) async {
    final b = blocks('<div>Hi <a href="https://x.com">there</a></div><blockquote>Old</blockquote><div><img src="data:image/gif;base64,${base64Encode(gif)}" width="40" height="40"></div>'
        '<table><tr><td>Name</td><td>${'A long title that wraps onto more lines ' * 6}</td></tr></table><ul><li>Item</li></ul><hr>')!;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SimpleMailBody(blocks: b)))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Hi there', findRichText: true), findsOneWidget);
    expect(find.textContaining('Old', findRichText: true), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('A long title', findRichText: true), findsOneWidget);
    expect(tester.getSize(find.byType(Image)).width, 40);
  });
}
