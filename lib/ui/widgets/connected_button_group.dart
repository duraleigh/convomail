import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One segment of a [ConnectedButtonGroup].
class ButtonGroupItem<T> {
  const ButtonGroupItem({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Material 3 Expressive connected button group.
///
/// Segments sit 2dp apart. The outer ends are fully rounded; inner corners
/// are 8dp. The selected segment morphs to a full pill in the primary color
/// (spec 5.1). Used for People/Feeds, List/Grid, Light/Dark/System.
class ConnectedButtonGroup<T> extends StatelessWidget {
  const ConnectedButtonGroup({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.height = 40,
    this.expand = true,
  });

  final List<ButtonGroupItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isSelected = item.value == selected;
      final first = i == 0;
      final last = i == items.length - 1;

      final radius = isSelected
          ? BorderRadius.circular(AppShapes.full)
          : BorderRadius.horizontal(
              left: Radius.circular(first ? AppShapes.full : AppShapes.sm),
              right: Radius.circular(last ? AppShapes.full : AppShapes.sm),
            );

      final segment = AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        height: height,
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () => onSelected(item.value),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: item.label,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Icon(item.icon, size: 18, color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      item.label,
                      style: text.labelLarge!.copyWith(
                        color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      if (i > 0) children.add(const SizedBox(width: 2));
      children.add(expand ? Expanded(child: segment) : segment);
    }
    return Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: children);
  }
}
