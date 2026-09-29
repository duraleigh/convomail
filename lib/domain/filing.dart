/// Filing rules: which People-list row(s) a message lives in.
///
/// Spec 4.3 and 4.19; decisions 1, 2, 5, 6. Pure Dart, no I/O.
///
/// - A received message files under its sender only.
/// - A message the user sent files under each recipient.
/// - If the participant set (sender + To + CC, minus the user) exactly
///   equals a user-defined group's members, the message files in that
///   group row only, for received and sent mail alike.
/// - Groups are never inferred; they come only from [GroupDefinition]s the
///   user created.
library;

import 'identity.dart';

/// A row in the People list: a contact or a user-defined group.
sealed class RowRef {
  const RowRef();

  /// Stable string key stored in `message_row_assignments.row_key`.
  String get key;

  static RowRef parse(String key) {
    if (key.startsWith('c:')) return ContactRow(key.substring(2));
    if (key.startsWith('g:')) return GroupRow(int.parse(key.substring(2)));
    throw FormatException('Unknown row key: $key');
  }
}

class ContactRow extends RowRef {
  const ContactRow(this.contactKey);
  final String contactKey;

  @override
  String get key => 'c:$contactKey';

  @override
  bool operator ==(Object other) => other is ContactRow && other.contactKey == contactKey;
  @override
  int get hashCode => contactKey.hashCode;
  @override
  String toString() => key;
}

class GroupRow extends RowRef {
  const GroupRow(this.groupId);
  final int groupId;

  @override
  String get key => 'g:$groupId';

  @override
  bool operator ==(Object other) => other is GroupRow && other.groupId == groupId;
  @override
  int get hashCode => groupId.hashCode;
  @override
  String toString() => key;
}

/// A user-defined group: an id and its member contact keys (already
/// resolved through [IdentityResolver]).
class GroupDefinition {
  GroupDefinition({required this.id, required Iterable<String> memberKeys}) : memberKeys = Set.unmodifiable(memberKeys);
  final int id;
  final Set<String> memberKeys;
}

/// The addresses on a message that matter for filing.
class MessageEnvelope {
  const MessageEnvelope({
    required this.from,
    this.to = const [],
    this.cc = const [],
  });
  final String from;
  final List<String> to;
  final List<String> cc;
}

class FilingResult {
  const FilingResult({required this.rows, required this.isFromMe, required this.participantKeys});

  /// Rows the message appears in. Never empty for a message with a sender.
  final Set<RowRef> rows;
  final bool isFromMe;

  /// Sender + To + CC, minus the user, resolved. Used for group matching and
  /// later for the thread view participant list.
  final Set<String> participantKeys;
}

class FilingRule {
  const FilingRule(this.identity, {this.groups = const []});
  final IdentityResolver identity;
  final List<GroupDefinition> groups;

  FilingResult file(MessageEnvelope m) {
    final sender = identity.resolve(m.from);
    final participants = identity.participantKeys([m.from, ...m.to, ...m.cc]);

    // Exact-match group rule first (4.19): applies to sent and received.
    final group = _matchGroup(participants);
    if (group != null) {
      return FilingResult(rows: {GroupRow(group.id)}, isFromMe: sender.isMe, participantKeys: participants);
    }

    if (sender.isMe) {
      // Sent mail: one row per recipient (decision 5). A message to only
      // yourself files under "me" so it is not lost.
      final recipients = identity.participantKeys([...m.to, ...m.cc]);
      final rows = recipients.isEmpty ? {const ContactRow(IdentityResolver.me)} : {for (final k in recipients) ContactRow(k)};
      return FilingResult(rows: rows, isFromMe: true, participantKeys: participants);
    }

    // Received mail: sender only (decision 1).
    return FilingResult(rows: {ContactRow(sender.contactKey)}, isFromMe: false, participantKeys: participants);
  }

  GroupDefinition? _matchGroup(Set<String> participants) {
    if (participants.length < 2) return null;
    for (final g in groups) {
      if (g.memberKeys.length == participants.length && g.memberKeys.containsAll(participants)) return g;
    }
    return null;
  }
}
