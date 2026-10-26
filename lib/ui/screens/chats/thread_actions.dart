import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/destinations.dart';
import '../../../store/board_queries.dart';
import '../../../store/database.dart';
import '../../../store/planner_queries.dart';
import '../../theme/tokens.dart';
import '../boards/tag_picker.dart';
import '../planner/event_dialogs.dart';
import '../planner/planner_state.dart';

final cardForThreadProvider = StreamProvider.family<Card?, String>((ref, threadKey) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.cards)..where((c) => c.threadKey.equals(threadKey))).watchSingleOrNull();
});

/// The "⋮" on a thread card: put it on the board, set tags, remind, or
/// create a planner event linked to it (spec 4.8, 4.9, 4.10).
class ThreadMenuButton extends ConsumerWidget {
  const ThreadMenuButton({super.key, required this.threadKey, required this.messages});
  final String threadKey;
  final List<Message> messages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onBoard = ref.watch(cardForThreadProvider(threadKey)).value;
    final newest = messages.first;
    final subject = newest.subject.isEmpty ? '(no subject)' : newest.subject;
    return PopupMenuButton<String>(
      tooltip: 'Thread actions',
      icon: Icon(onBoard != null ? Icons.view_kanban : Icons.more_horiz_rounded, size: 20, color: onBoard != null ? Theme.of(context).colorScheme.primary : null),
      padding: EdgeInsets.zero,
      onSelected: (v) async {
        final db = ref.read(databaseProvider);
        final messenger = ScaffoldMessenger.of(context);
        switch (v) {
          case 'board':
            final picked = await showTagPicker(context, selected: {}, title: 'Add to board · tags');
            if (picked == null) return;
            await db.addCard(threadKey, tagIds: picked);
            messenger.showSnackBar(SnackBar(
              content: Text('"$subject" is on the board'),
              behavior: SnackBarBehavior.floating,
              width: 400,
              action: SnackBarAction(label: 'Open board', onPressed: () => ref.read(destinationProvider.notifier).select(Destination.boards)),
            ));
          case 'tags':
            final card = onBoard!;
            final current = (await (db.select(db.cardTags)..where((t) => t.cardId.equals(card.id))).get()).map((t) => t.tagId).toSet();
            if (!context.mounted) return;
            final picked = await showTagPicker(context, selected: current);
            if (picked != null) await db.setCardTags(card.id, picked);
          case 'unboard':
            await db.removeCard(onBoard!.id);
          case 'remind':
            final rowKey = (await (db.select(db.messageRowAssignments)..where((r) => r.messageId.equals(newest.id))..limit(1)).getSingleOrNull())?.rowKey;
            if (!context.mounted) return;
            final id = await showReminderDialog(context, ref, title: subject, messageId: newest.id, threadKey: threadKey, rowKey: rowKey);
            if (id != null) messenger.showSnackBar(const SnackBar(content: Text('Reminder set'), behavior: SnackBarBehavior.floating, width: 300));
          case 'event':
            final id = await showEventEditor(context, ref, initialTitle: subject, initialDate: DateTime.now(), sourceMessageId: newest.id, threadKey: threadKey);
            if (id != null) {
              messenger.showSnackBar(SnackBar(
                content: const Text('Added to Planner'),
                behavior: SnackBarBehavior.floating,
                width: 320,
                action: SnackBarAction(label: 'Open', onPressed: () => openPlannerAt(ref, id)),
              ));
            }
          case 'todo':
            final id = await showEventEditor(context, ref, initialTitle: subject, todo: true, sourceMessageId: newest.id, threadKey: threadKey);
            if (id != null) messenger.showSnackBar(const SnackBar(content: Text('To-do added'), behavior: SnackBarBehavior.floating, width: 300));
        }
      },
      itemBuilder: (_) => [
        if (onBoard == null)
          const PopupMenuItem(value: 'board', child: ListTile(leading: Icon(Icons.view_kanban_outlined), title: Text('Add to board…'), dense: true))
        else ...[
          const PopupMenuItem(value: 'tags', child: ListTile(leading: Icon(Icons.label_outline_rounded), title: Text('Tags…'), dense: true)),
          const PopupMenuItem(value: 'unboard', child: ListTile(leading: Icon(Icons.remove_circle_outline_rounded), title: Text('Remove from board'), dense: true)),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'remind', child: ListTile(leading: Icon(Icons.alarm_add_outlined), title: Text('Remind me…'), dense: true)),
        const PopupMenuItem(value: 'event', child: ListTile(leading: Icon(Icons.event_outlined), title: Text('Create event…'), dense: true)),
        const PopupMenuItem(value: 'todo', child: ListTile(leading: Icon(Icons.check_circle_outline_rounded), title: Text('Add to-do…'), dense: true)),
      ],
    );
  }
}

final _eventsForMessageProvider = StreamProvider.family<List<PlannerEvent>, int>((ref, id) => ref.watch(databaseProvider).watchEventsForMessage(id));
final _remindersForMessageProvider = StreamProvider.family<List<Reminder>, int>((ref, id) => ref.watch(databaseProvider).watchRemindersForMessage(id));

/// Chips under a message for its linked planner items (spec 4.10
/// bidirectional links). Tapping opens the Planner on that item.
class LinkedPlannerChips extends ConsumerWidget {
  const LinkedPlannerChips({super.key, required this.messageId});
  final int messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(_eventsForMessageProvider(messageId)).value ?? const <PlannerEvent>[];
    final reminders = ref.watch(_remindersForMessageProvider(messageId)).value ?? const <Reminder>[];
    if (events.isEmpty && reminders.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in events)
            ActionChip(
              key: ValueKey('linked-event-${e.id}'),
              avatar: Icon(e.kind == 'todo' ? Icons.check_circle_outline_rounded : (e.kind == 'invite' ? Icons.mail_outline_rounded : Icons.event_outlined), size: 16, color: plannerColor(context, e.colorKey)),
              label: Text(e.startAt == null ? e.title : '${e.title} · ${describeSnooze(e.startAt!)}'),
              tooltip: e.kind == 'extracted' ? 'Found in this message: "${e.evidence}"' : 'Open in Planner',
              onPressed: () => openPlannerAt(ref, e.id),
            ),
          for (final r in reminders)
            Chip(
              avatar: Icon(Icons.alarm_outlined, size: 16, color: scheme.tertiary),
              label: Text('Reminder · ${describeSnooze(r.dueAt)}'),
              onDeleted: () => ref.read(databaseProvider).deleteReminder(r.id),
              deleteButtonTooltipMessage: 'Remove reminder',
            ),
        ],
      ),
    );
  }
}
