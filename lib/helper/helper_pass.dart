import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mail/google_oauth.dart';
import '../mail/mail_transport.dart';
import '../mail/models.dart';
import '../store/database.dart';
import 'helper_client.dart';
import 'helper_sync.dart';

/// The note that says this device joined by code (and so holds no password
/// and no Google sign-in of its own).
const kDeviceJoined = 'device.joined';

/// The pass a device that joined by code uses to reach the mailbox.
///
/// Such a device holds no password and no lasting sign-in. It asks the
/// helper for a pass, which Google honors for about an hour, and asks again
/// when that one runs low. Sign the device out on the helper and it gets no
/// more: within the hour it can no longer reach the mailbox at all.
class HelperPass implements GoogleViaHelper {
  HelperPass(this._ref);
  final Ref _ref;

  ({bool calendar, bool contacts})? _grants;
  DateTime? _grantsAt;

  @override
  Future<bool> joined() async => await _ref.read(databaseProvider).getSetting(kDeviceJoined) == '1';

  /// What Google allows the helper, asked at most every ten minutes.
  @override
  Future<({bool calendar, bool contacts})> grants() async {
    final at = _grantsAt;
    if (_grants != null && at != null && DateTime.now().difference(at) < const Duration(minutes: 10)) return _grants!;
    final client = await _ref.read(helperProvider.notifier).client();
    if (client == null) return (calendar: false, contacts: false);
    final who = await client.account();
    _grantsAt = DateTime.now();
    return _grants = (calendar: who.calendar, contacts: who.contacts);
  }

  String? _access;
  DateTime? _until;
  Future<String>? _asking;

  /// A pass with at least a few minutes left on it.
  @override
  Future<String> access() {
    final until = _until;
    if (_access != null && until != null && DateTime.now().isBefore(until.subtract(const Duration(minutes: 3)))) return Future.value(_access);
    return _asking ??= _ask().whenComplete(() => _asking = null);
  }

  Future<String> _ask() async {
    final client = await _ref.read(helperProvider.notifier).client();
    if (client == null) throw const HelperException('This device is not joined to a helper.', signedOut: true);
    final pass = await client.googlePass();
    _access = pass.access;
    _until = pass.until;
    return pass.access;
  }

  /// Forgets the pass in hand, so the next use asks the helper for a new one.
  void forget() {
    _access = null;
    _until = null;
    _grants = null;
  }

  /// The pass as mail sign-in details. A helper that cannot be reached is
  /// not a wrong password: the mail engine waits and tries again.
  Future<MailCredentials> credentials(String email) async {
    try {
      return MailCredentials.withPass(username: email, pass: await access());
    } on HelperException catch (e) {
      throw MailTransportException(e.unreachable ? 'The helper could not be reached, so this device has no pass to the mailbox yet.' : e.message, isAuthFailure: e.signedOut, offline: e.unreachable);
    }
  }
}

final helperPassProvider = Provider<HelperPass>((ref) => HelperPass(ref));

/// How an account that was set up by joining signs in.
const kHelperAuth = 'helper';
