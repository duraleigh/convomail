/// Outgoing mail: the transport-neutral description of a message the user
/// is sending, and the factory that turns it into MIME (plan M4).
///
/// Structure produced by [MimeFactory.build]:
///
/// ```
/// multipart/mixed                      (only when there are attachments)
///   multipart/related                  (only when there are inline images)
///     multipart/alternative
///       text/plain
///       text/html
///     image/* (Content-ID, inline)
///   application/* (attachment)
/// ```
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart' hide ServerConfig;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'models.dart';

class OutgoingAttachment {
  const OutgoingAttachment({required this.fileName, required this.mimeType, this.path, this.bytes, this.contentId})
      : assert(path != null || bytes != null);

  final String fileName;
  final String mimeType;

  /// Local file to read at build time; or
  final String? path;

  /// bytes already in memory (pasted images).
  final Uint8List? bytes;

  /// Set for inline images referenced from the HTML as `cid:<contentId>`.
  final String? contentId;

  bool get isInline => contentId != null;

  Future<Uint8List> load() async => bytes ?? await File(path!).readAsBytes();

  int get sizeHint {
    if (bytes != null) return bytes!.length;
    final f = File(path!);
    return f.existsSync() ? f.lengthSync() : 0;
  }

  Map<String, dynamic> toJson() => {'fileName': fileName, 'mimeType': mimeType, 'path': path, 'contentId': contentId};

  /// In-memory attachments are not persisted, so they come back null.
  static OutgoingAttachment? fromJson(Map<String, dynamic> j) {
    final path = j['path'] as String?;
    if (path == null) return null;
    return OutgoingAttachment(fileName: j['fileName'] as String, mimeType: j['mimeType'] as String, path: path, contentId: j['contentId'] as String?);
  }
}

class OutgoingMessage {
  const OutgoingMessage({
    required this.from,
    required this.to,
    this.cc = const [],
    this.bcc = const [],
    required this.subject,
    required this.html,
    this.plainText,
    this.attachments = const [],
    this.inReplyTo,
    this.references = const [],
    this.messageId,
    this.date,
  });

  final RemoteAddress from;
  final List<RemoteAddress> to;
  final List<RemoteAddress> cc;
  final List<RemoteAddress> bcc;
  final String subject;

  /// Body HTML fragment (no `<html>` wrapper needed). Local image paths in
  /// `<img src>` are converted to inline CID attachments by the factory.
  final String html;

  /// Optional plain-text alternative; derived from [html] when null.
  final String? plainText;
  final List<OutgoingAttachment> attachments;
  final String? inReplyTo;
  final List<String> references;

  /// Message-ID to use; generated from the sender's domain when null.
  final String? messageId;
  final DateTime? date;

  List<RemoteAddress> get allRecipients => [...to, ...cc, ...bcc];
}

/// Result of a build: the MIME message plus its RFC 822 rendering.
class BuiltMessage {
  const BuiltMessage({required this.message, required this.raw, required this.messageId});
  final MimeMessage message;
  final String raw;

  /// With angle brackets, as it appears in the header.
  final String messageId;
}

abstract final class MimeFactory {
  static Future<BuiltMessage> build(OutgoingMessage m) async {
    final inline = <OutgoingAttachment>[];
    final regular = <OutgoingAttachment>[];
    var html = m.html;

    // Local <img src="C:\..."> or file:// references become CID parts.
    var n = 0;
    for (final src in _localImageSources(html)) {
      final path = _pathFromSrc(src);
      final file = File(path);
      if (!file.existsSync()) continue;
      n++;
      final cid = 'img$n.${DateTime.now().millisecondsSinceEpoch}@convomail';
      inline.add(OutgoingAttachment(
        fileName: file.uri.pathSegments.isEmpty ? 'image$n' : file.uri.pathSegments.last,
        mimeType: MediaType.guessFromFileName(path).text,
        path: path,
        contentId: cid,
      ));
      html = html.replaceAll('src="$src"', 'src="cid:$cid"').replaceAll("src='$src'", 'src="cid:$cid"');
    }
    for (final a in m.attachments) {
      (a.isInline ? inline : regular).add(a);
    }

    final plain = m.plainText ?? htmlToPlainText(html);
    final fullHtml = _wrapHtml(html);

    final builder = MessageBuilder()
      ..from = [MailAddress(m.from.name.isEmpty ? null : m.from.name, m.from.address)]
      ..to = _addresses(m.to)
      ..cc = m.cc.isEmpty ? null : _addresses(m.cc)
      ..bcc = m.bcc.isEmpty ? null : _addresses(m.bcc)
      ..subject = m.subject
      ..date = m.date ?? DateTime.now();

    final messageId = _angle(m.messageId ?? MessageBuilder.createMessageId(_domainOf(m.from.address)));
    builder.messageId = messageId;

    // Choose the outer type and where the alternative body lives.
    late final PartBuilder bodyParent;
    if (regular.isNotEmpty) {
      builder.setContentType(MediaType.fromSubtype(MediaSubtype.multipartMixed));
      bodyParent = inline.isNotEmpty ? builder.addPart(mediaSubtype: MediaSubtype.multipartRelated) : builder;
    } else if (inline.isNotEmpty) {
      builder.setContentType(MediaType.fromSubtype(MediaSubtype.multipartRelated));
      bodyParent = builder;
    } else {
      builder.setContentType(MediaType.fromSubtype(MediaSubtype.multipartAlternative));
      bodyParent = builder;
    }

    final alternative = inline.isEmpty && regular.isEmpty ? builder : bodyParent.addPart(mediaSubtype: MediaSubtype.multipartAlternative);
    alternative
      ..addTextPlain(plain, transferEncoding: TransferEncoding.quotedPrintable)
      ..addTextHtml(fullHtml, transferEncoding: TransferEncoding.quotedPrintable);

    for (final a in inline) {
      final data = await a.load();
      final part = bodyParent.addBinary(
        data,
        MediaType.fromText(a.mimeType),
        filename: a.fileName,
        disposition: ContentDispositionHeader.from(ContentDisposition.inline, filename: a.fileName, size: data.length),
      );
      part.setHeader('Content-ID', '<${a.contentId}>');
    }
    for (final a in regular) {
      final data = await a.load();
      builder.addBinary(data, MediaType.fromText(a.mimeType), filename: a.fileName);
    }

    if (m.inReplyTo != null && m.inReplyTo!.trim().isNotEmpty) builder.setHeader('In-Reply-To', _angle(m.inReplyTo!));
    if (m.references.isNotEmpty) builder.setHeader('References', m.references.map(_angle).join(' '));
    builder.setHeader('X-Mailer', 'ConvoMail');

    final mime = builder.buildMimeMessage();
    return BuiltMessage(message: mime, raw: mime.renderMessage(), messageId: messageId);
  }

