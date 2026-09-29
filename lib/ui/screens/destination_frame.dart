import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Common frame for full-width destinations (Boards, Planner, Settings):
/// a flexible top app bar with a large headline, trailing actions, the
/// content in a large-radius surface container, and an optional FAB.
class DestinationFrame extends StatelessWidget {
  const DestinationFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.floatingAction,
    this.padContent = true,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingAction;
  final bool padContent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 12, 8),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: text.headlineMedium)),
                  ...actions,
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppShapes.xl),
                  clipBehavior: Clip.antiAlias,
                  child: padContent ? Padding(padding: const EdgeInsets.all(AppSpace.lg), child: child) : child,
                ),
              ),
            ),
          ],
        ),
        if (floatingAction != null) Positioned(right: 28, bottom: 28, child: floatingAction!),
      ],
    );
  }
}
