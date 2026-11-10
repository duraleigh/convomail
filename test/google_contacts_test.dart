import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convomail/mail/google_oauth.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/address_book_queries.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/sync/classification_service.dart';
import 'package:convomail/sync/contacts_sync.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';

import 'support/test_db.dart';

const _clientFile = '{"installed":{"client_id":"id-1","client_secret":"sec-1"}}';

/// Answers as Google would. Records what was asked.
class FakeGoogle {
  final calls = <String>[];
  final forms = <String>[];
  final pages = <Map<String, dynamic>>[];
  int connectionsCalls = 0;
  bool expireSyncToken = false;
  String tokenError = '';

  GoogleResponse _json(int status, Object body) => GoogleResponse(status, Uint8List.fromList(utf8.encode(jsonEncode(body))));

  Future<GoogleResponse> call(String method, Uri uri, {Map<String, String> headers = const {}, String? form, String? json}) async {
    calls.add('$method ${uri.host}${uri.path}');
    if (form != null) forms.add(form);
    if (uri.path == '/token') {
      if (tokenError.isNotEmpty) return _json(400, {'error': tokenError});
      return _json(200, {'access_token': 'acc', 'refresh_token': 'ref', 'expires_in': 3600});
    }
    if (uri.path == '/revoke') return _json(200, {});
    if (uri.host == 'people.googleapis.com') {
      expect(headers['Authorization'], 'Bearer acc');
      expect(uri.queryParameters['personFields'], 'names,emailAddresses,photos');
      if (uri.queryParameters['syncToken'] != null && expireSyncToken) {
        expireSyncToken = false;
        return _json(400, {'error': {'status': 'FAILED_PRECONDITION', 'details': [{'reason': 'EXPIRED_SYNC_TOKEN'}]}});
      }
      return _json(200, pages[connectionsCalls++]);
    }
    return GoogleResponse(200, Uint8List.fromList([1, 2, 3]));
  }
}

Map<String, dynamic> _person(String id, List<String> emails, {String? photo, bool placeholder = false}) => {
      'resourceName': 'people/$id',
      'emailAddresses': [for (final e in emails) {'value': e}],
      if (photo != null)
        'photos': [
          {'url': photo, 'default': placeholder, 'metadata': {'primary': true}},
        ],
    };

