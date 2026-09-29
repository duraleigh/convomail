import 'package:flutter/material.dart';

/// Two panes side by side with a draggable divider. The left pane has a
/// fixed, user-adjustable width clamped to [minLeft]..[maxLeft]; the right
/// pane takes the rest but never shrinks below [minRight].
class SplitPane extends StatefulWidget {
  const SplitPane({
    super.key,
    required this.left,
    required this.right,
    this.initialLeftWidth = 340,
    this.minLeft = 300,
    this.maxLeft = 480,
    this.minRight = 420,
    this.onLeftWidthChanged,
  });

  final Widget left;
  final Widget right;
  final double initialLeftWidth;
  final double minLeft;
  final double maxLeft;
  final double minRight;
  final ValueChanged<double>? onLeftWidthChanged;

  @override
  State<SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends State<SplitPane> {
  late double _left = widget.initialLeftWidth;
  bool _hover = false;
  bool _drag = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLeft = (constraints.maxWidth - widget.minRight).clamp(widget.minLeft, widget.maxLeft);
        final left = _left.clamp(widget.minLeft, maxLeft).toDouble();
        return Row(
          children: [
            SizedBox(width: left, child: widget.left),
            MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => setState(() => _drag = true),
                onHorizontalDragUpdate: (d) => setState(() => _left = (left + d.delta.dx).clamp(widget.minLeft, maxLeft)),
                onHorizontalDragEnd: (_) {
                  setState(() => _drag = false);
                  widget.onLeftWidthChanged?.call(left);
                },
                child: SizedBox(
                  width: 8,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: _drag || _hover ? 3 : 1,
                      height: double.infinity,
                      color: _drag || _hover ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: widget.right),
          ],
        );
      },
    );
  }
}
