import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Material 3 Expressive grouped list segment (spec 5.1).
///
/// Items sit 2dp apart on the surface. Inner corners are 4dp; the first
/// item's top corners and the last item's bottom corners are 20dp. A single
/// item gets 20dp all round. Each child is wrapped in a surface container.
class GroupedList extends StatelessWidget {
  const GroupedList({
    super.key,
    required this.children,
    this.gap = 2,
    this.color,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final double gap;
  final Color? color;
  final EdgeInsetsGeometry padding;

  /// The border radius for item [index] of [count] items.
  static BorderRadius radiusFor(int index, int count) {
    const outer = Radius.circular(AppShapes.lgIncreased);
    const inner = Radius.circular(AppShapes.xs);
    if (count <= 1) return const BorderRadius.all(outer);
    if (index == 0) return const BorderRadius.vertical(top: outer, bottom: inner);
    if (index == count - 1) return const BorderRadius.vertical(top: inner, bottom: outer);
    return const BorderRadius.all(inner);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.surfaceContainerLowest;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            GroupedListItem(radius: radiusFor(i, children.length), color: bg, child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// A single segment surface. Exposed so lazy lists can compute radii per
/// index with [GroupedList.radiusFor] and build items on demand.
class GroupedListItem extends StatelessWidget {
  const GroupedListItem({super.key, required this.radius, required this.child, this.color, this.onTap, this.selected = false});

  final BorderRadius radius;
  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.secondaryContainer : (color ?? scheme.surfaceContainerLowest);
    return Material(
      color: bg,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}
