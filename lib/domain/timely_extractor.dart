import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// The kinds of timely information found in mail (spec 4.21).
enum TimelyType { code, delivery, flight, train, hotel, car, event, bill, confirm }

/// One timely thing found in a message.
class TimelyFact {
  const TimelyFact({
    required this.type,
    required this.dedupeKey,
    required this.title,
    this.detail = '',
    this.startsAt,
    this.endsAt,
    this.actionUrl,
    this.actionLabel,
    this.code,
    this.status,
  });

  final TimelyType type;

  /// Later mail about the same thing updates it (a tracking number, a
  /// reservation, a flight on a date).
  final String dedupeKey;
  final String title;
  final String detail;

  /// Departure, arrival of a package, check-in, due date.
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? actionUrl;
  final String? actionLabel;

  /// One-time code. Never written to logs.
  final String? code;

  /// `delivered`, `out-for-delivery`, `cancelled`, or null.
  final String? status;
}

/// When a fact shows on the strip: from [from] until [until].
class TimelyWindow {
  const TimelyWindow(this.from, this.until);
  final DateTime from;
  final DateTime until;

  static const codeLifetime = Duration(minutes: 15);
  static const deliveryLead = Duration(days: 2);
  static const undatedDelivery = Duration(days: 4);
  static const travelLead = Duration(hours: 48);
  static const otherLead = Duration(hours: 24);
  static const billLead = Duration(days: 3);
  static const confirmLifetime = Duration(hours: 24);

  /// The window for [f], from a message received at [received].
  static TimelyWindow of(TimelyFact f, DateTime received) {
    DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);
    final start = f.startsAt;
    switch (f.type) {
      case TimelyType.code:
        return TimelyWindow(received, received.add(codeLifetime));
      case TimelyType.delivery:
        // Delivered: it stays, marked so, until the end of that day.
        if (f.status == 'delivered') return TimelyWindow(received, endOfDay(received));
        if (f.status == 'out-for-delivery') return TimelyWindow(received, endOfDay(received));
        if (start == null) return TimelyWindow(received, received.add(undatedDelivery));
        return TimelyWindow(start.subtract(deliveryLead), endOfDay(start));
      case TimelyType.flight:
      case TimelyType.train:
        final s = start ?? received;
        if (f.status == 'cancelled') return TimelyWindow(received, received);
        return TimelyWindow(s.subtract(travelLead), f.endsAt ?? s.add(const Duration(hours: 6)));
      case TimelyType.hotel:
      case TimelyType.car:
        final s = start ?? received;
        if (f.status == 'cancelled') return TimelyWindow(received, received);
        return TimelyWindow(s.subtract(otherLead), f.endsAt ?? s.add(const Duration(days: 1)));
      case TimelyType.event:
        final s = start ?? received;
        if (f.status == 'cancelled') return TimelyWindow(received, received);
        return TimelyWindow(s.subtract(otherLead), f.endsAt ?? s.add(const Duration(hours: 4)));
      case TimelyType.bill:
        final s = start ?? received;
        return TimelyWindow(s.subtract(billLead), endOfDay(s));
      case TimelyType.confirm:
        return TimelyWindow(received, received.add(confirmLifetime));
    }
  }
}

/// A message, as the extractor reads it.
class TimelyInput {
  const TimelyInput({
    required this.messageKey,
    required this.received,
    this.subject = '',
    this.fromName = '',
    this.fromAddress = '',
    this.text = '',
    this.html = '',
  });

  /// Stable id for things that exist once per message, such as codes.
  final String messageKey;
  final DateTime received;
  final String subject;
  final String fromName;
  final String fromAddress;
  final String text;
  final String html;
}

/// Reads codes, deliveries and travel out of a message, on the device. In
/// order: schema.org data the sender embedded (the markup Gmail documents),
/// then rules for mail without it. It never guesses a date: a trip or bill
/// whose date cannot be read yields nothing.
class TimelyExtractor {
  const TimelyExtractor();

  List<TimelyFact> extract(TimelyInput m) {
    final facts = <String, TimelyFact>{};
    for (final f in _fromSchema(m)) {
      facts[f.dedupeKey] = f;
    }
    if (facts.isEmpty) {
      for (final f in [
        ..._code(m),
        ..._delivery(m),
        ..._flight(m),
        ..._train(m),
        ..._hotel(m),
        ..._bill(m),
      ]) {
        facts.putIfAbsent(f.dedupeKey, () => f);
      }
      // An email with a code in it is a code; one with only a button to
      // press is "confirm your email address".
      if (!facts.values.any((f) => f.type == TimelyType.code)) {
        for (final f in _confirm(m)) {
          facts.putIfAbsent(f.dedupeKey, () => f);
        }
      }
    }
    return facts.values.toList();
  }

