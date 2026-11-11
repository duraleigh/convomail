import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../app/web_selection.dart';

/// Builds the widget that shows a sanitized HTML document. The default is
/// WebView2 on Windows; tests override it with a plain text renderer.
typedef HtmlRendererBuilder = Widget Function(BuildContext context, String html, {double maxHeight});

final htmlRendererProvider = Provider<HtmlRendererBuilder>((ref) {
  if (Platform.isWindows) {
    WebViewPool.instance.warm();
    return (context, html, {maxHeight = 1200}) => WebView2Body(html: html, maxHeight: maxHeight);
  }
  return (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html);
});

/// Opens a link from an email in the system browser, for the schemes mail
/// uses. Anything else is ignored.
void openMailLink(String href) {
  final uri = Uri.tryParse(href);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http' || uri.scheme == 'mailto' || uri.scheme == 'tel')) {
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// One WebView2 kept for reuse. Its message and address streams can be
/// listened to only once, so they are listened to here and passed to
/// whichever email is using it.
class PooledWebView {
  PooledWebView._(this.controller);
  final WebviewController controller;
  void Function(dynamic message)? onMessage;
  void Function(String url)? onUrl;
}

/// Starting a WebView2 takes a noticeable moment, so two are kept started
/// and ready, and each one goes back to the pool when its email closes.
/// Opening an email then only loads its page.
class WebViewPool {
  WebViewPool._();
  static final instance = WebViewPool._();

  /// Ready views to keep on hand.
  static const keep = 2;

  final List<PooledWebView> _ready = [];
  int _starting = 0;
  final List<Completer<PooledWebView>> _waiting = [];

  static const _script = r'''
    (function(){
      document.addEventListener('click', function(e){
        var a = e.target && e.target.closest ? e.target.closest('a') : null;
        if (!a) return;
        e.preventDefault();
        var href = a.getAttribute('href') || '';
        if (href) window.chrome.webview.postMessage(JSON.stringify({type:'link', href: href}));
      }, true);
      // This box gets the mouse but never the keyboard, and has no menu of
      // its own. So the app is told what is highlighted, and does the
      // copying itself (Ctrl+C, or the menu a right-click asks for).
      function picked(){ return String(window.getSelection() || '').slice(0, 500000); }
      var pickTimer = null;
      document.addEventListener('selectionchange', function(){
        clearTimeout(pickTimer);
        pickTimer = setTimeout(function(){
          window.chrome.webview.postMessage(JSON.stringify({type:'selection', text: picked(), p: page()}));
        }, 60);
      });
      document.addEventListener('contextmenu', function(e){
        e.preventDefault();
        window.chrome.webview.postMessage(JSON.stringify({type:'menu', x: e.clientX, y: e.clientY, text: picked(), p: page()}));
      });
      function height(){ return Math.ceil(document.documentElement.scrollHeight); }
      // Which load this page is, so word from an earlier page is ignored.
      function page(){ return document.documentElement.getAttribute('data-cm') || ''; }
      // "ready" goes once, after the page has laid out and painted twice,
      // so the view is shown only when it already looks right.
      function ready(){
        requestAnimationFrame(function(){ requestAnimationFrame(function(){
          window.chrome.webview.postMessage(JSON.stringify({type:'ready', h: height(), p: page()}));
          var last = height();
          new ResizeObserver(function(){
            var h = height();
            if (Math.abs(h - last) > 16) { last = h; window.chrome.webview.postMessage(JSON.stringify({type:'height', h: h, p: page()})); }
          }).observe(document.documentElement);
        }); });
      }
      if (document.readyState === 'complete') { ready(); } else { window.addEventListener('load', ready); }
    })();
  ''';

  /// Starts views until [keep] are ready or starting.
  void warm() {
    while (_ready.length + _starting < keep) {
      _starting++;
      unawaited(_create().then((v) {
        _starting--;
        _hand(v);
      }, onError: (Object _) {
        _starting--;
      }));
    }
  }

  void _hand(PooledWebView v) {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete(v);
    } else {
      _ready.add(v);
    }
  }

  Future<PooledWebView> _create() async {
    final c = WebviewController();
    await c.initialize();
    await c.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await c.addScriptToExecuteOnDocumentCreated(_script);
    final v = PooledWebView._(c);
    c.webMessage.listen((m) => v.onMessage?.call(m));
    c.url.listen((u) => v.onUrl?.call(u));
    return v;
  }

  /// A ready view, at once when one is on hand.
  Future<PooledWebView> take() {
    final completer = Completer<PooledWebView>();
    if (_ready.isNotEmpty) {
      completer.complete(_ready.removeLast());
    } else {
      _waiting.add(completer);
      if (_starting == 0) {
        _starting++;
        unawaited(_create().then((v) {
          _starting--;
          _hand(v);
        }, onError: (Object e) {
          _starting--;
          if (!completer.isCompleted) {
            _waiting.remove(completer);
            completer.completeError(e);
          }
        }));
      }
    }
    // Replace what was taken, in the background.
    Future<void>.microtask(warm);
    return completer.future;
  }

  /// Back from a closed email: blanked and kept, or closed when enough are
  /// on hand.
  void giveBack(PooledWebView v) {
    v.onMessage = null;
    v.onUrl = null;
    if (_ready.length >= keep) {
      unawaited(v.controller.dispose());
      return;
    }
    unawaited(v.controller.loadStringContent('<!DOCTYPE html><html><body></body></html>').then((_) => _hand(v), onError: (Object _) {}));
  }
}

