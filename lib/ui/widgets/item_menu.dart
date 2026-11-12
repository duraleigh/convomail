import 'package:flutter/material.dart';

/// One line of the menu on an item of a Today card.
class MenuChoice {
  const MenuChoice(this.id, this.label, this.icon, this.run);

  /// 'dismiss', 'later', 'reject', …: the menu line's key is `menu-<id>`.
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback run;
}

/// Where the screen was last touched: a press and hold opens its menu there.
Offset? lastPressAt;

/// Opens the menu of an item on a Today card at [at] (the middle of the
/// screen when not known): dismiss it, put it off until later, or say it
/// does not belong there. A right-click opens it on a PC, a press and hold
/// on a phone; a plain click keeps doing what it always did.
Future<void> showItemMenu(BuildContext context, Offset? at, List<MenuChoice> choices) async {
  if (choices.isEmpty) return;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final scheme = Theme.of(context).colorScheme;
  final where = at ?? overlay.size.center(Offset.zero);
  final picked = await showMenu<int>(
    context: context,
    position: RelativeRect.fromRect(where & const Size(1, 1), Offset.zero & overlay.size),
    items: [
      for (var i = 0; i < choices.length; i++)
        PopupMenuItem<int>(
          key: ValueKey('menu-${choices[i].id}'),
          value: i,
          child: Row(
            children: [
              Icon(choices[i].icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Flexible(child: Text(choices[i].label)),
            ],
          ),
        ),
    ],
  );
  if (picked != null) choices[picked].run();
}

/// The same menu for an item that does nothing when clicked.
class ItemMenu extends StatelessWidget {
  const ItemMenu({super.key, required this.choices, required this.child});

  /// Worked out when the menu is asked for.
  final List<MenuChoice> Function() choices;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (d) => showItemMenu(context, d.globalPosition, choices()),
        onLongPressStart: (d) => showItemMenu(context, d.globalPosition, choices()),
        child: child,
      );
}

/// The three words used on every card.
const kDismiss = 'Dismiss';
const kLater = 'Later…';
const kReject = 'Does not belong here';

/// Says what was just done, with a way to take it back, for a few seconds.
void sayDone(BuildContext context, String words, {VoidCallback? undo}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    persist: false,
    duration: const Duration(seconds: 8),
    behavior: SnackBarBehavior.floating,
    content: Text(words, maxLines: 2, overflow: TextOverflow.ellipsis),
    action: undo == null ? null : SnackBarAction(label: 'Undo', onPressed: undo),
  ));
}
