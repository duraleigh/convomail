import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../app/app_log.dart';
import '../mail/mail_transport.dart';
import '../mail/models.dart';
import '../store/classification_queries.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';
import '../store/timely_queries.dart';
import 'classification_service.dart';
import 'planner_service.dart';
import 'timely_service.dart';

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
///
/// Two connections: [transport] runs sync and waits for new mail, and spends
/// most of its life in IDLE, when it cannot serve anything else. On-demand
/// work (opening a message, attachments, flags, archive, delete) uses its own
/// connection, one operation at a time, so the user never waits on the sync.
class AccountSyncer {
  AccountSyncer({
    required this.db,
    required this.transport,
    MailTransport? onDemandTransport,
    required this.account,
    required this.credentials,
    this.pageSize = 500,
    this.idleTimeout = const Duration(minutes: 20),
    this.syncFolderRoles = const {FolderRole.inbox, FolderRole.sent, FolderRole.archive, FolderRole.other},
    this.sleep = _defaultSleep,
    this.onStatus,
    ClassificationService? classification,
    PlannerService? planner,
    this.onNewMessages,
    TimelyService? timely,
  })  : _onDemand = onDemandTransport ?? transport,
        classification = classification ?? ClassificationService(db),
        planner = planner ?? PlannerService(db),
        _status = SyncStatus(accountId: account.id, phase: SyncPhase.idle) {
    this.timely = timely ?? TimelyService(db, this.classification);
  }

  final ClassificationService classification;
  late final TimelyService timely;
  final PlannerService planner;

  /// New messages that arrived after the first sync of a folder (local
  /// ids), for notifications. Not called for the initial download.
  final void Function(List<int> messageIds)? onNewMessages;

  final AppDatabase db;
  final MailTransport transport;
  final MailTransport _onDemand;
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

  /// [run] is active, so [transport] belongs to it.
  bool _loopRunning = false;

  /// Folders other code asked the [run] loop to sync.
  final Map<int, Completer<void>> _folderRequests = {};

  Future<void> _onDemandTail = Future<void>.value();
  DateTime? _onDemandLastUsed;

  /// How long one on-demand operation may take. Message downloads get longer.
  static const onDemandTimeout = Duration(seconds: 30);
  static const onDemandDownloadTimeout = Duration(minutes: 2);

  /// An on-demand connection unused for this long is replaced: servers drop
  /// quiet connections, and a dead socket would only show as a slow timeout.
  static const onDemandMaxQuiet = Duration(minutes: 10);

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