void main() {
  late AppDatabase db;
  late InMemoryCredentialStore store;
  late FakeGoogle google;
  late GoogleOAuth oauth;
  late ContactsSync sync;
  late Directory dir;

  Future<void> sender(String address, String name) async {
    final account = (await db.select(db.accounts).get()).first;
    await db.into(db.contacts).insert(ContactsCompanion.insert(key: address, displayName: Value(name)), mode: InsertMode.insertOrIgnore);
    await db.into(db.contactAddresses).insert(ContactAddressesCompanion.insert(address: address, contactKey: address), mode: InsertMode.insertOrIgnore);
    final folder = (await db.select(db.folders).get()).first;
    final id = await db.into(db.messages).insert(MessagesCompanion.insert(accountId: account.id, folderId: folder.id, uid: address.hashCode.abs() % 100000, fromAddress: Value(address), fromName: Value(name), fromContactKey: Value(address), subject: const Value('Hello'), date: Value(DateTime.now())));
    await db.into(db.messageRowAssignments).insert(MessageRowAssignmentsCompanion.insert(messageId: id, rowKey: 'c:$address'));
    await db.refreshDirtyRows();
  }

  Future<Contact> contact(String key) => (db.select(db.contacts)..where((c) => c.key.equals(key))).getSingle();

  setUp(() async {
    db = testDatabase();
    final account = await insertTestAccount(db);
    await db.into(db.folders).insert(FoldersCompanion.insert(accountId: account.id, path: 'INBOX', name: 'INBOX', role: const Value('inbox')));
    store = InMemoryCredentialStore();
    google = FakeGoogle();
    dir = Directory.systemTemp.createTempSync('convomail_avatars_');
    oauth = GoogleOAuth(store: store, http: google.call, openBrowser: (_) async {});
    await store.write(GoogleOAuth.clientKey, _clientFile);
    await store.write(GoogleOAuth.refreshKey, 'ref');
    sync = ContactsSync(db: db, oauth: oauth, avatarsDir: dir, classification: ClassificationService(db));
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('sign-in', () {
    test('a wrong file is refused with a clear message; a client file is kept', () async {
      await store.delete(GoogleOAuth.clientKey);
      await expectLater(oauth.saveClientFile('{"nope":1}'), throwsA(isA<GoogleAuthException>()));
      await expectLater(oauth.saveClientFile('not json'), throwsA(isA<GoogleAuthException>()));
      expect(await oauth.hasClient, isFalse);
      await oauth.saveClientFile(_clientFile);
      expect(await oauth.hasClient, isTrue);
    });

    test('the browser flow: read-only scope, PKCE, a state check, and the token stored', () async {
      await store.delete(GoogleOAuth.refreshKey);
      Uri? opened;
      final flow = GoogleOAuth(
        store: store,
        http: google.call,
        openBrowser: (uri) async {
          opened = uri;
          final q = uri.queryParameters;
          final client = HttpClient();
          // A stray request first: it must not end the sign-in.
          final stray = await (await client.getUrl(Uri.parse('${q['redirect_uri']}/favicon.ico'))).close();
          expect(stray.statusCode, 404);
          await stray.drain<void>();
          final answer = await (await client.getUrl(Uri.parse('${q['redirect_uri']}/?code=abc&state=${q['state']}'))).close();
          await answer.drain<void>();
          client.close();
        },
      );
      await flow.connect();
      final q = opened!.queryParameters;
      expect(q['scope'], 'https://www.googleapis.com/auth/contacts.readonly https://www.googleapis.com/auth/calendar');
      expect(q['code_challenge_method'], 'S256');
      expect(q['code_challenge'], isNotEmpty);
      expect(q['redirect_uri'], startsWith('http://127.0.0.1:'));
      expect(await flow.isConnected, isTrue);
      expect(google.forms.single, contains('code_verifier='));
      expect(google.forms.single, contains('grant_type=authorization_code'));
    });

    test('a withdrawn permission asks to connect again', () async {
      google.tokenError = 'invalid_grant';
      await expectLater(oauth.accessToken(), throwsA(isA<GoogleAuthException>().having((e) => e.needsReconnect, 'needsReconnect', isTrue)));
      expect(await oauth.isConnected, isFalse);
    });
  });

  group('sync', () {
    test('photos land on people by any address, placeholders are skipped, and the row shows the photo', () async {
      await sender('tina@x.com', 'Tina');
      await sender('andy@x.com', 'Andy');
      await sender('stranger@x.com', 'Stranger');
      google.pages.add({
        'connections': [
          _person('c1', ['TINA@x.com', 'tina2@x.com'], photo: 'https://lh3.googleusercontent.com/a=s100'),
          _person('c2', ['andy@x.com'], photo: 'https://lh3.googleusercontent.com/b=s100', placeholder: true),
        ],
        'nextSyncToken': 'tok1',
      });
      await sync.syncNow();

      final tina = await contact('tina@x.com');
      expect(tina.inAddressBook, isTrue);
      expect(File(tina.photoPath!).readAsBytesSync(), [1, 2, 3]);
      expect(google.calls, contains('GET lh3.googleusercontent.com/a=s144'));

      final andy = await contact('andy@x.com');
      expect(andy.inAddressBook, isTrue);
      expect(andy.photoPath, isNull, reason: "Google's placeholder is not a photo");
      expect((await contact('stranger@x.com')).inAddressBook, isFalse);

      expect((await db.peopleRows()).firstWhere((r) => r.rowKey == 'c:tina@x.com').photoPath, tina.photoPath);
      expect(await db.getSetting(ContactsSync.syncTokenKey), 'tok1');
      expect(tina.classification, 'people');
      expect(tina.classReasons, 'In your contacts');
    });

    test('a merged person gets the photo from either address, and new senders get theirs on the next pass', () async {
      await sender('andrea@one.com', 'Andrea');
      await sender('andrea@two.com', 'Andrea J');
      await ClassificationService(db).mergePeople('andrea@one.com', ['andrea@two.com']);
      google.pages.add({
        'connections': [_person('c1', ['andrea@two.com', 'late@x.com'], photo: 'https://lh3.googleusercontent.com/a=s100')],
        'nextSyncToken': 'tok1',
      });
      await sync.syncNow();
      expect((await contact('andrea@one.com')).photoPath, isNotNull);

      await sender('late@x.com', 'Late');
      await db.applyAddressBook();
      expect((await contact('late@x.com')).inAddressBook, isTrue, reason: 'no new Google call was needed');
    });

    test('later syncs use the token; an expired token starts over; deleted people lose their photo and status', () async {
      await sender('tina@x.com', 'Tina');
      google.pages
        ..add({'connections': [_person('c1', ['tina@x.com'], photo: 'https://lh3.googleusercontent.com/a=s100')], 'nextSyncToken': 'tok1'})
        ..add({'connections': [_person('c1', ['tina@x.com'], photo: 'https://lh3.googleusercontent.com/a=s100')], 'nextSyncToken': 'tok2'})
        ..add({
          'connections': [
            {'resourceName': 'people/c1', 'metadata': {'deleted': true}},
          ],
          'nextSyncToken': 'tok3',
        });
      await sync.syncNow();
      final photo = (await contact('tina@x.com')).photoPath!;
      final downloads = google.calls.where((c) => c.contains('lh3')).length;

      google.expireSyncToken = true;
      await sync.syncNow();
      expect(await db.getSetting(ContactsSync.syncTokenKey), 'tok2');
      expect(google.calls.where((c) => c.contains('lh3')).length, downloads, reason: 'an unchanged photo is not downloaded again');

      await sync.syncNow();
      final tina = await contact('tina@x.com');
      expect(tina.inAddressBook, isFalse);
      expect(tina.photoPath, isNull);
      expect(File(photo).existsSync(), isFalse);
    });

    test('disconnect removes the permission, the photos and the saved contacts, and keeps the client file', () async {
      await sender('tina@x.com', 'Tina');
      google.pages.add({'connections': [_person('c1', ['tina@x.com'], photo: 'https://lh3.googleusercontent.com/a=s100')], 'nextSyncToken': 'tok1'});
      await sync.syncNow();
      await sync.disconnect();

      expect(await oauth.isConnected, isFalse);
      expect(await oauth.hasClient, isTrue);
      expect(dir.existsSync(), isFalse);
      expect(await db.addressBookEntries(), isEmpty);
      final tina = await contact('tina@x.com');
      expect(tina.photoPath, isNull);
      expect(tina.inAddressBook, isFalse);
      expect(google.calls, contains('POST oauth2.googleapis.com/revoke'));
    });
  });
}
