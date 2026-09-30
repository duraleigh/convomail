import 'dart:convert';

import 'package:drift/drift.dart';

import '../mail/models.dart';
import 'database.dart';

/// A recipient suggestion for the To/CC/BCC fields.
class RecipientSuggestion {
  const RecipientSuggestion({required this.address, required this.name, required this.contactKey, this.lastSeenAt});
  final String address;
  final String name;
  final String contactKey;
  final DateTime? lastSeenAt;

  RemoteAddress toAddress() => RemoteAddress(address, name);
}

/// Drafts, identities, and recipient lookup for the composer (spec 4.4).
extension ComposeQueries on AppDatabase {
  // ---- identities ------------------------------------------------------------

  Future<List<Identity>> identitiesForAccount(int accountId) => (select(identities)
        ..where((i) => i.accountId.equals(accountId))
        ..orderBy([(i) => OrderingTerm.desc(i.isDefault), (i) => OrderingTerm.asc(i.discovered), (i) => OrderingTerm.asc(i.id)]))
      .get();

  Stream<List<Identity>> watchAllIdentities() => (select(identities)
        ..orderBy([(i) => OrderingTerm.asc(i.accountId), (i) => OrderingTerm.desc(i.isDefault), (i) => OrderingTerm.asc(i.id)]))
      .watch();

  Future<Identity?> identityById(int id) => (select(identities)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<void> updateIdentity(int id, {String? name, String? signature}) => (update(identities)..where((i) => i.id.equals(id))).write(IdentitiesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        signature: signature == null ? const Value.absent() : Value(signature),
      ));

  Future<void> setDefaultIdentity(int accountId, int identityId) => transaction(() async {
        await (update(identities)..where((i) => i.accountId.equals(accountId))).write(const IdentitiesCompanion(isDefault: Value(false)));
        await (update(identities)..where((i) => i.id.equals(identityId))).write(const IdentitiesCompanion(isDefault: Value(true)));
      });

  /// Picks the identity to reply from: the one the original message was
  /// addressed to when that is one of ours, otherwise the account default.
  Future<Identity?> identityForReply(int accountId, int? originalMessageId) async {
    final list = await identitiesForAccount(accountId);
    if (list.isEmpty) return null;
    if (originalMessageId != null) {
      final parts = await (select(messageParticipants)..where((p) => p.messageId.equals(originalMessageId) & p.isMe.equals(true))).get();
      for (final p in parts) {
        final match = list.where((i) => i.email.toLowerCase() == p.address.toLowerCase()).firstOrNull;
        if (match != null) return match;
      }
    }
    return list.first;
  }

  // ---- drafts ----------------------------------------------------------------

  Future<int> saveDraft(DraftsCompanion draft) async {
    final now = DateTime.now();
    if (draft.id.present) {
      await (update(drafts)..where((d) => d.id.equals(draft.id.value))).write(draft.copyWith(updatedAt: Value(now)));
      return draft.id.value;
    }
    return into(drafts).insert(draft.copyWith(updatedAt: Value(now)));
  }

  Future<void> deleteDraft(int id) => (delete(drafts)..where((d) => d.id.equals(id))).go();

  Future<Draft?> draftById(int id) => (select(drafts)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// The reply/forward draft last edited for a People-list row, if any.
  Future<Draft?> draftForRow(String rowKey) => (select(drafts)
        ..where((d) => d.rowKey.equals(rowKey) & d.kind.equals('new').not())
        ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])
        ..limit(1))
      .getSingleOrNull();

  /// The most recent unsent new-message draft.
  Future<Draft?> latestNewDraft() => (select(drafts)
        ..where((d) => d.kind.equals('new'))
        ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])
        ..limit(1))
      .getSingleOrNull();

  Stream<Draft?> watchDraftForRow(String rowKey) => (select(drafts)
        ..where((d) => d.rowKey.equals(rowKey) & d.kind.equals('new').not())
        ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])
        ..limit(1))
      .watchSingleOrNull();

  Stream<Draft?> watchLatestNewDraft() => (select(drafts)
        ..where((d) => d.kind.equals('new'))
        ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])
        ..limit(1))
      .watchSingleOrNull();

  Stream<int> watchDraftCount() => customSelect('SELECT COUNT(*) AS n FROM drafts', readsFrom: {drafts}).watchSingle().map((r) => r.read<int>('n'));

  // ---- recipients ------------------------------------------------------------

  /// Contacts whose name or any address contains [query], most recently
  /// active first. Our own addresses are excluded.
  Future<List<RecipientSuggestion>> searchRecipients(String query, {int limit = 8}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final like = '%${q.replaceAll('%', '').replaceAll('_', '')}%';
    final rows = await customSelect(
      '''
      SELECT ca.address AS address, c.display_name AS name, c.key AS contact_key, c.last_seen_at AS last_seen
      FROM contact_addresses ca
      JOIN contacts c ON c.key = ca.contact_key
      WHERE c.is_me = 0 AND (LOWER(ca.address) LIKE ? OR LOWER(c.display_name) LIKE ?)
      ORDER BY (LOWER(ca.address) = ?) DESC, (LOWER(c.display_name) LIKE ?) DESC, c.last_seen_at DESC
      LIMIT ?
      ''',
      variables: [Variable.withString(like), Variable.withString(like), Variable.withString(q), Variable.withString('$q%'), Variable.withInt(limit)],
      readsFrom: {contactAddresses, contacts},
    ).get();
    return [
      for (final r in rows)
        RecipientSuggestion(
          address: r.read<String>('address'),
          name: r.read<String>('name'),
          contactKey: r.read<String>('contact_key'),
          lastSeenAt: r.readNullable<DateTime>('last_seen'),
        ),
    ];
  }

  /// The address to reach a contact: the one they most recently sent from.
  Future<RemoteAddress?> bestAddressForContact(String contactKey) async {
    final m = await (select(messages)
          ..where((m) => m.fromContactKey.equals(contactKey) & m.isFromMe.equals(false))
          ..orderBy([(m) => OrderingTerm.desc(m.date)])
          ..limit(1))
        .getSingleOrNull();
    if (m != null && m.fromAddress.isNotEmpty) return RemoteAddress(m.fromAddress, m.fromName);
    // Fall back to the participant table (contacts we only ever wrote to).
    final p = await (select(messageParticipants)
          ..where((p) => p.contactKey.equals(contactKey))
          ..orderBy([(p) => OrderingTerm.desc(p.id)])
          ..limit(1))
        .getSingleOrNull();
    if (p != null) return RemoteAddress(p.address, p.name);
    final contact = await (select(contacts)..where((c) => c.key.equals(contactKey))).getSingleOrNull();
    final addr = await (select(contactAddresses)..where((a) => a.contactKey.equals(contactKey))..limit(1)).getSingleOrNull();
    if (addr != null) return RemoteAddress(addr.address, contact?.displayName ?? '');
    return null;
  }

  Future<List<MessageParticipant>> participantsOf(int messageId) => (select(messageParticipants)..where((p) => p.messageId.equals(messageId))).get();
}

/// JSON helpers for the address lists stored in drafts.
abstract final class AddressJson {
  static String encode(List<RemoteAddress> list) => jsonEncode([for (final a in list) {'a': a.address, 'n': a.name}]);

  static List<RemoteAddress> decode(String json) {
    try {
      final raw = jsonDecode(json) as List;
      return [for (final e in raw) RemoteAddress((e as Map)['a'] as String, (e['n'] as String?) ?? '')];
    } catch (_) {
      return const [];
    }
  }
}
