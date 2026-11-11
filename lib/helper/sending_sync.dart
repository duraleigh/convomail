import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../app/app_log.dart';
import '../platform/credential_store.dart';
import '../store/compose_queries.dart';
import '../store/database.dart';
import '../store/sync_queries.dart';
import '../sync/signature_service.dart';
import 'helper_client.dart';
import 'helper_sync.dart';

/// Keeps the addresses the user sends from the same on every device: each
/// one's name, signature (pictures included), and, for an address that
/// sends through a mail server of its own, that server and its password.
///
/// The PC that set an address up hands it to the helper, which keeps it
/// locked. A phone or second PC that joins gets it from there, so it can
/// send from every address the first PC can, with nothing typed again.
class SendingSync {
  SendingSync(this._ref);
  final Ref _ref;

  static const _kSynced = 'sending.synced';
  static const _kRev = 'sending.rev';

  StreamSubscription<List<Identity>>? _watch;
  Timer? _soon;
  Future<void>? _running;
  bool _again = false;
  bool _stopped = false;

  AppDatabase get _db => _ref.read(databaseProvider);
  CredentialStore get _vault => _ref.read(credentialStoreProvider);

  /// Begins keeping in step. Call once the app is up.
  void start() {
    _ref.listen(helperProvider.select((h) => (h.connected, h.sendingRev)), (_, _) => _later(const Duration(milliseconds: 300)), fireImmediately: true);
    _watch ??= _db.watchAllIdentities().listen((_) => _later(const Duration(seconds: 2)));
  }

  void stop() {
    _stopped = true;
    _soon?.cancel();
    _watch?.cancel();
  }

  void _later(Duration d) {
    if (_stopped) return;
    _soon?.cancel();
    _soon = Timer(d, () => unawaited(run()));
  }

  /// A password was saved or removed for an address: passwords live outside
  /// the app's notes, so nothing else says so.
  void passwordChanged() => _later(const Duration(milliseconds: 500));

