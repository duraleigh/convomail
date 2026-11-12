import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../domain/piles.dart';
import '../store/classification_queries.dart';
import '../store/database.dart' hide ClassificationRule;
import '../store/mail_queries.dart';
import '../store/people_queries.dart';
import 'account_scope.dart';
import 'destinations.dart';

/// Active filter chip on the People list (spec 4.7). Exactly one.
final peopleFilterProvider = NotifierProvider<PeopleFilterNotifier, PeopleFilter>(PeopleFilterNotifier.new);

class PeopleFilterNotifier extends Notifier<PeopleFilter> {
  @override
  PeopleFilter build() => ref.read(_filterMemoryProvider)[ref.watch(inboxModeProvider)] ?? PeopleFilter.all;
  void select(PeopleFilter f) {
    ref.read(_filterMemoryProvider)[ref.read(inboxModeProvider)] = f;
    state = f;
  }
}

/// What Chats and Feeds each last had open, so switching between them returns
/// to where the user was. Kept apart from the notifiers, which rebuild when
/// the mode changes.
final _filterMemoryProvider = Provider<Map<InboxMode, PeopleFilter>>((ref) => {});
final _searchMemoryProvider = Provider<Map<InboxMode, String>>((ref) => {});
final _selectedMemoryProvider = Provider<Map<InboxMode, String?>>((ref) => {});

/// Live search text typed into the middle-pane search bar.
final peopleSearchProvider = NotifierProvider<PeopleSearchNotifier, String>(PeopleSearchNotifier.new);

class PeopleSearchNotifier extends Notifier<String> {
  PeopleSearchNotifier({this.initial = ''});
  final String initial;

  @override
  String build() => ref.read(_searchMemoryProvider)[ref.watch(inboxModeProvider)] ?? initial;
  void set(String s) {
    ref.read(_searchMemoryProvider)[ref.read(inboxModeProvider)] = s;
    state = s;
  }
}

/// The selected row key (`c:<contact>` or `g:<id>`), or null.
final selectedRowProvider = NotifierProvider<SelectedRowNotifier, String?>(SelectedRowNotifier.new);

class SelectedRowNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(_selectedMemoryProvider)[ref.watch(inboxModeProvider)];
  void select(String? key) {
    ref.read(_selectedMemoryProvider)[ref.read(inboxModeProvider)] = key;
    state = key;
  }
}

/// Opens a row from anywhere (a toast, a line on Today), on Feed or Noise
/// when it belongs there and on Chats otherwise. [read] is `ref.read`. A null key
/// just goes to Chats.
Future<void> openRow(T Function<T>(ProviderListenable<T>) read, String? key, {bool fromToday = false}) async {
  var destination = Destination.chats;
  if (key != null) {
    final db = read(databaseProvider);
    var pile = await db.rowPile(key);
    if (pile != null) {
      // Feed or Noise is settled for each email: go where its newest one is.
      final newest = (await db.watchOtherMail().first).where((i) => i.rowKey == key).firstOrNull;
      pile = newest?.pile ?? pile;
    }
    destination = switch (pile) {
      FeedsPile.feed => Destination.feed,
      FeedsPile.noise => Destination.noise,
      null => Destination.chats,
    };
  }
  read(destinationProvider.notifier).select(destination, fromToday: fromToday);
  if (key != null) read(selectedRowProvider.notifier).select(key);
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

/// The category picked in the pills on the Feeds screen; null is All.
final feedsCategoryFilterProvider = NotifierProvider<FeedsCategoryFilter, String?>(FeedsCategoryFilter.new);

class FeedsCategoryFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? category) => state = category;
}

final _categoriesInUseProvider = StreamProvider<List<String>>((ref) => ref.watch(databaseProvider).watchCategoriesInUse(accountId: ref.watch(accountScopeProvider)));

/// Every row of one list, whatever is typed in search or picked in the
/// pills: Chats, Feed or Noise.
final listRowsProvider = StreamProvider.family<List<PeopleRow>, InboxTab>((ref, tab) => ref.watch(databaseProvider).watchPeopleRows(tab: tab, accountId: ref.watch(accountScopeProvider)));

