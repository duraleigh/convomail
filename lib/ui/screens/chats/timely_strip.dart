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
import '../page_type.dart';
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
            for (var n = 0; n < shown.length; n++) ...[
              if (n > 0 && widget.embedded) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)),
              _TimelyLine(key: ValueKey('timely-line-${shown[n].id}'), item: shown[n], embedded: widget.embedded),
            ],
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
  const _TimelyLine({super.key, required this.item, this.embedded = false});
  final TimelyItem item;
  final bool embedded;

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

  /// "Due today", "Due Monday", "Due Nov 20".
  static String _due(DateTime day, DateTime now) {
    final w = dayWord(day, now, long: true);
    return 'Due ${w == 'Today' || w == 'Tomorrow' || w == 'Yesterday' ? w.toLowerCase() : w}';
  }

  /// "$16.58" out of "$16.58 due"; "" when the email named no amount.
  static String _amount(String detail) => RegExp(r'^(.*\d.*?)(?:\s+due)?$').firstMatch(detail)?.group(1) ?? '';

  /// The word a time goes by, for the kinds the rules find when the
  /// assistant is off.
  static String _verb(String type) => switch (type) {
        'flight' || 'train' => 'Departs',
        'hotel' => 'Check-in',
        'car' => 'Pickup',
        _ => '',
      };

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
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final code = item.code;
    final url = item.actionUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    final canLaunch = uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    final touch = ref.watch(isTouchDeviceProvider);
    // What the assistant says the email is about ("Amazon hard case"). A
    // sign-in code and a confirm-your-address email are known by who sent them.
    final named = item.type == 'code' || item.type == 'confirm' || item.messageId == null ? '' : (ref.watch(mailItemProvider(item.messageId!)).value?.reading?.thing ?? '');
    final sender = item.title;
    final start = item.startsAt;

    // The line: what it is, a smaller line under it, and on the right the
    // day, time or amount, with one thing to press.
    String title;
    var under = '';
    var top = '';
    var bottom = '';
    Color? topColor;
    var steps = 0;
    var showAction = canLaunch;
    switch (item.type) {
      case 'code':
        title = code ?? sender;
        final minutes = (item.hideAfter.difference(now).inSeconds / 60).ceil();
        under = [if (sender.isNotEmpty) sender, if (minutes > 0) '$minutes minute${minutes == 1 ? '' : 's'} left'].join(' · ');
      case 'confirm':
        title = 'Confirm your email address';
        under = 'for ${sender.isEmpty ? 'this sender' : sender}';
      case 'delivery':
        // Headed by what is in it, when the assistant could tell; who sent
        // it and who carries it underneath.
        final delivered = item.status == 'delivered';
        final out = item.status == 'out-for-delivery';
        title = named.isNotEmpty ? named : (sender.isNotEmpty ? sender : 'A delivery');
        under = [if (out) 'Out for delivery', if (named.isNotEmpty && sender.isNotEmpty) sender, if (item.detail.isNotEmpty) item.detail].join(' · ');
        steps = delivered ? 3 : (out ? 2 : 1);
        if (delivered) {
          top = 'Delivered';
          topColor = okColor;
          bottom = clockTime(item.mailAt ?? item.showFrom);
          showAction = false;
        } else if (out) {
          top = 'Today';
        } else if (start != null) {
          top = dayWord(start, now);
        }
      case 'bill':
        title = named.isEmpty ? sender : named;
        top = _amount(item.detail);
        under = [if (start != null) _due(start, now), if (top.isEmpty && item.detail.isNotEmpty && item.detail != 'Payment due') item.detail, if (named.isNotEmpty && sender.isNotEmpty) sender].join(' · ');
      default:
        title = named.isEmpty ? sender : named;
        final verb = _verb(item.type);
        under = [if (start != null && verb.isNotEmpty && item.detail != verb) verb, if (item.detail.isNotEmpty) item.detail, if (named.isNotEmpty && sender.isNotEmpty) sender].join(' · ');
        if (start != null) {
          top = dayWord(start, now);
          if (start.hour != 0 || start.minute != 0) bottom = clockTime(start);
        }
    }
    final stage = switch (steps) { 3 => 'Delivered', 2 => 'Out for delivery', _ => 'On its way' };
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
          padding: EdgeInsets.fromLTRB(widget.embedded ? 0 : 12, 10, 0, 10),
          child: Row(
            children: [
              RowIcon(item.type == 'delivery' ? Icons.inventory_2_outlined : _icon(item.type)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: ValueKey('timely-title-${item.id}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      // A code is read off the screen and typed: larger, with even digits.
                      style: item.type == 'code' && code != null ? rowTitle(context, strong: true).copyWith(fontSize: 16, letterSpacing: 1.4, fontFeatures: tabularFigures) : rowTitle(context),
                    ),
                    if (under.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(under, key: ValueKey('timely-under-${item.id}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: rowSmall(context))),
                    // Where a package is: on its way, out for delivery, delivered.
                    if (steps > 0)
                      Semantics(
                        key: ValueKey('timely-steps-${item.id}'),
                        label: stage,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Row(
                            children: [
                              for (var n = 0; n < 3; n++)
                                Expanded(
                                  child: Container(
                                    height: 3,
                                    margin: EdgeInsets.only(right: n < 2 ? 4 : 0),
                                    decoration: BoxDecoration(color: n < steps ? (steps == 3 ? okColor : scheme.primary) : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (code != null)
                FilledButton.tonalIcon(
                  key: ValueKey('timely-copy-${item.id}'),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => copyTimelyCode(context, code),
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  label: const Text('Copy'),
                )
              else if (canLaunch && item.type == 'confirm')
                FilledButton.tonal(
                  key: ValueKey('timely-action-${item.id}'),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                  child: Text(item.actionLabel ?? 'Confirm'),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (top.isNotEmpty) Text(top, key: ValueKey('timely-when-${item.id}'), style: rowTitle(context).copyWith(fontFeatures: tabularFigures, color: topColor)),
                    if (showAction)
                      InkWell(
                        key: ValueKey('timely-action-${item.id}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => launchUrl(uri!, mode: LaunchMode.externalApplication),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 4, 0, 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item.actionLabel ?? 'Open', style: rowSmall(context).copyWith(color: scheme.primary, fontWeight: FontWeight.w500)),
                              Icon(Icons.chevron_right_rounded, size: 16, color: scheme.primary),
                            ],
                          ),
                        ),
                      )
                    else if (bottom.isNotEmpty)
                      Text(bottom, key: ValueKey('timely-at-${item.id}'), style: rowSmall(context).copyWith(fontFeatures: tabularFigures)),
                  ],
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
                ),
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
