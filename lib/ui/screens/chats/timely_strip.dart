import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/conversation_state.dart';
import '../../../app/layout.dart';
import '../../../app/mail_state.dart';
import '../../../app/people_state.dart';
import '../../../app/search_state.dart';
import '../../../app/time_format.dart';
import '../../../app/timely_state.dart';
import '../../../store/database.dart';
import '../../../store/helper_queries.dart';
import '../../../store/timely_queries.dart';
import '../../theme/tokens.dart';
import '../../widgets/item_menu.dart';
import 'later_dialogs.dart';

/// Copies a one-time code. The snackbar never repeats the code.
Future<void> copyTimelyCode(BuildContext context, String code) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: code));
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(const SnackBar(persist: false, content: Text('Code copied'), behavior: SnackBarBehavior.floating, width: 240, duration: Duration(seconds: 2)));
}

/// The lines of one card on the Précis page: a one-time code just delivered,
/// a package due soon, a payment coming up. With [card] null, every kind
/// together. Takes no room when there is nothing to show.
class TimelyStrip extends ConsumerStatefulWidget {
  const TimelyStrip({super.key, this.embedded = false, this.card});

  /// Inside a card on the page: no background or outer spacing of its own.
  final bool embedded;

  /// Only this card's items.
  final FyiCard? card;

  static const shownByDefault = 3;

  @override
  ConsumerState<TimelyStrip> createState() => _TimelyStripState();
}

class _TimelyStripState extends ConsumerState<TimelyStrip> {
  Timer? _tick;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Windows open and close with the clock, without any new mail.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final due = timelyDue(ref.watch(timelyItemsProvider).value ?? const [], DateTime.now(), card: widget.card);
    if (due.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final shown = _expanded ? due : due.take(TimelyStrip.shownByDefault).toList();
    final hidden = due.length - shown.length;
    final id = widget.card == null ? '' : '-${widget.card!.id}';
    return Padding(
      key: ValueKey('timely-strip$id'),
      padding: widget.embedded ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: widget.embedded ? Colors.transparent : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppShapes.md),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final i in shown) _TimelyLine(key: ValueKey('timely-line-${i.id}'), item: i),
            if (hidden > 0 || _expanded && due.length > TimelyStrip.shownByDefault)
              TextButton(
                key: ValueKey('timely-more$id'),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Show $hidden more'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelyLine extends ConsumerStatefulWidget {
  const _TimelyLine({super.key, required this.item});
  final TimelyItem item;

  /// Today 7:05 AM, Tomorrow, Thu, Nov 12.
  static String when(DateTime t, DateTime now, {bool withTime = false}) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = day.difference(today).inDays;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final label = diff == 0 ? 'Today' : (diff == 1 ? 'Tomorrow' : (diff > 1 && diff < 7 ? days[t.weekday - 1] : '${months[t.month - 1]} ${t.day}'));
    if (!withTime || (t.hour == 0 && t.minute == 0)) return label;
    return '$label ${clockTime(t)}';
  }

  @override
  ConsumerState<_TimelyLine> createState() => _TimelyLineState();
}

class _TimelyLineState extends ConsumerState<_TimelyLine> {
  /// The mouse is over this line: its small x shows.
  bool _over = false;

  TimelyItem get item => widget.item;

  static IconData _icon(String type) => switch (type) {
        'code' => Icons.password_rounded,
        'confirm' => Icons.mark_email_read_outlined,
        'delivery' => Icons.local_shipping_outlined,
        'flight' => Icons.flight_takeoff_rounded,
        'train' => Icons.train_outlined,
        'hotel' => Icons.hotel_outlined,
        'car' => Icons.directions_car_outlined,
        'event' => Icons.event_outlined,
        'bill' => Icons.receipt_long_outlined,
        _ => Icons.schedule_rounded,
      };

  String _subtitle(DateTime now) {
    final start = item.startsAt;
    final parts = <String>[];
    switch (item.type) {
      case 'code':
        parts.add('One-time code');
      case 'confirm':
        parts.add('Press Confirm to do it from here');
      case 'delivery':
        if (item.status == 'out-for-delivery') {
          parts.add('Out for delivery');
        } else {
          parts.add(start == null ? 'On its way' : 'Arriving ${_TimelyLine.when(start, now)}');
        }
      case 'flight':
      case 'train':
        if (start != null) parts.add('Departs ${_TimelyLine.when(start, now, withTime: true)}');
      case 'hotel':
        if (start != null) parts.add('Check-in ${_TimelyLine.when(start, now, withTime: true)}');
      case 'car':
        if (start != null) parts.add('Pickup ${_TimelyLine.when(start, now, withTime: true)}');
      case 'bill':
        if (start != null) parts.add('Due ${_TimelyLine.when(start, now)}');
      default:
        if (start != null) parts.add(_TimelyLine.when(start, now, withTime: true));
    }
    if (item.detail.isNotEmpty) parts.add(item.detail);
    return parts.join(' · ');
  }

  void _dismiss(BuildContext context) {
    final db = ref.read(databaseProvider);
    final card = FyiCard.of(item.type).title;
    db.dismissTimely(item.id);
    sayDone(context, 'Taken off $card.', undo: () => db.undismissTimely(item.id));
  }

