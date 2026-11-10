import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

// A reply usually carries a copy of the whole conversation below it. Those
// earlier emails are already in the thread as their own messages, so each
// email shows only what was written that time; the copy opens with "Show
// earlier mail". Forwards keep everything: the forwarded email is the point.

/// An email split into the part written this time and the earlier mail
/// copied below it.
class QuoteSplit {
  const QuoteSplit(this.fresh, {required this.hasQuoted});

  /// The email without the copied earlier mail (the whole email when
  /// [hasQuoted] is false).
  final String fresh;

  /// Whether earlier mail was found and left out of [fresh].
  final bool hasQuoted;
}

final _forwardSubject = RegExp(r'^\s*(?:fwd?|fw)\s*:', caseSensitive: false);
final _forwardWords = RegExp(r'forwarded message|begin forwarded message|original message.*forward', caseSensitive: false);
final _wroteLine = RegExp(r'\bwrote\s*:?\s*$|\bschrieb\s*:?\s*$|\ba écrit\s*:?\s*$|\bescribió\s*:?\s*$', caseSensitive: false);
final _space = RegExp(r'[\s ​‌‍﻿]+');

/// Whether the hidden part opens as a forwarded email rather than with
/// "On …, Sam wrote:" (a reply to a forward is still a reply).
bool _startsAsForward(String hidden) {
  final wrote = RegExp(r'\bwrote\b', caseSensitive: false).firstMatch(hidden)?.start ?? hidden.length;
  final head = hidden.substring(0, [wrote, 200, hidden.length].reduce((a, b) => a < b ? a : b));
  return _forwardWords.hasMatch(head);
}

bool _isForward(String? subject) => subject != null && _forwardSubject.hasMatch(subject);

String _norm(String s) => s.replaceAll(_space, ' ').trim();

// --- HTML ---------------------------------------------------------------------

/// [html] without the earlier mail quoted below the new part.
QuoteSplit splitQuotedHtml(String html, {String? subject}) {
  if (_isForward(subject)) return QuoteSplit(html, hasQuoted: false);
  final doc = html_parser.parse(html);
  final body = doc.body;
  if (body == null) return QuoteSplit(html, hasQuoted: false);
  final start = _quoteStart(body);
  if (start == null) return QuoteSplit(html, hasQuoted: false);

  // What would be hidden: never a forward, and never the whole email.
  final hiddenText = _norm(_textFrom(start, body));
  if (_startsAsForward(hiddenText)) return QuoteSplit(html, hasQuoted: false);
  _removeFrom(start, body);
  _dropTrailingEmpty(body);
  if (_norm(body.text).isEmpty && body.querySelector('img') == null) return QuoteSplit(html, hasQuoted: false);
  return QuoteSplit(doc.outerHtml, hasQuoted: true);
}

/// Where the copied earlier mail begins, or null.
dom.Element? _quoteStart(dom.Element body) {
  final all = body.querySelectorAll('*');
  // Outlook: everything from its "From: … Sent: …" block on is the earlier
  // mail; it is not inside a quote.
  for (final el in all) {
    final id = el.id;
    if (id.endsWith('appendonsend') || id.endsWith('divRplyFwdMsg')) {
      return _withRuleBefore(el);
    }
  }
  for (final el in all) {
    final style = (el.attributes['style'] ?? '').toLowerCase().replaceAll(' ', '');
    if (el.localName == 'div' && style.contains('border-top:solid') && RegExp(r'^\s*From:', caseSensitive: false).hasMatch(el.text) && RegExp(r'(Sent|Date):', caseSensitive: false).hasMatch(el.text)) {
      return el;
    }
  }
  // Gmail, Yahoo, Apple Mail and others: a quote with its "On … wrote:"
  // line, as long as nothing new is written after it (an answer typed in
  // between the quoted lines keeps the email whole).
  for (final el in all) {
    final classes = el.classes;
    final gmail = classes.contains('gmail_quote_container') || (classes.any((c) => c == 'gmail_quote' || c.endsWith('_gmail_quote')) && !_hasAncestorClass(el, 'gmail_quote_container'));
    final yahoo = classes.contains('yahoo_quoted');
    if ((gmail || yahoo) && !_insideQuote(el) && _nothingAfter(el, body)) return el;
  }
  for (final el in all) {
    if (el.localName != 'blockquote' || _insideQuote(el)) continue;
    final attribution = _attributionBefore(el);
    if (attribution == null && el.attributes['type'] != 'cite' && !_opensWithAttribution(el)) continue;
    if (!_nothingAfter(el, body)) continue;
    return attribution ?? el;
  }
  return null;
}

bool _hasAncestorClass(dom.Element el, String cls) {
  for (var p = el.parent; p != null; p = p.parent) {
    if (p.classes.contains(cls)) return true;
  }
  return false;
}

bool _insideQuote(dom.Element el) {
  for (var p = el.parent; p != null; p = p.parent) {
    if (p.localName == 'blockquote' || p.classes.any((c) => c == 'gmail_quote' || c.endsWith('_gmail_quote') || c == 'gmail_quote_container' || c == 'yahoo_quoted')) return true;
  }
  return false;
}

/// The "On …, Sam wrote:" line just before a quote, if there is one.
dom.Element? _attributionBefore(dom.Element quote) {
  var prev = quote.previousElementSibling;
  while (prev != null && _norm(prev.text).isEmpty && prev.querySelector('img') == null) {
    prev = prev.previousElementSibling;
  }
  if (prev == null) return null;
  return _wroteLine.hasMatch(_norm(prev.text)) ? prev : null;
}

