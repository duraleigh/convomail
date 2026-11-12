import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/compose_state.dart';
import '../../../app/conversation_state.dart';
import '../../../app/layout.dart';
import '../../../app/settings.dart';
import '../../../domain/piles.dart';
import '../../../store/database.dart';
import '../../../store/done_queries.dart';
import '../../../store/mail_queries.dart';
import '../../../sync/classification_service.dart';
import '../../../sync/row_actions.dart';
import '../../shell/split_pane.dart';
import '../../theme/tokens.dart';
import '../../widgets/category_color.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/reading_line.dart';
import '../../widgets/tonal_avatar.dart';
import '../chats/later_dialogs.dart';
import '../chats/people_list_pane.dart' show relativeTime;
import '../chats/thread_view_panel.dart';
import '../chats/timely_strip.dart' show TimelyCodePill;

/// Emails under a heading ("Today", "Yesterday", "Last week").
typedef MailGroup = ({String label, List<MailItem> items});

/// Groups emails, newest first, by day and then by week: Today, Yesterday,
/// Earlier this week, Last week, then by month.
List<MailGroup> groupByDay(List<MailItem> items, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  String label(DateTime at) {
    final l = at.toLocal();
    final day = DateTime(l.year, l.month, l.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (!day.isBefore(weekStart)) return 'Earlier this week';
    if (!day.isBefore(weekStart.subtract(const Duration(days: 7)))) return 'Last week';
    return l.year == n.year ? months[l.month - 1] : '${months[l.month - 1]} ${l.year}';
  }

  final out = <MailGroup>[];
  for (final i in items) {
    final l = label(i.at);
    if (out.isEmpty || out.last.label != l) out.add((label: l, items: []));
    out.last.items.add(i);
  }
  return out;
}

/// The frame every one of the three lists shares: the list in the middle
/// pane (at the width the user dragged to) and the open email on the right.
class MailSplit extends ConsumerWidget {
  const MailSplit({super.key, required this.left, required this.right, this.detailOpen = false, this.onCloseDetail});
  final Widget left;
  final Widget right;

  /// On a phone: whether something is open (it then fills the screen), and
  /// how to go back to the list.
  final bool detailOpen;
  final VoidCallback? onCloseDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SplitPane(
        compact: isCompactLayout(context, ref),
        detailOpen: detailOpen,
        // Back closes an open reply first, then the email.
        onCloseDetail: () {
          if (ref.read(replyRequestProvider) != null) {
            ref.read(replyRequestProvider.notifier).close();
          } else {
            onCloseDetail?.call();
          }
        },
        initialLeftWidth: ref.watch(settingsProvider.select((s) => s.middlePaneWidth)),
        onLeftWidthChanged: (w) => ref.read(settingsProvider.notifier).setMiddlePaneWidth(w),
        minLeft: AppLayout.middlePaneMin,
        maxLeft: AppLayout.middlePaneMax,
        minRight: AppLayout.rightPaneMin,
        left: left,
        right: right,
      );
}

/// The heading of a list: its name, and one line under it.
class MailListHeader extends StatelessWidget {
  const MailListHeader({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.headlineMedium),
          const SizedBox(height: 2),
          Text(subtitle, key: const ValueKey('mail-list-subtitle'), style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// The small heading over a group of rows, with how many are in it.
class MailGroupLabel extends StatelessWidget {
  const MailGroupLabel({super.key, required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 6),
      child: Row(
        children: [
          Text(label, style: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('$count', style: text.labelMedium!.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

/// The pills along the top of Feed and Noise: "All", then one per tag in
/// use, each with its color dot.
class TagPills extends StatelessWidget {
  const TagPills({super.key, required this.tags, required this.selected, required this.onSelect});
  final List<String> tags;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tags.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(key: const ValueKey('feeds-pill-all'), label: const Text('All'), selected: selected == null, showCheckmark: false, onSelected: (_) => onSelect(null)),
          ),
          for (final t in tags)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('feeds-pill-$t'),
                avatar: CategoryDot(category: t),
                label: Text(pluralTag(t)),
                selected: selected == t,
                showCheckmark: false,
                onSelected: (_) => onSelect(selected == t ? null : t),
              ),
            ),
        ],
      ),
    );
  }
}

/// A tag as a pill names it: "Receipts", "Deliveries", "OTPs".
String pluralTag(String tag) => switch (tag) {
      'Delivery' => 'Deliveries',
      'Updates' || 'Social' || 'Travel' => tag,
      _ => '${tag}s',
    };

/// One email as a row: who on top, what underneath, when on the right.
/// Nothing else, so a list reads at a glance.
class MailRowTile extends StatelessWidget {
  const MailRowTile({super.key, required this.item, required this.selected, required this.onTap, this.focus = false, this.onMenu, this.faded = false, this.code, this.note});

  /// A few words under the time, in place of the "by" time ("back tomorrow 8:00 AM").
  final String? note;

  /// A sign-in code from this sender that is still in date, offered for
  /// copying without opening the email.
  final String? code;
  final MailItem item;
  final bool selected;
  final VoidCallback onTap;

  /// A Focus row: the second line is what is asked, with its "by" time.
  final bool focus;
  final void Function(Offset at)? onMenu;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final due = focus && note == null ? item.reading?.due : null;
    final late = due != null && due.isBefore(DateTime.now());
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppShapes.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('mail-row-${item.id}'),
            onTap: onTap,
            onSecondaryTapUp: onMenu == null ? null : (d) => onMenu!(d.globalPosition),
            // A long press is the phone's right click.
            onLongPress: onMenu == null
                ? null
                : () {
                    final box = context.findRenderObject() as RenderBox?;
                    onMenu!(box == null ? Offset.zero : box.localToGlobal(box.size.center(Offset.zero)));
                  },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: Row(
                children: [
                  TonalAvatar(identityKey: item.senderKey, name: item.senderName, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.senderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall!.copyWith(fontWeight: item.unread && !faded ? FontWeight.w800 : FontWeight.w600),
                              ),
                            ),
                            // The tag is a colored dot, named on hover.
                            if (item.tag != null) ...[const SizedBox(width: 6), Tooltip(message: item.tag!, child: CategoryDot(key: ValueKey('category-pill-${item.id}'), category: item.tag!, size: 8))],
                            if (item.countsTowardUnread) ...[const SizedBox(width: 6), Tooltip(message: 'Counts toward unread', child: Icon(Icons.notifications_active_outlined, size: 13, color: scheme.onSurfaceVariant))],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          focus ? item.ask : item.line,
                          maxLines: code == null ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium!.copyWith(color: item.unread && !faded ? scheme.onSurface : scheme.onSurfaceVariant),
                        ),
                        // When it comes back, on a line of its own so it fits a narrow list.
                        if (note != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              note!,
                              key: ValueKey('mail-note-${item.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall!.copyWith(color: const Color(0xFFCE93D8), fontWeight: FontWeight.w700, letterSpacing: 0),
                            ),
                          ),
                        if (code != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: TimelyCodePill(key: ValueKey('row-code-${item.rowKey}'), code: code!)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(relativeTime(item.at), style: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0)),
                      if (due != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'by ${dueLabel(due)}',
                          key: ValueKey('mail-due-${item.id}'),
                          style: text.labelSmall!.copyWith(color: late ? scheme.error : const Color(0xFFFFB74D), fontWeight: FontWeight.w700, letterSpacing: 0),
                        ),
                      ],
                      if (note != null) ...[
                        const SizedBox(height: 3),
                        const Icon(Icons.snooze_rounded, size: 16, color: Color(0xFFCE93D8)),
                      ] else if (faded) ...[
                        const SizedBox(height: 3),
                        Icon(Icons.check_rounded, size: 16, color: scheme.primary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets a row be dealt with where it sits, without opening it. Pointing at
/// the row shows two buttons at its right end, Done and Not Focus; swiping
/// it right is Done, swiping it left is Not Focus.
class QuickActions extends StatefulWidget {
  const QuickActions({super.key, required this.id, required this.child, required this.onDone, required this.onIgnore, this.onLater, this.touch = false});
  final int id;

  /// A phone: swiping left is Later (on a PC it is Not Focus, and Later is
  /// one of the buttons that show under the pointer).
  final bool touch;
  final Widget child;
  final VoidCallback onDone;

  /// "Later": put it off until a time the user picks.
  final VoidCallback? onLater;

  /// "Not Focus": this one did not need the user.
  final VoidCallback onIgnore;

  @override
  State<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<QuickActions> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget behind(Alignment side, IconData icon, String label, Color color, Color on) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          child: Container(
            alignment: side,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppShapes.lg)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(icon, size: 20, color: on), const SizedBox(width: 8), Text(label, style: text.labelLarge!.copyWith(color: on))],
            ),
          ),
        );
    return Dismissible(
      key: ValueKey('swipe-${widget.id}'),
      background: behind(Alignment.centerLeft, Icons.check_rounded, 'Done', scheme.primaryContainer, scheme.onPrimaryContainer),
      secondaryBackground: widget.touch && widget.onLater != null
          ? behind(Alignment.centerRight, Icons.snooze_rounded, 'Later', scheme.tertiaryContainer, scheme.onTertiaryContainer)
          : behind(Alignment.centerRight, Icons.do_not_disturb_on_outlined, 'Not Focus', scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      // Later asks until when first, so the row stays put until that is answered.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart && widget.touch && widget.onLater != null) {
          widget.onLater!();
          return false;
        }
        return true;
      },
      onDismissed: (direction) => direction == DismissDirection.startToEnd ? widget.onDone() : widget.onIgnore(),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Stack(
          children: [
            widget.child,
            if (_hover)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    key: ValueKey('quick-${widget.id}'),
                    color: scheme.surfaceContainerHighest,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(AppShapes.full),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(key: ValueKey('quick-done-${widget.id}'), tooltip: 'Done', visualDensity: VisualDensity.compact, icon: const Icon(Icons.check_rounded, size: 20), onPressed: widget.onDone),
                          if (widget.onLater != null)
                            IconButton(key: ValueKey('quick-later-${widget.id}'), tooltip: 'Later: bring it back at a time I pick', visualDensity: VisualDensity.compact, icon: const Icon(Icons.snooze_rounded, size: 20), onPressed: widget.onLater),
                          IconButton(
                            key: ValueKey('quick-ignore-${widget.id}'),
                            tooltip: 'Not Focus: this did not need me',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.do_not_disturb_on_outlined, size: 20),
                            onPressed: widget.onIgnore,
                          ),
                        ],
                      ),
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

/// "Later" on a Focus email: asks until when (the same choices Chats
/// offers), takes it out of Focus until then, and offers Undo. Picking
/// "Bring it back now" on one already put off returns it at once.
Future<void> putOffFocusMail(BuildContext context, WidgetRef ref, MailItem item, {String place = 'Focus'}) async {
  final messenger = ScaffoldMessenger.of(context);
  final db = ref.read(databaseProvider);
  final was = item.laterUntil;
  final already = item.putOffAt(DateTime.now());
  final until = await showSnoozePicker(context, currentlySnoozedUntil: already ? was : null);
  if (until == null) return;
  final back = until == SnoozeChoice.unsnooze;
  await db.setLaterUntil(item.id, back ? null : until);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    persist: false,
    duration: const Duration(seconds: 8),
    content: Text(back ? 'Back in $place.' : 'Put off until ${describeSnooze(until)}. It comes back to $place then.', maxLines: 1, overflow: TextOverflow.ellipsis),
    behavior: SnackBarBehavior.floating,
    width: 460,
    action: SnackBarAction(label: 'Undo', onPressed: () => db.setLaterUntil(item.id, already ? was : null)),
  ));
}

