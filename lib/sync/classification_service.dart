import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/classifier.dart';
import '../domain/identity.dart';
import '../store/classification_queries.dart';
import '../store/database.dart' hide ClassificationRule;
import '../store/people_queries.dart';
import '../store/sync_queries.dart';

final classificationServiceProvider = Provider<ClassificationService>((ref) => ClassificationService(ref.read(databaseProvider)));

/// Applies the [Classifier] to the database: sender decisions, per-message
/// exceptions and categories, overrides, rules, and the event log
/// (spec 4.11). Called by the sync engine after headers land and by the UI
/// for corrections.
class ClassificationService {
  ClassificationService(this.db);
  final AppDatabase db;

  /// Bumped when the rules change enough that existing automatic decisions
  /// should be redone. Stored under [versionKey].
  static const classifierVersion = 2;
  static const versionKey = 'classifier.version';

  /// Redoes automatic sender decisions once after a classifier upgrade;
  /// manual moves stay. Returns true when a reset happened.
  Future<bool> upgradeIfNeeded() async {
    final stored = int.tryParse(await db.getSetting(versionKey) ?? '') ?? 1;
    if (stored >= classifierVersion) return false;
    await db.resetAutoClassifications();
    await db.putSetting(versionKey, '$classifierVersion');
    return true;
  }

  Future<Classifier> _classifier() async {
    final rules = await db.loadRules();
    final names = <String>{};
    for (final a in await db.allAccounts()) {
      names.addAll(_firstNames(a.displayName));
    }
    for (final i in await db.select(db.identities).get()) {
      names.addAll(_firstNames(i.name));
    }
    return Classifier(rules: rules, userFirstNames: names);
  }

  static Iterable<String> _firstNames(String display) {
    final t = display.trim();
    if (t.isEmpty) return const [];
    final first = t.split(RegExp(r'\s+')).first.toLowerCase().replaceAll(RegExp(r'[^a-z\-]'), '');
    return first.length < 2 ? const [] : [first];
  }

  /// Classifies the given senders and every message from them. Returns the
  /// number of senders whose bucket changed.
  Future<int> classifySenders(Iterable<String> contactKeys, {bool log = true}) async {
    final keys = contactKeys.where((k) => k != IdentityResolver.me).toSet();
    if (keys.isEmpty) return 0;
    final classifier = await _classifier();
    var changed = 0;
    for (final key in keys) {
      final before = await (db.select(db.contacts)..where((c) => c.key.equals(key))).getSingleOrNull();
      if (before == null) continue;
      final facts = await db.senderFacts(key);
      if (facts == null) continue;
      final decision = classifier.classifySender(facts);
      await db.writeSenderDecision(key, decision, keepSource: before.classificationSource == 'override');
      final senderDefault = (await (db.select(db.contacts)..where((c) => c.key.equals(key))).getSingle()).feedsCategory;
      await _classifyMessagesOf(key, decision.bucket, classifier, senderDefault: senderDefault);
      if (before.classification != decision.bucket.name) changed++;
      if (log && (before.classification != decision.bucket.name || before.classReasons.isEmpty)) {
        await db.logClassification(contactKey: key, decision: decision.bucket, category: decision.category, reasons: decision.reasons, source: decision.source);
      }
    }
    await db.refreshDirtyRows();
    return changed;
  }

  Future<void> _classifyMessagesOf(String key, Bucket senderBucket, Classifier classifier, {String? senderDefault}) async {
    for (final m in await db.messagesFromSender(key)) {
      await _classifyMessage(m, senderBucket, classifier, senderDefault: senderDefault);
    }
  }

