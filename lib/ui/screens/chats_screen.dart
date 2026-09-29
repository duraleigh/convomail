import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/destinations.dart';
import '../../app/shortcuts.dart';
import '../shell/split_pane.dart';
import '../theme/tokens.dart';
import '../widgets/connected_button_group.dart';
import '../widgets/empty_state.dart';

/// Chats destination: middle pane (search, chips, People/Feeds, list) and
/// right pane (conversation). Milestone 0 ships the frame with empty states;
/// M1 and M2 fill the list, M3 fills the conversation.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SplitPane(
      initialLeftWidth: AppLayout.middlePaneDefault,
      minLeft: AppLayout.middlePaneMin,
      maxLeft: AppLayout.middlePaneMax,
      minRight: AppLayout.rightPaneMin,
      left: _MiddlePane(),
      right: _RightPane(),
    );
  }
}

class _MiddlePane extends ConsumerWidget {
  const _MiddlePane();

  static const _filters = ['All', 'Unread', 'Starred', 'This Week', 'Sent', 'Has attachments', 'From contacts'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mode = ref.watch(inboxModeProvider);
    final searchFocus = ref.watch(searchFocusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text('Chats', style: text.headlineMedium)),
              IconButton(tooltip: 'Filters', onPressed: () {}, icon: const Icon(Icons.tune_rounded)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SearchBar(
            focusNode: searchFocus,
            hintText: 'Search people and mail',
            leading: const Icon(Icons.search_rounded),
            onSubmitted: (_) {},
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _filters.length; i++)
                FilterChip(
                  label: Text(_filters[i]),
                  selected: i == 0,
                  onSelected: (_) {},
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: ConnectedButtonGroup<InboxMode>(
            selected: mode,
            onSelected: (m) => ref.read(inboxModeProvider.notifier).select(m),
            items: const [
              ButtonGroupItem(value: InboxMode.people, label: 'People', icon: Icons.person_outline_rounded),
              ButtonGroupItem(value: InboxMode.feeds, label: 'Feeds', icon: Icons.rss_feed_rounded),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EmptyState(
              icon: mode == InboxMode.people ? Icons.forum_outlined : Icons.inbox_outlined,
              title: mode == InboxMode.people ? 'No conversations yet' : 'Nothing filed to Feeds',
              message: 'Add an account in Settings to start syncing.',
              action: FilledButton.tonalIcon(
                onPressed: () => ref.read(destinationProvider.notifier).select(Destination.settings),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add account'),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Semantics(label: 'surface-container marker', child: SizedBox(height: 0, child: Container(color: scheme.surface))),
      ],
    );
  }
}

class _RightPane extends StatelessWidget {
  const _RightPane();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppShapes.xl),
        clipBehavior: Clip.antiAlias,
        child: const EmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Pick a person',
          message: 'Their whole conversation with you will show here.',
        ),
      ),
    );
  }
}
