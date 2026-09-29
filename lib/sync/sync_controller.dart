import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mail/mail_transport.dart';
import '../mail/models.dart';
import '../mail/transport_factory.dart';
import '../platform/credential_store.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';
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

class SyncController {
  SyncController(this._ref);
  final Ref _ref;
  final Map<int, AccountSyncer> _syncers = {};
  final Map<int, Future<void>> _runs = {};
  StreamSubscription<List<Account>>? _sub;

  AppDatabase get _db => _ref.read(databaseProvider);

  /// Begins watching accounts; call once at app start.
  void start() {
    _sub ??= _db.watchAccounts().listen(_reconcile);
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

  void _startAccount(Account account) {
    final store = _ref.read(credentialStoreProvider);
    final syncer = AccountSyncer(
      db: _db,
      transport: _ref.read(transportFactoryProvider)(),
      account: account,
      credentials: () async {
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
    );
    _syncers[account.id] = syncer;
    _runs[account.id] = syncer.run();
  }

  Future<void> _stopAccount(int id) async {
    final s = _syncers.remove(id);
    if (s == null) return;
    await s.stop();
    _ref.read(syncStatusProvider.notifier).remove(id);
  }

  AccountSyncer? syncerFor(int accountId) => _syncers[accountId];

  /// Stops and restarts one account's syncer, e.g. after an error or a
  /// password change.
  Future<void> restartAccount(int accountId) async {
    await _stopAccount(accountId);
    final account = await _db.accountById(accountId);
    if (account != null && account.enabled) _startAccount(account);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    for (final id in _syncers.keys.toList()) {
      await _stopAccount(id);
    }
  }
}
