import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/database.dart';
import '../../../store/planner_queries.dart';
import '../../theme/tokens.dart';

/// Sentinel returned by [showSnoozePicker] for "bring it back now".
abstract final class SnoozeChoice {
  static final DateTime unsnooze = DateTime.fromMillisecondsSinceEpoch(0);
}

String describeSnooze(DateTime t) {
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final time = '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  if (sameDay) return 'today $time';
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (t.year == tomorrow.year && t.month == tomorrow.month && t.day == tomorrow.day) return 'tomorrow $time';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[t.weekday - 1]} ${months[t.month - 1]} ${t.day}, $time';
}

/// Snooze presets plus a date-time picker (spec 4.9). Returns the wake
/// time, [SnoozeChoice.unsnooze], or null when cancelled.
Future<DateTime?> showSnoozePicker(BuildContext context, {DateTime? currentlySnoozedUntil}) async {
  final now = DateTime.now();
  final options = <(String, IconData, DateTime)>[
    ('Later today', Icons.schedule_rounded, SnoozePresets.laterToday(now)),
    ('This evening', Icons.nights_stay_outlined, SnoozePresets.thisEvening(now)),
    ('Tomorrow morning', Icons.wb_sunny_outlined, SnoozePresets.tomorrowMorning(now)),
    ('This weekend', Icons.weekend_outlined, SnoozePresets.nextWeekend(now)),
    ('Next Monday', Icons.next_week_outlined, SnoozePresets.nextMondayMorning(now)),
  ];
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Snooze until'),
      children: [
        for (final o in options)
          SimpleDialogOption(
            key: ValueKey('snooze-${o.$1}'),
            onPressed: () => Navigator.pop(ctx, o.$3),
            child: Row(children: [Icon(o.$2, size: 20), const SizedBox(width: 12), Expanded(child: Text(o.$1)), Text(describeSnooze(o.$3), style: Theme.of(ctx).textTheme.bodySmall)]),
          ),
        SimpleDialogOption(
          key: const ValueKey('snooze-pick'),
          onPressed: () async {
            final picked = await pickDateTime(ctx, initial: now.add(const Duration(days: 1)));
            if (ctx.mounted) Navigator.pop(ctx, picked);
          },
          child: const Row(children: [Icon(Icons.calendar_month_outlined, size: 20), SizedBox(width: 12), Text('Pick a date and time…')]),
        ),
        if (currentlySnoozedUntil != null)
          SimpleDialogOption(
            key: const ValueKey('snooze-clear'),
            onPressed: () => Navigator.pop(ctx, SnoozeChoice.unsnooze),
            child: const Row(children: [Icon(Icons.undo_rounded, size: 20), SizedBox(width: 12), Text('Bring it back now')]),
          ),
      ],
    ),
  );
}

Future<DateTime?> pickDateTime(BuildContext context, {required DateTime initial}) async {
  final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// "Remind me" with presets (spec 4.9). Creates the reminder; returns its id.
Future<int?> showReminderDialog(BuildContext context, WidgetRef ref, {required String title, int? messageId, String? threadKey, String? rowKey}) async {
  final now = DateTime.now();
  final options = <(String, DateTime)>[
    ('In an hour', now.add(const Duration(hours: 1))),
    ('This evening', SnoozePresets.thisEvening(now)),
    ('Tomorrow morning', SnoozePresets.tomorrowMorning(now)),
    ('Next Monday', SnoozePresets.nextMondayMorning(now)),
  ];
  final when = await showDialog<DateTime>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('Remind me about "$title"'),
      children: [
        for (final o in options)
          SimpleDialogOption(key: ValueKey('remind-${o.$1}'), onPressed: () => Navigator.pop(ctx, o.$2), child: Row(children: [Expanded(child: Text(o.$1)), Text(describeSnooze(o.$2), style: Theme.of(ctx).textTheme.bodySmall)])),
        SimpleDialogOption(
          onPressed: () async {
            final picked = await pickDateTime(ctx, initial: now.add(const Duration(hours: 2)));
            if (ctx.mounted) Navigator.pop(ctx, picked);
          },
          child: const Text('Pick a date and time…'),
        ),
      ],
    ),
  );
  if (when == null) return null;
  return ref.read(databaseProvider).addReminder(title: title, dueAt: when, messageId: messageId, threadKey: threadKey, rowKey: rowKey);
}

const plannerColorKeys = ['personal', 'work', 'travel', 'health', 'other'];

Color plannerColor(BuildContext context, String key) {
  final scheme = Theme.of(context).colorScheme;
  return switch (key) {
    'personal' => scheme.tertiary,
    'work' => scheme.primary,
    'travel' => const Color(0xFF00897B),
    'health' => const Color(0xFFD81B60),
    _ => scheme.secondary,
  };
}

/// Create or edit an event or to-do (spec 4.10). Returns the id.
Future<int?> showEventEditor(
  BuildContext context,
  WidgetRef ref, {
  PlannerEvent? existing,
  DateTime? initialDate,
  String? initialTitle,
  bool todo = false,
  int? sourceMessageId,
  String? threadKey,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _EventEditor(existing: existing, initialDate: initialDate, initialTitle: initialTitle, todo: todo, sourceMessageId: sourceMessageId, threadKey: threadKey),
  );
}

