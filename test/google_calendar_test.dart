import 'dart:convert';
import 'dart:typed_data';

import 'package:convomail/mail/google_oauth.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/sync/calendar_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_db.dart';

const _clientFile = '{"installed":{"client_id":"id-1","client_secret":"sec-1"}}';

/// Answers as Google Calendar would. Records what was asked and sent.
class FakeCalendar {
  final calls = <String>[];
  final sent = <String, Map<String, dynamic>>{};
  String granted = '${GoogleOAuth.contactsScope} ${GoogleOAuth.calendarScope}';
  bool apiOff = false;
  List<Map<String, dynamic>> calendars = [
    {'id': 'me@gmail.com', 'summary': 'me@gmail.com', 'backgroundColor': '#4986e7', 'selected': true, 'primary': true, 'accessRole': 'owner'},
    {'id': 'family', 'summary': 'Family', 'backgroundColor': '#16a765', 'selected': true, 'accessRole': 'writer'},
    {'id': 'holidays', 'summary': 'Holidays', 'backgroundColor': '#cd74e6', 'selected': true, 'accessRole': 'reader'},
    {'id': 'hidden-in-google', 'summary': 'Not shown', 'selected': false, 'accessRole': 'owner'},
  ];
  final events = <String, List<Map<String, dynamic>>>{};
  var nextId = 100;

  GoogleResponse _json(int status, Object body) => GoogleResponse(status, Uint8List.fromList(utf8.encode(jsonEncode(body))));

  Future<GoogleResponse> call(String method, Uri uri, {Map<String, String> headers = const {}, String? form, String? json}) async {
    if (uri.path == '/token') return _json(200, {'access_token': 'acc', 'refresh_token': 'ref', 'expires_in': 3600, 'scope': granted});
    calls.add('$method ${uri.path}');
    expect(headers['Authorization'], 'Bearer acc');
    if (apiOff) {
      return _json(403, {
        'error': {'code': 403, 'message': 'Google Calendar API has not been used in project 1 before or it is disabled.', 'errors': [{'reason': 'accessNotConfigured'}]},
      });
    }
    if (uri.path == '/calendar/v3/users/me/calendarList') return _json(200, {'items': calendars});
    final m = RegExp(r'^/calendar/v3/calendars/([^/]+)/events(?:/([^/]+))?$').firstMatch(uri.path);
    if (m != null) {
      final cal = Uri.decodeComponent(m.group(1)!);
      final id = m.group(2) == null ? null : Uri.decodeComponent(m.group(2)!);
      final list = events.putIfAbsent(cal, () => []);
      switch (method) {
        case 'GET':
          expect(uri.queryParameters['singleEvents'], 'true');
          return _json(200, {'items': list});
        case 'POST':
          final body = jsonDecode(json!) as Map<String, dynamic>;
          sent['POST $cal'] = body;
          final created = {...body, 'id': 'ev${nextId++}', 'status': 'confirmed'};
          list.add(created);
          return _json(200, created);
        case 'PATCH':
          final body = jsonDecode(json!) as Map<String, dynamic>;
          sent['PATCH $cal/$id'] = body;
          final i = list.indexWhere((e) => e['id'] == id);
          list[i] = {...list[i], ...body};
          return _json(200, list[i]);
        case 'DELETE':
          final before = list.length;
          list.removeWhere((e) => e['id'] == id);
          return before == list.length ? _json(410, {'error': {'code': 410, 'message': 'Resource has been deleted'}}) : GoogleResponse(204, Uint8List(0));
      }
    }
    return _json(404, {});
  }
}

