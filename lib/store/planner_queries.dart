import 'package:drift/drift.dart';

import 'database.dart';
import 'people_queries.dart';

/// Calendar events read from Google (for Today's Schedule), reminders, and
/// the bookkeeping for Later (snooze).
extension PlannerQueries on AppDatabase {
  // ---- events ----------------------------------------------------------------

  /// Timed and all-day calendar events overlapping [start, end).
  Stream<List<PlannerEvent>> watchEventsBetween(DateTime start, DateTime end) => (select(plannerEvents)
        ..where((e) => e.kind.equals('todo').not() & e.dismissed.equals(false) & e.startAt.isSmallerThanValue(end) & (e.endAt.isBiggerThanValue(start) | (e.endAt.isNull() & e.startAt.isBiggerOrEqualValue(start))))
        ..orderBy([(e) => OrderingTerm.asc(e.startAt)]))
      .watch();

  Future<PlannerEvent?> eventById(int id) => (select(plannerEvents)..where((e) => e.id.equals(id))).getSingleOrNull();

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
