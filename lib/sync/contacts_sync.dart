import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_log.dart';
import '../domain/identity.dart';
import '../mail/google_oauth.dart';
import '../platform/credential_store.dart';
import '../store/address_book_queries.dart';
import '../store/database.dart' hide ClassificationRule;
import 'classification_service.dart';

/// Google sign-in, opening the system browser.
final googleOAuthProvider = Provider<GoogleOAuth>((ref) => GoogleOAuth(
      store: ref.read(credentialStoreProvider),
      openBrowser: (uri) async {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    ));

final contactsSyncProvider = FutureProvider<ContactsSync>((ref) async {
  final support = await getApplicationSupportDirectory();
  return ContactsSync(
    db: ref.read(databaseProvider),
    oauth: ref.read(googleOAuthProvider),
    avatarsDir: Directory(p.join(support.path, 'avatars')),
    classification: ref.read(classificationServiceProvider),
  );
});

/// Keeps people's photos in line with the user's Google contacts (spec 4.2),
/// read through Google's People API. Only names, addresses and photos are
/// requested, and only photos are stored, in [avatarsDir]. Photos the user
/// never set (Google's letter placeholders) are skipped, so initials stay.
class ContactsSync {
  ContactsSync({required this.db, required this.oauth, required this.avatarsDir, required this.classification, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final GoogleOAuth oauth;
  final Directory avatarsDir;
  final ClassificationService classification;
  final DateTime Function() _clock;

  static const syncTokenKey = 'google.contacts.syncToken';
  static const lastSyncKey = 'google.contacts.lastSync';
  static const interval = Duration(hours: 24);

  Timer? _timer;
  Future<void>? _running;

  /// Runs at start: photos for senders first seen since the last run, then a
  /// sync when one is due. Stops quietly when not connected or offline.
  void start() {
    _timer ??= Timer.periodic(const Duration(hours: 1), (_) => unawaited(_tick()));
    unawaited(_tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    try {
      if (!await oauth.isConnected) return;
      await _apply();
      final last = DateTime.tryParse(await db.getSetting(lastSyncKey) ?? '');
      if (last == null || _clock().difference(last) >= interval) await syncNow();
    } catch (e, st) {
      AppLog.current?.warn('Google Contacts sync failed', AppLog.scrub(e));
      AppLog.current?.warn(st.toString().split('\n').first);
    }
  }

  /// One sync. Only one runs at a time; a second caller waits for it.
  Future<void> syncNow() => _running ??= _sync().whenComplete(() => _running = null);

  Future<void> _sync() async {
    var syncToken = await db.getSetting(syncTokenKey);
    String? pageToken;
    String? nextSyncToken;
    await avatarsDir.create(recursive: true);
    final known = {for (final e in await db.addressBookEntries()) e.resourceName: e};
    while (true) {
      final uri = Uri.https('people.googleapis.com', '/v1/people/me/connections', {
        'personFields': 'names,emailAddresses,photos',
        'pageSize': '500',
        'requestSyncToken': 'true',
        'pageToken': ?pageToken,
        'syncToken': ?syncToken,
      });
      final response = await _get(uri);
      if (syncToken != null && (response.status == 410 || response.text.contains('EXPIRED_SYNC_TOKEN'))) {
        // Tokens last a week. An expired one means starting over.
        syncToken = null;
        pageToken = null;
        await db.putSetting(syncTokenKey, '');
        continue;
      }
      if (response.status != 200) throw GoogleAuthException('Google Contacts answered ${response.status}.');
      final body = jsonDecode(response.text) as Map<String, dynamic>;
      for (final person in (body['connections'] as List<dynamic>?) ?? const []) {
        await _person(person as Map<String, dynamic>, known);
      }
      pageToken = body['nextPageToken'] as String?;
      nextSyncToken = body['nextSyncToken'] as String? ?? nextSyncToken;
      if (pageToken == null) break;
    }
    if (nextSyncToken != null) await db.putSetting(syncTokenKey, nextSyncToken);
    await db.putSetting(lastSyncKey, _clock().toIso8601String());
    await _apply();
  }

  Future<void> _apply() async {
    final changed = await db.applyAddressBook();
    if (changed.isNotEmpty) await classification.classifySenders(changed, log: false);
  }

  Future<void> _person(Map<String, dynamic> person, Map<String, AddressBookEntry> known) async {
    final resource = person['resourceName'] as String?;
    if (resource == null) return;
    final metadata = person['metadata'];
    if (metadata is Map && metadata['deleted'] == true) {
      await db.removeAddressBookPerson(resource);
      final old = known[resource]?.photoPath;
      if (old != null) await _deleteQuietly(File(old));
      return;
    }
    final addresses = {
      for (final e in (person['emailAddresses'] as List<dynamic>?) ?? const [])
        if (e is Map && e['value'] is String) IdentityResolver(myAddresses: const []).resolve(e['value'] as String).address,
    };
    if (addresses.isEmpty) {
      await db.removeAddressBookPerson(resource);
      return;
    }
    final url = _photoUrl(person);
    var path = known[resource]?.photoUrl == url ? known[resource]?.photoPath : null;
    if (url != null && path == null) path = await _download(url, resource);
    if (url == null) {
      final old = known[resource]?.photoPath;
      if (old != null) await _deleteQuietly(File(old));
    }
    await db.upsertAddressBookPerson(resource, addresses, photoPath: path, photoUrl: url);
  }

  /// The photo the user set, if any: primary first, never a placeholder.
  static String? _photoUrl(Map<String, dynamic> person) {
    final photos = [for (final x in (person['photos'] as List<dynamic>?) ?? const []) if (x is Map && x['default'] != true && x['url'] is String) x];
    if (photos.isEmpty) return null;
    final primary = photos.where((x) => x['metadata'] is Map && (x['metadata'] as Map)['primary'] == true).firstOrNull ?? photos.first;
    return primary['url'] as String;
  }

  Future<String?> _download(String url, String resource) async {
    final uri = Uri.tryParse(url.replaceFirst(RegExp(r'=s\d+$'), '=s144'));
    if (uri == null || uri.scheme != 'https') return null;
    final response = await oauth.http('GET', uri);
    if (response.status != 200 || response.bytes.isEmpty) return null;
    final file = File(p.join(avatarsDir.path, '${resource.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.jpg'));
    await file.writeAsBytes(response.bytes, flush: true);
    return file.path;
  }

  Future<GoogleResponse> _get(Uri uri) async {
    var response = await oauth.http('GET', uri, headers: {'Authorization': 'Bearer ${await oauth.accessToken()}'});
    if (response.status == 401) {
      oauth.invalidateAccess();
      response = await oauth.http('GET', uri, headers: {'Authorization': 'Bearer ${await oauth.accessToken()}'});
    }
    return response;
  }

  /// Forgets everything from Google: permission, sync state, photos.
  Future<void> disconnect() async {
    stop();
    await oauth.disconnect();
    await db.clearAddressBook();
    await db.putSetting(syncTokenKey, '');
    await db.putSetting(lastSyncKey, '');
    if (avatarsDir.existsSync()) await avatarsDir.delete(recursive: true);
    await _apply();
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // A leftover image is harmless.
    }
  }
}
