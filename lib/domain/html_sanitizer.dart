/// HTML email sanitizer and remote-content blocker (spec 4.13, plan M3).
///
/// Runs before anything reaches the renderer. Removes active content
/// (scripts, frames, forms, event handlers, dangerous URLs), rewrites
/// remote images to placeholders unless the user allowed them for this
/// message, records the remote hosts that were blocked or loaded, and
/// wraps the result in a document with a strict Content-Security-Policy so
/// the renderer cannot fetch anything the sanitizer missed.
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

class RemoteRef {
  const RemoteRef({required this.host, required this.url, required this.isTracker});
  final String host;
  final String url;

  /// 1×1 / hidden image, or a host matching known tracking patterns.
  final bool isTracker;
}

class SanitizedHtml {
  const SanitizedHtml({required this.html, required this.remote, required this.allowedRemote, this.bodyInner = ''});

  /// A complete HTML document ready for the renderer.
  final String html;

  /// The sanitized `<body>` contents alone, for quoting in replies.
  final String bodyInner;

  /// Every remote reference found. Blocked when [allowedRemote] is false.
  final List<RemoteRef> remote;
  final bool allowedRemote;

  bool get hasRemoteContent => remote.isNotEmpty;
  int get blockedCount => allowedRemote ? 0 : remote.length;
  Set<String> get hosts => {for (final r in remote) r.host};
  Set<String> get trackerHosts => {for (final r in remote) if (r.isTracker) r.host};
}

class HtmlSanitizer {
  const HtmlSanitizer();

  static const _removeEntirely = {
    'script', 'iframe', 'frame', 'frameset', 'object', 'embed', 'applet', 'form', 'input', 'button', 'textarea', 'select',
    'option', 'link', 'meta', 'base', 'noscript', 'template', 'video', 'audio', 'source', 'track', 'svg', 'math', 'canvas',
    'dialog', 'portal', 'slot',
  };
  static const _urlAttrs = {'href', 'src', 'srcset', 'background', 'poster', 'action', 'formaction', 'data', 'xlink:href', 'longdesc', 'cite', 'usemap', 'lowsrc', 'dynsrc'};
  static final _trackerHostPattern = RegExp(
    r'(^|\.)(list-manage\.com|mailchimp\.com|mandrillapp\.com|sendgrid\.net|mailgun\.(org|net)|hubspot(links)?\.com|hs-analytics\.net|exacttarget\.com|sfmc-content\.com|sparkpostmail\.com|mixpanel\.com|google-analytics\.com|doubleclick\.net|braze\.com|klaviyo\.com|customeriomail\.com|mailtrack\.io|bananatag\.com|yesware\.com|streak\.com|rs6\.net|constantcontact\.com|cmail\d*\.com|createsend\d*\.com|awstrack\.me|emltrk\.com|mailstat\.us|litmus\.com|open\.|click\.|track\.|pixel\.|beacon\.|links\.)',
    caseSensitive: false,
  );
  /// Placeholder shown where a remote image was blocked: a percent-encoded
  /// SVG data URI (no raw markup inside the attribute).
  static final _placeholderSvg = 'data:image/svg+xml;utf8,${Uri.encodeComponent("<svg xmlns='http://www.w3.org/2000/svg' width='120' height='24'><rect width='120' height='24' rx='6' fill='#E9E7EF'/><text x='60' y='16' font-family='Segoe UI,sans-serif' font-size='11' fill='#46464F' text-anchor='middle'>Image blocked</text></svg>")}';

  SanitizedHtml sanitize(String rawHtml, {bool allowRemoteImages = false, String? Function(String cid)? resolveCid}) {
    final doc = html_parser.parse(rawHtml);
    final remote = <RemoteRef>[];

    // 1. Remove active/embedding elements outright. Walk by local name:
    // elements in foreign namespaces (svg, math) are not matched by tag
    // selectors.
    for (final el in doc.querySelectorAll('*').toList()) {
      if (_removeEntirely.contains(el.localName?.toLowerCase())) el.remove();
    }

    // 2. Walk every element: attributes, URLs, styles.
    for (final el in doc.querySelectorAll('*')) {
      for (final name in el.attributes.keys.toList()) {
        final lname = name.toString().toLowerCase();
        final value = el.attributes[name] ?? '';
        if (lname.startsWith('on')) {
          el.attributes.remove(name);
          continue;
        }
        if (_urlAttrs.contains(lname) && _isDangerousUrl(value)) {
          el.attributes.remove(name);
          continue;
        }
        if (lname == 'srcset' || lname == 'lowsrc' || lname == 'dynsrc' || lname == 'ping') {
          el.attributes.remove(name);
          continue;
        }
        if (lname == 'style') {
          el.attributes[name] = _scrubCss(value, allowRemote: allowRemoteImages, remote: remote, isTracker: false);
        }
      }

      final tag = el.localName?.toLowerCase();
      if (tag == 'img') _handleImage(el, allowRemoteImages, remote, resolveCid);
      if (tag == 'a') {
        el.attributes['target'] = '_blank';
        el.attributes['rel'] = 'noopener noreferrer';
      }
      final bg = el.attributes['background'];
      if (bg != null) {
        final host = _hostOf(bg);
        if (host != null) {
          remote.add(RemoteRef(host: host, url: bg, isTracker: _looksLikeTrackerHost(host)));
          if (!allowRemoteImages) el.attributes.remove('background');
        }
      }
    }

    // 3. Style blocks: scrub remote url() and @import.
    for (final style in doc.querySelectorAll('style')) {
      style.text = _scrubCss(style.text, allowRemote: allowRemoteImages, remote: remote, isTracker: false);
    }

    final bodyInner = doc.body?.innerHtml ?? '';
    return SanitizedHtml(html: _wrap(bodyInner, allowRemoteImages), remote: remote, allowedRemote: allowRemoteImages, bodyInner: bodyInner);
  }

