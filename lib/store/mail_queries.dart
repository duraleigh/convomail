// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:drift/drift.dart';

import '../app/time_format.dart';
import '../domain/email_pile.dart';
import '../domain/piles.dart';
import 'database.dart';
import 'helper_queries.dart';

/// What the assistant said about one email.
class Reading {
  const Reading({required String line, required this.focus, required String ask, this.due, List<String> why = const [], this.answered = false, this.know = false, this.thing = '', this.draft = ''})
      : _line = line,
        _ask = ask,
        _why = why;

  // The assistant's own words. Any clock time in them is shown the way the
  // user reads the clock (12-hour or 24-hour), worked out when read.
  final String _line;
  final String _ask;
  final List<String> _why;

  /// One sentence saying what the email is.
  String get line => timesInText(_line);

  /// Whether the assistant thinks it needs the user.
  final bool focus;

  /// What is asked, as a short instruction; empty when nothing is.
  String get ask => timesInText(_ask);

  /// When it is needed by, if the email says.
  final DateTime? due;

  /// Up to three plain reasons.
  List<String> get why => [for (final w in _why) timesInText(w)];

  /// The user has answered the email since.
  final bool answered;

  /// Good to know though nothing is asked of the user.
  final bool know;

  /// A few words naming what the email is about ("Amazon hard case").
  final String thing;

  /// An email written for the user to look over and send. There is only
  /// ever one kind: asking whoever booked travel for them for the details
  /// that are missing. Nothing is sent unless the user sends it.
  final String draft;
}

/// One email as the Focus, Feed and Noise lists show it: who, what, when,
/// where it sits, and the assistant's reading when there is one. It carries
/// no email text.
class MailItem {
  const MailItem({
    required this.id,
    required this.accountId,
    required this.messageId,
    required this.threadKey,
    required this.rowKey,
    required this.senderKey,
    required this.senderName,
    required this.subject,
    required this.at,
    required this.unread,
    required this.person,
    this.tag,
    this.gmailTab,
    this.pile,
    this.by,
    this.reading,
    this.doneAt,
    this.senderWhy = '',
    this.focusFix,
    this.senderChosen,
    this.countsTowardUnread = false,
    this.laterUntil,
    this.dismissed = false,
  });

  final int id;
  final int accountId;
  final String? messageId;
  final String? threadKey;
  final String rowKey;
  final String senderKey;
  final String senderName;
  final String subject;
  final DateTime at;
  final bool unread;

  /// From a person (Chats) rather than a company or a list.
  final bool person;
  final String? tag;
  final String? gmailTab;

  /// Feed or Noise, for mail that is not from a person.
  final FeedsPile? pile;
  final PileBy? by;
  final Reading? reading;
  final DateTime? doneAt;

  /// Why the sender is treated as a person or not, in the app's own words.
  final String senderWhy;

  /// The user's own word: 'yes' (needs me), 'no' (Not Focus), or null.
  final String? focusFix;

  /// The user's standing choice for the sender, if any: Feed or Noise.
  final FeedsPile? senderChosen;

  /// The user asked for this sender's mail to count as unread on the app's icon.
  final bool countsTowardUnread;

  /// "Later": put off by the user until this time.
  final DateTime? laterUntil;

  /// Dismissed from Today's cards: off them (and out of Focus), not done.
  final bool dismissed;

  /// Whether this email needs the user: they said so, or the assistant did
  /// and the user has not answered it or said otherwise.
  bool get needsYou => !dismissed && doneAt == null && (focusFix == 'yes' || (focusFix != 'no' && reading != null && reading!.focus && !reading!.answered && (person || pile != FeedsPile.noise)));

  /// Whether the user has put this email off and its time has not come yet.
  bool putOffAt(DateTime now) => laterUntil != null && laterUntil!.isAfter(now);

  /// Whether this email is in Focus right now: it needs the user and is
  /// not put off until later.
  bool get inFocus => needsYou && !putOffAt(DateTime.now());

  /// The second line of a row: the assistant's sentence, else the subject.
  String get line => (reading?.line.isNotEmpty ?? false) ? reading!.line : (subject.isEmpty ? '(no subject)' : subject);

