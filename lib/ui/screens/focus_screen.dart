import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/mail_state.dart';
import '../../store/database.dart';
import '../../store/done_queries.dart';
import '../../store/mail_queries.dart';
import '../widgets/empty_state.dart';
import 'chats/later_dialogs.dart' show describeSnooze;
import 'mail/mail_widgets.dart';

/// Focus: every email that needs the user, as a list of emails (not of
/// people). Each row says who and what is asked, with a "by" time when the
/// email gives one. The open email is on the right.
///
/// It is filled by the assistant on the helper. With no assistant the list
/// stays empty and says why; nothing is guessed.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(readingsShownProvider).value ?? false;
    // Rows dealt with a moment ago leave at once; once the list itself no
    // longer has them, they are forgotten here.
    final dealt = ref.watch(focusDealtProvider);
    ref.listen(focusMailProvider, (_, next) {
      final now = next.value;
      if (now != null) ref.read(focusDealtProvider.notifier).keepOnly({for (final i in now) i.id});
    });
    final items = [
      for (final i in ref.watch(focusMailProvider).value ?? const <MailItem>[])
        if (!dealt.contains(i.id)) i,
    ];
    final done = ref.watch(focusDoneTodayProvider).value ?? const <MailItem>[];
    final later = ref.watch(focusLaterProvider).value ?? const <MailItem>[];
    final openId = ref.watch(openMailProvider('focus'));
    final open = [...items, ...later, ...done].where((i) => i.id == openId).firstOrNull;

    if (!shown && items.isEmpty && later.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MailListHeader(title: 'Focus', subtitle: 'The emails that need you.'),
          Expanded(
            child: EmptyState(
              key: ValueKey('focus-empty'),
              icon: Icons.adjust_rounded,
              title: 'Nothing here yet',
              message: 'The assistant is not on. When it is, every email that needs you is listed here.',
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final groups = <MailGroup>[
      (label: 'Today', items: [for (final i in items) if (!i.at.isBefore(today)) i]),
      (label: 'Earlier this week', items: [for (final i in items) if (i.at.isBefore(today) && !i.at.isBefore(weekStart)) i]),
      (label: 'Earlier', items: [for (final i in items) if (i.at.isBefore(weekStart)) i]),
    ].where((g) => g.items.isNotEmpty).toList();

    void tap(MailItem i) {
      ref.read(openMailProvider('focus').notifier).open(i.id);
      openMail(ref, i);
    }

    // Done or Not Focus, right in the list: the row leaves at once, and
    // Undo brings it back.
    Future<void> deal(MailItem i, {required bool done}) async {
      final db = ref.read(databaseProvider);
      final gone = ref.read(focusDealtProvider.notifier);
      final messenger = ScaffoldMessenger.of(context);
      gone.add(i.id);
      if (!done && ref.read(openMailProvider('focus')) == i.id) ref.read(openMailProvider('focus').notifier).open(null);
      if (done) {
        await db.setMessagesDone([i.id], true);
      } else {
        await db.setFocusFix(i.id, false);
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(persist: false, duration: const Duration(seconds: 8), 
        content: Text(done ? 'Done: ${i.ask}' : 'Taken out of Focus. The email is still in ${i.person ? 'its chat' : 'Feed'}.', maxLines: 1, overflow: TextOverflow.ellipsis),
        behavior: SnackBarBehavior.floating,
        width: 460,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            gone.remove(i.id);
            if (done) {
              await db.setMessagesDone([i.id], false);
            } else {
              await db.setFocusFix(i.id, i.focusFix == 'yes' ? true : null);
            }
          },
        ),
      ));
    }

    final entries = <Widget>[
      for (final g in groups) ...[
        MailGroupLabel(label: g.label, count: g.items.length),
        for (final i in g.items)
          QuickActions(
            key: ValueKey('quick-row-${i.id}'),
            id: i.id,
            onDone: () => deal(i, done: true),
            onLater: () => putOffFocusMail(context, ref, i),
            onIgnore: () => deal(i, done: false),
            child: MailRowTile(item: i, focus: true, selected: i.id == openId, onTap: () => tap(i), onMenu: (at) => showMailMenu(context, ref, i, at)),
          ),
      ],
      // Put off until a time: out of the way, but findable, and each one
      // says when it comes back.
      if (later.isNotEmpty) ...[
        MailGroupLabel(label: 'Later', count: later.length),
        for (final i in later)
          MailRowTile(
            item: i,
            focus: true,
            faded: true,
            note: 'back ${describeSnooze(i.laterUntil!)}',
            selected: i.id == openId,
            onTap: () => tap(i),
            onMenu: (at) => showMailMenu(context, ref, i, at),
          ),
      ],
      if (done.isNotEmpty) ...[
        MailGroupLabel(label: 'Done today', count: done.length),
        for (final i in done) MailRowTile(item: i, focus: true, faded: true, selected: i.id == openId, onTap: () => tap(i), onMenu: (at) => showMailMenu(context, ref, i, at)),
      ],
    ];

    return MailSplit(
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MailListHeader(
            title: 'Focus',
            subtitle: items.isEmpty ? 'Nothing needs you. Everything else is in Chats, Feed or Noise.' : '${items.length} email${items.length == 1 ? '' : 's'} need${items.length == 1 ? 's' : ''} you. Everything else is in Chats, Feed or Noise.',
          ),
          Expanded(
            child: entries.isEmpty
                ? const EmptyState(key: ValueKey('focus-clear'), icon: Icons.check_circle_outline_rounded, title: 'All clear', message: 'The assistant has read your mail and found nothing that needs you.')
                : ListView(key: const PageStorageKey('focus-list'), padding: const EdgeInsets.only(bottom: 16), children: entries),
          ),
        ],
      ),
      right: open == null ? const MailNothingOpen(icon: Icons.adjust_rounded, message: 'Pick an email on the left to read it here.') : MailEmailPane(item: open),
    );
  }
}
