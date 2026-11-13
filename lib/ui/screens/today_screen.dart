import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/account_scope.dart';
import '../../app/calendar_state.dart';
import '../../app/compose_state.dart';
import '../../app/conversation_state.dart';
import '../../app/destinations.dart';
import '../../app/layout.dart';
import '../../app/mail_state.dart';
import '../../app/people_state.dart';
import '../../app/settings_navigation.dart';
import '../../app/time_format.dart';
import '../../app/timely_state.dart';
import '../../helper/helper_sync.dart';
import '../../store/database.dart';
import '../../store/done_queries.dart';
import '../../store/helper_queries.dart';
import '../../store/mail_queries.dart';
import '../../store/planner_queries.dart';
import '../../sync/calendar_sync.dart';
import '../../sync/sync_controller.dart';
import '../../sync/waiting_sends.dart';
import '../theme/tokens.dart';
import '../widgets/item_menu.dart';
import '../widgets/reading_line.dart';
import '../widgets/tonal_avatar.dart';
import 'chats/later_dialogs.dart';
import 'chats/people_list_pane.dart' show relativeTime;
import 'chats/thread_view_panel.dart';
import 'chats/timely_strip.dart';
import 'mail/mail_widgets.dart' show openMail, putOffFocusMail;
import 'page_type.dart';
import 'trip_cards.dart';

/// Today's calendar events, in the calendars the user shows.
final todayEventsProvider = StreamProvider<List<PlannerEvent>>((ref) {
  // The day is asked for, not remembered: with Précis left open overnight
  // the card moves on to the new day by itself.
  final start = ref.watch(todayDateProvider);
  return watchShownEvents(ref, start, DateTime(start.year, start.month, start.day + 1));
});

final waitingOnProvider = StreamProvider<List<WaitingItem>>((ref) => ref.watch(databaseProvider).watchWaitingOn(accountId: ref.watch(accountScopeProvider)));
final sentNotReadYetProvider = StreamProvider<int>((ref) => ref.watch(databaseProvider).watchSentWithoutWordsCount(accountId: ref.watch(accountScopeProvider)));
final laterRowsProvider = StreamProvider<List<LaterRow>>((ref) => ref.watch(databaseProvider).watchLaterRows());
final openRemindersProvider = StreamProvider<List<Reminder>>((ref) => ref.watch(databaseProvider).watchReminders());
final doneTodayProvider = StreamProvider<List<DoneItem>>((ref) => ref.watch(databaseProvider).watchDoneToday(day: ref.watch(todayDateProvider)));

/// The front page: the day in cards. Needs you (filled once the assistant
/// is connected), who the user is waiting on, the day's calendar, a few
/// things worth a glance, what was put off, and what is done.
/// Whether the Précis page is being moved under a finger. The phone's write
/// button steps out of the way while it is, and comes back when it rests.
final pageMovingProvider = NotifierProvider<PageMoving, bool>(PageMoving.new);

