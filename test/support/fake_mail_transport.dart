import 'dart:async';
import 'dart:typed_data';

import 'package:convomail/mail/imap_transport.dart';
import 'package:convomail/mail/mail_transport.dart';
import 'package:convomail/mail/models.dart';
import 'package:enough_mail/enough_mail.dart' show MimeMessage;

/// An in-memory IMAP server for engine tests. Folders hold messages by UID;
/// tests mutate it between syncs to simulate another client.
class FakeFolder {
  FakeFolder(this.path, {this.role = FolderRole.other, this.uidValidity = 1});
  final String path;
  FolderRole role;
  int uidValidity;
  int nextUid = 1;
  int modSeq = 1;
  final Map<int, RemoteMessageHeader> messages = {};
  final Map<int, RemoteMessageBody> bodies = {};

  /// Gmail inbox category per UID, answered by `X-GM-RAW "category:..."` searches.
  final Map<int, String> categories = {};

  /// Decoded part bytes by uid then partId, for fetchParts.
  final Map<int, Map<String, Uint8List>> parts = {};

  int add(RemoteMessageHeader h, {RemoteMessageBody? body}) {
    final uid = nextUid++;
    final withUid = RemoteMessageHeader(
      uid: uid,
      from: h.from,
      messageId: h.messageId,
      inReplyTo: h.inReplyTo,
      references: h.references,
      subject: h.subject,
      to: h.to,
      cc: h.cc,
      date: h.date,
      internalDate: h.internalDate,
      flags: h.flags,
      size: h.size,
      hasAttachments: h.hasAttachments,
      signals: h.signals,
    );
    messages[uid] = withUid;
    if (body != null) bodies[uid] = body;
    modSeq++;
    return uid;
  }

  void setFlags(int uid, MessageFlagsState flags) {
    final m = messages[uid]!;
    messages[uid] = RemoteMessageHeader(
      uid: m.uid,
      from: m.from,
      messageId: m.messageId,
      inReplyTo: m.inReplyTo,
      references: m.references,
      subject: m.subject,
      to: m.to,
      cc: m.cc,
      date: m.date,
      internalDate: m.internalDate,
      flags: flags,
      size: m.size,
      hasAttachments: m.hasAttachments,
    );
    modSeq++;
  }

  void remove(int uid) {
    messages.remove(uid);
    modSeq++;
  }
}

class FakeMailTransport implements MailTransport {
  FakeMailTransport({this.password = 'secret'});

  final String password;
  final Map<String, FakeFolder> folders = {};
  final StreamController<MailboxEvent> _events = StreamController.broadcast();

  bool _connected = false;
  String? _selectedPath;
  int connectCount = 0;
  int fetchHeaderCalls = 0;
  bool failNextConnect = false;
  List<String> log = [];

  FakeFolder folder(String path, {FolderRole role = FolderRole.other}) => folders.putIfAbsent(path, () => FakeFolder(path, role: role));

  /// Pushes a server event to a pending idle().
  void push(MailboxEvent e) => _events.add(e);

  FakeFolder get _sel {
    final p = _selectedPath;
    if (p == null) throw const MailTransportException('No folder selected');
    return folders[p]!;
  }

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(ServerConfig server, MailCredentials credentials) async {
    connectCount++;
    log.add('connect ${server.host}');
    if (failNextConnect) {
      failNextConnect = false;
      throw const MailTransportException('simulated network failure');
    }
    if (credentials.password != password) {
      throw const MailTransportException('The server rejected the username or password.', isAuthFailure: true);
    }
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _selectedPath = null;
    // A pending idle() must return, as a closed socket would make it.
    if (_events.hasListener) _events.add(const ConnectionLostEvent());
  }

  @override
  Future<List<RemoteFolder>> listFolders() async {
    _requireConnected();
    return [for (final f in folders.values) RemoteFolder(path: f.path, name: f.path.split('/').last, role: f.role)];
  }

  @override
  Future<FolderStatus> selectFolder(String path) async {
    log.add('select $path');
    _requireConnected();
    final f = folders[path];
    if (f == null) throw MailTransportException('No such folder $path');
    _selectedPath = path;
    return FolderStatus(path: path, uidValidity: f.uidValidity, uidNext: f.nextUid, exists: f.messages.length, highestModSeq: f.modSeq);
  }

  @override
  Future<List<RemoteMessageHeader>> fetchHeaders({required int fromUid, int? toUid}) async {
    _requireConnected();
    fetchHeaderCalls++;
    log.add('fetchHeaders $fromUid-${toUid ?? '*'}');
    final f = _sel;
    return [
      for (final e in f.messages.entries)
        if (e.key >= fromUid && (toUid == null || e.key <= toUid)) e.value,
    ]..sort((a, b) => a.uid.compareTo(b.uid));
  }

  @override
  Future<List<RemoteFlagUpdate>> fetchFlags({required int maxUid, int? changedSinceModSeq}) async {
    _requireConnected();
    return [
      for (final e in _sel.messages.entries)
        if (e.key <= maxUid) RemoteFlagUpdate(uid: e.key, flags: e.value.flags),
    ];
  }

  @override
  Future<Set<int>> fetchExistingUids({required int maxUid}) async {
    _requireConnected();
    return {for (final uid in _sel.messages.keys) if (uid <= maxUid) uid};
  }

  @override
  Future<RemoteMessageBody> fetchBody(int uid) async {
    _requireConnected();
    return _sel.bodies[uid] ?? const RemoteMessageBody(text: '');
  }

