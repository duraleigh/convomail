import 'package:flutter/material.dart';

/// Material 3 Expressive floating toolbar (vibrant variant).
///
/// A 56dp pill in primary-container holding icon actions. Used for the
/// compose editor's formatting controls (spec 5.1, 5.3).
class FloatingToolbar extends StatelessWidget {
  const FloatingToolbar({super.key, required this.children, this.vibrant = true});

  final List<Widget> children;
  final bool vibrant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = vibrant ? scheme.primaryContainer : scheme.surfaceContainer;
    final fg = vibrant ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.3),
      child: SizedBox(
        height: 56,
        child: IconTheme(
          data: IconThemeData(color: fg, size: 22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon action inside a [FloatingToolbar].
class ToolbarAction extends StatelessWidget {
  const ToolbarAction({super.key, required this.icon, required this.tooltip, this.onPressed, this.active = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: IconTheme.of(context).color,
        backgroundColor: active ? scheme.primary.withValues(alpha: 0.18) : null,
        shape: active ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) : const CircleBorder(),
      ),
      icon: Icon(icon),
    );
  }
}