class PageMoving extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool moving) {
    // The page can be let go of after the app itself has closed.
    if (!ref.mounted) return;
    if (state != moving) state = moving;
  }
}

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final OpenThreadNotifier _openThread;
  late final PageMoving _moving;
  Timer? _tick;
  Timer? _rest;

  /// How long the page must lie still before the write button comes back.
  static const _restAfter = Duration(milliseconds: 700);

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollUpdateNotification && n.dragDetails != null || n is ScrollStartNotification && n.dragDetails != null) {
      _rest?.cancel();
      _moving.set(true);
    } else if (n is ScrollEndNotification) {
      _rest?.cancel();
      _rest = Timer(_restAfter, () => _moving.set(false));
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _openThread = ref.read(openThreadProvider.notifier);
    _moving = ref.read(pageMovingProvider.notifier);
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
    _rest?.cancel();
    // An email opened here does not follow the user to Chats.
    final notifier = _openThread;
    final moving = _moving;
    Future.microtask(() {
      notifier.close();
      moving.set(false);
    });
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
    final phone = isCompactLayout(context, ref);
    // A card with nothing in it is not drawn (only Schedule is). With nothing
    // in the whole left column, the right column is the page.
    final leftHasSomething =
        (ref.watch(focusMailProvider).value ?? const <MailItem>[]).isNotEmpty || _goodToKnowItems(ref).isNotEmpty || (ref.watch(waitingOnProvider).value ?? const <WaitingItem>[]).isNotEmpty;
    // Nothing on the whole page, and nothing on the calendar: it says so,
    // and says what will show here.
    final cards = ref.watch(helperCardsProvider).value ?? const <HelperCard>[];
    final assistant = ref.watch(readingsShownProvider).value ?? false;
    final today = DateTime(now.year, now.month, now.day);
    final quiet = !leftHasSomething &&
        timelyDue(ref.watch(timelyItemsProvider).value ?? const [], now).isEmpty &&
        (!assistant || (travelNow(cards, now).isEmpty && bookingsNow(cards, now).isEmpty)) &&
        (ref.watch(laterRowsProvider).value ?? const <LaterRow>[]).isEmpty &&
        (ref.watch(openRemindersProvider).value ?? const <Reminder>[]).isEmpty &&
        (ref.watch(focusLaterProvider).value ?? const <MailItem>[]).isEmpty &&
        (ref.watch(doneTodayProvider).value ?? const <DoneItem>[]).isEmpty &&
        !(ref.watch(todayEventsProvider).value ?? const <PlannerEvent>[]).any((e) => e.startAt != null && (e.allDay ? allDayCovers(e, today) : true));

    return LayoutBuilder(
      builder: (context, box) {
        final two = box.maxWidth >= 860 && leftHasSomething;
        final left = [const _NeedsYou(), const _GoodToKnow(), const _WaitingOn()];
        final right = [
          const _Schedule(),
          const _Fyi(FyiCard.otp),
          const _Travel(),
          const _Bookings(),
          for (final c in const [FyiCard.deliveries, FyiCard.payments, FyiCard.fyi]) _Fyi(c),
          const _Later(),
          const _Done(),
        ];
        return Stack(
          children: [
            // Fills its area, so a short page starts at the top.
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: phone ? _onScroll : null,
                child: SingleChildScrollView(
                key: const PageStorageKey('today-scroll'),
                // On a phone the last card clears the write button.
                padding: phone ? const EdgeInsets.fromLTRB(18, 12, 18, 88) : const EdgeInsets.fromLTRB(24, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (phone) ...[
                      // On a phone: the date with the small pills beside it,
                      // then the greeting on one line of its own, never wrapped.
                      Row(
                        children: [
                          Expanded(
                            child: Text(_date(now), key: const ValueKey('today-date'), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                          ),
                          const _WaitingToSend(small: true),
                          const _UpToDate(small: true),
                        ],
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(_greeting(now, name), key: const ValueKey('today-greeting'), maxLines: 1, softWrap: false, style: text.headlineMedium!.copyWith(fontSize: (text.headlineMedium!.fontSize ?? 28) + 2)),
                      ),
                    ] else
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
                    if (quiet) const _QuietDay(),
                  ],
                ),
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

/// A page with nothing on it says so, and says what will show.
class _QuietDay extends StatelessWidget {
  const _QuietDay();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('today-quiet'),
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            children: [
              Icon(Icons.wb_twilight_rounded, size: 44, color: scheme.surfaceContainerHighest),
              const SizedBox(height: 10),
              Text('A quiet day.', style: text.titleMedium!.copyWith(fontSize: 19, fontWeight: FontWeight.w500, color: scheme.onSurface)),
              const SizedBox(height: 6),
              Text(
                'Nothing needs your attention right now. Trips, deliveries and payments show here when there are any.',
                textAlign: TextAlign.center,
                style: rowTitle(context).copyWith(fontWeight: FontWeight.w400, height: 1.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What "Good to know" lists now: nothing while the assistant is off, and
/// never what FYI already lists.
List<MailItem> _goodToKnowItems(WidgetRef ref) {
  if (!(ref.watch(readingsShownProvider).value ?? false)) return const [];
  final inFyi = {for (final t in timelyDue(ref.watch(timelyItemsProvider).value ?? const [], DateTime.now())) t.messageId};
  return [
    for (final i in ref.watch(goodToKnowProvider).value ?? const <MailItem>[])
      if (!inFyi.contains(i.id)) i,
  ];
}

/// One group on the page: a small label (an icon, its name, how many), then
/// its lines on a quiet card. A group with no lines is not drawn at all,
/// unless it is [alwaysShown].
class _Section extends StatelessWidget {
  const _Section({required this.id, required this.icon, required this.title, required this.children, this.count, this.empty, this.alwaysShown = false, this.alarm, this.labelColor});
  final String id;
  final IconData icon;
  final String title;
  final int? count;
  final List<Widget> children;

  /// What to say when there are no lines, on a group that is [alwaysShown].
  final String? empty;
  final bool alwaysShown;

  /// The whole card takes this color to draw the eye: yellow for a delay,
  /// red for a cancellation. Nothing else on the page is colored.
  final Color? alarm;

  /// The label's own color (Needs you keeps its pink); gray otherwise.
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && !alwaysShown) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final tone = alarm ?? labelColor ?? scheme.onSurfaceVariant;
    final label = sectionLabel(context, color: tone);
    return Padding(
      key: ValueKey('today-$id'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 6, 7),
            child: Row(
              children: [
                Icon(icon, size: 15, color: tone),
                const SizedBox(width: 7),
                Expanded(child: Text(title.toUpperCase(), key: ValueKey('today-label-$id'), style: label)),
                if (count != null && count! > 0) Text('$count', key: ValueKey('today-count-$id'), style: label.copyWith(letterSpacing: 0)),
              ],
            ),
          ),
          Material(
            key: ValueKey('today-card-$id'),
            color: alarm == null ? scheme.surfaceContainerLowest : Color.alphaBlend(alarm!.withValues(alpha: 0.2), scheme.surfaceContainerLowest),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppShapes.lgIncreased),
              side: alarm == null ? BorderSide.none : BorderSide(color: alarm!, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (children.isEmpty && empty != null) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(empty!, style: rowSmall(context))),
                  for (var i = 0; i < children.length; i++) ...[if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)), children[i]],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "1 message waiting to send": written with no signal, sent by itself when
/// the signal returns. Shown only while something is waiting.
class _WaitingToSend extends ConsumerWidget {
  const _WaitingToSend({this.small = false});

  /// On a phone: small enough to sit beside the date.
  final bool small;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(waitingSendCountProvider).value ?? 0;
    if (n == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'On ${n == 1 ? 'its' : 'their'} way out. With no signal, Précis sends ${n == 1 ? 'it' : 'them'} by itself when the signal returns.',
        child: Container(
          key: const ValueKey('today-waiting-to-send'),
          padding: small ? const EdgeInsets.symmetric(horizontal: 7, vertical: 1) : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(AppShapes.full)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_send_outlined, size: small ? 11 : 14, color: scheme.onTertiaryContainer),
              SizedBox(width: small ? 4 : 6),
              Text('Sending $n', style: (small ? text.labelSmall! : text.labelMedium!).copyWith(color: scheme.onTertiaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Up to date · 8:02 AM": this device is in step with the helper, and when
/// it last checked. Shown only while the device follows a helper. Clicking
/// it checks everything right now: new mail, the helper, the calendar.
class _UpToDate extends ConsumerStatefulWidget {
  const _UpToDate({this.small = false});

  /// On a phone: small enough to sit beside the date.
  final bool small;

  @override
  ConsumerState<_UpToDate> createState() => _UpToDateState();
}

class _UpToDateState extends ConsumerState<_UpToDate> {
  bool _busy = false;

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    final helper = ref.read(helperProvider.notifier);
    final mail = ref.read(syncControllerProvider);
    final calendar = ref.read(calendarSyncProvider);
    try {
      // New mail and the calendar first, then the helper, so what it says
      // about the mail that just came in arrives in the same round.
      await Future.wait<void>([
        mail.checkNow(),
        calendar.syncNow().then<void>((_) {}).catchError((Object _) {}),
        helper.syncNow().catchError((Object _) {}),
      ]);
      await helper.syncNow();
    } catch (_) {
      // What went wrong shows where it always does (the pill turns red).
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = ref.watch(helperProvider);
    final at = link.inStepAt;
    if (!link.connected || at == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final behind = link.error != null;
    final small = widget.small;
    return Tooltip(
      message: 'Check for new mail now',
      child: Material(
        key: const ValueKey('today-up-to-date'),
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppShapes.full),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : _check,
          child: Padding(
            padding: small ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2) : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  SizedBox(key: const ValueKey('today-checking'), width: small ? 8 : 10, height: small ? 8 : 10, child: const CircularProgressIndicator(strokeWidth: 2))
                else
                  Container(width: small ? 6 : 8, height: small ? 6 : 8, decoration: BoxDecoration(color: behind ? scheme.error : const Color(0xFF81C784), shape: BoxShape.circle)),
                SizedBox(width: small ? 5 : 8),
                Text(_busy ? 'Checking…' : '${behind ? 'Last in step' : 'Up to date'} · ${_clock(at)}', style: (small ? text.labelSmall! : text.labelMedium!).copyWith(color: scheme.onSurfaceVariant)),
                if (!_busy) ...[
                  SizedBox(width: small ? 4 : 6),
                  Icon(Icons.refresh_rounded, size: small ? 11 : 14, color: scheme.onSurfaceVariant),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _clock(DateTime t) => clockTime(t.toLocal());

/// The one sentence at the top of the page ("The Lede"), written by the
/// assistant from the lines below it: white words beside a thin line, with
/// its label, when it was written, and an x to put it away.
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
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        key: const ValueKey('today-sentence'),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: scheme.primary, width: 3))),
        padding: const EdgeInsets.fromLTRB(13, 1, 0, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text('THE LEDE', key: const ValueKey('today-sentence-label'), style: sectionLabel(context, color: scheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(timesInText(s.text), key: const ValueKey('today-sentence-text'), style: text.titleMedium!.copyWith(fontSize: 16, height: 1.36, fontWeight: FontWeight.w400, color: scheme.onSurface)),
                  const SizedBox(height: 5),
                  Text(
                    'Written ${sameDay ? _clock(s.at) : 'on ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][s.at.month - 1]} ${s.at.day} at ${_clock(s.at)}'}${s.after > 0 ? ', after ${s.after} new email${s.after == 1 ? '' : 's'}' : ''}',
                    key: const ValueKey('today-sentence-when'),
                    style: rowSmall(context),
                  ),
                ],
              ),
            ),
            // Dismiss: it goes away here and on your other devices, until the next one is written.
            IconButton(
              key: const ValueKey('today-sentence-dismiss'),
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
              onPressed: () {
                final db = ref.read(databaseProvider);
                final messenger = ScaffoldMessenger.of(context);
                db.dismissDaySentence(s.at);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(SnackBar(
                  persist: false,
                  duration: const Duration(seconds: 8),
                  content: const Text('Dismissed. It comes back when the next one is written.'),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(label: 'Undo', onPressed: () => db.dismissDaySentence(null)),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The emails in Focus: what to do in bold; who it is from, by when, and
/// why on the line under it; then Done and Later.
class _NeedsYou extends ConsumerWidget {
  const _NeedsYou();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final small = rowSmall(context);
    final items = ref.watch(focusMailProvider).value ?? const <MailItem>[];
    return _Section(
      id: 'needs-you',
      icon: Icons.bolt_rounded,
      labelColor: focusColor,
      title: 'Needs you',
      count: items.length,
      children: [
        for (final i in items.take(8))
          InkWell(
            key: ValueKey('needs-${i.id}'),
            onTapDown: (d) => lastPressAt = d.globalPosition,
            onSecondaryTapUp: (d) => showItemMenu(context, d.globalPosition, _needsMenu(context, ref, i)),
            onLongPress: () => showItemMenu(context, lastPressAt, _needsMenu(context, ref, i)),
            onTap: () {
              ref.read(openMailProvider('focus').notifier).open(i.id);
              openMail(ref, i);
              ref.read(destinationProvider.notifier).select(Destination.focus, fromToday: true);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 1), child: TonalAvatar(identityKey: i.senderKey, name: i.senderName, size: 34)),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // What to do, in bold.
                        Text(i.ask, maxLines: 2, overflow: TextOverflow.ellipsis, style: rowTitle(context, strong: true)),
                        const SizedBox(height: 2),
                        // Who, by when, and why, sharing a line when they fit.
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(i.senderName, key: ValueKey('needs-who-${i.id}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
                            if (i.reading?.due != null) ...[
                              Text(' · ', style: small),
                              Text(
                                'by ${dueLabel(i.reading!.due!)}',
                                key: ValueKey('needs-by-${i.id}'),
                                style: small.copyWith(color: i.reading!.due!.isBefore(DateTime.now()) ? scheme.error : const Color(0xFFFFB74D), fontWeight: FontWeight.w700),
                              ),
                            ],
                            if ((i.reading?.line ?? '').isNotEmpty && i.reading!.line != i.ask) ...[
                              Text(' · ', style: small),
                              Text(i.reading!.line, key: ValueKey('needs-why-${i.id}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: small),
                            ],
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // An email written for the user to look over and
                              // send: it opens under the email, ready to change.
                              if ((i.reading?.draft ?? '').isNotEmpty)
                                FilledButton.tonalIcon(
                                  key: ValueKey('needs-draft-${i.id}'),
                                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () {
                                    ref.read(openMailProvider('focus').notifier).open(i.id);
                                    openMail(ref, i);
                                    ref.read(destinationProvider.notifier).select(Destination.focus, fromToday: true);
                                    ref.read(replyRequestProvider.notifier).open(ComposeRequest.reply(i.id, rowKey: i.rowKey, body: i.reading!.draft));
                                  },
                                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                                  label: const Text('Review draft'),
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
              onPressed: () => ref.read(destinationProvider.notifier).select(Destination.focus, fromToday: true),
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
    final items = ref.watch(waitingOnProvider).value ?? const <WaitingItem>[];
    // Sent emails whose words are not here yet cannot be judged. Said under
    // the lines when there are any; an empty card is not drawn.
    final unread = ref.watch(sentNotReadYetProvider).value ?? 0;
    final reading = 'Still reading $unread of the emails you sent, to see who has not answered.';
    final now = DateTime.now();
    return _Section(
      id: 'waiting-on',
      icon: Icons.hourglass_top_rounded,
      title: 'Waiting on',
      count: items.length,
      children: [
        for (final w in items)
          InkWell(
            key: ValueKey('waiting-${w.message.id}'),
            onTapDown: (d) => lastPressAt = d.globalPosition,
            onSecondaryTapUp: (d) => showItemMenu(context, d.globalPosition, _waitingMenu(context, ref, w)),
            onLongPress: () => showItemMenu(context, lastPressAt, _waitingMenu(context, ref, w)),
            onTap: () {
              ref.read(expandedMessagesProvider.notifier).expand(w.message.id);
              final thread = w.message.threadKey;
              if (thread == null || thread.isEmpty) {
                openRow(ref.read, w.rowKey, fromToday: true);
              } else {
                ref.read(openThreadProvider.notifier).open(thread);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  TonalAvatar(identityKey: w.rowKey.substring(2), name: w.name, size: 34),
                  const SizedBox(width: 11),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: rowTitle(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${w.asked.isNotEmpty ? 'You asked for: ${w.asked}' : (w.message.subject.isEmpty ? '(no subject)' : w.message.subject)} · you wrote ${_ago(w.sentAt, now)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: rowSmall(context),
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
            child: Text(reading, style: rowSmall(context)),
          ),
      ],
    );
  }
}

class _Schedule extends ConsumerWidget {
  const _Schedule();

  static String _time(DateTime t) => clockTime(t);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final connected = (ref.watch(googleCalendarsProvider).value ?? const []).isNotEmpty;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = [
      for (final e in ref.watch(todayEventsProvider).value ?? const <PlannerEvent>[])
        if (e.startAt != null && (e.allDay ? allDayCovers(e, today) : true)) e,
    ]..sort((a, b) => a.allDay == b.allDay ? a.startAt!.compareTo(b.startAt!) : (a.allDay ? -1 : 1));
    // Schedule always shows, also with nothing on it: then it is one quiet
    // line, not a card.
    if (connected && events.isEmpty) {
      return Padding(
        key: const ValueKey('today-schedule'),
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 9),
            Expanded(child: Text('Nothing on your calendar today.', key: const ValueKey('today-schedule-empty'), style: rowSmall(context))),
          ],
        ),
      );
    }
    return _Section(
      id: 'schedule',
      icon: Icons.calendar_today_rounded,
      title: 'Schedule',
      count: events.length,
      alwaysShown: true,
      children: [
        if (!connected)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 0, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('Connect your Google Calendar to see your day here. It is only read, never changed.', style: rowSmall(context)),
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
          ItemMenu(
            key: ValueKey('today-event-${e.id}'),
            choices: () => [
              MenuChoice('dismiss', kDismiss, Icons.close_rounded, () {
                final db = ref.read(databaseProvider);
                db.setEventDismissed(e.id, true);
                sayDone(context, 'Taken off Schedule. Your calendar is not changed.', undo: () => db.setEventDismissed(e.id, false));
              }),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: e.color != null ? Color(e.color!) : scheme.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: rowTitle(context)),
                        if ((e.location ?? '').isNotEmpty) Text(e.location!, maxLines: 1, overflow: TextOverflow.ellipsis, style: rowSmall(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // The time on the right, where the eye looks for it.
                  Text(
                    e.allDay ? 'All day' : _time(e.startAt!),
                    style: rowTitle(context).copyWith(fontFeatures: tabularFigures, color: !e.allDay && (e.endAt ?? e.startAt!).isBefore(now) ? scheme.onSurfaceVariant : null),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The menu of a line under Needs you.
List<MenuChoice> _needsMenu(BuildContext context, WidgetRef ref, MailItem i) {
  final db = ref.read(databaseProvider);
  return [
    MenuChoice('dismiss', kDismiss, Icons.close_rounded, () => _dismiss(context, db, i.id, 'Needs you')),
    MenuChoice('later', kLater, Icons.snooze_rounded, () => putOffFocusMail(context, ref, i)),
    MenuChoice('reject', kReject, Icons.block_rounded, () {
      db.setFocusFix(i.id, false);
      sayDone(context, 'Taken off Needs you. The assistant is told that mail like this does not need you.', undo: () => db.setFocusFix(i.id, null));
    }),
  ];
}

/// The menu of a line under Good to know.
List<MenuChoice> _knowMenu(BuildContext context, WidgetRef ref, MailItem i) {
  final db = ref.read(databaseProvider);
  return [
    MenuChoice('dismiss', kDismiss, Icons.close_rounded, () => _dismiss(context, db, i.id, 'Good to know')),
    MenuChoice('later', kLater, Icons.snooze_rounded, () => putOffFocusMail(context, ref, i, place: 'Good to know')),
    MenuChoice('reject', kReject, Icons.block_rounded, () {
      db.setWorthKnowing(i.id, false);
      sayDone(context, 'Taken off Good to know. The assistant is shown it, to learn what kind of thing does not belong here.', undo: () => db.setWorthKnowing(i.id, true));
    }),
  ];
}

/// The menu of a line under Waiting on.
List<MenuChoice> _waitingMenu(BuildContext context, WidgetRef ref, WaitingItem w) {
  final db = ref.read(databaseProvider);
  return [
    MenuChoice('dismiss', kDismiss, Icons.close_rounded, () => _dismiss(context, db, w.message.id, 'Waiting on')),
    MenuChoice('reject', kReject, Icons.block_rounded, () {
      db.setWaitingOn(w.message.id, false);
      sayDone(context, 'Taken off Waiting on. The assistant is told you are not waiting on mail like this.', undo: () => db.setWaitingOn(w.message.id, true));
    }),
  ];
}

/// The menu of an email under Later.
List<MenuChoice> _laterMailMenu(BuildContext context, WidgetRef ref, MailItem i) {
  final db = ref.read(databaseProvider);
  final know = !i.needsYou && (i.reading?.know ?? false);
  return [
    MenuChoice('back', 'Bring back now', Icons.undo_rounded, () => db.setLaterUntil(i.id, null)),
    MenuChoice('later', kLater, Icons.snooze_rounded, () => putOffFocusMail(context, ref, i, place: know ? 'Good to know' : 'Focus')),
    MenuChoice('dismiss', kDismiss, Icons.close_rounded, () => _dismiss(context, db, i.id, 'Later')),
  ];
}

/// Dismiss: off the card, not marked done (the check mark on the item does
/// that), and nothing is taught.
void _dismiss(BuildContext context, AppDatabase db, int messageId, String card) {
  db.setDismissed(messageId, true);
  sayDone(context, 'Taken off $card. It is not marked done.', undo: () => db.setDismissed(messageId, false));
}

/// "Good to know": what came that matters though nothing is asked. An
/// answer you were waiting for, a delivery that arrived, a notice about
/// your own accounts.
class _GoodToKnow extends ConsumerWidget {
  const _GoodToKnow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _goodToKnowItems(ref);
    return _Section(
      id: 'good-to-know',
      icon: Icons.lightbulb_outline_rounded,
      title: 'Good to know',
      count: items.length,
      children: [
        for (final i in items.take(10))
          InkWell(
            key: ValueKey('know-${i.id}'),
            onTapDown: (d) => lastPressAt = d.globalPosition,
            onSecondaryTapUp: (d) => showItemMenu(context, d.globalPosition, _knowMenu(context, ref, i)),
            onLongPress: () => showItemMenu(context, lastPressAt, _knowMenu(context, ref, i)),
            onTap: () {
              openMail(ref, i);
              if (i.person) {
                unawaited(openRow(ref.read, i.rowKey, fromToday: true));
              } else {
                ref.read(openMailProvider('feed').notifier).open(i.id);
                ref.read(destinationProvider.notifier).select(Destination.feed, fromToday: true);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.line, key: ValueKey('know-line-${i.id}'), maxLines: 3, overflow: TextOverflow.ellipsis, style: rowTitle(context)),
                        const SizedBox(height: 2),
                        Text(
                          [i.senderName, if (i.reading!.thing.isNotEmpty) i.reading!.thing, relativeTime(i.at)].join(' · '),
                          key: ValueKey('know-from-${i.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: rowSmall(context),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('know-done-${i.id}'),
                    tooltip: 'Done',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref.read(databaseProvider).setMessagesDone([i.id], true),
                    icon: const Icon(Icons.check_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        if (items.length > 10) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('and ${items.length - 10} more', style: rowSmall(context))),
      ],
    );
  }
}

/// Travel: flights and trains only, one line for each leg. With the
/// assistant on, the legs it read out of the mail; with it off, what the
/// fixed rules find. The whole card turns yellow for a delay and red for a
/// cancellation.
class _Travel extends ConsumerWidget {
  const _Travel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(ref.watch(readingsShownProvider).value ?? false)) return const _Fyi(FyiCard.travel);
    ref.watch(tripClockProvider);
    final legs = travelNow(ref.watch(helperCardsProvider).value ?? const [], DateTime.now());
    final alarm = legs.any((l) => l.cancelled) ? const Color(0xFFEF5350) : (legs.any((l) => l.delayed) ? const Color(0xFFFFCA28) : null);
    return _Section(
      id: 'travel',
      icon: Icons.flight_takeoff_rounded,
      title: 'Travel',
      count: legs.length,
      alarm: alarm,
      children: [if (legs.isNotEmpty) TravelLegs(legs: legs)],
    );
  }
}

/// Bookings: a hotel stay, a rental car, a car with a driver, a restaurant
/// table, an appointment, a ticket. With the assistant off, what the fixed
/// rules find.
class _Bookings extends ConsumerWidget {
  const _Bookings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(ref.watch(readingsShownProvider).value ?? false)) return const _Fyi(FyiCard.bookings);
    ref.watch(tripClockProvider);
    final items = bookingsNow(ref.watch(helperCardsProvider).value ?? const [], DateTime.now());
    return _Section(
      id: 'bookings',
      icon: Icons.event_available_rounded,
      title: 'Bookings',
      count: items.length,
      children: [if (items.isNotEmpty) BookingLines(items: items)],
    );
  }
}

/// One of the cards the fixed rules fill: OTP, Travel, Bookings, Deliveries,
/// Payments, FYI. Like every card but Schedule, it is not drawn when it has
/// nothing in it.
class _Fyi extends ConsumerWidget {
  const _Fyi(this.card);
  final FyiCard card;

  static IconData _look(FyiCard c) => switch (c) {
        FyiCard.otp => Icons.password_rounded,
        FyiCard.travel => Icons.flight_takeoff_rounded,
        FyiCard.bookings => Icons.event_available_rounded,
        FyiCard.deliveries => Icons.local_shipping_outlined,
        FyiCard.payments => Icons.receipt_long_outlined,
        FyiCard.fyi => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = timelyDue(ref.watch(timelyItemsProvider).value ?? const [], DateTime.now(), card: card);
    return _Section(
      id: card.id,
      icon: _look(card),
      title: card.title,
      count: due.length,
      children: [if (due.isNotEmpty) TimelyStrip(embedded: true, card: card)],
    );
  }
}

class _Later extends ConsumerWidget {
  const _Later();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(laterRowsProvider).value ?? const <LaterRow>[];
    final reminders = ref.watch(openRemindersProvider).value ?? const <Reminder>[];
    final mail = ref.watch(focusLaterProvider).value ?? const <MailItem>[];
    return _Section(
      id: 'later',
      icon: Icons.snooze_rounded,
      title: 'Later',
      count: rows.length + reminders.length + mail.length,
      children: [
        for (final i in mail)
          InkWell(
            key: ValueKey('later-mail-${i.id}'),
            onTapDown: (d) => lastPressAt = d.globalPosition,
            onSecondaryTapUp: (d) => showItemMenu(context, d.globalPosition, _laterMailMenu(context, ref, i)),
            onLongPress: () => showItemMenu(context, lastPressAt, _laterMailMenu(context, ref, i)),
            onTap: () {
              ref.read(openMailProvider('focus').notifier).open(i.id);
              openMail(ref, i);
              ref.read(destinationProvider.notifier).select(Destination.focus, fromToday: true);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.ask, maxLines: 2, overflow: TextOverflow.ellipsis, style: rowTitle(context)),
                        Text('${i.senderName} · back ${describeSnooze(i.laterUntil!)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: rowSmall(context)),
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
            onTapDown: (d) => lastPressAt = d.globalPosition,
            onSecondaryTapUp: (d) => showItemMenu(context, d.globalPosition, [MenuChoice('back', 'Bring back now', Icons.undo_rounded, () => ref.read(databaseProvider).snoozeRow(r.rowKey, null))]),
            onLongPress: () => showItemMenu(context, lastPressAt, [MenuChoice('back', 'Bring back now', Icons.undo_rounded, () => ref.read(databaseProvider).snoozeRow(r.rowKey, null))]),
            onTap: () => openRow(ref.read, r.rowKey, fromToday: true),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: rowTitle(context)),
                        Text('Back ${describeSnooze(r.until)}', style: rowSmall(context)),
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
            onTap: r.rowKey == null ? null : () => openRow(ref.read, r.rowKey, fromToday: true),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: rowTitle(context)),
                        Text('Reminder ${describeSnooze(r.dueAt)}', style: rowSmall(context)),
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
  Widget build(BuildContext context) => const _Done(ownPage: true);
}

class _Done extends ConsumerWidget {
  const _Done({this.ownPage = false});

  /// On the phone's Done page the card is the whole page, so it is drawn
  /// (and says so) with nothing in it. On Today an empty one is not drawn.
  final bool ownPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final items = ref.watch(doneTodayProvider).value ?? const <DoneItem>[];
    return _Section(
      id: 'done',
      icon: Icons.check_circle_outline_rounded,
      title: 'Done',
      count: items.length,
      alwaysShown: ownPage,
      empty: 'Nothing marked done yet today.',
      children: [
        for (final d in items)
          InkWell(
            key: ValueKey('done-${d.threadKey ?? d.title}'),
            onTap: (d.threadKey ?? '').isEmpty ? null : () => ref.read(openThreadProvider.notifier).open(d.threadKey!),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.who.isEmpty ? d.title : '${d.title} · ${d.who}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rowTitle(context).copyWith(fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant, decoration: TextDecoration.lineThrough),
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
