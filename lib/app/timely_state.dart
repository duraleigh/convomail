import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/database.dart';
import '../store/helper_queries.dart';
import '../store/timely_queries.dart';
import 'account_scope.dart';

/// Timely items not dismissed, in the selected account (spec 4.21). The
/// strip applies the time window, which moves on while the app runs.
final timelyItemsProvider = StreamProvider<List<TimelyItem>>((ref) {
  // What the user said does not belong under FYI is left out.
  final off = ref.watch(fyiOffProvider).value ?? const <String>{};
  return ref.watch(databaseProvider).watchTimelyItems(accountId: ref.watch(accountScopeProvider)).map((items) => [
        for (final i in items)
          if (!off.contains('${i.type}|${i.contactKey}')) i,
      ]);
});

/// The kinds of notice, by sender, the user said do not belong under FYI.
final fyiOffProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.settings)..where((s) => s.key.equals(kFyiOff))).watchSingleOrNull().map((row) => HelperQueries.decodeFyiOff(row?.value));
});

/// The cards on the Précis page that hold what the fixed rules find in mail.
/// (Travel and Bookings are filled by the assistant when it is on; the
/// rules fill them, with less to say, when it is not.)
enum FyiCard {
  otp('otp', 'OTP'),
  travel('travel', 'Travel'),
  bookings('bookings', 'Bookings'),
  deliveries('deliveries', 'Deliveries'),
  payments('payments', 'Payments'),
  fyi('fyi', 'FYI');

  const FyiCard(this.id, this.title);
  final String id;
  final String title;

  /// The card a kind of item (a [TimelyType] name) sits on.
  static FyiCard of(String type) => switch (type) {
        'code' || 'confirm' => FyiCard.otp,
        'flight' || 'train' => FyiCard.travel,
        'hotel' || 'car' || 'event' => FyiCard.bookings,
        'delivery' => FyiCard.deliveries,
        'bill' => FyiCard.payments,
        _ => FyiCard.fyi,
      };
}

/// Items that should show at [now], most urgent first: codes, then whatever
/// comes soonest. With [card], only that card's.
List<TimelyItem> timelyDue(List<TimelyItem> items, DateTime now, {FyiCard? card}) {
  // A delivered package stays, marked "Delivered", until the end of the day
  // it came. (Worked out here as well as when it is stored, so one stored by
  // an older version of the app on another device shows the same.)
  DateTime until(TimelyItem i) {
    if (i.type != 'delivery' || i.status != 'delivered') return i.hideAfter;
    final came = i.mailAt ?? i.showFrom;
    final midnight = DateTime(came.year, came.month, came.day + 1);
    return midnight.isAfter(i.hideAfter) ? midnight : i.hideAfter;
  }

  final due = [
    for (final i in items)
      if (!i.showFrom.isAfter(now) && until(i).isAfter(now) && !(i.laterUntil?.isAfter(now) ?? false) && (card == null || FyiCard.of(i.type) == card)) i,
  ];
  int rank(TimelyItem i) => i.type == 'code' ? 0 : 1;
  due.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    if (a.type == 'code') return b.showFrom.compareTo(a.showFrom);
    final at = a.startsAt ?? a.hideAfter;
    final bt = b.startsAt ?? b.hideAfter;
    return at.compareTo(bt);
  });
  return due;
}
