import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/conversation_state.dart';
import '../../app/destinations.dart';
import '../../app/layout.dart';
import '../../app/mail_state.dart';
import '../../app/people_state.dart';
import '../../app/search_state.dart';
import '../../app/time_format.dart';
import '../../domain/trip_cards.dart';
import '../../store/database.dart';
import '../../store/helper_queries.dart';
import '../widgets/item_menu.dart';
import 'chats/later_dialogs.dart';
import 'page_type.dart';

/// Travel legs and bookings the helper holds, as stored rows.
final helperCardsProvider = StreamProvider<List<HelperCard>>((ref) => ref.watch(databaseProvider).watchHelperCards());

/// A tick every half minute, so a leg leaves its card when it lands and one
/// five days out arrives on it, with no new mail.
final tripClockProvider = StreamProvider<int>((ref) => Stream.periodic(const Duration(seconds: 30), (i) => i));

/// The legs the Travel card shows now: the ones about to leave (and any
/// delayed or cancelled) first, by when they leave; then what was just
/// booked or changed.
List<TripLeg> travelNow(List<HelperCard> cards, DateTime now) {
  final legs = [
    for (final c in cards)
      if (c.kind == 'leg') ?TripLeg.fromData(c.k, c.data),
  ].where((l) => l.showsAt(now)).toList();
  int rank(TripLeg l) => l.headingAt(now) == 'Confirmed' || l.headingAt(now) == 'Changed' ? 1 : 0;
  final far = DateTime(9999);
  legs.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : (a.departsAt ?? far).compareTo(b.departsAt ?? far);
  });
  return legs;
}

/// The bookings the Bookings card shows now, soonest first.
List<(HelperCard, Booking)> bookingsNow(List<HelperCard> cards, DateTime now) {
  final out = <(HelperCard, Booking)>[];
  for (final c in cards) {
    if (c.kind != 'booking' || c.dismissed || (c.laterUntil?.isAfter(now) ?? false)) continue;
    final b = Booking.fromData(c.k, c.data);
    if (b != null && b.showsAt(now)) out.add((c, b));
  }
  final far = DateTime(9999);
  out.sort((a, b) => (a.$2.startsAt ?? far).compareTo(b.$2.startsAt ?? far));
  return out;
}

/// Opens the email with this Message-ID where it lives: a person's in
/// their chat, anything else in Feed, with the way back to the Précis page.
Future<void> openEmailByMessageId(WidgetRef ref, String messageId) async {
  if (messageId.isEmpty) return;
  final db = ref.read(databaseProvider);
  final m = await (db.select(db.messages)..where((t) => t.messageId.equals(messageId))..limit(1)).getSingleOrNull();
  if (m == null) return;
  ref.read(expandedMessagesProvider.notifier).expand(m.id);
  if (m.classification != 'feeds') {
    ref.read(scrollToMessageProvider.notifier).request(m.id);
    await openRow(ref.read, 'c:${m.fromContactKey}', fromToday: true);
  } else {
    ref.read(openMailProvider('feed').notifier).open(m.id);
    ref.read(destinationProvider.notifier).select(Destination.feed, fromToday: true);
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Mon, Nov 16".
String tripDay(LocalTime t) => '${_days[t.wall.weekday - 1]}, ${_months[t.month - 1]} ${t.day}';

/// "7:57 PM" or "19:57", as the user reads the clock; "" with no time known.
String tripClock(LocalTime? t) => t == null || !t.hasClock ? '' : clockTime(t.wall);

/// "2h 3m".
String tripLength(Duration d) => d.inHours > 0 ? '${d.inHours}h ${d.inMinutes % 60}m' : '${d.inMinutes}m';

/// The color a leg's heading and arc take: red when cancelled, yellow when
/// delayed, green otherwise.
Color tripColor(TripLeg l) => l.cancelled ? badColor : (l.delayed ? warnColor : okColor);

/// The Travel card's lines. A leg is a compact boarding pass until two days
/// before it leaves; then the first one is drawn large, with its airport
/// codes and an arc between them. A delayed or cancelled leg is large at once.
class TravelLegs extends ConsumerStatefulWidget {
  const TravelLegs({super.key, required this.legs});
  final List<TripLeg> legs;

  static const shownByDefault = 4;

  /// Whether the leg at [index] of [legs] is drawn large at [now].
  static bool large(List<TripLeg> legs, int index, DateTime now) => legs[index].delayed || legs[index].cancelled || (index == 0 && legs[index].closeAt(now));

  @override
  ConsumerState<TravelLegs> createState() => _TravelLegsState();
}

class _TravelLegsState extends ConsumerState<TravelLegs> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final legs = widget.legs;
    if (legs.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final shown = _all ? legs : legs.take(TravelLegs.shownByDefault).toList();
    final hidden = legs.length - shown.length;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)),
          InkWell(
            key: ValueKey('leg-${shown[i].key}'),
            onTap: () => unawaited(openEmailByMessageId(ref, shown[i].messageId)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 11, 0, 10),
              // On a wide page a leg keeps the width of a phone card, so its
              // line stays a line and its arc an arc.
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: TravelLegs.large(shown, i, now) ? _BigLeg(key: ValueKey('leg-large-${shown[i].key}'), leg: shown[i], now: now) : _Pass(key: ValueKey('leg-pass-${shown[i].key}'), leg: shown[i], now: now),
                ),
              ),
            ),
          ),
        ],
        if (hidden > 0 || _all && legs.length > TravelLegs.shownByDefault)
          TextButton(
            key: const ValueKey('travel-more'),
            onPressed: () => setState(() => _all = !_all),
            child: Text(_all ? 'Show less' : 'Show $hidden more'),
          ),
      ],
    );
  }
}

