import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/conversation_state.dart';
import '../../app/destinations.dart';
import '../../app/people_state.dart';
import '../../store/board_queries.dart';
import '../../store/database.dart';
import '../theme/tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/tonal_avatar.dart';
import 'boards/tag_picker.dart';
import 'chats/message_card.dart';
import 'chats/people_list_pane.dart' show relativeTime;
import 'destination_frame.dart';

final boardColumnsProvider = StreamProvider<List<BoardColumn>>((ref) => ref.watch(databaseProvider).watchColumns());
final boardCardsProvider = StreamProvider<List<CardInfo>>((ref) => ref.watch(databaseProvider).watchCards());

/// Tag filter for the board (null = all cards).
final boardTagFilterProvider = NotifierProvider<BoardTagFilterNotifier, int?>(BoardTagFilterNotifier.new);

class BoardTagFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;
}

/// Card whose conversation is open in the side panel.
final boardOpenCardProvider = NotifierProvider<BoardOpenCardNotifier, int?>(BoardOpenCardNotifier.new);

class BoardOpenCardNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void open(int? id) => state = id;
}

/// Kanban board (spec 4.8, 5.3): horizontally scrolling columns of
/// draggable cards with lift-and-tilt, count badges, a tag filter, and a
/// right-side conversation panel.
class BoardsScreen extends ConsumerWidget {
  const BoardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = ref.watch(boardColumnsProvider).value ?? const <BoardColumn>[];
    final allCards = ref.watch(boardCardsProvider).value ?? const <CardInfo>[];
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final filter = ref.watch(boardTagFilterProvider);
    final openId = ref.watch(boardOpenCardProvider);
    final cards = filter == null ? allCards : allCards.where((c) => c.tags.any((t) => t.id == filter || _descends(tags, t, filter))).toList();
    final open = openId == null ? null : allCards.where((c) => c.card.id == openId).firstOrNull;
    final scheme = Theme.of(context).colorScheme;

    return DestinationFrame(
      title: 'Boards',
      padContent: false,
      actions: [
        PopupMenuButton<int?>(
          tooltip: 'Filter by tag',
          icon: Icon(filter == null ? Icons.filter_list_rounded : Icons.filter_alt_rounded, color: filter == null ? null : scheme.primary),
          onSelected: (v) => ref.read(boardTagFilterProvider.notifier).set(v == -1 ? null : v),
          itemBuilder: (_) => [
            const PopupMenuItem(value: -1, child: Text('All cards')),
            for (final t in tags) PopupMenuItem(value: t.id, child: Text(BoardQueries.tagPath(tags, t))),
          ],
        ),
      ],
      floatingAction: FloatingActionButton.extended(
        heroTag: 'boards-fab',
        onPressed: () => _promptColumn(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New column'),
      ),
      child: Row(
        children: [
          Expanded(
            child: allCards.isEmpty
                ? const EmptyState(icon: Icons.view_kanban_outlined, title: 'No cards yet', message: 'Open a conversation in Chats and choose "Add to board" from a thread\'s menu.')
                : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(AppSpace.lg),
                    children: [
                      for (final col in columns) ...[
                        _BoardColumnView(column: col, cards: cards.where((c) => c.card.columnId == col.id).toList(), canDelete: columns.length > 1),
                        const SizedBox(width: AppSpace.md),
                      ],
                    ],
                  ),
          ),
          if (open != null) _CardPanel(card: open),
        ],
      ),
    );
  }

  static bool _descends(List<Tag> all, Tag t, int ancestor) {
    var cur = t;
    while (cur.parentId != null) {
      if (cur.parentId == ancestor) return true;
      final p = all.where((x) => x.id == cur.parentId).firstOrNull;
      if (p == null) return false;
      cur = p;
    }
    return false;
  }

  static Future<void> _promptColumn(BuildContext context, WidgetRef ref, {BoardColumn? existing}) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New column' : 'Rename column'),
        content: TextField(key: const ValueKey('column-name'), controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Waiting on', isDense: true, border: OutlineInputBorder()), onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('column-save'), onPressed: () => Navigator.pop(ctx, controller.text), child: Text(existing == null ? 'Add' : 'Save')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final db = ref.read(databaseProvider);
    if (existing == null) {
      await db.addColumn(name);
    } else {
      await db.renameColumn(existing.id, name);
    }
  }
}

