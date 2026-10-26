import 'package:drift/drift.dart';

import 'database.dart';

/// A board card with what the UI shows (spec 4.8): the thread's subject,
/// newest sender, and the row it is filed in.
class CardInfo {
  const CardInfo({required this.card, required this.title, required this.senderName, required this.senderKey, required this.rowKey, required this.lastDate, required this.tags, required this.messageCount});
  final Card card;
  final String title;
  final String senderName;
  final String senderKey;
  final String? rowKey;
  final DateTime? lastDate;
  final List<Tag> tags;
  final int messageCount;
}

class TagNode {
  const TagNode(this.tag, this.children);
  final Tag tag;
  final List<TagNode> children;
  String get name => tag.name;
}

/// Kanban board and tags (spec 4.8). Tags are a separate system from
/// Feeds categories and never touch the Feeds tables.
extension BoardQueries on AppDatabase {
  // ---- columns ---------------------------------------------------------------

  Stream<List<BoardColumn>> watchColumns() => (select(boardColumns)..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.id)])).watch();

  Future<int> addColumn(String name) async {
    final n = (await select(boardColumns).get()).length;
    return into(boardColumns).insert(BoardColumnsCompanion.insert(name: name.trim().isEmpty ? 'Column' : name.trim(), sortOrder: Value(n)));
  }

  Future<void> renameColumn(int id, String name) => (update(boardColumns)..where((c) => c.id.equals(id))).write(BoardColumnsCompanion(name: Value(name.trim())));

  /// Cards in a deleted column move to the first remaining column; the last
  /// column cannot be deleted.
  Future<bool> deleteColumn(int id) async {
    final cols = await (select(boardColumns)..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).get();
    if (cols.length <= 1) return false;
    final target = cols.firstWhere((c) => c.id != id);
    await transaction(() async {
      await (update(cards)..where((c) => c.columnId.equals(id))).write(CardsCompanion(columnId: Value(target.id)));
      await (delete(boardColumns)..where((c) => c.id.equals(id))).go();
    });
    return true;
  }

  Future<void> reorderColumns(List<int> idsInOrder) async {
    await transaction(() async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await (update(boardColumns)..where((c) => c.id.equals(idsInOrder[i]))).write(BoardColumnsCompanion(sortOrder: Value(i)));
      }
    });
  }

  // ---- cards -----------------------------------------------------------------

  Stream<List<CardInfo>> watchCards() {
    final q = customSelect(
      '''
      SELECT k.id AS card_id, k.thread_key, k.column_id, k.sort_order, k.created_at, k.updated_at,
             m.subject AS subject, m.from_name AS from_name, m.from_address AS from_address, m.from_contact_key AS from_key, m.is_from_me AS from_me,
             COALESCE(m.date, m.internal_date) AS last_date,
             (SELECT r.row_key FROM message_row_assignments r WHERE r.message_id = m.id ORDER BY r.row_key LIMIT 1) AS row_key,
             (SELECT COUNT(*) FROM messages mm WHERE mm.thread_key = k.thread_key AND mm.is_deleted = 0) AS n
      FROM cards k
      LEFT JOIN messages m ON m.id = (
        SELECT m2.id FROM messages m2 WHERE m2.thread_key = k.thread_key AND m2.is_deleted = 0
        ORDER BY COALESCE(m2.date, m2.internal_date) DESC, m2.id DESC LIMIT 1)
      ORDER BY k.column_id, k.sort_order, k.id
      ''',
      readsFrom: {cards, messages, messageRowAssignments, cardTags, tags},
    );
    return q.watch().asyncMap((rows) async {
      final allTags = {for (final t in await select(tags).get()) t.id: t};
      final links = await select(cardTags).get();
      return [
        for (final r in rows)
          CardInfo(
            card: Card(
              id: r.read<int>('card_id'),
              threadKey: r.read<String>('thread_key'),
              columnId: r.read<int>('column_id'),
              sortOrder: r.read<int>('sort_order'),
              createdAt: r.read<DateTime>('created_at'),
              updatedAt: r.read<DateTime>('updated_at'),
            ),
            title: (r.readNullable<String>('subject') ?? '').isEmpty ? '(no subject)' : r.read<String>('subject'),
            senderName: r.read<bool>('from_me') ? 'You' : ((r.readNullable<String>('from_name') ?? '').isNotEmpty ? r.read<String>('from_name') : (r.readNullable<String>('from_address') ?? '')),
            senderKey: r.read<bool>('from_me') ? 'me' : (r.readNullable<String>('from_key') ?? ''),
            rowKey: r.readNullable<String>('row_key'),
            lastDate: r.readNullable<DateTime>('last_date'),
            messageCount: r.read<int>('n'),
            tags: [for (final l in links.where((l) => l.cardId == r.read<int>('card_id'))) if (allTags[l.tagId] != null) allTags[l.tagId]!],
          ),
      ];
    });
  }

  Future<Card?> cardForThread(String threadKey) => (select(cards)..where((c) => c.threadKey.equals(threadKey))).getSingleOrNull();

  /// Puts a thread on the board (first column unless given). Idempotent.
  Future<int> addCard(String threadKey, {int? columnId, Iterable<int> tagIds = const []}) async {
    final existing = await cardForThread(threadKey);
    if (existing != null) {
      if (tagIds.isNotEmpty) await addTagsToCard(existing.id, tagIds);
      return existing.id;
    }
    final col = columnId ?? (await (select(boardColumns)..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])..limit(1)).getSingle()).id;
    final n = (await (select(cards)..where((c) => c.columnId.equals(col))).get()).length;
    final id = await into(cards).insert(CardsCompanion.insert(threadKey: threadKey, columnId: col, sortOrder: Value(n)));
    if (tagIds.isNotEmpty) await addTagsToCard(id, tagIds);
    return id;
  }

  /// Moves a card to [columnId] at [index] (end when null), re-numbering
  /// both columns.
  Future<void> moveCard(int cardId, int columnId, {int? index}) async {
    await transaction(() async {
      final card = await (select(cards)..where((c) => c.id.equals(cardId))).getSingle();
      final source = (await (select(cards)..where((c) => c.columnId.equals(card.columnId))..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.id)])).get()).where((c) => c.id != cardId).toList();
      final target = card.columnId == columnId ? source : (await (select(cards)..where((c) => c.columnId.equals(columnId))..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.id)])).get()).where((c) => c.id != cardId).toList();
      final at = (index ?? target.length).clamp(0, target.length);
      target.insert(at, card);
      for (var i = 0; i < source.length; i++) {
        if (card.columnId != columnId) await (update(cards)..where((c) => c.id.equals(source[i].id))).write(CardsCompanion(sortOrder: Value(i)));
      }
      for (var i = 0; i < target.length; i++) {
        await (update(cards)..where((c) => c.id.equals(target[i].id))).write(CardsCompanion(sortOrder: Value(i), columnId: Value(columnId), updatedAt: Value(DateTime.now())));
      }
    });
  }

  Future<void> removeCard(int cardId) => (delete(cards)..where((c) => c.id.equals(cardId))).go();

  Future<void> addTagsToCard(int cardId, Iterable<int> tagIds) async {
    for (final t in tagIds) {
      await into(cardTags).insert(CardTagsCompanion.insert(cardId: cardId, tagId: t), mode: InsertMode.insertOrIgnore);
    }
  }

  Future<void> setCardTags(int cardId, Iterable<int> tagIds) async {
    await transaction(() async {
      await (delete(cardTags)..where((c) => c.cardId.equals(cardId))).go();
      await addTagsToCard(cardId, tagIds);
    });
  }

  Future<Map<int, int>> columnCounts() async {
    final rows = await customSelect('SELECT column_id, COUNT(*) AS n FROM cards GROUP BY column_id').get();
    return {for (final r in rows) r.read<int>('column_id'): r.read<int>('n')};
  }

  // ---- tags ------------------------------------------------------------------

  Stream<List<Tag>> watchTags() => (select(tags)..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.name)])).watch();

  Future<int> createTag(String name, {int? parentId, int? color}) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Tag name is empty');
    final siblings = (await (select(tags)..where((t) => parentId == null ? t.parentId.isNull() : t.parentId.equals(parentId))).get()).length;
    return into(tags).insert(TagsCompanion.insert(name: n, parentId: Value(parentId), color: Value(color), sortOrder: Value(siblings)));
  }

  Future<void> renameTag(int id, String name) => (update(tags)..where((t) => t.id.equals(id))).write(TagsCompanion(name: Value(name.trim())));

  /// Deletes a tag and its whole subtree.
  Future<void> deleteTag(int id) async {
    final all = await select(tags).get();
    final doomed = <int>{id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final t in all) {
        if (t.parentId != null && doomed.contains(t.parentId) && doomed.add(t.id)) grew = true;
      }
    }
    await (delete(tags)..where((t) => t.id.isIn(doomed))).go();
  }

  /// Tags as a tree, children sorted like siblings.
  static List<TagNode> buildTagTree(List<Tag> flat) {
    List<TagNode> children(int? parent) => [
          for (final t in flat.where((t) => t.parentId == parent)) TagNode(t, children(t.id)),
        ];
    return children(null);
  }

  /// "Work › Design" style path for a tag.
  static String tagPath(List<Tag> flat, Tag tag) {
    final parts = <String>[tag.name];
    var cur = tag;
    while (cur.parentId != null) {
      final p = flat.where((t) => t.id == cur.parentId).firstOrNull;
      if (p == null) break;
      parts.insert(0, p.name);
      cur = p;
    }
    return parts.join(' › ');
  }
}
