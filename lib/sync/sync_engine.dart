import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../mail/mail_transport.dart';
import '../mail/models.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';

enum SyncPhase { idle, connecting, listingFolders, syncingFolder, waitingForMail, backoff, error, stopped }

class SyncStatus {
  const SyncStatus({
    required this.accountId,
    required this.phase,
    this.folderPath,
    this.folderDone = 0,
    this.folderTotal = 0,
    this.messagesFetched = 0,
    this.message,
    this.error,
  });

  final int accountId;
  final SyncPhase phase;
  final String? folderPath;
  final int folderDone;
  final int folderTotal;
  final int messagesFetched;
  final String? message;
  final String? error;

  SyncStatus copyWith({SyncPhase? phase, String? folderPath, int? folderDone, int? folderTotal, int? messagesFetched, String? message, String? error}) => SyncStatus(
        accountId: accountId,
        phase: phase ?? this.phase,
        folderPath: folderPath ?? this.folderPath,
        folderDone: folderDone ?? this.folderDone,
        folderTotal: folderTotal ?? this.folderTotal,
        messagesFetched: messagesFetched ?? this.messagesFetched,
        message: message,
        error: error,
      );

  @override
  String toString() => 'SyncStatus($accountId ${phase.name}${folderPath == null ? '' : ' $folderPath'} $folderDone/$folderTotal fetched=$messagesFetched${error == null ? '' : ' error=$error'})';
}

/// Syncs one account: folder discovery, header sync, flag and deletion
/// reconciliation, on-demand bodies, and an IDLE loop on the inbox.
///
/// UID bookkeeping per folder (plan M1):
/// - `lastSyncedUid` is the high-water mark of stored headers.
/// - New mail is everything above it.
/// - Deletions and flag changes are reconciled for UIDs up to it.
/// - A UIDVALIDITY change wipes the folder and starts over.
class AccountSyncer {
  AccountSyncer({
    required this.db,
    required this.transport,
    required this.account,
    required this.credentials,
    this.pageSize = 500,
    this.idleTimeout = const Duration(minutes: 20),
    this.syncFolderRoles = const {FolderRole.inbox, FolderRole.sent, FolderRole.archive, FolderRole.other},
    this.sleep = _defaultSleep,
    this.onStatus,
  }) : _status = SyncStatus(accountId: account.id, phase: SyncPhase.idle);

  final AppDatabase db;
  final MailTransport transport;
  final Account account;
  final Future<MailCredentials> Function() credentials;
  final int pageSize;
  final Duration idleTimeout;
  final Set<FolderRole> syncFolderRoles;
  final Future<void> Function(Duration) sleep;

  final void Function(SyncStatus)? onStatus;
  SyncStatus _status;
  bool _stopRequested = false;
  int _consecutiveFailures = 0;

  SyncStatus get status => _status;

  static Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

  void _emit(SyncStatus s) {
    _status = s;
    onStatus?.call(s);
  }

  ServerConfig get _server => ServerConfig(
        host: account.imapHost,
        port: account.imapPort,
        security: ConnectionSecurityName.parse(account.imapSecurity),
      );

  Future<void> _ensureConnected() async {
    if (transport.isConnected) return;
    _emit(_status.copyWith(phase: SyncPhase.connecting));
    await transport.connect(_server, await credentials());
  }

  /// One full pass over all folders that this syncer covers.
  Future<void> syncOnce() async {
    try {
      await _ensureConnected();
      _emit(_status.copyWith(phase: SyncPhase.listingFolders));
      final remote = await transport.listFolders();
      final byPath = await db.upsertFolders(account.id, remote);
      final targets = byPath.values.where((f) => f.selectable && syncFolderRoles.contains(_roleOf(f))).toList()
        ..sort((a, b) => _priority(a).compareTo(_priority(b)));

      var done = 0;
      for (final folder in targets) {
        if (_stopRequested) break;
        _emit(_status.copyWith(phase: SyncPhase.syncingFolder, folderPath: folder.path, folderDone: done, folderTotal: targets.length));
        await syncFolder(folder.id);
        done++;
        if (_roleOf(folder) == FolderRole.sent) {
          // Learn "send as" aliases from what the user actually sent, then
          // re-file everything that was attributed to those addresses.
          final added = await db.discoverIdentitiesFromSent(account.id, folder.id);
          if (added > 0) {
            _emit(_status.copyWith(message: 'found $added sending identit${added == 1 ? 'y' : 'ies'}, re-filing'));
            await db.refileAccount(account.id);
          }
        }
      }
      await db.setAccountSyncResult(account.id);
      _consecutiveFailures = 0;
      _emit(_status.copyWith(phase: SyncPhase.idle, folderDone: done, folderTotal: targets.length, folderPath: null));
    } on MailTransportException catch (e) {
      _consecutiveFailures++;
      await db.setAccountSyncResult(account.id, error: e.message);
      _emit(_status.copyWith(phase: SyncPhase.error, error: e.message));
      if (e.isAuthFailure) rethrow;
    }
  }

