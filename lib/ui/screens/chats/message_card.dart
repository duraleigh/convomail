import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/conversation_state.dart';
import '../../../store/database.dart';
import '../../../sync/row_actions.dart';
import '../../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../../widgets/tonal_avatar.dart';
import 'html_body_view.dart';
import 'people_list_pane.dart';

/// One expanded message (spec 4.3): header with To/CC and time, privacy
/// strip when remote content was blocked, the sanitized body, attachment
/// chips, and the inline action bar.
class MessageCard extends ConsumerWidget {
  const MessageCard({super.key, required this.message, this.showViewThread = true, this.threadCount = 1, this.onViewThread});

  final Message message;
  final bool showViewThread;
  final int threadCount;
  final VoidCallback? onViewThread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final body = ref.watch(renderedBodyProvider(message.id));
    final attachments = ref.watch(messageAttachmentsProvider(message.id)).value ?? const <Attachment>[];
    final participants = ref.watch(_participantsProvider(message.id)).value ?? const <MessageParticipant>[];
    final to = participants.where((p) => p.role == 'to').map(_label).join(', ');
    final cc = participants.where((p) => p.role == 'cc').map(_label).join(', ');
    final senderName = message.isFromMe ? 'You' : (message.fromName.isNotEmpty ? message.fromName : message.fromAddress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TonalAvatar(identityKey: message.isFromMe ? 'me' : message.fromContactKey, name: senderName, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(senderName, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    [if (to.isNotEmpty) 'To: $to', if (cc.isNotEmpty) 'CC: $cc', _fullTime(message.date ?? message.internalDate)].join(' · '),
                    style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: message.isFlagged ? 'Unstar' : 'Star',
              icon: Icon(message.isFlagged ? Icons.star_rounded : Icons.star_outline_rounded, color: message.isFlagged ? scheme.primary : scheme.onSurfaceVariant),
              onPressed: () => _setFlagged(ref, !message.isFlagged),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        body.when(
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
            child: Text('$e'.replaceFirst('Bad state: ', ''), style: text.bodyMedium!.copyWith(color: scheme.onErrorContainer)),
          ),
          data: (r) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (r.sanitized.hasRemoteContent) _PrivacyStrip(message: message, rendered: r),
              if (r.sanitized.hasRemoteContent) const SizedBox(height: AppSpace.sm),
              ref.watch(htmlRendererProvider)(context, r.html),
            ],
          ),
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final a in attachments.where((a) => !a.isInline)) _AttachmentChip(a)],
          ),
        ],
        const SizedBox(height: AppSpace.sm),
        Divider(color: scheme.outlineVariant),
        Row(
          children: [
            Tooltip(message: 'Reply arrives in milestone 4', child: TextButton.icon(onPressed: null, icon: const Icon(Icons.reply_rounded, size: 18), label: const Text('Reply'))),
            Tooltip(message: 'Forward arrives in milestone 4', child: TextButton.icon(onPressed: null, icon: const Icon(Icons.forward_rounded, size: 18), label: const Text('Forward'))),
            if (showViewThread && threadCount > 1) ...[
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                onPressed: onViewThread,
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: Text('View thread · $threadCount'),
              ),
            ],
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) async {
                final actions = ref.read(rowActionsProvider);
                switch (v) {
                  case 'unread':
                    await actions.markMessageRead(message.id, seen: false);
                  case 'read':
                    await actions.markMessageRead(message.id, seen: true);
                  case 'trash':
                    final pending = await actions.trashRow('c:${message.fromContactKey}', messageIds: [message.id], label: 'Moved to Trash');
                    if (pending != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(pending.label),
                        duration: actions.undoWindow,
                        behavior: SnackBarBehavior.floating,
                        width: 420,
                        action: SnackBarAction(label: 'Undo', onPressed: () => actions.undo(pending)),
                      ));
                    }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: message.isSeen ? 'unread' : 'read', child: Text(message.isSeen ? 'Mark unread' : 'Mark read')),
                const PopupMenuItem(value: 'trash', child: Text('Move to Trash')),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static String _label(MessageParticipant p) => p.isMe ? 'me' : (p.name.isNotEmpty ? p.name : p.address);

  static String _fullTime(DateTime? t) {
    if (t == null) return '';
    final l = t.toLocal();
    return '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][l.month - 1]} ${l.day}, ${l.year} · ${relativeTime(l)}';
  }

  Future<void> _setFlagged(WidgetRef ref, bool flagged) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.messages)..where((m) => m.id.equals(message.id))).write(MessagesCompanion(isFlagged: Value(flagged)));
    final syncer = ref.read(syncControllerProvider).syncerFor(message.accountId);
    if (syncer != null) await syncer.setFlags(message.folderId, [message.uid], flagged: flagged);
  }
}

