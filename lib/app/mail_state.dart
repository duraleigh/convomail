import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/piles.dart';
import '../store/database.dart';
import '../store/mail_queries.dart';
import 'account_scope.dart';

/// Every inbox email that is not from a person, newest first.
final otherMailProvider = StreamProvider<List<MailItem>>((ref) => ref.watch(databaseProvider).watchOtherMail(accountId: ref.watch(accountScopeProvider)));

/// Feed: the emails worth knowing. Decided for each email, not each sender.
final feedMailProvider = Provider<List<MailItem>>((ref) => [
      for (final i in ref.watch(otherMailProvider).value ?? const <MailItem>[])
        if (i.pile == FeedsPile.feed) i,
    ]);

/// Noise: everything that never needed the user.
final noiseMailProvider = Provider<List<MailItem>>((ref) => [
      for (final i in ref.watch(otherMailProvider).value ?? const <MailItem>[])
        if (i.pile == FeedsPile.noise) i,
    ]);

/// Ticks every half minute. An email put off until a time comes back into
/// Focus when the clock passes it, without anything else having to change.
final focusClockProvider = StreamProvider<int>((ref) => Stream.periodic(const Duration(seconds: 30), (n) => n + 1));

/// Focus: the emails that need the user.
final focusMailProvider = StreamProvider<List<MailItem>>((ref) {
  ref.watch(focusClockProvider);
  return ref.watch(databaseProvider).watchFocus(accountId: ref.watch(accountScopeProvider));
});

/// Focus emails put off until later, soonest back first.
final focusLaterProvider = StreamProvider<List<MailItem>>((ref) {
  ref.watch(focusClockProvider);
  return ref.watch(databaseProvider).watchFocusLater(accountId: ref.watch(accountScopeProvider));
});

/// Focus emails marked done today.
final focusDoneTodayProvider = StreamProvider<List<MailItem>>((ref) => ref.watch(databaseProvider).watchFocusDoneToday(accountId: ref.watch(accountScopeProvider)));

/// One email as the lists see it, for the sentence and the "?" on it.
final mailItemProvider = StreamProvider.family<MailItem?, int>((ref, id) => ref.watch(databaseProvider).watchMailItem(id));

/// Whether the assistant's readings are being shown at all.
final readingsShownProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        "SELECT (SELECT connected FROM helper_state WHERE id = 1) AS c, (SELECT value FROM settings WHERE key = 'helper.assistantOn') AS a",
        readsFrom: {db.helperState, db.settings},
      )
      .watchSingle()
      .map((r) => (r.data['c'] == 1) && r.data['a'] == '1');
});

/// The email open beside the Focus list, the Feed list and the Noise list,
/// each remembered apart ('focus' | 'feed' | 'noise').
final openMailProvider = NotifierProvider.family<OpenMailNotifier, int?, String>(OpenMailNotifier.new);

class OpenMailNotifier extends Notifier<int?> {
  OpenMailNotifier(this.list);
  final String list;

  @override
  int? build() => null;
  void open(int? id) => state = id;
}

/// Focus rows the user has just dealt with in the list (Done or Not Focus),
/// so they leave at once, before the change has been written.
final focusDealtProvider = NotifierProvider<FocusDealtNotifier, Set<int>>(FocusDealtNotifier.new);

class FocusDealtNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};
  void add(int id) => state = {...state, id};
  void remove(int id) => state = {...state}..remove(id);

  /// Forgets rows that are no longer in Focus anyway.
  void keepOnly(Set<int> ids) {
    final kept = state.intersection(ids);
    if (kept.length != state.length) state = kept;
  }
}

/// The tag pill chosen at the top of Feed or Noise; null is "All".
final mailTagProvider = NotifierProvider.family<MailTagNotifier, String?, String>(MailTagNotifier.new);

class MailTagNotifier extends Notifier<String?> {
  MailTagNotifier(this.list);
  final String list;

  @override
  String? build() => null;
  void select(String? tag) => state = tag;
}

/// The sender (or group of small senders) open in Noise.
final openNoiseGroupProvider = NotifierProvider<OpenNoiseGroupNotifier, String?>(OpenNoiseGroupNotifier.new);

class OpenNoiseGroupNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String? key) => state = key;
}
