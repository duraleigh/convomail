import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/classifier.dart';
import '../mail/imap_transport.dart';
import '../mail/models.dart';
import '../platform/credential_store.dart';

/// Read-only diagnostics, run from the command line. Both modes open the
/// database read-only (never migrating it, so they are safe beside a
/// running copy of the app), connect with each account's saved password,
/// and write `%TEMP%\convomail-diag.txt`. Reports hold sender domains,
/// header names, rule names and counts only: no addresses, names,
/// subjects or bodies.
///
/// * `--diag-signals`: re-reads the list headers of INBOX messages stored
///   without bulk signals and counts Gmail's category buckets.
/// * `--diag-classify`: reads every message's Gmail category, runs the
///   current classifier over the stored mail in memory, and reports which
///   senders would move between People and Feeds, grouped by domain.
Future<void> runDiag({required bool classify}) async {
  final out = StringBuffer();
  final path = p.join((await getApplicationSupportDirectory()).path, 'convomail.sqlite');
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  final store = WindowsCredentialStore();
  try {
    for (final account in db.select('SELECT * FROM accounts ORDER BY id')) {
      final id = account['id'] as int;
      out.writeln('account $id provider=${account['provider_id']} host=${account['imap_host']}');
      final pw = await store.read(CredentialStore.passwordKey(id));
      if (pw == null) {
        out.writeln('  no saved password');
        continue;
      }
      final t = ImapTransport();
      try {
        await t.connect(
          ServerConfig(host: account['imap_host'] as String, port: account['imap_port'] as int, security: ConnectionSecurityName.parse(account['imap_security'] as String)),
          MailCredentials(username: account['username'] as String, password: pw),
        );
        out.writeln('  capabilities: ${t.capabilities.join(' ')}');
        if (classify) {
          await _classifyDryRun(db, t, id, out);
        } else {
          await _signals(db, t, id, out);
        }
      } catch (e) {
        out.writeln('  error: $e');
      } finally {
        await t.disconnect();
      }
    }
  } finally {
    db.close();
  }
  final file = File(p.join(Platform.environment['TEMP'] ?? '.', 'convomail-diag.txt'));
  await file.writeAsString(out.toString());
  stdout.writeln(out);
}

String _domainOf(String address) => address.contains('@') ? address.substring(address.indexOf('@') + 1).toLowerCase() : '?';

Future<void> _signals(Database db, ImapTransport t, int accountId, StringBuffer out) async {
  final inbox = db.select("SELECT id, path FROM folders WHERE account_id = ? AND role = 'inbox'", [accountId]).firstOrNull;
  if (inbox == null) {
    out.writeln('  no inbox folder');
    return;
  }
  await t.selectFolder(inbox['path'] as String);
  final rows = db.select(
    "SELECT uid, from_address FROM messages WHERE folder_id = ? AND is_from_me = 0 AND bulk_signals = '' ORDER BY uid DESC LIMIT 30",
    [inbox['id']],
  );
  final domains = {for (final r in rows) r['uid'] as int: _domainOf(r['from_address'] as String)};
  out.writeln('  re-reading list headers for ${rows.length} messages stored with empty signals:');
  for (final line in await t.probeHeaders(domains.keys.toList())) {
    final uid = int.tryParse(RegExp(r'uid=(\d+)').firstMatch(line)?.group(1) ?? '');
    out.writeln('    ${domains[uid] ?? '?'}: $line');
  }
  if (t.capabilities.contains('X-GM-EXT-1')) {
    for (final cat in ['primary', 'updates', 'promotions', 'social', 'forums']) {
      out.writeln('  gmail category:$cat -> ${(await t.searchUids('X-GM-RAW "category:$cat"')).length} messages');
    }
  }
}

