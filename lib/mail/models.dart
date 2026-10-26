/// Transport-neutral mail models. The sync engine and the UI use these;
/// only `imap_transport.dart` knows about enough_mail types.
library;

import '../domain/classifier.dart';

export '../domain/classifier.dart' show BulkSignals;

enum ConnectionSecurity { ssl, starttls, none }

extension ConnectionSecurityName on ConnectionSecurity {
  String get dbValue => name;
  static ConnectionSecurity parse(String v) => ConnectionSecurity.values.firstWhere((s) => s.name == v, orElse: () => ConnectionSecurity.ssl);
}

class ServerConfig {
  const ServerConfig({required this.host, required this.port, required this.security});
  final String host;
  final int port;
  final ConnectionSecurity security;

  @override
  String toString() => '$host:$port/${security.name}';
}

class MailCredentials {
  const MailCredentials({required this.username, required this.password});
  final String username;
  final String password;

  @override
  String toString() => 'MailCredentials($username, ****)';
}

enum FolderRole { inbox, sent, drafts, trash, junk, archive, other }

class RemoteFolder {
  const RemoteFolder({required this.path, required this.name, required this.role, this.selectable = true});
  final String path;
  final String name;
  final FolderRole role;
  final bool selectable;
}

/// Server-side state of a selected folder.
class FolderStatus {
  const FolderStatus({
    required this.path,
    required this.uidValidity,
    required this.uidNext,
    required this.exists,
    this.highestModSeq,
  });
  final String path;
  final int uidValidity;
  final int uidNext;
  final int exists;
  final int? highestModSeq;
}

class RemoteAddress {
  const RemoteAddress(this.address, [this.name = '']);
  final String address;
  final String name;
}

class MessageFlagsState {
  const MessageFlagsState({
    this.seen = false,
    this.flagged = false,
    this.answered = false,
    this.draft = false,
    this.deleted = false,
  });
  final bool seen;
  final bool flagged;
  final bool answered;
  final bool draft;
  final bool deleted;

  static MessageFlagsState fromImapFlags(Iterable<String> flags) {
    final set = flags.map((f) => f.toLowerCase()).toSet();
    return MessageFlagsState(
      seen: set.contains(r'\seen'),
      flagged: set.contains(r'\flagged'),
      answered: set.contains(r'\answered'),
      draft: set.contains(r'\draft'),
      deleted: set.contains(r'\deleted'),
    );
  }
}

/// Header-level view of a message, enough to file and list it.
class RemoteMessageHeader {
  const RemoteMessageHeader({
    required this.uid,
    required this.from,
    this.messageId,
    this.inReplyTo,
    this.references = const [],
    this.subject = '',
    this.to = const [],
    this.cc = const [],
    this.date,
    this.internalDate,
    this.flags = const MessageFlagsState(),
    this.size = 0,
    this.hasAttachments = false,
    this.snippet = '',
    this.providerThreadId,
    this.signals = BulkSignals.none,
  });

  final int uid;
  final String? messageId;
  final String? inReplyTo;
  final List<String> references;
  final String subject;
  final RemoteAddress from;
  final List<RemoteAddress> to;
  final List<RemoteAddress> cc;
  final DateTime? date;
  final DateTime? internalDate;
  final MessageFlagsState flags;
  final int size;
  final bool hasAttachments;
  final String snippet;
  final String? providerThreadId;

  /// Bulk-mail header evidence (spec 4.11).
  final BulkSignals signals;
}

class RemoteAttachment {
  const RemoteAttachment({
    required this.partId,
    required this.fileName,
    required this.mimeType,
    required this.size,
    this.contentId,
    this.isInline = false,
  });
  final String partId;
  final String fileName;
  final String mimeType;
  final int size;
  final String? contentId;
  final bool isInline;
}

class RemoteMessageBody {
  const RemoteMessageBody({this.text, this.html, this.attachments = const [], this.calendar});
  final String? text;
  final String? html;
  final List<RemoteAttachment> attachments;

  /// Decoded `text/calendar` part (an invitation), when present.
  final String? calendar;
}

/// A flag change observed on the server for an already-known message.
class RemoteFlagUpdate {
  const RemoteFlagUpdate({required this.uid, required this.flags});
  final int uid;
  final MessageFlagsState flags;
}

/// Something the server pushed while idling.
sealed class MailboxEvent {
  const MailboxEvent();
}

class NewMailEvent extends MailboxEvent {
  const NewMailEvent();
}

class ExpungeEvent extends MailboxEvent {
  const ExpungeEvent();
}

class FlagsChangedEvent extends MailboxEvent {
  const FlagsChangedEvent();
}

class ConnectionLostEvent extends MailboxEvent {
  const ConnectionLostEvent();
}
