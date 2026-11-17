import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_log.dart';
import '../app/compose_state.dart';
import '../app/destinations.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';
import '../sync/schedule_service.dart';
import '../ui/shell/compact_shell.dart';
import 'android_bridge.dart';

/// Précis in the phone's Share menu: words, a link, pictures or files
/// shared from another app open a new email with them in it. Who it goes
/// to, and sending it, stay with the user.
class PhoneShare {
  PhoneShare(this._ref);
  final Ref _ref;
  StreamSubscription<SharedIn>? _shared;

  AndroidBridge get _bridge => _ref.read(androidBridgeProvider);

  /// Call once the app is up. Does nothing on a PC.
  void start() {
    if (!Platform.isAndroid) return;
    _shared ??= _bridge.shared.listen((s) => unawaited(receive(s)));
    unawaited(_bridge.takeShared().then((s) {
      if (s != null) return receive(s);
    }).catchError((Object _) {}));
  }

  void stop() => _shared?.cancel();

  /// Opens a new email holding what was shared.
  Future<void> receive(SharedIn s) async {
    try {
      final notices = _ref.read(appNoticesProvider.notifier);
      void tell(String title, [String body = '']) => notices.add(AppNotice(id: 'share:${DateTime.now().microsecondsSinceEpoch}', title: title, body: body, at: DateTime.now()));

      // A phone that has not joined yet has no one to send as.
      if ((await _ref.read(databaseProvider).allAccounts()).isEmpty) return;

      final left = [
        if (s.big > 0) s.big == 1 ? 'One file was too big to email' : '${s.big} files were too big to email',
        if (s.skipped > 0) s.skipped == 1 ? 'One file could not be read' : '${s.skipped} files could not be read',
      ];
      if (s.text.trim().isEmpty && s.files.isEmpty) {
        // Nothing came through that an email could hold.
        if (left.isNotEmpty) tell('Nothing to share', '${left.join(', and ')}.');
        return;
      }
      _ref.read(compactPageProvider.notifier).show(CompactPage.main);
      _ref.read(destinationProvider.notifier).select(Destination.chats);
      _ref.read(composeProvider.notifier).open(ComposeRequest.newMessage(subject: s.subject.trim(), body: s.text.trim(), attachments: s.files));
      if (left.isNotEmpty) tell('Not everything was added', '${left.join(', and ')}.');
    } catch (e, st) {
      AppLog.current?.error('taking in something shared from another app failed', AppLog.scrub(e), st);
    }
  }
}

final phoneShareProvider = Provider<PhoneShare>((ref) {
  final s = PhoneShare(ref);
  ref.onDispose(s.stop);
  return s;
});
