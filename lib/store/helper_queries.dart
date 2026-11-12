import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/classifier.dart';
import '../domain/identity.dart';
import 'classification_queries.dart';
import 'database.dart' hide ClassificationRule;
import 'group_queries.dart';
import 'merge_queries.dart';
import 'people_queries.dart';

/// The setting that holds quiet hours for alerts on phones, the same on
/// every device: `{"on": bool, "from": "22:00", "to": "07:00"}`.
const kQuietHours = 'alerts.quiet';

/// The setting that says how clock times are shown, the same on every
/// device: '24' for 15:00, anything else for 3:00 PM.
const kClockFormat = 'time.format';

/// The setting that lists what the user said does not belong under FYI,
/// the same on every device: a JSON list of "kind|sender".
const kFyiOff = 'fyi.off';

/// One change as it goes up to the helper: set ([data]) or gone ([deleted]),
/// or an action ([op]).
class HelperEntry {
  const HelperEntry.set(this.kind, this.k, Map<String, Object?> this.data)
      : deleted = false,
        op = null;
  const HelperEntry.gone(this.kind, this.k)
      : data = null,
        deleted = true,
        op = null;
  const HelperEntry.action(Map<String, Object?> this.op)
      : kind = 'op',
        k = '',
        data = null,
        deleted = false;

  final String kind;
  final String k;
  final Map<String, Object?>? data;
  final bool deleted;
  final Map<String, Object?>? op;

  Map<String, Object?> toJson() => op ?? (deleted ? {'kind': kind, 'k': k, 'deleted': true} : {'kind': kind, 'k': k, 'data': data});
}

int? _secs(DateTime? t) => t == null ? null : t.millisecondsSinceEpoch ~/ 1000;
/// The setting that holds the sentence for the top of Today, as the
/// helper last sent it.
const kDaySentence = 'helper.day';

/// The sentence the user dismissed, by when it was written (seconds). It
/// stays away, on every device, until the assistant writes a new one.
const kDayDismissed = 'helper.dayDismissed';

DateTime? _time(Object? secs) => secs is num && secs > 0 ? DateTime.fromMillisecondsSinceEpoch(secs.toInt() * 1000) : null;

/// The device's side of keeping in step with the helper: what waits to go
/// up, how each kind of thing is put into words for the helper, and how
/// what comes down is written here.
extension HelperQueries on AppDatabase {
  // ---- following a helper or not ---------------------------------------------

  Future<bool> helperConnected() async {
    final r = await customSelect('SELECT connected FROM helper_state WHERE id = 1').getSingleOrNull();
    return r != null && r.read<int>('connected') == 1;
  }

  /// Turning it off also forgets what the helper decided and what was
  /// waiting to go up: from then on this device sorts by itself again.
  Future<void> setHelperConnected(bool on) => transaction(() async {
        await customStatement('INSERT OR IGNORE INTO helper_state (id, connected, applying) VALUES (1, 0, 0)');
        await customStatement('UPDATE helper_state SET connected = ?, applying = 0 WHERE id = 1', [on ? 1 : 0]);
        if (!on) {
          await delete(helperOutbox).go();
          await delete(helperSenders).go();
          await delete(helperMarks).go();
          await delete(helperVerdicts).go();
        }
      });

  /// Runs [work] as a change that came from the helper: nothing it writes
  /// is noted for sending back.
  Future<T> applyingFromHelper<T>(Future<T> Function() work) => transaction(() async {
        await customStatement('UPDATE helper_state SET applying = 1 WHERE id = 1');
        try {
          return await work();
        } finally {
          await customStatement('UPDATE helper_state SET applying = 0 WHERE id = 1');
        }
      });

  // ---- what waits to go up -----------------------------------------------------

  Future<List<HelperOutboxData>> helperOutboxBatch({int limit = 300}) => (select(helperOutbox)
        ..orderBy([(o) => OrderingTerm.asc(o.id)])
        ..limit(limit))
      .get();

  Future<int> helperOutboxCount() async => (await customSelect('SELECT COUNT(*) AS n FROM helper_outbox').getSingle()).read<int>('n');