  // ---- schema.org ---------------------------------------------------------

  List<TimelyFact> _fromSchema(TimelyInput m) {
    if (m.html.isEmpty) return const [];
    if (!m.html.contains('schema.org')) return const [];
    final out = <TimelyFact>[];
    for (final o in schemaObjects(m.html)) {
      final f = _schemaFact(o, m);
      if (f != null) out.add(f);
    }
    return out;
  }

  /// Schema.org objects in [html], from JSON-LD and Microdata, in one shape.
  static List<Map<String, dynamic>> schemaObjects(String html) {
    final out = <Map<String, dynamic>>[];
    void add(Object? v) {
      if (v is List) {
        v.forEach(add);
      } else if (v is Map) {
        final map = v.map((k, x) => MapEntry('$k', x));
        if (map['@graph'] is List) {
          add(map['@graph']);
        } else {
          out.add(map);
        }
      }
    }

    dom.Document doc;
    try {
      doc = html_parser.parse(html);
    } catch (_) {
      return const [];
    }
    for (final s in doc.querySelectorAll('script')) {
      if ((s.attributes['type'] ?? '').toLowerCase() != 'application/ld+json') continue;
      try {
        add(jsonDecode(s.text));
      } catch (_) {
        // Bad data from a sender is simply ignored.
      }
    }
    for (final e in doc.querySelectorAll('[itemscope]')) {
      if (e.attributes.containsKey('itemprop')) continue;
      final o = _microdata(e);
      if (o['@type'] != null) out.add(o);
    }
    return out;
  }

  static Map<String, dynamic> _microdata(dom.Element scope) {
    final o = <String, dynamic>{};
    final type = scope.attributes['itemtype'];
    if (type != null) o['@type'] = type.split('/').last;
    void walk(dom.Element parent) {
      for (final c in parent.children) {
        final prop = c.attributes['itemprop'];
        if (prop != null) {
          o[prop] = c.attributes.containsKey('itemscope')
              ? _microdata(c)
              : (c.attributes['content'] ?? c.attributes['href'] ?? c.attributes['src'] ?? c.attributes['datetime'] ?? c.text.trim());
        }
        if (!c.attributes.containsKey('itemscope')) walk(c);
      }
    }

    walk(scope);
    return o;
  }

  static String _typeOf(Map<String, dynamic> o) => '${o['@type'] ?? ''}'.split('/').last;

  static Map<String, dynamic> _obj(Object? v) {
    if (v is Map) return v.map((k, x) => MapEntry('$k', x));
    if (v is List && v.isNotEmpty) return _obj(v.first);
    if (v is String) return {'name': v};
    return const {};
  }

  static String _str(Object? v) => v == null || v is Map || v is List ? '' : '$v'.trim();

