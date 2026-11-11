import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/destinations.dart';
import '../../app/people_state.dart';
import '../../app/search_state.dart';
import '../../app/shortcuts.dart';

/// A large search bar that slides open across the top of the app from the
/// search icon in the Chats and Feeds list (or Ctrl+F), and closes with its
/// X or Esc. Hidden on the other screens.
class TopSearchBar extends ConsumerStatefulWidget {
  const TopSearchBar({super.key});

  @override
  ConsumerState<TopSearchBar> createState() => _TopSearchBarState();
}

class _TopSearchBarState extends ConsumerState<TopSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(peopleSearchProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _controller.clear();
    ref.read(searchOpenProvider.notifier).close();
    // Back to where focus was before, inside the app's shortcuts, so Ctrl+F
    // and the rest keep working.
    ref.read(searchFocusProvider).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(destinationProvider);
    final onList = destination.isList;
    final shown = onList && ref.watch(searchBarShownProvider);
    final focus = ref.watch(searchFocusProvider);
    final mode = ref.watch(inboxModeProvider);

    // Chats and Feeds each keep their own search text.
    ref.listen(peopleSearchProvider, (_, next) {
      if (_controller.text != next) _controller.text = next;
    });
    // Opened: type straight away.
    ref.listen(searchOpenProvider, (prev, next) {
      if (next && prev != true) WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
    });

    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: !shown
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: const ValueKey('top-search'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: CallbackShortcuts(
                  bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
                  child: SearchBar(
                    controller: _controller,
                    focusNode: focus,
                    hintText: switch (mode) { InboxMode.people => 'Search people and mail', InboxMode.feed => 'Search Feed and mail', InboxMode.noise => 'Search Noise and mail' },
                    constraints: const BoxConstraints(minHeight: 54),
                    textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.titleMedium),
                    leading: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.search_rounded)),
                    trailing: [
                      IconButton(
                        key: const ValueKey('top-search-close'),
                        tooltip: 'Close search (Esc)',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _close,
                      ),
                    ],
                    onChanged: (v) => ref.read(peopleSearchProvider.notifier).set(v),
                  ),
                ),
              ),
      ),
    );
  }
}