  /// One round: take in what changed elsewhere, then send up what changed
  /// here. Rounds never overlap.
  Future<void> run() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = () async {
      try {
        do {
          _again = false;
          await _round();
        } while (_again && !_stopped);
      } on HelperException {
        // Unreachable, or signed out: the next round tries again.
      } catch (e, st) {
        AppLog.current?.error('keeping the sending addresses in step failed', AppLog.scrub(e), st);
      }
    }()
        .whenComplete(() => _running = null);
  }

  Future<void> _round() async {
    final link = _ref.read(helperProvider);
    if (!link.connected || _stopped) return;
    final client = await _ref.read(helperProvider.notifier).client();
    if (client == null) return;
    final account = (await _db.allAccounts()).firstOrNull;
    if (account == null) return;

    // Two notes per address: what the helper last held as this device saw
    // it, and what this device last held. Only a change made here goes up,
    // so two devices that write an address down slightly differently can
    // never send it back and forth.
    final notes = _decode(await _db.getSetting(_kSynced));
    final seen = notes.seen;
    final sent = notes.sent;
    var known = int.tryParse(await _db.getSetting(_kRev) ?? '');

    // 1. What changed elsewhere.
    final remote = link.sendingRev;
    if (known == null || (remote != null && remote != known)) {
      final got = await client.sending();
      for (final a in got.addresses) {
        final email = '${a['email'] ?? ''}'.toLowerCase();
        if (email.isEmpty) continue;
        final hash = _hash(a);
        if (seen[email] == hash) continue;
        final id = await _apply(account, email, a);
        seen[email] = hash;
        final now = await _db.identityById(id);
        if (now != null) sent[email] = _hash(await _entry(now));
      }
      known = got.rev;
      await _db.putSetting(_kSynced, jsonEncode({'seen': seen, 'sent': sent}));
      await _db.putSetting(_kRev, '$known');
    }

    // 2. What changed here.
    final send = <Map<String, Object?>>[];
    final local = <String>{};
    final after = <String, String>{};
    for (final i in await _db.select(_db.identities).get()) {
      final email = i.email.trim().toLowerCase();
      if (email.isEmpty || !local.add(email)) continue;
      final entry = await _entry(i);
      final hash = _hash(entry);
      if (sent[email] != hash) {
        send.add(entry);
        after[email] = hash;
      }
    }
    final gone = [for (final email in sent.keys) if (!local.contains(email)) email];
    for (final email in gone) {
      send.add({'email': email, 'deleted': true});
    }
    if (send.isEmpty) return;
    final rev = await client.putSending(send);
    sent.addAll(after);
    seen.addAll(after);
    for (final email in gone) {
      sent.remove(email);
      seen.remove(email);
    }
    await _db.putSetting(_kSynced, jsonEncode({'seen': seen, 'sent': sent}));
    // When only this device's change moved the number on, there is nothing
    // new to fetch; otherwise the next round fetches.
    if (known + 1 == rev) await _db.putSetting(_kRev, '$rev');
  }

  /// One address in the helper's words.
  Future<Map<String, Object?>> _entry(Identity i) async {
    final pics = <String, String>{};
    String? document;
    final json = i.signatureJson;
    if (json != null && json.isNotEmpty) {
      try {
        final doc = jsonDecode(json);
        await _eachPicture(doc, (url) async {
          if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('pic:')) return url;
          final file = File(url);
          if (!file.existsSync()) return url;
          final name = p.basename(url);
          pics[name] = base64Encode(await file.readAsBytes());
          return 'pic:$name';
        });
        document = jsonEncode(doc);
      } catch (_) {
        document = json;
      }
    }
    final password = i.smtpHost == null ? null : await _vault.read(CredentialStore.identityPasswordKey(i.id));
    return {
      'email': i.email.trim().toLowerCase(),
      if (i.name.isNotEmpty) 'name': i.name,
      if (i.signature.isNotEmpty) 'signature': i.signature,
      'signatureJson': ?document,
      if (pics.isNotEmpty) 'pics': pics,
      'host': ?i.smtpHost,
      'port': ?i.smtpPort,
      'security': ?i.smtpSecurity,
      'user': ?i.smtpUsername,
      if (password != null && password.isNotEmpty) 'password': password,
      if (i.hidden) 'hidden': true,
      if (i.isDefault) 'isDefault': true,
      if (i.discovered) 'discovered': true,
    };
  }

  /// Writes one address from the helper into this device's notes. Returns
  /// the address's id here.
  Future<int> _apply(Account account, String email, Map<String, Object?> a) async {
    final pics = a['pics'] is Map ? (a['pics'] as Map) : const <Object?, Object?>{};
    String? document;
    final json = a['signatureJson'];
    if (json is String && json.isNotEmpty) {
      try {
        final dir = await _ref.read(signatureImagesDirProvider);
        final doc = jsonDecode(json);
        await _eachPicture(doc, (url) async {
          if (!url.startsWith('pic:')) return url;
          final name = p.basename(url.substring(4));
          final file = File(p.join(dir.path, name));
          final data = pics[name];
          if (!file.existsSync() && data is String) await file.writeAsBytes(base64Decode(data), flush: true);
          return file.path;
        });
        document = jsonEncode(doc);
      } catch (_) {
        document = null;
      }
    }
    final host = a['host'] as String?;
    final row = IdentitiesCompanion(
      name: Value((a['name'] as String?) ?? ''),
      signature: Value((a['signature'] as String?) ?? ''),
      signatureJson: Value(document),
      smtpHost: Value(host),
      smtpPort: Value((a['port'] as num?)?.toInt()),
      smtpSecurity: Value(a['security'] as String?),
      smtpUsername: Value(a['user'] as String?),
      hidden: Value(a['hidden'] == true),
      discovered: Value(a['discovered'] == true),
    );
    final all = await _db.select(_db.identities).get();
    final mine = all.where((i) => i.email.trim().toLowerCase() == email).firstOrNull;
    final int id;
    if (mine == null) {
      id = await _db.into(_db.identities).insert(row.copyWith(accountId: Value(account.id), email: Value(email)));
    } else {
      id = mine.id;
      await (_db.update(_db.identities)..where((i) => i.id.equals(id))).write(row);
    }
    if (a['isDefault'] == true && !(mine?.isDefault ?? false)) await _db.setDefaultIdentity(account.id, id);
    final password = a['password'];
    if (host != null && password is String && password.isNotEmpty) {
      await _vault.write(CredentialStore.identityPasswordKey(id), password);
    } else if (host == null) {
      // No server of its own any more: its password has no use here.
      await _vault.delete(CredentialStore.identityPasswordKey(id));
    }
    // An address that arrives with a server but no password leaves this
    // device's own password alone: a password is never removed on another
    // device's say-so.
    return id;
  }

  /// Visits every picture in a signature document, replacing its address
  /// with what [change] returns.
  static Future<void> _eachPicture(Object? node, Future<String> Function(String url) change) async {
    if (node is Map) {
      final data = node['data'];
      if (node['type'] == 'image' && data is Map && data['url'] is String) {
        data['url'] = await change(data['url'] as String);
      }
      for (final v in node.values) {
        await _eachPicture(v, change);
      }
    } else if (node is List) {
      for (final v in node) {
        await _eachPicture(v, change);
      }
    }
  }

  static ({Map<String, String> seen, Map<String, String> sent}) _decode(String? json) {
    Map<String, String> part(Object? m) => m is Map ? {for (final e in m.entries) '${e.key}': '${e.value}'} : {};
    if (json == null || json.isEmpty) return (seen: {}, sent: {});
    try {
      final o = jsonDecode(json) as Map;
      return (seen: part(o['seen']), sent: part(o['sent']));
    } catch (_) {
      return (seen: {}, sent: {});
    }
  }

  /// The same for the same address however its parts are ordered.
  static String _hash(Map<String, Object?> entry) => sha1.convert(utf8.encode(jsonEncode(_ordered(entry)))).toString();

  static Object? _ordered(Object? v) {
    if (v is Map) return SplayTreeMap<String, Object?>.from({for (final e in v.entries) '${e.key}': _ordered(e.value)});
    if (v is List) return [for (final x in v) _ordered(x)];
    return v;
  }
}

final sendingSyncProvider = Provider<SendingSync>((ref) {
  final s = SendingSync(ref);
  ref.onDispose(s.stop);
  return s;
});
