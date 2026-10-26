import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Single-instance enforcement (spec 5.3 single-window rule, plan M10).
///
/// The first instance listens on a loopback port recorded in
/// `<support>/instance.json`. A later instance connects, hands over its
/// command-line arguments (a `mailto:` link, usually) as one JSON line,
/// and exits. If the recorded port is dead the file is stale and the new
/// instance takes over. Pure Dart, no named mutex needed.
class SingleInstance {
  SingleInstance(this.supportDir);
  final Directory supportDir;
  ServerSocket? _server;

  File get _lockFile => File(p.join(supportDir.path, 'instance.json'));

  /// Tries to forward [args] to a running instance. Returns true when one
  /// accepted them (the caller should exit).
  Future<bool> forwardToRunning(List<String> args, {Duration timeout = const Duration(milliseconds: 800)}) async {
    final port = _recordedPort();
    if (port == null) return false;
    try {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: timeout);
      socket.write('${jsonEncode({'args': args, 'pid': pid})}\n');
      await socket.flush();
      final reply = await socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first.timeout(timeout, onTimeout: () => '');
      socket.destroy();
      return reply.trim() == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Starts listening; [onArgs] receives each forwarded argument list.
  Future<void> becomePrimary(void Function(List<String> args) onArgs) async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    await supportDir.create(recursive: true);
    await _lockFile.writeAsString(jsonEncode({'port': _server!.port, 'pid': pid}));
    _server!.listen((socket) {
      socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        try {
          final m = jsonDecode(line) as Map<String, dynamic>;
          final args = (m['args'] as List?)?.cast<String>() ?? const <String>[];
          onArgs(args);
          socket.write('ok\n');
        } catch (_) {
          socket.write('error\n');
        }
        socket.flush().then((_) => socket.destroy());
      }, onError: (_) => socket.destroy());
    });
  }

  int get port => _server?.port ?? -1;

  Future<void> close() async {
    await _server?.close();
    _server = null;
    try {
      if (_lockFile.existsSync()) await _lockFile.delete();
    } catch (_) {}
  }

  int? _recordedPort() {
    try {
      if (!_lockFile.existsSync()) return null;
      final m = jsonDecode(_lockFile.readAsStringSync()) as Map<String, dynamic>;
      return m['port'] as int?;
    } catch (_) {
      return null;
    }
  }
}
