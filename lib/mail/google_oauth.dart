import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../platform/credential_store.dart';

/// An HTTP answer, as bytes because photos come through here too.
class GoogleResponse {
  const GoogleResponse(this.status, this.bytes);
  final int status;
  final Uint8List bytes;
  String get text => utf8.decode(bytes, allowMalformed: true);
}

/// The HTTP call, replaceable in tests. [form] is sent as a web form,
/// [json] as JSON (calendar events).
typedef GoogleHttp = Future<GoogleResponse> Function(String method, Uri uri, {Map<String, String> headers, String? form, String? json});

Future<GoogleResponse> defaultGoogleHttp(String method, Uri uri, {Map<String, String> headers = const {}, String? form, String? json}) async {
  if (uri.scheme != 'https') throw const GoogleAuthException('Google requests must use https.');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (form != null) {
      request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.write(form);
    } else if (json != null) {
      request.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      request.add(utf8.encode(json));
    }
    final response = await request.close().timeout(const Duration(seconds: 30));
    final bytes = BytesBuilder(copy: false);
    await response.forEach(bytes.add).timeout(const Duration(seconds: 60));
    return GoogleResponse(response.statusCode, bytes.takeBytes());
  } finally {
    client.close(force: true);
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message, {this.needsReconnect = false});
  final String message;

  /// The saved permission is gone; only signing in again helps.
  final bool needsReconnect;

  @override
  String toString() => message;
}

/// Google sign-in for contacts (spec 4.2) and the calendar. The user
/// supplies their own OAuth client as a downloaded file, the browser does the
/// signing in, and the app only ever holds tokens, in Windows Credential
/// Manager. It asks for read-only contacts access and for the calendar
/// (shown in the Planner, and changed from there).
class GoogleOAuth {
  GoogleOAuth({required this.store, GoogleHttp? http, required this.openBrowser, DateTime Function()? clock})
      : http = http ?? defaultGoogleHttp,
        _clock = clock ?? DateTime.now;

  final CredentialStore store;
  final GoogleHttp http;
  final Future<void> Function(Uri uri) openBrowser;
  final DateTime Function() _clock;

  static const contactsScope = 'https://www.googleapis.com/auth/contacts.readonly';
  static const calendarScope = 'https://www.googleapis.com/auth/calendar';
  static const scope = '$contactsScope $calendarScope';
  static const clientKey = 'google.client';
  static const refreshKey = 'google.refreshToken';

  /// What Google granted at the last sign-in or token renewal (not secret).
  static const grantedKey = 'google.grantedScopes';
  static final _authUri = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth');
  static final _tokenUri = Uri.parse('https://oauth2.googleapis.com/token');

  String? _access;
  DateTime? _accessUntil;

  Future<bool> get hasClient async => await store.read(clientKey) != null;
  Future<bool> get isConnected async => await store.read(refreshKey) != null;

  /// Whether the saved permission covers the calendar. A connection made
  /// before calendar access was asked for does not; signing in again adds it.
  Future<bool> get hasCalendar async {
    if (!await isConnected) return false;
    var granted = await store.read(grantedKey);
    if (granted == null) {
      // Connected before this was kept: a renewal says what is granted.
      try {
        invalidateAccess();
        await accessToken();
      } on GoogleAuthException {
        return false;
      }
      granted = await store.read(grantedKey);
    }
    return (granted ?? '').split(' ').contains(calendarScope);
  }

  /// Checks and keeps the client file Google gives for a Desktop app.
  Future<void> saveClientFile(String fileContents) async {
    final (id, _) = _parseClient(fileContents);
    if (id.isEmpty) throw const GoogleAuthException('That file has no client ID.');
    await store.write(clientKey, fileContents);
  }

  static (String, String) _parseClient(String contents) {
    try {
      final o = jsonDecode(contents);
      final section = o is Map ? (o['installed'] ?? o['web']) : null;
      if (section is! Map) throw const FormatException();
      return ('${section['client_id'] ?? ''}', '${section['client_secret'] ?? ''}');
    } on FormatException {
      throw const GoogleAuthException('That is not an OAuth client file from Google. In the Google Cloud console, download the client created for a Desktop app.');
    }
  }

