import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/event_extractor.dart';
import '../store/database.dart';
import '../store/planner_queries.dart';
import '../store/sync_queries.dart';
import 'sync_engine.dart';

final plannerServiceProvider = Provider<PlannerService>((ref) => PlannerService(ref.read(databaseProvider)));

/// Runs event extraction (spec 4.10) when a body arrives and, in the
/// background, over recent People mail that was never opened.
class PlannerService {
  PlannerService(this.db, {this.extractor = const EventExtractor()});
  final AppDatabase db;
  final EventExtractor extractor;

  /// Extracts from one stored message: the invitation part first, then the
  /// text of People mail. Feeds mail only contributes invitations.
  Future<int> extractFromMessage(int messageId) async {
    final m = await db.messageById(messageId);
    if (m == null) return 0;
    final found = <ExtractedEvent>[];
    if (m.icsText != null && m.icsText!.trim().isNotEmpty) {
      found.addAll(extractor.fromICalendar(m.icsText!));
    }
    if (m.classification != 'feeds' && !m.isFromMe) {
      final text = m.bodyText ?? '';
      if (text.trim().isNotEmpty) {
        found.addAll(extractor.fromText(text, reference: m.date ?? m.internalDate ?? DateTime.now(), subject: m.subject));
      }
    }
    return db.upsertExtracted(m, found);
  }

  /// Fetches bodies for recent People mail that was never opened and
  /// extracts from them. Bounded per pass so sync stays responsive.
  Future<int> recentPass(AccountSyncer syncer, {int limit = 30}) async {
    final pending = await db.messagesNeedingExtraction(limit: limit);
    var fetched = 0;
    for (final m in pending) {
      if (m.accountId != syncer.account.id) continue;
      try {
        await syncer.fetchBody(m.id); // fetchBody calls extractFromMessage
        fetched++;
      } catch (_) {
        break; // offline; try again next sync
      }
    }
    return fetched;
  }
}
