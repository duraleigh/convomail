import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/database.dart';
import '../store/planner_queries.dart';
import '../sync/calendar_sync.dart';

Stream<String?> _watchSetting(AppDatabase db, String key) => (db.select(db.settings)..where((s) => s.key.equals(key))).watchSingleOrNull().map((r) => r?.value);

/// The user's Google calendars, as last read from Google.
final googleCalendarsProvider = StreamProvider<List<GoogleCalendarInfo>>((ref) {
  final db = ref.watch(databaseProvider);
  return _watchSetting(db, CalendarSync.calendarsKey).map((raw) {
    if (raw == null || raw.isEmpty) return const <GoogleCalendarInfo>[];
    try {
      return [for (final j in jsonDecode(raw) as List<dynamic>) GoogleCalendarInfo.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      return const <GoogleCalendarInfo>[];
    }
  });
});

/// Calendars the user chose not to show on Today (still read).
final hiddenCalendarsProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return _watchSetting(db, CalendarSync.hiddenKey).map((raw) {
    if (raw == null || raw.isEmpty) return const <String>{};
    try {
      return {for (final x in jsonDecode(raw) as List<dynamic>) '$x'};
    } catch (_) {
      return const <String>{};
    }
  });
});

/// The last problem talking to Google Calendar, or null.
final calendarErrorProvider = StreamProvider<String?>((ref) => _watchSetting(ref.watch(databaseProvider), CalendarSync.errorKey).map((v) => v == null || v.isEmpty ? null : v));

/// When the calendar last synced.
final calendarLastSyncProvider = StreamProvider<DateTime?>((ref) => _watchSetting(ref.watch(databaseProvider), CalendarSync.lastSyncKey).map((v) => v == null ? null : DateTime.tryParse(v)));

/// A calendar's name, for the event detail.
final googleCalendarNameProvider = Provider.family<String?, String?>((ref, id) {
  if (id == null) return null;
  return (ref.watch(googleCalendarsProvider).value ?? const []).where((c) => c.id == id).firstOrNull?.name;
});

/// Events in [start, end), without those in calendars hidden here.
Stream<List<PlannerEvent>> watchShownEvents(Ref ref, DateTime start, DateTime end) {
  final hidden = ref.watch(hiddenCalendarsProvider).value ?? const <String>{};
  return ref.watch(databaseProvider).watchEventsBetween(start, end).map((list) => [for (final e in list) if (e.calendarId == null || !hidden.contains(e.calendarId)) e]);
}

/// Whether an all-day event covers [day] (Google's end date is the day after).
bool allDayCovers(PlannerEvent e, DateTime day) {
  final s = e.startAt!;
  final first = DateTime(s.year, s.month, s.day);
  final end = e.endAt;
  final after = end == null || !end.isAfter(first) ? first.add(const Duration(days: 1)) : DateTime(end.year, end.month, end.day);
  final d = DateTime(day.year, day.month, day.day);
  return !d.isBefore(first) && d.isBefore(after);
}
