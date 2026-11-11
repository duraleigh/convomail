import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_log.dart';
import '../mail/google_oauth.dart';
import '../store/database.dart';
import 'contacts_sync.dart';

/// One of the user's Google calendars.
class GoogleCalendarInfo {
  const GoogleCalendarInfo({required this.id, required this.name, required this.color, required this.writable, this.primary = false});
  final String id;
  final String name;

  /// ARGB.
  final int color;

  /// The user can add and change events in it.
  final bool writable;
  final bool primary;

  Map<String, Object> toJson() => {'id': id, 'name': name, 'color': color, 'writable': writable, 'primary': primary};
  static GoogleCalendarInfo fromJson(Map<String, dynamic> j) =>
      GoogleCalendarInfo(id: '${j['id']}', name: '${j['name']}', color: (j['color'] as num?)?.toInt() ?? 0xFF4285F4, writable: j['writable'] == true, primary: j['primary'] == true);
}

/// An event as entered in the Planner, to send to Google.
class CalendarEventDraft {
  const CalendarEventDraft({required this.title, required this.start, this.end, this.allDay = false, this.location, this.notes = ''});
  final String title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String? location;
  final String notes;
}

/// Something Google said no to, in words for the Settings page.
class CalendarException implements Exception {
  const CalendarException(this.message, {this.apiOff = false, this.needsReconnect = false});
  final String message;

  /// The Google Calendar API is not turned on in the user's Google Cloud
  /// project.
  final bool apiOff;
  final bool needsReconnect;

  @override
  String toString() => message;
}

final calendarSyncProvider = Provider<CalendarSync>((ref) {
  final sync = CalendarSync(db: ref.read(databaseProvider), oauth: ref.read(googleOAuthProvider));
  ref.onDispose(sync.stop);
  return sync;
});