/// Opens an email beside its list: its words are shown, and it counts as read.
void openMail(WidgetRef ref, MailItem item) {
  ref.read(expandedMessagesProvider.notifier).expand(item.id);
  if (item.unread) unawaited(ref.read(rowActionsProvider).markMessageRead(item.id));
}

/// The right-click menu of an email row.
Future<void> showMailMenu(BuildContext context, WidgetRef ref, MailItem item, Offset at) async {
  final db = ref.read(databaseProvider);
  final other = item.pile == FeedsPile.noise ? FeedsPile.feed : FeedsPile.noise;
  final otherName = other == FeedsPile.feed ? 'Feed' : 'Noise';
  final picked = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    items: [
      PopupMenuItem(value: 'done', child: Text(item.doneAt == null ? 'Done' : 'Not done')),
      if (item.needsYou) PopupMenuItem(value: 'later', child: Text(item.putOffAt(DateTime.now()) ? 'Later: change or bring back…' : 'Later…')),
      if (item.needsYou) const PopupMenuItem(value: 'notfocus', child: Text('Not Focus')) else if (item.doneAt == null) const PopupMenuItem(value: 'focus', child: Text('This needs me')),
      if (!item.person) ...[
        PopupMenuItem(value: 'one', child: Text('Move this one to $otherName')),
        PopupMenuItem(value: 'sender', child: Text('Always $otherName for this sender')),
        const PopupMenuItem(value: 'person', child: Text('This is a person')),
        CheckedPopupMenuItem(value: 'counts', checked: item.countsTowardUnread, child: const Text('Counts toward unread')),
      ],
      PopupMenuItem(value: 'read', child: Text(item.unread ? 'Mark as read' : 'Mark as unread')),
    ],
  );
  switch (picked) {
    case 'done':
      await db.setMessagesDone([item.id], item.doneAt == null);
    case 'later':
      if (context.mounted) await putOffFocusMail(context, ref, item);
    case 'notfocus':
      await db.setFocusFix(item.id, false);
    case 'focus':
      await db.setFocusFix(item.id, true);
    case 'one':
      await db.setEmailPile(item.id, other);
    case 'sender':
      if (context.mounted) await moveSenderOf(context, ref, item, pile: other);
    case 'person':
      if (context.mounted) await moveSenderOf(context, ref, item);
    case 'counts':
      await ref.read(classificationServiceProvider).setCountsTowardUnread(item.senderKey, !item.countsTowardUnread);
    case 'read':
      await ref.read(rowActionsProvider).markMessageRead(item.id, seen: item.unread);
  }
}

