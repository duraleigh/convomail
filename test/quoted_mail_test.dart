import 'package:convomail/domain/quoted_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

/// Each email shows what was written that time; the earlier mail copied
/// below a reply is left out (it is already in the thread).
void main() {
  // The words, with spaces dropped (the page's own text runs lines together).
  String text(String html) => html_parser.parse(html).body!.text.replaceAll(RegExp(r'\s+'), '');

  group('HTML', () {
    test('Gmail: the "On … wrote:" block and everything quoted in it go; the signature stays', () {
      final s = splitQuotedHtml('<div dir="ltr">Fine with Thursday.</div><br><div class="gmail_signature">Clay</div>'
          '<div class="gmail_quote gmail_quote_container"><div class="gmail_attr">On Tue, Nov 10, 2026, Emily wrote:<br></div>'
          '<blockquote class="gmail_quote"><div>For this week, let us change it up</div><div class="gmail_quote">On Mon, Nicole wrote:<blockquote>Older</blockquote></div></blockquote></div>');
      expect(s.hasQuoted, isTrue);
      expect(text(s.fresh), 'FinewithThursday.Clay');
    });

    test('Gmail: a signature placed below the quote is kept', () {
      final s = splitQuotedHtml('<div>Sounds good</div><div class="gmail_quote gmail_quote_container"><div class="gmail_attr">On Mon, Sam wrote:</div><blockquote class="gmail_quote">Old</blockquote></div>'
          '<div><br></div><span class="gmail_signature_prefix">-- </span><br><div class="gmail_signature">Emily Bundy</div>');
      expect(s.hasQuoted, isTrue);
      expect(text(s.fresh), 'Soundsgood--EmilyBundy');
    });

    test('Outlook: from the line and "From: … Sent: …" on', () {
      final s = splitQuotedHtml('<div>Yes, approved.</div><div id="appendonsend"></div><hr style="display:inline-block;width:98%"><div id="divRplyFwdMsg"><b>From:</b> Emily<br><b>Sent:</b> Monday</div><div>Old schedule</div>');
      expect(s.hasQuoted, isTrue);
      expect(text(s.fresh), 'Yes,approved.');
      expect(s.fresh, isNot(contains('<hr')));
      final desktop = splitQuotedHtml('<div class="WordSection1"><p class="MsoNormal">Thanks</p><div style="border:none;border-top:solid #E1E1E1 1.0pt;padding:3.0pt 0in 0in 0in"><p class="MsoNormal"><b>From:</b> Sam<br><b>Sent:</b> Monday</p></div><p class="MsoNormal">Old</p></div>');
      expect(text(desktop.fresh), 'Thanks');
    });

    test('Apple Mail and others: a quote after its "wrote:" line, or opening with it', () {
      final apple = splitQuotedHtml('<div>Great</div><div><br><blockquote type="cite">On Nov 9, 2026, at 6:39 PM, Emily wrote:<br><br></blockquote></div><blockquote type="cite"><div>Old</div></blockquote>');
      expect(text(apple.fresh), 'Great');
      final yahoo = splitQuotedHtml('<div>See you then</div><div class="yahoo_quoted"><div>On Monday, Sam wrote:</div><blockquote>Old</blockquote></div>');
      expect(text(yahoo.fresh), 'Seeyouthen');
      final inside = splitQuotedHtml('<div>Ok</div><br><blockquote><div>On Mon, Nov 9, 2026 at 6:39 PM Emily wrote:<br></div><div>Old</div></blockquote>');
      expect(text(inside.fresh), 'Ok');
    });

    test('a forward shows only what the sender wrote; the forwarded email is the part that opens', () {
      // Gmail.
      final gmail = splitQuotedHtml('<div>FYI</div><div class="gmail_quote gmail_quote_container"><div class="gmail_attr">---------- Forwarded message ---------<br>From: Sam</div><div>The forwarded email</div></div>');
      expect([gmail.hasQuoted, gmail.forwarded, text(gmail.fresh)], [true, true, 'FYI']);
      // Apple Mail, with the later pieces of the email after the first.
      final apple = splitQuotedHtml('<html><body><div dir="auto">See the three invoices below.<br><div><br><blockquote type="cite"><div>Begin forwarded message:</div><br><div><b>From:</b> Paul</div><div>Invoices attached.</div></blockquote></div></div><div><div>Second piece</div></div></body></html>');
      expect([apple.hasQuoted, apple.forwarded, text(apple.fresh)], [true, true, 'Seethethreeinvoicesbelow.']);
      // Outlook, known for a forward by its subject.
      final outlook = splitQuotedHtml('<div>Please see below.</div><div id="appendonsend"></div><hr style="display:inline-block;width:98%"><div id="divRplyFwdMsg"><b>From:</b> Paul<br><b>Sent:</b> Monday</div><div>Invoices</div>', subject: 'FW: Invoices');
      expect([outlook.hasQuoted, outlook.forwarded, text(outlook.fresh)], [true, true, 'Pleaseseebelow.']);
      // The same shape under a reply's subject is earlier mail, not a forward.
      expect(splitQuotedHtml('<div>Yes.</div><div id="appendonsend"></div><hr><div id="divRplyFwdMsg"><b>From:</b> Paul<br><b>Sent:</b> Monday</div><div>Old</div>', subject: 'RE: Invoices').forwarded, isFalse);
    });

    test('a forward with nothing written above it is shown as it is', () {
      const only = '<div class="gmail_quote gmail_quote_container"><div class="gmail_attr">---------- Forwarded message ---------<br>From: Sam</div><div>The forwarded email</div></div>';
      expect(splitQuotedHtml(only, subject: 'Fwd: Plans').hasQuoted, isFalse);
      expect(splitQuotedHtml('<html><body><div><br><blockquote type="cite"><div>Begin forwarded message:</div><div>All of it</div></blockquote></div></body></html>').hasQuoted, isFalse);
      expect(splitQuotedText('---------- Forwarded message ---------\nFrom: Sam\n\nHi').hasQuoted, isFalse);
    });

    test('kept whole: answers typed between quoted lines, and quotes without a "wrote:" line', () {
      expect(splitQuotedHtml('<div>Re below</div><div class="gmail_quote">On Mon, Sam wrote:<blockquote>Q1</blockquote></div><div>My answer to Q1</div>').hasQuoted, isFalse);
      expect(splitQuotedHtml('<p>As Lincoln said:</p><blockquote>Four score</blockquote>').hasQuoted, isFalse);
      expect(splitQuotedHtml('<div class="gmail_quote">On Mon, Sam wrote:<blockquote>Only the quote</blockquote></div>').hasQuoted, isFalse, reason: 'never hides the whole email');
    });

    test('a reply to a forwarded email is still a reply', () {
      final s = splitQuotedHtml('<div>Thanks!</div><div class="gmail_quote gmail_quote_container"><div class="gmail_attr">On Mon, Sam wrote:</div><blockquote class="gmail_quote">---------- Forwarded message ---------<br>From: X</blockquote></div>');
      expect(s.hasQuoted, isTrue);
      expect(text(s.fresh), 'Thanks!');
    });
  });

  group('plain text', () {
    test('"On … wrote:" with ">" lines, and Outlook headers', () {
      final s = splitQuotedText('Sounds good.\n\nClay\n\nOn Mon, Nov 9, 2026 at 6:39 PM Emily Bundy <e@x.net>\nwrote:\n\n> Old line\n> More\n');
      expect(s.hasQuoted, isTrue);
      expect(s.fresh, 'Sounds good.\n\nClay');
      expect(splitQuotedText('Yes\n\nFrom: Sam\nSent: Monday\nTo: Me\n\nOld').fresh, 'Yes');
      expect(splitQuotedText('Yes\n-----Original Message-----\nOld').fresh, 'Yes');
    });

    test('answers between quoted lines are kept whole', () {
      expect(splitQuotedText('On Mon, Sam wrote:\n> Q1\nAnswer 1\n> Q2\nAnswer 2').hasQuoted, isFalse);
    });

    test('a forward shows only what the sender wrote', () {
      final s = splitQuotedText('FYI\n\n---------- Forwarded message ---------\nFrom: Sam\nDate: Monday\n\nHi');
      expect([s.hasQuoted, s.forwarded, s.fresh], [true, true, 'FYI']);
      final apple = splitQuotedText('See below.\n\nBegin forwarded message:\n\nFrom: Paul\nSubject: Invoices\n\nAttached.');
      expect([apple.hasQuoted, apple.forwarded, apple.fresh], [true, true, 'See below.']);
      // A reply's copy is still "earlier mail".
      expect(splitQuotedText('Yes\n-----Original Message-----\nOld').forwarded, isFalse);
    });
  });
}
