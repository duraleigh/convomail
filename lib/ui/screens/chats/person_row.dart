import 'package:flutter/material.dart';

import '../../../store/people_queries.dart';
import '../../theme/tokens.dart';
import '../../widgets/tonal_avatar.dart';
import 'people_list_pane.dart';

/// One People-list row (spec 4.2): avatar, name, preview, time, unread
/// badge, pin marker. Hover reveals action buttons; right-click opens the
/// same actions as a context menu.
class PersonRow extends StatefulWidget {
  const PersonRow({super.key, required this.row, required this.selected, required this.onAction});

  final PeopleRow row;
  final bool selected;
  final ValueChanged<RowAction> onAction;

  @override
  State<PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<PersonRow> {
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
        PopupMenuItem(
          value: RowAction.pin,
          child: ListTile(
            leading: Icon(widget.row.pinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(widget.row.pinned ? 'Unpin' : 'Pin'),
            dense: true,
          ),
        ),
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onSecondaryTapUp: (d) => _showMenu(d.globalPosition),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              rowAvatar(row, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (row.pinned) ...[
                          Icon(Icons.push_pin, size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            row.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium!.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
                          ),
                        ),
                        if (!_hover) ...[
                          const SizedBox(width: 8),
                          Text(
                            relativeTime(row.lastActivity),
                            style: text.labelSmall!.copyWith(
                              color: unread ? scheme.primary : scheme.onSurfaceVariant,
                              fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.previewFromMe ? 'You: ${row.preview}' : row.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        if (!_hover && unread) ...[const SizedBox(width: 8), CountBadge(row.unread)],
                      ],
                    ),
                  ],
                ),
              ),
              if (_hover) ...[
                const SizedBox(width: 6),
                _HoverActions(row: row, onAction: widget.onAction),
              ],
            ],
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(IconData icon, String tip, RowAction a) => IconButton(
          tooltip: tip,
          icon: Icon(icon, size: 20),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant, minimumSize: const Size(32, 32)),
          onPressed: () => onAction(a),
        );
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppShapes.full)),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.archive_outlined, 'Archive all (E)', RowAction.archive),
          btn(Icons.delete_outline_rounded, 'Delete… (Del)', RowAction.trash),
          btn(Icons.mark_email_read_outlined, 'Mark all as read', RowAction.markRead),
          btn(row.pinned ? Icons.push_pin : Icons.push_pin_outlined, row.pinned ? 'Unpin (P)' : 'Pin (P)', RowAction.pin),
        ],
      ),
    );
  }
}
