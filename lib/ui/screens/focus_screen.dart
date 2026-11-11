import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/mail_state.dart';
import '../../store/mail_queries.dart';
import '../widgets/empty_state.dart';
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
    final items = ref.watch(focusMailProvider).value ?? const <MailItem>[];
    final done = ref.watch(focusDoneTodayProvider).value ?? const <MailItem>[];
    final openId = ref.watch(openMailProvider('focus'));
    final open = [...items, ...done].where((i) => i.id == openId).firstOrNull;

    if (!shown && items.isEmpty) {
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

    final entries = <Widget>[
      for (final g in groups) ...[
        MailGroupLabel(label: g.label, count: g.items.length),
        for (final i in g.items) MailRowTile(item: i, focus: true, selected: i.id == openId, onTap: () => tap(i), onMenu: (at) => showMailMenu(context, ref, i, at)),
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
