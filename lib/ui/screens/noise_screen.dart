import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/mail_state.dart';
import '../../app/people_state.dart';
import '../../domain/piles.dart';
import '../../store/mail_queries.dart';
import '../../sync/row_actions.dart';
import '../theme/tokens.dart';
import '../widgets/category_color.dart';
import '../widgets/empty_state.dart';
import '../widgets/reading_line.dart';
import '../widgets/tonal_avatar.dart';
import 'chats/people_list_pane.dart' show relativeTime;
import 'feed_screen.dart' show tagsInUse;
import 'mail/mail_widgets.dart';

/// One row of Noise: a sender with its emails, or the small senders of one
/// kind gathered together ("Other promotions · 7 senders").
class NoiseGroup {
  NoiseGroup({required this.key, required this.title, required this.items, required this.senders, this.tag});
  final String key;
  final String title;

  /// Newest first.
  final List<MailItem> items;
  final int senders;
  final String? tag;

  bool get many => senders > 1;
  DateTime get newest => items.first.at;
  int since(DateTime t) => items.where((i) => !i.at.isBefore(t)).length;
}

/// Noise as the list shows it: one row per sender. Senders with a single
/// email are gathered by kind when there are three or more of that kind, so
/// the list stays short. Busiest this week first.
List<NoiseGroup> noiseGroups(List<MailItem> items, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final week = n.subtract(const Duration(days: 7));
  final bySender = <String, List<MailItem>>{};
  for (final i in items) {
    bySender.putIfAbsent(i.senderKey, () => []).add(i);
  }
  final singles = <String?, List<MailItem>>{};
  final out = <NoiseGroup>[];
  for (final e in bySender.entries) {
    if (e.value.length == 1) {
      singles.putIfAbsent(e.value.first.tag, () => []).add(e.value.first);
    } else {
      out.add(NoiseGroup(key: 's:${e.key}', title: e.value.first.senderName, items: e.value, senders: 1, tag: e.value.first.tag));
    }
  }
  for (final e in singles.entries) {
    if (e.value.length >= 3) {
      final what = e.key == null ? 'senders' : pluralTag(e.key!).toLowerCase();
      out.add(NoiseGroup(key: 't:${e.key ?? ''}', title: 'Other $what', items: e.value, senders: e.value.length, tag: e.key));
    } else {
      for (final i in e.value) {
        out.add(NoiseGroup(key: 's:${i.senderKey}', title: i.senderName, items: [i], senders: 1, tag: i.tag));
      }
    }
  }
  out.sort((a, b) {
    final c = b.since(week).compareTo(a.since(week));
    return c != 0 ? c : b.newest.compareTo(a.newest);
  });
  return out;
}

/// Noise: everything that never needed the user. It does not ring, it is
/// not on Today, and it has no dot on the rail. One row per sender, with how
/// many came this week; the right side says why it is here and offers the
/// ways out.
class NoiseScreen extends ConsumerWidget {
  const NoiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final all = ref.watch(noiseMailProvider);
    final loading = ref.watch(otherMailProvider).isLoading && all.isEmpty;
    final tag = ref.watch(mailTagProvider('noise'));
    final tags = tagsInUse(all);
    final items = tag == null || !tags.contains(tag) ? all : [for (final i in all) if (i.tag == tag) i];
    final groups = noiseGroups(items);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = now.subtract(const Duration(days: 7));
    final thisWeek = all.where((i) => !i.at.isBefore(week)).length;
    // A sender opened from somewhere else (search, Today) lands on its row here.
    final asked = ref.watch(selectedRowProvider);
    if (asked != null) {
      final g = groups.where((g) => g.items.any((i) => i.rowKey == asked)).firstOrNull;
      if (g != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ref.read(selectedRowProvider.notifier).select(null);
          ref.read(openNoiseGroupProvider.notifier).open(g.key);
          ref.read(openMailProvider('noise').notifier).open(null);
        });
      }
    }
    final openKey = ref.watch(openNoiseGroupProvider);
    final open = groups.where((g) => g.key == openKey).firstOrNull;
    final openId = ref.watch(openMailProvider('noise'));
    final openItem = open?.items.where((i) => i.id == openId).firstOrNull;

    return MailSplit(
      // On a phone: a sender's emails fill the screen, then one email does.
      detailOpen: open != null,
      onCloseDetail: () {
        if (ref.read(openMailProvider('noise')) != null) {
          ref.read(openMailProvider('noise').notifier).open(null);
        } else {
          ref.read(openNoiseGroupProvider.notifier).open(null);
        }
      },
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MailListHeader(
            key: const ValueKey('noise-header'),
            title: 'Noise',
            subtitle: all.isEmpty ? 'Kept out of your way. Nothing here yet.' : '${all.length} email${all.length == 1 ? '' : 's'} kept out of your way, $thisWeek from this week.',
          ),
          TagPills(tags: tags, selected: tags.contains(tag) ? tag : null, onSelect: (t) => ref.read(mailTagProvider('noise').notifier).select(t)),
          Expanded(
            child: loading
                ? const SizedBox.shrink()
                : groups.isEmpty
                    ? const EmptyState(key: ValueKey('noise-empty'), icon: Icons.volume_off_outlined, title: 'Nothing in Noise', message: 'Promotions, social notices and other mail that never needed you is kept here, silently.')
                    : ListView.builder(
                        key: const PageStorageKey('noise-list'),
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        itemCount: groups.length,
                        itemBuilder: (_, i) {
                          final g = groups[i];
                          final w = g.since(week);
                          final t = g.since(today);
                          final selected = g.key == openKey;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                            child: Material(
                              color: selected ? scheme.secondaryContainer : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppShapes.lg),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: ValueKey('noise-row-${g.key}'),
                                onTap: () {
                                  ref.read(openNoiseGroupProvider.notifier).open(g.key);
                                  ref.read(openMailProvider('noise').notifier).open(null);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                                  child: Row(
                                    children: [
                                      TonalAvatar(identityKey: g.many ? 'noise-${g.tag}' : g.items.first.senderKey, name: g.title, size: 40),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(child: Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w600))),
                                                if (g.tag != null) ...[const SizedBox(width: 6), Tooltip(message: g.tag!, child: CategoryDot(category: g.tag!, size: 8))],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              [
                                                w > 0 ? '$w this week' : '${g.items.length} email${g.items.length == 1 ? '' : 's'}',
                                                if (w > 0 && g.items.length > w) '${g.items.length} in all',
                                                if (g.many) '${g.senders} senders',
                                              ].join(' · '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(t > 0 ? '$t today' : relativeTime(g.newest), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('noise-archive-all'),
                  onPressed: () => _archive(context, ref, items, 'all ${items.length} emails in ${tag == null || !tags.contains(tag) ? 'Noise' : pluralTag(tag)}', confirm: true),
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  label: Text('Archive all ${items.length}'),
                ),
              ),
            ),
        ],
      ),
      right: open == null
          ? const MailNothingOpen(icon: Icons.volume_off_outlined, message: 'Pick a sender on the left to see why it is here, and what to do about it.')
          : openItem != null
              ? MailEmailPane(item: openItem, onClose: () => ref.read(openMailProvider('noise').notifier).open(null))
              : _NoisePane(group: open),
    );
  }
}

