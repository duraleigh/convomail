import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Local-only diagnostics log (plan M12: "crash reporting that stores logs
/// locally only"). One file per day under `<support dir>/logs`, pruned to
/// the last [keepDays]. Nothing is ever uploaded. Entries hold exception
/// text and stack traces, never message bodies, addresses, or credentials;
/// callers must keep it that way.
class AppLog {
  AppLog(this.dir, {this.keepDays = 7, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Directory dir;
  final int keepDays;
  final DateTime Function() _clock;

  static const _prefix = 'convomail-';

  File get todayFile => fileFor(_clock());

  File fileFor(DateTime day) => File(p.join(dir.path, '$_prefix${_date(day)}.log'));

  static String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> init() async {
    await dir.create(recursive: true);
    await prune();
  }

  void info(String message) => _append('INFO', message);
  void warn(String message, [Object? error]) => _append('WARN', message, error);
  void error(String message, [Object? error, StackTrace? stack]) => _append('ERROR', message, error, stack);

  void _append(String level, String message, [Object? error, StackTrace? stack]) {
    final buf = StringBuffer()..write('${_clock().toIso8601String()} $level $message');
    if (error != null) buf.write(' | $error');
    buf.writeln();
    if (stack != null) buf.writeln(stack.toString().trimRight());
    try {
      dir.createSync(recursive: true);
      todayFile.writeAsStringSync(buf.toString(), mode: FileMode.append, flush: true);
    } catch (_) {
      // Logging must never take the app down.
    }
  }

  /// Log files for days older than [keepDays] are deleted.
  Future<void> prune() async {
    if (!await dir.exists()) return;
    final cutoff = _clock().subtract(Duration(days: keepDays));
    await for (final f in dir.list()) {
      if (f is! File) continue;
      final name = p.basename(f.path);
      if (!name.startsWith(_prefix) || !name.endsWith('.log')) continue;
      final day = DateTime.tryParse(name.substring(_prefix.length, name.length - 4));
      if (day != null && day.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  Future<List<File>> files() async {
    if (!await dir.exists()) return const [];
    final out = <File>[];
    await for (final f in dir.list()) {
      if (f is File && p.basename(f.path).startsWith(_prefix)) out.add(f);
    }
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  Future<int> totalBytes() async {
    var n = 0;
    for (final f in await files()) {
      n += await f.length();
    }
    return n;
  }

  Future<void> clear() async {
    for (final f in await files()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  /// Routes framework and uncaught asynchronous errors into [log]. Debug
  /// builds keep the console output too.
  static void install(AppLog log) {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      log.error('flutter', details.exceptionAsString(), details.stack);
      if (kDebugMode) previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      log.error('uncaught', error, stack);
      return true;
    };
  }
}

/// Null outside the Windows app (tests, benches); main overrides it.
final appLogProvider = Provider<AppLog?>((ref) => null);
