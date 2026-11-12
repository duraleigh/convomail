import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// An answer from the helper.
class HelperResponse {
  const HelperResponse(this.status, this.body);
  final int status;
  final String body;

  Map<String, Object?> get json {
    try {
      final v = jsonDecode(body);
      return v is Map ? v.cast<String, Object?>() : const {};
    } on FormatException {
      return const {};
    }
  }
}

/// The web call, replaceable in tests.
typedef HelperHttp = Future<HelperResponse> Function(String method, Uri uri, {Map<String, String> headers, String? body});

Future<HelperResponse> defaultHelperHttp(String method, Uri uri, {Map<String, String> headers = const {}, String? body}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.openUrl(method, uri);
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      request.add(utf8.encode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 60));
    final text = await utf8.decodeStream(response).timeout(const Duration(seconds: 60));
    return HelperResponse(response.statusCode, text);
  } finally {
    client.close(force: true);
  }
}

/// Why talking to the helper failed, in words for the user.
class HelperException implements Exception {
  const HelperException(this.message, {this.signedOut = false, this.unreachable = false});
  final String message;

  /// The helper no longer knows this device (signed out from another one).
  final bool signedOut;

  /// The helper could not be reached at all; worth trying again later.
  final bool unreachable;

  @override
  String toString() => message;
}

/// The few calls a device makes to the helper.
class HelperClient {
  HelperClient(String base, {this.token, HelperHttp? http, this.inFront})
      : base = normalizeBase(base),
        _http = http ?? defaultHelperHttp;

  final Uri base;
  final String? token;
  final HelperHttp _http;

  /// Whether Précis is open and in front of the user on this PC right now.
  /// The helper is told, so a phone does not ring for what is already on
  /// screen here.
  final bool Function()? inFront;

