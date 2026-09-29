import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Key/value persistence for app settings. The database implements this;
/// tests use [InMemorySettingsStore].
abstract interface class SettingsStore {
  Future<String?> getSetting(String key);
  Future<void> putSetting(String key, String value);
}

class InMemorySettingsStore implements SettingsStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> getSetting(String key) async => _values[key];

  @override
  Future<void> putSetting(String key, String value) async => _values[key] = value;

  Map<String, String> get values => Map.unmodifiable(_values);
}

/// The settings store used by the app: the drift database.
final settingsStoreProvider = Provider<SettingsStore>((ref) => ref.watch(databaseProvider));
