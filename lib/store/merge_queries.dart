import 'package:drift/drift.dart';

import 'database.dart';
import 'group_queries.dart';
import 'people_queries.dart';

/// Everything a merge changed, so Undo can put it back exactly.
class MergeSnapshot {
  const MergeSnapshot({
    required this.keep,
    required this.merged,
    required this.addresses,
    required this.prefs,
    required this.memberships,
    required this.draftRows,
    required this.reminderRows,
  });

  final Contact keep;
  final List<Contact> merged;

  /// Address → contact key before the merge, for the merged contacts.
  final Map<String, String> addresses;

  /// Row preferences of the kept and merged rows before the merge.
  final List<RowPref> prefs;
  final List<GroupMember> memberships;
  final Map<int, String> draftRows;
  final Map<int, String> reminderRows;

  /// Every contact key involved.
  Set<String> get keys => {keep.key, for (final c in merged) c.key};
}

/// Combining contacts into one person (spec 4.2). Only ever done at the
/// user's request; nothing merges automatically.
extension MergeQueries on AppDatabase {
  /// Addresses that file under [contactKey], its own key first.
  Future<List<String>> addressesOf(String contactKey) async {
    final rows = await (select(contactAddresses)..where((a) => a.contactKey.equals(contactKey))).get();
    final list = rows.map((a) => a.address).toList()..sort();
    list
      ..remove(contactKey)
      ..insert(0, contactKey);
    return list;
  }

  /// Files every address of [merged] under [keepKey], which keeps its name.
  /// Returns what is needed to undo it. [merged] must not contain the user.
  Future<MergeSnapshot> mergeContacts(String keepKey, Iterable<String> merged) async {
    final others = merged.where((k) => k != keepKey).toSet();
    final all = {keepKey, ...others};
    final rowKeys = {for (final k in all) 'c:$k'};
    final otherRowKeys = {for (final k in others) 'c:$k'};
    final keep = await (select(contacts)..where((c) => c.key.equals(keepKey))).getSingle();
    final merging = await (select(contacts)..where((c) => c.key.isIn(others))).get();

    final snapshot = MergeSnapshot(
      keep: keep,
      merged: merging,
      addresses: {for (final a in await (select(contactAddresses)..where((a) => a.contactKey.isIn(others))).get()) a.address: a.contactKey},
      prefs: await (select(rowPrefs)..where((p) => p.rowKey.isIn(rowKeys))).get(),
      memberships: await (select(groupMembers)..where((m) => m.contactKey.isIn(others))).get(),
      draftRows: {for (final d in await (select(drafts)..where((d) => d.rowKey.isIn(otherRowKeys))).get()) d.id: d.rowKey!},
      reminderRows: {for (final r in await (select(reminders)..where((r) => r.rowKey.isIn(otherRowKeys))).get()) r.id: r.rowKey!},
    );

    await transaction(() async {
      // Addresses first: deleting a contact cascades to its addresses.
      await (update(contactAddresses)..where((a) => a.contactKey.isIn(others))).write(ContactAddressesCompanion(contactKey: Value(keepKey), source: const Value('user')));
      await (update(contactAddresses)..where((a) => a.address.equals(keepKey))).write(ContactAddressesCompanion(contactKey: Value(keepKey)));

      // Group membership moves over; a group holding both keeps one entry.
      for (final m in snapshot.memberships) {
        await into(groupMembers).insert(GroupMembersCompanion.insert(groupId: m.groupId, contactKey: keepKey), mode: InsertMode.insertOrIgnore);
      }
      await (delete(groupMembers)..where((m) => m.contactKey.isIn(others))).go();

      await _mergeRowPrefs(keepKey, snapshot.prefs);
      await (update(drafts)..where((d) => d.rowKey.isIn(otherRowKeys))).write(DraftsCompanion(rowKey: Value('c:$keepKey')));
      await (update(reminders)..where((r) => r.rowKey.isIn(otherRowKeys))).write(RemindersCompanion(rowKey: Value('c:$keepKey')));
      await (update(classificationEvents)..where((e) => e.contactKey.isIn(others))).write(ClassificationEventsCompanion(contactKey: Value(keepKey)));

      await _mergeContactFields(keep, merging);
    });

    await refileCandidates(all);
    await (delete(contacts)..where((c) => c.key.isIn(others))).go();
    await _removeOrphanRows(otherRowKeys);
    filingGeneration++;
    return snapshot;
  }