  Future<void> _classifyMessage(Message m, Bucket senderBucket, Classifier classifier, {String? senderDefault}) async {
    final facts = MessageFacts(
      from: m.fromAddress,
      fromName: m.fromName,
      subject: m.subject,
      snippet: m.snippet,
      signals: BulkSignals.decode(m.bulkSignals),
      isReplyToMine: await db.isReplyToMine(m.inReplyTo),
      providerCategory: m.providerCategory,
    );
    var bucket = m.isFromMe ? Bucket.people : senderBucket;
    if (bucket == Bucket.feeds && classifier.isPersonalException(facts)) bucket = Bucket.people;
    String? category;
    if (bucket == Bucket.feeds) {
      final inferred = classifier.messageCategory(facts, senderDefault: senderDefault);
      category = inferred == senderDefault ? m.feedsCategory : inferred;
      // A category the user set on this message is kept.
      if (m.feedsCategory != null && m.feedsCategory != senderDefault) category = m.feedsCategory;
    }
    if (m.classification != bucket.name || m.feedsCategory != category) {
      await db.writeMessageClassification(m.id, bucket, category: category);
      if (bucket == Bucket.people && senderBucket == Bucket.feeds && !m.isFromMe) {
        await db.logClassification(messageId: m.id, contactKey: m.fromContactKey, decision: bucket, reasons: const ['personal exception'], source: 'auto');
      }
    }
  }

  /// After a body arrives the salutation is known; re-check that message.
  Future<void> reclassifyMessage(int messageId) async {
    final m = await db.messageById(messageId);
    if (m == null || m.isFromMe) return;
    final c = await (db.select(db.contacts)..where((x) => x.key.equals(m.fromContactKey))).getSingleOrNull();
    if (c == null || c.classification != 'feeds') return;
    await _classifyMessage(m, Bucket.feeds, await _classifier(), senderDefault: c.feedsCategory);
    await db.refreshDirtyRows();
  }

  /// Messages replying to any of [messageIds] (mail the user sent) are
  /// re-evaluated so the reply-to-me exception applies.
  Future<void> reclassifyRepliesTo(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final replies = await (db.select(db.messages)..where((m) => m.inReplyTo.isIn(messageIds) & m.isFromMe.equals(false))).get();
    if (replies.isEmpty) return;
    final classifier = await _classifier();
    for (final m in replies) {
      final c = await (db.select(db.contacts)..where((x) => x.key.equals(m.fromContactKey))).getSingleOrNull();
      if (c == null) continue;
      await _classifyMessage(m, c.classification == 'feeds' ? Bucket.feeds : Bucket.people, classifier, senderDefault: c.feedsCategory);
    }
    await db.refreshDirtyRows();
  }

  /// Senders never classified yet, in batches (startup backfill).
  Future<int> classifyPending({int limit = 200}) async {
    final pending = await db.unclassifiedSenders(limit: limit);
    if (pending.isEmpty) return 0;
    await classifySenders(pending, log: false);
    return pending.length;
  }

  // ---- user actions ------------------------------------------------------------

  /// Permanent manual move (spec 4.11). `null` clears the override.
  Future<void> moveSender(String contactKey, Bucket? bucket) async {
    await db.setSenderOverride(contactKey, bucket);
    await classifySenders([contactKey], log: false);
    await db.logClassification(contactKey: contactKey, decision: bucket ?? Bucket.people, reasons: [bucket == null ? 'override cleared' : 'manual move'], source: 'override');
  }

  Future<void> setCountsTowardUnread(String contactKey, bool on) async {
    await db.setCountsTowardUnread(contactKey, on);
    await db.markRowsDirty(['c:$contactKey']);
    await db.refreshDirtyRows();
  }

  Future<void> setSenderCategory(String contactKey, String? category) async {
    await db.setSenderCategory(contactKey, category);
    await db.logClassification(contactKey: contactKey, decision: Bucket.feeds, category: category, reasons: const ['sender category set'], source: 'correction');
  }

  /// "Just this once": fix one message without a rule.
  Future<void> setMessageCategory(int messageId, String? category) async {
    final m = await db.messageById(messageId);
    if (m == null) return;
    await db.setMessageCategory(messageId, category);
    await db.logClassification(messageId: messageId, contactKey: m.fromContactKey, decision: Bucket.feeds, category: category, reasons: const ['message category set'], source: 'correction');
  }

