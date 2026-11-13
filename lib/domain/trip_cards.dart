import 'dart:convert';

/// One flight or one train the user is to travel on, as the assistant read
/// it out of the mail. A round trip with a connection each way is four of
/// these. Times are kept the way the email wrote them: the departure in the
/// clock of the place it leaves from, the arrival in the clock of the place
/// it arrives at. [departsAt] and [arrivesAt] are those same moments in
/// real time, so "has it landed yet" is right wherever the user is.
class TripLeg {
  const TripLeg({
    required this.key,
    this.mode = 'flight',
    this.carrier = '',
    this.number = '',
    this.fromCode = '',
    this.fromCity = '',
    this.toCode = '',
    this.toCity = '',
    this.departs,
    this.arrives,
    this.departsAt,
    this.arrivesAt,
    this.locator = '',
    this.state = 'confirmed',
    this.newsAt,
    this.wasDeparts,
    this.wasArrives,
    this.checkInUrl = '',
    this.messageId = '',
    this.missing = const [],
  });

  final String key;

  /// `flight` or `train`.
  final String mode;
  final String carrier;
  final String number;
  final String fromCode;
  final String fromCity;
  final String toCode;
  final String toCity;

  /// Local wall-clock times, as written in the email.
  final LocalTime? departs;
  final LocalTime? arrives;

  /// The same moments in real time.
  final DateTime? departsAt;
  final DateTime? arrivesAt;

  /// The record locator or confirmation code.
  final String locator;

  /// `confirmed`, `changed`, `checkin` (invited to check in), `checked`
  /// (checked in), `delayed`, `cancelled`.
  final String state;

  /// When the booking, or a confirmed change to it, came.
  final DateTime? newsAt;

  /// For a delay: the times it had before.
  final LocalTime? wasDeparts;
  final LocalTime? wasArrives;

  /// Where the email's own "check in" button leads.
  final String checkInUrl;

  /// The newest email about it, by Message-ID.
  final String messageId;

  /// What its card lacks, in plain words.
  final List<String> missing;

  bool get delayed => state == 'delayed';
  bool get cancelled => state == 'cancelled';

  /// How long it is in the air or on the rails.
  Duration? get duration => departsAt == null || arrivesAt == null || !arrivesAt!.isAfter(departsAt!) ? null : arrivesAt!.difference(departsAt!);

  /// "Raleigh/Durham to New York LaGuardia".
  String get route {
    final from = fromCity.isNotEmpty ? fromCity : fromCode;
    final to = toCity.isNotEmpty ? toCity : toCode;
    if (from.isEmpty && to.isEmpty) return mode == 'train' ? 'Train' : 'Flight';
    return '${from.isEmpty ? '?' : from} to ${to.isEmpty ? '?' : to}';
  }

  static const confirmedFor = Duration(hours: 24);
  static const upcomingFrom = Duration(days: 5);

  /// When it is over: its arrival, in the arrival city's own time. With no
  /// arrival time known, six hours after it leaves; with no time at all,
  /// the end of its day.
  DateTime? get over => arrivesAt ?? departsAt?.add(const Duration(hours: 6));

  /// Whether the Travel card shows it at [now]:
  ///  - for a day after it was booked or a change to it was confirmed;
  ///  - from five days before it leaves;
  ///  - whenever it is delayed or cancelled;
  /// and never once it has arrived.
  bool showsAt(DateTime now) {
    final end = over;
    if (end != null && !end.isAfter(now)) return false;
    if (delayed || cancelled) return true;
    if (newsAt != null && now.difference(newsAt!) < confirmedFor) return true;
    final leaves = departsAt;
    return leaves != null && !leaves.subtract(upcomingFrom).isAfter(now);
  }

  /// It is close enough to be drawn large: it leaves within two days, or it
  /// is delayed or cancelled. Until then it is a compact pass.
  static const closeFrom = Duration(hours: 48);

  bool closeAt(DateTime now) {
    if (delayed || cancelled) return true;
    final leaves = departsAt;
    return leaves != null && !leaves.subtract(closeFrom).isAfter(now);
  }

  /// The small heading it sits under.
  String headingAt(DateTime now) {
    if (cancelled) return 'Cancelled';
    if (delayed) return 'Delayed';
    if (state == 'checked') return 'Checked in';
    final leaves = departsAt;
    final soon = leaves != null && !leaves.subtract(upcomingFrom).isAfter(now);
    if (soon) return 'Upcoming';
    return state == 'changed' ? 'Changed' : 'Confirmed';
  }

  static TripLeg? fromData(String key, String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final Map<dynamic, dynamic> d = decoded;
    String s(String k) => d[k] is String ? d[k] as String : '';
    return TripLeg(
      key: key,
      mode: s('mode') == 'train' ? 'train' : 'flight',
      carrier: s('carrier'),
      number: s('number'),
      fromCode: s('fc'),
      fromCity: s('fcity'),
      toCode: s('tc'),
      toCity: s('tcity'),
      departs: LocalTime.parse(s('dep')),
      arrives: LocalTime.parse(s('arr')),
      departsAt: _moment(d['dep_at']),
      arrivesAt: _moment(d['arr_at']),
      locator: s('loc'),
      state: s('state').isEmpty ? 'confirmed' : s('state'),
      newsAt: (d['news_at'] is num && (d['news_at'] as num) > 0) ? _moment(d['news_at']) : null,
      wasDeparts: LocalTime.parse(s('was_dep')),
      wasArrives: LocalTime.parse(s('was_arr')),
      checkInUrl: s('checkin'),
      messageId: s('mid'),
      missing: [for (final m in (d['missing'] is List ? d['missing'] as List : const [])) if (m is String) m],
    );
  }
}