/// The small heading over a leg and its day: "UPCOMING · Mon, Nov 16". The
/// state is green, yellow for a delay, red for a cancellation.
class _Heading extends StatelessWidget {
  const _Heading({required this.leg, required this.now});
  final TripLeg leg;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final label = sectionLabel(context);
    final dep = leg.departs;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(leg.headingAt(now).toUpperCase(), key: ValueKey('leg-heading-${leg.key}'), style: label.copyWith(color: tripColor(leg))),
        if (dep != null) ...[
          Text(' · ', style: label),
          Text(tripDay(dep), key: ValueKey('leg-day-${leg.key}'), style: label.copyWith(letterSpacing: 0.4)),
        ],
      ],
    );
  }
}

/// A time, or for a delay the old time struck through with the new one
/// beside it in the delay's color.
class _Times extends StatelessWidget {
  const _Times({required this.now, this.was, required this.style, required this.color, this.id, this.end = false});
  final LocalTime? now;
  final LocalTime? was;
  final TextStyle style;
  final Color color;
  final String? id;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final current = tripClock(now);
    final old = was == null || tripClock(was) == current ? '' : tripClock(was);
    if (old.isEmpty) return Text(current.isEmpty ? '–' : current, key: id == null ? null : ValueKey<String>(id!), style: style);
    return Wrap(
      spacing: 6,
      alignment: end ? WrapAlignment.end : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(old, key: id == null ? null : ValueKey<String>('$id-was'), style: style.copyWith(decoration: TextDecoration.lineThrough, color: style.color?.withValues(alpha: 0.7))),
        Text(current.isEmpty ? '–' : current, key: id == null ? null : ValueKey<String>(id!), style: style.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// When it leaves, on the left, and when it arrives, on the right (with the
/// day, when that is a different one).
class _TimesRow extends StatelessWidget {
  const _TimesRow({required this.leg});
  final TripLeg leg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tripColor(leg);
    final dep = leg.departs;
    final arr = leg.arrives;
    final style = rowTitle(context).copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant, fontFeatures: tabularFigures, decoration: leg.cancelled ? TextDecoration.lineThrough : null);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Times(now: dep, was: leg.delayed ? leg.wasDeparts : null, style: style, color: color, id: 'leg-dep-${leg.key}')),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Times(now: arr, was: leg.delayed ? leg.wasArrives : null, style: style, color: color, id: 'leg-arr-${leg.key}', end: true),
              if (dep != null && arr != null && !dep.sameDay(arr)) Text(tripDay(arr), key: ValueKey('leg-nextday-${leg.key}'), style: rowSmall(context)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckIn extends StatelessWidget {
  const _CheckIn({required this.leg});
  final TripLeg leg;

  static bool offered(TripLeg leg) {
    final uri = Uri.tryParse(leg.checkInUrl);
    return leg.state == 'checkin' && uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  @override
  Widget build(BuildContext context) {
    if (!offered(leg)) return const SizedBox.shrink();
    final uri = Uri.parse(leg.checkInUrl);
    return FilledButton.tonalIcon(
      key: ValueKey('leg-checkin-${leg.key}'),
      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.how_to_reg_outlined, size: 16),
      label: const Text('Check in'),
    );
  }
}

/// A leg more than two days off, or any leg after the first: a compact
/// boarding pass. Everything the large one says, in a third of the room.
class _Pass extends StatelessWidget {
  const _Pass({super.key, required this.leg, required this.now});
  final TripLeg leg;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final label = sectionLabel(context);
    final small = rowSmall(context);
    final length = leg.duration;
    final codes = text.headlineMedium!.copyWith(fontSize: 30, fontWeight: FontWeight.w400, height: 1, letterSpacing: 0.3, color: leg.cancelled ? scheme.onSurfaceVariant : scheme.onSurface, decoration: leg.cancelled ? TextDecoration.lineThrough : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _Heading(leg: leg, now: now)),
            if (leg.number.isNotEmpty) Text(leg.number, key: ValueKey('leg-number-${leg.key}'), style: label.copyWith(letterSpacing: 0.4)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(leg.fromCode.isEmpty ? '–' : leg.fromCode, key: ValueKey('leg-from-${leg.key}'), style: codes),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    SizedBox(height: 18, child: CustomPaint(size: Size.infinite, painter: _LinePainter(color: tripColor(leg), glyphColor: scheme.onSurface, train: leg.mode == 'train'))),
                    if (length != null) Text(tripLength(length), key: ValueKey('leg-length-${leg.key}'), style: small.copyWith(fontSize: 10.5, height: 1.1)),
                  ],
                ),
              ),
            ),
            Text(leg.toCode.isEmpty ? '–' : leg.toCode, key: ValueKey('leg-to-${leg.key}'), style: codes),
          ],
        ),
        const SizedBox(height: 4),
        _TimesRow(leg: leg),
        const SizedBox(height: 6),
        Text(leg.route, key: ValueKey('leg-route-${leg.key}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: small),
        const SizedBox(height: 9),
        const _DashRule(),
        const SizedBox(height: 9),
        _PassFoot(leg: leg),
        if (_CheckIn.offered(leg)) Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: Alignment.centerRight, child: _CheckIn(leg: leg))),
      ],
    );
  }
}

