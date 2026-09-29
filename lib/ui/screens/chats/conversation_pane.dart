import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/conversation_state.dart';
import '../../../app/people_state.dart';
import '../../../store/database.dart';
import '../../../store/thread_queries.dart';
import '../../../sync/row_actions.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tonal_avatar.dart';
import 'message_card.dart';
import 'people_list_pane.dart';
import 'thread_view_panel.dart';

/// Right pane of Chats (spec 4.3, 5.3): the selected row's conversation,
/// grouped by day, one card per thread; tapping a collapsed card expands
/// its messages inline; "View thread" opens the cross-participant overlay.
class ConversationPane extends ConsumerWidget {
  const ConversationPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selectedKey = ref.watch(selectedRowProvider);
    final rows = ref.watch(peopleRowsProvider).value ?? const [];
    final row = rows.where((r) => r.rowKey == selectedKey).firstOrNull;
    final messages = ref.watch(selectedRowMessagesProvider);
    final openThread = ref.watch(openThreadProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppShapes.xl),
        clipBehavior: Clip.antiAlias,
        child: selectedKey == null
            ? const EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'Pick a person', message: 'Their whole conversation with you will show here.')
            : Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                        child: Row(
                          children: [
                            if (row != null) rowAvatar(row, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row?.title ?? selectedKey, style: text.titleLarge, overflow: TextOverflow.ellipsis),
                                  if (row != null && !row.isGroup && row.identityKey != row.title)
                                    Text(row.identityKey, style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            if (row != null) Text('${row.total} message${row.total == 1 ? '' : 's'}', style: text.labelMedium!.copyWith(color: scheme.onSurfaceVariant)),
                            const IconButton(tooltip: 'Search in conversation (milestone 6)', onPressed: null, icon: Icon(Icons.search_rounded)),
                            const IconButton(tooltip: 'Files (milestone 5)', onPressed: null, icon: Icon(Icons.folder_outlined)),
                            IconButton(
                              tooltip: row?.unread == 0 ? 'All read' : 'Mark all as read',
                              onPressed: row == null || row.unread == 0 ? null : () => ref.read(rowActionsProvider).markRowRead(row.rowKey),
                              icon: const Icon(Icons.mark_email_read_outlined),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: messages.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('$e')),
                          data: (list) => list.isEmpty
                              ? const EmptyState(icon: Icons.mark_email_read_outlined, title: 'Nothing here', message: 'No messages in this conversation.')
                              : _ThreadedList(messages: list),
                        ),
                      ),
                      _ReplyBarPlaceholder(rowTitle: row?.title ?? ''),
                    ],
                  ),
                  if (openThread != null) ThreadViewPanel(threadKey: openThread),
                ],
              ),
      ),
    );
  }
}

bool _autoExpanded = false;

