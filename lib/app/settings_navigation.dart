import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sections of the Settings destination (spec 5.3). Held in a provider so
/// other screens can deep-link, e.g. "Add account" from the empty inbox.
enum SettingsSection {
  accounts('Accounts', Icons.account_circle_outlined),
  appearance('Appearance', Icons.palette_outlined),
  notifications('Notifications', Icons.notifications_outlined),
  privacy('Privacy', Icons.shield_outlined),
  peopleGroups('People Groups', Icons.group_outlined),
  feeds('Feeds', Icons.rss_feed_rounded),
  tags('Groups & Tags', Icons.label_outline_rounded),
  keyboard('Keyboard', Icons.keyboard_outlined),
  defaultApp('Default mail app', Icons.mail_outline_rounded);

  const SettingsSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

final settingsSectionProvider = NotifierProvider<SettingsSectionNotifier, SettingsSection>(SettingsSectionNotifier.new);

class SettingsSectionNotifier extends Notifier<SettingsSection> {
  @override
  SettingsSection build() => SettingsSection.accounts;
  void select(SettingsSection s) => state = s;
}

/// Set when a screen wants Settings → Accounts to open with the add flow.
final settingsAddAccountRequestProvider = NotifierProvider<_FlagNotifier, bool>(_FlagNotifier.new);

class _FlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}