/// The foot of a pass: who flies it on the left, the confirmation code on
/// the right (it can be selected and copied).
class _PassFoot extends StatelessWidget {
  const _PassFoot({required this.leg});
  final TripLeg leg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = rowSmall(context);
    return Row(
      children: [
        Expanded(child: Text(leg.carrier.isEmpty ? (leg.mode == 'train' ? 'Train' : 'Flight') : leg.carrier, key: ValueKey('leg-carrier-${leg.key}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: small)),
        const SizedBox(width: 10),
        Text('Confirmation ', style: small),
        SelectableText(leg.locator.isEmpty ? '–' : leg.locator, key: ValueKey('leg-conf-${leg.key}'), maxLines: 1, style: small.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w500, letterSpacing: 0.6)),
      ],
    );
  }
}

/// The first leg within two days of leaving, or one delayed or cancelled:
/// drawn large.
class _BigLeg extends StatelessWidget {
  const _BigLeg({super.key, required this.leg, required this.now});
  final TripLeg leg;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = tripColor(leg);
    final length = leg.duration;
    final codes = text.displaySmall!.copyWith(fontSize: 40, fontWeight: FontWeight.w400, height: 1, letterSpacing: 0.3, color: leg.cancelled ? scheme.onSurfaceVariant : scheme.onSurface, decoration: leg.cancelled ? TextDecoration.lineThrough : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _Heading(leg: leg, now: now)),
            _CheckIn(leg: leg),
          ],
        ),
        const SizedBox(height: 7),
        Text(leg.route, key: ValueKey('leg-route-${leg.key}'), style: text.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2, color: scheme.onSurface)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(leg.fromCode.isEmpty ? '–' : leg.fromCode, key: ValueKey('leg-from-${leg.key}'), style: codes),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _ArcPainter(color: color, badge: scheme.onSurface, glyphColor: scheme.surface, train: leg.mode == 'train'),
                      ),
                    ),
                    if (length != null) Text(tripLength(length), key: ValueKey('leg-length-${leg.key}'), style: rowSmall(context)),
                  ],
                ),
              ),
            ),
            Text(leg.toCode.isEmpty ? '–' : leg.toCode, key: ValueKey('leg-to-${leg.key}'), style: codes),
          ],
        ),
        const SizedBox(height: 8),
        _TimesRow(leg: leg),
        const SizedBox(height: 12),
        const _DashRule(),
        const SizedBox(height: 11),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Pair(top: 'Confirmation', bottom: leg.locator.isEmpty ? '–' : leg.locator, id: 'leg-conf-${leg.key}')),
            const SizedBox(width: 10),
            Expanded(child: _Pair(top: leg.carrier.isEmpty ? (leg.mode == 'train' ? 'Train' : 'Flight') : leg.carrier, bottom: leg.number.isEmpty ? '–' : leg.number, id: 'leg-number-${leg.key}')),
          ],
        ),
      ],
    );
  }
}