/// The open email beside a list: the thread it belongs to with older
/// messages folded to a line each, this email open, and Done on top.
class MailEmailPane extends ConsumerWidget {
  const MailEmailPane({super.key, required this.item, this.onClose});
  final MailItem item;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final db = ref.read(databaseProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.xl),
        clipBehavior: Clip.antiAlias,
        child: ThreadView(
          key: ValueKey('mail-pane-${item.id}'),
          threadKey: item.threadKey,
          messageId: item.id,
          focusId: item.id,
          onClose: onClose,
          actions: [
            if (item.doneAt == null)
              FilledButton.tonalIcon(
                key: const ValueKey('mail-done'),
                onPressed: () => db.setMessagesDone([item.id], true),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Done'),
              )
            else
              TextButton(key: const ValueKey('mail-undone'), onPressed: () => db.setMessagesDone([item.id], false), child: const Text('Not done')),
            // Later, beside Done, on an email that needs the user.
            if (item.needsYou) ...[
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                key: const ValueKey('mail-later'),
                onPressed: () => putOffFocusMail(context, ref, item),
                icon: const Icon(Icons.snooze_rounded, size: 18),
                label: Text(item.putOffAt(DateTime.now()) ? 'Back ${describeSnooze(item.laterUntil!)}' : 'Later'),
              ),
            ],
            const SizedBox(width: 4),
            // Answering happens right here, under the email.
            if (item.person) ...[
              IconButton(
                key: const ValueKey('mail-reply'),
                tooltip: 'Reply',
                icon: const Icon(Icons.reply_rounded),
                onPressed: () => ref.read(replyRequestProvider.notifier).open(ComposeRequest.reply(item.id, rowKey: item.rowKey)),
              ),
              IconButton(
                key: const ValueKey('mail-reply-all'),
                tooltip: 'Reply all',
                icon: const Icon(Icons.reply_all_rounded),
                onPressed: () => ref.read(replyRequestProvider.notifier).open(ComposeRequest.reply(item.id, rowKey: item.rowKey, all: true)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What the right side says when no email is open.
class MailNothingOpen extends StatelessWidget {
  const MailNothingOpen({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => EmptyState(icon: icon, title: 'Nothing open', message: message);
}
