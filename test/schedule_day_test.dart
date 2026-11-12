import 'package:convomail/app/mail_state.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/ui/screens/today_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_db.dart';

final _day = NotifierProvider<_Day, DateTime>(_Day.new);

class _Day extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime(2026, 11, 11);
  void set(DateTime d) => state = d;
}

/// The Schedule card on Today shows today, also when Précis has been left
/// open since yesterday.
void main() {
  test('left open overnight, the Schedule card moves on to the new day: yesterday\'s meeting is gone', () async {
    final db = testDatabase();
    addTearDown(db.close);
    await db.into(db.plannerEvents).insert(PlannerEventsCompanion.insert(title: 'Zoom with Mariah', kind: 'google', startAt: Value(DateTime(2026, 11, 11, 15)), endAt: Value(DateTime(2026, 11, 11, 16))));
    await db.into(db.plannerEvents).insert(PlannerEventsCompanion.insert(title: 'Dentist', kind: 'google', startAt: Value(DateTime(2026, 11, 13, 9)), endAt: Value(DateTime(2026, 11, 13, 10))));
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) => db),
      todayDateProvider.overrideWith((ref) => ref.watch(_day)),
    ]);
    addTearDown(c.dispose);
    final sub = c.listen(todayEventsProvider, (_, _) {});
    addTearDown(sub.close);

    Future<List<String>> titles() async => [for (final e in await c.read(todayEventsProvider.future)) e.title];

    expect(await titles(), ['Zoom with Mariah']);
    // Midnight passes with the app open.
    c.read(_day.notifier).set(DateTime(2026, 11, 12));
    expect(await titles(), isEmpty, reason: 'nothing is on the calendar today');
    c.read(_day.notifier).set(DateTime(2026, 11, 13));
    expect(await titles(), ['Dentist']);
  });
}
