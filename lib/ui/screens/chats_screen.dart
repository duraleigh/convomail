import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/compose_state.dart';
import '../../app/layout.dart';
import '../../app/people_state.dart';
import '../../app/settings.dart';
import '../shell/split_pane.dart';
import '../theme/tokens.dart';
import 'chats/compose/compose_pane.dart';
import 'chats/conversation_pane.dart';
import 'chats/people_list_pane.dart';

/// Chats destination: the People list in the middle pane and the selected
/// conversation on the right (spec 5.3).
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compose = ref.watch(composeProvider);
    final compact = isCompactLayout(context, ref);
    return SplitPane(
      // On a phone: the list of people, then one conversation (or a new message).
      compact: compact,
      detailOpen: compose != null || (compact && ref.watch(selectedRowProvider) != null),
      onCloseDetail: () {
        if (ref.read(composeProvider) != null) {
          ref.read(composeProvider.notifier).close();
        } else if (ref.read(replyRequestProvider) != null) {
          // An open reply closes first, then the conversation.
          ref.read(replyRequestProvider.notifier).close();
        } else {
          ref.read(selectedRowProvider.notifier).select(null);
        }
      },
      // The width the user last dragged to.
      initialLeftWidth: ref.watch(settingsProvider.select((s) => s.middlePaneWidth)),
      onLeftWidthChanged: (w) => ref.read(settingsProvider.notifier).setMiddlePaneWidth(w),
      minLeft: AppLayout.middlePaneMin,
      maxLeft: AppLayout.middlePaneMax,
      minRight: AppLayout.rightPaneMin,
      left: const PeopleListPane(),
      right: compose == null ? const ConversationPane() : ComposePane(request: compose),
    );
  }
}
