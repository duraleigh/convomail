import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/conversation_state.dart';
import '../../app/destinations.dart';
import '../../app/people_state.dart';
import '../../app/search_state.dart';
import '../../store/database.dart';
import '../../store/planner_queries.dart';
import '../../store/sync_queries.dart';
import '../theme/tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/grouped_list.dart';
import 'destination_frame.dart';
import 'planner/event_dialogs.dart';
import 'planner/planner_state.dart';

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const double _hourHeight = 56;

/// Planner (spec 4.10, 5.3): mini month calendar and to-dos on the left,
/// the week grid in the middle, and the selected item's details with its
/// link back to the source conversation on the right.
class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(plannerWeekStartProvider);
    final selected = ref.watch(plannerSelectedEventProvider);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final title = weekStart.month == weekEnd.month ? '${_months[weekStart.month - 1]} ${weekStart.day}–${weekEnd.day}, ${weekStart.year}' : '${_months[weekStart.month - 1].substring(0, 3)} ${weekStart.day} – ${_months[weekEnd.month - 1].substring(0, 3)} ${weekEnd.day}, ${weekEnd.year}';
    return DestinationFrame(
      title: 'Planner',
      padContent: false,
      actions: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Previous week', onPressed: () => ref.read(plannerWeekStartProvider.notifier).shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
        TextButton(key: const ValueKey('planner-today'), onPressed: () => ref.read(plannerWeekStartProvider.notifier).today(), child: const Text('Today')),
        IconButton(tooltip: 'Next week', onPressed: () => ref.read(plannerWeekStartProvider.notifier).shift(1), icon: const Icon(Icons.chevron_right_rounded)),
      ],
      floatingAction: FloatingActionButton(
        heroTag: 'planner-fab',
        tooltip: 'New event or to-do',
        onPressed: () async {
          final id = await showEventEditor(context, ref, initialDate: DateTime.now());
          if (id != null) ref.read(plannerSelectedEventProvider.notifier).select(id);
        },
        child: const Icon(Icons.add_rounded),
      ),
      child: Row(
        children: [
          const SizedBox(width: 288, child: _SidePane()),
          VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const Expanded(child: _WeekView()),
          if (selected != null) _DetailPanel(eventId: selected),
        ],
      ),
    );
  }
}

class _SidePane extends ConsumerWidget {
  const _SidePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final todos = ref.watch(plannerTodosProvider).value ?? const <PlannerEvent>[];
    final reminders = ref.watch(plannerRemindersProvider).value ?? const <Reminder>[];
    return ListView(
      padding: const EdgeInsets.all(AppSpace.md),
      children: [
        const _MiniMonth(),
        const SizedBox(height: AppSpace.lg),
        Row(
          children: [
            Expanded(child: Text('TO-DO · ${todos.where((t) => !t.done).length}', style: text.labelSmall!.copyWith(letterSpacing: 1))),
            IconButton(
              key: const ValueKey('todo-add'),
              tooltip: 'Add to-do',
              visualDensity: VisualDensity.compact,
              onPressed: () => showEventEditor(context, ref, todo: true),
              icon: const Icon(Icons.add_rounded, size: 20),
            ),
          ],
        ),
        if (todos.isEmpty)
          Text('Nothing to do. Add one here or from a thread\'s menu in Chats.', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant))
        else
          GroupedList(
            color: scheme.surfaceContainer,
            children: [
              for (final t in todos)
                CheckboxListTile(
                  key: ValueKey('todo-${t.id}'),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: t.done,
                  onChanged: (v) => ref.read(databaseProvider).setEventDone(t.id, v ?? false),
                  title: Text(t.title, style: t.done ? text.bodyMedium!.copyWith(decoration: TextDecoration.lineThrough, color: scheme.onSurfaceVariant) : null),
                  subtitle: t.startAt == null ? null : Text(describeSnooze(t.startAt!), style: text.bodySmall),
                  secondary: IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_right_rounded), onPressed: () => ref.read(plannerSelectedEventProvider.notifier).select(t.id)),
                ),
            ],
          ),
        const SizedBox(height: AppSpace.lg),
        Text('REMINDERS · ${reminders.length}', style: text.labelSmall!.copyWith(letterSpacing: 1)),
        const SizedBox(height: 4),
        if (reminders.isEmpty)
          Text('Set one from a thread\'s menu in Chats.', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant))
        else
          GroupedList(
            color: scheme.surfaceContainer,
            children: [
              for (final r in reminders)
                ListTile(
                  key: ValueKey('reminder-${r.id}'),
                  dense: true,
                  leading: Icon(r.firedAt == null ? Icons.alarm_outlined : Icons.alarm_on_rounded, color: r.firedAt == null ? scheme.onSurfaceVariant : scheme.tertiary),
                  title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(describeSnooze(r.dueAt)),
                  trailing: IconButton(visualDensity: VisualDensity.compact, tooltip: 'Done', icon: const Icon(Icons.check_rounded), onPressed: () => ref.read(databaseProvider).setReminderDone(r.id, true)),
                  onTap: r.rowKey == null
                      ? null
                      : () {
                          ref.read(selectedRowProvider.notifier).select(r.rowKey);
                          if (r.messageId != null) {
                            ref.read(expandedMessagesProvider.notifier).expand(r.messageId!);
                            ref.read(scrollToMessageProvider.notifier).request(r.messageId!);
                          }
                          ref.read(destinationProvider.notifier).select(Destination.chats);
                        },
                ),
            ],
          ),
      ],
    );
  }
}

