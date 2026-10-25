import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/compose_state.dart';
import '../../app/destinations.dart';
import '../../app/shortcuts.dart';
import '../screens/boards_screen.dart';
import '../screens/chats_screen.dart';
import '../screens/planner_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/tokens.dart';
import '../widgets/tonal_avatar.dart';

/// The single-window desktop shell: navigation rail on the left, destination
/// content on the right (spec 5.3). Nothing opens a second OS window.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static bool _autoComposed = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(destinationProvider);
    final scheme = Theme.of(context).colorScheme;
    if (ref.read(autoComposeProvider) && !_autoComposed) {
      _autoComposed = true;
      final request = ref.read(autoComposeRequestProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(composeProvider.notifier).open(request));
    }

    return AppShortcutScope(
      onCompose: () {
        ref.read(destinationProvider.notifier).select(Destination.chats);
        ref.read(composeProvider.notifier).open();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Row(
          children: [
            _Rail(destination: destination),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(key: ValueKey(destination), child: _content(destination)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(Destination d) => switch (d) {
        Destination.chats => const ChatsScreen(),
        Destination.boards => const BoardsScreen(),
        Destination.planner => const PlannerScreen(),
        Destination.settings => const SettingsScreen(),
      };
}

class _Rail extends ConsumerWidget {
  const _Rail({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final railIndex = Destination.rail.indexOf(destination);

    return NavigationRail(
      selectedIndex: railIndex < 0 ? null : railIndex,
      onDestinationSelected: (i) => ref.read(destinationProvider.notifier).select(Destination.rail[i]),
      leading: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 14),
        child: FloatingActionButton(
          heroTag: 'compose-fab',
          tooltip: 'New message (Ctrl+N)',
          onPressed: () => Actions.maybeInvoke(context, const ComposeIntent()),
          child: const Icon(Icons.edit_outlined),
        ),
      ),
      destinations: [
        for (final d in Destination.rail)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SettingsRailItem(selected: destination == Destination.settings),
                const SizedBox(height: AppSpace.md),
                Tooltip(
                  message: 'Accounts',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => ref.read(destinationProvider.notifier).select(Destination.settings),
                    child: const TonalAvatar(identityKey: 'me', name: 'You', size: 36),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: scheme.surfaceContainer,
    );
  }
}

/// Settings lives at the bottom of the rail, drawn with the same pill
/// indicator as the NavigationRail destinations above it.
class _SettingsRailItem extends ConsumerWidget {
  const _SettingsRailItem({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Settings',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShapes.md),
        onTap: () => ref.read(destinationProvider.notifier).select(Destination.settings),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? scheme.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppShapes.full),
                ),
                alignment: Alignment.center,
                child: Icon(
                  selected ? Destination.settings.selectedIcon : Destination.settings.icon,
                  size: 24,
                  color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Settings',
                style: text.labelMedium!.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
