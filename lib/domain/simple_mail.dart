import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

// Simple emails (personal mail: lines of text, bold, links, lists, quotes,
// pictures) are drawn straight into the conversation in Précis's own
// colours and font. Designed emails (newsletters: layout tables, columns,
// coloured panels, fixed widths) keep their own look in the browser box.
// This file decides which is which and turns a simple one into blocks.

/// A piece of a line: text with its style, or a picture.
class MailSpan {
  const MailSpan(this.text, {this.bold = false, this.italic = false, this.underline = false, this.strike = false, this.mono = false, this.mark = false, this.href}) : image = null;
  const MailSpan.image(MailImage this.image, {this.href})
      : text = '',
        bold = false,
        italic = false,
        underline = false,
        strike = false,
        mono = false,
        mark = false;

  final String text;
  final bool bold, italic, underline, strike, mono;

  /// A search match.
  final bool mark;
  final String? href;
  final MailImage? image;

  MailSpan withText(String t) => MailSpan(t, bold: bold, italic: italic, underline: underline, strike: strike, mono: mono, mark: mark, href: href);
}

/// A picture in a simple email: its bytes when it came inside the message,
/// its address when remote pictures are allowed, or blocked.
class MailImage {
  const MailImage({this.bytes, this.url, this.width, this.height, this.alt = '', this.blocked = false});
  final Uint8List? bytes;
  final String? url;
  final double? width, height;
  final String alt;
  final bool blocked;
}

sealed class MailBlock {
  const MailBlock();
}

/// One line or paragraph. Empty [spans] is a blank line.
class MailText extends MailBlock {
  const MailText(this.spans, {this.heading = 0, this.spaceAfter = false});
  final List<MailSpan> spans;

  /// 1–3 for headings, 0 for body text.
  final int heading;

  /// A paragraph gap follows (after <p>, headings).
  final bool spaceAfter;

  String get plainText => spans.map((s) => s.text).join();
}

/// Quoted text (a reply's earlier mail, or a quote).
class MailQuote extends MailBlock {
  const MailQuote(this.children);
  final List<MailBlock> children;
}

/// A list item with its marker ("•" or "3.").
class MailListItem extends MailBlock {
  const MailListItem(this.marker, this.children);
  final String marker;
  final List<MailBlock> children;
}

/// A small table of side-by-side cells (a signature's logo beside the name,
/// say), drawn as columns.
class MailColumns extends MailBlock {
  const MailColumns(this.cells);
  final List<List<MailBlock>> cells;
}

class MailRule extends MailBlock {
  const MailRule();
}

/// The blocks of a sanitized email body ([bodyInner]: the inside of its
/// `<body>`), or null when it is a designed email that needs its own look.
List<MailBlock>? simpleMailBlocks(String bodyInner) {
  final root = html_parser.parseFragment(bodyInner);
  if (_isDesigned(root)) return null;
  final b = _Builder();
  b.walkChildren(root, const _Style());
  b.flush();
  final blocks = _tidy(b.out);
  return blocks.isEmpty ? null : blocks;
}

/// Whether an HTML body shows anything: text or a picture. Some mail sends
/// an empty HTML part with the words only in the plain-text part.
bool htmlHasContent(String html) {
  final doc = html_parser.parse(html);
  final body = doc.body;
  if (body == null) return false;
  return body.text.trim().isNotEmpty || body.querySelector('img') != null;
}

// --- Telling simple from designed ------------------------------------------

const _inlineTags = {'span', 'font', 'b', 'strong', 'i', 'em', 'u', 'mark', 'small', 'big', 'sub', 'sup', 's', 'strike', 'del', 'ins', 'code', 'tt', 'abbr', 'cite', 'q', 'label'};
final _layoutCss = RegExp(r'(?:^|;)\s*(?:float\s*:\s*(?:left|right)|position\s*:\s*(?:absolute|fixed|relative)|display\s*:\s*(?:flex|grid|inline-flex))', caseSensitive: false);
final _cssWidth = RegExp(r'(?:^|;)\s*(?:min-)?width\s*:\s*(\d+)px', caseSensitive: false);
final _cssBackground = RegExp(r'(?:^|;)\s*background(?:-color|-image)?\s*:\s*([^;]+)', caseSensitive: false);

