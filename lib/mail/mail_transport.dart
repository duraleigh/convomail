import 'dart:typed_data';

import 'models.dart';

/// Exception raised by a [MailTransport] with a user-presentable message.
class MailTransportException implements Exception {
  const MailTransportException(this.message, {this.isAuthFailure = false, this.cause});
  final String message;
  final bool isAuthFailure;
  final Object? cause;

  @override
  String toString() => 'MailTransportException: $message';
}

/// The subset of IMAP the sync engine needs, expressed transport-neutrally
/// so the engine is unit-testable with `FakeMailTransport`.
abstract interface class MailTransport {
  bool get isConnected;

  Future<void> connect(ServerConfig server, MailCredentials credentials);
  Future<void> disconnect();

  Future<List<RemoteFolder>> listFolders();

  /// Selects a folder and returns its server-side state.
  Future<FolderStatus> selectFolder(String path);

  /// Headers for UIDs in [fromUid]..[toUid] inclusive (toUid null = to end)
  /// of the selected folder. Returns them in ascending UID order.
  Future<List<RemoteMessageHeader>> fetchHeaders({required int fromUid, int? toUid});

  /// Current flags for all messages with UID <= [maxUid] in the selected
  /// folder. Used for reconciliation; servers with CONDSTORE may narrow it
  /// with [changedSinceModSeq].
  Future<List<RemoteFlagUpdate>> fetchFlags({required int maxUid, int? changedSinceModSeq});

  /// UIDs currently present in the selected folder up to [maxUid]. Used to
  /// detect messages deleted elsewhere.
  Future<Set<int>> fetchExistingUids({required int maxUid});

  Future<RemoteMessageBody> fetchBody(int uid);

  /// Bulk-mail header signals for already-known messages (backfill after
  /// the schema upgrade that introduced them). Missing uids are omitted.
  Future<Map<int, BulkSignals>> fetchSignals(List<int> uids);

  /// Server capability names from the login greeting (upper case), e.g.
  /// `X-GM-EXT-1` on Gmail. Empty until connected.
  List<String> get capabilities;

  /// Raw `UID SEARCH` in the selected folder; returns matching UIDs. Used
  /// for provider-side classification (Gmail `X-GM-RAW "category:..."`).
  Future<Set<int>> searchUids(String criteria);

  /// Diagnostic: header names present on each message, with the encoded
  /// bulk signals the transport derives from them.
  Future<List<String>> probeHeaders(List<int> uids, {String? criteria});

  /// Decoded bytes of the given MIME parts (attachment `partId`s from
  /// [fetchBody]) of a message in the selected folder. Parts that do not
  /// exist are left out of the result.
  Future<Map<String, Uint8List>> fetchParts(int uid, List<String> partIds);

  Future<void> setFlags(List<int> uids, {bool? seen, bool? flagged, bool? answered, bool? deleted});

  /// Moves messages from the selected folder to [targetPath]. Uses MOVE when
  /// the server supports it, otherwise COPY + \Deleted + EXPUNGE.
  Future<void> moveMessages(List<int> uids, String targetPath);

  /// Marks messages \Deleted and expunges them from the selected folder.
  /// On Gmail this is how a message leaves the Inbox without leaving All
  /// Mail, i.e. "archive".
  Future<void> deleteMessages(List<int> uids);

  /// Creates a folder and returns its path.
  Future<String> createFolder(String name);

  /// Appends a raw RFC 822 message to [folderPath] (IMAP APPEND). Used to
  /// store a sent copy on servers that do not save one themselves.
  Future<void> appendMessage(String folderPath, String rawMessage, {bool seen = true});

  /// Waits in IDLE on the selected folder until the server pushes something
  /// or [timeout] elapses (returns null on timeout).
  Future<MailboxEvent?> idle({required Duration timeout});
}
