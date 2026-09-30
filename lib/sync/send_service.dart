import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/html_sanitizer.dart';
import '../mail/mail_sender.dart';
import '../mail/mail_transport.dart';
import '../mail/models.dart';
import '../mail/outgoing.dart';
import '../mail/provider_config.dart';
import '../platform/credential_store.dart';
import '../store/compose_queries.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';
import 'sync_controller.dart';

/// What the composer hands to [SendService.send].
class ComposeSubmission {
  const ComposeSubmission({
    required this.accountId,
    required this.identityId,
    required this.to,
    this.cc = const [],
    this.bcc = const [],
    required this.subject,
    required this.bodyHtml,
    this.attachments = const [],
    this.inReplyToMessageId,
    this.kind = 'new',
    this.includeQuote = true,
    this.draftId,
  });

  final int accountId;
  final int? identityId;
  final List<RemoteAddress> to;
  final List<RemoteAddress> cc;
  final List<RemoteAddress> bcc;
  final String subject;

  /// The editor's HTML fragment, without signature or quoted original.
  final String bodyHtml;
  final List<OutgoingAttachment> attachments;

  /// Local id of the message replied to / forwarded, when any.
  final int? inReplyToMessageId;

  /// `new`, `reply`, `replyAll`, `forward`.
  final String kind;
  final bool includeQuote;
  final int? draftId;

  bool get isReply => kind == 'reply' || kind == 'replyAll';
  bool get isForward => kind == 'forward';
}

enum SendPhase { building, sending, storingCopy, done, failed }

class SendProgress {
  const SendProgress(this.phase, {this.error, this.messageId});
  final SendPhase phase;
  final String? error;
  final String? messageId;

  bool get inFlight => phase != SendPhase.done && phase != SendPhase.failed;

  String get label => switch (phase) {
        SendPhase.building => 'Preparing…',
        SendPhase.sending => 'Sending…',
        SendPhase.storingCopy => 'Saving to Sent…',
        SendPhase.done => 'Sent',
        SendPhase.failed => error ?? 'Send failed',
      };
}

/// Progress per compose session. Keyed by a token the composer chooses.
final sendProgressProvider = NotifierProvider<SendProgressNotifier, Map<String, SendProgress>>(SendProgressNotifier.new);

class SendProgressNotifier extends Notifier<Map<String, SendProgress>> {
  @override
  Map<String, SendProgress> build() => const {};
  void put(String token, SendProgress p) => state = {...state, token: p};
  void clear(String token) => state = {...state}..remove(token);
}

final sendServiceProvider = Provider<SendService>((ref) => SendService(ref));

