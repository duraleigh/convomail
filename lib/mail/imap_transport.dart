import 'dart:async';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart' hide ServerConfig;

import 'mail_transport.dart';
import 'models.dart';

/// [MailTransport] over IMAP using enough_mail. The only file that touches
/// enough_mail's IMAP types.
class ImapTransport implements MailTransport {
  ImapTransport({this.logEnabled = false, this.responseTimeout = const Duration(seconds: 60)});

  final bool logEnabled;
  final Duration responseTimeout;

  ImapClient? _client;
  Mailbox? _selected;
  bool _condStore = false;
  List<String> _capabilities = const [];
  Completer<MailboxEvent?>? _pendingIdle;

  static const _signalFields = 'LIST-UNSUBSCRIBE LIST-ID LIST-POST FEEDBACK-ID PRECEDENCE AUTO-SUBMITTED';
  static const _headerFields = 'FROM TO CC BCC REPLY-TO SUBJECT DATE MESSAGE-ID IN-REPLY-TO REFERENCES $_signalFields';
  static const _headerCriteria = '(UID FLAGS INTERNALDATE RFC822.SIZE BODYSTRUCTURE BODY.PEEK[HEADER.FIELDS ($_headerFields)])';

  ImapClient get _c {
    final c = _client;
    if (c == null || !c.isConnected) throw const MailTransportException('Not connected');
    return c;
  }

  @override
  bool get isConnected => _client?.isConnected ?? false;

  @override
  List<String> get capabilities => _capabilities;

  @override
  Future<void> connect(ServerConfig server, MailCredentials credentials) async {
    final client = ImapClient(isLogEnabled: logEnabled, defaultResponseTimeout: responseTimeout);
    try {
      await client.connectToServer(server.host, server.port, isSecure: server.security == ConnectionSecurity.ssl);
      if (server.security == ConnectionSecurity.starttls) {
        await client.startTls();
      }
      // A device that joined by code signs in with the helper's pass (XOAUTH2); the PC that set Précis up, with its password.
      final caps = credentials.pass ? await client.authenticateWithOAuth2(credentials.username, credentials.password) : await client.login(credentials.username, credentials.password);
      _condStore = caps.any((c) => c.name.toUpperCase() == 'CONDSTORE');
      _capabilities = [for (final c in caps) c.name.toUpperCase()];
      _client = client;
    } on ImapException catch (e) {
      final msg = e.message ?? e.toString();
      final upper = msg.toUpperCase();
      final auth = upper.contains('AUTHENTICATIONFAILED') || upper.contains('LOGIN') || upper.contains('INVALID CREDENTIALS') || (credentials.pass && upper.contains('AUTHENTICATE'));
      throw MailTransportException(
        auth ? (credentials.pass ? 'Google did not accept the pass from the helper.' : 'The server rejected the username or password.') : 'IMAP error: $msg',
        isAuthFailure: auth,
        cause: e,
      );
    } on MailTransportException {
      rethrow;
    } catch (e) {
      throw MailTransportException('Could not connect to ${server.host}:${server.port} ($e)', cause: e);
    }
  }

  @override
  Future<void> disconnect() async {
    final c = _client;
    _client = null;
    _selected = null;
    final pending = _pendingIdle;
    if (pending != null && !pending.isCompleted) pending.complete(const ConnectionLostEvent());
    if (c == null) return;
    try {
      // A connection that died (the computer slept, the phone changed
      // networks) never answers: saying goodbye must not wait on it.
      if (c.isLoggedIn) await c.logout().timeout(const Duration(seconds: 3));
    } catch (_) {
      // ignore: best effort
    } finally {
      try {
        await c.disconnect();
      } catch (_) {}
    }
  }

  @override
  Future<List<RemoteFolder>> listFolders() async {
    final boxes = await _c.listMailboxes(recursive: true);
    return [
      for (final b in boxes)
        RemoteFolder(
          path: b.encodedPath,
          name: b.name,
          role: _roleFor(b),
          selectable: !b.isNotSelectable && !_isVirtual(b),
        ),
    ];
  }

  static FolderRole _roleFor(Mailbox b) {
    if (b.isInbox) return FolderRole.inbox;
    if (b.isSent) return FolderRole.sent;
    if (b.isDrafts) return FolderRole.drafts;
    if (b.isTrash) return FolderRole.trash;
    if (b.isJunk) return FolderRole.junk;
    if (b.isArchive) return FolderRole.archive;
    final n = b.name.toLowerCase();
    if (n == 'inbox') return FolderRole.inbox;
    if (n == 'sent' || n == 'sent items' || n == 'sent mail' || n == 'sent messages') return FolderRole.sent;
    if (n == 'drafts') return FolderRole.drafts;
    if (n == 'trash' || n == 'deleted items' || n == 'deleted messages' || n == 'bin') return FolderRole.trash;
    if (n == 'junk' || n == 'spam' || n == 'junk e-mail') return FolderRole.junk;
    if (n == 'archive' || n == 'archives') return FolderRole.archive;
    return FolderRole.other;
  }

