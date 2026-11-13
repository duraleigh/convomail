import 'dart:convert';

import 'package:convomail/domain/trip_cards.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/ui/screens/trip_cards.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rules of the Travel and Bookings cards, with no screen: when a leg
/// shows, what heading it sits under, when it leaves.
void main() {
  int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  /// A leg leaving at [dep] (real time) and landing [hours] later.
  TripLeg leg(DateTime dep, {double hours = 2, String state = 'confirmed', DateTime? news, String key = 'AA1|d|RDU|LGA'}) {
    final arr = dep.add(Duration(minutes: (hours * 60).round()));
    return TripLeg.fromData(
      key,
      jsonEncode({
        'mode': 'flight', 'carrier': 'American Airlines', 'number': 'AA4704', 'fc': 'RDU', 'fcity': 'Raleigh/Durham', 'tc': 'LGA', 'tcity': 'New York LaGuardia',
        'dep': '2026-11-16T19:57', 'arr': '2026-11-16T22:00', 'dep_at': secs(dep), 'arr_at': secs(arr), 'loc': 'HEYLVT', 'state': state,
        'news_at': news == null ? 0 : secs(news), 'was_dep': state == 'delayed' ? '2026-11-16T18:30' : '', 'was_arr': '', 'checkin': '', 'mid': '<a@x>', 'missing': <String>[],
      }),
    )!;
  }

  final now = DateTime(2026, 11, 12, 12);

  group('a travel leg', () {
    test('reads what the helper keeps', () {
      final l = leg(now.add(const Duration(days: 4)));
      expect([l.carrier, l.number, l.fromCode, l.fromCity, l.toCode, l.toCity, l.locator, l.messageId], ['American Airlines', 'AA4704', 'RDU', 'Raleigh/Durham', 'LGA', 'New York LaGuardia', 'HEYLVT', '<a@x>']);
      expect([l.departs!.hour, l.departs!.minute, l.arrives!.hour, l.arrives!.minute], [19, 57, 22, 0]);
      expect(l.route, 'Raleigh/Durham to New York LaGuardia');
      expect(l.duration, const Duration(hours: 2));
      expect(TripLeg.fromData('k', 'not json'), isNull);
    });

    test('shows for a day after it is booked, under "Confirmed", then goes until five days before it leaves', () {
      final dep = now.add(const Duration(days: 30));
      final l = leg(dep, news: now.subtract(const Duration(hours: 2)));
      expect(l.showsAt(now), isTrue);
      expect(l.headingAt(now), 'Confirmed');
      expect(l.showsAt(now.add(const Duration(hours: 21, minutes: 59))), isTrue);
      expect(l.showsAt(now.add(const Duration(hours: 22, minutes: 1))), isFalse, reason: '24 hours after the booking email');
      // Five days before it leaves it comes back, whether or not any other email came.
      expect(l.showsAt(dep.subtract(const Duration(days: 5, minutes: 1))), isFalse);
      expect(l.showsAt(dep.subtract(const Duration(days: 5))), isTrue);
      expect(l.headingAt(dep.subtract(const Duration(days: 5))), 'Upcoming');
    });

    test('a confirmed change is news for a day too, under "Changed"', () {
      final l = leg(now.add(const Duration(days: 30)), state: 'changed', news: now.subtract(const Duration(hours: 1)));
      expect(l.showsAt(now), isTrue);
      expect(l.headingAt(now), 'Changed');
    });

    test('leaves the card at its arrival, not before', () {
      final dep = now.add(const Duration(hours: 1));
      final l = leg(dep, hours: 3.5);
      expect(l.headingAt(now), 'Upcoming');
      expect(l.showsAt(dep.add(const Duration(hours: 3, minutes: 29))), isTrue, reason: 'still in the air');
      expect(l.showsAt(dep.add(const Duration(hours: 3, minutes: 30))), isFalse, reason: 'landed');
    });

    test('checked in, delayed and cancelled say so; a delay or a cancellation shows however far off it is', () {
      final soon = now.add(const Duration(days: 1));
      expect(leg(soon, state: 'checked').headingAt(now), 'Checked in');
      expect(leg(soon, state: 'checkin').headingAt(now), 'Upcoming', reason: 'invited to check in: still upcoming, with the link');
      final far = now.add(const Duration(days: 40));
      expect(leg(far, state: 'delayed').showsAt(now), isTrue);
      // Drawn large from two days before it leaves; at once for a delay or a cancellation. A compact pass until then.
      expect(leg(far).closeAt(now), isFalse);
      expect(leg(far).closeAt(far.subtract(const Duration(hours: 48, minutes: 1))), isFalse);
      expect(leg(far).closeAt(far.subtract(const Duration(hours: 48))), isTrue);
      expect([leg(far, state: 'delayed').closeAt(now), leg(far, state: 'cancelled').closeAt(now)], [true, true]);
      expect(leg(far, state: 'delayed').headingAt(now), 'Delayed');
      expect(leg(far, state: 'cancelled').headingAt(now), 'Cancelled');
      expect(leg(far, state: 'cancelled').showsAt(far.add(const Duration(hours: 3))), isFalse, reason: 'gone once its time has passed');
    });
  });

  group('the Travel card', () {
    HelperCard row(TripLeg l, String data) => HelperCard(k: 'leg:${l.key}', kind: 'leg', data: data, dismissed: false, messageId: '', updatedAt: now);
    String data(DateTime dep, {String state = 'confirmed', DateTime? news}) => jsonEncode({'number': 'AA1', 'fc': 'RDU', 'tc': 'LGA', 'dep': '2026-11-16T19:57', 'dep_at': secs(dep), 'arr_at': secs(dep.add(const Duration(hours: 2))), 'state': state, 'news_at': news == null ? 0 : secs(news)});

    test('every leg that fits the rules shows: what leaves soonest first, then what was just booked', () {
      HelperCard card(String key, String d) => HelperCard(k: 'leg:$key', kind: 'leg', data: d, dismissed: false, messageId: '', updatedAt: now);
      final cards = [
        card('booked', data(now.add(const Duration(days: 60)), news: now.subtract(const Duration(hours: 3)))),
        card('thursday', data(now.add(const Duration(days: 4)))),
        card('tomorrow', data(now.add(const Duration(days: 1)), state: 'checked')),
        card('far', data(now.add(const Duration(days: 20)))),
        card('landed', data(now.subtract(const Duration(hours: 5)))),
        HelperCard(k: 'booking:x', kind: 'booking', data: '{}', dismissed: false, messageId: '', updatedAt: now),
      ];
      expect([for (final l in travelNow(cards, now)) l.key], ['leg:tomorrow', 'leg:thursday', 'leg:booked']);
      expect(row(leg(now), '{}').kind, 'leg');
    });
  });

  group('a booking', () {
    Booking hotel({required DateTime start, DateTime? news, String state = 'confirmed'}) => Booking.fromData(
          'booking:hotel|1',
          jsonEncode({
            'type': 'hotel', 'name': 'The Joule', 'starts': '2026-11-20T15:00', 'ends': '2026-11-22T11:00', 'start_at': secs(start), 'end_at': secs(start.add(const Duration(days: 2))),
            'place': 'Dallas', 'address': '1530 Main St', 'conf': '88412207', 'phone': '214-555-0100', 'state': state, 'news_at': news == null ? 0 : secs(news), 'mid': '<h@x>',
          }),
        )!;

    test('follows the same rule as travel: a day after it is booked, then from five days before, until it is over', () {
      final start = now.add(const Duration(days: 20));
      final b = hotel(start: start, news: now.subtract(const Duration(hours: 1)));
      expect([b.typeName, b.name, b.place, b.address, b.conf, b.phone], ['Hotel', 'The Joule', 'Dallas', '1530 Main St', '88412207', '214-555-0100']);
      expect(b.showsAt(now), isTrue);
      expect(b.headingAt(now), 'Confirmed');
      expect(b.showsAt(now.add(const Duration(days: 2))), isFalse);
      expect(b.showsAt(start.subtract(const Duration(days: 5))), isTrue);
      expect(b.headingAt(start.subtract(const Duration(days: 5))), 'Upcoming');
      expect(b.showsAt(start.add(const Duration(days: 1))), isTrue, reason: 'during the stay');
      expect(b.showsAt(start.add(const Duration(days: 2))), isFalse, reason: 'after check-out');
    });

    test('one dismissed or put off is not on the card; the rest are soonest first', () {
      String d(DateTime start) => jsonEncode({'type': 'restaurant', 'name': 'x', 'start_at': secs(start), 'starts': '2026-11-13T19:30'});
      final cards = [
        HelperCard(k: 'booking:later', kind: 'booking', data: d(now.add(const Duration(days: 3))), dismissed: false, messageId: '', updatedAt: now),
        HelperCard(k: 'booking:soon', kind: 'booking', data: d(now.add(const Duration(days: 1))), dismissed: false, messageId: '', updatedAt: now),
        HelperCard(k: 'booking:off', kind: 'booking', data: d(now.add(const Duration(days: 1))), dismissed: true, messageId: '', updatedAt: now),
        HelperCard(k: 'booking:put-off', kind: 'booking', data: d(now.add(const Duration(days: 1))), dismissed: false, laterUntil: now.add(const Duration(hours: 5)), messageId: '', updatedAt: now),
      ];
      expect([for (final (c, _) in bookingsNow(cards, now)) c.k], ['booking:soon', 'booking:later']);
      expect([for (final (c, _) in bookingsNow(cards, now.add(const Duration(hours: 6)))) c.k], contains('booking:put-off'));
    });
  });
}
