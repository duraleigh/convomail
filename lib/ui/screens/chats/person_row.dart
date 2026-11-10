import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/account_scope.dart';

import '../../../store/people_queries.dart';
import '../../theme/tokens.dart';
import '../../widgets/tonal_avatar.dart';
import 'people_list_pane.dart';
import 'timely_strip.dart';

/// One People-list row (spec 4.2): avatar, name, the user's optional
/// subtitle, time, unread badge, pin marker; no message text. Hovering swaps
/// the time and unread count, in their own fixed spot on the right, for the
/// action buttons, with a short fade: nothing moves and the name is never
/// covered. Right-click opens the same actions as a context menu.
class PersonRow extends ConsumerStatefulWidget {
  const PersonRow({super.key, required this.row, required this.selected, required this.onAction, this.checked = false, this.selectionMode = false, this.onCheck, this.liveCode});

  /// A one-time code from this sender still in date, offered for copying.
  final String? liveCode;

  final PeopleRow row;
  final bool selected;
  final ValueChanged<RowAction> onAction;

  /// Picked for a bulk action.
  final bool checked;

  /// Some rows are picked: every row shows its checkbox.
  final bool selectionMode;

  /// Toggles [checked]; null hides the checkbox (search results).
  final VoidCallback? onCheck;

  @override
  ConsumerState<PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends ConsumerState<PersonRow> {
  /// Screen-reader label (plan M12 accessibility): name, unread count,
  /// and row state, so the row reads as one item.
  static String semanticLabel(PeopleRow row) => [
        row.title,
        if (row.subtitle != null) row.subtitle!,
        if (row.unread > 0) '${row.unread} unread',
        if (row.pinned) 'pinned',
        if (row.muted) 'muted',
        if (row.snoozedUntil != null) 'snoozed',
      ].join(', ');

  bool _hover = false;

  Future<void> _showMenu(Offset globalPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<RowAction>(
      context: context,
      position: RelativeRect.fromRect(globalPosition & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        const PopupMenuItem(value: RowAction.archive, child: ListTile(leading: Icon(Icons.archive_outlined), title: Text('Archive all'), dense: true)),
        const PopupMenuItem(value: RowAction.trash, child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Delete…'), dense: true)),
        const PopupMenuItem(value: RowAction.markRead, child: ListTile(leading: Icon(Icons.mark_email_read_outlined), title: Text('Mark all as read'), dense: true)),
        PopupMenuItem(value: RowAction.snooze, child: ListTile(leading: const Icon(Icons.snooze_outlined), title: Text(widget.row.isSnoozed ? 'Snoozed… (change)' : 'Snooze…'), dense: true)),
        PopupMenuItem(value: RowAction.mute, child: ListTile(leading: Icon(widget.row.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined), title: Text(widget.row.muted ? 'Unmute notifications' : 'Mute notifications'), dense: true)),
        PopupMenuItem(
          value: RowAction.pin,
          child: ListTile(
            leading: Icon(widget.row.pinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(widget.row.pinned ? 'Unpin' : 'Pin'),
            dense: true,
          ),
        ),
        if (!widget.row.isGroup && widget.row.identityKey != 'me')
          const PopupMenuItem(value: RowAction.rename, child: ListTile(leading: Icon(Icons.drive_file_rename_outline_rounded), title: Text('Edit name and subtitle…'), dense: true)),
        if (!widget.row.isGroup && widget.row.identityKey != 'me')
          const PopupMenuItem(value: RowAction.mergeWith, child: ListTile(leading: Icon(Icons.merge_rounded), title: Text('Merge with…'), dense: true)),
        if (!widget.row.isGroup) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: widget.row.isFeeds ? RowAction.moveToPeople : RowAction.moveToFeeds,
            child: ListTile(
              leading: Icon(widget.row.isFeeds ? Icons.person_outline_rounded : Icons.rss_feed_rounded),
              title: Text(widget.row.isFeeds ? 'Move to People' : 'Move to Feeds'),
              subtitle: const Text('Permanent until you change it'),
              dense: true,
            ),
          ),
          if (widget.row.isFeeds) ...[
            PopupMenuItem(
              value: RowAction.toggleCounts,
              child: ListTile(
                leading: Icon(widget.row.countsTowardUnread ? Icons.notifications_active : Icons.notifications_none_rounded),
                title: Text(widget.row.countsTowardUnread ? 'Stop counting toward unread' : 'Counts toward unread'),
                dense: true,
              ),
            ),
            const PopupMenuItem(value: RowAction.category, child: ListTile(leading: Icon(Icons.label_outline_rounded), title: Text('Category…'), dense: true)),
          ],
        ],
      ],
    );
    if (action != null) widget.onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final row = widget.row;
    final unread = row.unread > 0;
    final subtitle = row.subtitle;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: semanticLabel(row),
      child: MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onSecondaryTapUp: (d) => _showMenu(d.globalPosition),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
          child: Row(
            children: [
              // The avatar and the checkbox share one spot and crossfade.
              SizedBox(
                width: 36,
                height: 36,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: widget.onCheck != null && (widget.selectionMode || _hover)
                      ? Checkbox(
                          key: ValueKey('row-check-${row.rowKey}'),
                          value: widget.checked,
                          onChanged: (_) => widget.onCheck!(),
                        )
                      : KeyedSubtree(key: const ValueKey('avatar'), child: rowAvatar(row, size: 36)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (row.pinned) ...[
                          Icon(Icons.push_pin, size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                        ],
                        if (ref.watch(multiAccountProvider) && ref.watch(accountScopeProvider) == null && row.accountIds.isNotEmpty) ...[
                          for (final id in row.accountIds.take(3))
                            Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Container(key: ValueKey('account-dot-${row.rowKey}-$id'), width: 8, height: 8, decoration: BoxDecoration(color: accountColor(id, scheme), shape: BoxShape.circle)),
                            ),
                          const SizedBox(width: 3),
                        ],
                        if (row.muted) ...[
                          Tooltip(message: 'Notifications muted', child: Icon(Icons.notifications_off_outlined, size: 14, color: scheme.onSurfaceVariant)),
                          const SizedBox(width: 4),
                        ],
                        if (row.isSnoozed) ...[
                          Tooltip(message: 'Snoozed', child: Icon(Icons.snooze_rounded, size: 14, color: scheme.tertiary)),
                          const SizedBox(width: 4),
                        ],
                        if (row.isFeeds && row.countsTowardUnread) ...[
                          Tooltip(message: 'Counts toward unread', child: Icon(Icons.notifications_active, size: 14, color: scheme.primary)),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) => Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    key: ValueKey('row-name-${row.rowKey}'),
                                    style: text.titleMedium!.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w500, height: 1.2),
                                  ),
                                ),
                                if (row.onFeedsTab && row.category != null) ...[
                                  const SizedBox(width: 8),
                                  // Never more than half the room, so it cannot
                                  // squeeze the name out or overflow the row.
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
                                    child: Container(
                                      key: ValueKey('category-pill-${row.rowKey}'),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                                      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(AppShapes.full)),
                                      child: Text(row.category!, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall!.copyWith(color: scheme.onSecondaryContainer, letterSpacing: 0)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // One fixed spot: the time and unread count, or while
                        // hovered the actions, fading in place of each other.
                        SizedBox(
                          width: _HoverActions.width,
                          height: 24,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeIn,
                            layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerRight, children: [...previous, ?current]),
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: child is _HoverActions
                                  ? SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation), child: child)
                                  : child,
                            ),
                            child: _hover
                                ? _HoverActions(key: const ValueKey('actions'), row: row, onAction: widget.onAction)
                                : Row(
                                    key: const ValueKey('time'),
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          relativeTime(row.lastActivity),
                                          maxLines: 1,
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: text.labelSmall!.copyWith(
                                            color: unread ? scheme.primary : scheme.onSurfaceVariant,
                                            fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                      ),
                                      if (unread) ...[const SizedBox(width: 8), CountBadge(row.unread)],
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 110),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: subtitle == null && widget.liveCode == null
                          ? const SizedBox(width: double.infinity)
                          : Row(
                              children: [
                                if (widget.liveCode != null) ...[
                                  TimelyCodePill(key: ValueKey('row-code-${row.rowKey}'), code: widget.liveCode!),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: subtitle == null
                                      ? const SizedBox.shrink()
                                      : Padding(
                                          padding: const EdgeInsets.only(top: 1),
                                          child: Text(
                                            subtitle,
                                            key: ValueKey('row-subtitle-${row.rowKey}'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: text.bodySmall!.copyWith(
                                              fontSize: 11.5,
                                              height: 1.25,
                                              letterSpacing: 0.2,
                                              fontWeight: FontWeight.w400,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _HoverActions extends StatelessWidget {
  const _HoverActions({super.key, required this.row, required this.onAction});
  final PeopleRow row;
  final ValueChanged<RowAction> onAction;

  static const double _button = 26;
  static const double width = _button * 5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(IconData icon, String tip, RowAction a) => IconButton(
          tooltip: tip,
          icon: Icon(icon),
          iconSize: 17,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: _button, height: 24),
          style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: () => onAction(a),
        );
    return Row(
      key: ValueKey('row-actions-${row.rowKey}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.archive_outlined, 'Archive all (E)', RowAction.archive),
        btn(Icons.delete_outline_rounded, 'Delete… (Del)', RowAction.trash),
        btn(Icons.mark_email_read_outlined, 'Mark all as read', RowAction.markRead),
        btn(Icons.snooze_outlined, 'Snooze… (S)', RowAction.snooze),
        btn(row.pinned ? Icons.push_pin : Icons.push_pin_outlined, row.pinned ? 'Unpin (P)' : 'Pin (P)', RowAction.pin),
      ],
    );
  }
}