/// A small label with its value under it, at the foot of the large leg.
class _Pair extends StatelessWidget {
  const _Pair({required this.top, required this.bottom, required this.id});
  final String top;
  final String bottom;
  final String id;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(top.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: sectionLabel(context).copyWith(letterSpacing: 0.8)),
        const SizedBox(height: 1),
        SelectableText(bottom, key: ValueKey(id), maxLines: 1, style: rowTitle(context).copyWith(letterSpacing: 0.4)),
      ],
    );
  }
}

/// A thin dashed rule, like the tear line on a pass.
class _DashRule extends StatelessWidget {
  const _DashRule();

  @override
  Widget build(BuildContext context) => SizedBox(height: 1, child: CustomPaint(size: Size.infinite, painter: _DashPainter(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.16))));
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0.5), Offset(math.min(x + 4, size.width), 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// A straight dashed line from one airport code to the other, ending in a
/// plane (or a train).
class _LinePainter extends CustomPainter {
  const _LinePainter({required this.color, required this.glyphColor, required this.train});
  final Color color;
  final Color glyphColor;
  final bool train;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final stop = size.width - 20;
    for (var x = 1.0; x < stop; x += 11) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, stop), y), paint);
    }
    final icon = train ? Icons.train_rounded : Icons.flight_rounded;
    final glyph = TextPainter(
      text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 18, color: glyphColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(size.width - 9, y);
    // A plane pointing the way it is going.
    if (!train) canvas.rotate(math.pi / 2);
    glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.color != color || old.glyphColor != glyphColor || old.train != train;
}

/// A dashed arc from one airport code to the other, ending in a small
/// round badge with a plane (or a train) in it.
class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.color, required this.badge, required this.glyphColor, required this.train});
  final Color color;
  final Color badge;
  final Color glyphColor;
  final bool train;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 11.0;
    final start = Offset(4, size.height - 4);
    final end = Offset(size.width - r - 2, size.height - r + 2);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(size.width * 0.45, -size.height * 0.55, end.dx - r, end.dy - 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      const dash = 11.0;
      const gap = 8.0;
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(metric.extractPath(at, math.min(at + dash, metric.length)), paint);
        at += dash + gap;
      }
    }
    canvas.drawCircle(end, r, Paint()..color = badge);
    final icon = train ? Icons.train_rounded : Icons.flight_rounded;
    final glyph = TextPainter(
      text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 15, color: glyphColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(end.dx, end.dy);
    // A plane pointing the way it is going.
    if (!train) canvas.rotate(math.pi / 2);
    glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color || old.badge != badge || old.glyphColor != glyphColor || old.train != train;
}

