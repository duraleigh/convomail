import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/account_scope.dart';
import '../../../app/compose_state.dart';
import '../../../app/conversation_state.dart';
import '../../../app/search_state.dart';
import '../../../domain/classifier.dart';
import '../../../store/classification_queries.dart';
import '../../../store/database.dart';
import '../../../sync/row_actions.dart';
import '../../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../../widgets/reading_line.dart';
import '../../widgets/tonal_avatar.dart';
import 'files/attachment_ui.dart';
import 'html_body_view.dart';
import 'people_list_pane.dart';
import 'rule_proposal_dialog.dart';
import 'simple_mail_view.dart';
import 'thread_actions.dart';

/// One expanded message (spec 4.3): header with To/CC and time, privacy
/// strip when remote content was blocked, the sanitized body, attachment
/// chips, and the inline action bar.
class MessageCard extends ConsumerWidget {
  const MessageCard({super.key, required this.message, this.showViewThread = true, this.threadCount = 1, this.inChat = 1, this.onViewThread});

  final Message message;
  final bool showViewThread;
  final int threadCount;

  /// How many of the thread's messages this chat holds; the rest belong to
  /// other people's chats and open with "N more in this thread".
  final int inChat;
  final VoidCallback? onViewThread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final body = ref.watch(renderedBodyProvider(message.id));
    final attachments = ref.watch(messageAttachmentsProvider(message.id)).value ?? const <Attachment>[];
    final participants = ref.watch(_participantsProvider(message.id)).value ?? const <MessageParticipant>[];
    final to = participants.where((p) => p.role == 'to').map(_label).join(', ');
    final cc = participants.where((p) => p.role == 'cc').map(_label).join(', ');
    final senderName = message.isFromMe ? 'You' : (message.fromName.isNotEmpty ? message.fromName : message.fromAddress);
    final detailsOpen = ref.watch(_detailsOpenProvider).contains(message.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TonalAvatar(identityKey: message.isFromMe ? 'me' : message.fromContactKey, name: senderName, size: 36),
            const SizedBox(width: 10),
            Expanded(
              // Clicking the sender line shows who exactly sent it, from which
              // address, and everyone it went to.
              child: InkWell(
                key: ValueKey('message-details-toggle-${message.id}'),
                borderRadius: BorderRadius.circular(AppShapes.sm),
                onTap: () => ref.read(_detailsOpenProvider.notifier).toggle(message.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            senderName,
                            style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (message.feedsCategory != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            key: ValueKey('message-category-${message.id}'),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                            decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(AppShapes.full)),
                            child: Text(message.feedsCategory!, style: text.labelSmall!.copyWith(color: scheme.onTertiaryContainer, letterSpacing: 0)),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            [
                              if (to.isNotEmpty) 'To: $to',
                              if (cc.isNotEmpty) 'CC: $cc',
                              _fullTime(message.date ?? message.internalDate),
                              if (ref.watch(multiAccountProvider)) 'via ${_accountEmail(ref)}',
                            ].join(' · '),
                            style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Shows there is more to see here.
                        Icon(detailsOpen ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 18, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: message.isFlagged ? 'Unstar' : 'Star',
              icon: Icon(message.isFlagged ? Icons.star_rounded : Icons.star_outline_rounded, color: message.isFlagged ? scheme.primary : scheme.onSurfaceVariant),
              onPressed: () => _setFlagged(ref, !message.isFlagged),
            ),
          ],
        ),
        if (detailsOpen) _MessageDetails(message: message, participants: participants, account: ref.watch(multiAccountProvider) ? _accountEmail(ref) : null),
        // The assistant's one sentence, and the "?" that says why the email
        // is where it is. Nothing of the kind sits on the user's own mail.
        if (!message.isFromMe && !message.isDraft) ReadingLine(messageId: message.id),
        const SizedBox(height: AppSpace.md),
        // While the email is worked out again (marked read, say), the one on
        // screen stays: a reload never blanks it.
        body.when(
          skipLoadingOnReload: true,
          // A steady blank of about an email's height, with a quiet bar only
          // if the download takes a while: no spinner flashing by.
          loading: () => const _BodyPlaceholder(),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
            child: Row(
              children: [
                Expanded(
                  child: Text('$e'.replaceFirst('Bad state: ', '').replaceFirst('MailTransportException: ', ''), style: text.bodyMedium!.copyWith(color: scheme.onErrorContainer)),
                ),
                const SizedBox(width: AppSpace.sm),
                TextButton(key: ValueKey('body-retry-${message.id}'), onPressed: () => ref.invalidate(messageBodyProvider(message.id)), child: const Text('Retry')),
              ],
            ),
          ),
          data: (r) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The pictures notice is for Feeds only; mail from people just
              // shows its pictures.
              if (r.sanitized.hasRemoteContent && message.classification == 'feeds') _PrivacyStrip(message: message, rendered: r),
              if (r.sanitized.hasRemoteContent && message.classification == 'feeds') const SizedBox(height: AppSpace.sm),
              if (r.isPlainText && !r.sanitized.hasRemoteContent)
                PlainTextBody(text: r.text, highlight: ref.watch(conversationHighlightProvider))
              // Simple mail prints straight into the conversation; only
              // designed mail needs the browser box.
              else if (r.blocks != null)
                SimpleMailBody(blocks: r.blocks!)
              else
                ref.watch(htmlRendererProvider)(context, r.html),
              if (r.hasQuoted || ref.watch(earlierMailShownProvider).contains(message.id)) _EarlierMailToggle(messageId: message.id, shown: !r.hasQuoted),
            ],
          ),
        ),
        ReminderChips(messageId: message.id),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final a in attachments.where((a) => !a.isInline)) AttachmentChip(key: ValueKey('chip-${a.id}'), attachment: a)],
          ),
        ],
        const SizedBox(height: AppSpace.sm),
        Divider(color: scheme.outlineVariant),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => ref.read(replyRequestProvider.notifier).open(ComposeRequest.reply(message.id, rowKey: _rowKey)),
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: const Text('Reply'),
            ),
            IconButton(
              tooltip: 'Reply all',
              onPressed: () => ref.read(replyRequestProvider.notifier).open(ComposeRequest.reply(message.id, rowKey: _rowKey, all: true)),
              icon: const Icon(Icons.reply_all_rounded, size: 18),
              visualDensity: VisualDensity.compact,
            ),
            TextButton.icon(
              onPressed: () => ref.read(replyRequestProvider.notifier).open(ComposeRequest.forward(message.id, rowKey: _rowKey)),
              icon: const Icon(Icons.forward_rounded, size: 18),
              label: const Text('Forward'),
            ),
            if (showViewThread && threadCount > inChat) ...[
              const SizedBox(width: 4),
              TextButton.icon(
                key: ValueKey('more-in-thread-${message.id}'),
                onPressed: onViewThread,
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: Text('${threadCount - inChat} more in this thread'),
              ),
            ],
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) async {
                final actions = ref.read(rowActionsProvider);
                switch (v) {
                  case 'unread':
                    await actions.markMessageRead(message.id, seen: false);
                  case 'read':
                    await actions.markMessageRead(message.id, seen: true);
                  case 'bucket':
                    final target = message.classification == 'feeds' ? Bucket.people : Bucket.feeds;
                    if (context.mounted) await correctClassification(context, ref, message: message, bucket: target, title: target == Bucket.people ? 'Move to Chats' : 'Move to Feed or Noise');
                  case 'category':
                    final names = await ref.read(databaseProvider).categoryNames();
                    if (!context.mounted) return;
                    final picked = await showDialog<String?>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Category for this message'),
                        children: [for (final n in names) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, n), child: Text(n))],
                      ),
                    );
                    if (picked != null && context.mounted) await correctClassification(context, ref, message: message, category: picked, title: 'Tag as $picked');
                  case 'trash':
                    final pending = await actions.trashRow('c:${message.fromContactKey}', messageIds: [message.id], label: 'Moved to Trash');
                    if (pending != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(pending.label),
                          duration: actions.undoWindow,
                          behavior: SnackBarBehavior.floating,
                          width: 420,
                          action: SnackBarAction(label: 'Undo', onPressed: () => actions.undo(pending)),
                        ),
                      );
                    }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: message.isSeen ? 'unread' : 'read', child: Text(message.isSeen ? 'Mark unread' : 'Mark read')),
                const PopupMenuItem(value: 'trash', child: Text('Move to Trash')),
                if (!message.isFromMe) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'bucket', child: Text(message.classification == 'feeds' ? 'This is a person → Chats…' : 'This is not a person → Feed or Noise…')),
                  if (message.classification == 'feeds') const PopupMenuItem(value: 'category', child: Text('Change category…')),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// The row this card is shown in: the sender's, or for our own mail the
  /// selected row (the recipient's).
  String get _rowKey => 'c:${message.fromContactKey}';

  String _accountEmail(WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    return accounts.where((a) => a.id == message.accountId).firstOrNull?.email ?? 'account ${message.accountId}';
  }

  static String _label(MessageParticipant p) => p.isMe ? 'me' : (p.name.isNotEmpty ? p.name : p.address);

  static String _fullTime(DateTime? t) {
    if (t == null) return '';
    final l = t.toLocal();
    return '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][l.month - 1]} ${l.day}, ${l.year} · ${relativeTime(l)}';
  }

  Future<void> _setFlagged(WidgetRef ref, bool flagged) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.messages)..where((m) => m.id.equals(message.id))).write(MessagesCompanion(isFlagged: Value(flagged)));
    final syncer = ref.read(syncControllerProvider).syncerFor(message.accountId);
    if (syncer != null) await syncer.setFlags(message.folderId, [message.uid], flagged: flagged);
  }
}