class _EventEditor extends ConsumerStatefulWidget {
  const _EventEditor({this.existing, this.initialDate, this.initialTitle, required this.todo, this.sourceMessageId, this.threadKey});
  final PlannerEvent? existing;
  final DateTime? initialDate;
  final String? initialTitle;
  final bool todo;
  final int? sourceMessageId;
  final String? threadKey;

  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? widget.initialTitle ?? '');
  late final _location = TextEditingController(text: widget.existing?.location ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late bool _isTodo = widget.existing?.kind == 'todo' || widget.todo;
  late bool _allDay = widget.existing?.allDay ?? false;
  late DateTime? _date = widget.existing?.startAt ?? widget.initialDate;
  late TimeOfDay _start = TimeOfDay.fromDateTime(widget.existing?.startAt ?? _roundUp(widget.initialDate ?? DateTime.now()));
  late TimeOfDay _end = TimeOfDay.fromDateTime(widget.existing?.endAt ?? (widget.existing?.startAt ?? _roundUp(widget.initialDate ?? DateTime.now())).add(const Duration(hours: 1)));
  late String _color = widget.existing?.colorKey ?? 'other';

  static DateTime _roundUp(DateTime t) => DateTime(t.year, t.month, t.day, t.hour + 1);

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    DateTime? start;
    DateTime? end;
    if (_date != null) {
      start = _allDay || _isTodo ? DateTime(_date!.year, _date!.month, _date!.day, _isTodo && !_allDay ? _start.hour : 0, _isTodo && !_allDay ? _start.minute : 0) : DateTime(_date!.year, _date!.month, _date!.day, _start.hour, _start.minute);
      if (!_isTodo && !_allDay) {
        end = DateTime(_date!.year, _date!.month, _date!.day, _end.hour, _end.minute);
        if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
      }
    }
    if (!_isTodo && start == null) return;
    int id;
    if (widget.existing == null) {
      id = await db.addEvent(
        title: _title.text,
        start: start,
        end: end,
        allDay: _allDay && !_isTodo,
        kind: _isTodo ? 'todo' : 'manual',
        colorKey: _color,
        sourceMessageId: widget.sourceMessageId,
        threadKey: widget.threadKey,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        notes: _notes.text,
      );
    } else {
      id = widget.existing!.id;
      await db.updateEvent(id, title: _title.text, start: start, end: end, clearEnd: end == null, allDay: _allDay && !_isTodo, colorKey: _color, location: _location.text.trim(), notes: _notes.text);
    }
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    String fmtTime(TimeOfDay t) => t.format(context);
    String fmtDate(DateTime d) => '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]}, ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.day}';
    return AlertDialog(
      title: Text(widget.existing == null ? (_isTodo ? 'New to-do' : 'New event') : (_isTodo ? 'Edit to-do' : 'Edit event')),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.existing == null)
                SegmentedButton<bool>(
                  segments: const [ButtonSegment(value: false, label: Text('Event'), icon: Icon(Icons.event_outlined)), ButtonSegment(value: true, label: Text('To-do'), icon: Icon(Icons.check_circle_outline_rounded))],
                  selected: {_isTodo},
                  onSelectionChanged: (s) => setState(() => _isTodo = s.first),
                  showSelectedIcon: false,
                ),
              const SizedBox(height: AppSpace.md),
              TextField(key: const ValueKey('event-title'), controller: _title, autofocus: true, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('event-date'),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (d != null) setState(() => _date = d);
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(_date == null ? (_isTodo ? 'No due date' : 'Pick a date') : fmtDate(_date!)),
                  ),
                  const SizedBox(width: 8),
                  if (!_allDay) ...[
                    OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: _start);
                        if (t != null) setState(() => _start = t);
                      },
                      child: Text(fmtTime(_start)),
                    ),
                    if (!_isTodo) ...[
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                      OutlinedButton(
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: _end);
                          if (t != null) setState(() => _end = t);
                        },
                        child: Text(fmtTime(_end)),
                      ),
                    ],
                  ],
                ],
              ),
              if (!_isTodo)
                CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, controlAffinity: ListTileControlAffinity.leading, value: _allDay, onChanged: (v) => setState(() => _allDay = v ?? false), title: const Text('All day')),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: 8,
                children: [
                  for (final k in plannerColorKeys)
                    ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: plannerColor(context, k), radius: 6),
                      label: Text(k[0].toUpperCase() + k.substring(1)),
                      selected: _color == k,
                      onSelected: (_) => setState(() => _color = k),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              if (!_isTodo) TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder(), isDense: true)),
              if (!_isTodo) const SizedBox(height: AppSpace.md),
              TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder(), isDense: true, alignLabelWithHint: true)),
              if (widget.sourceMessageId != null || widget.existing?.sourceMessageId != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text('Linked to a message in Chats.', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('event-save'), onPressed: _title.text.trim().isEmpty && widget.initialTitle == null ? null : _save, child: Text(widget.existing == null ? 'Add' : 'Save')),
      ],
    );
  }
}
