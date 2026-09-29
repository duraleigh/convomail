import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings.dart';
import '../../app/settings_navigation.dart';
import '../../app/shortcuts.dart';
import '../theme/tokens.dart';
import '../widgets/connected_button_group.dart';
import '../widgets/grouped_list.dart';
import 'destination_frame.dart';
import 'settings/accounts_section.dart';

/// Settings destination: section list on the left, detail on the right
/// (spec 5.3). Accounts, Appearance and Keyboard are live; the rest fill in
/// with their milestones.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(settingsSectionProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DestinationFrame(
      title: 'Settings',
      padContent: false,
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                GroupedList(
                  children: [
                    for (final s in SettingsSection.values)
                      ListTile(
                        leading: Icon(s.icon),
                        title: Text(s.label),
                        selected: s == section,
                        selectedTileColor: scheme.secondaryContainer,
                        selectedColor: scheme.onSecondaryContainer,
                        onTap: () => ref.read(settingsSectionProvider.notifier).select(s),
                      ),
                  ],
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.label, style: text.titleLarge),
                  const SizedBox(height: AppSpace.lg),
                  Expanded(child: _Detail(section)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail(this.section);
  final SettingsSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (section) {
      case SettingsSection.accounts:
        final startAdding = ref.watch(settingsAddAccountRequestProvider);
        if (startAdding) {
          WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(settingsAddAccountRequestProvider.notifier).set(false));
        }
        return AccountsDetail(startAdding: startAdding);
      case SettingsSection.appearance:
        return const _AppearanceDetail();
      case SettingsSection.keyboard:
        return const _KeyboardDetail();
      default:
        return _Placeholder(section);
    }
  }
}

class _AppearanceDetail extends ConsumerWidget {
  const _AppearanceDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        Text('Theme', style: text.labelSmall!.copyWith(letterSpacing: 1)),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          width: 360,
          child: ConnectedButtonGroup<ThemeMode>(
            selected: settings.themeMode,
            onSelected: (m) => ref.read(settingsProvider.notifier).setThemeMode(m),
            items: const [
              ButtonGroupItem(value: ThemeMode.light, label: 'Light', icon: Icons.light_mode_outlined),
              ButtonGroupItem(value: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode_outlined),
              ButtonGroupItem(value: ThemeMode.system, label: 'System', icon: Icons.brightness_auto_outlined),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        GroupedList(
          color: scheme.surfaceContainerLowest,
          children: [
            SwitchListTile(
              title: const Text('Follow Windows accent color'),
              subtitle: const Text('Dynamic color. Off uses the indigo scheme.'),
              value: settings.dynamicColor,
              onChanged: (v) => ref.read(settingsProvider.notifier).setDynamicColor(v),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyboardDetail extends StatelessWidget {
  const _KeyboardDetail();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        GroupedList(
          children: [
            for (final (keys, what) in AppShortcuts.descriptions)
              ListTile(
                title: Text(what),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppShapes.sm),
                  ),
                  child: Text(keys, style: text.labelMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.section);
  final SettingsSection section;

  static const _milestone = {
    SettingsSection.notifications: 'milestone 10',
    SettingsSection.privacy: 'milestone 3',
    SettingsSection.peopleGroups: 'milestone 7',
    SettingsSection.feeds: 'milestone 8',
    SettingsSection.tags: 'milestone 9',
    SettingsSection.defaultApp: 'milestone 10',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(AppShapes.lg)),
        child: Text(
          '${section.label} settings arrive in ${_milestone[section]}.',
          style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