class _BoardColumnView extends ConsumerWidget {
  const _BoardColumnView({required this.column, required this.cards, required this.canDelete});
  final BoardColumn column;
  final List<CardInfo> cards;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final db = ref.read(databaseProvider);
    return DragTarget<CardInfo>(
      onWillAcceptWithDetails: (d) => true,
      onAcceptWithDetails: (d) => db.moveCard(d.data.card.id, column.id),
      builder: (context, candidates, _) {
        final hot = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 300,
          decoration: BoxDecoration(
            color: hot ? scheme.primaryContainer.withValues(alpha: 0.45) : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppShapes.lg),
            border: hot ? Border.all(color: scheme.primary) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
                child: Row(
                  children: [
                    Expanded(child: Text(column.name, style: text.titleMedium, overflow: TextOverflow.ellipsis)),
                    Container(
                      key: ValueKey('column-count-${column.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(AppShapes.full)),
                      child: Text('${cards.length}', style: text.labelSmall!.copyWith(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700, letterSpacing: 0)),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Column',
                      onSelected: (v) async {
                        if (v == 'rename') {
                          await BoardsScreen._promptColumn(context, ref, existing: column);
                          return;
                        }
                        if (v == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Delete "${column.name}"?'),
                              content: Text('Its ${cards.length} card${cards.length == 1 ? '' : 's'} move to the first column.'),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
                            ),
                          );
                          if (ok == true) await db.deleteColumn(column.id);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'rename', child: Text('Rename')),
                        if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete column')),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: cards.isEmpty
                    ? Center(child: Text('Drop cards here', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                        itemCount: cards.length,
                        itemBuilder: (context, i) => _DraggableCard(info: cards[i], index: i),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DraggableCard extends ConsumerWidget {
  const _DraggableCard({required this.info, required this.index});
  final CardInfo info;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final card = _BoardCard(info: info);
    // Dropping on a card inserts before it (within or across columns).
    return DragTarget<CardInfo>(
      onWillAcceptWithDetails: (d) => d.data.card.id != info.card.id,
      onAcceptWithDetails: (d) => db.moveCard(d.data.card.id, info.card.columnId, index: index),
      builder: (context, candidates, _) => Column(
        children: [
          AnimatedContainer(duration: const Duration(milliseconds: 120), height: candidates.isNotEmpty ? 56 : 0, margin: EdgeInsets.only(bottom: candidates.isNotEmpty ? 8 : 0), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppShapes.md))),
          Draggable<CardInfo>(
            data: info,
            feedback: Transform.rotate(
              angle: 0.035,
              child: Material(
                color: Colors.transparent,
                elevation: 10,
                shadowColor: Colors.black45,
                borderRadius: BorderRadius.circular(AppShapes.md),
                child: SizedBox(width: 284, child: card),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: card),
            child: card,
          ),
        ],
      ),
    );
  }
}

class _BoardCard extends ConsumerWidget {
  const _BoardCard({required this.info});
  final CardInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = ref.watch(boardOpenCardProvider) == info.card.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: ValueKey('card-${info.card.id}'),
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppShapes.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ref.read(boardOpenCardProvider.notifier).open(info.card.id),
          onSecondaryTapUp: (d) => _menu(context, ref, d.globalPosition),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.title, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TonalAvatar(identityKey: info.senderKey, name: info.senderName, size: 24),
                    const SizedBox(width: 8),
                    Expanded(child: Text(info.senderName, style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                    if (info.messageCount > 1) Text('${info.messageCount} · ', style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
                    Text(relativeTime(info.lastDate), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
                  ],
                ),
                if (info.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [for (final t in info.tags) TagChip(t.name, color: t.color)]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, Offset at) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final columns = ref.read(boardColumnsProvider).value ?? const <BoardColumn>[];
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        const PopupMenuItem(value: 'tags', child: Text('Tags…')),
        for (final c in columns.where((c) => c.id != info.card.columnId)) PopupMenuItem(value: 'move:${c.id}', child: Text('Move to ${c.name}')),
        const PopupMenuItem(value: 'remove', child: Text('Remove from board')),
      ],
    );
    if (v == null || !context.mounted) return;
    final db = ref.read(databaseProvider);
    if (v == 'tags') {
      final picked = await showTagPicker(context, selected: info.tags.map((t) => t.id).toSet());
      if (picked != null) await db.setCardTags(info.card.id, picked);
    } else if (v.startsWith('move:')) {
      await db.moveCard(info.card.id, int.parse(v.substring(5)));
    } else if (v == 'remove') {
      await db.removeCard(info.card.id);
      if (ref.read(boardOpenCardProvider) == info.card.id) ref.read(boardOpenCardProvider.notifier).open(null);
    }
  }
}

/// Right-side panel: the card's thread without leaving the board.
class _CardPanel extends ConsumerWidget {
  const _CardPanel({required this.card});
  final CardInfo card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final messages = ref.watch(threadMessagesProvider(card.card.threadKey));
    return Container(
      width: 480,
      decoration: BoxDecoration(color: scheme.surface, border: Border(left: BorderSide(color: scheme.outlineVariant))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text(card.title, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (card.rowKey != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(selectedRowProvider.notifier).select(card.rowKey);
                      ref.read(destinationProvider.notifier).select(Destination.chats);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open in Chats'),
                  ),
                IconButton(tooltip: 'Close', onPressed: () => ref.read(boardOpenCardProvider.notifier).open(null), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) => ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final m in list) ...[
                    MessageCard(message: m, showViewThread: false),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
