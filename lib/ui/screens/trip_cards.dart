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
Color tripColor(TripLeg l) => l.cancelled ? const Color(0xFFEF5350) : (l.delayed ? const Color(0xFFFFCA28) : const Color(0xFF43A047));

/// The Travel card's lines: the first leg drawn large, with its airport
/// codes and an arc between them; the rest as detailed, smaller and plain.
class TravelLegs extends ConsumerStatefulWidget {
  const TravelLegs({super.key, required this.legs});
  final List<TripLeg> legs;

  static const shownByDefault = 4;

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
          if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
          InkWell(
            key: ValueKey('leg-${shown[i].key}'),
            onTap: () => unawaited(openEmailByMessageId(ref, shown[i].messageId)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(2, i == 0 ? 4 : 9, 4, 9),
              // On a wide page the large leg keeps the width of a phone
              // card, so its arc stays an arc.
              child: i == 0 ? Align(alignment: Alignment.centerLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540), child: _BigLeg(leg: shown[i], now: now))) : _SmallLeg(leg: shown[i], now: now),
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

/// The small heading over a leg: Confirmed, Upcoming, Checked in, Delayed,
/// Cancelled.
class _Heading extends StatelessWidget {
  const _Heading({required this.leg, required this.now});
  final TripLeg leg;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strong = leg.cancelled || leg.delayed;
    return Text(
      leg.headingAt(now).toUpperCase(),
      key: ValueKey('leg-heading-${leg.key}'),
      style: Theme.of(context).textTheme.labelSmall!.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w800, color: strong ? tripColor(leg) : scheme.onSurfaceVariant),
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
        Text(current.isEmpty ? '–' : current, key: id == null ? null : ValueKey<String>(id!), style: style.copyWith(color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _CheckIn extends StatelessWidget {
  const _CheckIn({required this.leg});
  final TripLeg leg;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(leg.checkInUrl);
    if (leg.state != 'checkin' || uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return const SizedBox.shrink();
    return FilledButton.tonalIcon(
      key: ValueKey('leg-checkin-${leg.key}'),
      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.how_to_reg_outlined, size: 16),
      label: const Text('Check in'),
    );
  }
}

/// The first leg, drawn large.
class _BigLeg extends StatelessWidget {
  const _BigLeg({required this.leg, required this.now});
  final TripLeg leg;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final quiet = scheme.onSurfaceVariant;
    final color = tripColor(leg);
    final dep = leg.departs;
    final arr = leg.arrives;
    final nextDay = dep != null && arr != null && !dep.sameDay(arr);
    final length = leg.duration;
    final codes = text.displaySmall!.copyWith(fontWeight: FontWeight.w400, height: 1.05, letterSpacing: 0.5, decoration: leg.cancelled ? TextDecoration.lineThrough : null);
    final under = text.titleMedium!.copyWith(color: quiet, fontWeight: FontWeight.w400);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _Heading(leg: leg, now: now)),
            _CheckIn(leg: leg),
          ],
        ),
        const SizedBox(height: 4),
        Text(leg.route, key: ValueKey('leg-route-${leg.key}'), style: text.titleLarge!.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
        const SizedBox(height: 4),
        if (dep != null)
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(tripDay(dep), key: ValueKey('leg-day-${leg.key}'), style: under),
              if (dep.hasClock) ...[
                Text('•', style: under),
                _Times(now: dep, was: leg.delayed ? leg.wasDeparts : null, style: under, color: color),
                Text('–', style: under),
                _Times(now: arr, was: leg.delayed ? leg.wasArrives : null, style: under, color: color),
                if (nextDay) Text('(${tripDay(arr)})', style: under),
              ],
            ],
          ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(leg.fromCode.isEmpty ? '–' : leg.fromCode, key: ValueKey('leg-from-${leg.key}'), style: codes),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _ArcPainter(color: color, badge: scheme.onSurface, glyphColor: scheme.surface, train: leg.mode == 'train'),
                      ),
                    ),
                    if (length != null) Text(tripLength(length), key: ValueKey('leg-length-${leg.key}'), style: text.titleSmall!.copyWith(color: quiet, fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ),
            Text(leg.toCode.isEmpty ? '–' : leg.toCode, key: ValueKey('leg-to-${leg.key}'), style: codes),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Times(now: dep, was: leg.delayed ? leg.wasDeparts : null, style: under, color: color, id: 'leg-dep-${leg.key}')),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _Times(now: arr, was: leg.delayed ? leg.wasArrives : null, style: under, color: color, id: 'leg-arr-${leg.key}', end: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 6, right: 12), child: Icon(Icons.tag_rounded, size: 22, color: quiet)),
            Expanded(
              child: _Pair(top: 'Confirmation', bottom: leg.locator.isEmpty ? '–' : leg.locator, id: 'leg-conf-${leg.key}'),
            ),
            Expanded(
              child: _Pair(top: leg.carrier.isEmpty ? (leg.mode == 'train' ? 'Train' : 'Flight') : leg.carrier, bottom: leg.number.isEmpty ? '–' : leg.number, id: 'leg-number-${leg.key}'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.top, required this.bottom, required this.id});
  final String top;
  final String bottom;
  final String id;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(top, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
        SelectableText(bottom, key: ValueKey(id), maxLines: 1, style: text.titleSmall!.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400)),
      ],
    );
  }
}

