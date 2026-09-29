import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';
import 'destination_frame.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DestinationFrame(
      title: 'Planner',
      actions: [
        IconButton(tooltip: 'Today', onPressed: () {}, icon: const Icon(Icons.today_outlined)),
        IconButton(tooltip: 'More', onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
      ],
      floatingAction: FloatingActionButton(heroTag: 'planner-fab', onPressed: () {}, child: const Icon(Icons.add_rounded)),
      child: const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Your week is clear',
        message: 'Events found in your mail will appear here. Planner arrives in milestone 9.',
      ),
    );
  }
}
