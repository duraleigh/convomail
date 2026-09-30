import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/compose_state.dart';
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
    return SplitPane(
      initialLeftWidth: AppLayout.middlePaneDefault,
      minLeft: AppLayout.middlePaneMin,
      maxLeft: AppLayout.middlePaneMax,
      minRight: AppLayout.rightPaneMin,
      left: const PeopleListPane(),
      right: compose == null ? const ConversationPane() : ComposePane(request: compose),
    );
  }
}