void main() {
  late AppDatabase db;
  late InMemoryCredentialStore store;
  late FakeCalendar google;
  late GoogleOAuth oauth;
  late CalendarSync sync;
  final now = DateTime(2026, 11, 10, 8);

  setUp(() async {
    db = testDatabase();
    store = InMemoryCredentialStore();
    google = FakeCalendar();
    oauth = GoogleOAuth(store: store, http: google.call, openBrowser: (_) async {}, clock: () => now);
    await store.write(GoogleOAuth.clientKey, _clientFile);
    await store.write(GoogleOAuth.refreshKey, 'ref');
    sync = CalendarSync(db: db, oauth: oauth, clock: () => now);
    google.events['me@gmail.com'] = [
      {'id': 'a1', 'status': 'confirmed', 'summary': 'Dentist', 'location': 'Main St', 'description': '<b>Bring</b> card<br>Floss', 'start': {'dateTime': '2026-11-11T14:00:00Z'}, 'end': {'dateTime': '2026-11-11T15:00:00Z'}},
      {'id': 'a2', 'status': 'confirmed', 'summary': 'Vacation', 'start': {'date': '2026-11-20'}, 'end': {'date': '2026-11-23'}},
      {'id': 'a3', 'status': 'cancelled'},
    ];
    google.events['holidays'] = [
      {'id': 'h1', 'summary': 'Thanksgiving', 'start': {'date': '2026-11-26'}, 'end': {'date': '2026-11-27'}},
    ];
  });

  tearDown(() => db.close());

  Future<List<PlannerEvent>> stored() => db.select(db.plannerEvents).get();

  test('calendar access comes from what Google granted; without it nothing is asked', () async {
    google.granted = GoogleOAuth.contactsScope;
    expect(await oauth.hasCalendar, isFalse);
    await sync.syncNow();
    expect(google.calls, isEmpty);
    expect(await stored(), isEmpty);

    google.granted = '${GoogleOAuth.contactsScope} ${GoogleOAuth.calendarScope}';
    oauth.invalidateAccess();
    await oauth.accessToken();
    expect(await oauth.hasCalendar, isTrue);
  });

  test('the calendars shown in Google come in with their events and colours', () async {
    await sync.syncNow();
    final calendars = await sync.savedCalendars();
    expect(calendars.map((c) => c.name), ['me@gmail.com', 'Family', 'Holidays'], reason: 'main first; not-shown calendars left out');
    expect(calendars.first.primary, isTrue);
    expect(calendars.last.writable, isFalse);

    final events = await stored();
    expect(events.map((e) => e.title).toSet(), {'Dentist', 'Vacation', 'Thanksgiving'}, reason: 'cancelled occurrences are left out');
    final dentist = events.firstWhere((e) => e.title == 'Dentist');
    expect(dentist.kind, 'google');
    expect(dentist.startAt, DateTime.utc(2026, 11, 11, 14).toLocal());
    expect(dentist.color, 0xFF4986E7);
    expect(dentist.notes, 'Bring card\nFloss');
    expect(dentist.location, 'Main St');
    final vacation = events.firstWhere((e) => e.title == 'Vacation');
    expect(vacation.allDay, isTrue);
    expect(vacation.startAt, DateTime(2026, 11, 20));
    expect(vacation.endAt, DateTime(2026, 11, 23));
  });

  test('a sync makes the Planner match: changes, deletions and calendars no longer shown', () async {
    await sync.syncNow();
    google.events['me@gmail.com']!.removeWhere((e) => e['id'] == 'a2');
    google.events['me@gmail.com']!.first['summary'] = 'Dentist (moved)';
    google.calendars.removeWhere((c) => c['id'] == 'holidays');
    await sync.syncNow();
    expect((await stored()).map((e) => e.title).toSet(), {'Dentist (moved)'});
  });

  test('the Calendar API turned off is said plainly, and kept for Settings', () async {
    google.apiOff = true;
    await expectLater(sync.syncNow(), throwsA(isA<CalendarException>().having((e) => e.apiOff, 'apiOff', isTrue)));
    expect(await db.getSetting(CalendarSync.errorKey), contains('Google Calendar API is turned off'));
    google.apiOff = false;
    await sync.syncNow();
    expect(await db.getSetting(CalendarSync.errorKey), isEmpty);
  });

  test('a week far from today is read when shown; nearby weeks need no extra call', () async {
    await sync.syncNow();
    google.calls.clear();
    await sync.ensureRange(DateTime(2026, 11, 16), DateTime(2026, 11, 23));
    expect(google.calls, isEmpty);
    await sync.ensureRange(DateTime(2028, 3, 6), DateTime(2028, 3, 13));
    expect(google.calls.where((c) => c.startsWith('GET /calendar/v3/calendars/')), hasLength(3));
  });

  test('hiding a calendar here is kept', () async {
    await sync.syncNow();
    await sync.setHidden('holidays', true);
    expect(await sync.hiddenCalendars(), {'holidays'});
    await sync.setHidden('holidays', false);
    expect(await sync.hiddenCalendars(), isEmpty);
  });

  test('only reading is asked of Google', () {
    expect(GoogleOAuth.calendarScope, endsWith('calendar.readonly'));
  });
}
