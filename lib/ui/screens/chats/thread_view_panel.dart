import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/compose_state.dart';
import '../../../app/conversation_state.dart';
import '../../../app/layout.dart';
import '../../../store/database.dart';
import '../../theme/tokens.dart';
import '../../widgets/tonal_avatar.dart';
import 'compose/compose_form.dart';
import 'compose/reply_composer.dart' show rowDraftProvider;
import 'message_card.dart';
import 'people_list_pane.dart';

/// Full thread across every participant (spec 4.3, 4.20), as an overlay
/// panel inside the right pane. Oldest first; each message collapsible.
class ThreadViewPanel extends ConsumerStatefulWidget {
  const ThreadViewPanel({super.key, required this.threadKey});
  final String threadKey;

  @override
  ConsumerState<ThreadViewPanel> createState() => _ThreadViewPanelState();
}

class _ThreadViewPanelState extends ConsumerState<ThreadViewPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _anim.reverse();
    if (mounted) ref.read(openThreadProvider.notifier).close();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // On a phone the email fills the screen, and Back closes it.
    final compact = isCompactLayout(context, ref);

    return Positioned.fill(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (ref.read(replyRequestProvider) != null) {
            ref.read(replyRequestProvider.notifier).close();
          } else {
            _close();
          }
        },
        child: Stack(
        children: [
          GestureDetector(onTap: _close, child: FadeTransition(opacity: _anim, child: Container(color: scheme.scrim.withValues(alpha: 0.32)))),
          SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic)),
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: compact ? 1 : 0.88,
                child: Material(
                  color: scheme.surface,
                  elevation: 3,
                  borderRadius: compact ? BorderRadius.zero : const BorderRadius.horizontal(left: Radius.circular(AppShapes.xl)),
                  clipBehavior: Clip.antiAlias,
                  child: ThreadView(threadKey: widget.threadKey, onClose: _close),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// One email by itself, for an email that belongs to no thread.
final _singleMessageProvider = StreamProvider.family<List<Message>, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.messages)
        ..where((m) => m.id.equals(id))
        ..where((m) => m.isDeleted.equals(false)))
      .watch();
});

/// A thread's emails, oldest first, each one collapsible: the inside of
/// [ThreadViewPanel], and the open email beside the Focus, Feed and Noise
/// lists.
///
/// With [focusId], older emails in the thread start folded to a line each
/// and that email is open. [actions] sit at the right of the heading.
class ThreadView extends ConsumerStatefulWidget {
  const ThreadView({super.key, required this.threadKey, this.messageId, this.focusId, this.onClose, this.actions = const []});

  /// The thread to show; empty or null shows the one email [messageId].
  final String? threadKey;
  final int? messageId;
  final int? focusId;
  final VoidCallback? onClose;
  final List<Widget> actions;

  @override
  ConsumerState<ThreadView> createState() => _ThreadViewState();
}

Widget _maybeExpanded(bool expand, Widget child) => expand ? Expanded(child: child) : child;

class _ThreadViewState extends ConsumerState<ThreadView> {
  /// Emails the user folded or opened by hand; the rest follow [ThreadView.focusId].
  final Map<int, bool> _open = {};

  /// The reply box this view is showing, so it is closed when the view goes.
  late final ReplyRequestNotifier _replies = ref.read(replyRequestProvider.notifier);
  ComposeRequest? _showing;

  @override
  void initState() {
    super.initState();
    _replies;
  }

  @override
  void dispose() {
    // A reply left open here does not follow the user to another email.
    final showing = _showing;
    final replies = _replies;
    if (showing != null) Future.microtask(() => replies.closeIfStill(showing));
    super.dispose();
  }

  bool _isOpen(Message m, List<Message> all) {
    final chosen = _open[m.id];
    if (chosen != null) return chosen;
    final focus = widget.focusId;
    return focus == null || all.length == 1 || m.id == focus;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final key = widget.threadKey;
    final messages = key == null || key.isEmpty ? ref.watch(_singleMessageProvider(widget.messageId ?? -1)) : ref.watch(threadMessagesProvider(key));
    return messages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) {
        final subject = list.isEmpty ? 'Thread' : (list.first.subject.isEmpty ? '(no subject)' : list.first.subject);
        // Reply, Reply all and Forward on an email here open the reply box
        // right here, under the email (the same box Chats has).
        final asked = ref.watch(replyRequestProvider);
        final request = asked != null && list.any((m) => m.id == asked.messageId) ? asked : null;
        _showing = request;
        final phone = isCompactLayout(context, ref);
        final below = widget.actions.isNotEmpty && phone;
        // On a phone an open reply has the whole screen above the keyboard.
        final fullReply = request != null && phone;
        final rowKey = request?.rowKey;
        final draft = rowKey == null ? null : ref.watch(rowDraftProvider(rowKey)).value;
        final people = <String, String>{};
        for (final m in list) {
          people[m.isFromMe ? 'me' : m.fromContactKey] = m.isFromMe ? 'You' : (m.fromName.isNotEmpty ? m.fromName : m.fromAddress);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!fullReply)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject, style: text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text('${list.length} message${list.length == 1 ? '' : 's'} · ${people.values.join(', ')}', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (!below) ...widget.actions,
                  if (widget.onClose != null) IconButton(tooltip: 'Close', onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
                ],
              ),
                  // On a phone the title gets the full width, and Done, Later and Reply sit under it.
                  if (below) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 4, children: widget.actions)),
                ],
              ),
            ),
            if (!fullReply)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Wrap(spacing: -8, children: [for (final e in people.entries) TonalAvatar(identityKey: e.key, name: e.value, size: 28)]),
            ),
            if (!fullReply)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final m = list[i];
                  final collapsed = !_isOpen(m, list);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppShapes.lgIncreased),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _open[m.id] = collapsed),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                              child: Row(
                                children: [
                                  TonalAvatar(identityKey: m.isFromMe ? 'me' : m.fromContactKey, name: m.isFromMe ? 'You' : (m.fromName.isNotEmpty ? m.fromName : m.fromAddress), size: 28),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(m.isFromMe ? 'You' : (m.fromName.isNotEmpty ? m.fromName : m.fromAddress), style: text.titleSmall)),
                                  Text(relativeTime(m.date ?? m.internalDate), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
                                  Icon(collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, size: 20, color: scheme.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),
                          if (!collapsed)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: MessageCard(message: m, showViewThread: false),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (request != null)
              _maybeExpanded(
                fullReply,
                Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Material(
                  key: const ValueKey('thread-reply'),
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppShapes.xl),
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  shadowColor: scheme.shadow.withValues(alpha: 0.2),
                  child: ComposeForm(
                    key: ValueKey('thread-reply-${request.hashCode}'),
                    request: request,
                    compact: true,
                    fill: fullReply,
                    // A draft already begun for this same email, in the same way, is picked up again.
                    existingDraft: draft != null && draft.kind == request.kind && draft.inReplyToMessageId == request.messageId ? draft : null,
                    onClose: () => ref.read(replyRequestProvider.notifier).close(),
                    header: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
                      child: Row(
                        children: [
                          Icon(request.isForward ? Icons.forward_rounded : Icons.reply_rounded, size: 20, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${switch (request.kind) { 'forward' => 'Forward', 'replyAll' => 'Reply all', _ => 'Reply' }} · $subject',
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
              ),
              ),
          ],
        );
      },
    );
  }
}