  /// Gmail exposes label views ([Gmail]/All Mail, Important, Starred) that
  /// duplicate every message. They are not synced as folders.
  static bool _isVirtual(Mailbox b) {
    if (b.hasFlag(MailboxFlag.all) || b.hasFlag(MailboxFlag.flagged) || b.hasFlag(MailboxFlag.virtual)) return true;
    final n = b.name.toLowerCase();
    return n == 'all mail' || n == 'important' || n == 'starred';
  }

  @override
  Future<FolderStatus> selectFolder(String path) async {
    final box = await _c.selectMailboxByPath(path, enableCondStore: _condStore);
    _selected = box;
    return FolderStatus(
      path: path,
      uidValidity: box.uidValidity ?? 0,
      uidNext: box.uidNext ?? (box.messagesExists + 1),
      exists: box.messagesExists,
      highestModSeq: box.highestModSequence,
    );
  }

  @override
  Future<List<RemoteMessageHeader>> fetchHeaders({required int fromUid, int? toUid}) async {
    _requireSelected();
    if (toUid != null && toUid < fromUid) return const [];
    final seq = toUid == null ? MessageSequence.fromRangeToLast(fromUid, isUidSequence: true) : MessageSequence.fromRange(fromUid, toUid, isUidSequence: true);
    final result = await _c.uidFetchMessages(seq, _headerCriteria);
    final out = <RemoteMessageHeader>[];
    for (final m in result.messages) {
      final uid = m.uid;
      if (uid == null) continue;
      out.add(headerFromMime(uid, m));
    }
    out.sort((a, b) => a.uid.compareTo(b.uid));
    return out;
  }

  /// Header-level view of a parsed MIME message. Public so the test fake
  /// can accept appended messages the same way a server would.
  static RemoteMessageHeader headerFromMime(int uid, MimeMessage m) {
    final from = m.from?.firstOrNull ?? m.sender;
    return RemoteMessageHeader(
      uid: uid,
      messageId: _cleanId(m.getHeaderValue('message-id')),
      inReplyTo: _cleanId(m.getHeaderValue('in-reply-to')),
      references: _splitIds(m.getHeaderValue('references')),
      subject: m.decodeSubject() ?? '',
      from: RemoteAddress(from?.email ?? '', from?.personalName ?? ''),
      to: [for (final a in m.to ?? const <MailAddress>[]) RemoteAddress(a.email, a.personalName ?? '')],
      cc: [for (final a in m.cc ?? const <MailAddress>[]) RemoteAddress(a.email, a.personalName ?? '')],
      date: m.decodeDate(),
      internalDate: _parseInternalDate(m.internalDate),
      flags: MessageFlagsState.fromImapFlags(m.flags ?? const []),
      size: m.size ?? 0,
      hasAttachments: _hasAttachments(m),
      signals: signalsFromMime(m),
    );
  }

  static BulkSignals signalsFromMime(MimeMessage m) => BulkSignals.fromHeaders(
        listUnsubscribe: m.getHeaderValue('list-unsubscribe'),
        listId: m.getHeaderValue('list-id'),
        listPost: m.getHeaderValue('list-post'),
        feedbackId: m.getHeaderValue('feedback-id'),
        precedence: m.getHeaderValue('precedence'),
        autoSubmitted: m.getHeaderValue('auto-submitted'),
      );

  @override
  Future<Map<int, BulkSignals>> fetchSignals(List<int> uids) async {
    _requireSelected();
    if (uids.isEmpty) return const {};
    final seq = MessageSequence.fromIds(uids, isUid: true);
    final result = await _c.uidFetchMessages(seq, '(UID BODY.PEEK[HEADER.FIELDS ($_signalFields)])');
    final out = <int, BulkSignals>{};
    for (final m in result.messages) {
      final uid = m.uid;
      if (uid == null) continue;
      out[uid] = signalsFromMime(m);
    }
    return out;
  }

  @override
  Future<Set<int>> searchUids(String criteria) async {
    _requireSelected();
    final result = await _c.uidSearchMessages(searchCriteria: criteria);
    return {...?result.matchingSequence?.toList()};
  }

