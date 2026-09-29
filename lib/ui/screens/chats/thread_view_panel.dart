import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/conversation_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/tonal_avatar.dart';
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
  final Set<int> _collapsed = {};

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
    final text = Theme.of(context).textTheme;
    final messages = ref.watch(threadMessagesProvider(widget.threadKey));

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(onTap: _close, child: FadeTransition(opacity: _anim, child: Container(color: scheme.scrim.withValues(alpha: 0.32)))),
          SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic)),
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.88,
                child: Material(
                  color: scheme.surface,
                  elevation: 3,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppShapes.xl)),
                  clipBehavior: Clip.antiAlias,
                  child: messages.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (list) {
                      final subject = list.isEmpty ? 'Thread' : (list.first.subject.isEmpty ? '(no subject)' : list.first.subject);
                      final people = <String, String>{};
                      for (final m in list) {
                        people[m.isFromMe ? 'me' : m.fromContactKey] = m.isFromMe ? 'You' : (m.fromName.isNotEmpty ? m.fromName : m.fromAddress);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
                            child: Row(
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
                                IconButton(tooltip: 'Close', onPressed: _close, icon: const Icon(Icons.close_rounded)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: Wrap(spacing: -8, children: [for (final e in people.entries) TonalAvatar(identityKey: e.key, name: e.value, size: 28)]),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: list.length,
                              itemBuilder: (context, i) {
                                final m = list[i];
                                final collapsed = _collapsed.contains(m.id);
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
                                          onTap: () => setState(() => collapsed ? _collapsed.remove(m.id) : _collapsed.add(m.id)),
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
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
