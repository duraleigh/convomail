import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings.dart';
import '../../app/shortcuts.dart';
import '../theme/tokens.dart';
import '../widgets/connected_button_group.dart';
import '../widgets/grouped_list.dart';
import 'destination_frame.dart';

/// Settings destination: section list on the left, detail on the right
/// (spec 5.3). Milestone 0 ships Appearance and Keyboard; the rest are
/// placeholders that fill in with their milestones.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

enum _Section {
  accounts('Accounts', Icons.account_circle_outlined),
  appearance('Appearance', Icons.palette_outlined),
  notifications('Notifications', Icons.notifications_outlined),
  privacy('Privacy', Icons.shield_outlined),
  peopleGroups('People Groups', Icons.group_outlined),
  feeds('Feeds', Icons.rss_feed_rounded),
  tags('Groups & Tags', Icons.label_outline_rounded),
  keyboard('Keyboard', Icons.keyboard_outlined),
  defaultApp('Default mail app', Icons.mail_outline_rounded);

  const _Section(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _Section _section = _Section.appearance;

  @override
  Widget build(BuildContext context) {
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
                    for (final s in _Section.values)
                      ListTile(
                        leading: Icon(s.icon),
                        title: Text(s.label),
                        selected: s == _section,
                        selectedTileColor: scheme.secondaryContainer,
                        selectedColor: scheme.onSecondaryContainer,
                        onTap: () => setState(() => _section = s),
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
                  Text(_section.label, style: text.titleLarge),
                  const SizedBox(height: AppSpace.lg),
                  Expanded(child: _detail(_section)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(_Section s) => switch (s) {
        _Section.appearance => const _AppearanceDetail(),
        _Section.keyboard => const _KeyboardDetail(),
        _ => _Placeholder(s),
      };
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
  final _Section section;

  static const _milestone = {
    _Section.accounts: 'milestone 1',
    _Section.notifications: 'milestone 10',
    _Section.privacy: 'milestone 3',
    _Section.peopleGroups: 'milestone 7',
    _Section.feeds: 'milestone 8',
    _Section.tags: 'milestone 9',
    _Section.defaultApp: 'milestone 10',
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