  static FolderRole _roleOf(Folder f) => FolderRole.values.firstWhere((r) => r.name == f.role, orElse: () => FolderRole.other);

  static int _priority(Folder f) => switch (_roleOf(f)) {
        FolderRole.inbox => 0,
        FolderRole.sent => 1,
        FolderRole.archive => 2,
        _ => 3,
      };

  /// Syncs a single folder: new headers above the high-water mark, then
  /// reconciliation of deletions and flags below it.
  Future<void> syncFolder(int folderId) async {
    await _ensureConnected();
    var folder = await db.folderById(folderId);
    if (folder == null) return;

    final status = await transport.selectFolder(folder.path);

    if (folder.uidValidity != null && folder.uidValidity != status.uidValidity) {
      await db.clearFolderMessages(folderId);
      folder = (await db.folderById(folderId))!;
    }

    final filing = await db.loadFilingRule();
    final highWater = folder.lastSyncedUid;
    final serverTop = status.uidNext - 1;
    var fetched = 0;

    // --- new messages above the high-water mark, newest page first so the
    // list fills from the top on a first sync.
    if (serverTop > highWater) {
      var pageEnd = serverTop;
      var newHighWater = highWater;
      while (pageEnd > highWater && !_stopRequested) {
        final pageStart = math.max(highWater + 1, pageEnd - pageSize + 1);
        final headers = await transport.fetchHeaders(fromUid: pageStart, toUid: pageEnd);
        fetched += await db.upsertHeaders(account.id, folderId, headers, filing);
        // Record progress so an interrupted first sync resumes where it left
        // off; the high-water mark only advances once the top page is stored.
        newHighWater = math.max(newHighWater, pageEnd);
        if (pageEnd == serverTop) {
          await db.updateFolderState(folderId, uidValidity: status.uidValidity, uidNext: status.uidNext, lastSyncedUid: newHighWater, messagesExists: status.exists);
        }
        pageEnd = pageStart - 1;
        _emit(_status.copyWith(messagesFetched: _status.messagesFetched + headers.length));
      }
    }

    // --- reconcile deletions and flags for what we already had.
    if (highWater > 0) {
      final existing = await transport.fetchExistingUids(maxUid: highWater);
      await db.deleteVanished(folderId, existing, lowUid: 1, highUid: highWater);
      final flags = await transport.fetchFlags(maxUid: highWater, changedSinceModSeq: folder.highestModSeq);
      await db.applyFlagUpdates(folderId, flags);
    }

    await db.updateFolderState(
      folderId,
      uidValidity: status.uidValidity,
      uidNext: status.uidNext,
      highestModSeq: status.highestModSeq,
      lastSyncedUid: math.max(highWater, serverTop),
      messagesExists: status.exists,
    );
    _emit(_status.copyWith(messagesFetched: _status.messagesFetched, message: '$fetched new in ${folder.path}'));
  }

  /// Fetches and stores a message body on demand.
  Future<RemoteMessageBody> fetchBody(int messageDbId) async {
    final m = await db.messageById(messageDbId);
    if (m == null) throw StateError('No message $messageDbId');
    final folder = await db.folderById(m.folderId);
    if (folder == null) throw StateError('No folder ${m.folderId}');
    await _ensureConnected();
    await transport.selectFolder(folder.path);
    final body = await transport.fetchBody(m.uid);
    await db.storeBody(messageDbId, body);
    return body;
  }

  /// Decoded bytes for attachment parts of a stored message.
  Future<Map<String, Uint8List>> fetchParts(int messageDbId, List<String> partIds) async {
    final m = await db.messageById(messageDbId);
    if (m == null) throw StateError('No message $messageDbId');
    final folder = await db.folderById(m.folderId);
    if (folder == null) throw StateError('No folder ${m.folderId}');
    await _ensureConnected();
    await transport.selectFolder(folder.path);
    return transport.fetchParts(m.uid, partIds);
  }

  /// Pushes flag changes to the server and mirrors them locally.
  Future<void> setFlags(int folderId, List<int> uids, {bool? seen, bool? flagged, bool? answered, bool? deleted}) async {
    final folder = await db.folderById(folderId);
    if (folder == null) return;
    await _ensureConnected();
    await transport.selectFolder(folder.path);
    await transport.setFlags(uids, seen: seen, flagged: flagged, answered: answered, deleted: deleted);
    final current = await transport.fetchFlags(maxUid: uids.reduce(math.max));
    await db.applyFlagUpdates(folderId, current.where((u) => uids.contains(u.uid)).toList());
  }

