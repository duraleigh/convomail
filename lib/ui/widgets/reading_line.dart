import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/mail_state.dart';
import '../../domain/classifier.dart' show Bucket;
import '../../domain/email_pile.dart';
import '../../domain/piles.dart';
import '../../store/classification_queries.dart';
import '../../store/database.dart';
import '../../store/mail_queries.dart';
import '../../sync/classification_service.dart';
import '../theme/tokens.dart';

/// The soft pink that marks Focus everywhere it shows.
const focusColor = Color(0xFFF48FB1);

/// Under an email's heading: the assistant's one sentence, with a small
/// star so it is plain the assistant wrote it, and the "?" that says why
/// the email is where it is.
///
/// An email the assistant has not read (or with the assistant off) shows
/// only the "?".
class ReadingLine extends ConsumerWidget {
  const ReadingLine({super.key, required this.messageId});
  final int messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mailItemProvider(messageId)).value;
    if (item == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final line = item.reading?.line ?? '';
    final why = WhyButton(item: item);
    if (line.isEmpty) {
      return Align(alignment: Alignment.centerRight, child: why);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Container(
        key: ValueKey('reading-$messageId'),
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.38), borderRadius: BorderRadius.circular(AppShapes.md)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line, style: text.bodyMedium!.copyWith(color: scheme.onSurface)),
                  if (item.inFocus && (item.reading?.due != null))
                    Text('Needed by ${dueLabel(item.reading!.due!)}', style: text.labelMedium!.copyWith(color: const Color(0xFFFFB74D), letterSpacing: 0)),
                ],
              ),
            ),
            why,
          ],
        ),
      ),
    );
  }
}

/// "3:00 PM", "tomorrow 3:00 PM", "Fri 3:00 PM", "Mar 14".
String dueLabel(DateTime due, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final l = due.toLocal();
  final days = DateTime(l.year, l.month, l.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  final hour = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final time = '$hour:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const week = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return switch (days) {
    0 => time,
    1 => 'tomorrow $time',
    -1 => 'yesterday $time',
    > 1 && < 7 => '${week[l.weekday - 1]} $time',
    _ => '${months[l.month - 1]} ${l.day}',
  };
}

/// Where an email sits, in a word.
String placeName(MailItem i) => i.inFocus ? 'Focus' : (i.person ? 'Chats' : (i.pile == FeedsPile.noise ? 'Noise' : 'Feed'));

/// The reasons the "?" gives, three at most, as plain sentences.
List<String> whyReasons(MailItem i) {
  final out = <String>[];
  if (i.focusFix == 'yes') out.add('You put this in Focus.');
  if (i.focusFix == 'no') out.add('You said this does not need you.');
  out.addAll(i.reading?.why ?? const []);
  if (!i.person && i.pile != null && i.by != null && i.by != PileBy.assistant) {
    out.add(pileReason(i.pile!, i.by!, tag: i.tag, gmailTab: i.gmailTab));
  }
  if (i.person && out.length < 3) {
    for (final r in i.senderWhy.split(' · ')) {
      if (r.trim().isNotEmpty && out.length < 3) out.add(r.trim().endsWith('.') ? r.trim() : '${r.trim()}.');
    }
  }
  if (out.isEmpty) out.add(i.person ? 'It is from a person, so it is in Chats.' : 'The assistant has not read this email.');
  return out.take(3).toList();
}