  Future<void> _mergeRowPrefs(String keepKey, List<RowPref> prefs) async {
    if (prefs.isEmpty) return;
    final keepRow = 'c:$keepKey';
    final own = prefs.where((p) => p.rowKey == keepRow).firstOrNull;
    final otherPrefs = prefs.where((p) => p.rowKey != keepRow);
    DateTime? latest(DateTime? a, DateTime? b) => a == null ? b : (b == null || a.isAfter(b) ? a : b);
    var pinned = own?.pinned ?? false;
    var muted = own?.muted ?? false;
    var snoozed = own?.snoozedUntil;
    var resurfaced = own?.resurfacedAt;
    for (final p in otherPrefs) {
      pinned = pinned || p.pinned;
      muted = muted || p.muted;
      snoozed ??= p.snoozedUntil;
      resurfaced = latest(resurfaced, p.resurfacedAt);
    }
    await into(rowPrefs).insertOnConflictUpdate(RowPrefsCompanion.insert(
      rowKey: keepRow,
      pinned: Value(pinned),
      muted: Value(muted),
      snoozedUntil: Value(snoozed),
      resurfacedAt: Value(resurfaced),
    ));
    await (delete(rowPrefs)..where((p) => p.rowKey.isIn(otherPrefs.map((o) => o.rowKey)))).go();
  }

  Future<void> _mergeContactFields(Contact keep, List<Contact> merging) async {
    var subtitle = keep.userSubtitle;
    var photo = keep.photoPath;
    var category = keep.feedsCategory;
    var book = keep.inAddressBook;
    var counts = keep.countsTowardUnread;
    var first = keep.firstSeenAt;
    var last = keep.lastSeenAt;
    var classification = keep.classification;
    var source = keep.classificationSource;
    for (final c in merging) {
      subtitle ??= c.userSubtitle;
      photo ??= c.photoPath;
      category ??= c.feedsCategory;
      book = book || c.inAddressBook;
      counts = counts || c.countsTowardUnread;
      if (c.firstSeenAt.isBefore(first)) first = c.firstSeenAt;
      if (c.lastSeenAt.isAfter(last)) last = c.lastSeenAt;
      // A manual move on either contact stands, the kept one's first.
      if (source != 'override' && c.classificationSource == 'override') {
        classification = c.classification;
        source = 'override';
      }
    }
    await (update(contacts)..where((c) => c.key.equals(keep.key))).write(ContactsCompanion(
      userSubtitle: Value(subtitle),
      photoPath: Value(photo),
      feedsCategory: Value(category),
      inAddressBook: Value(book),
      countsTowardUnread: Value(counts),
      firstSeenAt: Value(first),
      lastSeenAt: Value(last),
      classification: Value(classification),
      classificationSource: Value(source),
    ));
  }

  Future<void> _removeOrphanRows(Set<String> rowKeys) async {
    if (rowKeys.isEmpty) return;
    await (delete(rowSummaries)..where((s) => s.rowKey.isIn(rowKeys))).go();
    await refreshDirtyRows();
  }

  /// Puts everything back as it was before [s].
  Future<void> undoMerge(MergeSnapshot s) async {
    await transaction(() async {
      for (final c in [s.keep, ...s.merged]) {
        await into(contacts).insertOnConflictUpdate(c);
      }
      for (final e in s.addresses.entries) {
        await (update(contactAddresses)..where((a) => a.address.equals(e.key))).write(ContactAddressesCompanion(contactKey: Value(e.value), source: const Value('observed')));
      }
      await (delete(groupMembers)..where((m) => m.contactKey.equals(s.keep.key) & m.groupId.isIn(s.memberships.map((x) => x.groupId)))).go();
      for (final m in s.memberships) {
        await into(groupMembers).insert(m, mode: InsertMode.insertOrIgnore);
      }
      await (delete(rowPrefs)..where((p) => p.rowKey.equals('c:${s.keep.key}'))).go();
      for (final p in s.prefs) {
        await into(rowPrefs).insertOnConflictUpdate(p);
      }
      for (final e in s.draftRows.entries) {
        await (update(drafts)..where((d) => d.id.equals(e.key))).write(DraftsCompanion(rowKey: Value(e.value)));
      }
      for (final e in s.reminderRows.entries) {
        await (update(reminders)..where((r) => r.id.equals(e.key))).write(RemindersCompanion(rowKey: Value(e.value)));
      }
    });
    await refileCandidates(s.keys);
    filingGeneration++;
  }

  /// Takes one address back out of a merged person, as a contact of its own
  /// named from its mail. Returns the new contact's key. Messages keep their
  /// addresses, so filing returns to how it would be without the merge.
  Future<String> separateAddress(String address) async {
    final mapping = await (select(contactAddresses)..where((a) => a.address.equals(address))).getSingle();
    final from = mapping.contactKey;
    if (from == address) return address;
    final newest = await (select(messages)
          ..where((m) => m.fromAddress.equals(address) & m.fromName.equals('').not())
          ..orderBy([(m) => OrderingTerm.desc(m.date)])
          ..limit(1))
        .getSingleOrNull();
    await transaction(() async {
      await into(contacts).insert(ContactsCompanion.insert(key: address, displayName: Value(newest?.fromName ?? '')), mode: InsertMode.insertOrIgnore);
      await (update(contactAddresses)..where((a) => a.address.equals(address))).write(ContactAddressesCompanion(contactKey: Value(address), source: const Value('observed')));
    });
    await refileCandidates({from, address});
    filingGeneration++;
    return address;
  }
}