  static List<MailAddress> _addresses(List<RemoteAddress> list) => [for (final a in list) MailAddress(a.name.isEmpty ? null : a.name, a.address)];

  static String _angle(String id) {
    final t = id.trim();
    return t.startsWith('<') ? t : '<$t>';
  }

  static String _domainOf(String address) {
    final i = address.lastIndexOf('@');
    return i < 0 ? 'convomail.local' : address.substring(i + 1);
  }

  static bool isLocalSource(String src) {
    final lower = src.toLowerCase();
    return lower.startsWith('file:') || RegExp(r'^[a-z]:[\\/]').hasMatch(lower) || lower.startsWith('/') || lower.startsWith(r'\\');
  }

  static List<String> _localImageSources(String html) {
    final doc = html_parser.parseFragment(html);
    final out = <String>[];
    for (final img in doc.querySelectorAll('img')) {
      final src = img.attributes['src'];
      if (src == null || src.isEmpty) continue;
      if (isLocalSource(src) && !out.contains(src)) out.add(src);
    }
    return out;
  }

  static String _pathFromSrc(String src) {
    if (src.toLowerCase().startsWith('file:')) {
      try {
        return Uri.parse(src).toFilePath(windows: Platform.isWindows);
      } catch (_) {
        return src.substring(src.indexOf(':') + 1).replaceFirst(RegExp(r'^/+'), '');
      }
    }
    return src;
  }

  static String _wrapHtml(String fragment) {
    final t = fragment.trimLeft().toLowerCase();
    if (t.startsWith('<!doctype') || t.startsWith('<html')) return fragment;
    return '<!DOCTYPE html><html><head><meta charset="utf-8"></head>'
        '<body style="font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;font-size:15px;line-height:1.45;color:#1b1b1f">'
        '$fragment</body></html>';
  }

  /// Plain-text rendering of an HTML fragment: block elements become line
  /// breaks, list items get a marker, links keep their URL, blockquotes are
  /// prefixed with `> `.
  static String htmlToPlainText(String html) {
    final doc = html_parser.parseFragment(html);
    final lines = <StringBuffer>[StringBuffer()];
    var quote = 0;

    void newLine() {
      lines.add(StringBuffer('> ' * quote));
    }

    bool lineIsBlank() => lines.last.toString().trim().replaceAll('>', '').isEmpty;

    void walk(dom.Node node, {String itemPrefix = ''}) {
      if (node is dom.Text) {
        final t = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (t.trim().isEmpty && lineIsBlank()) return;
        lines.last.write(t);
        return;
      }
      if (node is! dom.Element) return;
      final name = node.localName?.toLowerCase() ?? '';
      if (name == 'style' || name == 'script' || name == 'head' || name == 'title') return;
      const blocks = {'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'ul', 'ol', 'blockquote', 'table', 'tr', 'pre', 'section', 'article', 'header', 'footer'};
      if (name == 'br') {
        newLine();
        return;
      }
      if (name == 'hr') {
        if (!lineIsBlank()) newLine();
        lines.last.write('----------');
        newLine();
        return;
      }
      final isBlock = blocks.contains(name);
      if (isBlock && !lineIsBlank()) newLine();
      if (name == 'blockquote') {
        quote++;
        if (lineIsBlank()) {
          lines.removeLast();
          newLine();
        }
      }
      if (name == 'li') lines.last.write(itemPrefix.isEmpty ? '- ' : itemPrefix);
      var i = 1;
      for (final child in node.nodes) {
        final prefix = name == 'ol' ? '${i++}. ' : (name == 'ul' ? '- ' : itemPrefix);
        walk(child, itemPrefix: prefix);
      }
      if (name == 'a') {
        final href = node.attributes['href'];
        final text = node.text.trim();
        if (href != null && href.isNotEmpty && href != text && href != 'mailto:$text') lines.last.write(' <$href>');
      }
      if (name == 'blockquote') quote--;
      if (isBlock) newLine();
      if (name == 'p' || name.startsWith('h') && name.length == 2 || name == 'blockquote') newLine();
    }

    for (final n in doc.nodes) {
      walk(n);
    }
    final text = lines.map((b) => b.toString().trimRight()).join('\n');
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
