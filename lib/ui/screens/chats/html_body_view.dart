import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

/// Builds the widget that shows a sanitized HTML document. The default is
/// WebView2 on Windows; tests override it with a plain text renderer.
typedef HtmlRendererBuilder = Widget Function(BuildContext context, String html, {double maxHeight});

final htmlRendererProvider = Provider<HtmlRendererBuilder>((ref) {
  if (Platform.isWindows) {
    return (context, html, {maxHeight = 1200}) => WebView2Body(html: html, maxHeight: maxHeight);
  }
  return (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html);
});

/// Renders in an embedded WebView2. Navigation is disabled: clicks on links
/// are intercepted in the page and opened in the system browser. The
/// document height is measured after load so the view sizes to content,
/// capped at [maxHeight] with internal scrolling beyond that.
class WebView2Body extends StatefulWidget {
  const WebView2Body({super.key, required this.html, this.maxHeight = 1200});
  final String html;
  final double maxHeight;

  @override
  State<WebView2Body> createState() => _WebView2BodyState();
}

class _WebView2BodyState extends State<WebView2Body> {
  final _controller = WebviewController();
  final _subs = <StreamSubscription<dynamic>>[];
  double _height = 240;
  bool _ready = false;
  String? _error;

  static const _interceptScript = r'''
    (function(){
      document.addEventListener('click', function(e){
        var a = e.target && e.target.closest ? e.target.closest('a') : null;
        if (!a) return;
        e.preventDefault();
        var href = a.getAttribute('href') || '';
        if (href) window.chrome.webview.postMessage(JSON.stringify({type:'link', href: href}));
      }, true);
      function report(){ window.chrome.webview.postMessage(JSON.stringify({type:'height', h: document.documentElement.scrollHeight})); }
      window.addEventListener('load', report);
      new ResizeObserver(report).observe(document.documentElement);
      setTimeout(report, 50); setTimeout(report, 400);
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.white);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.addScriptToExecuteOnDocumentCreated(_interceptScript);
      _subs.add(_controller.webMessage.listen(_onMessage));
      _subs.add(_controller.url.listen((u) {
        // Any navigation away from our content is refused: reload ours.
        if (u.isNotEmpty && !u.startsWith('about:') && !u.startsWith('data:')) {
          _controller.loadStringContent(widget.html);
        }
      }));
      await _controller.loadStringContent(widget.html);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void didUpdateWidget(WebView2Body old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html && _ready) _controller.loadStringContent(widget.html);
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = raw is String ? jsonDecode(raw) : raw;
      if (msg is! Map) return;
      switch (msg['type']) {
        case 'height':
          final h = (msg['h'] as num).toDouble() + 8;
          if (mounted && (h - _height).abs() > 4) setState(() => _height = h.clamp(80, widget.maxHeight));
        case 'link':
          final href = msg['href'] as String? ?? '';
          final uri = Uri.tryParse(href);
          if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http' || uri.scheme == 'mailto' || uri.scheme == 'tel')) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return PlainHtmlFallback(html: widget.html, note: 'WebView2 is not available on this system ($_error). Showing text only.');
    if (!_ready) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(height: _height, child: Webview(_controller)),
    );
  }
}

/// Text-only rendering: strips tags from the sanitized document body. Used
/// where WebView2 is unavailable and in widget tests.
class PlainHtmlFallback extends StatelessWidget {
  const PlainHtmlFallback({super.key, required this.html, this.note});
  final String html;
  final String? note;

  static String textOf(String html) {
    final bodyStart = html.indexOf('<body');
    var s = bodyStart >= 0 ? html.substring(html.indexOf('>', bodyStart) + 1) : html;
    s = s.replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').replaceAll(RegExp(r'</(p|div|tr|li|h\d)>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&#39;', "'");
    return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(note!, style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant))),
        SelectableText(textOf(html), style: text.bodyMedium),
      ],
    );
  }
}