/// The Bookings card's lines: a hotel stay, a rental car, a car with a
/// driver, a restaurant table, an appointment, a ticket.
class BookingLines extends ConsumerStatefulWidget {
  const BookingLines({super.key, required this.items});
  final List<(HelperCard, Booking)> items;

  static const shownByDefault = 4;

  @override
  ConsumerState<BookingLines> createState() => _BookingLinesState();
}

class _BookingLinesState extends ConsumerState<BookingLines> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final shown = _all ? items : items.take(BookingLines.shownByDefault).toList();
    final hidden = items.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)),
          _BookingLine(key: ValueKey('booking-line-${shown[i].$1.k}'), row: shown[i].$1, booking: shown[i].$2),
        ],
        if (hidden > 0 || _all && items.length > BookingLines.shownByDefault)
          TextButton(
            key: const ValueKey('bookings-more'),
            onPressed: () => setState(() => _all = !_all),
            child: Text(_all ? 'Show less' : 'Show $hidden more'),
          ),
      ],
    );
  }
}

class _BookingLine extends ConsumerStatefulWidget {
  const _BookingLine({super.key, required this.row, required this.booking});
  final HelperCard row;
  final Booking booking;

  @override
  ConsumerState<_BookingLine> createState() => _BookingLineState();
}

class _BookingLineState extends ConsumerState<_BookingLine> {
  bool _over = false;

  Booking get b => widget.booking;
  String get k => widget.row.k;

  static IconData _icon(String type) => switch (type) {
        'hotel' => Icons.hotel_outlined,
        'car_rental' => Icons.car_rental_outlined,
        'car_service' => Icons.local_taxi_outlined,
        'restaurant' => Icons.restaurant_outlined,
        'appointment' => Icons.event_outlined,
        'event' => Icons.confirmation_number_outlined,
        _ => Icons.bookmark_border_rounded,
      };

  static String _when(LocalTime? t) => t == null ? '' : (t.hasClock ? '${tripDay(t)} ${tripClock(t)}' : tripDay(t));

  /// What it is headed by.
  String get _title => switch (b.type) {
        'hotel' => [b.name.isEmpty ? 'Hotel' : b.name, if (b.place.isNotEmpty) b.place].join(' · '),
        'car_service' => [b.name.isEmpty ? 'Car service' : b.name, if (b.person.isNotEmpty) 'Driver ${b.person}'].join(' · '),
        _ => b.name.isEmpty ? b.typeName : b.name,
      };

  /// A stay or a rental runs over days: its line gives both ends in full,
  /// and the right of the line gives the days ("Mon", "to Wed").
  bool get _spans => b.type == 'hotel' || b.type == 'car_rental';

  /// When, in the words that fit what it is. For anything with one start,
  /// the day and time are on the right of the line, so this holds only what
  /// that leaves out.
  String get _times {
    final from = _when(b.starts);
    final to = _when(b.ends);
    return switch (b.type) {
      'hotel' => [if (from.isNotEmpty) 'Check-in $from', if (to.isNotEmpty) 'Check-out $to'].join(' · '),
      'car_rental' => [if (from.isNotEmpty) 'Pick-up $from', if (to.isNotEmpty) 'Drop-off $to'].join(' · '),
      'car_service' => b.starts == null ? '' : 'Pick-up ${tripDay(b.starts!)}',
      'restaurant' => [if (b.starts != null) tripDay(b.starts!), if (b.party.isNotEmpty) 'Party of ${b.party}'].join(' · '),
      _ => [if (b.starts != null) tripDay(b.starts!), if (to.isNotEmpty && b.ends != null && b.starts != null && b.ends!.sameDay(b.starts!)) 'until ${tripClock(b.ends)}'].join(' '),
    };
  }

  /// Where, the number, and who to call.
  String get _rest => [
        if (b.type == 'car_service' || b.type == 'car_rental')
          [b.place, if (b.to.isNotEmpty) b.to].where((s) => s.isNotEmpty).join(' → ')
        else if (b.type != 'hotel' && b.place.isNotEmpty)
          b.place,
        if (b.address.isNotEmpty) b.address,
        if (b.conf.isNotEmpty) 'Confirmation ${b.conf}',
        if (b.phone.isNotEmpty) b.phone,
      ].where((s) => s.isNotEmpty).join(' · ');