/// Keeps the Planner in step with the user's Google Calendar, both ways
/// (spec 4.10). Every calendar the user shows in Google is read, for a span
/// around today and any week the Planner is moved to; events added, changed
/// or deleted in the Planner are sent to Google first and stored as Google
/// returns them. Repeating events come in as their single occurrences, and a
/// change made here applies to that occurrence only.
class CalendarSync {
  CalendarSync({required this.db, required this.oauth, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final GoogleOAuth oauth;
  final DateTime Function() _clock;

  static const calendarsKey = 'google.calendar.list';
  static const hiddenKey = 'google.calendar.hidden';
  static const defaultKey = 'google.calendar.default';
  static const lastSyncKey = 'google.calendar.lastSync';
  static const errorKey = 'google.calendar.error';
  static const interval = Duration(minutes: 10);
  static const back = Duration(days: 60);
  static const ahead = Duration(days: 400);

  static const _api = 'www.googleapis.com';
  static const _base = '/calendar/v3';

  Timer? _timer;
  Future<void>? _running;

  /// The span read on every sync; weeks outside it are read when shown.
  (DateTime, DateTime) get window {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    return (today.subtract(back), today.add(ahead));
  }

  void start() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(_quiet(syncNow)));
    unawaited(_quiet(syncNow));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _quiet(Future<void> Function() work) async {
    try {
      await work();
    } catch (e) {
      AppLog.current?.warn('Google Calendar sync failed', AppLog.scrub(e));
    }
  }

  /// Whether calendar sync can run: connected, with calendar permission.
  Future<bool> get ready async => await oauth.isConnected && await oauth.hasCalendar;

  /// One sync of the usual span. Only one runs at a time.
  Future<void> syncNow() => _running ??= _sync().whenComplete(() => _running = null);

  /// Reads one week (or any span) the Planner is showing, when it lies
  /// outside the usual span.
  Future<void> ensureRange(DateTime from, DateTime to) async {
    final (lo, hi) = window;
    if (!from.isBefore(lo) && !to.isAfter(hi)) return;
    if (!await ready) return;
    final calendars = await savedCalendars();
    for (final c in calendars) {
      await _readEvents(c, from, to);
    }
  }

  Future<void> _sync() async {
    if (!await ready) return;
    try {
      final calendars = await _readCalendars();
      final (from, to) = window;
      for (final c in calendars) {
        await _readEvents(c, from, to);
      }
      // Calendars no longer shown in Google leave the Planner.
      final ids = [for (final c in calendars) c.id];
      await (db.delete(db.plannerEvents)..where((e) => ids.isEmpty ? e.kind.equals('google') : e.kind.equals('google') & e.calendarId.isNotIn(ids))).go();
      await db.putSetting(lastSyncKey, _clock().toIso8601String());
      await db.putSetting(errorKey, '');
    } on CalendarException catch (e) {
      await db.putSetting(errorKey, e.message);
      rethrow;
    }
  }

  // ---- calendars -------------------------------------------------------------

  Future<List<GoogleCalendarInfo>> savedCalendars() async {
    final raw = await db.getSetting(calendarsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [for (final j in jsonDecode(raw) as List<dynamic>) GoogleCalendarInfo.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  /// The calendars the user shows in Google (ticked in Google Calendar's
  /// list), each with its colour. Kept for the Settings page and the editor.
  Future<List<GoogleCalendarInfo>> _readCalendars() async {
    final out = <GoogleCalendarInfo>[];
    String? page;
    do {
      final body = await _call('GET', Uri.https(_api, '$_base/users/me/calendarList', {'minAccessRole': 'reader', 'maxResults': '250', 'pageToken': ?page}));
      for (final c in (body['items'] as List<dynamic>?) ?? const []) {
        final m = c as Map<String, dynamic>;
        if (m['selected'] != true || m['deleted'] == true) continue;
        out.add(GoogleCalendarInfo(
          id: '${m['id']}',
          name: '${m['summaryOverride'] ?? m['summary'] ?? m['id']}',
          color: _hexColor(m['backgroundColor'] as String?) ?? 0xFF4285F4,
          writable: m['accessRole'] == 'owner' || m['accessRole'] == 'writer',
          primary: m['primary'] == true,
        ));
      }
      page = body['nextPageToken'] as String?;
    } while (page != null);
    out.sort((a, b) => a.primary != b.primary ? (a.primary ? -1 : 1) : a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await db.putSetting(calendarsKey, jsonEncode([for (final c in out) c.toJson()]));
    return out;
  }

  static int? _hexColor(String? hex) {
    if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
  }

  /// Calendars hidden in Précis (still synced, not shown).
  Future<Set<String>> hiddenCalendars() async {
    final raw = await db.getSetting(hiddenKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return {for (final x in jsonDecode(raw) as List<dynamic>) '$x'};
    } catch (_) {
      return {};
    }
  }

  Future<void> setHidden(String calendarId, bool hidden) async {
    final set = await hiddenCalendars();
    hidden ? set.add(calendarId) : set.remove(calendarId);
    await db.putSetting(hiddenKey, jsonEncode(set.toList()));
  }

  /// Where new events go: the user's choice, else the main calendar.
  Future<String?> defaultCalendarId() async {
    final calendars = await savedCalendars();
    final chosen = await db.getSetting(defaultKey);
    if (chosen != null && calendars.any((c) => c.id == chosen && c.writable)) return chosen;
    return calendars.where((c) => c.primary && c.writable).firstOrNull?.id ?? calendars.where((c) => c.writable).firstOrNull?.id;
  }

  Future<void> setDefaultCalendar(String calendarId) => db.putSetting(defaultKey, calendarId);

  // ---- events: reading -------------------------------------------------------

  /// Reads [calendar]'s events in [from, to) and makes the stored ones match.
  Future<void> _readEvents(GoogleCalendarInfo calendar, DateTime from, DateTime to) async {
    final found = <PlannerEventsCompanion>[];
    String? page;
    do {
      final body = await _call(
        'GET',
        Uri.https(_api, '$_base/calendars/${calendar.id}/events', {
          'timeMin': from.toUtc().toIso8601String(),
          'timeMax': to.toUtc().toIso8601String(),
          'singleEvents': 'true',
          'showDeleted': 'false',
          'maxResults': '2500',
          'pageToken': ?page,
        }),
      );
      for (final e in (body['items'] as List<dynamic>?) ?? const []) {
        final row = eventRow(e as Map<String, dynamic>, calendar);
        if (row != null) found.add(row);
      }
      page = body['nextPageToken'] as String?;
    } while (page != null);

    await db.transaction(() async {
      final stored = await (db.select(db.plannerEvents)
            ..where((e) => e.kind.equals('google') & e.calendarId.equals(calendar.id) & e.startAt.isSmallerThanValue(to) & (e.endAt.isBiggerThanValue(from) | (e.endAt.isNull() & e.startAt.isBiggerOrEqualValue(from)))))
          .get();
      final byUid = {for (final e in stored) e.uid: e};
      final seen = <String>{};
      for (final row in found) {
        final uid = row.uid.value!;
        seen.add(uid);
        final cur = byUid[uid] ?? await (db.select(db.plannerEvents)..where((e) => e.kind.equals('google') & e.calendarId.equals(calendar.id) & e.uid.equals(uid))).getSingleOrNull();
        if (cur == null) {
          await db.into(db.plannerEvents).insert(row);
        } else {
          await (db.update(db.plannerEvents)..where((e) => e.id.equals(cur.id))).write(row);
        }
      }
      // Deleted or moved out of this span in Google.
      for (final e in stored) {
        if (!seen.contains(e.uid)) await (db.delete(db.plannerEvents)..where((x) => x.id.equals(e.id))).go();
      }
    });
  }

  /// A stored row for a Google event, or null for one that is cancelled.
  static PlannerEventsCompanion? eventRow(Map<String, dynamic> e, GoogleCalendarInfo calendar) {
    if (e['status'] == 'cancelled') return null;
    final id = e['id'] as String?;
    final start = e['start'] as Map<String, dynamic>?;
    final end = e['end'] as Map<String, dynamic>?;
    if (id == null || start == null) return null;
    final allDay = start['date'] != null;
    DateTime? when(Map<String, dynamic>? m) {
      if (m == null) return null;
      if (m['date'] is String) {
        final d = DateTime.tryParse(m['date'] as String);
        return d == null ? null : DateTime(d.year, d.month, d.day);
      }
      return m['dateTime'] is String ? DateTime.tryParse(m['dateTime'] as String)?.toLocal() : null;
    }

    final s = when(start);
    if (s == null) return null;
    final title = (e['summary'] as String?)?.trim();
    return PlannerEventsCompanion.insert(
      title: title == null || title.isEmpty ? '(No title)' : title,
      startAt: Value(s),
      endAt: Value(when(end)),
      allDay: Value(allDay),
      kind: 'google',
      uid: Value(id),
      calendarId: Value(calendar.id),
      color: Value(calendar.color),
      location: Value((e['location'] as String?)?.trim()),
      notes: Value(_plain((e['description'] as String?) ?? '')),
    );
  }

  /// Google descriptions can carry HTML; the Planner shows text.
  static String _plain(String s) => s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();

  // ---- events: writing -------------------------------------------------------

  /// Adds an event to [calendarId] in Google, then stores it. Returns its
  /// id here.
  Future<int> create(String calendarId, CalendarEventDraft draft) async {
    final calendar = await _calendar(calendarId);
    final body = await _call('POST', Uri.https(_api, '$_base/calendars/$calendarId/events'), json: eventBody(draft));
    return _store(body, calendar);
  }

  /// Changes a Google event (that occurrence, for a repeating one), then
  /// stores what Google returns.
  Future<void> update(PlannerEvent event, CalendarEventDraft draft) async {
    final calendar = await _calendar(event.calendarId!);
    final body = await _call('PATCH', Uri.https(_api, '$_base/calendars/${calendar.id}/events/${event.uid!}'), json: eventBody(draft));
    await _store(body, calendar);
  }

  /// Deletes a Google event (that occurrence, for a repeating one) in Google
  /// and here.
  Future<void> delete(PlannerEvent event) async {
    try {
      await _call('DELETE', Uri.https(_api, '$_base/calendars/${event.calendarId!}/events/${event.uid!}'));
    } on CalendarException catch (e) {
      // Already gone in Google: remove it here too.
      if (!e.message.contains('(410)') && !e.message.contains('(404)')) rethrow;
    }
    await (db.delete(db.plannerEvents)..where((e) => e.id.equals(event.id))).go();
  }

  Future<GoogleCalendarInfo> _calendar(String id) async {
    final found = (await savedCalendars()).where((c) => c.id == id).firstOrNull;
    return found ?? GoogleCalendarInfo(id: id, name: id, color: 0xFF4285F4, writable: true);
  }

  Future<int> _store(Map<String, dynamic> body, GoogleCalendarInfo calendar) async {
    final row = eventRow(body, calendar);
    if (row == null) throw const CalendarException('Google did not return the event.');
    final uid = row.uid.value!;
    final cur = await (db.select(db.plannerEvents)..where((e) => e.kind.equals('google') & e.calendarId.equals(calendar.id) & e.uid.equals(uid))).getSingleOrNull();
    if (cur == null) return db.into(db.plannerEvents).insert(row);
    await (db.update(db.plannerEvents)..where((e) => e.id.equals(cur.id))).write(row);
    return cur.id;
  }

  /// The JSON Google expects. All-day events end the day after their last
  /// day; timed ones are sent in UTC.
  static String eventBody(CalendarEventDraft d) {
    String day(DateTime t) => '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final Map<String, Object> start;
    final Map<String, Object> end;
    if (d.allDay) {
      final first = DateTime(d.start.year, d.start.month, d.start.day);
      final last = d.end == null ? first : DateTime(d.end!.year, d.end!.month, d.end!.day);
      final after = last.isAfter(first) ? last : first.add(const Duration(days: 1));
      start = {'date': day(first)};
      end = {'date': day(after)};
    } else {
      start = {'dateTime': d.start.toUtc().toIso8601String()};
      end = {'dateTime': (d.end ?? d.start.add(const Duration(hours: 1))).toUtc().toIso8601String()};
    }
    return jsonEncode({
      'summary': d.title.trim().isEmpty ? 'Event' : d.title.trim(),
      'start': start,
      'end': end,
      'location': d.location?.trim() ?? '',
      'description': d.notes,
    });
  }

  // ---- HTTP --------------------------------------------------------------------

  Future<Map<String, dynamic>> _call(String method, Uri uri, {String? json}) async {
    Future<GoogleResponse> send() async => oauth.http(method, uri, headers: {'Authorization': 'Bearer ${await oauth.accessToken()}'}, json: json);
    GoogleResponse response;
    try {
      response = await send();
      if (response.status == 401) {
        oauth.invalidateAccess();
        response = await send();
      }
    } on GoogleAuthException catch (e) {
      throw CalendarException(e.message, needsReconnect: e.needsReconnect);
    }
    if (response.status == 204 || (response.status == 200 && response.bytes.isEmpty)) return const {};
    Map<String, dynamic> body;
    try {
      final o = jsonDecode(response.text);
      body = o is Map<String, dynamic> ? o : const {};
    } catch (_) {
      body = const {};
    }
    if (response.status >= 200 && response.status < 300) return body;
    final error = body['error'] is Map ? body['error'] as Map : const <String, Object>{};
    final reasons = [for (final e in (error['errors'] as List<dynamic>?) ?? const []) if (e is Map) '${e['reason']}'];
    final message = '${error['message'] ?? ''}';
    if (reasons.contains('accessNotConfigured') || message.contains('has not been used in project') || message.contains('is disabled')) {
      throw const CalendarException('The Google Calendar API is turned off in your Google Cloud project. Turn it on there (see the steps below), then press Sync now.', apiOff: true);
    }
    if (response.status == 403 && (reasons.contains('insufficientPermissions') || message.contains('insufficient'))) {
      throw const CalendarException('Précis does not have permission for your calendar yet. Press Allow calendar access.', needsReconnect: true);
    }
    throw CalendarException('Google Calendar answered ${message.isEmpty ? '' : '"$message" '}(${response.status}).');
  }
}
