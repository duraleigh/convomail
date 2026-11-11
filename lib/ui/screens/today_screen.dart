import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/account_scope.dart';
import '../../app/calendar_state.dart';
import '../../app/compose_state.dart';
import '../../app/conversation_state.dart';
import '../../app/destinations.dart';
import '../../app/mail_state.dart';
import '../../app/people_state.dart';
import '../../app/settings_navigation.dart';
import '../../app/timely_state.dart';
import '../../helper/helper_sync.dart';
import '../../store/database.dart';
import '../../store/done_queries.dart';
import '../../store/mail_queries.dart';
import '../../store/planner_queries.dart';
import '../../sync/calendar_sync.dart';
import '../../sync/waiting_sends.dart';
import '../theme/tokens.dart';
import '../widgets/reading_line.dart';
import '../widgets/tonal_avatar.dart';
import 'chats/later_dialogs.dart';
import 'chats/thread_view_panel.dart';
import 'chats/timely_strip.dart';
import 'mail/mail_widgets.dart' show openMail, putOffFocusMail;

/// Today's calendar events, in the calendars the user shows.
final todayEventsProvider = StreamProvider<List<PlannerEvent>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return watchShownEvents(ref, start, start.add(const Duration(days: 1)));
});

final waitingOnProvider = StreamProvider<List<WaitingItem>>((ref) => ref.watch(databaseProvider).watchWaitingOn(accountId: ref.watch(accountScopeProvider)));
final sentNotReadYetProvider = StreamProvider<int>((ref) => ref.watch(databaseProvider).watchSentWithoutWordsCount(accountId: ref.watch(accountScopeProvider)));
final laterRowsProvider = StreamProvider<List<LaterRow>>((ref) => ref.watch(databaseProvider).watchLaterRows());
final openRemindersProvider = StreamProvider<List<Reminder>>((ref) => ref.watch(databaseProvider).watchReminders());
final doneTodayProvider = StreamProvider<List<DoneItem>>((ref) => ref.watch(databaseProvider).watchDoneToday());

/// The front page: the day in cards. Needs you (filled once the assistant
/// is connected), who the user is waiting on, the day's calendar, a few
/// things worth a glance, what was put off, and what is done.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final OpenThreadNotifier _openThread;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _openThread = ref.read(openThreadProvider.notifier);
    // Opening Today brings the calendar up to date.
    unawaited(ref.read(calendarSyncProvider).syncNow().catchError((Object _) {}));
    // Times on the page ("in 2 hours", what has passed) move with the clock.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    // An email opened here does not follow the user to Chats.
    final notifier = _openThread;
    Future.microtask(notifier.close);
    super.dispose();
  }

  static String _greeting(DateTime now, String? name) {
    final part = now.hour < 12 ? 'Good morning' : (now.hour < 18 ? 'Good afternoon' : 'Good evening');
    final first = (name ?? '').trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? part : '$part, $first';
  }

  static String _date(DateTime d) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final name = accounts.isEmpty ? null : accounts.first.displayName;
    final openThread = ref.watch(openThreadProvider);

    return LayoutBuilder(
      builder: (context, box) {
        final two = box.maxWidth >= 860;
        final left = [const _NeedsYou(), const _WaitingOn()];
        final right = [const _Schedule(), const _Fyi(), const _Later(), const _Done()];
        return Stack(
          children: [
            // Fills its area, so a short page starts at the top.
            Positioned.fill(
              child: SingleChildScrollView(
                key: const PageStorageKey('today-scroll'),
                padding: const EdgeInsets.fromLTRB(24, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _date(now),
                                key: const ValueKey('today-date'),
                                style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 2),
                              Text(_greeting(now, name), key: const ValueKey('today-greeting'), style: text.headlineMedium),
                            ],
                          ),
                        ),
                        const _WaitingToSend(),
                        const _UpToDate(),
                      ],
                    ),
                    const _Sentence(),
                    const SizedBox(height: AppSpace.lg),
                    if (two)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            flex: 3,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right),
                          ),
                        ],
                      )
                    else ...[
                      ...left,
                      ...right,
                    ],
                  ],
                ),
              ),
            ),
            // An email opened from a line slides in over the page from the
            // right, the same way the full thread does in Chats. A click
            // beside it closes it.
            if (openThread != null)
              KeyedSubtree(
                key: const ValueKey('today-email'),
                child: ThreadViewPanel(key: ValueKey(openThread), threadKey: openThread),
              ),
          ],
        );
      },
    );
  }
}