  /// `precis.example.com`, with or without `https://`, becomes a web
  /// address. Only https is allowed, except to this same computer.
  static Uri normalizeBase(String input) {
    var s = input.trim();
    if (s.isEmpty) throw const HelperException('Type the helper’s address.');
    if (!s.contains('://')) s = 'https://$s';
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) throw const HelperException('That does not look like a web address.');
    final local = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) throw const HelperException('The helper’s address must start with https://');
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null);
  }

  HelperClient withToken(String token) => HelperClient(base.toString(), token: token, http: _http, inFront: inFront);

  Future<Map<String, Object?>> _call(String method, String path, {Map<String, Object?>? body, Map<String, String>? query}) async {
    final HelperResponse r;
    try {
      // The clock offset lets the helper say "by 3:00 PM" in this user's own time.
      r = await _http(
        method,
        base.replace(path: path, queryParameters: query),
        headers: {
          'X-Precis-Token': ?token,
          'Accept': 'application/json',
          'X-Precis-Zone': '${DateTime.now().timeZoneOffset.inMinutes}',
          if (inFront?.call() ?? false) 'X-Precis-Front': '1',
        },
        body: body == null ? null : jsonEncode(body),
      );
    } on SocketException {
      throw const HelperException('The helper could not be reached.', unreachable: true);
    } on TimeoutException {
      throw const HelperException('The helper did not answer in time.', unreachable: true);
    } on HandshakeException {
      throw const HelperException('The helper’s address did not prove who it is (its certificate was refused).', unreachable: true);
    } on HttpException {
      throw const HelperException('The helper could not be reached.', unreachable: true);
    }
    if (r.status >= 200 && r.status < 300) return r.json;
    final said = r.json['error'];
    if (r.status == 401) throw HelperException(said is String ? said : 'This device is not signed in to the helper.', signedOut: true);
    if (r.status >= 500 || r.status == 404 && said is! String) {
      throw HelperException(said is String ? said : 'The helper is not answering as it should (${r.status}).', unreachable: true);
    }
    throw HelperException(said is String ? said : 'The helper said no (${r.status}).');
  }

  /// Checks that a Précis helper lives at the address.
  Future<String> ping() async {
    final r = await _call('GET', '/api/ping');
    if (r['ok'] != true) throw const HelperException('That address answered, but it is not a Précis helper.');
    return (r['version'] as String?) ?? '';
  }

  /// Trades a joining code for this device's own token.
  Future<({int device, String token})> pair(String code, {required String name, required String kind}) async {
    final r = await _call('POST', '/api/pair', body: {'code': code, 'name': name, 'kind': kind});
    final token = r['token'];
    if (token is! String || token.isEmpty) throw const HelperException('The helper did not let this device in.');
    return (device: (r['device'] as num?)?.toInt() ?? 0, token: token);
  }

  Future<({List<Map<String, Object?>> items, int next, bool more, bool? assistant, int? sending, bool? alerts})> changes(int since) async {
    final r = await _call('GET', '/api/changes', query: {'since': '$since'});
    return (
      items: [for (final i in (r['items'] as List?) ?? const []) (i as Map).cast<String, Object?>()],
      next: (r['next'] as num?)?.toInt() ?? since,
      more: r['more'] == true,
      assistant: r['assistant'] is bool ? r['assistant'] as bool : null,
      sending: (r['sending'] as num?)?.toInt(),
      alerts: r['alerts'] is bool ? r['alerts'] as bool : null,
    );
  }

  /// Whose mailbox the helper holds, and what Google allows it.
  Future<({String email, String name, bool mail, bool calendar, bool contacts})> account() async {
    final r = await _call('GET', '/api/account');
    final g = r['grants'] is Map ? (r['grants'] as Map) : const <Object?, Object?>{};
    return (email: '${r['email'] ?? ''}', name: '${r['name'] ?? ''}', mail: g['mail'] == true, calendar: g['calendar'] == true, contacts: g['contacts'] == true);
  }

  /// A pass to the mailbox, good for about an hour. The lasting sign-in
  /// never leaves the helper.
  Future<({String email, String access, DateTime until})> googlePass() async {
    final r = await _call('GET', '/api/google/token');
    final access = r['access'];
    if (access is! String || access.isEmpty) throw const HelperException('The helper gave no pass to the mailbox.');
    final now = (r['now'] as num?)?.toInt() ?? 0;
    final expires = (r['expires'] as num?)?.toInt() ?? 0;
    // By this device's own clock: however long the helper says is left.
    final left = Duration(seconds: expires > now ? expires - now : 600);
    return (email: '${r['email'] ?? ''}', access: access, until: DateTime.now().add(left));
  }

  /// The addresses the user sends from, with what each needs to send.
  Future<({List<Map<String, Object?>> addresses, int rev})> sending() async {
    final r = await _call('GET', '/api/sending');
    return (addresses: [for (final a in (r['addresses'] as List?) ?? const []) (a as Map).cast<String, Object?>()], rev: (r['rev'] as num?)?.toInt() ?? 0);
  }

  Future<int> putSending(List<Map<String, Object?>> addresses) async => ((await _call('POST', '/api/sending', body: {'addresses': addresses}))['rev'] as num?)?.toInt() ?? 0;

  /// What a phone needs to sign up with Google's alert service; null until
  /// alerts are set up on the helper's page.
  Future<Map<String, String>?> alerts() async {
    final r = await _call('GET', '/api/alerts');
    final app = r['app'];
    return r['ready'] == true && app is Map ? {for (final e in app.entries) '${e.key}': '${e.value}'} : null;
  }

  /// Tells the helper where to send this phone its alerts, and whether it may ring.
  /// It also says this app can show a sign-in code alert, so the helper
  /// sends them here.
  Future<void> setPush({String? token, bool? ring}) => _call('POST', '/api/devices/push', body: {'token': ?token, 'ring': ?ring, 'codes': true});

  /// Turns the assistant on or off, or sets its monthly ceiling (in
  /// millionths of a dollar). Returns how the assistant is doing after.
  Future<Map<String, Object?>> setAssistant({bool? on, int? ceiling}) async {
    final r = await _call('POST', '/api/assistant', body: {'on': ?on, 'ceiling': ?ceiling});
    final a = r['assistant'];
    return a is Map ? a.cast<String, Object?>() : const {};
  }

  /// With [echo], this device hears its own change back (used for changes
  /// made outside the app's own notes, such as from an alert).
  Future<void> push(List<Map<String, Object?>> items, {bool echo = false}) => _call('POST', '/api/push', body: {'items': items, if (echo) 'echo': true});

  Future<void> seed(List<Map<String, Object?>> senders, {required int at, List<String> myIds = const []}) => _call('POST', '/api/seed', body: {'senders': senders, 'at': at, 'myIds': myIds});

  Future<Map<String, Object?>> status() => _call('GET', '/api/status');

  Future<({List<Map<String, Object?>> devices, int me})> devices() async {
    final r = await _call('GET', '/api/devices');
    return (devices: [for (final d in (r['devices'] as List?) ?? const []) (d as Map).cast<String, Object?>()], me: (r['me'] as num?)?.toInt() ?? 0);
  }

  Future<String> newCode() async => ((await _call('POST', '/api/devices/code', body: const {}))['code'] as String?) ?? '';

  Future<void> signOut(int deviceId) => _call('POST', '/api/devices/signout', body: {'id': deviceId});
}