bool _isDesigned(dom.Node root) {
  var images = 0;
  var links = 0;
  // Outlook puts the earlier mail after its "From: … Sent: …" block rather
  // than in a quote; everything from there on is quoted.
  var outlookQuote = false;
  for (final el in _elements(root)) {
    final tag = el.localName ?? '';
    final style = el.attributes['style'] ?? '';
    final id = el.id;
    if (id.endsWith('divRplyFwdMsg') || id.endsWith('appendonsend')) outlookQuote = true;
    // Only the new message decides: earlier mail quoted below a reply (an
    // old newsletter, a fancy signature) does not, nor does a link preview.
    if (outlookQuote || _inQuote(el) || _inLinkPreview(el)) continue;
    if (_hidden(style)) continue;
    if (tag == 'center') return true;
    if (el.attributes.containsKey('bgcolor')) return true;
    // Side-by-side cells: a small table (a signature) is drawn as columns;
    // a big one is a page layout.
    if (tag == 'table') {
      final widest = el.querySelectorAll('tr').map((r) => _cells(r).length).fold(0, (a, b) => a > b ? a : b);
      final textLength = el.text.trim().length;
      // A table inside a table is a page layout, unless it is small (a
      // banner or signature: an icon beside a line of text).
      if (widest > 1 && (widest > 3 || textLength > 500 || (el.querySelector('table') != null && textLength > 200))) return true;
    }
    // Emoji and small icons are not pictures that make a layout.
    if (tag == 'img') {
      if (!_tiny(el) && !_isEmoji(el) && !_icon(el)) images++;
      continue;
    }
    if (tag == 'a') links++;
    // Outlook writes lists as flex boxes; they are still lists.
    if (tag != 'ul' && tag != 'ol' && tag != 'li' && _layoutCss.hasMatch(style)) return true;
    final w = _cssWidth.firstMatch(style);
    if (w != null && int.parse(w.group(1)!) >= 400) return true;
    final wAttr = int.tryParse((el.attributes['width'] ?? '').replaceAll('px', '').trim());
    if (wAttr != null && wAttr >= 400 && (tag == 'table' || tag == 'td' || tag == 'th' || tag == 'div')) return true;
    if (!_inlineTags.contains(tag)) {
      final bg = _cssBackground.firstMatch(style);
      if (bg != null && !_plainBackground(bg.group(1)!)) return true;
    }
  }
  return images > 8 || links > 30;
}

/// Pale named colours: banners and highlights, not a designed panel.
const _paleNames = {
  'whitesmoke', 'lightgrey', 'lightgray', 'gainsboro', 'aliceblue', 'ghostwhite', 'snow', 'ivory', 'azure', 'mintcream', 'honeydew', 'seashell', 'floralwhite',
  'oldlace', 'linen', 'lavenderblush', 'lavender', 'beige', 'lightyellow', 'lightcyan', 'lightblue', 'cornsilk', 'lemonchiffon', 'papayawhip', 'mistyrose',
};