  /// Runs [work] on the on-demand connection, after anything already queued,
  /// so a folder select and the command after it stay together. Connects when
  /// needed and retries once on a fresh connection, except for a rejected
  /// password.
  Future<T> _exclusive<T>(Future<T> Function(MailTransport t) work, {Duration timeout = onDemandTimeout}) {
    final run = _onDemandTail.then((_) => _runOnDemand(work, timeout));
    _onDemandTail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<T> _runOnDemand<T>(Future<T> Function(MailTransport t) work, Duration timeout) async {
    final t = _onDemand;
    final shared = identical(t, transport);
    final last = _onDemandLastUsed;
    if (!shared && last != null && t.isConnected && DateTime.now().difference(last) > onDemandMaxQuiet) await _dropOnDemand();
    for (var attempt = 0;; attempt++) {
      final isRetry = attempt > 0;
      try {
        if (!t.isConnected) {
          if (shared) {
            await _ensureConnected();
          } else {
            await t.connect(_server, await credentials()).timeout(onDemandTimeout);
          }
        }
        final result = await work(t).timeout(timeout);
        _onDemandLastUsed = DateTime.now();
        return result;
      } on MailTransportException catch (e) {
        if (e.isAuthFailure || isRetry) rethrow;
      } on TimeoutException {
        if (isRetry) throw const MailTransportException('The mail server took too long to answer.');
      }
      if (!shared) await _dropOnDemand();
    }
  }

  Future<void> _dropOnDemand() async {
    try {
      await _onDemand.disconnect().timeout(const Duration(seconds: 5));
    } catch (_) {
      // It is being replaced either way.
    }
  }

  /// Syncs a folder from outside the sync flow. While [run] is active its
  /// connection is not ours to use, so the loop does the work: this wakes it
  /// and waits briefly. The sync still happens if the wait runs out.
  Future<void> _requestFolderSync(int folderId) async {
    if (!_loopRunning) return syncFolder(folderId);
    final done = _folderRequests.putIfAbsent(folderId, Completer<void>.new);
    transport.interruptIdle();
    await done.future.timeout(onDemandTimeout, onTimeout: () {});
  }

  Future<void> _serveFolderRequests() async {
    while (_folderRequests.isNotEmpty) {
      final request = _folderRequests.entries.first;
      _folderRequests.remove(request.key);
      try {
        await syncFolder(request.key);
      } finally {
        request.value.complete();
      }
    }
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
      await _backfillSignals(targets);
      if (!_stopRequested) await _backfillProviderCategories(targets);
      // Anything an interrupted pass left undecided is finished here.
      while (!_stopRequested && await classification.classifyPending() > 0) {}
      if (!_stopRequested) await planner.recentPass(this);
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

  /// Messages synced before list headers were part of the header fetch
  /// have no bulk signals; fetch them in pages and classify their senders.
  Future<void> _backfillSignals(List<Folder> folders) async {
    for (final folder in folders) {
      while (!_stopRequested) {
        final uids = await db.uidsMissingSignals(folder.id, pageSize: pageSize);
        if (uids.isEmpty) break;
        _emit(_status.copyWith(message: 'reading list headers in ${folder.path}'));
        await transport.selectFolder(folder.path);
        final signals = await transport.fetchSignals(uids);
        // Messages the server no longer has get empty signals so the loop ends.
        final filled = {for (final u in uids) u: signals[u] ?? BulkSignals.none};
        final senders = await db.storeSignals(folder.id, filled);
        await classification.classifySenders(senders);
      }
    }
    while (!_stopRequested && await classification.classifyPending() > 0) {}
  }

  /// Gmail's inbox categories (Primary, Updates, Promotions, Social,
  /// Forums), read with `X-GM-RAW` searches when the server offers them.
  static const providerCategoryNames = ['primary', 'updates', 'promotions', 'social', 'forums'];

  bool get _hasProviderCategories => transport.capabilities.contains('X-GM-EXT-1');

  /// Reads the provider category of UIDs `lo..hi` in the selected [folderId]
  /// and stores it. Returns the senders whose messages were updated.
  Future<Set<String>> _readProviderCategories(int folderId, (int, int) range, {bool redecide = false}) async {
    final (lo, hi) = range;
    final found = <String, Set<int>>{};
    for (final c in providerCategoryNames) {
      found[c] = await transport.searchUids('UID $lo:$hi X-GM-RAW "category:$c"');
    }
    return db.storeProviderCategories(folderId, range, found, redecide: redecide);
  }

  /// Messages stored before categories were read get them once, and their
  /// senders are classified again. Those senders are marked undecided in the
  /// same transaction, so a pass cut short is finished later instead of
  /// leaving decisions made without the categories.
  Future<void> _backfillProviderCategories(List<Folder> folders) async {
    if (!_hasProviderCategories) return;
    for (final folder in folders) {
      if (_stopRequested) return;
      if (_roleOf(folder) == FolderRole.sent) continue;
      final range = await db.uidRangeMissingProviderCategory(folder.id);
      if (range == null) continue;
      _emit(_status.copyWith(message: 'reading Gmail categories in ${folder.path}'));
      await transport.selectFolder(folder.path);
      final senders = await _readProviderCategories(folder.id, range, redecide: true);
      await classification.classifySenders(senders, log: false);
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

    final filingAtStart = db.filingGeneration;
    final filing = await db.loadFilingRule();
    final readCategories = _hasProviderCategories && _roleOf(folder) != FolderRole.sent;
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
        final newIds = <int>[];
        fetched += await db.upsertHeaders(account.id, folderId, headers, filing, newIds: newIds);
        if (readCategories && headers.isNotEmpty) await _readProviderCategories(folderId, (pageStart, pageEnd));
        await classification.classifySenders({for (final h in headers) filing.identity.resolve(h.from.address).contactKey});
        // Replies to mail the user sent are People messages even from a Feeds
        // sender; Sent syncs after INBOX, so re-check once the originals land.
        final mine = [for (final h in headers) if (h.messageId != null && filing.identity.resolve(h.from.address).isMe) h.messageId!];
        if (mine.isNotEmpty) await classification.reclassifyRepliesTo(mine);
        if (highWater > 0 && newIds.isNotEmpty && _roleOf(folder) == FolderRole.inbox) onNewMessages?.call(newIds);
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
    // People were merged or separated while this pass was filing mail.
    if (db.filingGeneration != filingAtStart) await db.refileAccount(account.id);
    _emit(_status.copyWith(messagesFetched: _status.messagesFetched, message: '$fetched new in ${folder.path}'));
  }

  /// Fetches and stores a message body on demand.
  Future<RemoteMessageBody> fetchBody(int messageDbId) async {
    final m = await db.messageById(messageDbId);
    if (m == null) throw StateError('No message $messageDbId');
    final folder = await db.folderById(m.folderId);
    if (folder == null) throw StateError('No folder ${m.folderId}');
    final body = await _exclusive((t) async {
      await t.selectFolder(folder.path);
      return t.fetchBody(m.uid);
    }, timeout: onDemandDownloadTimeout);
    await db.storeBody(messageDbId, body);
    await classification.reclassifyMessage(messageDbId);
    await planner.extractFromMessage(messageDbId);
    await timely.processMessage(messageDbId);
    return body;
  }

  /// Decoded bytes for attachment parts of a stored message.
  Future<Map<String, Uint8List>> fetchParts(int messageDbId, List<String> partIds) async {
    final m = await db.messageById(messageDbId);
    if (m == null) throw StateError('No message $messageDbId');
    final folder = await db.folderById(m.folderId);
    if (folder == null) throw StateError('No folder ${m.folderId}');
    return _exclusive((t) async {
      await t.selectFolder(folder.path);
      return t.fetchParts(m.uid, partIds);
    }, timeout: onDemandDownloadTimeout);
  }

  /// Pushes flag changes to the server and mirrors them locally.
  Future<void> setFlags(int folderId, List<int> uids, {bool? seen, bool? flagged, bool? answered, bool? deleted}) async {
    final folder = await db.folderById(folderId);
    if (folder == null) return;
    final current = await _exclusive((t) async {
      await t.selectFolder(folder.path);
      await t.setFlags(uids, seen: seen, flagged: flagged, answered: answered, deleted: deleted);
      return t.fetchFlags(maxUid: uids.reduce(math.max));
    });
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
    await _exclusive((t) async {
      if (account.providerId == 'gmail') {
        await t.selectFolder(folder.path);
        await t.deleteMessages(uids);
        return;
      }
      var archive = (await db.foldersForAccount(account.id)).where((f) => f.role == FolderRole.archive.name).firstOrNull;
      if (archive == null) {
        final path = await t.createFolder('Archive');
        await db.upsertFolders(account.id, await t.listFolders());
        archive = (await db.foldersForAccount(account.id)).where((f) => f.path == path).firstOrNull;
        if (archive == null) throw const MailTransportException('Could not create an Archive folder.');
      }
      if (archive.id == folderId) return;
      await t.selectFolder(folder.path);
      await t.moveMessages(uids, archive.path);
    });
  }

  /// After an SMTP send: appends the copy to Sent when the server does not
  /// keep one itself, then re-syncs Sent so the message appears in the
  /// recipients' rows. Returns false when no Sent folder is known.
  Future<bool> storeSentCopy(String rawMessage, {required bool appendCopy}) async {
    final sent = await _exclusive((t) async {
      var folder = (await db.foldersForAccount(account.id)).where((f) => f.role == FolderRole.sent.name).firstOrNull;
      if (folder == null && appendCopy) {
        final path = await t.createFolder('Sent');
        await db.upsertFolders(account.id, await t.listFolders());
        folder = (await db.foldersForAccount(account.id)).where((f) => f.path == path || f.role == FolderRole.sent.name).firstOrNull;
      }
      if (folder != null && appendCopy) await t.appendMessage(folder.path, rawMessage, seen: true);
      return folder;
    }, timeout: onDemandDownloadTimeout);
    if (sent == null) return false;
    await _requestFolderSync(sent.id);
    return true;
  }

  /// Moves messages to the Trash folder on the server.
  Future<void> trashOnServer(int folderId, List<int> uids) async {
    if (uids.isEmpty) return;
    final folder = await db.folderById(folderId);
    if (folder == null) return;
    final trash = (await db.foldersForAccount(account.id)).where((f) => f.role == FolderRole.trash.name).firstOrNull;
    await _exclusive((t) async {
      await t.selectFolder(folder.path);
      if (trash == null || trash.id == folderId) {
        await t.deleteMessages(uids);
      } else {
        await t.moveMessages(uids, trash.path);
      }
    });
  }

  /// Reads a batch of recent mail for codes, deliveries and travel (spec
  /// 4.21), on the sync connection so it never competes with the user. Bodies
  /// are stored without marking anything read, and this path leaves out the
  /// salutation re-check that opening a message runs. Returns how many
  /// messages it went through.
  Future<int> _timelyPass({int batch = 40}) async {
    final pending = await db.messagesForTimelyCheck(account.id, limit: batch);
    String? selected;
    for (final m in pending) {
      if (_stopRequested) break;
      try {
        if (m.bodyFetchedAt == null) {
          if (!TimelyService.worthReading(m)) {
            await db.markTimelyChecked(m.id, found: false);
            continue;
          }
          final folder = await db.folderById(m.folderId);
          if (folder == null) continue;
          if (selected != folder.path) {
            await transport.selectFolder(folder.path);
            selected = folder.path;
          }
          await db.storeBody(m.id, await transport.fetchBody(m.uid));
        }
        await timely.processMessage(m.id);
      } on MailTransportException catch (e) {
        if (!transport.isConnected) rethrow;
        // A message gone from the server, for instance. Not worth retrying.
        AppLog.current?.warn('reading a message for timely information failed', AppLog.scrub(e));
        await db.markTimelyChecked(m.id, found: false);
      }
    }
    return pending.length;
  }

  /// Full sync, then idle on the inbox and re-sync it on every push. Runs
  /// until [stop] is called. Reconnects with exponential backoff.
  Future<void> run() async {
    _stopRequested = false;
    _loopRunning = true;
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
          if (_folderRequests.isNotEmpty) {
            await _serveFolderRequests();
            continue;
          }
          // Work through recent mail a batch at a time, checking for new mail
          // between batches so a code just sent never waits for the backlog.
          if (await _timelyPass() > 0) {
            await syncFolder(inbox.id);
            continue;
          }
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
      } catch (e, st) {
        AppLog.current?.error('sync failed', AppLog.scrub(e), st);
        _consecutiveFailures++;
        _emit(_status.copyWith(phase: SyncPhase.error, error: e.toString()));
        await transport.disconnect();
        await _backoff();
      }
    }
    _loopRunning = false;
    for (final request in _folderRequests.values) {
      request.complete();
    }
    _folderRequests.clear();
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
    if (!identical(_onDemand, transport)) await _dropOnDemand();
  }
}