  void _handleImage(Element img, bool allow, List<RemoteRef> remote, String? Function(String cid)? resolveCid) {
    final src = img.attributes['src']?.trim() ?? '';
    if (src.isEmpty) return;
    final lower = src.toLowerCase();
    if (lower.startsWith('cid:')) {
      final resolved = resolveCid?.call(src.substring(4));
      if (resolved != null) img.attributes['src'] = resolved;
      return;
    }
    if (lower.startsWith('data:image/')) return;
    final host = _hostOf(src);
    if (host == null) {
      img.attributes.remove('src');
      return;
    }
    final tiny = _isTiny(img);
    remote.add(RemoteRef(host: host, url: src, isTracker: tiny || _looksLikeTrackerHost(host)));
    if (!allow) {
      img.attributes['data-blocked-src'] = src;
      img.attributes['src'] = tiny ? 'data:image/gif;base64,R0lGODlhAQABAAAAACw=' : _placeholderSvg;
      if (!tiny) {
        img.attributes['alt'] = img.attributes['alt']?.isNotEmpty == true ? img.attributes['alt']! : 'Image blocked';
        img.classes.add('cm-blocked');
        img.attributes.remove('srcset');
      }
    }
  }

  static bool _isTiny(Element img) {
    int? dim(String? v) => v == null ? null : int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
    final w = dim(img.attributes['width']);
    final h = dim(img.attributes['height']);
    if (w != null && h != null && w <= 2 && h <= 2) return true;
    final style = img.attributes['style']?.toLowerCase() ?? '';
    return style.contains('display:none') || style.contains('display: none') || style.contains('visibility:hidden') || style.contains('visibility: hidden');
  }

  static bool _looksLikeTrackerHost(String host) => _trackerHostPattern.hasMatch(host);

  static bool _isDangerousUrl(String value) {
    final v = value.trim().toLowerCase().replaceAll(RegExp(r'[\s\u0000-\u001f]'), '');
    return v.startsWith('javascript:') || v.startsWith('vbscript:') || v.startsWith('data:text/html') || v.startsWith('data:application') || v.startsWith('file:');
  }

  static String? _hostOf(String url) {
    var u = url.trim();
    if (u.startsWith('//')) u = 'https:$u';
    final lower = u.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) return null;
    final parsed = Uri.tryParse(u);
    final host = parsed?.host.toLowerCase();
    return (host == null || host.isEmpty) ? null : host;
  }

  static final _cssUrl = RegExp(r'''url\(\s*(['"]?)([^'")]+)\1\s*\)''', caseSensitive: false);
  static final _cssImport = RegExp(r'@import[^;]*;?', caseSensitive: false);
  static final _cssDangerous = RegExp(r'(expression\s*\(|behavior\s*:|-moz-binding\s*:|javascript:)', caseSensitive: false);

  static String _scrubCss(String css, {required bool allowRemote, required List<RemoteRef> remote, required bool isTracker}) {
    var out = css.replaceAll(_cssImport, '');
    out = out.replaceAll(_cssDangerous, '');
    out = out.replaceAllMapped(_cssUrl, (m) {
      final target = m.group(2)!.trim();
      final host = _hostOf(target);
      if (host == null) {
        return target.toLowerCase().startsWith('data:image/') ? m.group(0)! : 'none';
      }
      remote.add(RemoteRef(host: host, url: target, isTracker: _looksLikeTrackerHost(host)));
      return allowRemote ? m.group(0)! : 'none';
    });
    return out;
  }

  static String _wrap(String bodyInner, bool allowRemote) {
    final img = allowRemote ? 'img-src data: cid: https: http:' : 'img-src data: cid:';
    return '''<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; $img; style-src 'unsafe-inline'; font-src 'none'; script-src 'none'; connect-src 'none'; frame-src 'none'; object-src 'none'; form-action 'none'; base-uri 'none'; media-src 'none'">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  html,body{margin:0;padding:0;background:#fff;color:#1b1b21;font-family:"Segoe UI Variable Text","Segoe UI",Roboto,sans-serif;font-size:14px;line-height:1.5;word-wrap:break-word;overflow-wrap:anywhere}
  body{padding:16px}
  img{max-width:100%;height:auto}
  img.cm-blocked{border:1px dashed #c7c5d0;border-radius:6px}
  table{max-width:100%}
  pre{white-space:pre-wrap}
  blockquote{border-left:3px solid #c7c5d0;margin:8px 0;padding-left:12px;color:#46464f}
  a{color:#4653d0}
</style>
</head><body>$bodyInner</body></html>''';
  }
}

/// Escapes plain text into HTML with clickable links, for messages that
/// have no HTML part.
String plainTextToHtml(String text) {
  final escaped = text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  final linked = escaped.replaceAllMapped(RegExp(r'(https?://[^\s<]+)'), (m) => '<a href="${m.group(1)}">${m.group(1)}</a>');
  final quoted = linked.split('\n').map((line) => line.startsWith('&gt;') ? '<span class="q">$line</span>' : line).join('\n');
  return '<pre style="font-family:inherit;white-space:pre-wrap;margin:0">$quoted</pre>';
}
