import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell/split_pane.dart';
import '../theme/tokens.dart';
import 'chats/people_list_pane.dart';
import 'chats/row_messages_pane.dart';

/// Chats destination: the People list in the middle pane and the selected
/// conversation on the right (spec 5.3).
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SplitPane(
      initialLeftWidth: AppLayout.middlePaneDefault,
      minLeft: AppLayout.middlePaneMin,
      maxLeft: AppLayout.middlePaneMax,
      minRight: AppLayout.rightPaneMin,
      left: PeopleListPane(),
      right: RowMessagesPane(),
    );
  }
}