  /// Removes messages from their folder on the server the way "archive"
  /// means for this provider: Gmail keeps everything in All Mail, so
  /// expunging from the folder archives it; other servers move to the
  /// Archive folder, created if missing.
  Future<void> archiveOnServer(int folderId, List<int> uids) async {
    if (uids.isEmpty) return;
    final folder = await db.folderById(folderId);
    if (folder == null) return;
    await _ensureConnected();
    if (account.providerId == 'gmail') {
      await transport.selectFolder(folder.path);
      await transport.deleteMessages(uids);
      return;
    }
    var archive = (await db.foldersForAccount(account.id)).where((f) => f.role == FolderRole.archive.name).firstOrNull;
    if (archive == null) {
      final path = await transport.createFolder('Archive');
      await db.upsertFolders(account.id, await transport.listFolders());
      archive = (await db.foldersForAccount(account.id)).where((f) => f.path == path).firstOrNull;
      if (archive == null) throw const MailTransportException('Could not create an Archive folder.');
    }
    if (archive.id == folderId) return;
    await transport.selectFolder(folder.path);
    await transport.moveMessages(uids, archive.path);
  }

  /// After an SMTP send: appends the copy to Sent when the server does not
  /// keep one itself, then re-syncs Sent so the message appears in the
  /// recipients' rows. Returns false when no Sent folder is known.
  Future<bool> storeSentCopy(String rawMessage, {required bool appendCopy}) async {
    await _ensureConnected();
    var sent = (await db.foldersForAccount(account.id)).where((f) => f.role == FolderRole.sent.name).firstOrNull;
    if (sent == null && appendCopy) {
      final path = await transport.createFolder('Sent');
      await db.upsertFolders(account.id, await transport.listFolders());
      sent = (await db.foldersForAccount(account.id)).where((f) => f.path == path || f.role == FolderRole.sent.name).firstOrNull;
    }
    if (sent == null) return false;
    if (appendCopy) await transport.appendMessage(sent.path, rawMessage, seen: true);
    await syncFolder(sent.id);
    return true;
  }

  /// Moves messages to the Trash folder on the server.
  Future<void> trashOnServer(int folderId, List<int> uids) async {
    if (uids.isEmpty) return;
    final folder = await db.folderById(folderId);
    if (folder == null) return;
    await _ensureConnected();
    final trash = (await db.foldersForAccount(account.id)).where((f) => f.role == FolderRole.trash.name).firstOrNull;
    await transport.selectFolder(folder.path);
    if (trash == null || trash.id == folderId) {
      await transport.deleteMessages(uids);
    } else {
      await transport.moveMessages(uids, trash.path);
    }
  }

  /// Full sync, then idle on the inbox and re-sync it on every push. Runs
  /// until [stop] is called. Reconnects with exponential backoff.
  Future<void> run() async {
    _stopRequested = false;
    while (!_stopRequested) {
      try {
        await syncOnce();
        if (_status.phase == SyncPhase.error) {
          await _backoff();
          continue;
        }
        final inbox = (await db.foldersForAccount(account.id)).where((f) => f.role == FolderRole.inbox.name).firstOrNull;
        if (inbox == null) {
          await _backoff();
          continue;
        }
        while (!_stopRequested) {
          await transport.selectFolder(inbox.path);
          _emit(_status.copyWith(phase: SyncPhase.waitingForMail, folderPath: inbox.path));
          final event = await transport.idle(timeout: idleTimeout);
          if (_stopRequested) break;
          switch (event) {
            case ConnectionLostEvent():
              throw const MailTransportException('Connection lost');
            case NewMailEvent():
            case ExpungeEvent():
            case FlagsChangedEvent():
              _emit(_status.copyWith(phase: SyncPhase.syncingFolder, folderPath: inbox.path));
              await syncFolder(inbox.id);
            case null:
              // Idle timeout: refresh the inbox and re-arm.
              await syncFolder(inbox.id);
          }
        }
      } on MailTransportException catch (e) {
        if (e.isAuthFailure) {
          _emit(_status.copyWith(phase: SyncPhase.error, error: e.message));
          return; // needs the user; do not hammer the server
        }
        _consecutiveFailures++;
        _emit(_status.copyWith(phase: SyncPhase.error, error: e.message));
        await transport.disconnect();
        await _backoff();
      } catch (e) {
        _consecutiveFailures++;
        _emit(_status.copyWith(phase: SyncPhase.error, error: e.toString()));
        await transport.disconnect();
        await _backoff();
      }
    }
    _emit(_status.copyWith(phase: SyncPhase.stopped));
  }

  Future<void> _backoff() async {
    final seconds = math.min(300, 2 << math.min(_consecutiveFailures, 7));
    _emit(_status.copyWith(phase: SyncPhase.backoff, message: 'retrying in ${seconds}s'));
    await sleep(Duration(seconds: seconds));
  }

  Future<void> stop() async {
    _stopRequested = true;
    await transport.disconnect();
  }
}
