import 'dart:io';

import 'package:enough_mail/enough_mail.dart' hide ServerConfig;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mail_transport.dart';
import 'models.dart';

/// Sends a built message over SMTP. One connection per send; the sync
/// engine's IMAP connection is unaffected.
abstract interface class MailSender {
  Future<void> send(
    ServerConfig server,
    MailCredentials credentials,
    MimeMessage message, {
    required RemoteAddress from,
    required List<RemoteAddress> recipients,
  });
}

final mailSenderProvider = Provider<MailSender>((ref) => SmtpSender());

class SmtpSender implements MailSender {
  SmtpSender({this.logEnabled = false, this.timeout = const Duration(seconds: 90)});
  final bool logEnabled;
  final Duration timeout;

  @override
  Future<void> send(ServerConfig server, MailCredentials credentials, MimeMessage message, {required RemoteAddress from, required List<RemoteAddress> recipients}) async {
    if (recipients.isEmpty) throw const MailTransportException('Add at least one recipient.');
    final client = SmtpClient(_ehloHost(), isLogEnabled: logEnabled);
    try {
      await client.connectToServer(server.host, server.port, isSecure: server.security == ConnectionSecurity.ssl, timeout: const Duration(seconds: 20));
      await client.ehlo();
      if (server.security == ConnectionSecurity.starttls) {
        if (!client.serverInfo.supportsStartTls) throw MailTransportException('${server.host} does not offer STARTTLS.');
        await client.startTls();
      }
      if (credentials.password.isNotEmpty) {
        final mech = client.serverInfo.supportsAuth(AuthMechanism.plain)
            ? AuthMechanism.plain
            : client.serverInfo.supportsAuth(AuthMechanism.login)
                ? AuthMechanism.login
                : AuthMechanism.plain;
        await client.authenticate(credentials.username, credentials.password, mech);
      }
      final response = await client
          .sendMessage(
            message,
            from: MailAddress(from.name.isEmpty ? null : from.name, from.address),
            recipients: [for (final r in recipients) MailAddress(null, r.address)],
            use8BitEncoding: client.serverInfo.supports8BitMime,
          )
          .timeout(timeout);
      if (response.isFailedStatus) throw MailTransportException('The server refused the message: ${response.errorMessage}');
    } on SmtpException catch (e) {
      final msg = e.message ?? e.response.errorMessage;
      final code = e.response.code ?? 0;
      final upper = msg.toUpperCase();
      final auth = code == 535 || code == 534 || upper.contains('AUTHENTICATION') || upper.contains('USERNAME AND PASSWORD');
      throw MailTransportException(auth ? 'The mail server rejected the username or password.' : 'Send failed: $msg', isAuthFailure: auth, cause: e);
    } on MailTransportException {
      rethrow;
    } on SocketException catch (e) {
      throw MailTransportException('Could not reach ${server.host}:${server.port} (${e.osError?.message ?? e.message})', cause: e);
    } catch (e) {
      throw MailTransportException('Send failed: $e', cause: e);
    } finally {
      try {
        await client.quit();
      } catch (_) {}
      try {
        await client.disconnect();
      } catch (_) {}
    }
  }

  static String _ehloHost() {
    final h = Platform.localHostname.trim();
    return h.isEmpty ? 'convomail.local' : h.replaceAll(RegExp(r'[^A-Za-z0-9.-]'), '-');
  }
}

/// Records what would have been sent. Tests use it in place of SMTP.
class RecordingMailSender implements MailSender {
  final List<SentRecord> sent = [];

  /// When set, every send throws this.
  MailTransportException? failWith;
  Duration delay = Duration.zero;

  @override
  Future<void> send(ServerConfig server, MailCredentials credentials, MimeMessage message, {required RemoteAddress from, required List<RemoteAddress> recipients}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failWith != null) throw failWith!;
    sent.add(SentRecord(server: server, username: credentials.username, message: message, from: from, recipients: recipients));
  }
}

class SentRecord {
  const SentRecord({required this.server, required this.username, required this.message, required this.from, required this.recipients});
  final ServerConfig server;
  final String username;
  final MimeMessage message;
  final RemoteAddress from;
  final List<RemoteAddress> recipients;

  /// The message as a receiver would see it (rendered, then re-parsed).
  MimeMessage get parsed => MimeMessage.parseFromText(message.renderMessage());
}