  Stream<int> watchHelperOutboxCount() => customSelect('SELECT COUNT(*) AS n FROM helper_outbox', readsFrom: {helperOutbox}).watchSingle().map((r) => r.read<int>('n'));

  Future<void> clearHelperOutbox(Iterable<int> ids) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 400) {
      await (delete(helperOutbox)..where((o) => o.id.isIn(list.sublist(i, i + 400 > list.length ? list.length : i + 400)))).go();
    }
  }

  /// Dismisses the sentence at the top of Today that was written at [at]:
  /// it goes away here and on every other device, and comes back only when
  /// the assistant writes a new one. With [at] null, brings it back.
  Future<void> dismissDaySentence(DateTime? at) async {
    final secs = at == null ? 0 : at.millisecondsSinceEpoch ~/ 1000;
    await putSetting(kDayDismissed, at == null ? '' : '$secs');
    await noteForHelper('pref', 'day', {'dismissed': secs});
  }

  /// Notes a change that is not simply a row's state: a fix to one email,
  /// or a tag renamed or removed. Nothing is noted when no helper is followed.
  Future<void> noteForHelper(String kind, String k, Map<String, Object?> data) async {
    if (!await helperConnected()) return;
    await transaction(() async {
      // A newer word on the same thing replaces an older one still waiting
      // to go up, so the helper always ends on the user's last word.
      final fields = data.keys.toSet();
      for (final r in await customSelect('SELECT id, data FROM helper_outbox WHERE kind = ? AND k = ?', variables: [Variable.withString(kind), Variable.withString(k)]).get()) {
        Object? old;
        try {
          old = jsonDecode(r.read<String>('data'));
        } catch (_) {}
        if (old is Map && old.keys.toSet().containsAll(fields) && old.length == fields.length) {
          await customStatement('DELETE FROM helper_outbox WHERE id = ?', [r.read<int>('id')]);
        }
      }
      await customStatement('INSERT OR IGNORE INTO helper_outbox (kind, k, data) VALUES (?, ?, ?)', [kind, k, jsonEncode(data)]);
    });
  }

  /// Notes everything the helper keeps, for the first sending-up. Senders go
  /// separately, with the facts behind them (see [senderSeed]).
  Future<void> noteEverythingForHelper() => transaction(() async {
        Future<void> all(String kind, String sql) => customStatement("INSERT OR IGNORE INTO helper_outbox (kind, k, data) SELECT '$kind', $sql");
        await customStatement("INSERT OR IGNORE INTO helper_outbox (kind, k, data) VALUES ('me', '*', '')");
        await all('tag', "name, '' FROM feeds_categories");
        await all('rule', "uid, '' FROM classification_rules WHERE uid IS NOT NULL");
        await all('addr', "address, '' FROM contact_addresses WHERE address <> contact_key");
        await all('book', "key, '' FROM contacts WHERE in_address_book = 1 AND is_me = 0");
        await all('rowpref', "row_key, '' FROM row_prefs");
        await all('reminder', "uid, '' FROM reminders WHERE uid IS NOT NULL");
        await all('done', "message_id, '' FROM messages WHERE done_at IS NOT NULL AND message_id IS NOT NULL AND message_id <> '' GROUP BY message_id");
      });

  /// Puts one waiting change into the helper's words, reading the row as it
  /// stands now. A row that is gone becomes a removal.
  Future<List<HelperEntry>> helperEntriesFor(HelperOutboxData o) async {
    if (o.kind == 'op') return [HelperEntry.action((jsonDecode(o.data) as Map).cast<String, Object?>())];
    if (o.data.isNotEmpty) return [HelperEntry.set(o.kind, o.k, (jsonDecode(o.data) as Map).cast<String, Object?>())];
    switch (o.kind) {
      case 'sender':
        final c = await (select(contacts)..where((c) => c.key.equals(o.k))).getSingleOrNull();
        return c == null || c.isMe ? const [] : [HelperEntry.set('sender', o.k, senderItem(c))];
      case 'rule':
        final r = await (select(classificationRules)..where((r) => r.uid.equals(o.k))).getSingleOrNull();
        return [r == null ? HelperEntry.gone('rule', o.k) : HelperEntry.set('rule', o.k, {'uid': o.k, 'field': r.field, 'pattern': r.pattern, 'bucket': r.bucket, 'category': r.category, 'at': _secs(r.createdAt)})];
      case 'tag':
        final t = await (select(feedsCategoryRows)..where((t) => t.name.equals(o.k))).getSingleOrNull();
        return [t == null ? HelperEntry.gone('tag', o.k) : HelperEntry.set('tag', o.k, {'pos': t.sortOrder, 'builtin': t.builtin})];
      case 'rowpref':
        final p = await (select(rowPrefs)..where((p) => p.rowKey.equals(o.k))).getSingleOrNull();
        return [p == null ? HelperEntry.gone('rowpref', o.k) : HelperEntry.set('rowpref', o.k, {'snoozed': _secs(p.snoozedUntil), 'pinned': p.pinned, 'muted': p.muted, 'resurfaced': _secs(p.resurfacedAt)})];
      case 'reminder':
        final r = await (select(reminders)..where((r) => r.uid.equals(o.k))).getSingleOrNull();
        if (r == null) return [HelperEntry.gone('reminder', o.k)];
        final m = r.messageId == null ? null : await (select(messages)..where((m) => m.id.equals(r.messageId!))).getSingleOrNull();
        return [
          HelperEntry.set('reminder', o.k, {'title': r.title, 'due': _secs(r.dueAt), 'done': r.done, 'fired': _secs(r.firedAt), 'mid': m?.messageId, 'thread': r.threadKey, 'row': r.rowKey, 'created': _secs(r.createdAt)}),
        ];
      case 'done':
        final r = await customSelect('SELECT MAX(done_at) AS at FROM messages WHERE message_id = ? AND done_at IS NOT NULL', variables: [Variable.withString(o.k)]).getSingle();
        final at = r.readNullable<int>('at');
        return [at == null ? HelperEntry.gone('done', o.k) : HelperEntry.set('done', o.k, {'at': at})];
      case 'addr':
        final a = await (select(contactAddresses)..where((a) => a.address.equals(o.k))).getSingleOrNull();
        return [a == null || a.contactKey == a.address ? HelperEntry.gone('addr', o.k) : HelperEntry.set('addr', o.k, {'key': a.contactKey})];
      case 'book':
        final c = await (select(contacts)..where((c) => c.key.equals(o.k))).getSingleOrNull();
        return [c != null && c.inAddressBook ? HelperEntry.set('book', o.k, const {'in': true}) : HelperEntry.gone('book', o.k)];
      case 'me':
        // Every address the user sends from, and the first names mail greets them by.
        final names = <String>{};
        final out = <HelperEntry>[];
        final seen = <String>{};
        for (final a in await select(accounts).get()) {
          names.addAll(_firstNames(a.displayName));
          if (seen.add(normalizeAddress(a.email))) out.add(HelperEntry.set('me', normalizeAddress(a.email), {'name': a.displayName}));
        }
        for (final i in await select(identities).get()) {
          names.addAll(_firstNames(i.name));
          if (seen.add(normalizeAddress(i.email))) out.add(HelperEntry.set('me', normalizeAddress(i.email), {'name': i.name}));
        }
        out.add(HelperEntry.set('names', 'user', {'first': names.toList()..sort()}));
        return out;
      default:
        return const [];
    }
  }

  static Iterable<String> _firstNames(String display) {
    final t = display.trim();
    if (t.isEmpty) return const [];
    final first = t.split(RegExp(r'\s+')).first.toLowerCase().replaceAll(RegExp(r'[^a-z\-]'), '');
    return first.length < 2 ? const [] : [first];
  }

  /// A sender's row in the helper's words.
  Map<String, Object?> senderItem(Contact c) => {
        'cls': c.classification,
        'src': c.classificationSource,
        'cat': c.feedsCategory,
        'pile': c.feedsPile,
        'counts': c.countsTowardUnread,
        'label': c.userLabel,
        'subtitle': c.userSubtitle,
        'name': c.displayName,
        'reasons': c.classReasons,
      };

  // ---- the first sending-up of senders -------------------------------------------

  /// Every sender this device has decided, most recently seen first.
  Future<List<String>> senderKeysForSeed() async {
    final rows = await customSelect("SELECT key FROM contacts WHERE is_me = 0 AND class_reasons <> '' ORDER BY last_seen_at DESC").get();
    return [for (final r in rows) r.read<String>('key')];
  }

  /// A sender as it goes up the first time: its row, and the facts behind
  /// the decision (counts from mail the helper will never read).
  Future<Map<String, Object?>?> senderSeed(String key) async {
    final c = await (select(contacts)..where((c) => c.key.equals(key))).getSingleOrNull();
    final f = await senderFacts(key);
    if (c == null || f == null) return null;
    final mail = (await rowMailByCategory(rowKey: 'c:$key'))['c:$key'] ?? const {};
    return {
      'k': key,
      'item': senderItem(c),
      'facts': {
        'address': f.address,
        'otherAddresses': f.otherAddresses,
        'messagesReceived': f.messagesReceived,
        'messagesSentTo': f.messagesSentTo,
        'repliesToAutomated': f.repliesToAutomated,
        'recipientNames': f.recipientNames,
        'messagesWithTimely': f.messagesWithTimely,
        'name': f.name,
        'userHasWrittenTo': f.userHasWrittenTo,
        'messagesWithBulkHeaders': f.messagesWithBulkHeaders,
        'messagesWithKnownSignals': f.messagesWithKnownSignals,
        'listIds': f.listIds.toList(),
        'providerCategories': f.providerCategories,
        'subjects': f.subjects,
        'mail': {for (final e in mail.entries) e.key ?? '': {'total': e.value.total, 'unread': e.value.unread}},
      },
    };
  }

  /// Message-IDs of mail the user sent, so the helper knows an answer to
  /// one when it sees it.
  Future<List<String>> myMessageIds() async {
    final rows = await customSelect("SELECT DISTINCT message_id AS m FROM messages WHERE is_from_me = 1 AND message_id IS NOT NULL AND message_id <> ''").get();
    return [for (final r in rows) r.read<String>('m')];
  }

  // ---- what the helper decided ------------------------------------------------------

  /// The helper's decision for a sender, when this device follows a helper
  /// and the helper has made one. A stale "moved by you" is not used: the
  /// user's own move lives on the sender itself.
  Future<SenderDecision?> helperSender(String key) async {
    final r = await customSelect(
      'SELECT s.cls, s.src, s.cat, s.reasons FROM helper_senders s JOIN helper_state h ON h.id = 1 AND h.connected = 1 WHERE s.key = ?',
      variables: [Variable.withString(key)],
    ).getSingleOrNull();
    if (r == null) return null;
    // A move the user made by hand on another device is theirs here too: it
    // comes back marked as a move, so this device never mistakes the sender
    // for one it may decide by itself (and never tells the helper so).
    final reasons = r.read<String>('reasons');
    return SenderDecision(
      r.read<String>('cls') == 'feeds' ? Bucket.feeds : Bucket.people,
      category: r.readNullable<String>('cat'),
      reasons: reasons.isEmpty ? const [] : reasons.split(' · '),
      source: r.read<String>('src'),
    );
  }

  /// What the user said does not belong under FYI: "kind|sender" pairs.
  static Set<String> decodeFyiOff(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      return {for (final x in jsonDecode(json) as List) if (x is String) x};
    } catch (_) {
      return const {};
    }
  }

  /// "Does not belong here" on an FYI item ([off] true), or that taken
  /// back: notices of that kind from that sender stay off FYI, on every device.
  Future<void> setFyiOff(String kind, String contactKey, bool off) async {
    final set = {...decodeFyiOff(await getSetting(kFyiOff))};
    final pair = '$kind|$contactKey';
    if (off ? !set.add(pair) : !set.remove(pair)) return;
    final list = set.toList()..sort();
    await putSetting(kFyiOff, jsonEncode(list));
    await noteForHelper('pref', 'fyioff', {'list': list});
  }

  /// The helper's decision for one email, by its Message-ID.
  Future<({Bucket bucket, String? category})?> helperVerdict(String? messageId) async {
    if (messageId == null || messageId.isEmpty) return null;
    final r = await customSelect(
      'SELECT v.cls, v.cat FROM helper_verdicts v JOIN helper_state h ON h.id = 1 AND h.connected = 1 WHERE v.message_id = ?',
      variables: [Variable.withString(messageId)],
    ).getSingleOrNull();
    return r == null ? null : (bucket: r.read<String>('cls') == 'feeds' ? Bucket.feeds : Bucket.people, category: r.readNullable<String>('cat'));
  }

  /// The user fixed one email here: the fix stands at once, without waiting
  /// for the helper to say it back.
  Future<void> rememberLocalVerdict(String? messageId, Bucket bucket, String? category) async {
    if (messageId == null || messageId.isEmpty || !await helperConnected()) return;
    await into(helperVerdicts).insertOnConflictUpdate(HelperVerdictsCompanion.insert(messageId: messageId, cls: bucket.name, cat: Value(bucket == Bucket.feeds ? category : null)));
  }

  Future<void> _keepMark(String messageId, HelperMarksCompanion mark) async {
    final n = await (update(helperMarks)..where((m) => m.messageId.equals(messageId))).write(mark);
    if (n == 0) await into(helperMarks).insert(mark.copyWith(messageId: Value(messageId)), mode: InsertMode.insertOrIgnore);
  }

  /// Files [address] under the person [key], as another device did; with
  /// [key] null (or the address itself), takes it back out as its own
  /// contact. Works whether or not any mail from the address is here yet:
  /// mail that arrives later is filed by the same mapping.
  Future<void> _applyAddress(String address, String? key) async {
    final mapping = await (select(contactAddresses)..where((a) => a.address.equals(address))).getSingleOrNull();
    if (key == null || key.isEmpty || key == address) {
      if (mapping != null && mapping.contactKey != address) await separateAddress(address);
      return;
    }
    if (mapping?.contactKey == key) return;
    await into(contacts).insert(ContactsCompanion.insert(key: key), mode: InsertMode.insertOrIgnore);
    await into(contactAddresses).insert(ContactAddressesCompanion.insert(address: key, contactKey: key), mode: InsertMode.insertOrIgnore);
    if (mapping == null) {
      await into(contactAddresses).insert(ContactAddressesCompanion.insert(address: address, contactKey: key, source: const Value('user')), mode: InsertMode.insertOrIgnore);
      return;
    }
    final standalone = mapping.contactKey == address && await (select(contacts)..where((c) => c.key.equals(address))).getSingleOrNull() != null;
    if (standalone) {
      await mergeContacts(key, [address]);
      return;
    }
    await (update(contactAddresses)..where((a) => a.address.equals(address))).write(ContactAddressesCompanion(contactKey: Value(key), source: const Value('user')));
    await refileCandidates({mapping.contactKey, key});
    filingGeneration++;
  }

  /// Writes one change from the helper. Returns the sender keys whose mail
  /// should be filed again. Call inside [applyingFromHelper].
  Future<Set<String>> applyHelperItem(String kind, String k, Map<String, Object?> data, {required bool deleted}) async {
    switch (kind) {
      case 'sender':
        if (deleted) {
          await (delete(helperSenders)..where((s) => s.key.equals(k))).go();
          return {k};
        }
        final cls = data['cls'] == 'feeds' ? 'feeds' : 'people';
        final src = (data['src'] as String?) ?? 'auto';
        await into(helperSenders).insertOnConflictUpdate(HelperSendersCompanion.insert(
          key: k,
          cls: cls,
          src: Value(src),
          cat: Value(data['cat'] as String?),
          reasons: Value((data['reasons'] as String?) ?? ''),
          pile: data.containsKey('pile') ? Value(data['pile'] as String?) : const Value.absent(),
          counts: data.containsKey('counts') ? Value(data['counts'] == true) : const Value.absent(),
          label: data.containsKey('label') ? Value(data['label'] as String?) : const Value.absent(),
          subtitle: data.containsKey('subtitle') ? Value(data['subtitle'] as String?) : const Value.absent(),
        ));
        await (update(contacts)..where((c) => c.key.equals(k) & c.isMe.equals(false))).write(ContactsCompanion(
          classification: Value(cls),
          classificationSource: Value(src),
          feedsCategory: Value(data['cat'] as String?),
          classReasons: Value((data['reasons'] as String?) ?? ''),
          feedsPile: data.containsKey('pile') ? Value(data['pile'] as String?) : const Value.absent(),
          countsTowardUnread: data.containsKey('counts') ? Value(data['counts'] == true) : const Value.absent(),
          userLabel: data.containsKey('label') ? Value(data['label'] as String?) : const Value.absent(),
          userSubtitle: data.containsKey('subtitle') ? Value(data['subtitle'] as String?) : const Value.absent(),
        ));
        return {k};
      case 'sort':
        if (deleted) {
          await (delete(helperVerdicts)..where((v) => v.messageId.equals(k))).go();
          return const {};
        }
        final cls = data['cls'] == 'feeds' ? 'feeds' : 'people';
        final cat = cls == 'feeds' ? data['cat'] as String? : null;
        final pile = cls == 'feeds' && (data['pile'] == 'feed' || data['pile'] == 'noise') ? data['pile'] as String : null;
        await into(helperVerdicts).insertOnConflictUpdate(HelperVerdictsCompanion.insert(messageId: k, cls: cls, cat: Value(cat), pile: Value(pile)));
        await (update(messages)..where((m) => m.messageId.equals(k) & m.isFromMe.equals(false))).write(MessagesCompanion(classification: Value(cls), feedsCategory: Value(cat)));
        return const {};
      case 'rule':
        if (deleted) {
          await (delete(classificationRules)..where((r) => r.uid.equals(k))).go();
          return const {};
        }
        final row = ClassificationRulesCompanion(
          uid: Value(k),
          field: Value((data['field'] as String?) ?? 'sender'),
          pattern: Value((data['pattern'] as String?) ?? ''),
          bucket: Value(data['bucket'] as String?),
          category: Value(data['category'] as String?),
        );
        final n = await (update(classificationRules)..where((r) => r.uid.equals(k))).write(row);
        if (n == 0) await into(classificationRules).insert(row.copyWith(createdAt: Value(_time(data['at']) ?? DateTime.now())));
        return const {};
      case 'tag':
        if (deleted) {
          await (delete(feedsCategoryRows)..where((t) => t.name.equals(k))).go();
          return const {};
        }
        final pos = (data['pos'] as num?)?.toInt() ?? 0;
        final n = await (update(feedsCategoryRows)..where((t) => t.name.equals(k))).write(FeedsCategoryRowsCompanion(sortOrder: Value(pos)));
        if (n == 0) await into(feedsCategoryRows).insert(FeedsCategoryRowsCompanion.insert(name: k, sortOrder: Value(pos), builtin: Value(data['builtin'] == true)));
        return const {};
      case 'rowpref':
        if (deleted) {
          await (delete(rowPrefs)..where((p) => p.rowKey.equals(k))).go();
        } else {
          await into(rowPrefs).insertOnConflictUpdate(RowPrefsCompanion(
            rowKey: Value(k),
            pinned: Value(data['pinned'] == true),
            muted: Value(data['muted'] == true),
            snoozedUntil: Value(_time(data['snoozed'])),
            resurfacedAt: Value(_time(data['resurfaced'])),
            updatedAt: Value(DateTime.now()),
          ));
        }
        await markRowsDirty([k]);
        return const {};
      case 'reminder':
        if (deleted) {
          await (delete(reminders)..where((r) => r.uid.equals(k))).go();
          return const {};
        }
        final mid = data['mid'] as String?;
        final local = mid == null || mid.isEmpty ? null : await (select(messages)..where((m) => m.messageId.equals(mid))..limit(1)).getSingleOrNull();
        final row = RemindersCompanion(
          uid: Value(k),
          title: Value((data['title'] as String?) ?? 'Reminder'),
          dueAt: Value(_time(data['due']) ?? DateTime.now()),
          done: Value(data['done'] == true),
          messageId: Value(local?.id),
          threadKey: Value(data['thread'] as String?),
          rowKey: Value(data['row'] as String?),
        );
        // Whether it has rung is each device's own business: this device
        // rings by its own clock. A reminder first heard of after it rang
        // elsewhere does not ring late here.
        final n = await (update(reminders)..where((r) => r.uid.equals(k))).write(row);
        if (n == 0) await into(reminders).insert(row.copyWith(firedAt: Value(_time(data['fired']))));
        return const {};
      case 'done':
        final doneAt = deleted ? null : (_time(data['at']) ?? DateTime.now());
        // Kept as well as applied: the email itself may not have landed here yet.
        await _keepMark(k, HelperMarksCompanion(doneAt: Value(doneAt)));
        await (update(messages)..where((m) => m.messageId.equals(k))).write(MessagesCompanion(doneAt: Value(doneAt)));
        return const {};
      case 'addr':
        // People joined into one on another device (or taken apart again).
        await _applyAddress(k, deleted ? null : data['key'] as String?);
        return const {};
      case 'pref':
        // A setting that holds on every device: quiet hours.
        if (k == 'quiet') await putSetting(kQuietHours, deleted ? '' : jsonEncode({'on': data['on'] == true, 'from': data['from'], 'to': data['to']}));
        // The sentence on Today, dismissed on another device.
        if (k == 'day') await putSetting(kDayDismissed, deleted ? '' : '${(data['dismissed'] as num?)?.toInt() ?? ''}');
        // 12-hour or 24-hour clock, chosen on another device.
        if (k == 'clock') await putSetting(kClockFormat, deleted ? '' : (data['h24'] == true ? '24' : '12'));
        // What was said not to belong under FYI, on another device.
        if (k == 'fyioff') await putSetting(kFyiOff, deleted ? '' : jsonEncode([for (final x in (data['list'] is List ? data['list'] as List : const [])) if (x is String) x]));
        return const {};
      case 'msgfix':
        // What the user set on one email on another device: Focus or not,
        // put off until later, Feed or Noise. (Its place among Chats and Feed arrives as 'sort'.)
        if (deleted) return const {};
        if (data.containsKey('focus') || data.containsKey('pile') || data.containsKey('later')) {
          final later = data.containsKey('later') ? Value(_time(data['later'])) : const Value<DateTime?>.absent();
          final focus = data.containsKey('focus') ? Value(data['focus'] == true ? 'yes' : (data['focus'] == false ? 'no' : null)) : const Value<String?>.absent();
          final pile = data.containsKey('pile') ? Value(data['pile'] == 'feed' || data['pile'] == 'noise' ? data['pile'] as String : null) : const Value<String?>.absent();
          await _keepMark(k, HelperMarksCompanion(laterUntil: later, focusFix: focus, pileFix: pile));
          await (update(messages)..where((m) => m.messageId.equals(k))).write(MessagesCompanion(laterUntil: later, focusFix: focus, pileFix: pile));
        }
        // "Does not belong here" said on another device (or taken back).
        if (data['know'] is bool) await (update(helperReadings)..where((r) => r.messageId.equals(k))).write(HelperReadingsCompanion(know: Value(data['know'] == true)));
        if (data['asks'] is bool) await (update(helperReadings)..where((r) => r.messageId.equals(k) & r.sent.equals(true))).write(HelperReadingsCompanion(asks: Value(data['asks'] == true)));
        return const {};
      case 'read':
        // The assistant's reading of one email.
        if (deleted) {
          await (delete(helperReadings)..where((r) => r.messageId.equals(k))).go();
          return const {};
        }
        final why = data['why'];
        await into(helperReadings).insertOnConflictUpdate(HelperReadingsCompanion.insert(
          messageId: k,
          line: Value((data['line'] as String?) ?? ''),
          focus: Value(data['focus'] == true),
          ask: Value((data['ask'] as String?) ?? ''),
          due: Value(_time(data['due'])),
          why: Value(jsonEncode(why is List ? [for (final w in why) if (w is String) w] : const <String>[])),
          answered: Value(data['answered'] == true),
          readAt: Value(_time(data['at'])),
          sent: Value(data['sent'] == true),
          asks: Value(data['asks'] == true),
          know: Value(data['know'] == true),
          thing: Value((data['thing'] as String?) ?? ''),
        ));
        return const {};
      case 'day':
        // The one sentence at the top of Today, with when it was written.
        await putSetting(kDaySentence, deleted ? '' : jsonEncode({'text': data['text'], 'at': data['at'], 'after': data['after']}));
        return const {};
      default:
        // Things only this device tells the helper (own addresses, the
        // address book) need nothing done here.
        return const {};
    }
  }
}