Future<void> _classifyDryRun(Database db, ImapTransport t, int accountId, StringBuffer out) async {
  // 1. Gmail category of every stored message, per folder.
  final categoryOf = <(int, int), String>{};
  if (t.capabilities.contains('X-GM-EXT-1')) {
    for (final f in db.select("SELECT id, path FROM folders WHERE account_id = ? AND role <> 'sent' AND EXISTS (SELECT 1 FROM messages m WHERE m.folder_id = folders.id)", [accountId])) {
      await t.selectFolder(f['path'] as String);
      for (final cat in ['primary', 'updates', 'promotions', 'social', 'forums']) {
        for (final uid in await t.searchUids('X-GM-RAW "category:$cat"')) {
          categoryOf[(f['id'] as int, uid)] = cat;
        }
      }
    }
  }
  out.writeln('  gmail categories read for ${categoryOf.length} messages');

  // 2. Facts per sender, built the way ClassificationQueries.senderFacts does.
  final written = {
    for (final r in db.select("SELECT DISTINCT p.contact_key AS k FROM messages m JOIN message_participants p ON p.message_id = m.id WHERE m.is_from_me = 1 AND p.role IN ('to','cc')")) r['k'] as String,
  };
  final msgs = db.select('''
    SELECT id, folder_id, uid, message_id, from_contact_key AS k, from_address, from_name, subject, bulk_signals, is_deleted,
           COALESCE(date, internal_date) AS ts
    FROM messages WHERE account_id = ? AND is_from_me = 0 ORDER BY ts DESC
  ''', [accountId]);
  final byKey = <String, List<Row>>{};
  for (final m in msgs) {
    byKey.putIfAbsent(m['k'] as String, () => []).add(m);
  }
  final contacts = {for (final c in db.select('SELECT * FROM contacts WHERE is_me = 0')) c['key'] as String: c};
  final rules = [
    for (final r in db.select('SELECT * FROM classification_rules ORDER BY id'))
      ClassificationRule(field: r['field'] as String, pattern: r['pattern'] as String, bucket: r['bucket'] == null ? null : Bucket.values.byName(r['bucket'] as String), category: r['category'] as String?),
  ];
  final classifier = Classifier(rules: rules);

  // domain -> counters
  final toFeeds = <String, _DomainStat>{};
  final toPeople = <String, _DomainStat>{};
  final stillPeople = <String, _DomainStat>{};
  var peopleBefore = 0, peopleAfter = 0, feedsBefore = 0, feedsAfter = 0;
  final reasonKinds = <String, int>{};

  for (final e in byKey.entries) {
    final c = contacts[e.key];
    if (c == null) continue;
    final list = e.value;
    final address = list.first['from_address'] as String;
    final known = list.where((m) => m['bulk_signals'] != null).length;
    final bulk = list.where((m) => (m['bulk_signals'] as String?)?.isNotEmpty ?? false).length;
    final listIds = {
      for (final m in list)
        if ((m['bulk_signals'] as String?)?.contains(';') ?? false) (m['bulk_signals'] as String).substring((m['bulk_signals'] as String).indexOf(';') + 1).toLowerCase(),
    };
    final seen = <String>{};
    final cats = <String, int>{};
    final subjects = <String>[];
    for (final m in list) {
      final dedupe = (m['message_id'] as String?) ?? 'id:${m['id']}';
      final cat = categoryOf[(m['folder_id'] as int, m['uid'] as int)];
      if (!seen.add(dedupe)) continue;
      if (cat != null) cats[cat] = (cats[cat] ?? 0) + 1;
      if (m['is_deleted'] == 0 && subjects.length < 20) subjects.add(m['subject'] as String);
    }
    final name = list.map((m) => m['from_name'] as String).firstWhere((n) => n.isNotEmpty, orElse: () => c['display_name'] as String);
    final isOverride = c['classification_source'] == 'override';
    final facts = SenderFacts(
      address: address,
      name: name,
      userHasWrittenTo: written.contains(e.key),
      inAddressBook: c['in_address_book'] == 1,
      messagesWithBulkHeaders: bulk,
      messagesWithKnownSignals: known,
      listIds: listIds,
      override: isOverride ? (c['classification'] == 'feeds' ? Bucket.feeds : Bucket.people) : null,
      providerCategories: cats,
      subjects: subjects,
    );
    final d = classifier.classifySender(facts);
    final before = c['classification'] as String;
    final after = d.bucket.name;
    before == 'people' ? peopleBefore++ : feedsBefore++;
    after == 'people' ? peopleAfter++ : feedsAfter++;
    final kind = d.reasons.isEmpty ? '-' : d.reasons.first.replaceAll(RegExp(r'\s*\(.*'), '');
    reasonKinds['$after: $kind'] = (reasonKinds['$after: $kind'] ?? 0) + 1;
    final target = before == 'people' && after == 'feeds'
        ? toFeeds
        : before == 'feeds' && after == 'people'
            ? toPeople
            : after == 'people'
                ? stillPeople
                : null;
    if (target != null) {
      final s = target.putIfAbsent(_domainOf(address), _DomainStat.new);
      s.senders++;
      s.messages += list.length;
      s.reasons[kind] = (s.reasons[kind] ?? 0) + 1;
      cats.forEach((k, v) => s.cats[k] = (s.cats[k] ?? 0) + v);
      if (_looksHuman(name)) s.humanNames++;
    }
  }

  out.writeln('  inbound senders: People $peopleBefore -> $peopleAfter, Feeds $feedsBefore -> $feedsAfter');
  out.writeln('  decisions by first reason:');
  for (final e in reasonKinds.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) {
    out.writeln('    ${e.value.toString().padLeft(4)}  ${e.key}');
  }
  void dump(String title, Map<String, _DomainStat> m) {
    out.writeln('  $title (${m.values.fold(0, (a, s) => a + s.senders)} senders):');
    for (final e in m.entries.toList()..sort((a, b) => b.value.messages.compareTo(a.value.messages))) {
      out.writeln('    ${e.key.padRight(38)} ${e.value}');
    }
  }

  dump('People -> Feeds', toFeeds);
  dump('Feeds -> People', toPeople);
  dump('People after the change', stillPeople);
}

/// "First Last" style display names, for spotting people sent to Feeds.
bool _looksHuman(String name) => RegExp(r"^[A-Z][a-zA-Z'’\-]+,? [A-Z][a-zA-Z'’\-.]+( [A-Z][a-zA-Z'’\-]+)?$").hasMatch(name.trim());

class _DomainStat {
  int senders = 0;
  int messages = 0;
  int humanNames = 0;
  final Map<String, int> reasons = {};
  final Map<String, int> cats = {};

  @override
  String toString() => 'senders=$senders msgs=$messages humanNames=$humanNames gmail=$cats why=$reasons';
}