  /// Diagnostic only: switches enough_mail's wire log on or off after
  /// login, so credentials never reach the log.
  set debugLog(bool on) => _client?.isLogEnabled = on;

  @override
  Future<List<String>> probeHeaders(List<int> uids, {String? criteria}) async {
    _requireSelected();
    if (uids.isEmpty) return const [];
    final seq = MessageSequence.fromIds(uids, isUid: true);
    final result = await _c.uidFetchMessages(seq, criteria ?? '(UID BODY.PEEK[HEADER.FIELDS ($_signalFields)])');
    final out = <String>[];
    for (final m in result.messages) {
      final names = [for (final h in m.headers ?? const <Header>[]) h.name.toLowerCase()];
      out.add('uid=${m.uid} names=$names signals=${signalsFromMime(m).encode()}');
    }
    return out;
  }

  static bool _hasAttachments(MimeMessage m) {
    try {
      return m.hasAttachments();
    } catch (_) {
      return false;
    }
  }

  static String? _cleanId(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }

  static List<String> _splitIds(String? raw) {
    if (raw == null) return const [];
    return RegExp(r'<[^>]+>').allMatches(raw).map((m) => m.group(0)!).toList();
  }

  static DateTime? _parseInternalDate(String? raw) {
    if (raw == null) return null;
    try {
      return DateCodec.decodeDate(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<RemoteFlagUpdate>> fetchFlags({required int maxUid, int? changedSinceModSeq}) async {
    _requireSelected();
    if (maxUid < 1) return const [];
    final seq = MessageSequence.fromRange(1, maxUid, isUidSequence: true);
    final result = await _c.uidFetchMessages(
      seq,
      '(UID FLAGS)',
      changedSinceModSequence: _condStore ? changedSinceModSeq : null,
    );
    return [
      for (final m in result.messages)
        if (m.uid != null) RemoteFlagUpdate(uid: m.uid!, flags: MessageFlagsState.fromImapFlags(m.flags ?? const [])),
    ];
  }

  @override
  Future<Set<int>> fetchExistingUids({required int maxUid}) async {
    _requireSelected();
    if (maxUid < 1) return const {};
    final result = await _c.uidSearchMessages(searchCriteria: 'UID 1:$maxUid');
    return result.matchingSequence?.toList().toSet() ?? const {};
  }

  @override
  Future<void> ping() async {
    await _c.noop();
  }

  @override
  Future<RemoteMessageBody> fetchBody(int uid) async {
    _requireSelected();
    final result = await _c.uidFetchMessage(uid, 'BODY.PEEK[]');
    final m = result.messages.firstOrNull;
    if (m == null) throw MailTransportException('Message $uid not found on server');
    return bodyFromMime(m);
  }

  /// Fetches the whole message once and decodes the requested parts. A
  /// per-part BODY[n] fetch would be lighter, but decoding then depends on
  /// headers that are not in that response; one full fetch is reliable.
  @override
  Future<Map<String, Uint8List>> fetchParts(int uid, List<String> partIds) async {
    _requireSelected();
    if (partIds.isEmpty) return const {};
    final result = await _c.uidFetchMessage(uid, 'BODY.PEEK[]');
    final m = result.messages.firstOrNull;
    if (m == null) throw MailTransportException('Message $uid not found on server');
    return partsFromMime(m, partIds);
  }

  @override
  Future<Map<int, List<RemoteAttachment>>> fetchAttachmentLists(List<int> uids) async {
    _requireSelected();
    if (uids.isEmpty) return const {};
    final result = await _c.uidFetchMessages(MessageSequence.fromIds(uids, isUid: true), '(UID BODYSTRUCTURE)');
    return {
      for (final m in result.messages)
        if (m.uid != null) m.uid!: attachmentsFromMime(m),
    };
  }

  static Map<String, Uint8List> partsFromMime(MimeMessage m, List<String> partIds) {
    final out = <String, Uint8List>{};
    for (final id in partIds) {
      try {
        // An email that is nothing but one file has no parts under it: the
        // file is the email itself, and the server calls it part 1.
        final part = m.getPart(id) ?? (id == '1' && (m.parts?.isEmpty ?? true) ? m : null);
        final bytes = part?.decodeContentBinary();
        if (bytes != null) out[id] = bytes;
      } catch (_) {
        // Unknown or undecodable part: skip it.
      }
    }
    return out;
  }

  /// Body and attachment list of a parsed MIME message.
  static RemoteMessageBody bodyFromMime(MimeMessage m) {
    String? calendar;
    try {
      calendar = m.getPartWithMediaSubtype(MediaSubtype.textCalendar)?.decodeContentText();
    } catch (_) {}
    // Some mail programs (Apple Mail, when it forwards files) write an
    // email as several pieces of text with the files in between. Every
    // piece is the email's words, in order, not only the first.
    final plain = <String>[];
    final html = <String>[];
    _collectWords(m, plain, html);
    final words = html.isEmpty ? m.decodeTextHtmlPart() : joinHtmlPieces(html);
    return RemoteMessageBody(
      text: plain.isEmpty ? m.decodeTextPlainPart() : plain.join('\n\n'),
      html: words,
      attachments: attachmentsFromMime(m, html: words),
      calendar: calendar,
    );
  }

  /// Gathers the words of an email, in order: every text part that is not
  /// itself a file. An email attached to this one is a file, so its words
  /// are not gathered.
  static void _collectWords(MimePart part, List<String> plain, List<String> html) {
    try {
      final type = part.mediaType;
      if (type.top == MediaToptype.multipart) {
        for (final child in part.parts ?? const <MimePart>[]) {
          _collectWords(child, plain, html);
        }
        return;
      }
      if (type.sub != MediaSubtype.textPlain && type.sub != MediaSubtype.textHtml) return;
      final how = part.getHeaderContentDisposition();
      if (how?.disposition == ContentDisposition.attachment || (part.decodeFileName() ?? '').isNotEmpty) return;
      final words = part.decodeContentText();
      if (words == null || words.trim().isEmpty) return;
      (type.sub == MediaSubtype.textHtml ? html : plain).add(words);
    } catch (_) {
      // A part that cannot be read is left out; the rest of the email stands.
    }
  }

  static final _bodyOpen = RegExp(r'<body[^>]*>', caseSensitive: false);
  static final _bodyClose = RegExp(r'</body\s*>', caseSensitive: false);

  /// Several pieces of HTML as one document: the later pieces go inside the
  /// first one's body, each in a block of its own.
  static String joinHtmlPieces(List<String> pieces) {
    if (pieces.length == 1) return pieces.single;
    String inner(String piece) {
      final open = _bodyOpen.firstMatch(piece);
      final close = _bodyClose.allMatches(piece).lastOrNull;
      if (open == null) return piece;
      return piece.substring(open.end, close != null && close.start >= open.end ? close.start : piece.length);
    }

    final first = pieces.first;
    final rest = [for (final p in pieces.skip(1)) '<div>${inner(p)}</div>'].join();
    final close = _bodyClose.allMatches(first).lastOrNull;
    return close == null ? first + rest : first.substring(0, close.start) + rest + first.substring(close.start);
  }

  /// The files an email carries, from the email itself or from the server's
  /// description of it (which names every part without sending any).
  ///
  /// A file is a file however it was sent. Mail programs mark a file either
  /// "attachment" or "inline", or do not mark it at all; a PDF marked
  /// "inline" is still a file to open. Only a picture that the email's own
  /// words show in place (it has a content id, and the words refer to it) is
  /// kept out of the list of files. With [html] the words are known and are
  /// checked; without them, a picture with a content id is taken to be one.
  static List<RemoteAttachment> attachmentsFromMime(MimeMessage m, {String? html}) {
    final attachments = <RemoteAttachment>[];
    for (final info in m.findContentInfo(disposition: ContentDisposition.attachment)) {
      attachments.add(RemoteAttachment(
        partId: info.fetchId,
        fileName: info.fileName ?? 'attachment',
        mimeType: info.mediaType?.text ?? 'application/octet-stream',
        size: info.size ?? 0,
        contentId: info.cid,
        isInline: false,
      ));
    }
    // Everything not marked "attachment": marked "inline", or not marked.
    final rest = <ContentInfo>[];
    final body = m.body;
    if (body != null) {
      body.collectContentInfo(ContentDisposition.attachment, rest, reverse: true);
    } else {
      m.collectContentInfo(ContentDisposition.attachment, rest, null, reverse: true);
    }
    for (final info in rest) {
      final type = info.mediaType;
      if (type == null || type.top == MediaToptype.multipart) continue;
      final name = info.fileName ?? '';
      final markedInline = info.contentDisposition?.disposition == ContentDisposition.inline;
      // The email's own words, and its calendar invitation, are not files.
      if (name.isEmpty && (type.isText || type.top == MediaToptype.message)) continue;
      // A part with no name and no mark that is not a picture: nothing to offer.
      if (name.isEmpty && !markedInline && !info.isImage) continue;
      final cid = (info.cid ?? '').replaceAll(RegExp(r'^<|>$'), '');
      final shownInTheWords = info.isImage && cid.isNotEmpty && (html == null || html.contains('cid:$cid'));
      attachments.add(RemoteAttachment(
        partId: info.fetchId,
        fileName: name.isEmpty ? (shownInTheWords ? 'inline' : 'attachment') : name,
        mimeType: type.text,
        size: info.size ?? 0,
        contentId: info.cid,
        isInline: shownInTheWords,
      ));
    }
    return attachments;
  }

  @override
  Future<void> setFlags(List<int> uids, {bool? seen, bool? flagged, bool? answered, bool? deleted}) async {
    _requireSelected();
    if (uids.isEmpty) return;
    final seq = MessageSequence.fromIds(uids, isUid: true);
    final add = <String>[];
    final remove = <String>[];
    void put(bool? v, String flag) {
      if (v == null) return;
      (v ? add : remove).add(flag);
    }

    put(seen, MessageFlags.seen);
    put(flagged, MessageFlags.flagged);
    put(answered, MessageFlags.answered);
    put(deleted, MessageFlags.deleted);
    if (add.isNotEmpty) await _c.uidStore(seq, add, action: StoreAction.add, silent: true);
    if (remove.isNotEmpty) await _c.uidStore(seq, remove, action: StoreAction.remove, silent: true);
  }

  @override
  Future<void> moveMessages(List<int> uids, String targetPath) async {
    _requireSelected();
    if (uids.isEmpty) return;
    final seq = MessageSequence.fromIds(uids, isUid: true);
    if (_c.serverInfo.supportsMove) {
      await _c.uidMove(seq, targetMailboxPath: targetPath);
    } else {
      await _c.uidCopy(seq, targetMailboxPath: targetPath);
      await _c.uidStore(seq, [MessageFlags.deleted], action: StoreAction.add, silent: true);
      if (_c.serverInfo.supportsUidPlus) {
        await _c.uidExpunge(seq);
      } else {
        await _c.expunge();
      }
    }
  }

  @override
  Future<void> deleteMessages(List<int> uids) async {
    _requireSelected();
    if (uids.isEmpty) return;
    final seq = MessageSequence.fromIds(uids, isUid: true);
    await _c.uidStore(seq, [MessageFlags.deleted], action: StoreAction.add, silent: true);
    if (_c.serverInfo.supportsUidPlus) {
      await _c.uidExpunge(seq);
    } else {
      await _c.expunge();
    }
  }

  @override
  Future<String> createFolder(String name) async {
    final box = await _c.createMailbox(name);
    return box.encodedPath;
  }

  @override
  Future<MailboxEvent?> idle({required Duration timeout}) async {
    _requireSelected();
    final c = _c;
    final completer = Completer<MailboxEvent?>();
    _pendingIdle = completer;
    final sub = c.eventBus.on<ImapEvent>().listen((e) {
      if (completer.isCompleted) return;
      switch (e) {
        case ImapMessagesExistEvent():
          completer.complete(const NewMailEvent());
        case ImapExpungeEvent():
        case ImapVanishedEvent():
          completer.complete(const ExpungeEvent());
        case ImapFetchEvent():
          completer.complete(const FlagsChangedEvent());
        case ImapConnectionLostEvent():
          completer.complete(const ConnectionLostEvent());
        default:
          break;
      }
    });
    try {
      await c.idleStart();
      final result = await completer.future.timeout(timeout, onTimeout: () => null);
      if (c.isConnected) {
        try {
          await c.idleDone();
        } catch (_) {}
      }
      return result;
    } finally {
      _pendingIdle = null;
      await sub.cancel();
    }
  }

  @override
  void interruptIdle() {
    final pending = _pendingIdle;
    if (pending != null && !pending.isCompleted) pending.complete(null);
  }

  /// Appends a raw RFC 822 message to a folder. Used by integration tests to
  /// simulate mail arriving from elsewhere; the app's own sending goes
  /// through SMTP and the server's Sent folder in milestone 4.
  Future<void> appendForTest(String folderPath, String rawMessage) => appendMessage(folderPath, rawMessage, seen: false);

  @override
  Future<void> appendMessage(String folderPath, String rawMessage, {bool seen = true}) async {
    final box = await _c.selectMailboxByPath(folderPath);
    _selected = box;
    await _c.appendMessageText(rawMessage, targetMailbox: box, flags: seen ? [MessageFlags.seen] : null);
  }

  void _requireSelected() {
    if (_selected == null) throw const MailTransportException('No folder selected');
  }
}