/// Builds, sends, files, and cleans up after an outgoing message.
class SendService {
  SendService(this._ref);
  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);

  /// Sends [s]. Progress is published under [token]. Throws
  /// [MailTransportException] on failure after recording it.
  Future<String> send(ComposeSubmission s, {required String token}) async {
    final progress = _ref.read(sendProgressProvider.notifier);
    progress.put(token, const SendProgress(SendPhase.building));
    try {
      final account = await _db.accountById(s.accountId);
      if (account == null) throw const MailTransportException('That account no longer exists.');
      final identity = s.identityId == null ? null : await _db.identityById(s.identityId!);
      final from = RemoteAddress(identity?.email ?? account.email, identity?.name ?? account.displayName);

      final original = s.inReplyToMessageId == null ? null : await _db.messageById(s.inReplyToMessageId!);
      final built = await MimeFactory.build(await _outgoing(s, from, identity, original));

      progress.put(token, const SendProgress(SendPhase.sending));
      final password = await _ref.read(credentialStoreProvider).read(CredentialStore.passwordKey(account.id));
      if (password == null) throw const MailTransportException('No saved password for this account.', isAuthFailure: true);
      final server = ServerConfig(
        host: identity?.smtpHost ?? account.smtpHost,
        port: identity?.smtpPort ?? account.smtpPort,
        security: ConnectionSecurityName.parse(identity?.smtpSecurity ?? account.smtpSecurity),
      );
      await _ref.read(mailSenderProvider).send(
            server,
            MailCredentials(username: account.username, password: password),
            built.message,
            from: from,
            recipients: [...s.to, ...s.cc, ...s.bcc],
          );

      // Sent copy: servers that do not keep one get an APPEND; then the Sent
      // folder is re-synced so the message shows in the recipient's row.
      progress.put(token, SendProgress(SendPhase.storingCopy, messageId: built.messageId));
      final profile = ProviderProfiles.byId(account.providerId);
      final syncer = _ref.read(syncControllerProvider).syncerFor(account.id);
      if (syncer != null) {
        await syncer.storeSentCopy(built.raw, appendCopy: !(profile?.smtpSavesSentCopy ?? false));
      }

      if (original != null && s.isReply) {
        await (_db.update(_db.messages)..where((m) => m.id.equals(original.id))).write(const MessagesCompanion(isAnswered: Value(true)));
        if (syncer != null) await syncer.setFlags(original.folderId, [original.uid], answered: true);
      }
      if (s.draftId != null) await _db.deleteDraft(s.draftId!);
      progress.put(token, SendProgress(SendPhase.done, messageId: built.messageId));
      return built.messageId;
    } on MailTransportException catch (e) {
      progress.put(token, SendProgress(SendPhase.failed, error: e.message));
      rethrow;
    } catch (e) {
      progress.put(token, SendProgress(SendPhase.failed, error: 'Send failed: $e'));
      throw MailTransportException('Send failed: $e', cause: e);
    }
  }

  Future<OutgoingMessage> _outgoing(ComposeSubmission s, RemoteAddress from, Identity? identity, Message? original) async {
    // The signature is part of the editor document (inserted when the
    // composer opens, editable before send), so nothing is appended here.
    var html = s.bodyHtml.trim();
    String? inReplyTo;
    var references = <String>[];
    if (original != null) {
      final body = await _originalBody(original);
      if (s.isReply) {
        inReplyTo = original.messageId;
        references = [..._splitRefs(original.referencesHeader), if (original.messageId != null) original.messageId!];
        if (s.includeQuote) html = '$html${quoteBlock(original, body)}';
      } else if (s.isForward) {
        html = '$html${forwardBlock(original, body, await _db.participantsOf(original.id))}';
      }
    }
    return OutgoingMessage(
      from: from,
      to: s.to,
      cc: s.cc,
      bcc: s.bcc,
      subject: s.subject,
      html: html,
      attachments: s.attachments,
      inReplyTo: inReplyTo,
      references: references,
    );
  }

  /// The original's HTML (sanitized, remote images allowed so the quoted
  /// mail keeps its pictures), fetching it from the server if needed.
  Future<String> _originalBody(Message original) async {
    var m = original;
    if (m.bodyFetchedAt == null) {
      final syncer = _ref.read(syncControllerProvider).syncerFor(m.accountId);
      if (syncer != null) {
        try {
          await syncer.fetchBody(m.id);
          m = (await _db.messageById(m.id)) ?? m;
        } catch (_) {
          // Quote whatever we have (the snippet at worst).
        }
      }
    }
    if (m.bodyHtml != null && m.bodyHtml!.trim().isNotEmpty) {
      return const HtmlSanitizer().sanitize(m.bodyHtml!, allowRemoteImages: true).bodyInner;
    }
    final text = m.bodyText ?? m.snippet;
    return plainTextToHtml(text);
  }

  static List<String> _splitRefs(String? refs) => refs == null ? const [] : refs.split(RegExp(r'\s+')).where((r) => r.isNotEmpty).toList();

  /// Gmail-style attribution line plus blockquote.
  static String quoteBlock(Message original, String bodyInner) {
    final who = original.fromName.isNotEmpty ? '${_esc(original.fromName)} &lt;${_esc(original.fromAddress)}&gt;' : _esc(original.fromAddress);
    return '<br><div class="convomail-quote"><div style="color:#5f6368;margin:12px 0 4px">On ${_esc(_when(original.date ?? original.internalDate))}, $who wrote:</div>'
        '<blockquote style="margin:0 0 0 0.8ex;border-left:2px solid #ccc;padding-left:1ex">$bodyInner</blockquote></div>';
  }

  static String forwardBlock(Message original, String bodyInner, List<MessageParticipant> parts) {
    final to = parts.where((p) => p.role == 'to').map((p) => p.name.isNotEmpty ? '${_esc(p.name)} &lt;${_esc(p.address)}&gt;' : _esc(p.address)).join(', ');
    final cc = parts.where((p) => p.role == 'cc').map((p) => p.name.isNotEmpty ? '${_esc(p.name)} &lt;${_esc(p.address)}&gt;' : _esc(p.address)).join(', ');
    final from = original.fromName.isNotEmpty ? '${_esc(original.fromName)} &lt;${_esc(original.fromAddress)}&gt;' : _esc(original.fromAddress);
    return '<br><div class="convomail-forward"><div style="color:#5f6368;margin:12px 0 8px">---------- Forwarded message ----------<br>'
        'From: $from<br>Date: ${_esc(_when(original.date ?? original.internalDate))}<br>Subject: ${_esc(original.subject)}'
        '${to.isEmpty ? '' : '<br>To: $to'}${cc.isEmpty ? '' : '<br>Cc: $cc'}</div>$bodyInner</div>';
  }

  static String _when(DateTime? t) {
    if (t == null) return 'an earlier date';
    final l = t.toLocal();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '${days[l.weekday - 1]}, ${months[l.month - 1]} ${l.day}, ${l.year} at $h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _esc(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);

  /// Subject for a reply or forward of [original].
  static String derivedSubject(Message original, {required bool forward}) {
    var s = original.subject.trim();
    final re = RegExp(r'^(re|fwd?|aw|wg)\s*:\s*', caseSensitive: false);
    if (forward) {
      return s.toLowerCase().startsWith('fwd:') || s.toLowerCase().startsWith('fw:') ? s : 'Fwd: $s';
    }
    while (re.hasMatch(s) && !s.toLowerCase().startsWith('re:')) {
      s = s.replaceFirst(re, '');
    }
    return s.toLowerCase().startsWith('re:') ? s : 'Re: $s';
  }
}