  /// What to do, for a Focus row.
  String get ask => (reading?.ask.isNotEmpty ?? false) ? reading!.ask : line;
}

extension MailQueries on AppDatabase {
  static const _select = '''
    SELECT m.id, m.account_id, m.message_id, m.thread_key, m.subject, m.is_seen, m.classification, m.provider_category, m.done_at,
           m.from_contact_key, m.from_name, m.from_address, m.pile_fix, m.focus_fix, m.later_until,
           COALESCE(m.date, m.internal_date) AS ts,
           COALESCE(NULLIF(c.user_label, ''), NULLIF(c.display_name, ''), NULLIF(m.from_name, ''), m.from_address) AS who,
           c.feeds_pile AS chosen, COALESCE(m.feeds_category, c.feeds_category) AS tag, c.class_reasons AS sender_why, c.counts_toward_unread AS counts,
           v.pile AS hpile,
           r.message_id AS rid, r.line, r.focus, r.ask, r.due, r.why, r.answered, r.know, r.thing, r.draft,
           (SELECT MIN(a.row_key) FROM message_row_assignments a WHERE a.message_id = m.id) AS row_key
    FROM messages m
    JOIN folders f ON f.id = m.folder_id AND f.role = 'inbox'
    LEFT JOIN contacts c ON c.key = m.from_contact_key
    LEFT JOIN helper_verdicts v ON v.message_id = m.message_id
    LEFT JOIN helper_readings r ON r.message_id = m.message_id
    WHERE m.is_deleted = 0 AND m.is_from_me = 0 AND m.is_draft = 0
  ''';

  MailItem _mailItem(QueryRow r, {required bool assistantOn, Set<String> off = const {}}) {
    DateTime? t(String k) {
      final v = r.readNullable<int>(k);
      return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }

    final person = r.read<String>('classification') != 'feeds';
    final hasReading = r.readNullable<String>('rid') != null && assistantOn;
    Reading? reading;
    if (hasReading) {
      var why = const <String>[];
      try {
        final w = jsonDecode(r.readNullable<String>('why') ?? '[]');
        if (w is List) why = [for (final x in w) if (x is String) x];
      } catch (_) {}
      reading = Reading(
        line: r.readNullable<String>('line') ?? '',
        focus: r.readNullable<bool>('focus') ?? false,
        ask: r.readNullable<String>('ask') ?? '',
        due: t('due'),
        why: why,
        answered: r.readNullable<bool>('answered') ?? false,
        know: r.readNullable<bool>('know') ?? false,
        thing: r.readNullable<String>('thing') ?? '',
        draft: r.readNullable<String>('draft') ?? '',
      );
    }
    final tag = r.readNullable<String>('tag');
    final tab = r.readNullable<String>('provider_category');
    final placed = person
        ? null
        : emailPile(
            fix: r.readNullable<String>('pile_fix'),
            senderChosen: r.readNullable<String>('chosen'),
            tag: tag,
            gmailTab: tab,
            helper: r.readNullable<String>('hpile'),
            readByAssistant: hasReading,
          );
    final key = r.read<String>('from_contact_key');
    return MailItem(
      id: r.read<int>('id'),
      accountId: r.read<int>('account_id'),
      messageId: r.readNullable<String>('message_id'),
      threadKey: r.readNullable<String>('thread_key'),
      rowKey: r.readNullable<String>('row_key') ?? 'c:$key',
      senderKey: key,
      senderName: r.readNullable<String>('who') ?? key,
      subject: r.read<String>('subject'),
      at: t('ts') ?? DateTime.fromMillisecondsSinceEpoch(0),
      unread: !r.read<bool>('is_seen'),
      person: person,
      tag: person ? null : tag,
      gmailTab: tab,
      pile: placed?.pile,
      by: placed?.by,
      reading: reading,
      doneAt: t('done_at'),
      senderWhy: r.readNullable<String>('sender_why') ?? '',
      focusFix: r.readNullable<String>('focus_fix'),
      laterUntil: t('later_until'),
      dismissed: off.contains(r.readNullable<String>('message_id') ?? ''),
      senderChosen: FeedsPile.parse(r.readNullable<String>('chosen')),
      countsTowardUnread: r.readNullable<bool>('counts') ?? false,
    );
  }

