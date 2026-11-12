import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_format.dart';
import '../../../store/database.dart';
import '../../../store/planner_queries.dart';

/// Sentinel returned by [showSnoozePicker] for "bring it back now".
abstract final class SnoozeChoice {
  static final DateTime unsnooze = DateTime.fromMillisecondsSinceEpoch(0);
}

String describeSnooze(DateTime t) {
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  final time = clockTime(t);
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
      title: const Text('Later, until'),
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
          child: const Row(children: [Icon(Icons.calendar_month_outlined, size: 20), SizedBox(width: 12), Expanded(child: Text('Pick a date and time…'))]),
        ),
        if (currentlySnoozedUntil != null)
          SimpleDialogOption(
            key: const ValueKey('snooze-clear'),
            onPressed: () => Navigator.pop(ctx, SnoozeChoice.unsnooze),
            child: const Row(children: [Icon(Icons.undo_rounded, size: 20), SizedBox(width: 12), Expanded(child: Text('Bring it back now'))]),
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