/// Categories with mail in the list being shown (Feed or Noise), for its
/// pills, in their configured order.
final feedsCategoriesInUseProvider = FutureProvider<List<String>>((ref) async {
  final mode = ref.watch(inboxModeProvider);
  if (!mode.isFeeds) return const [];
  final ordered = await ref.watch(_categoriesInUseProvider.future);
  final rows = await ref.watch(listRowsProvider(mode.tab).future);
  final here = {for (final r in rows) r.rowKey};
  final byCategory = await ref.watch(databaseProvider).rowKeysByCategory();
  return [for (final c in ordered) if ((byCategory[c] ?? const <String>{}).any(here.contains)) c];
});

/// How many emails Noise took in over the last seven days. Null until the
/// whole count is known.
final noiseThisWeekProvider = FutureProvider<int>((ref) async {
  final rows = await ref.watch(listRowsProvider(InboxTab.noise).future);
  return ref.watch(databaseProvider).countReceivedSince([for (final r in rows) r.rowKey], DateTime.now().subtract(const Duration(days: 7)));
});

/// Order of the Chats and Feeds lists, kept across restarts.
final peopleSortProvider = AsyncNotifierProvider<PeopleSortNotifier, PeopleSort>(PeopleSortNotifier.new);

class PeopleSortNotifier extends AsyncNotifier<PeopleSort> {
  static const key = 'list.sort';

  @override
  Future<PeopleSort> build() async {
    final saved = await ref.read(databaseProvider).getSetting(key);
    return PeopleSort.values.where((s) => s.name == saved).firstOrNull ?? PeopleSort.newest;
  }

  Future<void> select(PeopleSort sort) async {
    state = AsyncData(sort);
    await ref.read(databaseProvider).putSetting(key, sort.name);
  }
}

/// How many chats have mail from a person that has not been read. Chats
/// put off until later and muted ones do not count. Any at all puts a dot
/// on the Chats icon, so unread mail from people is never out of sight
/// just because Focus is empty.
final chatsUnreadProvider = Provider<int>((ref) {
  var n = 0;
  for (final r in ref.watch(listRowsProvider(InboxTab.people)).value ?? const <PeopleRow>[]) {
    if (r.peopleUnread > 0 && !r.isSnoozed && !r.muted) n++;
  }
  return n;
});

/// When the newest mail in Feed arrived, in milliseconds. Noise never
/// counts: it has no dot.
final newestFeedsIdProvider = Provider<AsyncValue<int>>((ref) => ref.watch(listRowsProvider(InboxTab.feed)).whenData((rows) {
      var newest = 0;
      for (final r in rows) {
        final t = r.lastActivity?.millisecondsSinceEpoch ?? 0;
        if (t > newest) newest = t;
      }
      return newest;
    }));

/// When the newest mail in Feed arrived, as of the last time Feed was open.
/// Anything newer puts a dot on the Feed icon.
final feedsSeenUpToProvider = AsyncNotifierProvider<FeedsSeenUpTo, int>(FeedsSeenUpTo.new);

class FeedsSeenUpTo extends AsyncNotifier<int> {
  static const key = 'feed.seenAt';

  @override
  // The first time, everything already there counts as seen: no dot.
  Future<int> build() async => int.tryParse(await ref.read(databaseProvider).getSetting(key) ?? '') ?? DateTime.now().millisecondsSinceEpoch;

  Future<void> markSeen(int id) async {
    final now = state.value;
    if (now == null || id <= now) return;
    state = AsyncData(id);
    await ref.read(databaseProvider).putSetting(key, '$id');
  }
}

/// Whether something has come into Feeds since it was last open.
final feedsHasNewProvider = Provider<bool>((ref) {
  final newest = ref.watch(newestFeedsIdProvider).value;
  final seen = ref.watch(feedsSeenUpToProvider).value;
  return newest != null && seen != null && newest > seen;
});

/// People rows for the current filter and search, live from the database.
final peopleRowsProvider = StreamProvider<List<PeopleRow>>((ref) {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(peopleFilterProvider);
  final search = ref.watch(peopleSearchProvider);
  final mode = ref.watch(inboxModeProvider);
  final scope = ref.watch(accountScopeProvider);
  final category = mode.isFeeds ? ref.watch(feedsCategoryFilterProvider) : null;
  final sort = ref.watch(peopleSortProvider).value ?? PeopleSort.newest;
  return db.watchPeopleRows(filter: filter, search: search, category: category, sort: sort, tab: mode.tab, accountId: scope);
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
