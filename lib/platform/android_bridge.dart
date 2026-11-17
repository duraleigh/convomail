import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'credential_store.dart';

/// The few things only Android can do for the app: keep secrets locked in
/// the phone's own key store, and handle alerts. The other side is in
/// `android/app/src/main/kotlin/com/clayaiken/precis/`.
class AndroidBridge {
  AndroidBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'opened' && call.arguments is String) _opened.add(call.arguments as String);
      if (call.method == 'shared' && call.arguments is String) {
        final s = SharedIn.parse(call.arguments as String);
        if (s != null) _shared.add(s);
      }
    });
  }

  static const _channel = MethodChannel('precis/android');
  final _opened = StreamController<String>.broadcast();
  final _shared = StreamController<SharedIn>.broadcast();

  /// Something shared to Précis from another app while Précis was open.
  Stream<SharedIn> get shared => _shared.stream;

  /// What was shared to Précis to open it, once.
  Future<SharedIn?> takeShared() async => SharedIn.parse(await _channel.invokeMethod<String>('takeShared'));

  /// The Message-ID of an email whose alert was tapped while the app was open.
  Stream<String> get opened => _opened.stream;

  /// The email whose alert opened the app, once.
  Future<String?> takeOpened() => _channel.invokeMethod<String>('takeOpened');

  Future<String?> vaultRead(String key) => _channel.invokeMethod<String>('vaultRead', {'key': key});
  Future<void> vaultWrite(String key, String value) => _channel.invokeMethod<void>('vaultWrite', {'key': key, 'value': value});
  Future<void> vaultDelete(String key) => _channel.invokeMethod<void>('vaultDelete', {'key': key});

  /// Whether the phone lets Précis show alerts.
  Future<bool> alertsAllowed() async => await _channel.invokeMethod<bool>('alertsAllowed') ?? false;

  /// Asks the user to allow alerts (Android 13 and later ask once).
  Future<bool> askForAlerts() async => await _channel.invokeMethod<bool>('alertsAsk') ?? false;

  /// Signs the phone up with Google's alert service. Returns the phone's
  /// address for alerts, or null when that did not work.
  Future<String?> startAlerts(Map<String, String> app, String helper) => _channel.invokeMethod<String>('alertsStart', {'app': app, 'helper': helper});

  Future<void> stopAlerts() => _channel.invokeMethod<void>('alertsStop');
  Future<void> setRing(bool ring) => _channel.invokeMethod<void>('alertsRing', {'ring': ring});

  /// Tells the phone's alerts how to write a time: 15:00 or 3:00 PM.
  Future<void> setClock24(bool h24) => _channel.invokeMethod<void>('alertsClock', {'h24': h24});

  /// Done and Later pressed on alerts while the phone had no signal, in
  /// the helper's words, waiting to be sent.
  Future<List<Map<String, Object?>>> waitingChanges() async {
    final json = await _channel.invokeMethod<String>('alertsWaiting') ?? '[]';
    try {
      return [for (final c in jsonDecode(json) as List) (c as Map).cast<String, Object?>()];
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearWaiting() => _channel.invokeMethod<void>('alertsClearWaiting');

  /// Plays the short "sent" sound.
  Future<void> playSent() => _channel.invokeMethod<void>('playSent');

  /// Takes every alert off the screen (the user is looking at Focus itself).
  Future<void> clearShown() => _channel.invokeMethod<void>('alertsClearShown');
}

/// What another app handed to Précis through the phone's Share menu.
class SharedIn {
  const SharedIn({this.text = '', this.subject = '', this.files = const [], this.skipped = 0, this.big = 0});

  /// Shared words, or a link.
  final String text;

  /// What the other app called it (a web page's title, say).
  final String subject;

  /// Shared pictures and files, already copied to this phone's own space.
  final List<String> files;

  /// How many files could not be read, and how many were left out for size.
  final int skipped;
  final int big;

  bool get isEmpty => text.trim().isEmpty && subject.trim().isEmpty && files.isEmpty && skipped == 0 && big == 0;

  /// From the phone side's JSON; null when there is nothing in it.
  static SharedIn? parse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      final s = SharedIn(
        text: m['text'] as String? ?? '',
        subject: m['subject'] as String? ?? '',
        files: [for (final f in m['files'] as List? ?? const []) if (f is String && f.isNotEmpty) f],
        skipped: (m['skipped'] as num?)?.toInt() ?? 0,
        big: (m['big'] as num?)?.toInt() ?? 0,
      );
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }
}

final androidBridgeProvider = Provider<AndroidBridge>((ref) => AndroidBridge());

/// Secrets on Android: locked with a key in the phone's own key store.
class AndroidCredentialStore implements CredentialStore {
  AndroidCredentialStore(this._bridge);
  final AndroidBridge _bridge;

  @override
  Future<String?> read(String key) => _bridge.vaultRead(key);

  @override
  Future<void> write(String key, String value) => _bridge.vaultWrite(key, value);

  @override
  Future<void> delete(String key) => _bridge.vaultDelete(key);
}
