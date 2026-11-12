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

/// Items that should show at [now], most urgent first: codes, then whatever
/// comes soonest.
List<TimelyItem> timelyDue(List<TimelyItem> items, DateTime now) {
  final due = [for (final i in items) if (!i.showFrom.isAfter(now) && i.hideAfter.isAfter(now)) i];
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
