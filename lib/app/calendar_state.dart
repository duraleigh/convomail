import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/database.dart';
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

/// Calendars hidden in Précis's Planner (still kept in step).
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

/// The calendar new events go to, by the user's choice or the main one.
final defaultCalendarIdProvider = StreamProvider<String?>((ref) {
  final db = ref.watch(databaseProvider);
  final calendars = ref.watch(googleCalendarsProvider).value ?? const [];
  return _watchSetting(db, CalendarSync.defaultKey).map((chosen) {
    if (chosen != null && calendars.any((c) => c.id == chosen && c.writable)) return chosen;
    return calendars.where((c) => c.primary && c.writable).firstOrNull?.id ?? calendars.where((c) => c.writable).firstOrNull?.id;
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