  Future<void> _later(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final card = FyiCard.of(item.type).title;
    final was = item.laterUntil;
    final until = await showSnoozePicker(context);
    if (until == null || until == SnoozeChoice.unsnooze || !context.mounted) return;
    await db.setTimelyLater(item.id, until);
    if (!context.mounted) return;
    sayDone(context, 'Put off until ${describeSnooze(until)}. It comes back to $card then.', undo: () => db.setTimelyLater(item.id, was));
  }

  /// Dismiss this one, put it off, or say notices of this kind from this
  /// sender do not belong on the card.
  List<MenuChoice> _menu(BuildContext context) {
    final db = ref.read(databaseProvider);
    final card = FyiCard.of(item.type).title;
    return [
      MenuChoice('dismiss', kDismiss, Icons.close_rounded, () => _dismiss(context)),
      MenuChoice('later', kLater, Icons.snooze_rounded, () => _later(context)),
      if (item.contactKey.isNotEmpty)
        MenuChoice('reject', kReject, Icons.block_rounded, () {
          db.setFyiOff(item.type, item.contactKey, true);
          sayDone(context, 'Taken off $card. Notices of this kind from ${item.title.isEmpty ? 'this sender' : item.title} stay off it.', undo: () => db.setFyiOff(item.type, item.contactKey, false));
        }),
    ];
  }

  Future<void> _open() async {
    final id = item.messageId;
    if (id != null) {
      ref.read(expandedMessagesProvider.notifier).expand(id);
      ref.read(scrollToMessageProvider.notifier).request(id);
    }
    await openRow(ref.read, 'c:${item.contactKey}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final code = item.code;
    final url = item.actionUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    final canLaunch = uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    final touch = ref.watch(isTouchDeviceProvider);
    // What the assistant says the email is about ("Amazon hard case"). A
    // sign-in code and a confirm-your-address email are known by who sent them.
    final named = item.type == 'code' || item.type == 'confirm' || item.messageId == null ? '' : (ref.watch(mailItemProvider(item.messageId!)).value?.reading?.thing ?? '');
    final delivery = item.type == 'delivery';
    // A delivery is headed by who it comes from, with what is in it in small
    // print underneath. Anything else is headed by what it is.
    final String title;
    final String under;
    String small = '';
    if (item.type == 'confirm') {
      title = 'Confirm your email address for ${item.title.isEmpty ? 'this sender' : item.title}';
      under = _subtitle(DateTime.now());
    } else if (delivery) {
      title = item.title.isEmpty ? (named.isEmpty ? 'A delivery' : named) : item.title;
      under = _subtitle(DateTime.now());
      if (item.title.isNotEmpty) small = named;
    } else {
      title = named.isEmpty ? item.title : named;
      under = [_subtitle(DateTime.now()), if (named.isNotEmpty && item.title.isNotEmpty) item.title].where((s) => s.isNotEmpty).join(' · ');
    }
    final quiet = text.bodySmall!.copyWith(fontSize: 11.5, color: scheme.onSurfaceVariant);
    return MouseRegion(
      onEnter: (_) => setState(() => _over = true),
      onExit: (_) => setState(() => _over = false),
      child: InkWell(
        key: ValueKey('timely-${item.id}'),
        onTap: _open,
        onTapDown: (d) => lastPressAt = d.globalPosition,
        onSecondaryTapUp: (d) => showItemMenu(context, d.globalPosition, _menu(context)),
        onLongPress: () => showItemMenu(context, lastPressAt, _menu(context)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 2, 6),
          child: Row(
            children: [
              Icon(_icon(item.type), size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, key: ValueKey('timely-title-${item.id}'), maxLines: item.type == 'confirm' ? 2 : 1, overflow: TextOverflow.ellipsis, style: text.labelLarge),
                    if (small.isNotEmpty) Text(small, key: ValueKey('timely-inside-${item.id}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: quiet.copyWith(fontSize: 11)),
                    if (under.isNotEmpty) Text(under, maxLines: 1, overflow: TextOverflow.ellipsis, style: quiet),
                  ],
                ),
              ),
              if (code != null)
                TextButton.icon(
                  key: ValueKey('timely-copy-${item.id}'),
                  onPressed: () => copyTimelyCode(context, code),
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  label: Text(code, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                )
              else if (canLaunch && item.type == 'confirm')
                FilledButton.tonal(
                  key: ValueKey('timely-action-${item.id}'),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                  child: Text(item.actionLabel ?? 'Confirm'),
                )
              else if (canLaunch)
                TextButton(
                  key: ValueKey('timely-action-${item.id}'),
                  onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                  child: Text(item.actionLabel ?? 'Open'),
                ),
              // A small x, on a PC, that shows only while the mouse is over
              // the line. (A phone has the press-and-hold menu.)
              if (!touch)
                Opacity(
                  opacity: _over ? 1 : 0,
                  child: IconButton(
                    key: ValueKey('timely-dismiss-${item.id}'),
                    tooltip: 'Dismiss',
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _dismiss(context),
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Gmail-style copy pill under a sender's name on Feeds.
class TimelyCodePill extends StatelessWidget {
  const TimelyCodePill({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(AppShapes.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => copyTimelyCode(context, code),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.content_copy_rounded, size: 12, color: scheme.onSecondaryContainer),
              const SizedBox(width: 4),
              Text('Copy code: $code', style: Theme.of(context).textTheme.labelSmall!.copyWith(color: scheme.onSecondaryContainer, letterSpacing: 0)),
            ],
          ),
        ),
      ),
    );
  }
}
