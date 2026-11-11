import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/mail_state.dart';
import '../../app/people_state.dart';
import '../../app/timely_state.dart';
import '../../domain/classifier.dart' show FeedsCategories;
import '../../store/mail_queries.dart';
import '../widgets/empty_state.dart';
import 'mail/mail_widgets.dart';

/// The tags in use among [items], the built-in ones first in their usual
/// order, then the user's own by name.
List<String> tagsInUse(Iterable<MailItem> items) {
  final used = {for (final i in items) if (i.tag != null) i.tag!};
  return [
    for (final t in FeedsCategories.defaults) if (used.contains(t)) t,
    ...(used.where((t) => !FeedsCategories.defaults.contains(t)).toList()..sort()),
  ];
}

/// Feed: mail worth knowing that needs no reply. A list of emails, newest
/// first, grouped by day. Each row's second line says what the email is, so
/// most never need opening. Whether an email is here or in Noise is decided
/// for that email, not for its sender.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(feedMailProvider);
    final loading = ref.watch(otherMailProvider).isLoading && all.isEmpty;
    final tag = ref.watch(mailTagProvider('feed'));
    final tags = tagsInUse(all);
    final items = tag == null || !tags.contains(tag) ? all : [for (final i in all) if (i.tag == tag) i];
    final openId = ref.watch(openMailProvider('feed'));
    final open = all.where((i) => i.id == openId).firstOrNull;

    // A sender opened from somewhere else (search, Today) lands on its
    // newest email here, whether Feed was already showing or not.
    final asked = ref.watch(selectedRowProvider);
    if (asked != null) {
      final first = all.where((i) => i.rowKey == asked).firstOrNull;
      if (first != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ref.read(selectedRowProvider.notifier).select(null);
          ref.read(openMailProvider('feed').notifier).open(first.id);
        });
      }
    }

    // A sign-in code still in date shows on its sender's newest row, with Copy.
    final codes = {
      for (final c in timelyDue(ref.watch(timelyItemsProvider).value ?? const [], DateTime.now()).reversed)
        if (c.code != null) c.contactKey: c.code!,
    };
    final codeShown = <String>{};

    final entries = <Widget>[];
    for (final g in groupByDay(items)) {
      entries.add(MailGroupLabel(label: g.label, count: g.items.length));
      for (final i in g.items) {
        entries.add(MailRowTile(
          item: i,
          selected: i.id == openId,
          code: codes[i.senderKey] != null && codeShown.add(i.senderKey) ? codes[i.senderKey] : null,
          onTap: () {
            ref.read(openMailProvider('feed').notifier).open(i.id);
            openMail(ref, i);
          },
          onMenu: (at) => showMailMenu(context, ref, i, at),
        ));
      }
    }

    return MailSplit(
      left: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MailListHeader(title: 'Feed', subtitle: 'Worth knowing. Nothing here needs a reply.'),
          TagPills(tags: tags, selected: tags.contains(tag) ? tag : null, onSelect: (t) => ref.read(mailTagProvider('feed').notifier).select(t)),
          Expanded(
            child: loading
                ? const SizedBox.shrink()
                : entries.isEmpty
                    ? const EmptyState(key: ValueKey('feed-empty'), icon: Icons.rss_feed_rounded, title: 'Nothing in Feed', message: 'Receipts, deliveries, trips, codes and notices worth knowing show here.')
                    : ListView.builder(key: const PageStorageKey('feed-list'), padding: const EdgeInsets.only(bottom: 16), itemCount: entries.length, itemBuilder: (_, i) => entries[i]),
          ),
        ],
      ),
      right: open == null ? const MailNothingOpen(icon: Icons.rss_feed_rounded, message: 'Pick an email on the left to read it here.') : MailEmailPane(item: open),
    );
  }
}
