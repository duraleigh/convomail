import 'package:drift/drift.dart';

import 'database.dart';
import 'people_queries.dart';

/// Planner events, to-dos, reminders, and snooze bookkeeping (spec 4.9,
/// 4.10).
extension PlannerQueries on AppDatabase {
  // ---- events ----------------------------------------------------------------

  /// Timed and all-day items overlapping [start, end), not dismissed, not
  /// to-dos.
  Stream<List<PlannerEvent>> watchEventsBetween(DateTime start, DateTime end) => (select(plannerEvents)
        ..where((e) => e.kind.equals('todo').not() & e.dismissed.equals(false) & e.startAt.isSmallerThanValue(end) & (e.endAt.isBiggerThanValue(start) | (e.endAt.isNull() & e.startAt.isBiggerOrEqualValue(start))))
        ..orderBy([(e) => OrderingTerm.asc(e.startAt)]))
      .watch();

  Stream<List<PlannerEvent>> watchTodos() => (select(plannerEvents)
        ..where((e) => e.kind.equals('todo') & e.dismissed.equals(false))
        ..orderBy([(e) => OrderingTerm.asc(e.done), (e) => OrderingTerm.asc(e.startAt), (e) => OrderingTerm.asc(e.id)]))
      .watch();

  Stream<List<PlannerEvent>> watchEventsForMessage(int messageId) => (select(plannerEvents)..where((e) => e.sourceMessageId.equals(messageId) & e.dismissed.equals(false))).watch();

  Stream<List<PlannerEvent>> watchEventsForThread(String threadKey) => (select(plannerEvents)..where((e) => e.threadKey.equals(threadKey) & e.dismissed.equals(false))).watch();

