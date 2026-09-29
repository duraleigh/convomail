import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';
import 'destination_frame.dart';

class BoardsScreen extends StatelessWidget {
  const BoardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DestinationFrame(
      title: 'Boards',
      actions: [
        IconButton(tooltip: 'Filter', onPressed: () {}, icon: const Icon(Icons.filter_list_rounded)),
        IconButton(tooltip: 'More', onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
      ],
      floatingAction: FloatingActionButton.extended(
        heroTag: 'boards-fab',
        onPressed: () {},
        icon: const Icon(Icons.add_rounded),
        label: const Text('New column'),
      ),
      child: const EmptyState(
        icon: Icons.view_kanban_outlined,
        title: 'No boards yet',
        message: 'Tag a conversation to turn it into a card. Boards arrive in milestone 9.',
      ),
    );
  }
}
