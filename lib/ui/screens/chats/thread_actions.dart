import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/database.dart';
import '../../../store/done_queries.dart';
import '../../../store/planner_queries.dart';
import '../../theme/tokens.dart';
import 'later_dialogs.dart';

/// The "⋯" on a thread card: mark it done, or set a reminder.
class ThreadMenuButton extends ConsumerWidget {
  const ThreadMenuButton({super.key, required this.threadKey, required this.messages});
  final String threadKey;
  final List<Message> messages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newest = messages.first;
    final subject = newest.subject.isEmpty ? '(no subject)' : newest.subject;
    // Done when every incoming email in the thread is done.
    final incoming = [for (final m in messages) if (!m.isFromMe) m];
    final done = incoming.isNotEmpty && incoming.every((m) => m.doneAt != null);
    return PopupMenuButton<String>(
      tooltip: 'Thread actions',
      icon: Icon(done ? Icons.check_circle_rounded : Icons.more_horiz_rounded, size: 20, color: done ? Theme.of(context).colorScheme.primary : null),
      padding: EdgeInsets.zero,
      onSelected: (v) async {
        final db = ref.read(databaseProvider);
        final messenger = ScaffoldMessenger.of(context);
        switch (v) {
          case 'done':
            await db.setMessagesDone([for (final m in messages) m.id], !done);
          case 'remind':
            final rowKey = (await (db.select(db.messageRowAssignments)..where((r) => r.messageId.equals(newest.id))..limit(1)).getSingleOrNull())?.rowKey;
            if (!context.mounted) return;
            final id = await showReminderDialog(context, ref, title: subject, messageId: newest.id, threadKey: threadKey, rowKey: rowKey);
            if (id != null) messenger.showSnackBar(const SnackBar(persist: false, content: Text('Reminder set'), behavior: SnackBarBehavior.floating, width: 300));
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          key: ValueKey('thread-done-$threadKey'),
          value: 'done',
          child: ListTile(leading: Icon(done ? Icons.undo_rounded : Icons.check_rounded), title: Text(done ? 'Not done' : 'Done'), dense: true),
        ),
        const PopupMenuItem(value: 'remind', child: ListTile(leading: Icon(Icons.alarm_add_outlined), title: Text('Remind me…'), dense: true)),
      ],
    );
  }
}

final _remindersForMessageProvider = StreamProvider.family<List<Reminder>, int>((ref, id) => ref.watch(databaseProvider).watchRemindersForMessage(id));

/// Chips under a message for its reminders.
class ReminderChips extends ConsumerWidget {
  const ReminderChips({super.key, required this.messageId});
  final int messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(_remindersForMessageProvider(messageId)).value ?? const <Reminder>[];
    if (reminders.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
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