final _participantsProvider = StreamProvider.family<List<MessageParticipant>, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.messageParticipants)..where((p) => p.messageId.equals(id))).watch();
});

/// "N remote images blocked · Load images" with an expandable list of the
/// blocked hosts (spec 4.13 tracker log).
class _PrivacyStrip extends ConsumerStatefulWidget {
  const _PrivacyStrip({required this.message, required this.rendered});
  final Message message;
  final RenderedBody rendered;

  @override
  ConsumerState<_PrivacyStrip> createState() => _PrivacyStripState();
}

class _PrivacyStripState extends ConsumerState<_PrivacyStrip> {
  bool _showHosts = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = widget.rendered.sanitized;
    final blocked = !s.allowedRemote;
    final trackers = s.trackerHosts.length;
    final label = blocked
        ? '${s.remote.length} remote image${s.remote.length == 1 ? '' : 's'} blocked${trackers > 0 ? ' · $trackers tracker${trackers == 1 ? '' : 's'}' : ''}'
        : 'Remote images loaded for this message${trackers > 0 ? ' · $trackers tracker${trackers == 1 ? '' : 's'} can see you read it' : ''}';

    return Container(
      decoration: BoxDecoration(color: blocked ? scheme.secondaryContainer : scheme.tertiaryContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(blocked ? Icons.shield_outlined : Icons.visibility_outlined, size: 18, color: blocked ? scheme.onSecondaryContainer : scheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: text.labelLarge!.copyWith(color: blocked ? scheme.onSecondaryContainer : scheme.onTertiaryContainer))),
              TextButton(
                onPressed: () => setState(() => _showHosts = !_showHosts),
                child: Text(_showHosts ? 'Hide hosts' : 'Blocked hosts'),
              ),
              if (blocked)
                FilledButton.tonal(
                  onPressed: () => ref.read(databaseProvider).setImagesAllowed(widget.message.id, true),
                  child: const Text('Load images'),
                )
              else
                TextButton(
                  onPressed: () => ref.read(databaseProvider).setImagesAllowed(widget.message.id, false),
                  child: const Text('Block again'),
                ),
            ],
          ),
          if (_showHosts)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 4, 8, 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in s.remote.map((r) => r.host).toSet())
                    Chip(
                      avatar: s.trackerHosts.contains(r) ? const Icon(Icons.gps_fixed_rounded, size: 14) : null,
                      label: Text(r, style: text.labelSmall!.copyWith(letterSpacing: 0)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip(this.a);
  final Attachment a;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppShapes.md)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(a.mimeType), size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(a.fileName, style: text.labelLarge),
          const SizedBox(width: 8),
          Text(_size(a.size), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
        ],
      ),
    );
  }

  static IconData _iconFor(String mime) {
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.contains('spreadsheet') || mime.contains('excel') || mime.contains('csv')) return Icons.table_chart_outlined;
    if (mime.contains('presentation') || mime.contains('powerpoint')) return Icons.slideshow_outlined;
    if (mime.contains('word') || mime.contains('document')) return Icons.description_outlined;
    if (mime.contains('zip') || mime.contains('compressed')) return Icons.folder_zip_outlined;
    return Icons.attach_file_rounded;
  }

  static String _size(int bytes) {
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