/// One card on Today: an icon, a title, a count, then its lines.
class _Section extends StatelessWidget {
  const _Section({required this.id, required this.icon, required this.color, required this.title, required this.children, this.count, this.empty});
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final int? count;
  final List<Widget> children;

  /// What to say when there are no lines.
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Material(
        key: ValueKey('today-$id'),
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppShapes.lgIncreased),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(AppShapes.sm)),
                    child: Icon(icon, size: 17, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (count != null && count! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
                      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppShapes.full)),
                      child: Text('$count', style: text.labelMedium!.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
              const SizedBox(height: 6),
              if (children.isEmpty && empty != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 4, 4, 8),
                  child: Text(empty!, style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
                ),
              for (var i = 0; i < children.length; i++) ...[if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)), children[i]],
            ],
          ),
        ),
      ),
    );
  }
}

/// "1 message waiting to send": written with no signal, sent by itself when
/// the signal returns. Shown only while something is waiting.
class _WaitingToSend extends ConsumerWidget {
  const _WaitingToSend();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(waitingSendCountProvider).value ?? 0;
    if (n == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Written with no signal. Précis sends ${n == 1 ? 'it' : 'them'} by itself when the signal returns.',
        child: Container(
          key: const ValueKey('today-waiting-to-send'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(AppShapes.full)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_send_outlined, size: 14, color: scheme.onTertiaryContainer),
              const SizedBox(width: 6),
              Text('$n waiting to send', style: text.labelMedium!.copyWith(color: scheme.onTertiaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Up to date · 8:02 AM": this PC is in step with the helper, and when it
/// last checked. Shown only while the PC follows a helper.
class _UpToDate extends ConsumerWidget {
  const _UpToDate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(helperProvider);
    final at = link.inStepAt;
    if (!link.connected || at == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final behind = link.error != null;
    return Container(
      key: const ValueKey('today-up-to-date'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppShapes.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: behind ? scheme.error : const Color(0xFF81C784), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('${behind ? 'Last in step' : 'Up to date'} · ${_clock(at)}', style: text.labelMedium!.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

String _clock(DateTime t) {
  final l = t.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
}

/// The one sentence at the top of the page, written by the assistant from
/// the lines below it, with a small star so it is plain who wrote it, and
/// when it was written.
class _Sentence extends ConsumerWidget {
  const _Sentence();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(daySentenceProvider).value;
    if (s == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final sameDay = s.at.year == now.year && s.at.month == now.month && s.at.day == now.day;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: Container(
        key: const ValueKey('today-sentence'),
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.38), borderRadius: BorderRadius.circular(AppShapes.lgIncreased)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 3), child: Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.text, key: const ValueKey('today-sentence-text'), style: text.titleMedium!.copyWith(height: 1.35, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    'Written ${sameDay ? _clock(s.at) : 'on ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][s.at.month - 1]} ${s.at.day} at ${_clock(s.at)}'}${s.after > 0 ? ', after ${s.after} new email${s.after == 1 ? '' : 's'}' : ''}',
                    key: const ValueKey('today-sentence-when'),
                    style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The emails in Focus, in full: what to do in bold, why, who and which
/// email, a "by" time when there is one, and Done and Later on the line.
class _NeedsYou extends ConsumerWidget {
  const _NeedsYou();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shown = ref.watch(readingsShownProvider).value ?? false;
    final items = ref.watch(focusMailProvider).value ?? const <MailItem>[];
    return _Section(
      id: 'needs-you',
      icon: Icons.bolt_rounded,
      color: focusColor,
      title: 'Needs you',
      count: items.length,
      empty: shown ? 'Nothing. The assistant has read your mail and found nothing that needs you.' : 'The assistant is not on. When it is, the emails that need you are listed here.',
      children: [
        for (final i in items.take(8))
          InkWell(
            key: ValueKey('needs-${i.id}'),
            onTap: () {
              ref.read(openMailProvider('focus').notifier).open(i.id);
              openMail(ref, i);
              ref.read(destinationProvider.notifier).select(Destination.focus);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: TonalAvatar(identityKey: i.senderKey, name: i.senderName, size: 32)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // What to do, in bold; then why; then who and which email.
                        Text(i.ask, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w700)),
                        if ((i.reading?.line ?? '').isNotEmpty && i.reading!.line != i.ask)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(i.reading!.line, key: ValueKey('needs-why-${i.id}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${i.senderName} · ${i.subject.isEmpty ? '(no subject)' : i.subject}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (i.reading?.due != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.schedule_rounded, size: 14, color: i.reading!.due!.isBefore(DateTime.now()) ? scheme.error : const Color(0xFFFFB74D)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'by ${dueLabel(i.reading!.due!)}',
                                        key: ValueKey('needs-by-${i.id}'),
                                        style: text.labelMedium!.copyWith(color: i.reading!.due!.isBefore(DateTime.now()) ? scheme.error : const Color(0xFFFFB74D), fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              TextButton.icon(
                                key: ValueKey('needs-done-${i.id}'),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () => ref.read(databaseProvider).setMessagesDone([i.id], true),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Done'),
                              ),
                              TextButton.icon(
                                key: ValueKey('needs-later-${i.id}'),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () => putOffFocusMail(context, ref, i),
                                icon: const Icon(Icons.snooze_rounded, size: 16),
                                label: const Text('Later'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (items.length > 8)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('needs-more'),
              onPressed: () => ref.read(destinationProvider.notifier).select(Destination.focus),
              child: Text('${items.length - 8} more in Focus'),
            ),
          ),
      ],
    );
  }
}

class _WaitingOn extends ConsumerWidget {
  const _WaitingOn();

  static String _ago(DateTime sent, DateTime now) {
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(sent.year, sent.month, sent.day)).inDays;
    return days <= 1 ? 'yesterday' : '$days days ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = ref.watch(waitingOnProvider).value ?? const <WaitingItem>[];
    // Sent emails whose words are not here yet cannot be judged.
    final unread = ref.watch(sentNotReadYetProvider).value ?? 0;
    final reading = 'Still reading $unread of the emails you sent, to see who has not answered.';
    final now = DateTime.now();
    return _Section(
      id: 'waiting-on',
      icon: Icons.hourglass_top_rounded,
      color: scheme.primary,
      title: 'Waiting on',
      count: items.length,
      empty: unread > 0 ? reading : 'Nobody. Everyone you asked has answered, or it has been less than three days.',
      children: [
        for (final w in items)
          InkWell(
            key: ValueKey('waiting-${w.message.id}'),
            onTap: () {
              ref.read(expandedMessagesProvider.notifier).expand(w.message.id);
              final thread = w.message.threadKey;
              if (thread == null || thread.isEmpty) {
                openRow(ref.read, w.rowKey);
              } else {
                ref.read(openThreadProvider.notifier).open(thread);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  TonalAvatar(identityKey: w.rowKey.substring(2), name: w.name, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: w.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(text: ' has not answered'),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                        Text(
                          '${w.asked.isNotEmpty ? 'You asked for: ${w.asked}' : (w.message.subject.isEmpty ? '(no subject)' : w.message.subject)} · you wrote ${_ago(w.sentAt, now)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: ValueKey('waiting-follow-up-${w.message.id}'),
                    onPressed: () async {
                      await openRow(ref.read, w.rowKey);
                      ref.read(replyRequestProvider.notifier).open(ComposeRequest.reply(w.message.id, rowKey: w.rowKey));
                    },
                    child: const Text('Follow up'),
                  ),
                  IconButton(
                    key: ValueKey('waiting-done-${w.message.id}'),
                    tooltip: 'Done',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    onPressed: () => ref.read(databaseProvider).setMessagesDone([w.message.id], true),
                  ),
                ],
              ),
            ),
          ),
        if (items.isNotEmpty && unread > 0)
          Padding(
            key: const ValueKey('waiting-reading'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(reading, style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}

class _Schedule extends ConsumerWidget {
  const _Schedule();

  static String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final connected = (ref.watch(googleCalendarsProvider).value ?? const []).isNotEmpty;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = [
      for (final e in ref.watch(todayEventsProvider).value ?? const <PlannerEvent>[])
        if (e.startAt != null && (e.allDay ? allDayCovers(e, today) : true)) e,
    ]..sort((a, b) => a.allDay == b.allDay ? a.startAt!.compareTo(b.startAt!) : (a.allDay ? -1 : 1));
    return _Section(
      id: 'schedule',
      icon: Icons.calendar_today_rounded,
      color: const Color(0xFFFFB74D),
      title: 'Schedule',
      count: events.length,
      empty: connected ? 'Nothing on your calendar today.' : null,
      children: [
        if (!connected)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 0, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('Connect your Google Calendar to see your day here. It is only read, never changed.', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
                ),
                TextButton(
                  key: const ValueKey('today-connect-calendar'),
                  onPressed: () {
                    ref.read(settingsSectionProvider.notifier).select(SettingsSection.calendar);
                    ref.read(destinationProvider.notifier).select(Destination.settings);
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        for (final e in events)
          Padding(
            key: ValueKey('today-event-${e.id}'),
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: e.color != null ? Color(e.color!) : scheme.primary, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 76,
                  child: Text(
                    e.allDay ? 'All day' : _time(e.startAt!),
                    style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: !e.allDay && (e.endAt ?? e.startAt!).isBefore(now) ? scheme.onSurfaceVariant : null),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: text.bodyMedium),
                      if ((e.location ?? '').isNotEmpty)
                        Text(
                          e.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Fyi extends ConsumerWidget {
  const _Fyi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = timelyDue(ref.watch(timelyItemsProvider).value ?? const [], DateTime.now());
    return _Section(
      id: 'fyi',
      icon: Icons.info_outline_rounded,
      color: const Color(0xFF64B5F6),
      title: 'FYI',
      count: due.length,
      empty: 'Nothing to note right now. Codes, deliveries, trips and bills show here when they matter.',
      children: [if (due.isNotEmpty) const TimelyStrip(embedded: true)],
    );
  }
}

class _Later extends ConsumerWidget {
  const _Later();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rows = ref.watch(laterRowsProvider).value ?? const <LaterRow>[];
    final reminders = ref.watch(openRemindersProvider).value ?? const <Reminder>[];
    final mail = ref.watch(focusLaterProvider).value ?? const <MailItem>[];
    return _Section(
      id: 'later',
      icon: Icons.snooze_rounded,
      color: const Color(0xFFCE93D8),
      title: 'Later',
      count: rows.length + reminders.length + mail.length,
      empty: 'Nothing put off. Use Later on a Focus email or a chat, or Remind me on a thread.',
      children: [
        for (final i in mail)
          InkWell(
            key: ValueKey('later-mail-${i.id}'),
            onTap: () {
              ref.read(openMailProvider('focus').notifier).open(i.id);
              openMail(ref, i);
              ref.read(destinationProvider.notifier).select(Destination.focus);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.ask, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                        Text('${i.senderName} · back ${describeSnooze(i.laterUntil!)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  TextButton(key: ValueKey('later-mail-back-${i.id}'), onPressed: () => ref.read(databaseProvider).setLaterUntil(i.id, null), child: const Text('Bring back now')),
                ],
              ),
            ),
          ),
        for (final r in rows)
          InkWell(
            key: ValueKey('later-row-${r.rowKey}'),
            onTap: () => openRow(ref.read, r.rowKey),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                        Text('Back ${describeSnooze(r.until)}', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  TextButton(key: ValueKey('later-back-${r.rowKey}'), onPressed: () => ref.read(databaseProvider).snoozeRow(r.rowKey, null), child: const Text('Bring back now')),
                ],
              ),
            ),
          ),
        for (final r in reminders)
          InkWell(
            key: ValueKey('later-reminder-${r.id}'),
            onTap: r.rowKey == null ? null : () => openRow(ref.read, r.rowKey),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                        Text('Reminder ${describeSnooze(r.dueAt)}', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('later-reminder-done-${r.id}'),
                    tooltip: 'Done',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    onPressed: () => ref.read(databaseProvider).setReminderDone(r.id, true),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// What was marked done today, as its own card (the phone shows it on a
/// page of its own, under More).
class DoneTodayList extends StatelessWidget {
  const DoneTodayList({super.key});

  @override
  Widget build(BuildContext context) => const _Done();
}

class _Done extends ConsumerWidget {
  const _Done();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = ref.watch(doneTodayProvider).value ?? const <DoneItem>[];
    return _Section(
      id: 'done',
      icon: Icons.check_circle_outline_rounded,
      color: const Color(0xFF81C784),
      title: 'Done',
      count: items.length,
      empty: 'Nothing marked done yet today.',
      children: [
        for (final d in items)
          InkWell(
            key: ValueKey('done-${d.threadKey ?? d.title}'),
            onTap: (d.threadKey ?? '').isEmpty ? null : () => ref.read(openThreadProvider.notifier).open(d.threadKey!),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.who.isEmpty ? d.title : '${d.title} · ${d.who}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant, decoration: TextDecoration.lineThrough),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