  /// Whether the assistant's readings are shown: this device follows a
  /// helper and the assistant is on there. Switched off, the sentences and
  /// Focus go quiet and the app is as it was without an assistant.
  Future<bool> readingsShown() async => await helperConnected() && await getSetting('helper.assistantOn') == '1';

  Stream<List<MailItem>> _watchMail(String extra, List<Variable> variables, {int? accountId, int limit = 5000}) {
    return customSelect(
      '$_select ${accountId == null ? '' : 'AND m.account_id = ?'} $extra ORDER BY ts DESC, m.id DESC LIMIT $limit',
      variables: [if (accountId != null) Variable.withInt(accountId), ...variables],
      readsFrom: {messages, folders, contacts, helperVerdicts, helperReadings, messageRowAssignments, settings, helperState},
    ).watch().asyncMap((rows) async {
      final on = await readingsShown();
      final off = await dismissedIds();
      return [for (final r in rows) _mailItem(r, assistantOn: on, off: off)];
    });
  }

  /// Every inbox email that is not from a person, newest first, each with
  /// its own place (Feed or Noise) and the assistant's line when it has one.
  Stream<List<MailItem>> watchOtherMail({int? accountId}) => _watchMail("AND m.classification = 'feeds'", const [], accountId: accountId);

  /// The emails that need the user: the assistant said so, and the user has
  /// not answered, marked it done, or said "Not Focus". Newest first.
  Stream<List<MailItem>> watchFocus({int? accountId}) => _watchMail(
        "AND m.done_at IS NULL AND (m.focus_fix = 'yes' OR (r.focus = 1 AND r.answered = 0 AND m.is_answered = 0 AND COALESCE(m.focus_fix, '') <> 'no'))",
        const [],
        accountId: accountId,
        limit: 500,
      ).map((items) => [
            for (final i in items)
              if (i.inFocus) i,
          ]);

