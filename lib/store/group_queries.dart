import 'package:drift/drift.dart';

import '../domain/identity.dart';
import 'database.dart';
import 'people_queries.dart';
import 'sync_queries.dart';

/// A user-defined group with its members resolved to display names and
/// how many conversations currently file into it (spec 4.18, 4.19).
class GroupInfo {
  const GroupInfo({required this.id, required this.name, required this.members, required this.filedCount, required this.createdAt});
  final int id;
  final String name;

  /// (contactKey, displayName)
  final List<(String, String)> members;
  final int filedCount;
  final DateTime createdAt;

  String get rowKey => 'g:$id';
}

class GroupValidationException implements Exception {
  const GroupValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Create / rename / edit / delete groups, re-filing cached mail each time
/// (spec 4.19 "editing a group re-runs the match").
extension GroupQueries on AppDatabase {
  Stream<List<GroupInfo>> watchGroups() {
    final q = customSelect(
      '''
      SELECT g.id, g.name, g.created_at,
             COALESCE((SELECT s.total FROM row_summaries s WHERE s.row_key = 'g:' || g.id), 0) AS filed
      FROM people_groups g
      ORDER BY g.name COLLATE NOCASE
      ''',
      readsFrom: {peopleGroups, rowSummaries, groupMembers, contacts},
    );
    return q.watch().asyncMap((rows) async {
      final members = await select(groupMembers).get();
      final names = {for (final c in await select(contacts).get()) c.key: c.shownName};
      return [
        for (final r in rows)
          GroupInfo(
            id: r.read<int>('id'),
            name: r.read<String>('name'),
            createdAt: r.read<DateTime>('created_at'),
            filedCount: r.read<int>('filed'),
            members: [
              for (final m in members.where((m) => m.groupId == r.read<int>('id')))
                (m.contactKey, (names[m.contactKey] ?? '').isNotEmpty ? names[m.contactKey]! : m.contactKey),
            ]..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase())),
          ),
      ];
    });
  }

  Future<GroupInfo?> groupById(int id) async => (await watchGroups().first).where((g) => g.id == id).firstOrNull;

  /// Validates per spec 4.19: at least two members, none of them the user.
  Future<Set<String>> _normalizeMembers(Iterable<String> keys) async {
    final identity = await loadIdentityResolver();
    final out = <String>{};
    for (final k in keys) {
      final r = identity.resolve(k);
      if (r.isMe || r.contactKey == IdentityResolver.me) throw const GroupValidationException('You are part of every group already; pick other people.');
      out.add(r.contactKey);
    }
    if (out.length < 2) throw const GroupValidationException('A group needs at least two people.');
    return out;
  }

  Future<int> createGroup(String name, Iterable<String> memberKeys) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const GroupValidationException('Give the group a name.');
    final members = await _normalizeMembers(memberKeys);
    final id = await transaction(() async {
      final id = await into(peopleGroups).insert(PeopleGroupsCompanion.insert(name: trimmed));
      for (final k in members) {
        await into(groupMembers).insert(GroupMembersCompanion.insert(groupId: id, contactKey: k));
      }
      return id;
    });
    await refileCandidates(members, groupId: id);
    return id;
  }

  Future<void> renameGroup(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const GroupValidationException('Give the group a name.');
    await (update(peopleGroups)..where((g) => g.id.equals(id))).write(PeopleGroupsCompanion(name: Value(trimmed)));
  }

  Future<void> setGroupMembers(int id, Iterable<String> memberKeys) async {
    final members = await _normalizeMembers(memberKeys);
    final before = (await (select(groupMembers)..where((m) => m.groupId.equals(id))).get()).map((m) => m.contactKey).toSet();
    await transaction(() async {
      await (delete(groupMembers)..where((m) => m.groupId.equals(id))).go();
      for (final k in members) {
        await into(groupMembers).insert(GroupMembersCompanion.insert(groupId: id, contactKey: k));
      }
    });
    await refileCandidates({...before, ...members}, groupId: id);
  }

  /// Deleting returns the group's messages to sender-only filing.
  Future<void> deleteGroup(int id) async {
    final members = (await (select(groupMembers)..where((m) => m.groupId.equals(id))).get()).map((m) => m.contactKey).toSet();
    await transaction(() async {
      await (delete(peopleGroups)..where((g) => g.id.equals(id))).go();
      await (delete(rowPrefs)..where((p) => p.rowKey.equals('g:$id'))).go();
    });
    await refileCandidates(members, groupId: id);
  }

  /// Re-files only the messages a group change can affect: those with any
  /// member among their participants, plus whatever is filed in the group
  /// row now. Far cheaper than [refileAccount] on a large mailbox.
  Future<void> refileCandidates(Set<String> memberKeys, {int? groupId}) async {
    if (memberKeys.isEmpty && groupId == null) return;
    final filing = await loadFilingRule();
    final ids = <int>{};
    if (memberKeys.isNotEmpty) {
      final placeholders = List.filled(memberKeys.length, '?').join(',');
      final rows = await customSelect(
        'SELECT DISTINCT message_id AS id FROM message_participants WHERE contact_key IN ($placeholders) '
        'UNION SELECT id FROM messages WHERE from_contact_key IN ($placeholders)',
        variables: [for (final k in memberKeys) Variable.withString(k), for (final k in memberKeys) Variable.withString(k)],
      ).get();
      ids.addAll(rows.map((r) => r.read<int>('id')));
    }
    if (groupId != null) {
      final rows = await (select(messageRowAssignments)..where((r) => r.rowKey.equals('g:$groupId'))).get();
      ids.addAll(rows.map((r) => r.messageId));
    }
    if (ids.isEmpty) return;
    await transaction(() async {
      final msgs = await (select(messages)..where((m) => m.id.isIn(ids))).get();
      for (final m in msgs) {
        await refileMessage(m, filing);
      }
    });
    await refreshDirtyRows();
  }

  /// Conversations currently filed in the group row, newest first.
  Future<List<PeopleRow>> rowsForGroup(int id) async => (await peopleRows()).where((r) => r.rowKey == 'g:$id').toList();
}
