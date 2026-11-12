import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'destinations.dart';
import 'search_state.dart';
import 'web_selection.dart';

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

/// Ctrl+C while words are highlighted inside a designed email.
class CopyWebSelectionIntent extends Intent {
  const CopyWebSelectionIntent();
}

/// The shortcut table. Kept in one place so Settings can list it.
abstract final class AppShortcuts {
  static final Map<ShortcutActivator, Intent> table = {
    const SingleActivator(LogicalKeyboardKey.digit1, control: true): const GoToDestinationIntent(Destination.today),
    const SingleActivator(LogicalKeyboardKey.digit2, control: true): const GoToDestinationIntent(Destination.focus),
    const SingleActivator(LogicalKeyboardKey.digit3, control: true): const GoToDestinationIntent(Destination.chats),
    const SingleActivator(LogicalKeyboardKey.digit4, control: true): const GoToDestinationIntent(Destination.feed),
    const SingleActivator(LogicalKeyboardKey.digit5, control: true): const GoToDestinationIntent(Destination.noise),
    const SingleActivator(LogicalKeyboardKey.digit6, control: true): const GoToDestinationIntent(Destination.settings),
    const SingleActivator(LogicalKeyboardKey.keyN, control: true): const ComposeIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, control: true): const FocusSearchIntent(),
    // Only acts when words are highlighted in a designed email; otherwise
    // Ctrl+C goes on to whatever text is selected in the app itself.
    const SingleActivator(LogicalKeyboardKey.keyC, control: true): const CopyWebSelectionIntent(),
    const SingleActivator(LogicalKeyboardKey.slash): const FocusSearchIntent(),
  };

  /// Human-readable list for the Settings screen.
  static const List<(String, String)> descriptions = [
    ('Ctrl+1 … Ctrl+6', 'Switch to Précis, Focus, Chats, Feed, Noise, Settings'),
    ('Ctrl+N', 'New message'),
    ('Ctrl+F or /', 'Search'),
    ('R / Shift+R / F', 'Reply / Reply all / Forward the selected conversation'),
    ('Ctrl+Enter', 'Send the message being composed'),
    ('Esc', 'Close the composer (the draft is kept)'),
    ('E / Del / P / S', 'Archive / Delete / Pin / Later for the selected row'),
  ];
}

/// Copies what is highlighted in a designed email. It steps aside when
/// nothing is, so ordinary copying in the app is untouched.
class _CopyWebSelectionAction extends Action<CopyWebSelectionIntent> {
  @override
  bool isEnabled(CopyWebSelectionIntent intent) => WebSelection.text != null;

  @override
  Object? invoke(CopyWebSelectionIntent intent) {
    WebSelection.copy();
    return null;
  }
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
          CopyWebSelectionIntent: _CopyWebSelectionAction(),
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(onInvoke: (_) {
            // Feed and Noise have the same search bar; anywhere else goes to Chats.
            if (!ref.read(destinationProvider).isList) ref.read(destinationProvider.notifier).select(Destination.chats);
            ref.read(searchOpenProvider.notifier).open();
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