/// A leg after the first: every detail the first has, smaller and plain.
class _SmallLeg extends StatelessWidget {
  const _SmallLeg({required this.leg, required this.now});
  final TripLeg leg;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final quiet = text.bodySmall!.copyWith(color: scheme.onSurfaceVariant);
    final color = tripColor(leg);
    final dep = leg.departs;
    final arr = leg.arrives;
    final nextDay = dep != null && arr != null && !dep.sameDay(arr);
    final length = leg.duration;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 10),
          child: Icon(leg.mode == 'train' ? Icons.train_outlined : Icons.flight_rounded, size: 18, color: color),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Heading(leg: leg, now: now),
              const SizedBox(height: 1),
              Text(
                '${leg.fromCode.isEmpty ? '–' : leg.fromCode} → ${leg.toCode.isEmpty ? '–' : leg.toCode} · ${leg.route}',
                key: ValueKey('leg-route-${leg.key}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge!.copyWith(decoration: leg.cancelled ? TextDecoration.lineThrough : null),
              ),
              if (dep != null)
                Wrap(
                  spacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(tripDay(dep), key: ValueKey('leg-day-${leg.key}'), style: quiet),
                    if (dep.hasClock) ...[
                      Text('·', style: quiet),
                      _Times(now: dep, was: leg.delayed ? leg.wasDeparts : null, style: quiet, color: color, id: 'leg-dep-${leg.key}'),
                      Text('–', style: quiet),
                      _Times(now: arr, was: leg.delayed ? leg.wasArrives : null, style: quiet, color: color, id: 'leg-arr-${leg.key}'),
                      if (nextDay) Text('(${tripDay(arr)})', style: quiet),
                    ],
                    if (length != null) Text('· ${tripLength(length)}', key: ValueKey('leg-length-${leg.key}'), style: quiet),
                  ],
                ),
              Text(
                [
                  [leg.carrier, leg.number].where((s) => s.isNotEmpty).join(' '),
                  if (leg.locator.isNotEmpty) 'Confirmation ${leg.locator}',
                ].where((s) => s.isNotEmpty).join(' · '),
                key: ValueKey('leg-number-${leg.key}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: quiet,
              ),
            ],
          ),
        ),
        _CheckIn(leg: leg),
      ],
    );
  }
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
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      const dash = 12.0;
      const gap = 9.0;
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
          if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
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

  /// When, in the words that fit what it is.
  String get _times {
    final from = _when(b.starts);
    final to = _when(b.ends);
    return switch (b.type) {
      'hotel' => [if (from.isNotEmpty) 'Check-in $from', if (to.isNotEmpty) 'Check-out $to'].join(' · '),
      'car_rental' => [if (from.isNotEmpty) 'Pick-up $from', if (to.isNotEmpty) 'Drop-off $to'].join(' · '),
      'car_service' => from.isEmpty ? '' : 'Pick-up $from',
      'restaurant' => [if (from.isNotEmpty) from, if (b.party.isNotEmpty) 'Party of ${b.party}'].join(' · '),
      _ => [if (from.isNotEmpty) from, if (to.isNotEmpty && b.ends != null && b.starts != null && b.ends!.sameDay(b.starts!)) 'until ${tripClock(b.ends)}'].join(' '),
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final quiet = text.bodySmall!.copyWith(fontSize: 11.5, color: scheme.onSurfaceVariant);
    final touch = ref.watch(isTouchDeviceProvider);
    final heading = b.headingAt(DateTime.now());
    final times = _times;
    final rest = _rest;
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
          padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 2, right: 10), child: Icon(_icon(b.type), size: 20, color: b.cancelled ? const Color(0xFFEF5350) : scheme.primary)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${b.typeName} · $heading'.toUpperCase(),
                      key: ValueKey('booking-heading-$k'),
                      style: text.labelSmall!.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w800, color: b.cancelled ? const Color(0xFFEF5350) : scheme.onSurfaceVariant),
                    ),
                    Text(_title, key: ValueKey('booking-title-$k'), maxLines: 2, overflow: TextOverflow.ellipsis, style: text.labelLarge!.copyWith(decoration: b.cancelled ? TextDecoration.lineThrough : null)),
                    if (times.isNotEmpty) Text(times, key: ValueKey('booking-when-$k'), maxLines: 3, overflow: TextOverflow.ellipsis, style: quiet),
                    if (rest.isNotEmpty) Text(rest, key: ValueKey('booking-rest-$k'), maxLines: 4, overflow: TextOverflow.ellipsis, style: quiet),
                  ],
                ),
              ),
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
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
