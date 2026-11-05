import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../store/database.dart';

// Signatures: an editor document per address (text, links, pictures), or the
// older plain text. Put at the end of a new message, editable before sending;
// pictures are local files, sent inside the message.

/// The signature's blocks, ready to go into a message. Empty when there is
/// none.
List<Node> signatureNodes(Identity identity) {
  final json = identity.signatureJson;
  if (json != null && json.isNotEmpty) {
    try {
      final doc = Document.fromJson(jsonDecode(json) as Map<String, dynamic>);
      return trimEmpty([for (final n in doc.root.children) n.deepCopy()]);
    } catch (_) {
      // Unreadable document: fall back to the text.
    }
  }
  final text = identity.signature.trim();
  if (text.isEmpty) return const [];
  return [for (final line in text.split('\n')) paragraphNode(text: line)];
}

/// A document holding the signature, for the signature editor.
Document signatureDocument(Identity identity) {
  final doc = Document.blank();
  final nodes = signatureNodes(identity);
  if (nodes.isEmpty) {
    doc.root.insert(paragraphNode());
  } else {
    for (final n in nodes) {
      doc.root.insert(n);
    }
  }
  return doc;
}

bool isEmptyNode(Node n) => n.type == ParagraphBlockKeys.type && (n.delta?.toPlainText().trim() ?? '').isEmpty && n.children.isEmpty;

/// Drops blank lines at both ends and runs of blank lines inside.
List<Node> trimEmpty(List<Node> nodes) {
  final out = <Node>[];
  for (final n in nodes) {
    if (isEmptyNode(n) && (out.isEmpty || isEmptyNode(out.last))) continue;
    out.add(n);
  }
  while (out.isNotEmpty && isEmptyNode(out.last)) {
    out.removeLast();
  }
  return out;
}

/// The plain text of [nodes], one line per block.
String nodesPlainText(Iterable<Node> nodes) => [for (final n in nodes) if (n.delta != null) n.delta!.toPlainText()].join('\n').trim();

/// The inner HTML of the sender's own Gmail signature in a message they
/// sent, or null. Signatures inside quoted mail belong to someone else.
String? gmailSignatureHtml(String html) {
  final doc = html_parser.parse(html);
  for (final el in doc.querySelectorAll('.gmail_signature')) {
    if (_inQuote(el)) continue;
    if (el.text.trim().isEmpty && el.querySelector('img') == null) continue;
    return el.innerHtml;
  }
  return null;
}

bool _inQuote(dom.Element e) {
  for (var p = e.parent; p != null; p = p.parent) {
    if (p.localName == 'blockquote') return true;
    if (p.classes.any((c) => c.startsWith('gmail_quote'))) return true;
  }
  return false;
}

/// Converts signature HTML to editor blocks: text with bold, italic,
/// underline and links, one block per line, and pictures. [image] maps a
/// picture's `src` to what the block should show (a local path), or null
/// to leave the picture out.
List<Node> signatureNodesFromHtml(String html, {required String? Function(String src) image}) {
  final out = <Node>[];
  var delta = Delta();

  void flush() {
    final text = delta.toPlainText();
    if (text.trim().isEmpty) {
      out.add(paragraphNode());
    } else {
      out.add(paragraphNode(delta: _trimDelta(delta)));
    }
    delta = Delta();
  }

  void walk(dom.Node node, Map<String, Object> attrs) {
    if (node is dom.Text) {
      final t = node.text.replaceAll(RegExp(r'\s+'), ' ');
      if (t.isEmpty) return;
      if (delta.isEmpty && t.trim().isEmpty) return;
      delta.insert(t, attributes: attrs.isEmpty ? null : Map.of(attrs));
      return;
    }
    if (node is! dom.Element) {
      for (final c in node.nodes) {
        walk(c, attrs);
      }
      return;
    }
    final tag = node.localName ?? '';
    if (const {'style', 'script', 'head', 'title', 'meta'}.contains(tag)) return;
    if (tag == 'br') {
      flush();
      return;
    }
    if (tag == 'img') {
      final src = node.attributes['src'];
      final path = src == null ? null : image(src);
      if (path == null) return;
      if (delta.isNotEmpty) flush();
      out.add(imageNode(url: path, align: 'left', width: _size(node, 'width'), height: _size(node, 'height')));
      return;
    }
    final style = (node.attributes['style'] ?? '').toLowerCase().replaceAll(' ', '');
    final next = Map<String, Object>.of(attrs);
    if (tag == 'b' || tag == 'strong' || style.contains('font-weight:bold') || style.contains('font-weight:700')) next[AppFlowyRichTextKeys.bold] = true;
    if (tag == 'i' || tag == 'em' || style.contains('font-style:italic')) next[AppFlowyRichTextKeys.italic] = true;
    if (tag == 'u') next[AppFlowyRichTextKeys.underline] = true;
    if (tag == 'a' && (node.attributes['href'] ?? '').isNotEmpty) next[AppFlowyRichTextKeys.href] = node.attributes['href']!;
    final block = const {'div', 'p', 'tr', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'table', 'blockquote', 'ul', 'ol'}.contains(tag);
    if (block && delta.isNotEmpty) flush();
    for (final c in node.nodes) {
      walk(c, next);
    }
    if (block && delta.isNotEmpty) flush();
  }

  final body = html_parser.parseFragment(html);
  walk(body, const {});
  if (delta.isNotEmpty) flush();
  return trimEmpty(out);
}

Delta _trimDelta(Delta d) {
  final ops = d.toJson();
  if (ops.isEmpty) return d;
  final first = ops.first as Map<String, dynamic>;
  final last = ops.last as Map<String, dynamic>;
  if (first['insert'] is String) first['insert'] = (first['insert'] as String).trimLeft();
  if (last['insert'] is String) last['insert'] = (last['insert'] as String).trimRight();
  return Delta.fromJson([for (final o in ops) if ((o as Map)['insert'] != '') o]);
}

double? _size(dom.Element img, String which) {
  final attr = double.tryParse((img.attributes[which] ?? '').replaceAll('px', '').trim());
  if (attr != null && attr > 0) return attr;
  final m = RegExp('(?:^|;)\\s*$which\\s*:\\s*([0-9.]+)px').firstMatch(img.attributes['style'] ?? '');
  return m == null ? null : double.tryParse(m.group(1)!);
}
