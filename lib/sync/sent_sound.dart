import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';

import '../platform/android_bridge.dart';
import '../store/database.dart';

/// The setting for the sound played when mail has gone out ('0' is off).
const kSentSound = 'sound.sent';

/// Précis's own short sound for "your message has gone": two soft rising
/// notes. Played once the mail server has taken the message, never before.
class SentSound {
  SentSound(this._ref);
  final Ref _ref;
  String? _file;

  Future<void> play() async {
    try {
      if (await _ref.read(databaseProvider).getSetting(kSentSound) == '0') return;
      if (Platform.isAndroid) {
        await _ref.read(androidBridgeProvider).playSent();
      } else if (Platform.isWindows) {
        final path = _file ??= await _onDisk();
        using((arena) => PlaySound(path.toNativeUtf16(allocator: arena), 0, SND_FILENAME | SND_ASYNC | SND_NODEFAULT));
      }
    } catch (_) {
      // A sound that cannot play never gets in the way of the mail.
    }
  }

  /// Windows plays sounds from files: the sound is copied out once.
  Future<String> _onDisk() async {
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'sounds'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'sent.wav'));
    final data = await rootBundle.load('assets/sounds/sent.wav');
    if (!file.existsSync() || file.lengthSync() != data.lengthInBytes) {
      await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    }
    return file.path;
  }
}

/// Replaceable in tests, which play nothing.
final sentSoundProvider = Provider<Future<void> Function()>((ref) {
  final sound = SentSound(ref);
  return sound.play;
});
