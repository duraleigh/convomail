import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'destinations.dart';

/// Intents for app-wide keyboard shortcuts (spec 5.3 "Keyboard").
class GoToDestinationIntent extends Intent {
  const GoToDestinationIntent(this.destination);
  final Destination destination;
}

class ComposeIntent extends Intent {
  const ComposeIntent();
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

/// The shortcut table. Kept in one place so Settings can list it.
abstract final class AppShortcuts {
  static final Map<ShortcutActivator, Intent> table = {
    const SingleActivator(LogicalKeyboardKey.digit1, control: true): const GoToDestinationIntent(Destination.chats),
    const SingleActivator(LogicalKeyboardKey.digit2, control: true): const GoToDestinationIntent(Destination.boards),
    const SingleActivator(LogicalKeyboardKey.digit3, control: true): const GoToDestinationIntent(Destination.planner),
    const SingleActivator(LogicalKeyboardKey.digit4, control: true): const GoToDestinationIntent(Destination.settings),
    const SingleActivator(LogicalKeyboardKey.keyN, control: true): const ComposeIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, control: true): const FocusSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.slash): const FocusSearchIntent(),
  };

  /// Human-readable list for the Settings screen.
  static const List<(String, String)> descriptions = [
    ('Ctrl+1 … Ctrl+4', 'Switch to Chats, Boards, Planner, Settings'),
    ('Ctrl+N', 'New message'),
    ('Ctrl+F or /', 'Search'),
    ('R / Shift+R / F', 'Reply / Reply all / Forward (M3)'),
    ('E / Del / S', 'Archive / Delete / Snooze (M2)'),
  ];
}

/// Global focus node for the search field so the shortcut can reach it.
final searchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'search');
  ref.onDispose(node.dispose);
  return node;
});

/// Wraps the app in [Shortcuts] and [Actions] bound to Riverpod state.
class AppShortcutScope extends ConsumerWidget {
  const AppShortcutScope({super.key, required this.child, this.onCompose});
  final Widget child;
  final VoidCallback? onCompose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: AppShortcuts.table,
      child: FocusScope(
        autofocus: true,
        debugLabel: 'app-shortcuts',
        child: Actions(
        actions: {
          GoToDestinationIntent: CallbackAction<GoToDestinationIntent>(
            onInvoke: (i) {
              ref.read(destinationProvider.notifier).select(i.destination);
              return null;
            },
          ),
          ComposeIntent: CallbackAction<ComposeIntent>(onInvoke: (_) {
            onCompose?.call();
            return null;
          }),
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(onInvoke: (_) {
            ref.read(destinationProvider.notifier).select(Destination.chats);
            ref.read(searchFocusProvider).requestFocus();
            return null;
          }),
          },
          child: Focus(autofocus: true, child: child),
        ),
      ),
    );
  }
}