  /// Capabilities reported after connect (tests set `X-GM-EXT-1` to act as Gmail).
  @override
  List<String> capabilities = const [];

  /// Canned answers for [searchUids], keyed by the raw criteria.
  final Map<String, Set<int>> searchResults = {};

  @override
  Future<Set<int>> searchUids(String criteria) async {
    _requireConnected();
    log.add('search $criteria');
    final canned = searchResults[criteria];
    if (canned != null) return canned;
    // `UID lo:hi X-GM-RAW "category:name"` against the selected folder.
    final m = RegExp(r'^UID (\d+):(\d+) X-GM-RAW "category:(\w+)"$').firstMatch(criteria);
    if (m == null) return const {};
    final lo = int.parse(m.group(1)!), hi = int.parse(m.group(2)!), cat = m.group(3)!;
    return {for (final e in _sel.categories.entries) if (e.key >= lo && e.key <= hi && e.value == cat) e.key};
  }

  @override
  Future<List<String>> probeHeaders(List<int> uids, {String? criteria}) async => [for (final u in uids) 'uid=$u names=[] signals=${_sel.messages[u]?.signals.encode() ?? ''}'];

  @override
  Future<Map<int, BulkSignals>> fetchSignals(List<int> uids) async {
    _requireConnected();
    log.add('signals ${uids.length}');
    return {for (final u in uids) if (_sel.messages.containsKey(u)) u: _sel.messages[u]!.signals};
  }

  @override
  Future<Map<String, Uint8List>> fetchParts(int uid, List<String> partIds) async {
    _requireConnected();
    log.add('parts $uid ${partIds.join(',')}');
    final have = _sel.parts[uid] ?? const {};
    return {for (final id in partIds) if (have.containsKey(id)) id: have[id]!};
  }

  @override
  Future<void> setFlags(List<int> uids, {bool? seen, bool? flagged, bool? answered, bool? deleted}) async {
    _requireConnected();
    for (final uid in uids) {
      final cur = _sel.messages[uid]?.flags;
      if (cur == null) continue;
      _sel.setFlags(
        uid,
        MessageFlagsState(
          seen: seen ?? cur.seen,
          flagged: flagged ?? cur.flagged,
          answered: answered ?? cur.answered,
          draft: cur.draft,
          deleted: deleted ?? cur.deleted,
        ),
      );
    }
  }

  @override
  Future<void> moveMessages(List<int> uids, String targetPath) async {
    _requireConnected();
    final target = folders[targetPath];
    if (target == null) throw MailTransportException('No such folder $targetPath');
    for (final uid in uids) {
      final m = _sel.messages[uid];
      if (m == null) continue;
      _sel.remove(uid);
      target.add(m, body: _sel.bodies.remove(uid));
    }
    log.add('move ${uids.join(',')} -> $targetPath');
  }

  @override
  Future<void> deleteMessages(List<int> uids) async {
    _requireConnected();
    for (final uid in uids) {
      _sel.remove(uid);
    }
    log.add('delete ${uids.join(',')}');
  }

  @override
  Future<String> createFolder(String name) async {
    _requireConnected();
    folder(name);
    log.add('create $name');
    return name;
  }

  /// Parses the raw message like a server would and files it in [folderPath].
  @override
  Future<void> appendMessage(String folderPath, String rawMessage, {bool seen = true}) async {
    _requireConnected();
    final mime = MimeMessage.parseFromText(rawMessage);
    final f = folder(folderPath);
    final h = ImapTransport.headerFromMime(0, mime);
    final uid = f.add(
      RemoteMessageHeader(
        uid: 0,
        from: h.from,
        messageId: h.messageId,
        inReplyTo: h.inReplyTo,
        references: h.references,
        subject: h.subject,
        to: h.to,
        cc: h.cc,
        date: h.date,
        internalDate: DateTime.now(),
        flags: MessageFlagsState(seen: seen),
        size: rawMessage.length,
        hasAttachments: h.hasAttachments,
      ),
      body: ImapTransport.bodyFromMime(mime),
    );
    appended.add((folderPath, uid, rawMessage));
    log.add('append $folderPath');
  }

  /// Every appendMessage call: folder, assigned uid, raw text.
  final List<(String, int, String)> appended = [];

  @override
  Future<MailboxEvent?> idle({required Duration timeout}) async {
    _requireConnected();
    log.add('idle');
    return _events.stream.first.timeout(timeout, onTimeout: () => const NewMailEvent());
  }

  void _requireConnected() {
    if (!_connected) throw const MailTransportException('Not connected');
  }
}

/// Builds a header quickly in tests.
RemoteMessageHeader hdr({
  required String from,
  String fromName = '',
  List<String> to = const ['me@example.com'],
  List<String> cc = const [],
  String subject = 'Hello',
  String? messageId,
  String? inReplyTo,
  DateTime? date,
  bool seen = false,
  bool flagged = false,
}) =>
    RemoteMessageHeader(
      uid: 0,
      from: RemoteAddress(from, fromName),
      to: [for (final a in to) RemoteAddress(a)],
      cc: [for (final a in cc) RemoteAddress(a)],
      subject: subject,
      messageId: messageId,
      inReplyTo: inReplyTo,
      date: date ?? DateTime(2026, 7, 5, 15, 5),
      flags: MessageFlagsState(seen: seen, flagged: flagged),
    );
