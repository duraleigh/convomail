import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/database.dart';
import '../store/search_queries.dart';
import 'account_scope.dart';
import 'people_state.dart';
import 'settings.dart';

/// Search text after a short pause in typing. The People list filters on
/// the live text (cheap, in memory); the full-text query waits for this.
final debouncedSearchProvider = NotifierProvider<DebouncedSearchNotifier, String>(DebouncedSearchNotifier.new);

class DebouncedSearchNotifier extends Notifier<String> {
  Timer? _timer;

  @override
  String build() {
    ref.listen<String>(peopleSearchProvider, (_, next) {
      _timer?.cancel();
      if (next.trim().isEmpty) {
        state = '';
        return;
      }
      _timer = Timer(const Duration(milliseconds: 220), () => state = next);
    });
    ref.onDispose(() => _timer?.cancel());
    return ref.read(peopleSearchProvider);
  }
}

/// Whether the middle pane is in search-results mode.
final searchActiveProvider = Provider<bool>((ref) => ref.watch(peopleSearchProvider).trim().isNotEmpty);

/// Global full-text hits for the current query, filter chip, and Include
/// Feeds setting (spec 4.6).
final searchHitsProvider = FutureProvider<List<SearchHit>>((ref) async {
  final q = ref.watch(debouncedSearchProvider);
  if (q.trim().isEmpty) return const [];
  final filter = ref.watch(peopleFilterProvider);
  final includeFeeds = ref.watch(settingsProvider.select((s) => s.searchIncludeFeeds));
  return ref.watch(databaseProvider).searchMessages(q, filter: filter, includeFeeds: includeFeeds, accountId: ref.watch(accountScopeProvider));
});

/// In-conversation search (spec 4.6): the query typed into the
/// conversation header, or null when closed. Opening it from a global
/// result carries the global query over.
final conversationSearchProvider = NotifierProvider<ConversationSearchNotifier, String?>(ConversationSearchNotifier.new);

class ConversationSearchNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void open([String initial = '']) => state = initial;
  void set(String q) => state = q;
  void close() => state = null;
}

/// Highlight terms for the open conversation (empty when not searching).
final conversationHighlightProvider = Provider<List<String>>((ref) {
  final q = ref.watch(conversationSearchProvider);
  if (q == null || q.trim().isEmpty) return const [];
  return SearchQueries.searchTerms(q);
});

/// Message ids in the selected row that match the in-conversation query;
/// null when no query is active (show everything).
final conversationMatchesProvider = FutureProvider<Set<int>?>((ref) async {
  final q = ref.watch(conversationSearchProvider);
  final rowKey = ref.watch(selectedRowProvider);
  if (q == null || q.trim().isEmpty || rowKey == null) return null;
  return ref.watch(databaseProvider).searchInRow(rowKey, q);
});

/// A message the conversation should expand and scroll to once (set when a
/// global search result is opened).
final scrollToMessageProvider = NotifierProvider<ScrollToMessageNotifier, int?>(ScrollToMessageNotifier.new);

class ScrollToMessageNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void request(int id) => state = id;
  void clear() => state = null;
}
