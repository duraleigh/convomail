/// Provider auto-configuration (spec 4.1, plan open decision 4).
///
/// A bundled snapshot of well-known provider settings, plus host guessing.
/// No network lookup of the user's domain is ever made from here; DNS SRV
/// (RFC 6186) is a possible later addition and would only query the user's
/// own mail domain's DNS.
library;

import 'models.dart';

class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.displayName,
    required this.domains,
    required this.imap,
    required this.smtp,
    this.usesFullAddressAsUsername = true,
    this.appPasswordHelp,
    this.appPasswordUrl,
  });

  final String id;
  final String displayName;
  final List<String> domains;
  final ServerConfig imap;
  final ServerConfig smtp;
  final bool usesFullAddressAsUsername;

  /// Shown on the account setup screen so the user knows how to get a
  /// password that works with IMAP.
  final String? appPasswordHelp;
  final String? appPasswordUrl;
}

abstract final class ProviderProfiles {
  static const List<ProviderProfile> all = [
    ProviderProfile(
      id: 'gmail',
      displayName: 'Gmail',
      domains: ['gmail.com', 'googlemail.com'],
      imap: ServerConfig(host: 'imap.gmail.com', port: 993, security: ConnectionSecurity.ssl),
      smtp: ServerConfig(host: 'smtp.gmail.com', port: 465, security: ConnectionSecurity.ssl),
      appPasswordHelp: 'Gmail needs an app password: turn on 2-Step Verification in your Google Account, then create an app password under Security → 2-Step Verification → App passwords.',
      appPasswordUrl: 'https://myaccount.google.com/apppasswords',
    ),
    ProviderProfile(
      id: 'outlook',
      displayName: 'Outlook.com',
      domains: ['outlook.com', 'hotmail.com', 'live.com', 'msn.com'],
      imap: ServerConfig(host: 'outlook.office365.com', port: 993, security: ConnectionSecurity.ssl),
      smtp: ServerConfig(host: 'smtp-mail.outlook.com', port: 587, security: ConnectionSecurity.starttls),
      appPasswordHelp: 'Microsoft accounts no longer accept passwords over IMAP. Sign-in with Microsoft (OAuth) is planned for a later milestone.',
    ),
    ProviderProfile(
      id: 'icloud',
      displayName: 'iCloud Mail',
      domains: ['icloud.com', 'me.com', 'mac.com'],
      imap: ServerConfig(host: 'imap.mail.me.com', port: 993, security: ConnectionSecurity.ssl),
      smtp: ServerConfig(host: 'smtp.mail.me.com', port: 587, security: ConnectionSecurity.starttls),
      appPasswordHelp: 'iCloud needs an app-specific password from appleid.apple.com → Sign-In and Security → App-Specific Passwords.',
      appPasswordUrl: 'https://appleid.apple.com/account/manage',
    ),
    ProviderProfile(
      id: 'yahoo',
      displayName: 'Yahoo Mail',
      domains: ['yahoo.com', 'ymail.com', 'rocketmail.com'],
      imap: ServerConfig(host: 'imap.mail.yahoo.com', port: 993, security: ConnectionSecurity.ssl),
      smtp: ServerConfig(host: 'smtp.mail.yahoo.com', port: 465, security: ConnectionSecurity.ssl),
      appPasswordHelp: 'Yahoo needs an app password from Account Security → Generate app password.',
      appPasswordUrl: 'https://login.yahoo.com/account/security',
    ),
    ProviderProfile(
      id: 'aol',
      displayName: 'AOL Mail',
      domains: ['aol.com'],
      imap: ServerConfig(host: 'imap.aol.com', port: 993, security: ConnectionSecurity.ssl),
      smtp: ServerConfig(host: 'smtp.aol.com', port: 465, security: ConnectionSecurity.ssl),
      appPasswordHelp: 'AOL needs an app password from Account Security → Generate app password.',
    ),
    ProviderProfile(
      id: 'fastmail',
      displayName: 'Fastmail',
      domains: ['fastmail.com', 'fastmail.fm'],
      imap: ServerConfig(host: 'imap.fastmail.com', port: 993, security: ConnectionSecurity.ssl),
      smtp: ServerConfig(host: 'smtp.fastmail.com', port: 465, security: ConnectionSecurity.ssl),
      appPasswordHelp: 'Fastmail needs an app password from Settings → Privacy & Security → Integrations → New app password.',
    ),
    ProviderProfile(
      id: 'gmx',
      displayName: 'GMX',
      domains: ['gmx.com', 'gmx.net', 'gmx.de'],
      imap: ServerConfig(host: 'imap.gmx.com', port: 993, security: ConnectionSecurity.ssl),
      smtp: ServerConfig(host: 'mail.gmx.com', port: 587, security: ConnectionSecurity.starttls),
    ),
    ProviderProfile(
      id: 'zoho',
      displayName: 'Zoho Mail',
      domains: ['zoho.com', 'zohomail.com'],
      imap: ServerConfig(host: 'imap.zoho.com', port: 993, security: ConnectionSecurity.ssl),
      smtp: ServerConfig(host: 'smtp.zoho.com', port: 465, security: ConnectionSecurity.ssl),
    ),
  ];

  static ProviderProfile? forEmail(String email) {
    final at = email.lastIndexOf('@');
    if (at < 0) return null;
    final domain = email.substring(at + 1).toLowerCase();
    for (final p in all) {
      if (p.domains.contains(domain)) return p;
    }
    return null;
  }

  static ProviderProfile? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Guesses for a domain with no bundled profile, in the order to try.
  static List<ServerConfig> guessImap(String domain) => [
        ServerConfig(host: 'imap.$domain', port: 993, security: ConnectionSecurity.ssl),
        ServerConfig(host: 'mail.$domain', port: 993, security: ConnectionSecurity.ssl),
        ServerConfig(host: 'imap.$domain', port: 143, security: ConnectionSecurity.starttls),
        ServerConfig(host: 'mail.$domain', port: 143, security: ConnectionSecurity.starttls),
      ];

  static List<ServerConfig> guessSmtp(String domain) => [
        ServerConfig(host: 'smtp.$domain', port: 465, security: ConnectionSecurity.ssl),
        ServerConfig(host: 'mail.$domain', port: 465, security: ConnectionSecurity.ssl),
        ServerConfig(host: 'smtp.$domain', port: 587, security: ConnectionSecurity.starttls),
        ServerConfig(host: 'mail.$domain', port: 587, security: ConnectionSecurity.starttls),
      ];
}
