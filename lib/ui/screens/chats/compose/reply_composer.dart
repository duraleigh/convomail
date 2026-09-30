import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/compose_state.dart';
import '../../../../store/compose_queries.dart';
import '../../../../store/database.dart';
import '../../../../store/people_queries.dart';
import '../../../theme/tokens.dart';
import 'compose_form.dart';

bool _autoReplied = false;

final rowDraftProvider = StreamProvider.family<Draft?, String>((ref, rowKey) => ref.watch(databaseProvider).watchDraftForRow(rowKey));

/// The inline composer anchored at the bottom of a conversation (spec 4.3,
/// 4.4). Collapsed: a "Reply to X…" pill with reply-all and forward
/// buttons, or a "Resume draft" pill. Expanded: the full [ComposeForm].
class ReplyComposer extends ConsumerWidget {
  const ReplyComposer({super.key, required this.row, required this.messages});
  final PeopleRow row;
  final List<Message> messages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final request = ref.watch(replyRequestProvider);
    final draft = ref.watch(rowDraftProvider(row.rowKey)).value;
    final newest = messages.where((m) => !m.isDraft).firstOrNull;
    final firstName = row.title.split(' ').first;

    if (request != null) {
      final original = request.messageId == null ? null : messages.where((m) => m.id == request.messageId).firstOrNull;
      final title = switch (request.kind) {
        'forward' => 'Forward',
        'replyAll' => 'Reply all',
        _ => 'Reply to ${row.title}',
      };
      final subtitle = original == null ? '' : (original.subject.isEmpty ? '(no subject)' : original.subject);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Material(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppShapes.xl),
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          shadowColor: scheme.shadow.withValues(alpha: 0.2),
          child: ComposeForm(
            key: ValueKey('reply-${request.hashCode}'),
            request: request,
            compact: true,
            // Resume the row's draft only for the same kind of request: a
            // Forward while a reply draft exists starts fresh and keeps the draft.
            existingDraft: draft != null && draft.kind == request.kind ? draft : null,
            onClose: () => ref.read(replyRequestProvider.notifier).close(),
            header: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
              child: Row(
                children: [
                  Icon(request.isForward ? Icons.forward_rounded : Icons.reply_rounded, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subtitle.isEmpty ? title : '$title · $subtitle',
                      style: text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(tooltip: 'Close (Esc)', onPressed: () => ref.read(replyRequestProvider.notifier).close(), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (ref.read(autoReplyProvider) && !_autoReplied && newest != null) {
      _autoReplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(replyRequestProvider.notifier).open(ComposeRequest.reply(newest.id, rowKey: row.rowKey)));
    }

    void open({bool all = false, bool forward = false}) {
      if (newest == null) return;
      final n = ref.read(replyRequestProvider.notifier);
      if (forward) {
        n.open(ComposeRequest.forward(newest.id, rowKey: row.rowKey));
      } else {
        n.open(ComposeRequest.reply(newest.id, rowKey: row.rowKey, all: all));
      }
    }

    void resume() {
      if (draft == null) return;
      // Reopen the draft under its own kind; the form loads recipients,
      // subject, and body from it.
      final n = ref.read(replyRequestProvider.notifier);
      final id = draft.inReplyToMessageId;
      if (id != null && draft.kind == 'forward') {
        n.open(ComposeRequest.forward(id, rowKey: row.rowKey));
      } else if (id != null) {
        n.open(ComposeRequest.reply(id, rowKey: row.rowKey, all: draft.kind == 'replyAll'));
      } else if (newest != null) {
        n.open(ComposeRequest.reply(newest.id, rowKey: row.rowKey));
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: draft != null ? scheme.tertiaryContainer : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppShapes.full),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('reply-pill'),
                onTap: draft != null ? resume : () => open(),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(draft != null ? Icons.drafts_outlined : Icons.reply_rounded, size: 20, color: draft != null ? scheme.onTertiaryContainer : scheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          draft != null
                              ? 'Draft · ${draft.subject.isEmpty ? 'no subject' : draft.subject} — tap to resume'
                              : (newest == null ? 'Write to $firstName…' : 'Reply to $firstName…'),
                          style: text.bodyMedium!.copyWith(color: draft != null ? scheme.onTertiaryContainer : scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'Reply all (Shift+R)',
            onPressed: newest == null ? null : () => open(all: true),
            icon: const Icon(Icons.reply_all_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Forward (F)',
            onPressed: newest == null ? null : () => open(forward: true),
            icon: const Icon(Icons.forward_rounded),
          ),
        ],
      ),
    );
  }
}
