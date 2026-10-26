import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/database.dart';
import '../store/people_queries.dart';
import '../store/planner_queries.dart';

/// Something the app wants to tell the user now: a snooze ended, a
/// reminder is due. Shown in-app (snackbar); M10 turns these into toasts.
class AppNotice {
  const AppNotice({required this.id, required this.title, this.body = '', this.rowKey, this.messageId, this.eventId, required this.at});
  final String id;
  final String title;
  final String body;
  final String? rowKey;
  final int? messageId;
  final int? eventId;
  final DateTime at;
}

final appNoticesProvider = NotifierProvider<AppNoticesNotifier, List<AppNotice>>(AppNoticesNotifier.new);

class AppNoticesNotifier extends Notifier<List<AppNotice>> {
  @override
  List<AppNotice> build() => const [];
  void add(AppNotice n) => state = [...state, n];
  void remove(String id) => state = [for (final n in state) if (n.id != id) n];
  void clear() => state = const [];
}

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  final s = ScheduleService(ref);
  ref.onDispose(s.stop);
  return s;
});

/// Periodic check for due snoozes and reminders (spec 4.9). Runs every 30
/// seconds while the app is open; [tick] is also called directly by tests.
class ScheduleService {
  ScheduleService(this._ref);
  final Ref _ref;
  Timer? _timer;

  AppDatabase get _db => _ref.read(databaseProvider);

  void start({Duration every = const Duration(seconds: 30)}) {
    _timer ??= Timer.periodic(every, (_) => unawaited(tick(DateTime.now())));
    unawaited(tick(DateTime.now()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Resurfaces rows whose snooze ended and fires due reminders. Returns
  /// the notices raised.
  Future<List<AppNotice>> tick(DateTime now) async {
    final raised = <AppNotice>[];
    final notices = _ref.read(appNoticesProvider.notifier);

    final resurfaced = await _db.resurfaceDueSnoozes(now);
    for (final key in resurfaced) {
      final rows = await _db.peopleRows();
      final row = rows.where((r) => r.rowKey == key).firstOrNull;
      final n = AppNotice(id: 'snooze:$key:${now.millisecondsSinceEpoch}', title: 'Back from snooze', body: row?.title ?? key, rowKey: key, at: now);
      raised.add(n);
    }

    for (final r in await _db.dueReminders(now)) {
      await _db.markReminderFired(r.id, now);
      raised.add(AppNotice(id: 'reminder:${r.id}', title: 'Reminder', body: r.title, rowKey: r.rowKey, messageId: r.messageId, at: now));
    }

    for (final n in raised) {
      notices.add(n);
    }
    return raised;
  }
}