class _MiniMonth extends ConsumerWidget {
  const _MiniMonth();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final month = ref.watch(plannerMonthProvider);
    final weekStart = ref.watch(plannerWeekStartProvider);
    final now = DateTime.now();
    final first = DateTime(month.year, month.month, 1);
    final leading = (first.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[for (var i = 0; i < leading; i++) null, for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d)];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final events = ref.watch(_monthEventDaysProvider(month)).value ?? const <int>{};
    return Column(
      children: [
        Row(
          children: [
            IconButton(visualDensity: VisualDensity.compact, onPressed: () => ref.read(plannerMonthProvider.notifier).shift(-1), icon: const Icon(Icons.chevron_left_rounded, size: 20)),
            Expanded(child: Text('${_months[month.month - 1]} ${month.year}', textAlign: TextAlign.center, style: text.titleSmall)),
            IconButton(visualDensity: VisualDensity.compact, onPressed: () => ref.read(plannerMonthProvider.notifier).shift(1), icon: const Icon(Icons.chevron_right_rounded, size: 20)),
          ],
        ),
        Row(children: [for (final d in _days) Expanded(child: Text(d.substring(0, 1), textAlign: TextAlign.center, style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant)))]),
        for (var r = 0; r < cells.length ~/ 7; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Builder(builder: (context) {
                    final d = cells[r * 7 + c];
                    if (d == null) return const SizedBox(height: 32);
                    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
                    final inWeek = !d.isBefore(weekStart) && d.isBefore(weekStart.add(const Duration(days: 7)));
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppShapes.full),
                      onTap: () => ref.read(plannerWeekStartProvider.notifier).set(d),
                      child: Container(
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: isToday ? scheme.primary : (inWeek ? scheme.primaryContainer.withValues(alpha: 0.5) : null), shape: BoxShape.circle),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${d.day}', style: text.labelMedium!.copyWith(color: isToday ? scheme.onPrimary : scheme.onSurface)),
                            if (events.contains(d.day)) Container(width: 4, height: 4, decoration: BoxDecoration(color: isToday ? scheme.onPrimary : scheme.primary, shape: BoxShape.circle)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
      ],
    );
  }
}

final _monthEventDaysProvider = StreamProvider.family<Set<int>, DateTime>((ref, month) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  return ref.watch(databaseProvider).watchEventsBetween(start, end).map((list) => {for (final e in list) if (e.startAt != null) e.startAt!.day});
});

class _WeekView extends ConsumerStatefulWidget {
  const _WeekView();