  void _dismiss(BuildContext context) {
    final db = ref.read(databaseProvider);
    db.setCardDismissed(k, true);
    sayDone(context, 'Taken off Bookings.', undo: () => db.setCardDismissed(k, false));
  }

  Future<void> _later(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final was = widget.row.laterUntil;
    final until = await showSnoozePicker(context);
    if (until == null || until == SnoozeChoice.unsnooze || !context.mounted) return;
    await db.setCardLater(k, until);
    if (!context.mounted) return;
    sayDone(context, 'Put off until ${describeSnooze(until)}. It comes back to Bookings then.', undo: () => db.setCardLater(k, was));
  }

  List<MenuChoice> _menu(BuildContext context) {
    final db = ref.read(databaseProvider);
    final what = '${b.typeName}: ${b.name}'.trim();
    return [
      MenuChoice('dismiss', kDismiss, Icons.close_rounded, () => _dismiss(context)),
      MenuChoice('later', kLater, Icons.snooze_rounded, () => _later(context)),
      MenuChoice('reject', kReject, Icons.block_rounded, () {
        db.setCardRejected(k, true, what);
        sayDone(context, 'Taken off Bookings. The assistant is shown it, to learn what kind of thing does not belong here.', undo: () => db.setCardRejected(k, false, what));
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final small = rowSmall(context);
    final touch = ref.watch(isTouchDeviceProvider);
    final now = DateTime.now();
    final heading = b.headingAt(now);
    final times = _times;
    final rest = _rest;
    // On the right: the time it starts with its day under it (only the day
    // when no time is known); for a stay or a rental, its days.
    final starts = b.starts;
    final day = starts == null ? '' : dayWord(starts.wall, now);
    final top = starts == null ? '' : (starts.hasClock && !_spans ? tripClock(starts) : day);
    final bottom = starts == null ? '' : (_spans ? (b.ends == null ? '' : 'to ${dayWord(b.ends!.wall, now)}') : (starts.hasClock ? day : ''));
    return MouseRegion(
      onEnter: (_) => setState(() => _over = true),
      onExit: (_) => setState(() => _over = false),
      child: InkWell(
        key: ValueKey('booking-$k'),
        onTap: () => unawaited(openEmailByMessageId(ref, b.messageId)),
        onTapDown: (d) => lastPressAt = d.globalPosition,
        onSecondaryTapUp: (d) => showItemMenu(context, d.globalPosition, _menu(context)),
        onLongPress: () => showItemMenu(context, lastPressAt, _menu(context)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: RowIcon(_icon(b.type), color: b.cancelled ? badColor : null)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Said only when it is news: just confirmed, changed, cancelled.
                    if (heading != 'Upcoming')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(heading.toUpperCase(), key: ValueKey('booking-heading-$k'), style: sectionLabel(context, color: b.cancelled ? badColor : null)),
                      ),
                    Text(_title, key: ValueKey('booking-title-$k'), maxLines: 2, overflow: TextOverflow.ellipsis, style: rowTitle(context).copyWith(decoration: b.cancelled ? TextDecoration.lineThrough : null)),
                    if (times.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(times, key: ValueKey('booking-when-$k'), maxLines: 3, overflow: TextOverflow.ellipsis, style: small)),
                    if (rest.isNotEmpty) Text(rest, key: ValueKey('booking-rest-$k'), maxLines: 4, overflow: TextOverflow.ellipsis, style: small),
                  ],
                ),
              ),
              if (top.isNotEmpty) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(top, key: ValueKey('booking-at-$k'), style: rowTitle(context).copyWith(fontFeatures: tabularFigures, decoration: b.cancelled ? TextDecoration.lineThrough : null)),
                    if (bottom.isNotEmpty) Text(bottom, key: ValueKey('booking-day-$k'), style: small),
                  ],
                ),
              ],
              if (!touch)
                Opacity(
                  opacity: _over ? 1 : 0,
                  child: IconButton(
                    key: ValueKey('booking-dismiss-$k'),
                    tooltip: 'Dismiss',
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _dismiss(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
