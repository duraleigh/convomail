import 'package:convomail/domain/timely_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures are written here, not taken from real mail. The false-positive
/// list matters as much as the rest: a code on the strip that is really an
/// order number is worse than no code.
void main() {
  const x = TimelyExtractor();
  final received = DateTime(2026, 11, 2, 9, 30);

  List<TimelyFact> read(String subject, {String text = '', String html = '', String fromName = 'Sender', String fromAddress = 'no-reply@sender.example'}) =>
      x.extract(TimelyInput(messageKey: 'k', received: received, subject: subject, text: text, html: html, fromName: fromName, fromAddress: fromAddress));

  String? code(String subject, {String text = ''}) => read(subject, text: text).where((f) => f.type == TimelyType.code).firstOrNull?.code;

  group('confirm your email address', () {
    const button = '<p>Thanks for signing up.</p><a href="https://acme.example/help">Help</a> <a href="https://acme.example/confirm?t=abc123">Confirm my email</a>';

    test('an email that asks you to press a button to confirm your address gives the button\'s own link', () {
      final f = read('Please confirm your email address', text: 'Press the button to confirm your email address.', html: button, fromName: 'Acme').single;
      expect(f.type, TimelyType.confirm);
      expect(f.actionUrl, 'https://acme.example/confirm?t=abc123');
      expect(f.title, 'Acme');
      final w = TimelyWindow.of(f, received);
      expect(w.from, received);
      expect(w.until, received.add(const Duration(hours: 24)));
    });

    test('"verify your account" counts too', () {
      expect(read('One more step', text: 'Verify your account to get started.', html: '<a href="https://x.example/v/1">Verify account</a>').single.type, TimelyType.confirm);
    });

    test('an email with a code in it is a code, not a button to press', () {
      final facts = read('Verify your email', text: 'Your code is A7K2QX', html: button);
      expect(facts.map((f) => f.type), [TimelyType.code]);
    });

    test('no button, no card; and other mail that says "confirm" is left alone', () {
      expect(read('Please confirm your email address', text: 'Reply to this email to confirm your email address.'), isEmpty);
      expect(read('Your order is confirmed', text: 'We will confirm the delivery date soon.', html: button), isEmpty);
    });
  });

  group('one-time codes', () {
    final cases = <(String, String, String)>[
      ('Your verification code is 482913', '', '482913'),
      ('Your verification code', 'Your verification code is 112233. It expires in 10 minutes.', '112233'),
      ('Sign in to Acme', 'Use this code to sign in: 845-221', '845-221'),
      ('Security code', 'Your security code: 7741', '7741'),
      ('Your login code', 'Enter this code to log in:\n\n   905 113\n\nThanks', '905 113'),
      ('Verify your email', 'Your code is A7K2QX', 'A7K2QX'),
      ('Google Verification Code', 'G-123456 is your Google verification code.', 'G-123456'),
      ('One-time passcode', '334455 is your one-time passcode', '334455'),
      ('Your one time password', 'OTP: 990011', '990011'),
      ('Two-factor authentication', 'Your 2FA code is 5522', '5522'),
    ];
    for (final (subject, text, want) in cases) {
      test('finds the code in "$subject"', () => expect(code(subject, text: text)?.replaceAll(' ', ''), want.replaceAll(' ', '')));
    }

    final notCodes = <(String, String)>[
      ('Your order #4823-1192 has shipped', 'Thanks for your order 482913.'),
      ('Use promo code SAVE20 today', 'Your code is SAVE20 for 20% off.'),
      ('Flight confirmation', 'Your confirmation code is ABC123. Flight DL 123.'),
      ('Invoice 88213 from Vendor', 'Amount due: \$120.00. Invoice number 88213.'),
      ('New sign-in to your account', 'We noticed a new sign-in on Windows. If this was you, ignore this.'),
      ('Happy 2026 from all of us', 'See what 2026 has in store. Call 919-555-1212.'),
      ('Reset your password', 'Click the link below to choose a new password.'),
      ('Security alert', 'Your password was changed on Monday.'),
      ('Your QR code is ready', 'Download your QR code.'),
      ('Weekly digest', 'Top code examples from your team this week.'),
    ];
    for (final (subject, text) in notCodes) {
      test('no code in "$subject"', () => expect(code(subject, text: text), isNull));
    }

    test('a code shows at once and is gone 15 minutes later', () {
      final f = read('Your verification code is 482913').single;
      final w = TimelyWindow.of(f, received);
      expect(w.from, received);
      expect(w.until, received.add(const Duration(minutes: 15)));
    });
  });

  group('deliveries', () {
    test('a valid UPS number gives the carrier page, and the date is read', () {
      final f = read('Your order has shipped', text: 'Tracking number 1Z999AA10123456784. Arriving Thursday, Nov 5.').single;
      expect(f.type, TimelyType.delivery);
      expect(f.dedupeKey, 'parcel:1Z999AA10123456784');
      expect(f.actionUrl, 'https://www.ups.com/track?tracknum=1Z999AA10123456784');
      expect(f.startsAt, DateTime(2026, 11, 5));
      expect(f.detail, 'UPS');
    });

    test('a UPS-shaped number with a bad check digit is not a tracking number', () {
      expect(read('Monthly report', text: 'Reference 1Z999AA10123456780.'), isEmpty);
    });

    test('out for delivery and delivered are statuses, and later mail shares the key', () {
      final out = read('Your package is out for delivery', text: 'Tracking number 1Z999AA10123456784').single;
      expect(out.status, 'out-for-delivery');
      final done = read('Your package was delivered', text: 'Tracking number 1Z999AA10123456784').single;
      expect(done.status, 'delivered');
      expect(done.dedupeKey, out.dedupeKey);
      // Delivered: it stays on its card, marked so, until the end of that day.
      final w = TimelyWindow.of(done, received);
      expect(w.from, received);
      expect(w.until, DateTime(received.year, received.month, received.day + 1));
    });

    test('an email "track" link is used when there is no number', () {
      final f = read('Your order is on its way', html: '<a href="https://shop.example/t/abc">Track your package</a>', text: 'Arrives tomorrow').single;
      expect(f.actionUrl, 'https://shop.example/t/abc');
      expect(f.startsAt, DateTime(2026, 11, 3));
    });

    test('shows two days ahead, and through the arrival date', () {
      final f = read('Your order has shipped', text: 'Arriving Nov 10').single;
      final w = TimelyWindow.of(f, received);
      expect(w.from, DateTime(2026, 11, 8));
      expect(w.until, DateTime(2026, 11, 11));
    });

    test('marketing about shipping is not a delivery', () {
      expect(read('Free shipping this weekend only!'), isEmpty);
      expect(read('Sale: 30% off and free shipping', text: 'Delivered to your door'), isEmpty);
    });
  });

  group('travel', () {
    test('a flight confirmation without markup', () {
      final f = read('Your flight confirmation', fromName: 'Delta', text: 'Confirmation GX7H2K\nFlight DL 1234 RDU to LGA\nThu, Nov 5, 2026 at 7:05 AM').single;
      expect(f.type, TimelyType.flight);
      expect(f.title, 'Flight DL 1234 · RDU to LGA');
      expect(f.detail, 'Confirmation GX7H2K');
      expect(f.startsAt, DateTime(2026, 11, 5, 7, 5));
      expect(TimelyWindow.of(f, received).from, DateTime(2026, 11, 3, 7, 5));
    });

    test('no readable date, no flight: it never guesses', () {
      expect(read('Your flight confirmation', text: 'Flight DL 1234 RDU to LGA').where((f) => f.type == TimelyType.flight), isEmpty);
    });

    test('fare marketing is not a trip', () {
      expect(read('Flights from \$49: fare sale', text: 'Flight DL 1234 on Nov 5').where((f) => f.type == TimelyType.flight), isEmpty);
    });

    test('a train', () {
      final f = read('Your Amtrak trip', fromName: 'Amtrak', text: 'Train 88 departs Nov 6, 2026 at 11:15 AM').single;
      expect(f.type, TimelyType.train);
      expect(f.title, 'Train 88');
      expect(f.startsAt, DateTime(2026, 11, 6, 11, 15));
    });

    test('a hotel', () {
      final f = read('Your hotel reservation is confirmed', fromName: 'Marriott', text: 'Check-in: Nov 7, 2026\nCheckout: Nov 9, 2026').single;
      expect(f.type, TimelyType.hotel);
      expect(f.startsAt, DateTime(2026, 11, 7));
    });
  });

  group('bills', () {
    test('a due date and amount', () {
      final f = read('Your statement is ready', text: 'Amount \$84.20 due by Nov 12, 2026.').single;
      expect(f.type, TimelyType.bill);
      expect(f.detail, '\$84.20 due');
      expect(f.startsAt, DateTime(2026, 11, 12));
    });
    test('no due date, no bill', () => expect(read('Your statement is ready', text: 'View it online.'), isEmpty));
  });

  group('schema.org data', () {
    String jsonLd(String body) => '<html><head><script type="application/ld+json">$body</script></head><body>schema.org</body></html>';

    test('ParcelDelivery', () {
      final f = read('Shipped', html: jsonLd('''{"@context":"http://schema.org","@type":"ParcelDelivery","carrier":{"@type":"Organization","name":"FedEx"},
        "itemShipped":{"@type":"Product","name":"Blue Widget"},"trackingNumber":"123456789012","trackingUrl":"https://track.example/123",
        "expectedArrivalUntil":"2026-11-06T12:00:00-05:00","partOfOrder":{"@type":"Order","orderNumber":"A1","merchant":{"@type":"Organization","name":"Acme"}}}''')).single;
      expect(f.type, TimelyType.delivery);
      expect(f.title, 'Blue Widget');
      expect(f.detail, 'FedEx');
      expect(f.actionUrl, 'https://track.example/123');
      expect(f.startsAt, DateTime.parse('2026-11-06T12:00:00-05:00').toLocal());
    });

    test('FlightReservation, multi-leg, in a list', () {
      final facts = read('Trip', html: jsonLd('''[
        {"@context":"http://schema.org","@type":"FlightReservation","reservationNumber":"RXJ34P","checkinUrl":"https://air.example/checkin",
         "reservationFor":{"@type":"Flight","flightNumber":"110","airline":{"@type":"Airline","name":"United","iataCode":"UA"},
         "departureAirport":{"@type":"Airport","iataCode":"SFO"},"arrivalAirport":{"@type":"Airport","iataCode":"JFK"},
         "departureTime":"2026-11-05T20:15:00-08:00","arrivalTime":"2026-11-06T04:30:00-05:00"}},
        {"@context":"http://schema.org","@type":"FlightReservation","reservationNumber":"RXJ34P",
         "reservationFor":{"@type":"Flight","flightNumber":"111","airline":{"@type":"Airline","name":"United","iataCode":"UA"},
         "departureAirport":{"@type":"Airport","iataCode":"JFK"},"arrivalAirport":{"@type":"Airport","iataCode":"BOS"},
         "departureTime":"2026-11-06T06:00:00-05:00"}}
      ]'''));
      expect(facts, hasLength(2));
      expect(facts.first.title, 'Flight UA 110 · SFO to JFK');
      expect(facts.first.detail, 'Confirmation RXJ34P');
      expect(facts.first.actionUrl, 'https://air.example/checkin');
    });

    test('Microdata', () {
      final f = read('Shipped', html: '''<div itemscope itemtype="http://schema.org/ParcelDelivery">
        <div itemprop="carrier" itemscope itemtype="http://schema.org/Organization"><meta itemprop="name" content="UPS"/></div>
        <div itemprop="itemShipped" itemscope itemtype="http://schema.org/Product"><meta itemprop="name" content="Red Widget"/></div>
        <meta itemprop="trackingNumber" content="1Z999AA10123456784"/>
        <meta itemprop="expectedArrivalUntil" content="2026-11-07T12:00:00-05:00"/>
      </div>''').single;
      expect(f.title, 'Red Widget');
      expect(f.actionUrl, contains('ups.com'));
    });

    test('a cancelled reservation is off the strip', () {
      final f = read('Cancelled', html: jsonLd('''{"@type":"FlightReservation","reservationStatus":"http://schema.org/ReservationCancelled",
        "reservationFor":{"@type":"Flight","flightNumber":"9","airline":{"iataCode":"DL"},"departureTime":"2026-11-05T08:00:00-05:00"}}''')).single;
      expect(f.status, 'cancelled');
      final w = TimelyWindow.of(f, received);
      expect(w.until.isAfter(w.from), isFalse);
    });

    test('bad data and non-web links are ignored', () {
      expect(read('x', html: jsonLd('{not json')), isEmpty);
      final f = read('x', html: jsonLd('''{"@type":"ParcelDelivery","trackingUrl":"javascript:alert(1)","expectedArrivalUntil":"2026-11-07T12:00:00-05:00"}''')).single;
      expect(f.actionUrl, isNull);
    });
  });

  group('dates', () {
    DateTime? d(String s) => TimelyExtractor.parseDate(s, received);
    test('forms', () {
      expect(d('today'), DateTime(2026, 11, 2));
      expect(d('tomorrow'), DateTime(2026, 11, 3));
      expect(d('Thursday'), DateTime(2026, 11, 5));
      expect(d('Nov 5'), DateTime(2026, 11, 5));
      expect(d('November 5, 2027'), DateTime(2027, 11, 5));
      expect(d('11/5/26'), DateTime(2026, 11, 5));
      expect(d('2026-12-01'), DateTime(2026, 12, 1));
      expect(d('Jan 3'), DateTime(2027, 1, 3), reason: 'next one, not last January');
      expect(d('Feb 31'), isNull);
      expect(d('someday'), isNull);
    });
  });
}
