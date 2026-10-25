import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/database.dart';
import '../store/people_queries.dart';

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

/// People rows for the current filter and search, live from the database.
final peopleRowsProvider = StreamProvider<List<PeopleRow>>((ref) {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(peopleFilterProvider);
  final search = ref.watch(peopleSearchProvider);
  return db.watchPeopleRows(filter: filter, search: search);
});

/// Dev/verification aid: when true, the list selects its first row and the
/// conversation expands its newest thread once, on first load.
final autoOpenFirstProvider = Provider<bool>((ref) => false);

/// Messages of the selected row, newest first.
final selectedRowMessagesProvider = StreamProvider<List<Message>>((ref) {
  final key = ref.watch(selectedRowProvider);
  if (key == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchMessagesForRow(key);
});
