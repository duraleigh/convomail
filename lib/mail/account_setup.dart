import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/credential_store.dart';
import '../store/database.dart';
import 'mail_transport.dart';
import 'models.dart';
import 'provider_config.dart';
import 'transport_factory.dart';

/// Proposed settings for an address, before the user confirms them.
class AccountProposal {
  const AccountProposal({
    required this.email,
    required this.username,
    required this.imap,
    required this.smtp,
    required this.providerId,
    this.profile,
    this.alternatives = const [],
  });

  final String email;
  final String username;
  final ServerConfig imap;
  final ServerConfig smtp;
  final String providerId;
  final ProviderProfile? profile;

  /// Other IMAP guesses to try if the first fails.
  final List<ServerConfig> alternatives;

  AccountProposal copyWith({String? username, ServerConfig? imap, ServerConfig? smtp}) => AccountProposal(
        email: email,
        username: username ?? this.username,
        imap: imap ?? this.imap,
        smtp: smtp ?? this.smtp,
        providerId: providerId,
        profile: profile,
        alternatives: alternatives,
      );
}

class ConnectionTestResult {
  const ConnectionTestResult.ok(this.imap) : error = null, isAuthFailure = false;
  const ConnectionTestResult.failed(this.error, {this.isAuthFailure = false}) : imap = null;
  final ServerConfig? imap;
  final String? error;
  final bool isAuthFailure;
  bool get ok => error == null;
}

/// Account setup (spec 4.1): auto-detect, test, save.
class AccountSetupService {
  AccountSetupService({required this.db, required this.credentials, required this.newTransport});

  final AppDatabase db;
  final CredentialStore credentials;
  final MailTransport Function() newTransport;

  /// Bundled-profile lookup with host guessing as the fallback. Never
  /// makes a network request.
  AccountProposal propose(String email) {
    final e = email.trim();
    final profile = ProviderProfiles.forEmail(e);
    if (profile != null) {
      return AccountProposal(email: e, username: profile.usesFullAddressAsUsername ? e : e.split('@').first, imap: profile.imap, smtp: profile.smtp, providerId: profile.id, profile: profile);
    }
    final domain = e.contains('@') ? e.substring(e.lastIndexOf('@') + 1).toLowerCase() : '';
    final imapGuesses = ProviderProfiles.guessImap(domain);
    final smtpGuesses = ProviderProfiles.guessSmtp(domain);
    return AccountProposal(
      email: e,
      username: e,
      imap: imapGuesses.first,
      smtp: smtpGuesses.first,
      providerId: 'custom',
      alternatives: imapGuesses.skip(1).toList(),
    );
  }

  /// Tries the proposal's IMAP server, then each alternative, with the given
  /// password. Returns the config that worked or the last error. An
  /// authentication failure stops the search immediately: the host was
  /// right, the password was not.
  Future<ConnectionTestResult> testImap(AccountProposal p, String password) async {
    final candidates = [p.imap, ...p.alternatives];
    String? lastError;
    for (final server in candidates) {
      final t = newTransport();
      try {
        await t.connect(server, MailCredentials(username: p.username, password: password));
        await t.listFolders();
        return ConnectionTestResult.ok(server);
      } on MailTransportException catch (e) {
        if (e.isAuthFailure) return ConnectionTestResult.failed(e.message, isAuthFailure: true);
        lastError = e.message;
      } finally {
        await t.disconnect();
      }
    }
    return ConnectionTestResult.failed(lastError ?? 'Could not reach a mail server.');
  }

  /// Persists the account and stores the password in the credential store.
  /// Returns the new account id.
  Future<int> save(AccountProposal p, String password, {String displayName = ''}) async {
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(
          email: p.email,
          displayName: Value(displayName),
          imapHost: p.imap.host,
          imapPort: p.imap.port,
          imapSecurity: p.imap.security.name,
          smtpHost: p.smtp.host,
          smtpPort: p.smtp.port,
          smtpSecurity: p.smtp.security.name,
          username: p.username,
          providerId: Value(p.providerId),
        ));
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: id, email: p.email, name: Value(displayName), isDefault: const Value(true)));
    await credentials.write(CredentialStore.passwordKey(id), password);
    return id;
  }

  Future<void> remove(int accountId) async {
    await credentials.delete(CredentialStore.passwordKey(accountId));
    await (db.delete(db.accounts)..where((a) => a.id.equals(accountId))).go();
  }
}

final accountSetupProvider = Provider<AccountSetupService>((ref) => AccountSetupService(
      db: ref.watch(databaseProvider),
      credentials: ref.watch(credentialStoreProvider),
      newTransport: ref.watch(transportFactoryProvider),
    ));
