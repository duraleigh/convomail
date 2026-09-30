import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/compose_state.dart';
import '../../../../store/compose_queries.dart';
import '../../../../store/database.dart';
import '../../../theme/tokens.dart';
import 'compose_form.dart';

final latestNewDraftProvider = StreamProvider<Draft?>((ref) => ref.watch(databaseProvider).watchLatestNewDraft());

/// New-message composer that replaces the right pane in place (spec 5.3).
/// Resumes the most recent unsent new-message draft when there is one.
class ComposePane extends ConsumerWidget {
  const ComposePane({super.key, required this.request});
  final ComposeRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final draft = ref.watch(latestNewDraftProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppShapes.xl),
        clipBehavior: Clip.antiAlias,
        child: draft.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (d) => ComposeForm(
            // A new key per request so a fresh Ctrl+N after a send starts clean.
            key: ValueKey('compose-${request.hashCode}-${d?.id}'),
            request: request,
            existingDraft: request.to.isEmpty && request.subject.isEmpty ? d : null,
            onClose: () => ref.read(composeProvider.notifier).close(),
            header: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(d != null ? 'Draft' : 'New message', style: text.titleLarge)),
                  IconButton(tooltip: 'Close (Esc)', onPressed: () => ref.read(composeProvider.notifier).close(), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