/// Archives [items] (they leave the inbox and Noise; nothing is deleted),
/// with Undo for a few seconds.
Future<void> _archive(BuildContext context, WidgetRef ref, List<MailItem> items, String what, {bool confirm = false}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (confirm) {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Archive $what?'),
        content: const Text('They leave your inbox and Noise. Nothing is deleted: archived mail stays in your mailbox under All Mail.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('noise-archive-confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive')),
        ],
      ),
    );
    if (yes != true) return;
  }
  final actions = ref.read(rowActionsProvider);
  final byRow = <String, List<int>>{};
  for (final i in items) {
    byRow.putIfAbsent(i.rowKey, () => []).add(i.id);
  }
  final pending = <PendingAction>[];
  for (final e in byRow.entries) {
    final p = await actions.archiveRow(e.key, messageIds: e.value);
    if (p != null) pending.add(p);
  }
  if (pending.isEmpty) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(persist: false, duration: const Duration(seconds: 6), 
    content: Text('Archived ${items.length} email${items.length == 1 ? '' : 's'}'),
    behavior: SnackBarBehavior.floating,
    width: 420,
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () async {
        for (final p in pending) {
          await actions.undo(p);
        }
      },
    ),
  ));
}

/// The right side of Noise for one sender: why it is here, the ways out,
/// and its emails.
class _NoisePane extends ConsumerWidget {
  const _NoisePane({required this.group});
  final NoiseGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final first = group.items.first;
    final n = group.items.length;
    final reasons = group.many ? ['These are single emails from ${group.senders} senders, all of the same kind.', ...whyReasons(first).take(1)] : whyReasons(first);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.xl),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          key: ValueKey('noise-pane-${group.key}'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            Row(
              children: [
                TonalAvatar(identityKey: group.many ? 'noise-${group.tag}' : first.senderKey, name: group.title, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.title, style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(group.many ? '${group.senders} senders' : first.senderKey, style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text('$n email${n == 1 ? '' : 's'}', style: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(AppShapes.lgIncreased)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.help_outline_rounded, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('Why this is in Noise', style: text.titleSmall!.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 8),
                  for (final r in reasons) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(r, style: text.bodyMedium)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!group.many) ...[
                        FilledButton.tonalIcon(
                          key: const ValueKey('noise-to-feed'),
                          icon: const Icon(Icons.rss_feed_rounded, size: 18),
                          label: const Text('Move to Feed'),
                          onPressed: () => moveSenderOf(context, ref, first, pile: FeedsPile.feed),
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey('noise-person'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          label: const Text('This is a person'),
                          onPressed: () => moveSenderOf(context, ref, first),
                        ),
                      ],
                      OutlinedButton.icon(
                        key: const ValueKey('noise-archive-group'),
                        icon: const Icon(Icons.archive_outlined, size: 18),
                        label: Text(n == 1 ? 'Archive it' : 'Archive all $n'),
                        onPressed: () => _archive(context, ref, group.items, '$n emails'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppShapes.lgIncreased),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < group.items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
                    InkWell(
                      key: ValueKey('noise-email-${group.items[i].id}'),
                      onTap: () {
                        ref.read(openMailProvider('noise').notifier).open(group.items[i].id);
                        openMail(ref, group.items[i]);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.many ? '${group.items[i].senderName}: ${group.items[i].subject.isEmpty ? '(no subject)' : group.items[i].subject}' : (group.items[i].subject.isEmpty ? '(no subject)' : group.items[i].subject),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodyMedium!.copyWith(fontWeight: group.items[i].unread ? FontWeight.w700 : FontWeight.w400),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(relativeTime(group.items[i].at), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
