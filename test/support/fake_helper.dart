import 'dart:convert';
import 'dart:io';

import 'package:convomail/helper/helper_client.dart';

/// A stand-in for the helper that speaks its protocol from memory: joining
/// by code, one stream of items, pushes from devices, the first sending-up.
/// No test reaches a real helper through this.
class FakeHelper {
  final Map<String, ({Map<String, Object?> data, bool deleted, int seq, int? origin})> items = {};
  int seq = 0;

  /// Tokens of devices that joined, by device id.
  final Map<int, String> tokens = {};
  final Map<int, String> names = {};
  String? code = 'GOODCODE';

  /// Everything devices sent with a push, in order.
  final List<Map<String, Object?>> pushed = [];

  /// Senders received in the first sending-up, and Message-IDs of sent mail.
  final List<Map<String, Object?>> seeded = [];
  final Set<String> myIds = {};
  int? seedAt;

  /// When true, every call fails as an unplugged network would.
  bool unreachable = false;

  /// How the assistant is doing, as the real helper reports it.
  Map<String, Object?> assistant = {'hasKey': false, 'on': false, 'model': '', 'modelName': '', 'ceiling': 10000000, 'month': 0, 'today': 0, 'problem': '', 'problemKind': '', 'waiting': 0, 'read': 0, 'focus': 0};

  /// The clock offset the device last sent, in minutes.
  String? zone;

  /// Kinds the helper refuses, to check one bad change cannot block others.
  final Set<String> refuse = {};
  int calls = 0;
  int seedCalls = 0;

  /// Stops the first sending-up after this many sender batches (as if the
  /// app were closed part-way); null lets it finish.
  int? failSeedAfter;

  String _key(String kind, String k) => '$kind\u0000$k';

  /// The helper itself writes an item (a decision, or a change from another
  /// device).
  void put(String kind, String k, Map<String, Object?> data, {int? origin}) {
    items[_key(kind, k)] = (data: data, deleted: false, seq: ++seq, origin: origin);
  }

  void remove(String kind, String k, {int? origin}) {
    items[_key(kind, k)] = (data: const {}, deleted: true, seq: ++seq, origin: origin);
  }

  Map<String, Object?>? item(String kind, String k) {
    final i = items[_key(kind, k)];
    return i == null || i.deleted ? null : i.data;
  }

  bool gone(String kind, String k) => items[_key(kind, k)]?.deleted ?? false;

  /// Everything pushed of one kind, newest last.
  List<Map<String, Object?>> pushedOf(String kind) => [for (final p in pushed) if (p['kind'] == kind) p];

  Future<HelperResponse> call(String method, Uri uri, {Map<String, String> headers = const {}, String? body}) async {
    calls++;
    if (unreachable) throw const SocketException('no route');
    HelperResponse json(Object data, [int status = 200]) => HelperResponse(status, jsonEncode(data));
    final j = body == null || body.isEmpty ? const <String, Object?>{} : (jsonDecode(body) as Map).cast<String, Object?>();
    final path = uri.path;
    if (path == '/api/ping') return json({'ok': true, 'version': 'fake'});
    if (path == '/api/pair') {
      if (code == null || '${j['code']}'.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase() != code) return json({'error': 'That code is not right, or it is more than 10 minutes old.'}, 403);
      code = null;
      final id = tokens.length + 1;
      tokens[id] = '$id.token-for-device-$id-xxxxxxxxxxxxxxxxxxxx';
      names[id] = '${j['name']}';
      return json({'device': id, 'token': tokens[id], 'seq': 0});
    }
    final token = headers['X-Precis-Token'];
    zone = headers['X-Precis-Zone'] ?? zone;
    final device = tokens.entries.where((e) => e.value == token).map((e) => e.key).firstOrNull;
    if (device == null) return json({'error': 'This device is not signed in to the helper.'}, 401);
    switch ('$method $path') {
      case 'GET /api/changes':
        final since = int.tryParse(uri.queryParameters['since'] ?? '') ?? 0;
        final rows = items.entries.where((e) => e.value.seq > since).toList()..sort((a, b) => a.value.seq.compareTo(b.value.seq));
        final page = rows.take(500).toList();
        return json({
          'items': [
            for (final e in page)
              if (e.value.origin != device) {'kind': e.key.split('\u0000')[0], 'k': e.key.split('\u0000')[1], 'data': e.value.data, 'deleted': e.value.deleted, 'seq': e.value.seq},
          ],
          'next': page.isEmpty ? since : page.last.value.seq,
          'more': rows.length > 500,
          'assistant': assistant['on'] == true && assistant['hasKey'] == true,
        });
      case 'POST /api/assistant':
        if (j['ceiling'] is int) assistant = {...assistant, 'ceiling': j['ceiling']};
        if (j['on'] is bool) {
          if (j['on'] == true && assistant['hasKey'] != true) return json({'error': 'The assistant has no key or reader yet. Set it on the helper’s page.'}, 409);
          assistant = {...assistant, 'on': j['on']};
        }
        return json({'assistant': assistant});
      case 'POST /api/push':
        final list = [for (final i in (j['items'] as List?) ?? const []) (i as Map).cast<String, Object?>()];
        for (final i in list) {
          if (refuse.contains(i['kind'] ?? i['op'])) return json({'error': 'That kind of change is not one a device may send.'}, 400);
        }
        for (final i in list) {
          pushed.add(i);
          if (i['op'] != null) continue;
          if (i['deleted'] == true) {
            remove('${i['kind']}', '${i['k']}', origin: device);
          } else {
            put('${i['kind']}', '${i['k']}', (i['data'] as Map).cast<String, Object?>(), origin: device);
          }
        }
        return json({'applied': list.length, 'seq': seq});
      case 'POST /api/seed':
        final senders = [for (final s in (j['senders'] as List?) ?? const []) (s as Map).cast<String, Object?>()];
        if (senders.isNotEmpty) {
          seedCalls++;
          if (failSeedAfter != null && seedCalls > failSeedAfter!) throw const SocketException('closed part-way');
        }
        seedAt = (j['at'] as num?)?.toInt();
        myIds.addAll([for (final m in (j['myIds'] as List?) ?? const []) '$m']);
        for (final s in senders) {
          seeded.add(s);
          put('sender', '${s['k']}', (s['item'] as Map).cast<String, Object?>(), origin: device);
        }
        return json({'senders': senders.length, 'seq': seq});
      case 'GET /api/status':
        return json({
          'version': 'fake',
          'now': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'seq': seq,
          'device': {'id': device, 'name': names[device], 'kind': 'windows'},
          'accounts': [
            {'email': 'me@example.com', 'lastChecked': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 30, 'firstReadDone': false, 'firstRead': 200, 'notice': false, 'error': null},
          ],
          'timer': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 20,
          'emails': 200,
          'assistant': assistant,
        });
      case 'GET /api/devices':
        return json({
          'devices': [for (final e in names.entries) if (tokens.containsKey(e.key)) {'id': e.key, 'name': e.value, 'kind': 'windows', 'created': 1, 'last_seen': DateTime.now().millisecondsSinceEpoch ~/ 1000, 'revoked': 0}],
          'me': device,
        });
      case 'POST /api/devices/code':
        code = 'NEXTCODE';
        return json({'code': code, 'minutes': 10});
      case 'POST /api/devices/signout':
        tokens.remove((j['id'] as num?)?.toInt() ?? device);
        return json({'ok': true});
    }
    return json({'error': 'The helper does not know that address.'}, 404);
  }

  /// Signs a device out from "another device".
  void signOut(int id) => tokens.remove(id);
}