/// A hex or rgb() colour whose every channel is pale.
bool _pale(String w) {
  List<int>? ch;
  final hex = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$').firstMatch(w);
  if (hex != null) {
    var h = hex.group(1)!;
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    ch = [for (var i = 0; i < 6; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];
  }
  final rgb = RegExp(r'^rgba?\((\d+),(\d+),(\d+)').firstMatch(w);
  if (rgb != null) ch = [for (var i = 1; i <= 3; i++) int.parse(rgb.group(i)!)];
  return ch != null && ch.every((c) => c >= 0xD0);
}

/// White, see-through or pale backgrounds change nothing that matters.
bool _plainBackground(String v) {
  final s = v.trim().toLowerCase().replaceAll('!important', '').trim();
  if (s.contains('url(')) return false;
  if (s.contains('transparent') || RegExp(r'rgba\([^)]*,\s*0(?:\.0+)?\s*\)').hasMatch(s)) return true;
  final words = s
      .replaceAllMapped(RegExp(r'\([^)]*\)'), (m) => m.group(0)!.replaceAll(' ', ''))
      .replaceAll(RegExp(r'\d+%|\b0\b|no-repeat|repeat|scroll|fixed|center|top|left|none'), ' ')
      .trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return words.isEmpty ||
      words.every((w) => const {'white', 'inherit', 'initial', 'unset', 'revert', 'window'}.contains(w) || _paleNames.contains(w) || _pale(w));
}

/// A row's cells that hold something.
List<dom.Element> _cells(dom.Element tr) =>
    [for (final c in tr.children) if ((c.localName == 'td' || c.localName == 'th') && (c.text.trim().isNotEmpty || c.querySelector('img') != null)) c];

Iterable<dom.Element> _elements(dom.Node n) sync* {
  for (final c in n.nodes) {
    if (c is dom.Element) {
      yield c;
      yield* _elements(c);
    }
  }
}

bool _hidden(String style) {
  final s = style.toLowerCase().replaceAll(' ', '');
  return s.contains('display:none') || s.contains('visibility:hidden') || s.contains('max-height:0') || (s.contains('font-size:0') && !s.contains('font-size:0.'));
}

double? _dim(dom.Element img, String which) {
  final attr = double.tryParse((img.attributes[which] ?? '').replaceAll('px', '').trim());
  if (attr != null && attr > 0) return attr;
  final m = RegExp('(?:^|;)\\s*$which\\s*:\\s*([0-9.]+)px').firstMatch(img.attributes['style'] ?? '');
  return m == null ? null : double.tryParse(m.group(1)!);
}

bool _inQuote(dom.Element el) {
  for (var p = el.parent; p != null; p = p.parent) {
    if (p.localName == 'blockquote' || p.classes.any((c) => c == 'gmail_quote' || c.endsWith('_gmail_quote'))) return true;
  }
  return false;
}

/// Apple Mail's preview card for a pasted link.
bool _inLinkPreview(dom.Element el) {
  for (dom.Element? p = el; p != null; p = p.parent) {
    if (p.classes.any((c) => c.startsWith('lp-rich-link') || c == 'apple-rich-link')) return true;
  }
  return false;
}

/// Gmail's emoji pictures, drawn as the emoji itself.
bool _isEmoji(dom.Element img) {
  final alt = (img.attributes['alt'] ?? '').trim();
  final w = _dim(img, 'width');
  return img.attributes.containsKey('data-emoji') || (alt.isNotEmpty && alt.runes.length <= 2 && alt.runes.first > 0x2000 && (w == null || w <= 32));
}

/// A small icon (a signature's social links, say).
bool _icon(dom.Element img) {
  final w = _dim(img, 'width');
  final h = _dim(img, 'height');
  return (w != null && w <= 48) && (h == null || h <= 48);
}

bool _tiny(dom.Element img) {
  final w = _dim(img, 'width');
  final h = _dim(img, 'height');
  if (w != null && h != null && w <= 2 && h <= 2) return true;
  return (img.attributes['src'] ?? '').startsWith('data:image/gif;base64,R0lGODlhAQABAAAAACw=');
}

// --- Building blocks --------------------------------------------------------

class _Style {
  const _Style({this.bold = false, this.italic = false, this.underline = false, this.strike = false, this.mono = false, this.mark = false, this.href, this.pre = false});
  final bool bold, italic, underline, strike, mono, mark, pre;
  final String? href;

  _Style copyWith({bool? bold, bool? italic, bool? underline, bool? strike, bool? mono, bool? mark, String? href, bool? pre}) => _Style(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        strike: strike ?? this.strike,
        mono: mono ?? this.mono,
        mark: mark ?? this.mark,
        href: href ?? this.href,
        pre: pre ?? this.pre,
      );
}

const _blockTags = {
  'div', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'table', 'tbody', 'thead', 'tfoot', 'tr', 'td', 'th', 'section', 'article', 'header', 'footer',
  'main', 'aside', 'nav', 'address', 'dl', 'dt', 'dd', 'figure', 'figcaption', 'pre', 'body', 'html',
};
final _spaces = RegExp(r'[ \t\r\n\f]+');

class _Builder {
  final List<MailBlock> out = [];
  List<MailSpan> _line = [];

  String get _lineText => _line.map((s) => s.text).join();

  /// Ends the current line. A line of only a line break or a no-break space
  /// is a deliberate blank line; spaces from the source's own layout are not.
  void flush({int heading = 0, bool spaceAfter = false}) {
    final line = _line;
    _line = [];
    final hasImage = line.any((s) => s.image != null);
    final text = line.map((s) => s.text).join();
    if (!hasImage && text.replaceAll('\n', '').replaceAll(' ', '').trim().isEmpty) {
      if (text.contains('\n') || text.contains(' ')) out.add(const MailText([]));
      return;
    }
    // A closing line break is the end of the line itself.
    final spans = [...line];
    while (spans.isNotEmpty && spans.last.image == null && spans.last.text.endsWith(' ')) {
      spans[spans.length - 1] = spans.last.withText(spans.last.text.trimRight());
      if (spans.last.text.isEmpty) spans.removeLast();
    }
    if (spans.isNotEmpty && spans.last.image == null && spans.last.text.endsWith('\n')) {
      final t = spans.last.text;
      spans[spans.length - 1] = spans.last.withText(t.substring(0, t.length - 1));
      if (spans.last.text.isEmpty) spans.removeLast();
    }
    out.add(MailText(spans, heading: heading, spaceAfter: spaceAfter));
  }

  void _text(String raw, _Style s) {
    var t = s.pre ? raw.replaceAll('\r\n', '\n') : raw.replaceAll(_spaces, ' ');
    if (t.isEmpty) return;
    final current = _lineText;
    if (!s.pre && (current.isEmpty || current.endsWith('\n') || current.endsWith(' '))) t = t.replaceFirst(RegExp('^ +'), '');
    if (t.isEmpty) return;
    _line.add(MailSpan(t, bold: s.bold, italic: s.italic, underline: s.underline, strike: s.strike, mono: s.mono || s.pre, mark: s.mark, href: s.href));
  }

  void _lineBreak(_Style s) {
    if (_line.isNotEmpty && _line.last.image == null && _line.last.text.endsWith(' ')) {
      final last = _line.removeLast();
      final t = last.text.trimRight();
      if (t.isNotEmpty) _line.add(last.withText(t));
    }
    _line.add(MailSpan('\n', bold: s.bold, italic: s.italic, mono: s.mono));
  }

  void walkChildren(dom.Node node, _Style s) {
    for (final c in node.nodes) {
      walk(c, s);
    }
  }

  void walk(dom.Node node, _Style s) {
    if (node is dom.Text) {
      _text(node.text, s);
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName ?? '';
    if (const {'style', 'script', 'head', 'title', 'meta', 'link', 'xml'}.contains(tag)) return;
    final style = node.attributes['style'] ?? '';
    if (_hidden(style)) return;
    final css = style.toLowerCase().replaceAll(' ', '');

    switch (tag) {
      case 'br':
        _lineBreak(s);
        return;
      case 'hr':
        flush();
        out.add(const MailRule());
        return;
      case 'img':
        _image(node, s);
        return;
      case 'blockquote':
        flush();
        final inner = _Builder();
        inner.walkChildren(node, s);
        inner.flush();
        final kids = _tidy(inner.out);
        if (kids.isNotEmpty) out.add(MailQuote(kids));
        return;
      case 'table' when node.querySelectorAll('tr').any((r) => _cells(r).length > 1):
        flush();
        for (final tr in node.querySelectorAll('tr')) {
          final cells = _cells(tr);
          if (cells.length == 1) {
            walk(cells.single, s);
            flush();
            continue;
          }
          final built = <List<MailBlock>>[];
          for (final c in cells) {
            final inner = _Builder();
            inner.walkChildren(c, s);
            inner.flush();
            final kids = _tidy(inner.out);
            if (kids.isNotEmpty) built.add(kids);
          }
          if (built.length == 1) {
            out.addAll(built.single);
          } else if (built.isNotEmpty) {
            out.add(MailColumns(built));
          }
        }
        return;
      case 'ul' || 'ol':
        flush();
        var n = int.tryParse(node.attributes['start'] ?? '') ?? 1;
        for (final li in node.children) {
          final inner = _Builder();
          if (li.localName == 'li') {
            inner.walkChildren(li, s);
          } else {
            inner.walk(li, s);
          }
          inner.flush();
          final kids = _tidy(inner.out);
          if (kids.isEmpty) continue;
          out.add(MailListItem(tag == 'ol' ? '${n++}.' : '•', kids));
        }
        return;
    }

    var next = s;
    if (tag == 'b' || tag == 'strong' || css.contains('font-weight:bold') || css.contains('font-weight:700') || css.contains('font-weight:600')) next = next.copyWith(bold: true);
    if (tag == 'i' || tag == 'em' || css.contains('font-style:italic')) next = next.copyWith(italic: true);
    if (tag == 'u' || css.contains('text-decoration:underline')) next = next.copyWith(underline: true);
    if (tag == 's' || tag == 'strike' || tag == 'del' || css.contains('line-through')) next = next.copyWith(strike: true);
    if (tag == 'code' || tag == 'tt') next = next.copyWith(mono: true);
    if (tag == 'pre') next = next.copyWith(pre: true);
    if (tag == 'mark' && node.classes.contains('cm-hl')) next = next.copyWith(mark: true);
    if (tag == 'a') {
      final href = node.attributes['href'] ?? '';
      if (href.isNotEmpty) next = next.copyWith(href: href);
    }

    final heading = switch (tag) { 'h1' => 1, 'h2' => 2, 'h3' => 3, 'h4' || 'h5' || 'h6' => 3, _ => 0 };
    // Outlook writes every line as its own <p class=MsoNormal> with no gap.
    final paragraph = heading > 0 || tag == 'pre' || (tag == 'p' && !node.classes.any((c) => c.startsWith('Mso')));
    final block = _blockTags.contains(tag) || tag == 'li';
    if (block) flush();
    walkChildren(node, next);
    if (block) flush(heading: heading, spaceAfter: paragraph);
  }

  void _image(dom.Element img, _Style s) {
    if (_tiny(img)) return;
    final src = img.attributes['src'] ?? '';
    final alt = (img.attributes['alt'] ?? '').trim();
    final w = _dim(img, 'width');
    // Gmail's emoji pictures: the emoji itself, as text.
    if (_isEmoji(img)) {
      if (alt.isNotEmpty) _text(alt, s);
      return;
    }
    final blocked = img.classes.contains('cm-blocked') || img.attributes.containsKey('data-blocked-src');
    Uint8List? bytes;
    String? url;
    if (!blocked) {
      if (src.startsWith('data:image/')) {
        try {
          bytes = UriData.parse(src).contentAsBytes();
        } catch (_) {
          return;
        }
      } else if (src.startsWith('https://') || src.startsWith('http://')) {
        url = src;
      } else {
        return;
      }
    }
    _line.add(MailSpan.image(
      MailImage(bytes: bytes, url: url, width: w, height: _dim(img, 'height'), alt: alt == 'Image blocked' ? '' : alt, blocked: blocked),
      href: s.href,
    ));
  }
}

/// Drops blank lines at the ends and runs of more than one blank line.
List<MailBlock> _tidy(List<MailBlock> blocks) {
  bool blank(MailBlock b) => b is MailText && b.spans.isEmpty;
  final out = <MailBlock>[];
  for (final b in blocks) {
    if (blank(b) && (out.isEmpty || blank(out.last))) continue;
    out.add(b);
  }
  while (out.isNotEmpty && blank(out.last)) {
    out.removeLast();
  }
  return out;
}

/// The text of [blocks], one line per block (for tests and copying).
String mailBlocksText(List<MailBlock> blocks) => [
      for (final b in blocks)
        switch (b) {
          MailText() => b.plainText,
          MailQuote() => mailBlocksText(b.children).split('\n').map((l) => '> $l').join('\n'),
          MailListItem() => '${b.marker} ${mailBlocksText(b.children)}',
          MailColumns() => b.cells.map(mailBlocksText).join(' | '),
          MailRule() => '---',
        },
    ].join('\n');

/// Base64 bytes as a data: URI (used by tests).
String imageDataUri(String mime, List<int> bytes) => 'data:$mime;base64,${base64Encode(bytes)}';