  /// "Just this once" bucket change for a single message.
  Future<void> setMessageBucket(int messageId, Bucket bucket) async {
    final m = await db.messageById(messageId);
    if (m == null) return;
    await db.writeMessageClassification(messageId, bucket, category: bucket == Bucket.feeds ? m.feedsCategory : null);
    await db.logClassification(messageId: messageId, contactKey: m.fromContactKey, decision: bucket, reasons: const ['just this once'], source: 'correction');
    await db.refreshDirtyRows();
  }

  /// What the app would propose for a correction on [message].
  Future<ClassificationRule> proposeRule(Message message, {Bucket? bucket, String? category}) async {
    return Classifier.proposeRule(
      m: MessageFacts(from: message.fromAddress, fromName: message.fromName, subject: message.subject, signals: BulkSignals.decode(message.bulkSignals)),
      bucket: bucket,
      category: category,
    );
  }

  /// Saves an accepted rule and, when [retroactive], re-classifies the
  /// senders and messages it matches.
  Future<int> acceptRule(ClassificationRule rule, {bool retroactive = true}) async {
    final id = await db.insertRule(rule);
    await db.logClassification(contactKey: rule.pattern, decision: rule.bucket ?? Bucket.feeds, category: rule.category, reasons: [rule.describe()], source: 'rule');
    if (retroactive) await applyRule(rule.id == null ? ClassificationRule(id: id, field: rule.field, pattern: rule.pattern, bucket: rule.bucket, category: rule.category) : rule);
    return id;
  }

  Future<void> applyRule(ClassificationRule rule) async {
    final senders = await _sendersMatching(rule);
    if (senders.isNotEmpty) await classifySenders(senders, log: false);
    if (rule.field == 'subject' && rule.category != null) {
      // Subject rules are message-level: tag matching Feeds messages.
      final classifier = await _classifier();
      final rows = await (db.select(db.messages)..where((m) => m.classification.equals('feeds'))).get();
      for (final m in rows) {
        final facts = MessageFacts(from: m.fromAddress, subject: m.subject, signals: BulkSignals.decode(m.bulkSignals));
        if (rule.matchesMessage(facts)) {
          final c = await (db.select(db.contacts)..where((x) => x.key.equals(m.fromContactKey))).getSingleOrNull();
          final cat = classifier.messageCategory(facts, senderDefault: c?.feedsCategory);
          await db.setMessageCategory(m.id, cat == c?.feedsCategory ? null : cat);
        }
      }
    }
  }

  Future<void> deleteRule(int id) async {
    final rules = await db.loadRules();
    final rule = rules.where((r) => r.id == id).firstOrNull;
    await db.deleteRule(id);
    if (rule != null) {
      final senders = await _sendersMatching(rule);
      if (senders.isNotEmpty) await classifySenders(senders, log: false);
    }
  }

  Future<Set<String>> _sendersMatching(ClassificationRule rule) async {
    final out = <String>{};
    switch (rule.field) {
      case 'sender':
        final r = (await db.loadIdentityResolver()).resolve(rule.pattern);
        out.add(r.contactKey);
      case 'domain':
        final rows = await (db.select(db.contactAddresses)..where((a) => a.address.like('%@${rule.pattern}') | a.address.like('%.${rule.pattern}'))).get();
        out.addAll(rows.map((r) => r.contactKey));
      case 'listId':
        final rows = await (db.selectOnly(db.messages, distinct: true)
              ..addColumns([db.messages.fromContactKey])
              ..where(db.messages.bulkSignals.like('%;${rule.pattern}')))
            .get();
        out.addAll(rows.map((r) => r.read(db.messages.fromContactKey)!));
      case 'subject':
        final rows = await (db.selectOnly(db.messages, distinct: true)
              ..addColumns([db.messages.fromContactKey])
              ..where(db.messages.subject.lower().like('%${rule.pattern.split('|').first.trim()}%')))
            .get();
        if (rule.bucket != null) out.addAll(rows.map((r) => r.read(db.messages.fromContactKey)!));
    }
    return out;
  }
}