final _participantsProvider = StreamProvider.family<List<MessageParticipant>, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.messageParticipants)..where((p) => p.messageId.equals(id))).watch();
});

/// "N remote images blocked · Load images" with an expandable list of the
/// blocked hosts (spec 4.13 tracker log).
class _PrivacyStrip extends ConsumerStatefulWidget {
  const _PrivacyStrip({required this.message, required this.rendered});
  final Message message;
  final RenderedBody rendered;

  @override
  ConsumerState<_PrivacyStrip> createState() => _PrivacyStripState();
}

class _PrivacyStripState extends ConsumerState<_PrivacyStrip> {
  bool _showHosts = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = widget.rendered.sanitized;
    final blocked = !s.allowedRemote;
    final trackers = s.trackerHosts.length;
    final label = blocked
        ? '${s.remote.length} remote image${s.remote.length == 1 ? '' : 's'} blocked${trackers > 0 ? ' · $trackers tracker${trackers == 1 ? '' : 's'}' : ''}'
        : 'Remote images loaded for this message${trackers > 0 ? ' · $trackers tracker${trackers == 1 ? '' : 's'} can see you read it' : ''}';

    return Container(
      decoration: BoxDecoration(color: blocked ? scheme.secondaryContainer : scheme.tertiaryContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(blocked ? Icons.shield_outlined : Icons.visibility_outlined, size: 18, color: blocked ? scheme.onSecondaryContainer : scheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: text.labelLarge!.copyWith(color: blocked ? scheme.onSecondaryContainer : scheme.onTertiaryContainer)),
              ),
              TextButton(onPressed: () => setState(() => _showHosts = !_showHosts), child: Text(_showHosts ? 'Hide hosts' : 'Blocked hosts')),
              if (blocked)
                FilledButton.tonal(onPressed: () => ref.read(databaseProvider).setImagesAllowed(widget.message.id, true), child: const Text('Load images'))
              else
                TextButton(onPressed: () => ref.read(databaseProvider).setImagesAllowed(widget.message.id, false), child: const Text('Block again')),
            ],
          ),
          if (_showHosts)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 4, 8, 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in s.remote.map((r) => r.host).toSet())
                    Chip(
                      avatar: s.trackerHosts.contains(r) ? const Icon(Icons.gps_fixed_rounded, size: 14) : null,
                      label: Text(r, style: text.labelSmall!.copyWith(letterSpacing: 0)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BodyPlaceholder extends StatefulWidget {
  const _BodyPlaceholder();

  @override
  State<_BodyPlaceholder> createState() => _BodyPlaceholderState();
}

class _BodyPlaceholderState extends State<_BodyPlaceholder> {
  bool _slow = false;
  late final Timer _timer = Timer(const Duration(milliseconds: 600), () {
    if (mounted) setState(() => _slow = true);
  });

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 160,
    child: Align(
      alignment: Alignment.topLeft,
      child: _slow ? SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6))) : null,
    ),
  );
}

