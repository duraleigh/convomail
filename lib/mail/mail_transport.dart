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

  /// Waits in IDLE on the selected folder until the server pushes something
  /// or [timeout] elapses (returns null on timeout).
  Future<MailboxEvent?> idle({required Duration timeout});
}
