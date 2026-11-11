import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

/// Focus: every email that needs the user. It is filled by the assistant,
/// which reads each email for what it asks. Until the assistant is connected
/// the list stays empty and says so; nothing is guessed.
class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 12, 8),
          child: Text('Focus', style: text.headlineMedium),
        ),
        const Expanded(
          child: EmptyState(
            key: ValueKey('focus-empty'),
            icon: Icons.adjust_rounded,
            title: 'Nothing here yet',
            message: 'The assistant is not connected yet. When it is, every email that needs you is listed here.',
          ),
        ),
      ],
    );
  }
}