/// Whether a quote's first line is its own "On …, Sam wrote:".
bool _opensWithAttribution(dom.Element quote) {
  final text = _norm(quote.text);
  final wrote = RegExp(r'\bwrote\s*:', caseSensitive: false).firstMatch(text);
  return wrote != null && wrote.start < 200 && RegExp(r'^On\s', caseSensitive: false).hasMatch(text);
}

/// An Outlook marker, with the line drawn just before it.
dom.Element _withRuleBefore(dom.Element el) {
  var prev = el.previousElementSibling;
  while (prev != null && prev.localName != 'hr' && _norm(prev.text).isEmpty && prev.querySelector('img') == null) {
    prev = prev.previousElementSibling;
  }
  return prev != null && prev.localName == 'hr' ? prev : el;
}

/// A signature placed below the quoted mail (Gmail can put it there).
bool _isSignature(dom.Node n) =>
    n is dom.Element && (n.classes.any((c) => c.endsWith('gmail_signature') || c.endsWith('gmail_signature_prefix')) || n.id.endsWith('Signature') || n.querySelector('.gmail_signature') != null && _norm(n.text) == _norm(n.querySelector('.gmail_signature')!.text));

/// Whether nothing but blank space (or a signature) follows [el] to the end
/// of [body].
bool _nothingAfter(dom.Element el, dom.Element body) {
  for (dom.Node? n = el; n != null && n != body; n = n.parent) {
    final parent = n.parent;
    if (parent == null) break;
    final i = parent.nodes.indexOf(n);
    for (final s in parent.nodes.skip(i + 1)) {
      if (_isSignature(s)) continue;
      if (_norm(s.text ?? '').isNotEmpty) return false;
      if (s is dom.Element && s.querySelector('img') != null) return false;
      if (s is dom.Element && s.localName == 'img') return false;
    }
  }
  return true;
}

/// The text of [el] and everything after it.
String _textFrom(dom.Element el, dom.Element body) {
  final out = StringBuffer(el.text);
  for (dom.Node? n = el; n != null && n != body; n = n.parent) {
    final parent = n.parent;
    if (parent == null) break;
    final i = parent.nodes.indexOf(n);
    for (final s in parent.nodes.skip(i + 1)) {
      out.write(' ${s.text ?? ''}');
    }
  }
  return out.toString();
}

/// Removes [el] and everything after it, except a signature.
void _removeFrom(dom.Element el, dom.Element body) {
  for (dom.Node? n = el; n != null && n != body; n = n.parent) {
    final parent = n.parent;
    if (parent == null) break;
    final i = parent.nodes.indexOf(n);
    for (final s in parent.nodes.skip(i + 1).toList()) {
      if (!_isSignature(s)) s.remove();
    }
  }
  el.remove();
}

/// Blank lines and breaks left at the end.
void _dropTrailingEmpty(dom.Element el) {
  while (el.nodes.isNotEmpty) {
    final last = el.nodes.last;
    if (last is dom.Text && _norm(last.text).isEmpty) {
      last.remove();
    } else if (last is dom.Element && (last.localName == 'br' || (const {'div', 'p', 'span', 'font'}.contains(last.localName) && _norm(last.text).isEmpty && last.querySelector('img') == null))) {
      last.remove();
    } else if (last is dom.Element && const {'div', 'p', 'span', 'font'}.contains(last.localName)) {
      _dropTrailingEmpty(last);
      return;
    } else {
      return;
    }
  }
}

// --- Plain text ---------------------------------------------------------------

final _originalMessage = RegExp(r'^\s*-{2,}\s*Original Message\s*-{2,}\s*$', caseSensitive: false);
final _fromLine = RegExp(r'^\s*\*?From:\*?\s', caseSensitive: false);
final _sentLine = RegExp(r'^\s*\*?(Sent|Date):\*?\s', caseSensitive: false);

/// [text] without the earlier mail quoted below the new part.
QuoteSplit splitQuotedText(String text, {String? subject}) {
  if (_isForward(subject)) return QuoteSplit(text, hasQuoted: false);
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  int? cut;
  for (var i = 0; i < lines.length && cut == null; i++) {
    final line = lines[i];
    if (_originalMessage.hasMatch(line)) {
      cut = i;
    } else if (_fromLine.hasMatch(line) && lines.skip(i + 1).take(4).any(_sentLine.hasMatch)) {
      cut = i;
    } else if (_wroteLine.hasMatch(line.trim()) && (line.trim().startsWith('On ') || (i > 0 && lines[i - 1].trim().startsWith('On ')))) {
      final start = line.trim().startsWith('On ') ? i : i - 1;
      if (_onlyQuotedAfter(lines, i + 1)) cut = start;
    } else if (line.startsWith('>') && _onlyQuotedAfter(lines, i)) {
      cut = i;
    }
  }
  if (cut == null) return QuoteSplit(text, hasQuoted: false);
  // The forward line can sit just above the headers.
  final hidden = lines.skip(cut < 2 ? 0 : cut - 2).take(8).join(' ');
  if (_startsAsForward(hidden)) return QuoteSplit(text, hasQuoted: false);
  final fresh = lines.take(cut).join('\n').trimRight();
  if (fresh.trim().isEmpty) return QuoteSplit(text, hasQuoted: false);
  return QuoteSplit(fresh, hasQuoted: true);
}

bool _onlyQuotedAfter(List<String> lines, int from) {
  var quoted = 0;
  for (final l in lines.skip(from)) {
    if (l.trim().isEmpty) continue;
    if (!l.startsWith('>')) return false;
    quoted++;
  }
  return quoted > 0;
}
