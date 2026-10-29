import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/database.dart';
import '../store/people_queries.dart';
import 'account_scope.dart';
import 'destinations.dart';

/// Active filter chip on the People list (spec 4.7). Exactly one.
final peopleFilterProvider = NotifierProvider<PeopleFilterNotifier, PeopleFilter>(PeopleFilterNotifier.new);

class PeopleFilterNotifier extends Notifier<PeopleFilter> {
  @override
  PeopleFilter build() => PeopleFilter.all;
  void select(PeopleFilter f) => state = f;
}

/// Live search text typed into the middle-pane search bar.
final peopleSearchProvider = NotifierProvider<PeopleSearchNotifier, String>(PeopleSearchNotifier.new);

class PeopleSearchNotifier extends Notifier<String> {
  PeopleSearchNotifier({this.initial = ''});
  final String initial;

  @override
  String build() => initial;
  void set(String s) => state = s;
}

/// The selected row key (`c:<contact>` or `g:<id>`), or null.
final selectedRowProvider = NotifierProvider<SelectedRowNotifier, String?>(SelectedRowNotifier.new);

class SelectedRowNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? key) => state = key;
}

/// Rows picked for a bulk action (Ctrl-click, Shift-click, the row
/// checkbox, Ctrl+A). Separate from [selectedRowProvider], which is the one
/// row open in the conversation pane.
final multiSelectProvider = NotifierProvider<MultiSelectNotifier, Set<String>>(MultiSelectNotifier.new);

class MultiSelectNotifier extends Notifier<Set<String>> {
  /// The last row toggled; Shift-click selects from here.
  String? anchor;

  @override
  Set<String> build() => const {};

  void toggle(String key) {
    anchor = key;
    state = state.contains(key) ? ({...state}..remove(key)) : {...state, key};
  }

  /// Adds every row between [anchor] and [key] in [ordered] (the list as
  /// shown). Without an anchor it toggles [key].
  void extendTo(String key, List<String> ordered) {
    final from = anchor == null ? -1 : ordered.indexOf(anchor!);
    final to = ordered.indexOf(key);
    if (from < 0 || to < 0) {
      toggle(key);
      return;
    }
    final lo = from < to ? from : to;
    final hi = from < to ? to : from;
    state = {...state, ...ordered.sublist(lo, hi + 1)};
  }

  void setAll(Iterable<String> keys) => state = keys.toSet();

  void clear() {
    anchor = null;
    state = const {};
  }
}

/// People rows for the current filter and search, live from the database.
final peopleRowsProvider = StreamProvider<List<PeopleRow>>((ref) {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(peopleFilterProvider);
  final search = ref.watch(peopleSearchProvider);
  final mode = ref.watch(inboxModeProvider);
  final scope = ref.watch(accountScopeProvider);
  return db.watchPeopleRows(filter: filter, search: search, tab: mode == InboxMode.feeds ? InboxTab.feeds : InboxTab.people, accountId: scope);
});

/// Dev/verification aid: when true, the list selects its first row and the
/// conversation expands its newest thread once, on first load.
final autoOpenFirstProvider = Provider<bool>((ref) => false);

/// Messages of the selected row, newest first.
final selectedRowMessagesProvider = StreamProvider<List<Message>>((ref) {
  final key = ref.watch(selectedRowProvider);
  if (key == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchMessagesForRow(key, accountId: ref.watch(accountScopeProvider));
});
