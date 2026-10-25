import 'dart:async';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/html_sanitizer.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';
import '../store/thread_queries.dart';
import '../sync/attachment_service.dart';
import '../sync/sync_controller.dart';
import 'search_state.dart';
import 'settings.dart';

/// Message ids currently expanded inline in the conversation (spec 4.3).
final expandedMessagesProvider = NotifierProvider<ExpandedMessagesNotifier, Set<int>>(ExpandedMessagesNotifier.new);

class ExpandedMessagesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};
  void toggle(int id) => state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
  void expand(int id) => state = {...state, id};
  void clear() => state = const {};
}

/// The thread key whose full thread view is open as an overlay, or null.
final openThreadProvider = NotifierProvider<OpenThreadNotifier, String?>(OpenThreadNotifier.new);

class OpenThreadNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String key) => state = key;
  void close() => state = null;
}

/// The live message row (flags, imagesAllowed, body columns).
final messageRowProvider = StreamProvider.family<Message?, int>((ref, messageId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.messages)..where((m) => m.id.equals(messageId))).watchSingleOrNull();
});

/// The message with its body present. If the body has not been fetched,
/// asks the account's syncer once; the row stream then emits the stored
/// body and everything re-renders. Re-emits on any later change to the row
/// (e.g. "Load images").
final messageBodyProvider = FutureProvider.family<Message, int>((ref, messageId) async {
  final m = await ref.watch(messageRowProvider(messageId).future);
  if (m == null) throw StateError('Message $messageId no longer exists');
  if (m.bodyFetchedAt != null) return m;
  final syncer = ref.read(syncControllerProvider).syncerFor(m.accountId);
  if (syncer == null) throw StateError('This account is not connected. The message body will load when sync resumes.');
  await syncer.fetchBody(messageId);
  // storeBody updated the row; the stream above delivers it on the next
  // build. Return the fresh row now so the first render has the body.
  return (await ref.read(databaseProvider).messageById(messageId))!;
});

/// Attachments of a message.
final messageAttachmentsProvider = StreamProvider.family<List<Attachment>, int>((ref, messageId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.attachments)..where((a) => a.messageId.equals(messageId))).watch();
});

/// Rendered, sanitized HTML for a message plus what was blocked. Records
/// tracker events (spec 4.13) as a side effect of rendering.
class RenderedBody {
  const RenderedBody({required this.html, required this.sanitized, required this.isPlainText});
  final String html;
  final SanitizedHtml sanitized;
  final bool isPlainText;
}

final renderedBodyProvider = FutureProvider.family<RenderedBody, int>((ref, messageId) async {
  final m = await ref.watch(messageBodyProvider(messageId).future);
  final settings = ref.watch(settingsProvider);
  final allow = m.imagesAllowed || !settings.blockRemoteImages;
  const sanitizer = HtmlSanitizer();
  final isPlain = (m.bodyHtml ?? '').trim().isEmpty;
  final source = isPlain ? plainTextToHtml(m.bodyText ?? '') : m.bodyHtml!;

  // Inline (cid:) images come from the message itself, never the network:
  // downloaded parts are embedded as data URIs; missing ones are fetched
  // and the attachments stream re-renders this provider when they land.
  final inline = (ref.watch(messageAttachmentsProvider(messageId)).value ?? const <Attachment>[]).where((a) => a.isInline).toList();
  if (inline.any((a) => a.localPath == null)) {
    unawaited(ref.read(attachmentServiceProvider).downloadInline(messageId));
  }
  final highlight = ref.watch(conversationHighlightProvider);
  final out = sanitizer.sanitize(source, allowRemoteImages: allow, resolveCid: (cid) => AttachmentService.dataUriFor(inline, cid), highlight: highlight);
  await ref.read(databaseProvider).recordTrackerEvents(messageId, out);
  return RenderedBody(html: out.html, sanitized: out, isPlainText: isPlain);
});

/// Thread messages across all participants (spec 4.20), oldest first.
final threadMessagesProvider = StreamProvider.family<List<Message>, String>((ref, threadKey) {
  return ref.watch(databaseProvider).watchThread(threadKey);
});

/// Aggregate privacy stats for Settings → Privacy (spec 4.13).
class PrivacyStats {
  const PrivacyStats({required this.trackersBlockedThisWeek, required this.sendersWhoKnowYouRead, required this.imagesBlockedTotal});
  final int trackersBlockedThisWeek;
  final int sendersWhoKnowYouRead;
  final int imagesBlockedTotal;
}

final privacyStatsProvider = StreamProvider<PrivacyStats>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.trackerEvents).watch().asyncMap((_) => db.privacyStats());
});

extension PrivacyQueries on AppDatabase {
  Future<void> recordTrackerEvents(int messageId, SanitizedHtml out) async {
    if (out.remote.isEmpty) return;
    await transaction(() async {
      await (delete(trackerEvents)..where((t) => t.messageId.equals(messageId))).go();
      final seen = <String>{};
      for (final r in out.remote) {
        if (!seen.add(r.host)) continue;
        await into(trackerEvents).insert(TrackerEventsCompanion.insert(
          messageId: messageId,
          host: r.host,
          isTracker: Value(r.isTracker),
          blocked: Value(!out.allowedRemote),
        ));
      }
    });
  }

  Future<void> setImagesAllowed(int messageId, bool allowed) => (update(messages)..where((m) => m.id.equals(messageId))).write(MessagesCompanion(imagesAllowed: Value(allowed)));

  Future<PrivacyStats> privacyStats() async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final blockedWeek = await customSelect(
      'SELECT COUNT(*) AS n FROM tracker_events WHERE blocked = 1 AND is_tracker = 1 AND at >= ?',
      variables: [Variable.withDateTime(weekAgo)],
    ).getSingle();
    final blockedTotal = await customSelect('SELECT COUNT(*) AS n FROM tracker_events WHERE blocked = 1').getSingle();
    final senders = await customSelect(
      'SELECT COUNT(DISTINCT m.from_contact_key) AS n FROM tracker_events t JOIN messages m ON m.id = t.message_id WHERE t.blocked = 0 AND t.is_tracker = 1',
    ).getSingle();
    return PrivacyStats(
      trackersBlockedThisWeek: blockedWeek.data['n'] as int,
      imagesBlockedTotal: blockedTotal.data['n'] as int,
      sendersWhoKnowYouRead: senders.data['n'] as int,
    );
  }

  Future<void> resetPrivacyStats() => delete(trackerEvents).go();
}