  @override
  ConsumerState<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<_WeekView> {
  final _scroll = ScrollController(initialScrollOffset: 7 * _hourHeight);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final weekStart = ref.watch(plannerWeekStartProvider);
    final events = ref.watch(plannerWeekEventsProvider).value ?? const <PlannerEvent>[];
    final selected = ref.watch(plannerSelectedEventProvider);
    final now = DateTime.now();
    final days = [for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i))];
    final allDay = events.where((e) => e.allDay).toList();
    final timed = events.where((e) => !e.allDay && e.startAt != null).toList();

    Widget block(PlannerEvent e, {bool compact = false}) {
      final color = plannerColor(context, e.colorKey);
      final tentative = e.kind == 'extracted';
      return Material(
        key: ValueKey('event-${e.id}'),
        color: selected == e.id ? color : color.withValues(alpha: tentative ? 0.14 : 0.22),
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ref.read(plannerSelectedEventProvider.notifier).select(e.id),
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3)), borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.fromLTRB(6, 3, 4, 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    e.title,
                    maxLines: compact ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium!.copyWith(color: selected == e.id ? scheme.onPrimary : scheme.onSurface, fontStyle: tentative ? FontStyle.italic : null, letterSpacing: 0),
                  ),
                ),
                if (e.kind == 'invite') Icon(Icons.mail_outline_rounded, size: 12, color: color),
                if (tentative) Icon(Icons.help_outline_rounded, size: 12, color: color),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Day headers + all-day row.
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 8, 12, 0),
          child: Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Column(
                    children: [
                      Text(_days[d.weekday - 1].toUpperCase(), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1)),
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _sameDay(d, now) ? scheme.primary : null, shape: BoxShape.circle),
                        child: Text('${d.day}', style: text.titleMedium!.copyWith(color: _sameDay(d, now) ? scheme.onPrimary : scheme.onSurface)),
                      ),
                      SizedBox(
                        height: 28,
                        child: Column(children: [for (final e in allDay.where((e) => _sameDay(e.startAt!, d)).take(1)) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: SizedBox(height: 22, child: block(e, compact: true)))]),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: events.isEmpty && !_sameWeek(now, weekStart)
              ? const EmptyState(icon: Icons.calendar_month_outlined, title: 'Nothing this week', message: 'Events found in your mail, invitations, and anything you add show up here.')
              : SingleChildScrollView(
                  controller: _scroll,
                  child: SizedBox(
                    height: 24 * _hourHeight,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final dayWidth = (constraints.maxWidth - 56 - 12) / 7;
                      return Stack(
                        children: [
                          // Hour lines and labels.
                          for (var h = 0; h < 24; h++) ...[
                            Positioned(top: h * _hourHeight, left: 0, right: 0, child: Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6))),
                            Positioned(
                              top: h * _hourHeight - 7,
                              left: 8,
                              child: Text(h == 0 ? '' : (h < 12 ? '$h AM' : (h == 12 ? '12 PM' : '${h - 12} PM')), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
                            ),
                          ],
                          // Day separators.
                          for (var i = 1; i < 7; i++) Positioned(top: 0, bottom: 0, left: 56 + i * dayWidth, child: VerticalDivider(width: 1, color: scheme.outlineVariant.withValues(alpha: 0.4))),
                          // Now line.
                          if (_sameWeek(now, weekStart))
                            Positioned(
                              top: (now.hour + now.minute / 60) * _hourHeight,
                              left: 56 + (now.weekday - 1) * dayWidth,
                              width: dayWidth,
                              child: Container(height: 2, color: scheme.error),
                            ),
                          // Events, laid out per day with simple overlap columns.
                          for (var i = 0; i < 7; i++)
                            ..._layoutDay(timed.where((e) => _sameDay(e.startAt!, days[i])).toList()).map((slot) {
                              final e = slot.$1;
                              final start = e.startAt!;
                              final end = e.endAt ?? start.add(const Duration(hours: 1));
                              final top = (start.hour + start.minute / 60) * _hourHeight;
                              final height = ((end.difference(start).inMinutes / 60) * _hourHeight).clamp(22.0, 24 * _hourHeight - top);
                              final w = dayWidth / slot.$3;
                              return Positioned(
                                top: top + 1,
                                left: 56 + i * dayWidth + slot.$2 * w + 2,
                                width: w - 4,
                                height: height - 2,
                                child: block(e),
                              );
                            }),
                        ],
                      );
                    }),
                  ),
                ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static bool _sameWeek(DateTime d, DateTime weekStart) => !d.isBefore(weekStart) && d.isBefore(weekStart.add(const Duration(days: 7)));

  /// (event, column index, column count) so overlapping events share width.
  static List<(PlannerEvent, int, int)> _layoutDay(List<PlannerEvent> events) {
    events.sort((a, b) => a.startAt!.compareTo(b.startAt!));
    final out = <(PlannerEvent, int, int)>[];
    final cluster = <PlannerEvent>[];
    DateTime? clusterEnd;
    void flush() {
      if (cluster.isEmpty) return;
      final cols = <DateTime>[];
      final placed = <(PlannerEvent, int)>[];
      for (final e in cluster) {
        final end = e.endAt ?? e.startAt!.add(const Duration(hours: 1));
        var col = cols.indexWhere((c) => !c.isAfter(e.startAt!));
        if (col < 0) {
          cols.add(end);
          col = cols.length - 1;
        } else {
          cols[col] = end;
        }
        placed.add((e, col));
      }
      for (final p in placed) {
        out.add((p.$1, p.$2, cols.length));
      }
      cluster.clear();
      clusterEnd = null;
    }

    for (final e in events) {
      final end = e.endAt ?? e.startAt!.add(const Duration(hours: 1));
      if (clusterEnd != null && !e.startAt!.isBefore(clusterEnd!)) flush();
      cluster.add(e);
      clusterEnd = clusterEnd == null || end.isAfter(clusterEnd!) ? end : clusterEnd;
    }
    flush();
    return out;
  }
}

