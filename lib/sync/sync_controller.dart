import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helper/helper_pass.dart';
import '../mail/mail_transport.dart';
import '../mail/models.dart';
import '../mail/transport_factory.dart';
import '../platform/credential_store.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';
import '../store/thread_queries.dart';
import 'calendar_sync.dart';
import 'classification_service.dart';
import 'contacts_sync.dart';
import 'notification_center.dart';
import 'sync_engine.dart';

/// Live sync status per account id.
final syncStatusProvider = NotifierProvider<SyncStatusNotifier, Map<int, SyncStatus>>(SyncStatusNotifier.new);

class SyncStatusNotifier extends Notifier<Map<int, SyncStatus>> {
  @override
  Map<int, SyncStatus> build() => const {};
  void put(SyncStatus s) => state = {...state, s.accountId: s};
  void remove(int accountId) => state = {for (final e in state.entries) if (e.key != accountId) e.key: e.value};
}

/// Runs one [AccountSyncer] per enabled account for as long as the app is
/// open. Starts syncers for new accounts and stops them for removed ones.
final syncControllerProvider = Provider<SyncController>((ref) {
  final c = SyncController(ref);
  ref.onDispose(c.dispose);
  return c;
});

/// Bumped when filing rules change; existing mail is filed again once.
const filingVersion = 2;
const filingVersionKey = 'filing.version';

class SyncController {
  SyncController(this._ref);
  final Ref _ref;
  final Map<int, AccountSyncer> _syncers = {};
  final Map<int, Future<void>> _runs = {};
  StreamSubscription<List<Account>>? _sub;
  Timer? _retry;

  AppDatabase get _db => _ref.read(databaseProvider);

  /// Begins watching accounts; call once at app start. Also threads any
  /// messages that predate the threading model (schema v5 migration).
  void start() {
    _sub ??= _db.watchAccounts().listen(_reconcile);
    // A joined device whose pass was refused (Google not allowed yet, or the
    // helper out of reach at the wrong moment) tries again by itself: there
    // is no password for the user to fix.
    _retry ??= Timer.periodic(const Duration(minutes: 2), (_) => unawaited(_retryJoined()));
    // Senders not yet classified (first launch after the Feeds milestone,
    // or an interrupted backfill) are worked through in batches.
    unawaited(() async {
      final service = ClassificationService(_db);
      try {
        await service.upgradeIfNeeded();
        while (await service.classifyPending(limit: 200) > 0) {}
      } catch (_) {
        // Best effort; the sync engine's backfill pass retries.
      }
    }());
    // Sent mail filed by the rule before version 2 went to everyone copied.
    // Everything is filed once more by the current rule.
    unawaited(() async {
      try {
        if (await _db.getSetting(filingVersionKey) == '$filingVersion') return;
        for (final a in await _db.allAccounts()) {
          await _db.refileAccount(a.id);
        }
        await _db.putSetting(filingVersionKey, '$filingVersion');
      } catch (e) {
        // Tried again at the next start.
      }
    }());
    // Events read out of mail that is gone (an earlier fault lost rows).
    unawaited(_db.pruneOrphanEvents().catchError((Object _) => 0));
    // Photos and address-book status, when Google Contacts is connected.
    unawaited(_ref.read(contactsSyncProvider.future).then((s) => s.start()).catchError((Object _) {}));
    // Google Calendar, for the Planner, when connected with calendar access.
    try {
      _ref.read(calendarSyncProvider).start();
    } catch (_) {
      // Not connected: nothing to keep in step.
    }
    unawaited(_db.rebuildMissingThreads(batch: 500).catchError((Object e) {
      // Threading backfill is best effort; new mail is threaded as it syncs.
      return 0;
    }));
  }

  Future<void> _reconcile(List<Account> accounts) async {
    final wanted = {for (final a in accounts) if (a.enabled) a.id: a};
    for (final id in _syncers.keys.toList()) {
      if (!wanted.containsKey(id)) await _stopAccount(id);
    }
    for (final a in wanted.values) {
      if (!_syncers.containsKey(a.id)) _startAccount(a);
    }
  }

  Future<void> _retryJoined() async {
    final statuses = _ref.read(syncStatusProvider);
    for (final id in _syncers.keys.toList()) {
      final account = _syncers[id]!.account;
      if (account.authMethod != kHelperAuth || statuses[id]?.phase != SyncPhase.error) continue;
      _ref.read(helperPassProvider).forget();
      await restartAccount(id);
    }
  }

  void _startAccount(Account account) {
    final store = _ref.read(credentialStoreProvider);
    final syncer = AccountSyncer(
      db: _db,
      transport: _ref.read(transportFactoryProvider)(),
      onDemandTransport: _ref.read(transportFactoryProvider)(),
      account: account,
      credentials: () async {
        // A device that joined by code has no password: the helper hands it a pass.
        if (account.authMethod == kHelperAuth) return _ref.read(helperPassProvider).credentials(account.email);
        // Brief grace period: the credential write and the accounts stream
        // can race by a few milliseconds on a fresh account.
        String? pw;
        for (var attempt = 0; attempt < 5 && pw == null; attempt++) {
          pw = await store.read(CredentialStore.passwordKey(account.id));
          if (pw == null) await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        if (pw == null) throw const MailTransportException('No saved password for this account. Remove it and add it again.', isAuthFailure: true);
        return MailCredentials(username: account.username, password: pw);
      },
      onStatus: (s) => _ref.read(syncStatusProvider.notifier).put(s),
      onNewMessages: (ids) => unawaited(_ref.read(notificationCenterProvider).onNewMessages(ids)),
    );
    _syncers[account.id] = syncer;
    _runs[account.id] = syncer.run();
  }

  Future<void> _stopAccount(int id, {bool updateStatus = true}) async {
    final s = _syncers.remove(id);
    if (s == null) return;
    // Read the notifier before the async gap; during container disposal the
    // ref must not be used at all.
    final status = updateStatus ? _ref.read(syncStatusProvider.notifier) : null;
    await s.stop();
    status?.remove(id);
  }

  AccountSyncer? syncerFor(int accountId) => _syncers[accountId];

  /// Looks for new mail on every account right now. An account that cannot
  /// be reached is passed over: its own state already says so.
  Future<void> checkNow() async {
    await Future.wait<void>([
      for (final s in _syncers.values.toList()) s.checkInbox().catchError((Object _) {}),
    ]);
  }

  /// Registers an externally created syncer without running its loop.
  /// Tests use this to route row actions through a fake server.
  @visibleForTesting
  void adoptForTest(int accountId, AccountSyncer syncer) => _syncers[accountId] = syncer;

  /// Stops and restarts one account's syncer, e.g. after an error or a
  /// password change.
  Future<void> restartAccount(int accountId) async {
    await _stopAccount(accountId);
    final account = await _db.accountById(accountId);
    if (account != null && account.enabled) _startAccount(account);
  }

  Future<void> dispose() async {
    _retry?.cancel();
    await _sub?.cancel();
    for (final id in _syncers.keys.toList()) {
      await _stopAccount(id, updateStatus: false);
    }
  }
}
