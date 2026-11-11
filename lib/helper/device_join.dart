import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app/app_log.dart';
import '../app/settings.dart';
import '../mail/google_oauth.dart';
import '../mail/provider_config.dart';
import '../platform/credential_store.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';
import 'helper_client.dart';
import 'helper_pass.dart';
import 'helper_sync.dart';

/// Where the app keeps its own files (attachments, pictures, logs).
/// Replaceable in tests.
final appFilesDirProvider = Provider<Future<Directory> Function()>((ref) => getApplicationSupportDirectory);

/// What stands between a joined device and its mail, in words for the
/// user; null when nothing does.
final joinNoticeProvider = NotifierProvider<JoinNotice, String?>(JoinNotice.new);

class JoinNotice extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? text) => state = text;
}

/// A phone or second PC with no Gmail sign-in of its own.
///
/// It joins the helper with a code. The helper says whose mailbox it holds
/// and hands the device a pass to it, and the device then fetches mail the
/// same way the first PC does. Signed out (from any device, or from the
/// helper's page), it loses the pass and wipes its own copy.
class DeviceJoin {
  DeviceJoin(this._ref);
  final Ref _ref;

  /// Set once this device joined by code (and so holds no password).
  static const joinedKey = kDeviceJoined;

  Timer? _retry;

  AppDatabase get _db => _ref.read(databaseProvider);
  CredentialStore get _vault => _ref.read(credentialStoreProvider);

  Future<bool> get joined async => await _db.getSetting(joinedKey) == '1';

  /// Call once the app is up: a device that joined but could not set its
  /// mailbox up yet (Google had not been allowed) keeps trying.
  Future<void> start() async {
    if (!await joined) return;
    await setUpMailbox();
    _retry ??= Timer.periodic(const Duration(seconds: 30), (_) => unawaited(setUpMailbox()));
  }

  void stop() {
    _retry?.cancel();
    _retry = null;
  }

  /// Joins the helper at [address] with a [code] from its page, then sets
  /// the mailbox up. Throws [HelperException] when the code or the address
  /// is wrong; anything in the way after that is told by [joinNoticeProvider].
  Future<void> join(String address, String code, {String? name}) async {
    if ((await _db.allAccounts()).isNotEmpty) {
      throw const HelperException('This device already has a mailbox set up. Use Settings, then Helper, to follow the helper.');
    }
    await _ref.read(helperProvider.notifier).connect(address, code, name: name, fresh: true);
    await _db.putSetting(joinedKey, '1');
    await _ref.read(settingsProvider.notifier).setOnboardingDone(true);
    await start();
  }

  /// Makes the mailbox on this device when it is missing.
  Future<void> setUpMailbox() async {
    final notice = _ref.read(joinNoticeProvider.notifier);
    try {
      if (!await joined) return;
      if ((await _db.allAccounts()).isNotEmpty) {
        notice.set(null);
        stop();
        return;
      }
      final client = await _ref.read(helperProvider.notifier).client();
      if (client == null) return;
      final who = await client.account();
      if (!who.mail) {
        notice.set('One more step on the helper’s page: open it in any browser, press “Connect Google again”, and leave every box ticked. Your mail shows up here by itself after that.');
        return;
      }
      if (who.email.isEmpty) return;
      final gmail = ProviderProfiles.forEmail('someone@gmail.com')!;
      await _db.transaction(() async {
        final id = await _db.into(_db.accounts).insert(AccountsCompanion.insert(
              email: who.email,
              displayName: Value(who.name),
              imapHost: gmail.imap.host,
              imapPort: gmail.imap.port,
              imapSecurity: gmail.imap.security.name,
              smtpHost: gmail.smtp.host,
              smtpPort: gmail.smtp.port,
              smtpSecurity: gmail.smtp.security.name,
              username: who.email,
              authMethod: const Value(kHelperAuth),
              providerId: Value(gmail.id),
            ));
        await _db.into(_db.identities).insert(IdentitiesCompanion.insert(accountId: id, email: who.email, name: Value(who.name), isDefault: const Value(true)));
      });
      notice.set(null);
      stop();
    } on HelperException catch (e) {
      if (!e.signedOut) notice.set(e.unreachable ? 'The helper cannot be reached right now. Précis keeps trying.' : e.message);
    } catch (e, st) {
      AppLog.current?.error('setting the mailbox up on a joined device failed', AppLog.scrub(e), st);
    }
  }

  /// The helper says this device was signed out. A device that joined by
  /// code removes its copy; returns whether it did.
  Future<bool> signedOut() async {
    if (!await joined) return false;
    await wipe();
    return true;
  }

  /// Removes everything Précis keeps on this device: mail, the people
  /// list, saved files, the passwords for sending addresses, and the link
  /// to the helper. Leaves a clean app at its welcome screen.
  Future<void> wipe() async {
    stop();
    _ref.read(helperPassProvider).forget();
    try {
      for (final i in await _db.select(_db.identities).get()) {
        await _vault.delete(CredentialStore.identityPasswordKey(i.id));
      }
      for (final a in await _db.allAccounts()) {
        await _vault.delete(CredentialStore.passwordKey(a.id));
      }
      for (final k in const [HelperSync.tokenKey, GoogleOAuth.refreshKey, GoogleOAuth.clientKey, GoogleOAuth.grantedKey]) {
        await _vault.delete(k);
      }
    } catch (e, st) {
      AppLog.current?.error('removing saved passwords failed', AppLog.scrub(e), st);
    }
    await _db.wipeEverything();
    try {
      final base = await _ref.read(appFilesDirProvider)();
      for (final name in const ['attachments', 'signature-images', 'compose-images', 'avatars', 'logs']) {
        final dir = Directory(p.join(base.path, name));
        if (dir.existsSync()) await dir.delete(recursive: true);
      }
    } catch (e, st) {
      AppLog.current?.error('removing saved files failed', AppLog.scrub(e), st);
    }
    _ref.invalidate(settingsProvider);
    _ref.read(joinNoticeProvider.notifier).set(null);
  }
}

final deviceJoinProvider = Provider<DeviceJoin>((ref) {
  final j = DeviceJoin(ref);
  ref.onDispose(j.stop);
  return j;
});
