import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/people_state.dart';
import '../../../store/database.dart';
import '../../../sync/row_actions.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/grouped_list.dart';
import 'people_list_pane.dart';

/// Interim right pane for milestone 2: the selected row's messages as a
/// simple list. Milestone 3 replaces this with the conversation view.
class RowMessagesPane extends ConsumerWidget {
  const RowMessagesPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selectedKey = ref.watch(selectedRowProvider);
    final rows = ref.watch(peopleRowsProvider).value ?? const [];
    final row = rows.where((r) => r.rowKey == selectedKey).firstOrNull;
    final messages = ref.watch(selectedRowMessagesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppShapes.xl),
        clipBehavior: Clip.antiAlias,
        child: selectedKey == null
            ? const EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'Pick a person', message: 'Their whole conversation with you will show here.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                    child: Row(
                      children: [
                        if (row != null) rowAvatar(row, size: 32),
                        const SizedBox(width: 10),
                        Expanded(child: Text(row?.title ?? selectedKey, style: text.titleLarge, overflow: TextOverflow.ellipsis)),
                        if (row != null)
                          Text('${row.total} message${row.total == 1 ? '' : 's'}', style: text.labelMedium!.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: messages.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (list) => list.isEmpty
                          ? const EmptyState(icon: Icons.mark_email_read_outlined, title: 'Nothing here', message: 'No messages in this conversation.')
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: list.length,
                              itemBuilder: (context, i) => Padding(
                                padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
                                child: GroupedListItem(
                                  radius: GroupedList.radiusFor(i, list.length),
                                  onTap: () => ref.read(rowActionsProvider).markMessageRead(list[i].id, seen: !list[i].isSeen),
                                  child: _MessageLine(message: list[i]),
                                ),
                              ),
                            ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    color: scheme.surfaceContainer,
                    child: Text(
                      'Conversation view with threads, bodies and replies arrives in milestone 3. Click a message to toggle read.',
                      style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MessageLine extends StatelessWidget {
  const _MessageLine({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unread = !message.isSeen && !message.isFromMe;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: unread ? scheme.primary : Colors.transparent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.subject.isEmpty ? '(no subject)' : message.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge!.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
                ),
                if (message.snippet.isNotEmpty)
                  Text(message.snippet, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (message.hasAttachments) Icon(Icons.attach_file_rounded, size: 16, color: scheme.onSurfaceVariant),
          if (message.isFlagged) Icon(Icons.star_rounded, size: 16, color: scheme.primary),
          if (message.isFromMe) Text('You', style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 10),
          Text(relativeTime(message.date ?? message.internalDate), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
        ],
      ),
    );
  }
}