  /// "Good to know" on Today: emails since [since] that the assistant says
  /// matter to the user though nothing is asked (an answer they were
  /// waiting for, a delivery that arrived, a notice about their accounts).
  /// Not what needs them, not Noise, not what is done. Newest first; of
  /// several from one sender about the same thing, only the newest (a
  /// delivery that has arrived replaces "out for delivery").
  Stream<List<MailItem>> watchGoodToKnow({int? accountId, required DateTime since}) => _watchMail(
        // One put off until later comes back when its time is up, whatever day it came.
        'AND r.message_id IS NOT NULL AND (COALESCE(m.date, m.internal_date) >= ? OR m.later_until IS NOT NULL)',
        [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
        accountId: accountId,
        limit: 80,
      ).map((items) {
        final seen = <String>{};
        final now = DateTime.now();
        final out = <MailItem>[];
        for (final i in items) {
          final r = i.reading;
          if (r == null) continue;
          // The newest word on a thing stands for it, shown or not: taking
          // it off the card never brings an older one back in its place.
          final newest = seen.add(r.thing.isEmpty ? 'id:${i.id}' : '${i.senderKey}|${r.thing.toLowerCase()}');
          if (newest && r.know && i.doneAt == null && !i.dismissed && !i.needsYou && !i.putOffAt(now) && (i.person || i.pile != FeedsPile.noise)) out.add(i);
        }
        return out;
      });

  /// Focus emails the user put off until later, soonest back first.
  Stream<List<MailItem>> watchFocusLater({int? accountId}) => _watchMail('AND m.later_until IS NOT NULL AND m.done_at IS NULL', const [], accountId: accountId, limit: 200).map((items) {
        final now = DateTime.now();
        return [
          for (final i in items)
            if (!i.dismissed && (i.needsYou || (i.reading?.know ?? false)) && i.putOffAt(now)) i,
        ]..sort((a, b) => a.laterUntil!.compareTo(b.laterUntil!));
      });

  /// "Later" on a Focus email: it leaves Focus until [until] and then comes
  /// back by itself. Null brings it back now. Told to the helper too, so
  /// every device agrees.
  Future<void> setLaterUntil(int id, DateTime? until) async {
    final m = await (select(messages)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (m == null) return;
    await (update(messages)..where((t) => t.id.equals(id))).write(MessagesCompanion(laterUntil: Value(until)));
    final mid = m.messageId;
    if (mid != null && mid.isNotEmpty) await noteForHelper('msgfix', mid, {'later': until == null ? null : until.millisecondsSinceEpoch ~/ 1000});
  }

  /// Focus emails marked done today, newest first.
  Stream<List<MailItem>> watchFocusDoneToday({int? accountId, DateTime? day}) {
    final d = day ?? DateTime.now();
    final start = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;
    return _watchMail("AND (r.focus = 1 OR m.focus_fix = 'yes') AND m.done_at IS NOT NULL AND m.done_at >= ?", [Variable.withInt(start)], accountId: accountId, limit: 100);
  }

  /// One email as the lists see it, for the "?" on an open email.
  Stream<MailItem?> watchMailItem(int id) => customSelect(
        '${_select.replaceFirst("JOIN folders f ON f.id = m.folder_id AND f.role = 'inbox'", 'JOIN folders f ON f.id = m.folder_id').replaceFirst('WHERE m.is_deleted = 0 AND m.is_from_me = 0 AND m.is_draft = 0', 'WHERE m.id = ?')} LIMIT 1',
        variables: [Variable.withInt(id)],
        readsFrom: {messages, folders, contacts, helperVerdicts, helperReadings, messageRowAssignments, settings, helperState},
      ).watch().asyncMap((rows) async => rows.isEmpty ? null : _mailItem(rows.first, assistantOn: await readingsShown(), off: await dismissedIds()));

  /// The user's own word on one email: true puts it in Focus, false is
  /// "Not Focus", null leaves it to the assistant again. Told to the helper
  /// too, so every device agrees.
  Future<void> setFocusFix(int id, bool? needsMe) async {
    final m = await (select(messages)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (m == null) return;
    await (update(messages)..where((t) => t.id.equals(id))).write(MessagesCompanion(focusFix: Value(needsMe == null ? null : (needsMe ? 'yes' : 'no'))));
    final mid = m.messageId;
    if (mid != null && mid.isNotEmpty) await noteForHelper('msgfix', mid, {'focus': needsMe});
  }

  /// "Does not belong here" on Good to know ([worth] false), or that taken
  /// back (true). This one email leaves the card; nothing else from its
  /// sender is touched. The helper is told, and the assistant is shown it
  /// from then on, to learn what kind of thing does not belong there.
  Future<void> setWorthKnowing(int id, bool worth) async {
    final m = await (select(messages)..where((t) => t.id.equals(id))).getSingleOrNull();
    final mid = m?.messageId;
    if (m == null || mid == null || mid.isEmpty) return;
    await (update(helperReadings)..where((r) => r.messageId.equals(mid))).write(HelperReadingsCompanion(know: Value(worth)));
    await noteForHelper('msgfix', mid, {'know': worth});
  }

  /// "Does not belong here" on Waiting on ([waiting] false), or that taken
  /// back (true), for an email the user sent.
  Future<void> setWaitingOn(int id, bool waiting) async {
    final m = await (select(messages)..where((t) => t.id.equals(id))).getSingleOrNull();
    final mid = m?.messageId;
    if (m == null || mid == null || mid.isEmpty) return;
    await (update(helperReadings)..where((r) => r.messageId.equals(mid) & r.sent.equals(true))).write(HelperReadingsCompanion(asks: Value(waiting)));
    await noteForHelper('msgfix', mid, {'asks': waiting});
  }

  /// Moves one email between Feed and Noise by hand ([pile] null takes the
  /// move back). The user's word wins over every rule and the assistant.
  Future<void> setEmailPile(int id, FeedsPile? pile) async {
    final m = await (select(messages)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (m == null) return;
    await (update(messages)..where((t) => t.id.equals(id))).write(MessagesCompanion(pileFix: Value(pile?.name)));
    final mid = m.messageId;
    if (mid != null && mid.isNotEmpty) await noteForHelper('msgfix', mid, {'pile': pile?.name});
  }
}
