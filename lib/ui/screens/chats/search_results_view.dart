import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/conversation_state.dart';
import '../../../app/people_state.dart';
import '../../../app/search_state.dart';
import '../../../app/settings.dart';
import '../../../store/people_queries.dart';
import '../../../store/search_queries.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/tonal_avatar.dart';
import 'people_list_pane.dart';
import 'person_row.dart';

/// Builds spans from FTS5-marked text: runs between the marker characters
/// get the highlight style.
TextSpan markedSpan(String marked, TextStyle base, TextStyle highlight) {
  final spans = <TextSpan>[];
  var inMark = false;
  final buf = StringBuffer();
  void flush() {
    if (buf.isEmpty) return;
    spans.add(TextSpan(text: buf.toString(), style: inMark ? highlight : base));
    buf.clear();
  }

  for (final ch in marked.runes) {
    if (ch == 0x01) {
      flush();
      inMark = true;
    } else if (ch == 0x02) {
      flush();
      inMark = false;
    } else {
      buf.writeCharCode(ch);
    }
  }
  flush();
  return TextSpan(children: spans, style: base);
}

/// Wraps occurrences of [terms] in [text] with the FTS marker characters so
/// [markedSpan] can style them (used where text did not come from FTS).
String markTerms(String text, List<String> terms) {
  final clean = terms.map((t) => t.trim()).where((t) => t.isNotEmpty).toList()..sort((a, b) => b.length.compareTo(a.length));
  if (clean.isEmpty || text.isEmpty) return text;
  final re = RegExp(clean.map(RegExp.escape).join('|'), caseSensitive: false);
  return text.replaceAllMapped(re, (m) => '\u0001${m.group(0)}\u0002');
}

/// Search-results mode of the middle pane (spec 4.6, 5.2 #10): the
/// Include Feeds switch, People rows that match, and full-text message
/// hits scoped by the active filter chip. Opening a hit selects its row,
/// expands and scrolls to the message, and carries the query into the
/// in-conversation search so matches are highlighted.
class SearchResultsView extends ConsumerWidget {
  const SearchResultsView({super.key, required this.people, required this.onOpenRow});
  final List<PeopleRow> people;
  final void Function(PeopleRow row) onOpenRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hits = ref.watch(searchHitsProvider);
    final includeFeeds = ref.watch(settingsProvider.select((s) => s.searchIncludeFeeds));
    final query = ref.watch(peopleSearchProvider);
    final selected = ref.watch(selectedRowProvider);
    final highlightStyle = TextStyle(backgroundColor: scheme.tertiaryContainer, color: scheme.onTertiaryContainer, fontWeight: FontWeight.w700);

    void openHit(SearchHit h) {
      ref.read(selectedRowProvider.notifier).select(h.rowKey);
      ref.read(conversationSearchProvider.notifier).open(query);
      ref.read(expandedMessagesProvider.notifier).expand(h.message.id);
      ref.read(scrollToMessageProvider.notifier).request(h.message.id);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
          child: Row(
            children: [
              Expanded(child: Text('Include Feeds', style: text.labelLarge)),
              Switch(
                key: const ValueKey('include-feeds'),
                value: includeFeeds,
                onChanged: (v) => ref.read(settingsProvider.notifier).setSearchIncludeFeeds(v),
              ),
            ],
          ),
        ),
        if (people.isNotEmpty) ...[
          _SectionLabel('PEOPLE · ${people.length}'),
          GroupedList(
            children: [
              for (final row in people)
                GroupedListItem(
                  key: ValueKey('search-person-${row.rowKey}'),
                  radius: GroupedList.radiusFor(people.indexOf(row), people.length),
                  selected: row.rowKey == selected,
                  onTap: () => onOpenRow(row),
                  child: PersonRow(row: row, selected: row.rowKey == selected, onAction: (_) {}),
                ),
            ],
          ),
        ],
        hits.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e', style: text.bodyMedium!.copyWith(color: scheme.error))),
          data: (list) {
            if (list.isEmpty && people.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 48),
                child: EmptyState(icon: Icons.search_off_rounded, title: 'No matches', message: 'Try another word, or clear the filter chip.'),
              );
            }
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel('MESSAGES · ${list.length}${list.length >= 100 ? '+' : ''}'),
                GroupedList(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      GroupedListItem(
                        key: ValueKey('search-hit-${list[i].message.id}'),
                        radius: GroupedList.radiusFor(i, list.length),
                        onTap: () => openHit(list[i]),
                        child: _HitTile(hit: list[i], highlight: highlightStyle),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(letterSpacing: 1)),
      );
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.highlight});
  final SearchHit hit;
  final TextStyle highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final m = hit.message;
    final sender = m.isFromMe ? 'You' : (m.fromName.isNotEmpty ? m.fromName : m.fromAddress);
    final unread = !m.isSeen && !m.isFromMe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TonalAvatar(identityKey: m.isFromMe ? 'me' : m.fromContactKey, name: sender, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(sender, style: text.titleSmall!.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    Text(relativeTime(m.date ?? m.internalDate), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
                  ],
                ),
                const SizedBox(height: 2),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: markedSpan(hit.subjectMarked.isEmpty ? '(no subject)' : hit.subjectMarked, text.bodyMedium!.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600), highlight),
                ),
                if (hit.snippetMarked.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: markedSpan(hit.snippetMarked, text.bodySmall!.copyWith(color: scheme.onSurfaceVariant), highlight),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