/// Messages whose full sender and recipient details are open.
/// "Show earlier mail" under an email whose copied earlier mail is hidden.
class _EarlierMailToggle extends ConsumerWidget {
  const _EarlierMailToggle({required this.messageId, required this.shown});
  final int messageId;
  final bool shown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.xs),
        child: TextButton.icon(
          key: ValueKey('earlier-mail-$messageId'),
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant, padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
          onPressed: () => ref.read(earlierMailShownProvider.notifier).toggle(messageId),
          icon: Icon(shown ? Icons.unfold_less_rounded : Icons.more_horiz_rounded, size: 18),
          label: Text(shown ? 'Hide earlier mail' : 'Show earlier mail'),
        ),
      ),
    );
  }
}

final _detailsOpenProvider = NotifierProvider<_DetailsOpen, Set<int>>(_DetailsOpen.new);

class _DetailsOpen extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};
  void toggle(int id) => state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
}

/// Who sent a message, from exactly which address, and everyone it went to,
/// each with name and address. Addresses can be selected and copied.
class _MessageDetails extends StatelessWidget {
  const _MessageDetails({required this.message, required this.participants, this.account});
  final Message message;
  final List<MessageParticipant> participants;
  final String? account;

  static String _date(DateTime? t) {
    if (t == null) return '';
    final l = t.toLocal();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final hour = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '${days[l.weekday - 1]}, ${months[l.month - 1]} ${l.day}, ${l.year} at $hour:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final label = text.labelMedium!.copyWith(color: scheme.onSurfaceVariant);
    final name = text.bodyMedium!;
    final address = text.bodySmall!.copyWith(color: scheme.onSurfaceVariant);

    Widget person(String n, String a) => SelectableText.rich(
      TextSpan(
        children: [
          if (n.isNotEmpty && n.toLowerCase() != a.toLowerCase()) TextSpan(text: '$n  ', style: name),
          TextSpan(text: a, style: n.isEmpty ? name : address),
        ],
      ),
    );

    TableRow row(String title, List<Widget> values) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3, bottom: 6),
          child: Text(title, style: label),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: values),
        ),
      ],
    );

    List<Widget> people(String role) => [for (final p in participants.where((p) => p.role == role)) person(p.isMe ? (p.name.isEmpty ? 'You' : '${p.name} (you)') : p.name, p.address)];

    final from = people('from');
    final rows = <TableRow>[
      row('From', from.isEmpty ? [person(message.fromName, message.fromAddress)] : from),
      for (final (role, title) in const [('replyTo', 'Reply to'), ('to', 'To'), ('cc', 'Cc'), ('bcc', 'Bcc')])
        if (participants.any((p) => p.role == role)) row(title, people(role)),
      row('Date', [SelectableText(_date(message.date ?? message.internalDate), style: name)]),
      if (account != null) row('Account', [SelectableText(account!, style: name)]),
    ];
    return Container(
      key: ValueKey('message-details-${message.id}'),
      margin: const EdgeInsets.only(top: AppSpace.sm, left: 46),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: [
          for (final r in rows)
            TableRow(
              children: [
                Padding(padding: const EdgeInsets.only(right: 16), child: r.children[0]),
                r.children[1],
              ],
            ),
        ],
      ),
    );
  }
}
