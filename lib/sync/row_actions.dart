import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/database.dart';
import '../store/people_queries.dart';
import '../store/sync_queries.dart';
import 'sync_controller.dart';
import 'sync_engine.dart';

/// A destructive bulk action that is applied locally at once and to the
/// server only after the undo window closes (spec 4.16).
class PendingAction {
  PendingAction({required this.id, required this.label, required this.messageIds, required this.undo, required this.commit});
  final int id;
  final String label;
  final List<int> messageIds;
  final Future<void> Function() undo;
  final Future<void> Function() commit;
  Timer? timer;
}

/// Live list of actions still inside their undo window, for the snackbar.
final pendingActionsProvider = NotifierProvider<PendingActionsNotifier, List<PendingAction>>(PendingActionsNotifier.new);

class PendingActionsNotifier extends Notifier<List<PendingAction>> {
  @override
  List<PendingAction> build() => const [];
  void add(PendingAction a) => state = [...state, a];
  void remove(int id) => state = [for (final a in state) if (a.id != id) a];
}

final rowActionsProvider = Provider<RowActions>((ref) => RowActions(ref));

/// Actions on a People row: archive, trash, mark read, pin (spec 4.2, 4.16).
///
/// Archive and trash hide the messages locally immediately, then hit the
/// server when the undo window (default 6 s) expires. Undo restores the
/// local rows and cancels the server call. Mark-read and pin apply at once.
class RowActions {
  RowActions(this._ref, {this.undoWindow = const Duration(seconds: 6)});

  final Ref _ref;
  final Duration undoWindow;
  int _nextId = 1;

  AppDatabase get _db => _ref.read(databaseProvider);

  Future<void> togglePin(String rowKey) async {
    final pref = await _db.rowPref(rowKey);
    await _db.setPinned(rowKey, !(pref?.pinned ?? false));
  }

  /// Marks every message in the row seen, locally and on the server.
  Future<void> markRowRead(String rowKey) async {
    final msgs = (await _db.messagesForRow(rowKey)).where((m) => !m.isSeen).toList();
    if (msgs.isEmpty) return;
    await (_db.update(_db.messages)..where((m) => m.id.isIn(msgs.map((m) => m.id).toList()))).write(const MessagesCompanion(isSeen: Value(true)));
    await _db.refreshDirtyRows();
    await _forEachFolder(msgs, (syncer, folderId, uids) => syncer.setFlags(folderId, uids, seen: true));
  }

  Future<void> markMessageRead(int messageId, {bool seen = true}) async {
    final m = await _db.messageById(messageId);
    if (m == null || m.isSeen == seen) return;
    await (_db.update(_db.messages)..where((x) => x.id.equals(messageId))).write(MessagesCompanion(isSeen: Value(seen)));
    await _db.refreshDirtyRows();
    await _forEachFolder([m], (syncer, folderId, uids) => syncer.setFlags(folderId, uids, seen: seen));
  }

  /// Archives all messages in the row (or only [messageIds] when given, for
  /// selective keep). Returns the pending action for the undo snackbar.
  Future<PendingAction?> archiveRow(String rowKey, {List<int>? messageIds, String? label}) => _hideThenCommit(
        rowKey,
        messageIds: messageIds,
        label: label ?? 'Archived',
        serverOp: (syncer, folderId, uids) => syncer.archiveOnServer(folderId, uids),
      );

  /// Trashes all messages in the row (or only [messageIds]).
  Future<PendingAction?> trashRow(String rowKey, {List<int>? messageIds, String? label}) => _hideThenCommit(
        rowKey,
        messageIds: messageIds,
        label: label ?? 'Moved to Trash',
        serverOp: (syncer, folderId, uids) => syncer.trashOnServer(folderId, uids),
      );

  Future<PendingAction?> _hideThenCommit(
    String rowKey, {
    required List<int>? messageIds,
    required String label,
    required Future<void> Function(AccountSyncer syncer, int folderId, List<int> uids) serverOp,
  }) async {
    var msgs = await _db.messagesForRow(rowKey);
    if (messageIds != null) {
      final wanted = messageIds.toSet();
      msgs = msgs.where((m) => wanted.contains(m.id)).toList();
    }
    if (msgs.isEmpty) return null;
    final ids = msgs.map((m) => m.id).toList();

    // Local first: hide now. The People query excludes is_deleted rows.
    await (_db.update(_db.messages)..where((m) => m.id.isIn(ids))).write(const MessagesCompanion(isDeleted: Value(true)));
    await _db.refreshDirtyRows();

    final action = PendingAction(
      id: _nextId++,
      label: '$label · ${ids.length} message${ids.length == 1 ? '' : 's'}',
      messageIds: ids,
      undo: () async {
        await (_db.update(_db.messages)..where((m) => m.id.isIn(ids))).write(const MessagesCompanion(isDeleted: Value(false)));
        await _db.refreshDirtyRows();
      },
      commit: () async {
        await _forEachFolder(msgs, serverOp);
        // The server no longer has them; drop the local rows so a later
        // reconciliation does not need to.
        await (_db.delete(_db.messages)..where((m) => m.id.isIn(ids))).go();
        await _db.refreshDirtyRows();
      },
    );
    final pending = _ref.read(pendingActionsProvider.notifier);
    pending.add(action);
    action.timer = Timer(undoWindow, () async {
      pending.remove(action.id);
      try {
        await action.commit();
      } catch (_) {
        // Server call failed: bring the messages back so nothing is lost
        // silently. The next sync reconciles.
        await action.undo();
      }
    });
    return action;
  }

  Future<void> undo(PendingAction action) async {
    action.timer?.cancel();
    _ref.read(pendingActionsProvider.notifier).remove(action.id);
    await action.undo();
  }

  /// Flushes pending actions immediately (app shutdown).
  Future<void> commitAll() async {
    for (final a in List.of(_ref.read(pendingActionsProvider))) {
      a.timer?.cancel();
      _ref.read(pendingActionsProvider.notifier).remove(a.id);
      await a.commit();
    }
  }

  /// Groups messages by account+folder and runs [op] through that account's
  /// syncer. Accounts without a running syncer are skipped; the change
  /// stays local and reconciles on the next sync.
  Future<void> _forEachFolder(List<Message> msgs, Future<void> Function(AccountSyncer syncer, int folderId, List<int> uids) op) async {
    final controller = _ref.read(syncControllerProvider);
    final byFolder = <(int, int), List<int>>{};
    for (final m in msgs) {
      byFolder.putIfAbsent((m.accountId, m.folderId), () => []).add(m.uid);
    }
    for (final e in byFolder.entries) {
      final syncer = controller.syncerFor(e.key.$1);
      if (syncer == null) continue;
      await op(syncer, e.key.$2, e.value);
    }
  }
}
