import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/account_scope.dart';
import '../../../app/mail_state.dart';
import '../../../domain/piles.dart';
import '../../../store/people_queries.dart';
import '../../theme/tokens.dart';
import '../../widgets/category_color.dart';
import '../../widgets/tonal_avatar.dart';
import 'people_list_pane.dart';
import 'timely_strip.dart';

/// One People-list row (spec 4.2): avatar, name, the user's optional
/// subtitle, time, unread badge, pin marker; no message text. Hovering fades
/// the time and unread count into one "more" button in the same spot, so
/// nothing moves and names keep their room; hovering that button pops up the
/// actions above the row, and clicking it (or right-clicking the row) opens
/// the full menu.
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

  bool _pointerIn = false;

  /// The actions strip is open (the pointer may be on it, outside the row).
  bool _stripOpen = false;

  bool get _hover => _pointerIn || _stripOpen;

  Future<void> _showMenu(Offset globalPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<RowAction>(
      context: context,
      position: RelativeRect.fromRect(globalPosition & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        const PopupMenuItem(
          value: RowAction.archive,
          child: ListTile(leading: Icon(Icons.archive_outlined), title: Text('Archive all'), dense: true),
        ),
        const PopupMenuItem(
          value: RowAction.trash,
          child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Delete…'), dense: true),
        ),
        const PopupMenuItem(
          value: RowAction.markRead,
          child: ListTile(leading: Icon(Icons.mark_email_read_outlined), title: Text('Mark all as read'), dense: true),
        ),
        PopupMenuItem(
          value: RowAction.snooze,
          child: ListTile(leading: const Icon(Icons.snooze_outlined), title: Text(widget.row.isSnoozed ? 'Later… (change)' : 'Later…'), dense: true),
        ),
        PopupMenuItem(
          value: RowAction.mute,
          child: ListTile(
            leading: Icon(widget.row.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
            title: Text(widget.row.muted ? 'Unmute notifications' : 'Mute notifications'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: RowAction.pin,
          child: ListTile(leading: Icon(widget.row.pinned ? Icons.push_pin : Icons.push_pin_outlined), title: Text(widget.row.pinned ? 'Unpin' : 'Pin'), dense: true),
        ),
        if (!widget.row.isGroup && widget.row.identityKey != 'me')
          const PopupMenuItem(
            value: RowAction.rename,
            child: ListTile(leading: Icon(Icons.drive_file_rename_outline_rounded), title: Text('Edit name and subtitle…'), dense: true),
          ),
        if (!widget.row.isGroup && widget.row.identityKey != 'me')
          const PopupMenuItem(
            value: RowAction.mergeWith,
            child: ListTile(leading: Icon(Icons.merge_rounded), title: Text('Merge with…'), dense: true),
          ),
        if (!widget.row.isGroup) ...[
          const PopupMenuDivider(),
          // The two places this sender is not in. A move stays until the
          // user changes it.
          if (widget.row.isFeeds)
            const PopupMenuItem(value: RowAction.moveToChats, child: ListTile(leading: Icon(Icons.person_outline_rounded), title: Text('Move to Chats'), subtitle: Text('Stays there until you change it'), dense: true)),
          if (!widget.row.isFeeds || widget.row.pile == FeedsPile.noise)
            const PopupMenuItem(value: RowAction.moveToFeed, child: ListTile(leading: Icon(Icons.rss_feed_rounded), title: Text('Move to Feed'), subtitle: Text('Stays there until you change it'), dense: true)),
          if (!widget.row.isFeeds || widget.row.pile != FeedsPile.noise)
            const PopupMenuItem(value: RowAction.moveToNoise, child: ListTile(leading: Icon(Icons.volume_off_outlined), title: Text('Move to Noise'), subtitle: Text('Stays there until you change it'), dense: true)),
          if (widget.row.isFeeds) ...[
            PopupMenuItem(
              value: RowAction.toggleCounts,
              child: ListTile(
                leading: Icon(widget.row.countsTowardUnread ? Icons.notifications_active : Icons.notifications_none_rounded),
                title: Text(widget.row.countsTowardUnread ? 'Stop counting toward unread' : 'Counts toward unread'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: RowAction.category,
              child: ListTile(leading: Icon(Icons.label_outline_rounded), title: Text('Category…'), dense: true),
            ),
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
        onEnter: (_) => setState(() => _pointerIn = true),
        onExit: (_) => setState(() => _pointerIn = false),
        child: GestureDetector(
          onSecondaryTapUp: (d) => _showMenu(d.globalPosition),
          // A long press is the phone's right click.
          onLongPressStart: (d) => _showMenu(d.globalPosition),
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
                        ? Checkbox(key: ValueKey('row-check-${row.rowKey}'), value: widget.checked, onChanged: (_) => widget.onCheck!())
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
                            if (row.pinned) ...[Icon(Icons.push_pin, size: 14, color: scheme.onSurfaceVariant), const SizedBox(width: 4)],
                            if (ref.watch(multiAccountProvider) && ref.watch(accountScopeProvider) == null && row.accountIds.isNotEmpty) ...[
                              for (final id in row.accountIds.take(3))
                                Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Container(
                                    key: ValueKey('account-dot-${row.rowKey}-$id'),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: accountColor(id, scheme), shape: BoxShape.circle),
                                  ),
                                ),
                              const SizedBox(width: 3),
                            ],
                            if (row.muted) ...[
                              Tooltip(
                                message: 'Notifications muted',
                                child: Icon(Icons.notifications_off_outlined, size: 14, color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (row.isSnoozed) ...[
                              Tooltip(
                                message: 'Put off until later',
                                child: Icon(Icons.snooze_rounded, size: 14, color: scheme.tertiary),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (row.isFeeds && row.countsTowardUnread) ...[
                              Tooltip(
                                message: 'Counts toward unread',
                                child: Icon(Icons.notifications_active, size: 14, color: scheme.primary),
                              ),
                              const SizedBox(width: 4),
                            ],
                            // The name, then right after it the category dot.
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      row.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      key: ValueKey('row-name-${row.rowKey}'),
                                      style: text.titleMedium!.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w500, height: 1.2),
                                    ),
                                  ),
                                  // A small pink dot when one of this person's emails
                                  // is in Focus.
                                  if (!row.onFeedsTab && ref.watch(focusRowKeysProvider).contains(row.rowKey)) ...[
                                    const SizedBox(width: 8),
                                    Tooltip(
                                      message: 'Has an email in Focus',
                                      child: Container(
                                        key: ValueKey('focus-dot-${row.rowKey}'),
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: Color(0xFFF48FB1), shape: BoxShape.circle),
                                      ),
                                    ),
                                  ],
                                  // The category as a dot in its colour (the pills along
                                  // the top say which colour is which): no written tag
                                  // taking the name's room.
                                  if (row.onFeedsTab && row.category != null) ...[
                                    const SizedBox(width: 8),
                                    Tooltip(
                                      message: row.category!,
                                      child: CategoryDot(key: ValueKey('category-pill-${row.rowKey}'), category: row.category!),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // The time and unread count take their own width only.
                            // While hovered they fade out and one "more" button
                            // fades in over the same spot: nothing moves.
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: _RowMoreButton.size),
                              child: Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  AnimatedOpacity(
                                    opacity: _hover ? 0 : 1,
                                    duration: const Duration(milliseconds: 140),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          relativeTime(row.lastActivity),
                                          style: text.labelSmall!.copyWith(
                                            color: unread ? scheme.primary : scheme.onSurfaceVariant,
                                            fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                        if (unread) ...[const SizedBox(width: 8), CountBadge(row.unread)],
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 140),
                                      child: _hover
                                          ? _RowMoreButton(
                                              key: ValueKey('row-more-${row.rowKey}'),
                                              row: row,
                                              onAction: widget.onAction,
                                              onMenu: _showMenu,
                                              onStripOpen: (open) {
                                                if (mounted && open != _stripOpen) setState(() => _stripOpen = open);
                                              },
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
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
                                    if (widget.liveCode != null) ...[TimelyCodePill(key: ValueKey('row-code-${row.rowKey}'), code: widget.liveCode!), const SizedBox(width: 6)],
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
                                                style: text.bodySmall!.copyWith(fontSize: 11.5, height: 1.25, letterSpacing: 0.2, fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
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

/// The one button a hovered row shows. Hovering it pops up the row's
/// actions in a small strip just above the row (so the row's name stays in
/// view); clicking it opens the full menu.
class _RowMoreButton extends StatefulWidget {
  const _RowMoreButton({super.key, required this.row, required this.onAction, required this.onMenu, required this.onStripOpen});
  final PeopleRow row;
  final ValueChanged<RowAction> onAction;
  final Future<void> Function(Offset globalPosition) onMenu;
  final ValueChanged<bool> onStripOpen;

  static const double size = 28;

  @override
  State<_RowMoreButton> createState() => _RowMoreButtonState();
}

class _RowMoreButtonState extends State<_RowMoreButton> {
  final _portal = OverlayPortalController();
  Timer? _hide;

  void _open() {
    _hide?.cancel();
    if (_portal.isShowing) return;
    _portal.show();
    widget.onStripOpen(true);
  }

  void _close() {
    _hide?.cancel();
    if (!_portal.isShowing) return;
    _portal.hide();
    widget.onStripOpen(false);
  }

  /// Closes a moment after the pointer leaves, so it can cross the gap
  /// between the button and the strip.
  void _leave() {
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 220), () {
      if (mounted) _close();
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    if (_portal.isShowing) {
      final report = widget.onStripOpen;
      WidgetsBinding.instance.addPostFrameCallback((_) => report(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strip = MouseRegion(
      onEnter: (_) => _open(),
      onExit: (_) => _leave(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 4 * (1 - t)), child: child),
        ),
        child: Material(
          color: scheme.surfaceContainerHigh,
          elevation: 3,
          shadowColor: Colors.black,
          borderRadius: BorderRadius.circular(AppShapes.full),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: _HoverActions(
              row: widget.row,
              onAction: (a) {
                _close();
                widget.onAction(a);
              },
            ),
          ),
        ),
      ),
    );
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      // Just above the button, right edges lined up.
      overlayChildBuilder: (context, info) {
        final at = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
        return Stack(
          children: [Positioned(right: info.overlaySize.width - at.right - 4, bottom: info.overlaySize.height - at.top + 2, child: strip)],
        );
      },
      child: MouseRegion(
        onEnter: (_) => _open(),
        onExit: (_) => _leave(),
        child: Builder(
          builder: (context) => IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: _RowMoreButton.size, height: 24),
            style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            onPressed: () {
              _close();
              final box = context.findRenderObject() as RenderBox;
              widget.onMenu(box.localToGlobal(box.size.bottomRight(Offset.zero)));
            },
          ),
        ),
      ),
    );
  }
}

class _HoverActions extends StatelessWidget {
  const _HoverActions({required this.row, required this.onAction});
  final PeopleRow row;
  final ValueChanged<RowAction> onAction;

  static const double _button = 30;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(IconData icon, String tip, RowAction a) => IconButton(
      tooltip: tip,
      icon: Icon(icon),
      iconSize: 17,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: _button, height: 30),
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
        btn(Icons.snooze_outlined, 'Later… (S)', RowAction.snooze),
        btn(row.pinned ? Icons.push_pin : Icons.push_pin_outlined, row.pinned ? 'Unpin (P)' : 'Pin (P)', RowAction.pin),
      ],
    );
  }
}
