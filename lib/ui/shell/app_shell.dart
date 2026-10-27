import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/account_scope.dart';
import '../../app/compose_state.dart';
import '../../app/destinations.dart';
import '../../app/onboarding.dart';
import '../../app/people_state.dart';
import '../../app/settings.dart';
import '../../app/settings_navigation.dart';
import '../../app/shortcuts.dart';
import '../../platform/windows_integration.dart';
import '../../store/database.dart';
import '../../sync/notification_center.dart';
import '../../sync/schedule_service.dart';
import '../screens/boards_screen.dart';
import '../screens/chats_screen.dart';
import '../screens/planner_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/tokens.dart';
import '../widgets/tonal_avatar.dart';

/// The single-window desktop shell: navigation rail on the left, destination
/// content on the right (spec 5.3). Nothing opens a second OS window.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  static bool _autoComposed = false;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription<void>? _badgeSub;

  @override
  void initState() {
    super.initState();
    final integration = ref.read(windowsIntegrationProvider);
    if (integration != null) {
      unawaited(integration.start());
      ref.read(notificationCenterProvider).start();
      // Badge: recompute whenever summaries change.
      final db = ref.read(databaseProvider);
      _badgeSub = db.select(db.rowSummaries).watch().listen((_) => _updateBadge());
    }
  }

  Future<void> _updateBadge() async {
    final integration = ref.read(windowsIntegrationProvider);
    if (integration == null) return;
    final settings = ref.read(settingsProvider);
    final n = await ref.read(notificationCenterProvider).badgeCount();
    await integration.setUnread(n, showBadge: settings.showBadge);
  }

  @override
  void dispose() {
    _badgeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(destinationProvider);
    final scheme = Theme.of(context).colorScheme;
    // Settings that the Windows layer mirrors.
    ref.listen(settingsProvider, (prev, next) {
      final integration = ref.read(windowsIntegrationProvider);
      if (integration == null) return;
      integration.closeToTray = next.closeToTray;
      if (prev?.showBadge != next.showBadge) unawaited(_updateBadge());
      if (prev != null && prev.launchAtLogin != next.launchAtLogin) unawaited(integration.setLaunchAtLogin(next.launchAtLogin));
    });
    // A clicked toast opens its row.
    ref.listen<OutgoingNotification?>(notificationClickProvider, (prev, next) {
      if (next == null) return;
      if (next.rowKey != null) ref.read(selectedRowProvider.notifier).select(next.rowKey);
      ref.read(destinationProvider.notifier).select(Destination.chats);
      ref.read(windowsIntegrationProvider)?.showWindow();
      ref.read(notificationClickProvider.notifier).clear();
    });
    // Snooze-ended and reminder notices surface as snackbars (M10 adds toasts).
    ref.listen<List<AppNotice>>(appNoticesProvider, (prev, next) {
      final seen = {for (final n in prev ?? const <AppNotice>[]) n.id};
      for (final n in next.where((n) => !seen.contains(n.id))) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(n.body.isEmpty ? n.title : '${n.title}: ${n.body}'),
          behavior: SnackBarBehavior.floating,
          width: 440,
          duration: const Duration(seconds: 8),
          action: n.rowKey == null
              ? null
              : SnackBarAction(
                  label: 'Open',
                  onPressed: () {
                    ref.read(selectedRowProvider.notifier).select(n.rowKey);
                    ref.read(destinationProvider.notifier).select(Destination.chats);
                  },
                ),
        ));
        ref.read(appNoticesProvider.notifier).remove(n.id);
      }
    });
    if (ref.read(autoComposeProvider) && !AppShell._autoComposed) {
      AppShell._autoComposed = true;
      final request = ref.read(autoComposeRequestProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(composeProvider.notifier).open(request));
    }

    final settings = ref.watch(settingsProvider);
    final accounts = ref.watch(accountsProvider).value;
    if (ref.watch(showOnboardingProvider) && !settings.onboardingDone && accounts != null && accounts.isEmpty) {
      return const OnboardingScreen();
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
                const _AccountSwitcher(),
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


/// Rail avatar: opens the account switcher (spec 4.14) with the unified
/// view, each account, and Add account. The avatar shows the scoped
/// account's color when one is selected.
class _AccountSwitcher extends ConsumerWidget {
  const _AccountSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final scope = ref.watch(accountScopeProvider);
    final current = accounts.where((a) => a.id == scope).firstOrNull;
    return PopupMenuButton<int>(
      key: const ValueKey('account-switcher'),
      tooltip: current == null ? 'All accounts' : current.email,
      offset: const Offset(72, -8),
      onSelected: (v) {
        if (v == -1) {
          ref.read(accountScopeProvider.notifier).select(null);
        } else if (v == -2) {
          ref.read(settingsSectionProvider.notifier).select(SettingsSection.accounts);
          ref.read(settingsAddAccountRequestProvider.notifier).set(true);
          ref.read(destinationProvider.notifier).select(Destination.settings);
        } else {
          ref.read(accountScopeProvider.notifier).select(v);
        }
        ref.read(selectedRowProvider.notifier).select(null);
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(value: -1, checked: scope == null, child: const Text('All accounts')),
        for (final a in accounts)
          CheckedPopupMenuItem(
            value: a.id,
            checked: scope == a.id,
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: accountColor(a.id, scheme), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(a.email, overflow: TextOverflow.ellipsis)),
                if (!a.enabled) Text(' · paused', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: -2, child: ListTile(leading: Icon(Icons.add_rounded), title: Text('Add account…'), dense: true, contentPadding: EdgeInsets.zero)),
      ],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TonalAvatar(identityKey: current?.email ?? 'me', name: current == null ? 'You' : accountShortLabel(current), size: 36),
          if (current != null)
            Positioned(right: -2, bottom: -2, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: accountColor(current.id, scheme), shape: BoxShape.circle, border: Border.all(color: scheme.surfaceContainer, width: 2)))),
        ],
      ),
    );
  }
}