class _DetailPanel extends ConsumerWidget {
  const _DetailPanel({required this.eventId});
  final int eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final event = ref.watch(plannerEventProvider(eventId)).value;
    final db = ref.read(databaseProvider);
    if (event == null) return const SizedBox(width: 360);
    final color = plannerColor(context, event.colorKey);
    final kindLabel = switch (event.kind) {
      'invite' => 'Calendar invitation',
      'extracted' => 'Found in a message',
      'todo' => 'To-do',
      _ => 'Event',
    };
    String when() {
      final s = event.startAt;
      if (s == null) return 'No date';
      if (event.allDay) return '${_days[s.weekday - 1]}, ${_months[s.month - 1]} ${s.day} · all day';
      final e = event.endAt;
      return '${_days[s.weekday - 1]}, ${_months[s.month - 1]} ${s.day} · ${_clock(s)}${e == null ? '' : ' – ${_clock(e)}'}';
    }

    return Container(
      key: const ValueKey('planner-detail'),
      width: 360,
      decoration: BoxDecoration(color: scheme.surface, border: Border(left: BorderSide(color: scheme.outlineVariant))),
      child: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(kindLabel, style: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant))),
              IconButton(tooltip: 'Close', onPressed: () => ref.read(plannerSelectedEventProvider.notifier).select(null), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          Text(event.title, style: text.headlineSmall),
          const SizedBox(height: 4),
          Text(when(), style: text.bodyMedium),
          if (event.location != null && event.location!.isNotEmpty) ...[const SizedBox(height: 4), Text(event.location!, style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant))],
          if (event.notes.isNotEmpty) ...[const SizedBox(height: AppSpace.md), Text(event.notes, style: text.bodyMedium)],
          if (event.kind == 'extracted' && event.evidence.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
              child: Text('"${event.evidence}"', style: text.bodySmall!.copyWith(fontStyle: FontStyle.italic)),
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (event.sourceMessageId != null)
                FilledButton.tonalIcon(
                  key: const ValueKey('event-open-conversation'),
                  onPressed: () async {
                    final m = await db.messageById(event.sourceMessageId!);
                    if (m == null) return;
                    final row = await (db.select(db.messageRowAssignments)..where((r) => r.messageId.equals(m.id))..limit(1)).getSingleOrNull();
                    ref.read(selectedRowProvider.notifier).select(row?.rowKey);
                    ref.read(expandedMessagesProvider.notifier).expand(m.id);
                    ref.read(scrollToMessageProvider.notifier).request(m.id);
                    ref.read(destinationProvider.notifier).select(Destination.chats);
                  },
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: const Text('Open conversation'),
                ),
              if (event.kind == 'extracted') ...[
                FilledButton.icon(key: const ValueKey('event-confirm'), onPressed: () => db.confirmEvent(event.id), icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Keep')),
                OutlinedButton.icon(key: const ValueKey('event-dismiss'), onPressed: () {
                  db.dismissEvent(event.id);
                  ref.read(plannerSelectedEventProvider.notifier).select(null);
                }, icon: const Icon(Icons.close_rounded, size: 18), label: const Text('Not an event')),
              ],
              if (event.kind == 'todo') FilledButton.tonalIcon(onPressed: () => db.setEventDone(event.id, !event.done), icon: Icon(event.done ? Icons.undo_rounded : Icons.check_rounded, size: 18), label: Text(event.done ? 'Mark not done' : 'Mark done')),
              OutlinedButton.icon(onPressed: () => showEventEditor(context, ref, existing: event), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
              TextButton.icon(
                onPressed: () {
                  db.deleteEvent(event.id);
                  ref.read(plannerSelectedEventProvider.notifier).select(null);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }
}