/// Moves everything from an email's sender for good: to Feed or Noise
/// ([pile]), or to Chats when [pile] is null ("This is a person"). The
/// user's move stays until they change it; Undo puts it back.
Future<void> moveSenderOf(BuildContext context, WidgetRef ref, MailItem item, {FeedsPile? pile, bool notPerson = false}) async {
  final messenger = ScaffoldMessenger.of(context);
  final db = ref.read(databaseProvider);
  final service = ref.read(classificationServiceProvider);
  final before = item.senderChosen;
  if (notPerson) {
    await service.moveSender(item.senderKey, Bucket.feeds);
  } else if (pile == null) {
    await service.moveSender(item.senderKey, Bucket.people);
  } else {
    await db.setSenderPile(item.senderKey, pile);
  }
  final where = notPerson ? 'Feed or Noise' : (pile == null ? 'Chats' : (pile == FeedsPile.feed ? 'Feed' : 'Noise'));
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(persist: false, duration: const Duration(seconds: 8), 
    content: Text('${item.senderName} moved to $where. It stays there until you change it.'),
    behavior: SnackBarBehavior.floating,
    width: 480,
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () async {
        if (pile == null || notPerson) {
          await service.moveSender(item.senderKey, null);
        } else {
          await db.setSenderPile(item.senderKey, before);
        }
      },
    ),
  ));
}

/// The "?" on an email: why it is where it is, and one tap to change it.
class WhyButton extends ConsumerWidget {
  const WhyButton({super.key, required this.item});
  final MailItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      key: ValueKey('why-${item.id}'),
      tooltip: 'Why this is here',
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.help_outline_rounded, size: 18, color: scheme.onSurfaceVariant),
      onPressed: () => showDialog<void>(context: context, builder: (_) => WhyDialog(messageId: item.id)),
    );
  }
}

class WhyDialog extends ConsumerWidget {
  const WhyDialog({super.key, required this.messageId});
  final int messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mailItemProvider(messageId)).value;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (item == null) return const SizedBox.shrink();
    final db = ref.read(databaseProvider);
    final other = item.pile == FeedsPile.noise ? FeedsPile.feed : FeedsPile.noise;
    final otherName = other == FeedsPile.feed ? 'Feed' : 'Noise';

    void done(String said) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(persist: false, content: Text(said)));
    }

    return AlertDialog(
      key: const ValueKey('why-dialog'),
      title: Text('Why this is in ${placeName(item)}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in whyReasons(item))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 7, right: 10), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: scheme.onSurfaceVariant, shape: BoxShape.circle))),
                    Expanded(child: Text(r, style: text.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.inFocus)
                  FilledButton.tonal(
                    key: const ValueKey('why-not-focus'),
                    onPressed: () async {
                      await db.setFocusFix(item.id, false);
                      done('Taken out of Focus. The email is still in ${item.person ? 'its chat' : 'Feed'}.');
                    },
                    child: const Text('Not Focus'),
                  )
                else if (item.doneAt == null)
                  FilledButton.tonal(
                    key: const ValueKey('why-needs-me'),
                    onPressed: () async {
                      await db.setFocusFix(item.id, true);
                      done('Added to Focus.');
                    },
                    child: const Text('This needs me'),
                  ),
                // Mail from a person that is not really from one: this one
                // email, or the sender for good.
                if (item.person) ...[
                  OutlinedButton(
                    key: const ValueKey('why-not-person-one'),
                    onPressed: () async {
                      await ref.read(classificationServiceProvider).setMessageBucket(item.id, Bucket.feeds);
                      done('This one email moved out of Chats. The sender is still a person.');
                    },
                    child: const Text('This one is not from a person'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('why-not-person'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      moveSenderOf(context, ref, item, notPerson: true);
                    },
                    child: const Text('Always: this sender is not a person'),
                  ),
                ],
                if (!item.person) ...[
                  OutlinedButton(
                    key: const ValueKey('why-chats-one'),
                    onPressed: () async {
                      await ref.read(classificationServiceProvider).setMessageBucket(item.id, Bucket.people);
                      done('This one email moved to Chats.');
                    },
                    child: const Text('This one belongs in Chats'),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey('why-move-one'),
                    onPressed: () async {
                      await db.setEmailPile(item.id, other);
                      done('This email moved to $otherName.');
                    },
                    child: Text('Move this one to $otherName'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('why-move-sender'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      moveSenderOf(context, ref, item, pile: other);
                    },
                    child: Text('Always $otherName for this sender'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('why-person'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      moveSenderOf(context, ref, item);
                    },
                    child: const Text('This is a person'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
