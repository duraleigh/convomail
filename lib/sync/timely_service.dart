import '../domain/timely_extractor.dart';
import '../store/classification_queries.dart';
import '../store/database.dart' hide ClassificationRule;
import '../store/sync_queries.dart';
import '../store/timely_queries.dart';
import 'classification_service.dart';

/// Reads mail for timely information (spec 4.21) and stores what it finds.
class TimelyService {
  TimelyService(this.db, this.classification, {this.extractor = const TimelyExtractor()});

  final AppDatabase db;
  final ClassificationService classification;
  final TimelyExtractor extractor;

  /// Whether a subject could be about a code, a delivery, travel or a bill.
  /// Other mail is not worth downloading for this.
  static final _subjectHint = RegExp(
    r'code|verif|otp|passcode|pin\b|sign.?in|log.?in|authenti|password|security|2fa|ship|deliver|track|order|arriv|package|parcel|flight|trip|itinerary|boarding|reservation|booking|confirm|check.?in|hotel|stay|train|ticket|rental|bill|statement|payment|due|invoice',
    caseSensitive: false,
  );

  static bool worthReading(Message m) => _subjectHint.hasMatch(m.subject) && m.size <= TimelyQueries.maxMessageSize;

  /// Reads one message whose body is stored, or marks it checked. Mail from
  /// people the user knows is left alone, so a friend's forwarded itinerary
  /// stays a friend's message. Returns how many items it yielded.
  Future<int> processMessage(int messageId) async {
    final m = await db.messageById(messageId);
    if (m == null || m.isFromMe || m.timelyCheckedAt != null) return 0;
    final contact = await (db.select(db.contacts)..where((c) => c.key.equals(m.fromContactKey))).getSingleOrNull();
    final facts0 = await db.senderFacts(m.fromContactKey);
    final known = contact != null && contact.classification != 'feeds' && (contact.inAddressBook || (facts0?.userHasWrittenTo ?? false));
    if (known) {
      await db.markTimelyChecked(m.id, found: false);
      return 0;
    }
    final received = m.date ?? m.internalDate ?? DateTime.now();
    final facts = extractor.extract(TimelyInput(
      // The email's own id where it has one, so a thing known only by its
      // email is the same thing on every device.
      messageKey: (m.messageId ?? '').isNotEmpty ? m.messageId! : '${m.accountId}:${m.folderId}:${m.uid}',
      received: received,
      subject: m.subject,
      fromName: contact?.shownName ?? m.fromName,
      fromAddress: m.fromAddress,
      text: m.bodyText ?? '',
      html: m.bodyHtml ?? '',
    ));
    await db.upsertTimely(m, facts, received);
    await db.markTimelyChecked(m.id, found: facts.isNotEmpty);
    // This is evidence about the sender: see SenderFacts.messagesWithTimely.
    if (facts.isNotEmpty) await classification.classifySenders([m.fromContactKey], log: false);
    return facts.length;
  }
}