/// Marks a page's `<html>` element with which load it is ([page]), so the
/// view's reports about an earlier page can be told apart.
String tagMailPage(String html, String page) {
  final at = html.indexOf(RegExp('<html', caseSensitive: false));
  if (at < 0) return '<!DOCTYPE html><html data-cm="$page"><body>$html</body></html>';
  return '${html.substring(0, at + 5)} data-cm="$page"${html.substring(at + 5)}';
}

/// Renders in an embedded WebView2 taken from [WebViewPool]. Navigation is
/// disabled: link clicks are opened in the system browser. Until the page
/// has painted and measured itself, a plain cover in the card's colour sits
/// over it at a steady height, so there is no black box and no jumping;
/// then the email appears once, at its own height.
class WebView2Body extends StatefulWidget {
  const WebView2Body({super.key, required this.html, this.maxHeight = 1200});
  final String html;
  final double maxHeight;

  @override
  State<WebView2Body> createState() => _WebView2BodyState();
}

class _WebView2BodyState extends State<WebView2Body> {
  PooledWebView? _view;
  double _height = 160;
  bool _shown = false;
  bool _slow = false;
  String? _error;
  Timer? _fallback;
  Timer? _slowTimer;
  bool _disposed = false;

  /// Each page load gets its own number, written into the page, and only
  /// messages carrying the current one count. A pooled view can still report
  /// on the page it showed before (its blank page, or this card's previous
  /// email), which would set the wrong height and show the box too early.
  static int _pages = 0;
  String _page = '';

  Future<void> _load(PooledWebView v) {
    _page = '${++_pages}';
    return v.controller.loadStringContent(tagMailPage(widget.html, _page));
  }