  /// Runs the browser sign-in and keeps the permission it returns.
  Future<void> connect({Duration timeout = const Duration(minutes: 5)}) async {
    final saved = await store.read(clientKey);
    if (saved == null) throw const GoogleAuthException('Choose your OAuth client file first.');
    final (clientId, clientSecret) = _parseClient(saved);

    final random = Random.secure();
    String token(int n) => base64Url.encode(List<int>.generate(n, (_) => random.nextInt(256))).replaceAll('=', '');
    final verifier = token(48);
    final state = token(16);
    final challenge = base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${server.port}';
    // Listening starts before the browser opens, so an answer can never
    // arrive before anyone waits for it.
    final answer = _awaitCode(server, state);
    // Kept from being reported as unhandled if opening the browser fails.
    unawaited(answer.then((_) {}, onError: (Object _) {}));
    try {
      await openBrowser(_authUri.replace(queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': scope,
        'access_type': 'offline',
        'prompt': 'consent',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      }));
      final code = await answer.timeout(timeout, onTimeout: () => throw const GoogleAuthException('Sign-in timed out. Try again.'));
      final response = await http('POST', _tokenUri, form: _form({
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirect,
      }));
      final body = _json(response);
      if (response.status != 200 || body['refresh_token'] == null) throw GoogleAuthException('Google did not grant access (${body['error'] ?? response.status}).');
      await store.write(refreshKey, '${body['refresh_token']}');
      await _keepGranted(body);
      _keepAccess(body);
    } finally {
      await server.close(force: true);
    }
  }

  Future<String> _awaitCode(HttpServer server, String state) async {
    await for (final request in server) {
      final query = request.uri.queryParameters;
      // Only the answer to this sign-in counts. Anything else on this port,
      // such as a browser asking for a favicon, is turned away.
      if (query['state'] != state) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      final error = query['error'];
      request.response.headers.contentType = ContentType.html;
      request.response.write('<!doctype html><title>Pr&eacute;cis</title><body style="font-family:sans-serif;margin:3em"><h2>${error == null ? 'Connected' : 'Not connected'}</h2><p>You can close this tab and go back to Précis.</p>');
      await request.response.close();
      if (error != null) throw GoogleAuthException('Sign-in did not finish ($error).');
      final code = query['code'];
      if (code == null) throw const GoogleAuthException('Google sent no sign-in code.');
      return code;
    }
    throw const GoogleAuthException('Sign-in stopped.');
  }

  /// A current access token, renewed when needed.
  Future<String> accessToken() async {
    final until = _accessUntil;
    if (_access != null && until != null && _clock().isBefore(until)) return _access!;
    final refresh = await store.read(refreshKey);
    final saved = await store.read(clientKey);
    if (refresh == null || saved == null) throw const GoogleAuthException('Google is not connected.', needsReconnect: true);
    final (clientId, clientSecret) = _parseClient(saved);
    final response = await http('POST', _tokenUri, form: _form({'client_id': clientId, 'client_secret': clientSecret, 'refresh_token': refresh, 'grant_type': 'refresh_token'}));
    final body = _json(response);
    if (response.status != 200) {
      if (body['error'] == 'invalid_grant') {
        await store.delete(refreshKey);
        throw const GoogleAuthException('Google needs to be connected again.', needsReconnect: true);
      }
      throw GoogleAuthException('Could not reach Google (${response.status}).');
    }
    await _keepGranted(body);
    _keepAccess(body);
    return _access!;
  }

  Future<void> _keepGranted(Map<String, dynamic> body) async {
    final granted = body['scope'];
    if (granted is String && granted.isNotEmpty) await store.write(grantedKey, granted);
  }

  void invalidateAccess() {
    _access = null;
    _accessUntil = null;
  }

  /// Forgets the permission here and tells Google to drop it. The client file
  /// stays, so connecting again takes one click.
  Future<void> disconnect() async {
    final refresh = await store.read(refreshKey);
    await store.delete(refreshKey);
    await store.delete(grantedKey);
    invalidateAccess();
    if (refresh == null) return;
    try {
      await http('POST', Uri.parse('https://oauth2.googleapis.com/revoke'), form: _form({'token': refresh}));
    } catch (_) {
      // Offline: it is forgotten here regardless.
    }
  }

  void _keepAccess(Map<String, dynamic> body) {
    _access = '${body['access_token']}';
    final seconds = body['expires_in'] is num ? (body['expires_in'] as num).toInt() : 3600;
    _accessUntil = _clock().add(Duration(seconds: seconds - 60));
  }

  static String _form(Map<String, String> fields) => [for (final e in fields.entries) '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}'].join('&');

  static Map<String, dynamic> _json(GoogleResponse r) {
    try {
      final o = jsonDecode(r.text);
      return o is Map<String, dynamic> ? o : const {};
    } catch (_) {
      return const {};
    }
  }
}
