import 'dart:math';

import 'package:convomail/domain/html_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = HtmlSanitizer();

  group('active content', () {
    test('scripts, frames, forms, objects and metas are removed', () {
      final r = s.sanitize('''
        <html><head><meta http-equiv="refresh" content="0;url=https://evil.example"><base href="https://evil.example/">
        <script>alert(1)</script><link rel="stylesheet" href="https://evil.example/x.css"></head>
        <body><p>Hi</p><iframe src="https://evil.example"></iframe><form action="https://evil.example"><input name="pw"></form>
        <object data="x.swf"></object><svg onload="alert(1)"></svg><noscript>x</noscript></body></html>''');
      expect(r.html, isNot(contains('<script')));
      expect(r.html, isNot(contains('<iframe')));
      expect(r.html, isNot(contains('<form')));
      expect(r.html, isNot(contains('<input')));
      expect(r.html, isNot(contains('<object')));
      expect(r.html, isNot(contains('<svg')));
      expect(r.html, isNot(contains('evil.example')));
      expect(r.html, contains('<p>Hi</p>'));
      expect(r.remote, isEmpty, reason: 'removed elements do not count as remote content');
    });

    test('event handlers and javascript: URLs are stripped; links open safely', () {
      final r = s.sanitize('<a href="javascript:alert(1)" onclick="x()" onmouseover="y()">go</a><a href="https://ok.example/a">ok</a><div onload="z()">d</div>');
      expect(r.html, isNot(contains('onclick')));
      expect(r.html, isNot(contains('onmouseover')));
      expect(r.html, isNot(contains('onload')));
      expect(r.html, isNot(contains('javascript:')));
      expect(r.html, contains('href="https://ok.example/a"'));
      expect(r.html, contains('target="_blank"'));
      expect(r.html, contains('rel="noopener noreferrer"'));
    });

    test('obfuscated javascript: is caught', () {
      final r = s.sanitize('<a href="  JaVaScRiPt:alert(1)">x</a><a href="java&#0;script:alert(1)">y</a>');
      expect(r.html.toLowerCase(), isNot(contains('javascript:')));
    });
  });

  group('remote images (spec 4.13)', () {
    test('remote images are replaced with a placeholder and their hosts recorded', () {
      final r = s.sanitize('<img src="https://cdn.shop.example/hero.jpg" width="600"><img src="//img.other.example/a.png">');
      expect(r.hasRemoteContent, isTrue);
      expect(r.hosts, {'cdn.shop.example', 'img.other.example'});
      expect(r.blockedCount, 2);
      expect(r.html, isNot(contains(' src="https://cdn.shop.example/hero.jpg"')));
      expect(r.html, contains('data-blocked-src="https://cdn.shop.example/hero.jpg"'));
      expect(r.html, contains('cm-blocked'));
      expect(r.html, contains('Image blocked'));
    });

    test('1x1 and hidden pixels are flagged as trackers and become transparent gifs', () {
      final r = s.sanitize('<img src="https://open.mailmetrics.example/o.gif" width="1" height="1"><img src="https://x.example/p.png" style="display:none">');
      expect(r.remote.length, 2);
      expect(r.remote.every((x) => x.isTracker), isTrue);
      expect(r.trackerHosts, {'open.mailmetrics.example', 'x.example'});
      expect(r.html, isNot(contains('Image blocked')), reason: 'pixels get no visible placeholder');
    });

    test('known tracking hosts are flagged even at full size', () {
      final r = s.sanitize('<img src="https://us1.list-manage.com/track/open.php?u=1" width="400" height="300">');
      expect(r.remote.single.isTracker, isTrue);
    });

    test('Load images keeps sources and records hosts as loaded', () {
      final r = s.sanitize('<img src="https://cdn.shop.example/hero.jpg">', allowRemoteImages: true);
      expect(r.html, contains('src="https://cdn.shop.example/hero.jpg"'));
      expect(r.blockedCount, 0);
      expect(r.hosts, {'cdn.shop.example'});
      expect(r.html, contains('img-src data: cid: https: http:'));
    });

    test('cid: images are kept and resolved; data: images are kept', () {
      final r = s.sanitize('<img src="cid:logo@x"><img src="data:image/png;base64,AAAA">', resolveCid: (cid) => 'data:image/png;base64,LOGO$cid');
      expect(r.html, contains('data:image/png;base64,LOGOlogo@x'));
      expect(r.html, contains('data:image/png;base64,AAAA'));
      expect(r.remote, isEmpty);
    });

    test('CSS backgrounds and @import are scrubbed; background attributes too', () {
      final r = s.sanitize('''<style>@import url(https://evil.example/a.css); .x{background:url("https://cdn.example/bg.png")}</style>
        <td background="https://cdn.example/td.png" style="background-image:url(https://cdn.example/s.png)">x</td>''');
      expect(r.html, isNot(contains('@import')));
      expect(r.html, isNot(contains('cdn.example')));
      expect(r.hosts, {'evil.example', 'cdn.example'}.intersection(r.hosts), reason: 'evil.example import is removed before url scan');
      expect(r.hosts, contains('cdn.example'));
    });

    test('CSS expression/behavior hacks are removed', () {
      final r = s.sanitize('<div style="width:expression(alert(1));behavior:url(x.htc)">x</div>');
      expect(r.html, isNot(contains('expression')));
      expect(r.html, isNot(contains('behavior')));
    });
  });

  group('document wrapper', () {
    test('has a strict CSP that forbids scripts, frames, connections and remote images by default', () {
      final r = s.sanitize('<p>x</p>');
      expect(r.html, contains("default-src 'none'"));
      expect(r.html, contains("script-src 'none'"));
      expect(r.html, contains("frame-src 'none'"));
      expect(r.html, contains("connect-src 'none'"));
      expect(r.html, contains('img-src data: cid;'.replaceAll(';', '')));
      expect(r.html, isNot(contains('https: http:')));
    });

    test('plain text becomes escaped, linkified HTML', () {
      final h = plainTextToHtml('Hi <b>\nSee https://ok.example/x?a=1&b=2\n> quoted');
      expect(h, contains('Hi &lt;b&gt;'));
      expect(h, contains('<a href="https://ok.example/x?a=1&amp;b=2">'));
      expect(h, contains('class="q"'));
    });
  });

  group('synthetic corpus invariants', () {
    // 200 generated emails mixing the patterns real newsletters, receipts
    // and mail-client output use. Every output must satisfy the invariants,
    // regardless of the combination.
    final rnd = Random(42);
    const pieces = [
      '<table width="600" cellpadding="0" style="background:url(https://c.example/bg.png)"><tr><td background="https://c.example/td.jpg"><img src="https://c.example/logo.png" width="200" height="50"></td></tr></table>',
      '<img src="https://open.tracker.example/o.gif?id=1" width="1" height="1" style="display:none">',
      '<script type="text/javascript">document.write("x")</script>',
      '<a href="https://shop.example/buy?u=1" onclick="track()" style="color:red">Buy now</a>',
      '<a href="javascript:void(0)">no</a>',
      '<div style="font-family:Arial;color:#333;width:expression(1)">Body <b>text</b> with &amp; entities</div>',
      '<iframe src="https://video.example/embed" width="560" height="315"></iframe>',
      '<form method="post" action="https://phish.example/login"><input type="password" name="p"><button>Go</button></form>',
      '<style>@import url(https://fonts.example/f.css); body{margin:0} .h{background-image:url("https://c.example/h.png")}</style>',
      '<img src="cid:part1.abc@mail" alt="inline">',
      '<img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=">',
      '<p>Plain paragraph with <i>italic</i> and a <span style="color:blue">span</span>.</p>',
      '<blockquote>On Tue, someone wrote:<br>quoted text</blockquote>',
      '<meta http-equiv="refresh" content="0;url=https://phish.example">',
      '<object data="https://x.example/movie.swf"></object><embed src="https://x.example/e.swf">',
      '<svg><script>alert(1)</script><image href="https://x.example/i.png"/></svg>',
      '<td style="background:url(\'https://c.example/q.png\') no-repeat">cell</td>',
      '<img srcset="https://c.example/a.png 1x, https://c.example/b.png 2x" src="https://c.example/a.png">',
      '<a href="mailto:someone@example.com">mail</a><a href="tel:+15551234">call</a>',
      '<div onmouseover="steal()" title="x">hover</div>',
    ];
    for (var i = 0; i < 200; i++) {
      test('email #$i', () {
        final parts = List.generate(3 + rnd.nextInt(6), (_) => pieces[rnd.nextInt(pieces.length)]);
        final email = '<html><head><title>t</title></head><body style="margin:0">${parts.join('\n')}</body></html>';
        final r = s.sanitize(email);
        final lower = r.html.toLowerCase();
        expect(lower, isNot(contains('<script')));
        expect(lower, isNot(contains('<iframe')));
        expect(lower, isNot(contains('<form')));
        expect(lower, isNot(contains('<object')));
        expect(lower, isNot(contains('<embed')));
        expect(lower, isNot(contains('<svg')));
        expect(lower, isNot(contains('<meta http-equiv="refresh"')));
        expect(RegExp(r'\son[a-z]+\s*=').hasMatch(lower), isFalse, reason: 'no event handlers');
        expect(lower, isNot(contains('javascript:')));
        expect(lower, isNot(contains('expression(')));
        // No live remote fetch: every http(s) reference is in data-blocked-src or an href.
        final body = lower.substring(lower.indexOf('<body>'));
        // data-blocked-src is inert; only a bare src/background attribute
        // would make the renderer fetch.
        for (final m in RegExp(r'\s(src|background)="(https?:|//)[^"]*"').allMatches(body)) {
          fail('live remote reference survived: ${m.group(0)}');
        }
        expect(RegExp(r'url\(\s*["\x27]?https?:').hasMatch(body), isFalse, reason: 'no remote CSS url()');
        expect(r.html, contains("script-src 'none'"));
      });
    }
  });
}
