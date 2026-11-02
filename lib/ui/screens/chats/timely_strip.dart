import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/conversation_state.dart';
import '../../../app/people_state.dart';
import '../../../app/search_state.dart';
import '../../../app/timely_state.dart';
import '../../../store/database.dart';
import '../../../store/timely_queries.dart';
import '../../theme/tokens.dart';

/// Copies a one-time code. The snackbar never repeats the code.
Future<void> copyTimelyCode(BuildContext context, String code) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: code));
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(const SnackBar(content: Text('Code copied'), behavior: SnackBarBehavior.floating, width: 240, duration: Duration(seconds: 2)));
}

/// Timely things pinned above the list (spec 4.21): a one-time code just
/// delivered, a package due soon, a departure coming up. Takes no room when
/// there is nothing timely.
class TimelyStrip extends ConsumerStatefulWidget {
  const TimelyStrip({super.key});

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
    final due = timelyDue(ref.watch(timelyItemsProvider).value ?? const [], DateTime.now());
    if (due.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final shown = _expanded ? due : due.take(TimelyStrip.shownByDefault).toList();
    final hidden = due.length - shown.length;
    return Padding(
      key: const ValueKey('timely-strip'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppShapes.md),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final i in shown) _TimelyLine(item: i),
            if (hidden > 0 || _expanded && due.length > TimelyStrip.shownByDefault)
              TextButton(
                key: const ValueKey('timely-more'),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Show $hidden more'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelyLine extends ConsumerWidget {
  const _TimelyLine({required this.item});
  final TimelyItem item;

  static IconData _icon(String type) => switch (type) {
        'code' => Icons.password_rounded,
        'delivery' => Icons.local_shipping_outlined,
        'flight' => Icons.flight_takeoff_rounded,
        'train' => Icons.train_outlined,
        'hotel' => Icons.hotel_outlined,
        'car' => Icons.directions_car_outlined,
        'event' => Icons.event_outlined,
        'bill' => Icons.receipt_long_outlined,
        _ => Icons.schedule_rounded,
      };

  /// Today 7:05 AM, Tomorrow, Thu, Nov 12.
  static String when(DateTime t, DateTime now, {bool withTime = false}) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = day.difference(today).inDays;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final label = diff == 0 ? 'Today' : (diff == 1 ? 'Tomorrow' : (diff > 1 && diff < 7 ? days[t.weekday - 1] : '${months[t.month - 1]} ${t.day}'));
    if (!withTime || (t.hour == 0 && t.minute == 0)) return label;
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$label $hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  String _subtitle(DateTime now) {
    final start = item.startsAt;
    final parts = <String>[];
    switch (item.type) {
      case 'code':
        parts.add('One-time code');
      case 'delivery':
        if (item.status == 'out-for-delivery') {
          parts.add('Out for delivery');
        } else {
          parts.add(start == null ? 'On its way' : 'Arriving ${when(start, now)}');
        }
      case 'flight':
      case 'train':
        if (start != null) parts.add('Departs ${when(start, now, withTime: true)}');
      case 'hotel':
        if (start != null) parts.add('Check-in ${when(start, now, withTime: true)}');
      case 'car':
        if (start != null) parts.add('Pickup ${when(start, now, withTime: true)}');
      case 'bill':
        if (start != null) parts.add('Due ${when(start, now)}');
      default:
        if (start != null) parts.add(when(start, now, withTime: true));
    }
    if (item.detail.isNotEmpty) parts.add(item.detail);
    return parts.join(' · ');
  }

  Future<void> _open(WidgetRef ref) async {
    final id = item.messageId;
    if (id != null) {
      ref.read(expandedMessagesProvider.notifier).expand(id);
      ref.read(scrollToMessageProvider.notifier).request(id);
    }
    await openRow(ref.read, 'c:${item.contactKey}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final code = item.code;
    final url = item.actionUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    final canLaunch = uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    return InkWell(
      key: ValueKey('timely-${item.id}'),
      onTap: () => _open(ref),
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
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge),
                  Text(_subtitle(DateTime.now()), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(fontSize: 11.5, color: scheme.onSurfaceVariant)),
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
            else if (canLaunch)
              TextButton(
                key: ValueKey('timely-action-${item.id}'),
                onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                child: Text(item.actionLabel ?? 'Open'),
              ),
            IconButton(
              key: ValueKey('timely-dismiss-${item.id}'),
              tooltip: 'Dismiss',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => ref.read(databaseProvider).dismissTimely(item.id),
            ),
          ],
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
