import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/settings_store.dart';

/// App-wide user settings persisted in the `settings` table (spec 4.18).
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.dynamicColor = false,
    this.middlePaneWidth = 340,
    this.blockRemoteImages = true,
    this.searchIncludeFeeds = false,
    this.notificationsEnabled = true,
    this.badgeIncludeFeeds = false,
    this.mutedAccounts = const {},
    this.closeToTray = true,
    this.launchAtLogin = false,
    this.showBadge = true,
  });

  final ThemeMode themeMode;
  final bool dynamicColor;
  final double middlePaneWidth;

  /// Spec 4.13: remote images blocked by default; a global toggle turns
  /// blocking off entirely.
  final bool blockRemoteImages;

  /// Spec 4.6: search results come from People rows only unless this is on.
  final bool searchIncludeFeeds;

  /// Spec 4.17: global toast switch, badge scope (People only by default),
  /// and per-account mute.
  final bool notificationsEnabled;
  final bool badgeIncludeFeeds;
  final Set<int> mutedAccounts;

  /// Windows integration (spec 4.17, plan M10).
  final bool closeToTray;
  final bool launchAtLogin;
  final bool showBadge;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? dynamicColor,
    double? middlePaneWidth,
    bool? blockRemoteImages,
    bool? searchIncludeFeeds,
    bool? notificationsEnabled,
    bool? badgeIncludeFeeds,
    Set<int>? mutedAccounts,
    bool? closeToTray,
    bool? launchAtLogin,
    bool? showBadge,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        dynamicColor: dynamicColor ?? this.dynamicColor,
        middlePaneWidth: middlePaneWidth ?? this.middlePaneWidth,
        blockRemoteImages: blockRemoteImages ?? this.blockRemoteImages,
        searchIncludeFeeds: searchIncludeFeeds ?? this.searchIncludeFeeds,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        badgeIncludeFeeds: badgeIncludeFeeds ?? this.badgeIncludeFeeds,
        mutedAccounts: mutedAccounts ?? this.mutedAccounts,
        closeToTray: closeToTray ?? this.closeToTray,
        launchAtLogin: launchAtLogin ?? this.launchAtLogin,
        showBadge: showBadge ?? this.showBadge,
      );
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _kTheme = 'appearance.themeMode';
  static const _kDynamic = 'appearance.dynamicColor';
  static const _kPane = 'layout.middlePaneWidth';
  static const _kBlockImages = 'privacy.blockRemoteImages';
  static const _kIncludeFeeds = 'search.includeFeeds';
  static const _kNotify = 'notifications.enabled';
  static const _kBadgeFeeds = 'notifications.badgeIncludeFeeds';
  static const _kMuted = 'notifications.mutedAccounts';
  static const _kCloseToTray = 'windows.closeToTray';
  static const _kLaunchAtLogin = 'windows.launchAtLogin';
  static const _kShowBadge = 'windows.showBadge';

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  SettingsStore get _db => ref.read(settingsStoreProvider);

  Future<void> _load() async {
    final theme = await _db.getSetting(_kTheme);
    final dynamic = await _db.getSetting(_kDynamic);
    final pane = await _db.getSetting(_kPane);
    final block = await _db.getSetting(_kBlockImages);
    final feeds = await _db.getSetting(_kIncludeFeeds);
    final notify = await _db.getSetting(_kNotify);
    final badgeFeeds = await _db.getSetting(_kBadgeFeeds);
    final muted = await _db.getSetting(_kMuted);
    final tray = await _db.getSetting(_kCloseToTray);
    final login = await _db.getSetting(_kLaunchAtLogin);
    final badge = await _db.getSetting(_kShowBadge);
    state = AppSettings(
      themeMode: ThemeMode.values.firstWhere((m) => m.name == theme, orElse: () => ThemeMode.system),
      dynamicColor: dynamic == 'true',
      middlePaneWidth: double.tryParse(pane ?? '') ?? 340,
      blockRemoteImages: block != 'false',
      searchIncludeFeeds: feeds == 'true',
      notificationsEnabled: notify != 'false',
      badgeIncludeFeeds: badgeFeeds == 'true',
      mutedAccounts: {for (final s in (muted ?? '').split(',')) if (int.tryParse(s) != null) int.parse(s)},
      closeToTray: tray != 'false',
      launchAtLogin: login == 'true',
      showBadge: badge != 'false',
    );
    loaded = true;
  }

  /// True once the stored values have been read (the first state is defaults).
  bool loaded = false;

  Future<void> setCloseToTray(bool on) async {
    state = state.copyWith(closeToTray: on);
    await _db.putSetting(_kCloseToTray, on.toString());
  }

  Future<void> setLaunchAtLogin(bool on) async {
    state = state.copyWith(launchAtLogin: on);
    await _db.putSetting(_kLaunchAtLogin, on.toString());
  }

  Future<void> setShowBadge(bool on) async {
    state = state.copyWith(showBadge: on);
    await _db.putSetting(_kShowBadge, on.toString());
  }

  Future<void> setNotificationsEnabled(bool on) async {
    state = state.copyWith(notificationsEnabled: on);
    await _db.putSetting(_kNotify, on.toString());
  }

  Future<void> setBadgeIncludeFeeds(bool on) async {
    state = state.copyWith(badgeIncludeFeeds: on);
    await _db.putSetting(_kBadgeFeeds, on.toString());
  }

  Future<void> setAccountMuted(int accountId, bool muted) async {
    final set = {...state.mutedAccounts};
    muted ? set.add(accountId) : set.remove(accountId);
    state = state.copyWith(mutedAccounts: set);
    await _db.putSetting(_kMuted, set.join(','));
  }

  Future<void> setSearchIncludeFeeds(bool on) async {
    state = state.copyWith(searchIncludeFeeds: on);
    await _db.putSetting(_kIncludeFeeds, on.toString());
  }

  Future<void> setBlockRemoteImages(bool on) async {
    state = state.copyWith(blockRemoteImages: on);
    await _db.putSetting(_kBlockImages, on.toString());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _db.putSetting(_kTheme, mode.name);
  }

  Future<void> setDynamicColor(bool on) async {
    state = state.copyWith(dynamicColor: on);
    await _db.putSetting(_kDynamic, on.toString());
  }

  Future<void> setMiddlePaneWidth(double w) async {
    state = state.copyWith(middlePaneWidth: w);
    await _db.putSetting(_kPane, w.toStringAsFixed(0));
  }
}
