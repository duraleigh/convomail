import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/settings_store.dart';

/// App-wide user settings persisted in the `settings` table (spec 4.18).
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.dynamicColor = false,
    this.middlePaneWidth = 340,
  });

  final ThemeMode themeMode;
  final bool dynamicColor;
  final double middlePaneWidth;

  AppSettings copyWith({ThemeMode? themeMode, bool? dynamicColor, double? middlePaneWidth}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        dynamicColor: dynamicColor ?? this.dynamicColor,
        middlePaneWidth: middlePaneWidth ?? this.middlePaneWidth,
      );
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _kTheme = 'appearance.themeMode';
  static const _kDynamic = 'appearance.dynamicColor';
  static const _kPane = 'layout.middlePaneWidth';

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
    state = AppSettings(
      themeMode: ThemeMode.values.firstWhere((m) => m.name == theme, orElse: () => ThemeMode.system),
      dynamicColor: dynamic == 'true',
      middlePaneWidth: double.tryParse(pane ?? '') ?? 340,
    );
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
