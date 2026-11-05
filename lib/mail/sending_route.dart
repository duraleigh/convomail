import '../store/database.dart';
import 'models.dart';
import 'provider_config.dart';

// Where mail from an address goes out.
//
// An address on the account's own domain sends through the account's
// server. Any other address (a custom-domain alias such as ca@clayaiken.com
// on a Gmail account) must send through its own domain's server: sent
// through the account's server instead, it arrives from a server its domain
// never approved, and a domain with a strict DMARC policy has it bounced.

/// The domain part of [email], lowercased.
String emailDomain(String email) => email.substring(email.lastIndexOf('@') + 1).toLowerCase();

String _domain(String email) => emailDomain(email);

/// True when [identity] sends through its account's server and login.
bool sendsThroughAccount(Identity identity, Account account) => identity.smtpHost == null && _domain(identity.email) == _domain(account.email);

/// True when [identity] cannot send yet: it needs a server of its own and
/// has none.
bool needsSendingSetup(Identity identity, Account account) => identity.smtpHost == null && _domain(identity.email) != _domain(account.email);

/// The identity's own server, when it has one.
ServerConfig? identityServer(Identity identity) =>
    identity.smtpHost == null ? null : ServerConfig(host: identity.smtpHost!, port: identity.smtpPort ?? 465, security: ConnectionSecurityName.parse(identity.smtpSecurity ?? 'ssl'));

/// A starting point when setting up an address: its provider's server when
/// known, otherwise Forward Email, which hosts this user's own domains.
ServerConfig suggestedServerFor(String email) => ProviderProfiles.forEmail(email)?.smtp ?? const ServerConfig(host: 'smtp.forwardemail.net', port: 465, security: ConnectionSecurity.ssl);