/// Groups the row's messages by day, then by thread key within a day.
class _ThreadedList extends ConsumerWidget {
  const _ThreadedList({required this.messages});
  final List<Message> messages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Family argument must be value-equal across builds, so the keys are
    // joined into one sorted string rather than passed as a List.
    final keyArg = (messages.map((m) => m.threadKey ?? 'm:${m.id}').toSet().toList()..sort()).join('\n');
    final counts = ref.watch(_threadCountsProvider(keyArg)).value ?? const <String, int>{};
    final expanded = ref.watch(expandedMessagesProvider);
    if (ref.read(autoOpenFirstProvider) && expanded.isEmpty && messages.isNotEmpty && !_autoExpanded) {
      _autoExpanded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(expandedMessagesProvider.notifier).expand(messages.first.id));
    }

    // Build day sections, newest day first; within a day newest thread first.
    final sections = <_DaySection>[];
    for (final m in messages) {
      final ts = (m.date ?? m.internalDate ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
      final day = DateTime(ts.year, ts.month, ts.day);
      var sec = sections.where((s) => s.day == day).firstOrNull;
      if (sec == null) {
        sec = _DaySection(day);
        sections.add(sec);
      }
      final key = m.threadKey ?? 'm:${m.id}';
      sec.threads.putIfAbsent(key, () => []).add(m);
    }

    final items = <Widget>[];
    for (final sec in sections) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
        child: Text(_dayLabel(sec.day), style: Theme.of(context).textTheme.labelSmall!.copyWith(letterSpacing: 1)),
      ));
      for (final e in sec.threads.entries) {
        final msgs = e.value;
        final isExpanded = msgs.any((m) => expanded.contains(m.id));
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ThreadCard(
            threadKey: e.key,
            messages: msgs,
            threadCount: counts[e.key] ?? msgs.length,
            expanded: isExpanded,
            onToggle: () {
              final n = ref.read(expandedMessagesProvider.notifier);
              if (isExpanded) {
                for (final m in msgs) {
                  if (expanded.contains(m.id)) n.toggle(m.id);
                }
              } else {
                for (final m in msgs) {
                  n.expand(m.id);
                }
                for (final m in msgs.where((m) => !m.isSeen && !m.isFromMe)) {
                  ref.read(rowActionsProvider).markMessageRead(m.id);
                }
              }
            },
            onViewThread: () => ref.read(openThreadProvider.notifier).open(e.key),
          ),
        ));
      }
    }

    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), children: items);
  }

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    if (diff < 7) return 'LAST ${const ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'][day.weekday - 1]}';
    return '${const ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][day.month - 1]} ${day.day}${day.year == now.year ? '' : ', ${day.year}'}';
  }
}

class _DaySection {
  _DaySection(this.day);
  final DateTime day;
  final Map<String, List<Message>> threads = {};
}

final _threadCountsProvider = FutureProvider.family<Map<String, int>, String>((ref, joined) => ref.watch(databaseProvider).threadCounts(joined.isEmpty ? const [] : joined.split('\n')));

/// Collapsed: subject, count pill, latest sender and preview, time.
/// Expanded: every message of this row in the thread, as MessageCards.
class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.threadKey,
    required this.messages,
    required this.threadCount,
    required this.expanded,
    required this.onToggle,
    required this.onViewThread,
  });

  final String threadKey;
  final List<Message> messages;
  final int threadCount;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onViewThread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final newest = messages.first;
    final unread = messages.any((m) => !m.isSeen && !m.isFromMe);
    final subject = newest.subject.isEmpty ? '(no subject)' : newest.subject;

    return Material(
      color: expanded ? scheme.surfaceContainerLowest : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppShapes.lgIncreased),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subject, style: text.titleMedium!.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w600), maxLines: expanded ? 3 : 1, overflow: TextOverflow.ellipsis),
                          if (!expanded) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${newest.isFromMe ? 'You' : (newest.fromName.isNotEmpty ? newest.fromName.split(' ').first : newest.fromAddress)}  ${newest.snippet.isNotEmpty ? newest.snippet : ''}'.trimRight(),
                              style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (threadCount > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(AppShapes.full)),
                        child: Text('$threadCount', style: text.labelSmall!.copyWith(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700, letterSpacing: 0)),
                      ),
                    if (unread && !expanded) ...[const SizedBox(width: 8), const CountBadge(1)],
                    const SizedBox(width: 8),
                    Text(relativeTime(newest.date ?? newest.internalDate), style: text.labelSmall!.copyWith(color: unread ? scheme.primary : scheme.onSurfaceVariant, letterSpacing: 0)),
                    Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = messages.length - 1; i >= 0; i--) ...[
                      if (i != messages.length - 1) Divider(height: 24, color: scheme.outlineVariant),
                      MessageCard(message: messages[i], threadCount: threadCount, onViewThread: onViewThread),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplyBarPlaceholder extends StatelessWidget {
  const _ReplyBarPlaceholder({required this.rowTitle});
  final String rowTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppShapes.full)),
              alignment: Alignment.centerLeft,
              child: Text('Reply to ${rowTitle.split(' ').first}… (compose arrives in milestone 4)', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppShapes.lg)),
            alignment: Alignment.center,
            child: Icon(Icons.send_rounded, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
