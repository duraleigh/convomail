import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'html_body_view.dart' show openMailLink;

/// A designed email on Android, in the phone's own web view.
///
/// The page is the same cleaned-up one the PC shows (no scripts of the
/// email's own, remote pictures held back unless allowed). It is fitted to
/// the phone's width and given its full height, so the email scrolls with
/// the conversation around it. A link opens in the phone's browser; the
/// view itself never leaves the email.
class AndroidHtmlBody extends StatefulWidget {
  const AndroidHtmlBody({super.key, required this.html, this.maxHeight = 1200});
  final String html;
  final double maxHeight;

  @override
  State<AndroidHtmlBody> createState() => _AndroidHtmlBodyState();
}

class _AndroidHtmlBodyState extends State<AndroidHtmlBody> {
  late final WebViewController _controller;
  double _height = 120;
  bool _shown = false;
  bool _loaded = false;
  final List<Timer> _timers = [];

  /// An email longer than this scrolls inside its own box.
  static const _tallest = 12000.0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // Only for measuring the page's height: an email's own scripts were removed before it got here.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(true)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          // The first load is ours. Anything after it is a link the user tapped.
          if (!_loaded || request.url.startsWith('about:') || request.url.startsWith('data:')) return NavigationDecision.navigate;
          openMailLink(request.url);
          return NavigationDecision.prevent;
        },
        onPageFinished: (_) {
          _loaded = true;
          _measure();
          // Pictures arrive after the text: measure again as they do.
          for (final ms in const [300, 1200, 3000]) {
            _timers.add(Timer(Duration(milliseconds: ms), _measure));
          }
        },
      ));
    unawaited(_controller.loadHtmlString(_fitted(widget.html)));
  }

  @override
  void didUpdateWidget(AndroidHtmlBody old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) {
      _loaded = false;
      unawaited(_controller.loadHtmlString(_fitted(widget.html)));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  /// Tells the page to lay itself out at the phone's width, and keeps wide
  /// pictures and tables from pushing past it.
  static String _fitted(String html) {
    const head = '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<style>html,body{max-width:100%;overflow-x:auto;word-wrap:break-word}img{max-width:100%;height:auto}</style>';
    final at = html.indexOf(RegExp(r'<head[^>]*>', caseSensitive: false));
    if (at >= 0) {
      final end = html.indexOf('>', at) + 1;
      return html.substring(0, end) + head + html.substring(end);
    }
    return '<!doctype html><html><head>$head</head><body>$html</body></html>';
  }

  Future<void> _measure() async {
    if (!mounted) return;
    try {
      final v = await _controller.runJavaScriptReturningResult('Math.max(document.documentElement.scrollHeight, document.body ? document.body.scrollHeight : 0)');
      final h = v is num ? v.toDouble() : double.tryParse('$v');
      if (!mounted || h == null || h <= 0) return;
      final next = (h + 8).clamp(40.0, _tallest);
      if ((next - _height).abs() > 4 || !_shown) {
        setState(() {
          _height = next;
          _shown = true;
        });
      }
    } catch (_) {
      if (mounted && !_shown) setState(() => _shown = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: WebViewWidget(
          controller: _controller,
          // Sideways drags (a wide table) belong to the email; up and down
          // belong to the conversation around it.
          gestureRecognizers: const {Factory<HorizontalDragGestureRecognizer>(HorizontalDragGestureRecognizer.new)},
        ),
      ),
    );
  }
}
