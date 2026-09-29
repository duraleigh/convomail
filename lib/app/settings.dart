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
  });

  final ThemeMode themeMode;
  final bool dynamicColor;
  final double middlePaneWidth;

  /// Spec 4.13: remote images blocked by default; a global toggle turns
  /// blocking off entirely.
  final bool blockRemoteImages;

  AppSettings copyWith({ThemeMode? themeMode, bool? dynamicColor, double? middlePaneWidth, bool? blockRemoteImages}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        dynamicColor: dynamicColor ?? this.dynamicColor,
        middlePaneWidth: middlePaneWidth ?? this.middlePaneWidth,
        blockRemoteImages: blockRemoteImages ?? this.blockRemoteImages,
      );
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _kTheme = 'appearance.themeMode';
  static const _kDynamic = 'appearance.dynamicColor';
  static const _kPane = 'layout.middlePaneWidth';
  static const _kBlockImages = 'privacy.blockRemoteImages';

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
    state = AppSettings(
      themeMode: ThemeMode.values.firstWhere((m) => m.name == theme, orElse: () => ThemeMode.system),
      dynamicColor: dynamic == 'true',
      middlePaneWidth: double.tryParse(pane ?? '') ?? 340,
      blockRemoteImages: block != 'false',
    );
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