  Future<PlannerEvent?> eventById(int id) => (select(plannerEvents)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> addEvent({
    required String title,
    DateTime? start,
    DateTime? end,
    bool allDay = false,
    String kind = 'manual',
    String colorKey = 'other',
    int? sourceMessageId,
    String? threadKey,
    String? location,
    String notes = '',
  }) =>
      into(plannerEvents).insert(PlannerEventsCompanion.insert(
        title: title.trim().isEmpty ? (kind == 'todo' ? 'To-do' : 'Event') : title.trim(),
        startAt: Value(start),
        endAt: Value(end),
        allDay: Value(allDay),
        kind: kind,
        colorKey: Value(colorKey),
        sourceMessageId: Value(sourceMessageId),
        threadKey: Value(threadKey),
        location: Value(location),
        notes: Value(notes),
      ));

  Future<void> updateEvent(int id, {String? title, DateTime? start, DateTime? end, bool? allDay, String? colorKey, String? location, String? notes, bool clearEnd = false}) =>
      (update(plannerEvents)..where((e) => e.id.equals(id))).write(PlannerEventsCompanion(
        title: title == null ? const Value.absent() : Value(title.trim()),
        startAt: start == null ? const Value.absent() : Value(start),
        endAt: clearEnd ? const Value(null) : (end == null ? const Value.absent() : Value(end)),
        allDay: allDay == null ? const Value.absent() : Value(allDay),
        colorKey: colorKey == null ? const Value.absent() : Value(colorKey),
        location: location == null ? const Value.absent() : Value(location),
        notes: notes == null ? const Value.absent() : Value(notes),
      ));

  Future<void> setEventDone(int id, bool done) => (update(plannerEvents)..where((e) => e.id.equals(id))).write(PlannerEventsCompanion(done: Value(done)));

  Future<void> deleteEvent(int id) => (delete(plannerEvents)..where((e) => e.id.equals(id))).go();

  /// Removes everything the app once added to the Planner by itself:
  /// dates read out of mail and calendar invitations. Only what the user
  /// adds, and their Google Calendar, belong there.
  Future<int> deleteMailGuesses() => (delete(plannerEvents)..where((e) => e.kind.isIn(const ['extracted', 'invite']))).go();

  // ---- reminders -------------------------------------------------------------

  Stream<List<Reminder>> watchReminders({bool includeDone = false}) => (select(reminders)
        ..where((r) => includeDone ? const Constant(true) : r.done.equals(false))
        ..orderBy([(r) => OrderingTerm.asc(r.dueAt)]))
      .watch();

  Future<int> addReminder({required String title, required DateTime dueAt, int? messageId, String? threadKey, String? rowKey}) =>
      into(reminders).insert(RemindersCompanion.insert(title: title.trim().isEmpty ? 'Reminder' : title.trim(), dueAt: dueAt, messageId: Value(messageId), threadKey: Value(threadKey), rowKey: Value(rowKey)));

  Future<List<Reminder>> dueReminders(DateTime now) => (select(reminders)..where((r) => r.done.equals(false) & r.firedAt.isNull() & r.dueAt.isSmallerOrEqualValue(now))).get();

  Future<void> markReminderFired(int id, DateTime at) => (update(reminders)..where((r) => r.id.equals(id))).write(RemindersCompanion(firedAt: Value(at)));

  Future<void> setReminderDone(int id, bool done) => (update(reminders)..where((r) => r.id.equals(id))).write(RemindersCompanion(done: Value(done)));

  Future<void> deleteReminder(int id) => (delete(reminders)..where((r) => r.id.equals(id))).go();

  Stream<List<Reminder>> watchRemindersForMessage(int messageId) => (select(reminders)..where((r) => r.messageId.equals(messageId) & r.done.equals(false))).watch();

  // ---- snooze ----------------------------------------------------------------

  Future<void> snoozeRow(String rowKey, DateTime? until) async {
    await into(rowPrefs).insertOnConflictUpdate(RowPrefsCompanion(
      rowKey: Value(rowKey),
      snoozedUntil: Value(until),
      resurfacedAt: const Value(null),
      updatedAt: Value(DateTime.now()),
    ));
    await markRowsDirty([rowKey]);
    await refreshDirtyRows();
  }

  /// Rows whose snooze has ended: clears it, stamps the resurfacing time
  /// (so the row sorts as newly received), and returns their keys.
  Future<List<String>> resurfaceDueSnoozes(DateTime now) async {
    final due = await (select(rowPrefs)..where((p) => p.snoozedUntil.isNotNull() & p.snoozedUntil.isSmallerOrEqualValue(now))).get();
    if (due.isEmpty) return const [];
    await transaction(() async {
      for (final p in due) {
        await (update(rowPrefs)..where((x) => x.rowKey.equals(p.rowKey))).write(RowPrefsCompanion(snoozedUntil: const Value(null), resurfacedAt: Value(now), updatedAt: Value(now)));
      }
    });
    await markRowsDirty(due.map((p) => p.rowKey));
    await refreshDirtyRows();
    return due.map((p) => p.rowKey).toList();
  }

  Future<DateTime?> nextSnoozeDue() async {
    final row = await (select(rowPrefs)..where((p) => p.snoozedUntil.isNotNull())..orderBy([(p) => OrderingTerm.asc(p.snoozedUntil)])..limit(1)).getSingleOrNull();
    return row?.snoozedUntil;
  }
}

/// Snooze presets (spec 4.9).
abstract final class SnoozePresets {
  static DateTime laterToday(DateTime now) {
    final t = DateTime(now.year, now.month, now.day, now.hour + 3);
    return t;
  }

  static DateTime thisEvening(DateTime now) {
    final t = DateTime(now.year, now.month, now.day, 18);
    return t.isAfter(now) ? t : t.add(const Duration(days: 1));
  }

  static DateTime tomorrowMorning(DateTime now) => DateTime(now.year, now.month, now.day + 1, 8);

  static DateTime nextMondayMorning(DateTime now) {
    final days = (DateTime.monday - now.weekday) % 7;
    return DateTime(now.year, now.month, now.day + (days == 0 ? 7 : days), 8);
  }

  static DateTime nextWeekend(DateTime now) {
    final days = (DateTime.saturday - now.weekday) % 7;
    return DateTime(now.year, now.month, now.day + (days == 0 ? 7 : days), 9);
  }
}