/// Another booking of the user's: a hotel stay, a rental car, a car with a
/// driver, a restaurant table, an appointment, a ticket.
class Booking {
  const Booking({
    required this.key,
    this.type = 'other',
    this.name = '',
    this.starts,
    this.ends,
    this.startsAt,
    this.endsAt,
    this.place = '',
    this.to = '',
    this.address = '',
    this.conf = '',
    this.phone = '',
    this.person = '',
    this.party = '',
    this.state = 'confirmed',
    this.newsAt,
    this.messageId = '',
  });

  final String key;

  /// `hotel`, `car_rental`, `car_service`, `restaurant`, `appointment`,
  /// `event`, `other`.
  final String type;

  /// The hotel, the car company, the restaurant, what the appointment is.
  final String name;
  final LocalTime? starts;
  final LocalTime? ends;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// A hotel's city; where a car is picked up; where an appointment is.
  final String place;

  /// Where a car is dropped off.
  final String to;
  final String address;
  final String conf;
  final String phone;

  /// A driver's name.
  final String person;

  /// How many, for a restaurant.
  final String party;
  final String state;
  final DateTime? newsAt;
  final String messageId;

  bool get cancelled => state == 'cancelled';

  /// When it is over: its end, or a while after it starts.
  DateTime? get over =>
      endsAt ??
      startsAt?.add(switch (type) {
        'hotel' || 'car_rental' => const Duration(days: 1),
        'restaurant' || 'appointment' => const Duration(hours: 2),
        _ => const Duration(hours: 4),
      });

  /// The same rule as travel: a day after it was booked or changed, and
  /// from five days before it starts, until it is over.
  bool showsAt(DateTime now) {
    final end = over;
    if (end != null && !end.isAfter(now)) return false;
    if (newsAt != null && now.difference(newsAt!) < TripLeg.confirmedFor) return true;
    final begins = startsAt;
    return begins != null && !begins.subtract(TripLeg.upcomingFrom).isAfter(now);
  }

  String headingAt(DateTime now) {
    if (cancelled) return 'Cancelled';
    final begins = startsAt;
    if (begins != null && !begins.subtract(TripLeg.upcomingFrom).isAfter(now)) return 'Upcoming';
    return state == 'changed' ? 'Changed' : 'Confirmed';
  }

  /// "Hotel", "Car service", …
  String get typeName => switch (type) {
        'hotel' => 'Hotel',
        'car_rental' => 'Rental car',
        'car_service' => 'Car service',
        'restaurant' => 'Restaurant',
        'appointment' => 'Appointment',
        'event' => 'Event',
        _ => 'Booking',
      };

  static Booking? fromData(String key, String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final Map<dynamic, dynamic> d = decoded;
    String s(String k) => d[k] is String ? d[k] as String : '';
    return Booking(
      key: key,
      type: s('type').isEmpty ? 'other' : s('type'),
      name: s('name'),
      starts: LocalTime.parse(s('starts')),
      ends: LocalTime.parse(s('ends')),
      startsAt: _moment(d['start_at']),
      endsAt: _moment(d['end_at']),
      place: s('place'),
      to: s('to'),
      address: s('address'),
      conf: s('conf'),
      phone: s('phone'),
      person: s('person'),
      party: s('party'),
      state: s('state').isEmpty ? 'confirmed' : s('state'),
      newsAt: (d['news_at'] is num && (d['news_at'] as num) > 0) ? _moment(d['news_at']) : null,
      messageId: s('mid'),
    );
  }
}

DateTime? _moment(Object? seconds) => seconds is num ? DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000) : null;

/// A time on the wall at some place, as an email wrote it: a day, and an
/// hour and minute when given. It is not a moment: it is never moved to the
/// user's own time zone.
class LocalTime {
  const LocalTime(this.year, this.month, this.day, [this.hour, this.minute]);
  final int year;
  final int month;
  final int day;
  final int? hour;
  final int? minute;

  bool get hasClock => hour != null && minute != null;

  /// The same wall-clock reading as a [DateTime], for formatting only.
  DateTime get wall => DateTime(year, month, day, hour ?? 0, minute ?? 0);

  bool sameDay(LocalTime o) => year == o.year && month == o.month && day == o.day;

  static final _shape = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?');

  /// From "2026-11-16T19:57" or "2026-11-16"; null for anything else.
  static LocalTime? parse(String s) {
    final m = _shape.firstMatch(s);
    if (m == null) return null;
    return LocalTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), m[4] == null ? null : int.parse(m[4]!), m[5] == null ? null : int.parse(m[5]!));
  }
}