  static DateTime? _time(Object? v) {
    final s = _str(v);
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  static String? _webUrl(Object? v) {
    final s = _str(v);
    final uri = Uri.tryParse(s);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty ? s : null;
  }

  static bool _cancelled(Map<String, dynamic> o) => _str(o['reservationStatus']).toLowerCase().contains('cancel');

  TimelyFact? _schemaFact(Map<String, dynamic> o, TimelyInput m) {
    final type = _typeOf(o);
    final reservation = _str(o['reservationNumber']);
    final item = _obj(o['reservationFor']);
    final status = _cancelled(o) ? 'cancelled' : null;
    switch (type) {
      case 'ParcelDelivery':
        final carrier = _str(_obj(o['carrier'])['name']);
        final order = _obj(o['partOfOrder']);
        final merchant = _str(_obj(order['merchant'])['name']);
        final product = _str(_obj(o['itemShipped'])['name']);
        final tracking = _str(o['trackingNumber']);
        final orderNo = _str(order['orderNumber']);
        final key = tracking.isNotEmpty ? 'parcel:${tracking.toUpperCase()}' : (orderNo.isNotEmpty ? 'order:$orderNo' : 'parcel:${m.messageKey}');
        final statusText = '${_str(order['orderStatus'])} ${_str(o['deliveryStatus'])}'.toLowerCase();
        return TimelyFact(
          type: TimelyType.delivery,
          dedupeKey: key,
          title: product.isNotEmpty ? product : (merchant.isNotEmpty ? merchant : m.fromName),
          detail: carrier,
          startsAt: _time(o['expectedArrivalUntil']) ?? _time(o['expectedArrivalFrom']),
          actionUrl: _webUrl(o['trackingUrl']) ?? _webUrl(_obj(o['potentialAction'])['url']) ?? (tracking.isEmpty ? null : _trackingUrl(tracking)),
          actionLabel: 'Track',
          status: statusText.contains('delivered') ? 'delivered' : null,
        );
      case 'FlightReservation':
        final airline = _obj(item['airline']);
        final number = '${_str(airline['iataCode'])} ${_str(item['flightNumber'])}'.trim();
        final from = _obj(item['departureAirport']);
        final to = _obj(item['arrivalAirport']);
        final depart = _time(item['departureTime']);
        if (depart == null) return null;
        final route = [_str(from['iataCode']), _str(to['iataCode'])].where((s) => s.isNotEmpty).join(' to ');
        return TimelyFact(
          type: TimelyType.flight,
          dedupeKey: 'flight:$number:${depart.toUtc().toIso8601String()}',
          title: 'Flight ${number.isEmpty ? _str(airline['name']) : number}${route.isEmpty ? '' : ' · $route'}',
          detail: reservation.isEmpty ? _str(airline['name']) : 'Confirmation $reservation',
          startsAt: depart,
          endsAt: _time(item['arrivalTime']),
          actionUrl: _webUrl(o['checkinUrl']) ?? _webUrl(_obj(o['potentialAction'])['target']),
          actionLabel: 'Check in',
          status: status,
        );
      case 'TrainReservation':
      case 'BusReservation':
        final isTrain = type == 'TrainReservation';
        final number = _str(item[isTrain ? 'trainNumber' : 'busNumber']);
        final company = _str(_obj(item[isTrain ? 'trainCompany' : 'busCompany'])['name']);
        final from = _str(_obj(item[isTrain ? 'departureStation' : 'departureBusStop'])['name']);
        final to = _str(_obj(item[isTrain ? 'arrivalStation' : 'arrivalBusStop'])['name']);
        final depart = _time(item['departureTime']);
        if (depart == null) return null;
        final route = [from, to].where((s) => s.isNotEmpty).join(' to ');
        final label = '${isTrain ? 'Train' : 'Bus'} ${number.isEmpty ? company : number}'.trim();
        return TimelyFact(
          type: TimelyType.train,
          dedupeKey: '${isTrain ? 'train' : 'bus'}:$number:${depart.toUtc().toIso8601String()}',
          title: '$label${route.isEmpty ? '' : ' · $route'}',
          detail: reservation.isEmpty ? company : 'Confirmation $reservation',
          startsAt: depart,
          endsAt: _time(item['arrivalTime']),
          status: status,
        );
      case 'LodgingReservation':
        final start = _time(o['checkinTime']) ?? _time(o['checkinDate']);
        if (start == null) return null;
        return TimelyFact(
          type: TimelyType.hotel,
          dedupeKey: 'hotel:${reservation.isEmpty ? '${_str(item['name'])}:${start.toUtc().toIso8601String()}' : reservation}',
          title: _str(item['name']).isEmpty ? 'Hotel check-in' : _str(item['name']),
          detail: reservation.isEmpty ? 'Check-in' : 'Confirmation $reservation',
          startsAt: start,
          endsAt: _time(o['checkoutTime']) ?? _time(o['checkoutDate']),
          status: status,
        );
      case 'RentalCarReservation':
        final start = _time(o['pickupTime']);
        if (start == null) return null;
        final brand = _str(_obj(_obj(o['reservationFor'])['rentalCompany'])['name']);
        return TimelyFact(
          type: TimelyType.car,
          dedupeKey: 'car:${reservation.isEmpty ? start.toUtc().toIso8601String() : reservation}',
          title: brand.isEmpty ? 'Rental car pickup' : 'Rental car · $brand',
          detail: _str(_obj(o['pickupLocation'])['name']),
          startsAt: start,
          endsAt: _time(o['dropoffTime']),
          status: status,
        );
      case 'EventReservation':
      case 'FoodEstablishmentReservation':
        final start = type == 'EventReservation' ? _time(item['startDate']) : _time(o['startTime']);
        if (start == null) return null;
        final name = _str(item['name']);
        return TimelyFact(
          type: TimelyType.event,
          dedupeKey: 'event:${reservation.isEmpty ? '$name:${start.toUtc().toIso8601String()}' : reservation}',
          title: name.isEmpty ? m.subject : name,
          detail: _str(_obj(item['location'])['name']),
          startsAt: start,
          endsAt: _time(item['endDate']) ?? _time(o['endTime']),
          status: status,
        );
      case 'Invoice':
        final due = _time(o['paymentDueDate']) ?? _time(o['paymentDue']);
        if (due == null) return null;
        final amount = _obj(o['totalPaymentDue']);
        final price = _str(amount['price']);
        return TimelyFact(
          type: TimelyType.bill,
          dedupeKey: 'bill:${_str(o['accountId'])}:${due.toUtc().toIso8601String()}',
          title: _str(_obj(o['provider'])['name']).isEmpty ? m.fromName : _str(_obj(o['provider'])['name']),
          detail: price.isEmpty ? 'Payment due' : '${_str(amount['priceCurrency'])} $price due'.trim(),
          startsAt: due,
          actionUrl: _webUrl(o['url']),
          actionLabel: 'Pay',
        );
    }
    return null;
  }

  // ---- one-time codes -----------------------------------------------------

  static final _codeTopic = RegExp(
    r'\b(?:(?:verification|security|log\s?-?in|sign\s?-?in|authentication|authorization|one[\s-]?time|access|confirmation)\s+(?:code|pin|password|passcode)|verification|passcode|otp|2fa|two[\s-]factor|one[\s-]?time\s+password|your\s+code|code\s+to\s+(?:log|sign|verify|confirm|continue))\b',
    caseSensitive: false,
  );
  static final _notACode = RegExp(r'\b(?:promo|coupon|discount|voucher|gift\s+card|referral|redeem|% off|zip\s+code|postal\s+code|dress\s+code|area\s+code|source\s+code|qr\s+code)\b', caseSensitive: false);
  static final _travelOrOrder = RegExp(r'\b(?:flight|itinerary|hotel|booking|reservation|order|ticket|trip|shipment)\b', caseSensitive: false);

  static final _codeAfterWord = RegExp(r'\b(?:[Cc]ode|CODE|[Pp]in|PIN|[Pp]asscode|otp|OTP|[Pp]assword|[Ss]ign\s?-?in|[Ll]og\s?-?in|[Vv]erify|[Cc]onfirm|[Cc]ontinue)\b(?:\s+is)?\s*[:=\-]?\s*(?:is\s+)?["“]?([A-Z0-9][A-Z0-9-]{2,10}[A-Z0-9])\b');
  static final _codeBeforeIsYour = RegExp(r'\b([A-Z0-9][A-Z0-9-]{2,10}[A-Z0-9])\s+is\s+your\b');
  static final _digitsLine = RegExp(r'^\s*(\d{3}[ -]\d{3}|\d{4,8})\s*$', multiLine: true);

  List<TimelyFact> _code(TimelyInput m) {
    final head = m.text.length > 1500 ? m.text.substring(0, 1500) : m.text;
    final topicInSubject = _codeTopic.hasMatch(m.subject);
    if (!topicInSubject && !_codeTopic.hasMatch(head)) return const [];
    if (_notACode.hasMatch(m.subject)) return const [];
    // A "confirmation code" on a trip or order is a booking reference.
    if (_travelOrOrder.hasMatch(m.subject) && !RegExp(r'\b(?:verif|log\s?-?in|sign\s?-?in|one[\s-]?time|otp|passcode)', caseSensitive: false).hasMatch(m.subject)) return const [];

    String? code;
    for (final source in [m.subject, head]) {
      for (final pattern in [_codeAfterWord, _codeBeforeIsYour]) {
        for (final match in pattern.allMatches(source)) {
          final before = source.substring(match.start > 40 ? match.start - 40 : 0, match.start);
          if (_notACode.hasMatch(before + match.group(0)!)) continue;
          final c = _plausibleCode(match.group(1)!);
          if (c != null) {
            code = c;
            break;
          }
        }
        if (code != null) break;
      }
      if (code != null) break;
    }
    if (code == null) {
      for (final match in _digitsLine.allMatches(head)) {
        final c = _plausibleCode(match.group(1)!);
        if (c != null) {
          code = c;
          break;
        }
      }
    }
    if (code == null) return const [];
    return [
      TimelyFact(
        type: TimelyType.code,
        dedupeKey: 'code:${m.messageKey}',
        title: m.fromName.isEmpty ? m.fromAddress : m.fromName,
        startsAt: m.received,
        code: code,
        actionLabel: 'Copy',
      ),
    ];
  }

  // ---- "confirm your email address" ---------------------------------------

  static final _confirmTopic = RegExp(
    r'\b(?:confirm|verify|validate|activate)\s+(?:your\s+|this\s+|the\s+|my\s+)?(?:new\s+)?(?:e-?mail(?:\s+address)?|account|sign-?\s?up|subscription|registration)\b',
    caseSensitive: false,
  );
  static final _confirmButton = RegExp(r'\b(?:confirm|verify|validate|activate)\b', caseSensitive: false);

  /// An email that asks the reader to press a button to confirm their
  /// address: the button's own link, so it can be pressed from the card.
  List<TimelyFact> _confirm(TimelyInput m) {
    final head = m.text.length > 1500 ? m.text.substring(0, 1500) : m.text;
    if (!_confirmTopic.hasMatch(m.subject) && !_confirmTopic.hasMatch(head)) return const [];
    final url = _linkLabelled(m.html, _confirmButton);
    if (url == null) return const [];
    return [
      TimelyFact(
        type: TimelyType.confirm,
        dedupeKey: 'confirm:${m.messageKey}',
        title: m.fromName.isEmpty ? m.fromAddress : m.fromName,
        startsAt: m.received,
        actionUrl: url,
        actionLabel: 'Confirm',
      ),
    ];
  }

  /// [raw] tidied when it can be a one-time code, else null.
  static String? _plausibleCode(String raw) {
    final c = raw.replaceAll(' ', '');
    final digitsOnly = c.replaceAll('-', '');
    if (RegExp(r'^\d+$').hasMatch(digitsOnly)) {
      if (digitsOnly.length < 4 || digitsOnly.length > 8) return null;
      // A bare year reads as a code too easily.
      if (digitsOnly.length == 4 && RegExp(r'^(19|20)\d\d$').hasMatch(digitsOnly)) return null;
      return c;
    }
    // Mixed codes need a digit: plain words like "BELOW" are not codes.
    if (RegExp(r'^G-\d{4,8}$').hasMatch(c)) return c;
    if (c.length < 5 || c.length > 10) return null;
    if (!RegExp(r'\d').hasMatch(c) || !RegExp(r'[A-Z]').hasMatch(c)) return null;
    return c;
  }

  // ---- deliveries ---------------------------------------------------------

  static final _shippingTopic = RegExp(r'\b(?:shipped|shipping\s+(?:confirmation|update|notification)|shipment|on\s+(?:its|the|their)\s+way|out\s+for\s+delivery|delivered|delivery\s+(?:update|date|scheduled|attempt)|arriving|has\s+shipped|tracking\s+(?:number|info|details)|package)\b', caseSensitive: false);
  static final _promo = RegExp(r'\b(?:free\s+shipping|\d+%\s+off|sale|save\s+\$?\d|deals?|coupon|shop\s+now|limited\s+time)\b', caseSensitive: false);
  static final _ups = RegExp(r'\b1Z[0-9A-Z]{16}\b');
  static final _usps = RegExp(r'\b(?:9[2-5]\d{20}|[A-Z]{2}\d{9}US)\b');
  static final _fedex = RegExp(r'\b(?:\d{12}|\d{15}|\d{20})\b');
  static final _amazon = RegExp(r'\bTBA\d{12}\b');
  static final _dhl = RegExp(r'\b\d{10}\b');
  static final _orderNumber = RegExp(r'\border\s*(?:number|no\.?|#)?\s*[:#]?\s*([A-Z0-9][A-Z0-9-]{3,24})\b', caseSensitive: false);
  static final _arrivalPhrase = RegExp(
    r'\b(?:arriv\w*|deliver\w*|expected|estimated|get\s+it|by|on)\b[^.\n]{0,40}?\b(today|tomorrow|(?:mon|tues?|wed(?:nes)?|thu(?:rs?)?|fri|sat(?:ur)?|sun)(?:day)?\b(?:,?\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2})?|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2}(?:,?\s+\d{4})?|\d{1,2}/\d{1,2}(?:/\d{2,4})?)',
    caseSensitive: false,
  );

  static bool _validUps(String t) {
    if (!t.startsWith('1Z') || t.length != 18) return false;
    var sum = 0;
    for (var i = 2; i < 17; i++) {
      final ch = t.codeUnitAt(i);
      final v = ch >= 48 && ch <= 57 ? ch - 48 : (ch - 63) % 10;
      sum += i.isOdd ? v * 2 : v;
    }
    return (10 - sum % 10) % 10 == t.codeUnitAt(17) - 48;
  }

  static bool _validMod10(String digits) {
    var sum = 0;
    var weight = 3;
    for (var i = digits.length - 2; i >= 0; i--) {
      sum += (digits.codeUnitAt(i) - 48) * weight;
      weight = weight == 3 ? 1 : 3;
    }
    return (10 - sum % 10) % 10 == digits.codeUnitAt(digits.length - 1) - 48;
  }

  /// Finds a tracking number and its carrier in [text].
  static (String, String)? _tracking(String text) {
    for (final match in _ups.allMatches(text)) {
      if (_validUps(match.group(0)!)) return (match.group(0)!, 'UPS');
    }
    final amazon = _amazon.firstMatch(text);
    if (amazon != null) return (amazon.group(0)!, 'Amazon');
    final lower = text.toLowerCase();
    for (final match in _usps.allMatches(text)) {
      final t = match.group(0)!;
      if (lower.contains('usps') || lower.contains('postal') || (RegExp(r'^\d+$').hasMatch(t) && _validMod10(t))) return (t, 'USPS');
    }
    if (lower.contains('fedex')) {
      for (final match in _fedex.allMatches(text)) {
        return (match.group(0)!, 'FedEx');
      }
    }
    if (lower.contains('dhl')) {
      for (final match in _dhl.allMatches(text)) {
        return (match.group(0)!, 'DHL');
      }
    }
    return null;
  }

  /// The carrier's own tracking page for a number.
  static String? _trackingUrl(String t) {
    final tracking = Uri.encodeComponent(t);
    if (t.startsWith('1Z')) return 'https://www.ups.com/track?tracknum=$tracking';
    if (t.startsWith('TBA')) return 'https://www.amazon.com/gp/your-account/order-history';
    if (RegExp(r'^(9[2-5]\d{20}|[A-Z]{2}\d{9}US)$').hasMatch(t)) return 'https://tools.usps.com/go/TrackConfirmAction?tLabels=$tracking';
    if (RegExp(r'^\d{12}$|^\d{15}$|^\d{20}$').hasMatch(t)) return 'https://www.fedex.com/fedextrack/?trknbr=$tracking';
    if (RegExp(r'^\d{10}$').hasMatch(t)) return 'https://www.dhl.com/global-en/home/tracking.html?tracking-id=$tracking';
    return null;
  }

  static String? _linkLabelled(String html, RegExp label) {
    if (html.isEmpty) return null;
    try {
      for (final a in html_parser.parse(html).querySelectorAll('a[href]')) {
        if (label.hasMatch(a.text)) {
          final url = _webUrl(a.attributes['href']);
          if (url != null) return url;
        }
      }
    } catch (_) {
      // No link then.
    }
    return null;
  }

  List<TimelyFact> _delivery(TimelyInput m) {
    final combined = '${m.subject}\n${m.text}';
    final tracking = _tracking(combined);
    final topical = _shippingTopic.hasMatch(m.subject);
    if (tracking == null && !topical) return const [];
    if (tracking == null && _promo.hasMatch(m.subject)) return const [];

    final subject = m.subject.toLowerCase();
    final textHead = (m.text.length > 800 ? m.text.substring(0, 800) : m.text).toLowerCase();
    String? status;
    if (RegExp(r'\bout\s+for\s+delivery\b').hasMatch(subject) || RegExp(r'\bout\s+for\s+delivery\b').hasMatch(textHead)) {
      status = 'out-for-delivery';
    } else if (RegExp(r'\b(?:was|been|package|order|item)?\s*delivered\b').hasMatch(subject)) {
      status = 'delivered';
    }

    DateTime? arrival;
    final phrase = _arrivalPhrase.firstMatch(m.subject) ?? _arrivalPhrase.firstMatch(m.text);
    if (phrase != null) arrival = parseDate(phrase.group(1)!, m.received);

    final order = _orderNumber.firstMatch(combined)?.group(1);
    final key = tracking != null ? 'parcel:${tracking.$1}' : (order != null && RegExp(r'\d').hasMatch(order) ? 'order:$order' : 'parcel:${m.fromAddress}:${_normalizeSubject(m.subject)}');
    final url = tracking == null ? null : _trackingUrl(tracking.$1);
    return [
      TimelyFact(
        type: TimelyType.delivery,
        dedupeKey: key,
        title: m.fromName.isEmpty ? m.fromAddress : m.fromName,
        detail: tracking?.$2 ?? '',
        startsAt: arrival,
        actionUrl: url ?? _linkLabelled(m.html, RegExp(r'\b(?:track|view\s+order|order\s+status)\b', caseSensitive: false)),
        actionLabel: 'Track',
        status: status,
      ),
    ];
  }

  static String _normalizeSubject(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  // ---- travel -------------------------------------------------------------

  static const _airlines = 'AA|DL|UA|WN|AS|B6|NK|F9|G4|HA|SY|AC|WS|BA|VS|AF|KL|LH|IB|EK|QR|TK|JL|NH|QF|LX|AY|SK|EI|TP';
  static final _flightTopic = RegExp(r'\b(?:flight|itinerary|boarding\s+pass|check[\s-]?in|e-?ticket|trip\s+confirmation|departure)\b', caseSensitive: false);
  static final _flightNumber = RegExp('\\b(?:flight\\s+(?:number\\s+)?(?:($_airlines)\\s?)?(\\d{1,4})|($_airlines)\\s?(\\d{1,4}))\\b', caseSensitive: false);
  static final _route = RegExp(r'\b([A-Z]{3})\s*(?:to|→|->|–|—|-|>)\s*([A-Z]{3})\b');
  static final _datePattern = RegExp(
    r'\b(?:(?:mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)[a-z]*,?\s+)?(?:(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2}(?:,?\s+\d{4})?|\d{1,2}/\d{1,2}(?:/\d{2,4})?|\d{4}-\d{2}-\d{2})\b',
    caseSensitive: false,
  );
  static final _timePattern = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m\.?\b', caseSensitive: false);
  static final _confirmation = RegExp(r'\b(?:[Cc]onfirmation|[Rr]ecord\s+[Ll]ocator|[Bb]ooking\s+(?:[Cc]ode|[Rr]eference))\b[^A-Z0-9\n]{0,20}([A-Z0-9]{6})\b');
  static final _travelPromo = RegExp(r'\b(?:fares?|\d+%|sale|deals?|miles\s+offer|save\s+\$?\d)\b', caseSensitive: false);

  List<TimelyFact> _flight(TimelyInput m) {
    if (!_flightTopic.hasMatch(m.subject) || _travelPromo.hasMatch(m.subject)) return const [];
    final combined = '${m.subject}\n${m.text}';
    final number = _flightNumber.firstMatch(combined);
    if (number == null) return const [];
    final airline = (number.group(1) ?? number.group(3) ?? '').toUpperCase();
    final digits = number.group(2) ?? number.group(4)!;
    final at = _dateTimeNear(combined, number.start, m.received);
    if (at == null) return const [];
    final route = _route.firstMatch(combined);
    final confirmation = _confirmation.firstMatch(combined)?.group(1);
    final label = '$airline $digits'.trim();
    return [
      TimelyFact(
        type: TimelyType.flight,
        dedupeKey: 'flight:$label:${at.toUtc().toIso8601String()}',
        title: 'Flight $label${route == null ? '' : ' · ${route.group(1)} to ${route.group(2)}'}',
        detail: confirmation == null ? m.fromName : 'Confirmation $confirmation',
        startsAt: at,
        actionUrl: _linkLabelled(m.html, RegExp(r'\bcheck[\s-]?in\b', caseSensitive: false)),
        actionLabel: 'Check in',
      ),
    ];
  }

  static final _trainNumber = RegExp(r'\btrain\s+(?:number\s+|#\s*)?(\d{1,5})\b', caseSensitive: false);

  List<TimelyFact> _train(TimelyInput m) {
    if (!RegExp(r'\b(?:train|amtrak|rail)\b', caseSensitive: false).hasMatch('${m.subject} ${m.fromName}')) return const [];
    if (_travelPromo.hasMatch(m.subject)) return const [];
    final combined = '${m.subject}\n${m.text}';
    final number = _trainNumber.firstMatch(combined);
    if (number == null) return const [];
    final at = _dateTimeNear(combined, number.start, m.received);
    if (at == null) return const [];
    return [
      TimelyFact(
        type: TimelyType.train,
        dedupeKey: 'train:${number.group(1)}:${at.toUtc().toIso8601String()}',
        title: 'Train ${number.group(1)}',
        detail: m.fromName,
        startsAt: at,
      ),
    ];
  }

  static final _hotelTopic = RegExp(r'\b(?:hotel|inn|resort|suites|marriott|hilton|hyatt|airbnb|stay|lodging)\b', caseSensitive: false);
  static final _checkInDate = RegExp(r'\bcheck[\s-]?in\b[^\n]{0,30}', caseSensitive: false);

  List<TimelyFact> _hotel(TimelyInput m) {
    if (!_hotelTopic.hasMatch('${m.subject} ${m.fromName}')) return const [];
    if (!RegExp(r'\b(?:reservation|booking|confirmation|confirmed|stay|itinerary|upcoming)\b', caseSensitive: false).hasMatch(m.subject) || _travelPromo.hasMatch(m.subject)) return const [];
    final match = _checkInDate.firstMatch(m.text);
    if (match == null) return const [];
    final date = _datePattern.firstMatch(match.group(0)!);
    if (date == null) return const [];
    final start = parseDate(date.group(0)!, m.received);
    if (start == null) return const [];
    final confirmation = _confirmation.firstMatch(m.text)?.group(1);
    return [
      TimelyFact(
        type: TimelyType.hotel,
        dedupeKey: 'hotel:${confirmation ?? '${m.fromAddress}:${start.toIso8601String()}'}',
        title: m.fromName.isEmpty ? 'Hotel check-in' : m.fromName,
        detail: confirmation == null ? 'Check-in' : 'Confirmation $confirmation',
        startsAt: start,
      ),
    ];
  }

  static final _billTopic = RegExp(r'\b(?:bill|statement|payment|invoice|autopay)\b', caseSensitive: false);
  static final _dueDate = RegExp(r'\bdue\b(?:\s+(?:on|by|date))*[:\s]+([^\n.]{0,30})', caseSensitive: false);
  static final _amount = RegExp(r'\$\s?\d[\d,]*(?:\.\d{2})?');

  List<TimelyFact> _bill(TimelyInput m) {
    if (!_billTopic.hasMatch(m.subject) || _promo.hasMatch(m.subject)) return const [];
    final combined = '${m.subject}\n${m.text}';
    final due = _dueDate.firstMatch(combined);
    if (due == null) return const [];
    final date = _datePattern.firstMatch(due.group(1)!);
    if (date == null) return const [];
    final at = parseDate(date.group(0)!, m.received);
    if (at == null) return const [];
    final amount = _amount.firstMatch(combined)?.group(0);
    return [
      TimelyFact(
        type: TimelyType.bill,
        dedupeKey: 'bill:${m.fromAddress}:${at.toIso8601String()}',
        title: m.fromName.isEmpty ? m.fromAddress : m.fromName,
        detail: amount == null ? 'Payment due' : '$amount due',
        startsAt: at,
        actionUrl: _linkLabelled(m.html, RegExp(r'\b(?:pay|view\s+(?:bill|statement))\b', caseSensitive: false)),
        actionLabel: 'Pay',
      ),
    ];
  }

  /// A date and time close after [start] in [text]; midnight when only the
  /// date can be read, and null when no date can.
  static DateTime? _dateTimeNear(String text, int start, DateTime received) {
    var after = text.substring(start);
    if (after.length > 400) after = after.substring(0, 400);
    var date = _datePattern.firstMatch(after);
    var region = after;
    if (date == null) {
      // Some mail puts the date before the flight number.
      final from = start > 300 ? start - 300 : 0;
      region = text.substring(from, start);
      date = _datePattern.firstMatch(region);
      if (date == null) return null;
    }
    final day = parseDate(date.group(0)!, received);
    if (day == null) return null;
    final time = _timePattern.firstMatch(region.substring(date.end)) ?? _timePattern.firstMatch(region);
    if (time == null) return day;
    var hour = int.parse(time.group(1)!);
    final minute = int.tryParse(time.group(2) ?? '0') ?? 0;
    if (hour > 12 || minute > 59) return day;
    final pm = time.group(3)!.toLowerCase() == 'p';
    if (hour == 12) hour = 0;
    if (pm) hour += 12;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  // ---- dates --------------------------------------------------------------

  static const _months = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12};
  static const _weekdays = {'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4, 'fri': 5, 'sat': 6, 'sun': 7};

  /// Reads a date written as today, tomorrow, a weekday, Nov 5, 11/5/2026 or
  /// 2026-11-05. A date without a year is the next one after [ref]. Null when
  /// it cannot be read.
  static DateTime? parseDate(String input, DateTime ref) {
    final s = input.trim().toLowerCase();
    final today = DateTime(ref.year, ref.month, ref.day);
    if (s == 'today') return today;
    if (s == 'tomorrow') return DateTime(today.year, today.month, today.day + 1);
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (iso != null) return _valid(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
    final slash = RegExp(r'(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?').firstMatch(s);
    if (slash != null) {
      final month = int.parse(slash.group(1)!);
      final day = int.parse(slash.group(2)!);
      final y = slash.group(3);
      if (y != null) return _valid(y.length == 2 ? 2000 + int.parse(y) : int.parse(y), month, day);
      return _nextOccurrence(month, day, today);
    }
    final named = RegExp(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})(?:,?\s+(\d{4}))?').firstMatch(s);
    if (named != null) {
      final month = _months[named.group(1)!]!;
      final day = int.parse(named.group(2)!);
      final y = named.group(3);
      if (y != null) return _valid(int.parse(y), month, day);
      return _nextOccurrence(month, day, today);
    }
    final weekday = RegExp(r'^(mon|tue|wed|thu|fri|sat|sun)').firstMatch(s);
    if (weekday != null) {
      final target = _weekdays[weekday.group(1)!]!;
      final ahead = (target - today.weekday + 7) % 7;
      return DateTime(today.year, today.month, today.day + ahead);
    }
    return null;
  }

  static DateTime? _valid(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    return date.month == m ? date : null;
  }

  static DateTime? _nextOccurrence(int month, int day, DateTime today) {
    final thisYear = _valid(today.year, month, day);
    if (thisYear == null) return null;
    return thisYear.isBefore(today.subtract(const Duration(days: 30))) ? _valid(today.year + 1, month, day) : thisYear;
  }
}
