import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/destinations.dart';
import '../../../store/database.dart';
import '../../../store/planner_queries.dart';

/// Monday 00:00 of the week shown in the Planner.
final plannerWeekStartProvider = NotifierProvider<PlannerWeekNotifier, DateTime>(PlannerWeekNotifier.new);

class PlannerWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => mondayOf(DateTime.now());
  void set(DateTime d) => state = mondayOf(d);
  void shift(int weeks) => state = state.add(Duration(days: 7 * weeks));
  void today() => state = mondayOf(DateTime.now());

  static DateTime mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }
}

/// The event whose detail panel is open, or null.
final plannerSelectedEventProvider = NotifierProvider<PlannerSelectedEventNotifier, int?>(PlannerSelectedEventNotifier.new);

class PlannerSelectedEventNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? id) => state = id;
}

final plannerWeekEventsProvider = StreamProvider<List<PlannerEvent>>((ref) {
  final start = ref.watch(plannerWeekStartProvider);
  return ref.watch(databaseProvider).watchEventsBetween(start, start.add(const Duration(days: 7)));
});

final plannerTodosProvider = StreamProvider<List<PlannerEvent>>((ref) => ref.watch(databaseProvider).watchTodos());
final plannerRemindersProvider = StreamProvider<List<Reminder>>((ref) => ref.watch(databaseProvider).watchReminders());
final plannerEventProvider = FutureProvider.family<PlannerEvent?, int>((ref, id) => ref.watch(databaseProvider).eventById(id));

/// Month shown in the mini calendar.
final plannerMonthProvider = NotifierProvider<PlannerMonthNotifier, DateTime>(PlannerMonthNotifier.new);

class PlannerMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  void shift(int months) => state = DateTime(state.year, state.month + months);
  void set(DateTime d) => state = DateTime(d.year, d.month);
}

/// Jumps to the Planner with [eventId] selected and its week shown.
Future<void> openPlannerAt(WidgetRef ref, int eventId) async {
  final e = await ref.read(databaseProvider).eventById(eventId);
  if (e?.startAt != null) {
    ref.read(plannerWeekStartProvider.notifier).set(e!.startAt!);
    ref.read(plannerMonthProvider.notifier).set(e.startAt!);
  }
  ref.read(plannerSelectedEventProvider.notifier).select(eventId);
  ref.read(destinationProvider.notifier).select(Destination.planner);
}