  @override
  void initState() {
    super.initState();
    // A quiet line, only if loading is unusually slow.
    _slowTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && !_shown) setState(() => _slow = true);
    });
    _open();
  }

  Future<void> _open() async {
    try {
      final v = await WebViewPool.instance.take();
      if (_disposed) {
        WebViewPool.instance.giveBack(v);
        return;
      }
      v.onMessage = _onMessage;
      v.onUrl = (u) {
        // Any navigation away from our content is refused: reload ours.
        if (u.isNotEmpty && !u.startsWith('about:') && !u.startsWith('data:')) unawaited(_load(v));
      };
      if (!mounted) return;
      await v.controller.setBackgroundColor(Theme.of(context).colorScheme.surfaceContainerLowest);
      await _load(v);
      if (!mounted) return;
      setState(() => _view = v);
      // Shown regardless after a while, should the page never report back.
      _fallback = Timer(const Duration(milliseconds: 2500), () => _reveal(null));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _reveal(double? h) {
    if (!mounted || _shown) return;
    setState(() {
      if (h != null) _height = (h + 8).clamp(40, widget.maxHeight);
    });
    // The view takes its new size first; the cover lifts a frame later, so
    // the resize itself is never seen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 40), () {
          if (mounted) setState(() => _shown = true);
        });
      });
    });
  }

  @override
  void didUpdateWidget(WebView2Body old) {
    super.didUpdateWidget(old);
    // New content (a picture arrived, images allowed): covered again until it
    // has painted, so the reload is never seen as a flash.
    if (old.html != widget.html && _view != null) {
      setState(() => _shown = false);
      _fallback?.cancel();
      _fallback = Timer(const Duration(milliseconds: 2500), () => _reveal(null));
      unawaited(_load(_view!));
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = raw is String ? jsonDecode(raw) : raw;
      if (msg is! Map) return;
      switch (msg['type']) {
        case 'ready' when msg['p'] == _page:
          _reveal((msg['h'] as num).toDouble());
        case 'height' when msg['p'] == _page:
          final h = ((msg['h'] as num).toDouble() + 8).clamp(40.0, widget.maxHeight);
          if (mounted && (h - _height).abs() > 16) setState(() => _height = h);
        case 'link':
          openMailLink(msg['href'] as String? ?? '');
        case 'selection' when msg['p'] == _page:
          WebSelection.report(this, msg['text'] as String? ?? '', _clearSelection);
        case 'menu' when msg['p'] == _page:
          final text = msg['text'] as String? ?? '';
          WebSelection.report(this, text, _clearSelection);
          unawaited(_showMenu(((msg['x'] as num?) ?? 0).toDouble(), ((msg['y'] as num?) ?? 0).toDouble(), text));
      }
    } catch (_) {}
  }

  void _clearSelection() {
    final v = _view;
    if (v != null && !_disposed) unawaited(v.controller.executeScript('window.getSelection().removeAllRanges()').catchError((Object _) {}));
  }

  /// The menu a right-click inside the email brings up: Copy and Select all.
  Future<void> _showMenu(double x, double y, String text) async {
    final box = context.findRenderObject();
    if (!mounted || box is! RenderBox) return;
    final at = box.localToGlobal(Offset(x, y));
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        PopupMenuItem(key: const ValueKey('web-copy'), value: 'copy', enabled: text.isNotEmpty, child: const Text('Copy')),
        const PopupMenuItem(key: ValueKey('web-select-all'), value: 'all', child: Text('Select all')),
      ],
    );
    if (picked == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
    } else if (picked == 'all') {
      final v = _view;
      if (v != null && !_disposed) await v.controller.executeScript('window.getSelection().selectAllChildren(document.body)').catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WebSelection.drop(this);
    _fallback?.cancel();
    _slowTimer?.cancel();
    final v = _view;
    if (v != null) WebViewPool.instance.giveBack(v);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return PlainHtmlFallback(html: widget.html, note: 'WebView2 is not available on this system ($_error). Showing text only.');
    final scheme = Theme.of(context).colorScheme;
    final view = _view;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A click anywhere else in the app lets go of what was
            // highlighted in here, as it would in any text.
            if (view != null)
              TapRegion(
                onTapOutside: (_) {
                  if (WebSelection.text != null) WebSelection.clear();
                },
                child: Webview(view.controller),
              ),
            // Lifted in one step: a fade from the dark card to a white email
            // passes through grey, which reads as a flash.
            if (!_shown)
              Container(
                color: scheme.surfaceContainerLowest,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.all(12),
                child: _slow ? SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2, color: scheme.primary.withValues(alpha: 0.6))) : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// A plain-text email drawn directly, with no browser engine: it appears at
/// once. Links can be clicked and search terms are marked.
class PlainTextBody extends StatelessWidget {
  const PlainTextBody({super.key, required this.text, this.highlight = const []});
  final String text;
  final List<String> highlight;

  static final _link = RegExp(r'(https?://[^\s<>"]+[^\s<>".,;:!?)\]])|([\w.+-]+@[\w-]+\.[\w.-]+\w)', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium!;
    final linkStyle = base.copyWith(color: theme.colorScheme.primary, decoration: TextDecoration.underline);
    final markStyle = TextStyle(backgroundColor: theme.colorScheme.tertiaryContainer, color: theme.colorScheme.onTertiaryContainer);
    final body = text.replaceAll('\r\n', '\n').trimRight();
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _link.allMatches(body)) {
      if (m.start > at) spans.addAll(_marked(body.substring(at, m.start), markStyle));
      final target = m.group(0)!;
      spans.add(TextSpan(
        text: target,
        style: linkStyle,
        recognizer: TapGestureRecognizer()..onTap = () => openMailLink(m.group(1) != null ? target : 'mailto:$target'),
      ));
      at = m.end;
    }
    if (at < body.length) spans.addAll(_marked(body.substring(at), markStyle));
    return SelectableText.rich(TextSpan(style: base, children: spans), key: const ValueKey('plain-body'));
  }

  List<InlineSpan> _marked(String s, TextStyle mark) {
    final terms = [for (final t in highlight) if (t.trim().isNotEmpty) RegExp.escape(t.trim())];
    if (terms.isEmpty) return [TextSpan(text: s)];
    final re = RegExp(terms.join('|'), caseSensitive: false);
    final out = <InlineSpan>[];
    var at = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > at) out.add(TextSpan(text: s.substring(at, m.start)));
      out.add(TextSpan(text: m.group(0), style: mark));
      at = m.end;
    }
    if (at < s.length) out.add(TextSpan(text: s.substring(at)));
    return out;
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
