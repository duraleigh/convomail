import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../domain/simple_mail.dart';
import 'html_body_view.dart';

/// A simple email drawn straight into the conversation, in the app's own
/// font and colours: no browser box, nothing to load, no flash. Text can be
/// selected across lines; links open in the browser; pictures (GIFs keep
/// moving) sit where the sender put them.
class SimpleMailBody extends StatefulWidget {
  const SimpleMailBody({super.key, required this.blocks});
  final List<MailBlock> blocks;

  @override
  State<SimpleMailBody> createState() => _SimpleMailBodyState();
}

class _SimpleMailBodyState extends State<SimpleMailBody> {
  final List<TapGestureRecognizer> _taps = [];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    return SelectionArea(
      key: const ValueKey('simple-mail-body'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _blocks(context, widget.blocks, quoted: false),
      ),
    );
  }

  List<Widget> _blocks(BuildContext context, List<MailBlock> blocks, {required bool quoted}) => [
        for (final (i, b) in blocks.indexed) _block(context, b, quoted: quoted, last: i == blocks.length - 1),
      ];

  Widget _block(BuildContext context, MailBlock b, {required bool quoted, required bool last}) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    switch (b) {
      case MailText():
        final base = switch (b.heading) {
          1 => text.titleLarge!,
          2 => text.titleMedium!.copyWith(fontWeight: FontWeight.w700),
          3 => text.titleSmall!.copyWith(fontWeight: FontWeight.w700),
          _ => text.bodyMedium!.copyWith(height: 1.45),
        }.copyWith(color: quoted ? scheme.onSurfaceVariant : scheme.onSurface);
        final line = b.spans.isEmpty ? Text(' ', style: base) : Text.rich(TextSpan(style: base, children: [for (final s in b.spans) _span(context, s, base)]));
        return Padding(padding: EdgeInsets.only(bottom: b.spaceAfter && !last ? 10 : 0), child: line);
      case MailQuote():
        return Container(
          margin: EdgeInsets.only(top: 4, bottom: last ? 0 : 8),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: scheme.outlineVariant, width: 3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blocks(context, b.children, quoted: true)),
        );
      case MailListItem():
        return Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 22, child: Text(b.marker, style: text.bodyMedium!.copyWith(height: 1.45, color: quoted ? scheme.onSurfaceVariant : scheme.onSurface))),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blocks(context, b.children, quoted: quoted))),
            ],
          ),
        );
      case MailColumns():
        return Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, cell) in b.cells.indexed)
                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(
                    padding: EdgeInsets.only(right: i == b.cells.length - 1 ? 0 : 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _blocks(context, cell, quoted: quoted)),
                  ),
                ),
            ],
          ),
        );
      case MailRule():
        return Divider(height: 20, color: scheme.outlineVariant);
    }
  }

  InlineSpan _span(BuildContext context, MailSpan s, TextStyle base) {
    final scheme = Theme.of(context).colorScheme;
    TapGestureRecognizer? tap;
    if (s.href != null) {
      final href = s.href!;
      tap = TapGestureRecognizer()..onTap = () => openMailLink(href);
      _taps.add(tap);
    }
    final image = s.image;
    if (image != null) {
      Widget child = _MailPicture(image: image);
      if (s.href != null) child = MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: tap!.onTap, child: child));
      return WidgetSpan(alignment: PlaceholderAlignment.bottom, child: child);
    }
    return TextSpan(
      text: s.text,
      recognizer: tap,
      mouseCursor: tap == null ? null : SystemMouseCursors.click,
      style: TextStyle(
        fontWeight: s.bold ? FontWeight.w700 : null,
        fontStyle: s.italic ? FontStyle.italic : null,
        fontFamily: s.mono ? 'Consolas' : null,
        color: s.href != null ? scheme.primary : null,
        decoration: TextDecoration.combine([
          if (s.underline || s.href != null) TextDecoration.underline,
          if (s.strike) TextDecoration.lineThrough,
        ]),
        decorationColor: s.href != null ? scheme.primary : null,
        backgroundColor: s.mark ? scheme.tertiaryContainer : null,
      ),
    );
  }
}

/// A picture at the size the sender gave it, never wider than the card.
class _MailPicture extends StatelessWidget {
  const _MailPicture({required this.image});
  final MailImage image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (image.blocked) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(6)),
        child: Text(image.alt.isEmpty ? 'Image blocked' : image.alt, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
      );
    }
    final w = image.width;
    final h = image.height;
    Widget errorBox(BuildContext c, Object e, StackTrace? st) => SizedBox(width: w ?? 24, height: h ?? 24);
    final Widget pic = image.bytes != null
        ? Image.memory(image.bytes!, gaplessPlayback: true, fit: BoxFit.contain, errorBuilder: errorBox)
        : Image.network(image.url!, gaplessPlayback: true, fit: BoxFit.contain, errorBuilder: errorBox);
    if (w != null && h != null && w > 0 && h > 0) {
      return ConstrainedBox(constraints: BoxConstraints(maxWidth: w), child: AspectRatio(aspectRatio: w / h, child: pic));
    }
    if (w != null) return ConstrainedBox(constraints: BoxConstraints(maxWidth: w), child: pic);
    return pic;
  }
}
