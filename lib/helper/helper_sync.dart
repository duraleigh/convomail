import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_log.dart';
import '../platform/credential_store.dart';
import '../store/database.dart';
import '../store/helper_queries.dart';
import '../store/people_queries.dart';
import '../sync/classification_service.dart';
import 'helper_client.dart';

/// The web call the helper client uses; tests put a stand-in here.
final helperHttpProvider = Provider<HelperHttp>((ref) => defaultHelperHttp);

/// Whether Précis is open and in front of the user on this PC. Phones
/// never say so: only a PC's screen silences a phone.
final appInFrontProvider = Provider<bool Function()>((ref) => () {
      if (!Platform.isWindows) return false;
      try {
        return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      } catch (_) {
        return false;
      }
    });

/// Called when the helper says this device was signed out. A device that
/// joined by code wipes its own copy (see device_join.dart); returns true
/// when it did.
final signedOutHandlerProvider = Provider<Future<bool> Function()>((ref) => () async => false);

/// How this device stands with the helper.
class HelperLink {
  const HelperLink({
    this.loaded = false,
    this.address,
    this.deviceId = 0,
    this.deviceName = '',
    this.busy = false,
    this.error,
    this.inStepAt,
    this.sentUp = false,
    this.sendingDone = 0,
    this.sendingTotal = 0,
    this.status,
    this.devices = const [],
    this.sendingRev,
    this.alertsReady = false,
  });

  final bool loaded;

  /// The helper's address; null when this device follows no helper.
  final String? address;
  final int deviceId;
  final String deviceName;

  /// Connecting, or sending up what this device knows for the first time.
  final bool busy;

  /// The last problem, in words for the user; null when all is well.
  final String? error;

  /// When this device and the helper last agreed.
  final DateTime? inStepAt;

  /// Whether the first sending-up of what this device knows has finished.
  final bool sentUp;
  final int sendingDone;
  final int sendingTotal;

  /// The helper's own state as last read (its mailbox, first read, timer).
  final Map<String, Object?>? status;
  final List<Map<String, Object?>> devices;

  /// The helper's count of changes to the addresses the user sends from;
  /// when it moves, this device fetches them again.
  final int? sendingRev;

  /// Alerts to phones are set up on the helper's page.
  final bool alertsReady;

  bool get connected => address != null;

  HelperLink copyWith({
    bool? loaded,
    String? Function()? address,
    int? deviceId,
    String? deviceName,
    bool? busy,
    String? Function()? error,
    DateTime? inStepAt,
    bool? sentUp,
    int? sendingDone,
    int? sendingTotal,
    Map<String, Object?>? Function()? status,
    List<Map<String, Object?>>? devices,
    int? sendingRev,
    bool? alertsReady,
  }) =>
      HelperLink(
        loaded: loaded ?? this.loaded,
        address: address == null ? this.address : address(),
        deviceId: deviceId ?? this.deviceId,
        deviceName: deviceName ?? this.deviceName,
        busy: busy ?? this.busy,
        error: error == null ? this.error : error(),
        inStepAt: inStepAt ?? this.inStepAt,
        sentUp: sentUp ?? this.sentUp,
        sendingDone: sendingDone ?? this.sendingDone,
        sendingTotal: sendingTotal ?? this.sendingTotal,
        status: status == null ? this.status : status(),
        devices: devices ?? this.devices,
        sendingRev: sendingRev ?? this.sendingRev,
        alertsReady: alertsReady ?? this.alertsReady,
      );
}

final helperProvider = NotifierProvider<HelperSync, HelperLink>(HelperSync.new);

/// The setting that remembers whether the helper's assistant is on ('1')
/// or off ('0'), as the helper last said.
const kAssistantOn = 'helper.assistantOn';

/// Keeps this device in step with the helper: sends up what the user
/// changes here, takes in what the helper decided and what other devices
/// changed. If the helper cannot be reached, Précis carries on by itself and
/// tries again; nothing waits on the helper.
class HelperSync extends Notifier<HelperLink> {
  static const _kUrl = 'helper.url';
  static const _kDevice = 'helper.device';
  static const _kName = 'helper.name';
  static const _kCursor = 'helper.cursor';
  static const _kSentUp = 'helper.sentUp';
  static const _kSeedAt = 'helper.seedAt';
  static const _kSeedIndex = 'helper.seedIndex';
  static const tokenKey = 'helper.token';

  /// How often the helper is asked what changed.
  static const interval = Duration(seconds: 20);

  Timer? _timer;
  StreamSubscription<int>? _outbox;
  Timer? _soon;
  Future<void>? _round;
  bool _again = false;
  Future<void>? _sendingUp;
  bool get _sending => _sendingUp != null;
  bool _stopped = false;

  /// The last unexpected failure, for the log and for tests.
  Object? lastFailure;

  AppDatabase get _db => ref.read(databaseProvider);
  CredentialStore get _vault => ref.read(credentialStoreProvider);

  @override
  HelperLink build() {
    ref.onDispose(() {
      _stopped = true;
      _timer?.cancel();
      _soon?.cancel();
      _outbox?.cancel();
    });
    return const HelperLink();
  }

  Future<HelperClient?> _client() async {
    final url = state.address ?? await _db.getSetting(_kUrl);
    if (url == null || url.isEmpty) return null;
    final token = await _vault.read(tokenKey);
    if (token == null || token.isEmpty) return null;
    return HelperClient(url, token: token, http: ref.read(helperHttpProvider), inFront: ref.read(appInFrontProvider));
  }

  /// The link to the helper for other parts of the app (the mailbox pass,
  /// the sending addresses, alerts); null when this device follows none.
  Future<HelperClient?> client() => _client();

  /// The helper's address as kept in this device's notes, for parts that
  /// work outside the app (a phone's alerts).
  static const urlKey = _kUrl;

  /// Reads how things stand from this device's own notes.
  Future<void> load() async {
    final url = await _db.getSetting(_kUrl);
    final has = url != null && url.isNotEmpty && ((await _vault.read(tokenKey)) ?? '').isNotEmpty;
    if (!has && await _db.helperConnected()) await _db.setHelperConnected(false);
    state = state.copyWith(
      loaded: true,
      address: () => has ? url : null,
      deviceId: int.tryParse(await _db.getSetting(_kDevice) ?? '') ?? 0,
      deviceName: await _db.getSetting(_kName) ?? '',
      sentUp: (await _db.getSetting(_kSentUp) ?? '').isNotEmpty,
    );
  }

  /// Starts keeping in step, if this device follows a helper. Call once the
  /// app is up.
  Future<void> start() async {
    await load();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(syncNow()));
    // Something the user changed goes up within a couple of seconds.
    await _outbox?.cancel();
    _outbox = _db.watchHelperOutboxCount().listen((n) {
      if (n == 0 || !state.connected) return;
      _soon?.cancel();
      _soon = Timer(const Duration(seconds: 2), () => unawaited(syncNow()));
    });
    if (state.connected) unawaited(_resume());
  }

  Future<void>? _resuming;

  Future<void> _resume() => _resuming = () async {
        try {
          if (!state.sentUp) await sendUpEverything();
          await syncNow();
        } catch (e, st) {
          // Closing the app mid-way lands here; anything else is worth a note.
          if (_stopped) return;
          lastFailure = e;
          AppLog.current?.error('getting in step with the helper failed', AppLog.scrub(e), st);
        }
      }();

  /// Completes when nothing is on its way to or from the helper.
  Future<void> idle() async {
    while (_resuming != null || _sendingUp != null || _round != null) {
      final waiting = [_resuming, _sendingUp, _round].whereType<Future<void>>().toList();
      _resuming = null;
      await Future.wait(waiting);
    }
  }

  /// Joins the helper at [address] with a joining [code] from its page.
  /// A [fresh] device has nothing of its own to send up: it only takes in.
  Future<void> connect(String address, String code, {String? name, bool fresh = false}) async {
    if (state.connected) throw const HelperException('This PC already follows a helper. Disconnect it first.');
    final http = ref.read(helperHttpProvider);
    state = state.copyWith(busy: true, error: () => null);
    try {
      final open = HelperClient(address, http: http);
      await open.ping();
      final deviceName = (name ?? '').trim().isEmpty ? Platform.localHostname : name!.trim();
      final joined = await open.pair(code, name: deviceName, kind: Platform.isAndroid ? 'android' : 'windows');
      await _vault.write(tokenKey, joined.token);
      await _db.putSetting(_kUrl, open.base.toString());
      await _db.putSetting(_kDevice, '${joined.device}');
      await _db.putSetting(_kName, deviceName);
      await _db.putSetting(_kCursor, '0');
      await _db.putSetting(_kSentUp, fresh ? '${DateTime.now().millisecondsSinceEpoch ~/ 1000}' : '');
      await _db.putSetting(_kSeedAt, '');
      await _db.putSetting(_kSeedIndex, '0');
      await _db.setHelperConnected(true);
      state = state.copyWith(address: () => open.base.toString(), deviceId: joined.device, deviceName: deviceName, sentUp: fresh, sendingDone: 0, sendingTotal: 0);
    } on HelperException catch (e) {
      state = state.copyWith(busy: false, error: () => e.message);
      rethrow;
    }
    unawaited(_resume());
  }

  /// Sends up what this device knows, the first time it joins: its tags,
  /// rules and choices, then every sender with the facts behind it. Can be
  /// stopped and picked up again where it left off.
  Future<void> sendUpEverything() => _sendingUp ??= _sendUp().whenComplete(() {
        _sendingUp = null;
        if (!_stopped && state.busy) state = state.copyWith(busy: false);
      });

  Future<void> _sendUp() async {
    final client = await _client();
    if (client == null) return;
    state = state.copyWith(busy: true, error: () => null);
    try {
      var at = int.tryParse(await _db.getSetting(_kSeedAt) ?? '');
      if (at == null) {
        at = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await _db.noteEverythingForHelper();
        final ids = await _db.myMessageIds();
        for (var i = 0; i < ids.length; i += 4000) {
          await client.seed(const [], at: at, myIds: ids.sublist(i, i + 4000 > ids.length ? ids.length : i + 4000));
        }
        // Noted only once that much is up, so a stop before here starts over.
        await _db.putSetting(_kSeedAt, '$at');
      }
      await _pushOutbox(client);
      final keys = await _db.senderKeysForSeed();
      var index = int.tryParse(await _db.getSetting(_kSeedIndex) ?? '') ?? 0;
      state = state.copyWith(sendingDone: index, sendingTotal: keys.length);
      const chunk = 100;
      while (index < keys.length && !_stopped) {
        final part = <Map<String, Object?>>[];
        for (final key in keys.sublist(index, index + chunk > keys.length ? keys.length : index + chunk)) {
          final seed = await _db.senderSeed(key);
          if (seed != null) part.add(seed);
        }
        await client.seed(part, at: at);
        index += chunk;
        await _db.putSetting(_kSeedIndex, '$index');
        state = state.copyWith(sendingDone: index > keys.length ? keys.length : index);
      }
      if (_stopped) return;
      await _db.putSetting(_kSentUp, '$at');
      state = state.copyWith(busy: false, sentUp: true, sendingDone: keys.length);
    } on HelperException catch (e) {
      await _problem(e);
    }
  }

  /// One round: send up what waits, take in what changed. Rounds never
  /// overlap: a call made while one is running waits for it and for one
  /// more after it, so whatever the caller just changed is included.
  Future<void> syncNow() {
    if (!state.connected || _stopped) return Future.value();
    final running = _round;
    if (running != null) {
      _again = true;
      return running;
    }
    return _round = _rounds().whenComplete(() => _round = null);
  }

  Future<void> _rounds() async {
    do {
      _again = false;
      await _oneRound();
    } while (_again && !_stopped && state.connected);
  }

  Future<void> _oneRound() async {
    try {
      final client = await _client();
      if (client == null) return;
      await _pushOutbox(client);
      await _pull(client);
      if (_stopped) return;
      state = state.copyWith(inStepAt: DateTime.now(), error: () => null, busy: _sending);
    } on HelperException catch (e) {
      await _problem(e);
    } catch (e, st) {
      AppLog.current?.error('keeping in step with the helper failed', AppLog.scrub(e), st);
      lastFailure = e;
      if (!_stopped) state = state.copyWith(busy: _sending, error: () => 'Something went wrong while keeping in step. Précis carries on by itself and tries again.');
    }
  }

  Future<void> _problem(HelperException e) async {
    if (_stopped) return;
    if (e.signedOut) {
      // A device that joined by code has nothing without the helper: it
      // wipes its own copy. The PC that set Précis up keeps everything and
      // carries on by itself.
      final wiped = await ref.read(signedOutHandlerProvider)();
      await _forget();
      state = HelperLink(
        loaded: true,
        error: wiped
            ? 'This device was signed out. Its copy of your mail was removed. Join again with a new code.'
            : 'This PC was signed out of the helper. Précis carries on by itself. Join again with a new code to follow the helper.',
      );
      return;
    }
    state = state.copyWith(busy: _sending, error: () => e.unreachable ? '${e.message} Précis carries on by itself and tries again.' : e.message);
  }

  Future<void> _pushOutbox(HelperClient client) async {
    while (!_stopped) {
      final rows = await _db.helperOutboxBatch();
      if (rows.isEmpty) return;
      final entries = <Map<String, Object?>>[];
      for (final o in rows) {
        entries.addAll([for (final e in await _db.helperEntriesFor(o)) e.toJson()]);
      }
      try {
        if (entries.isNotEmpty) await client.push(entries);
      } on HelperException catch (e) {
        if (e.unreachable || e.signedOut) rethrow;
        // The helper refused something in this batch. Send them one at a
        // time so one bad change cannot hold up the rest; what is refused
        // on its own is dropped.
        for (final entry in entries) {
          try {
            await client.push([entry]);
          } on HelperException catch (one) {
            if (one.unreachable || one.signedOut) rethrow;
            AppLog.current?.warn('the helper refused a change', '${entry['kind'] ?? entry['op']}: ${one.message}');
          }
        }
      }
      await _db.clearHelperOutbox(rows.map((o) => o.id));
    }
  }

  Future<void> _pull(HelperClient client) async {
    var cursor = int.tryParse(await _db.getSetting(_kCursor) ?? '') ?? 0;
    while (!_stopped) {
      final page = await client.changes(cursor);
      final refile = <String>{};
      // A hundred at a time, so the lists on screen are never kept waiting
      // behind a whole page of five hundred.
      for (var at = 0; at < page.items.length; at += 100) {
        await _db.applyingFromHelper(() async {
          for (final i in page.items.skip(at).take(100)) {
            final data = i['data'];
            refile.addAll(await _db.applyHelperItem('${i['kind']}', '${i['k']}', data is Map ? data.cast<String, Object?>() : const {}, deleted: i['deleted'] == true));
          }
        });
      }
      if (page.next != cursor) {
        cursor = page.next;
        await _db.putSetting(_kCursor, '$cursor');
      }
      if (!_stopped && (page.sending != null && page.sending != state.sendingRev || page.alerts != null && page.alerts != state.alertsReady)) {
        state = state.copyWith(sendingRev: page.sending, alertsReady: page.alerts);
      }
      // Whether the assistant is on: its readings show only while it is.
      final assistant = page.assistant;
      if (assistant != null && (await _db.getSetting(kAssistantOn) ?? '') != (assistant ? '1' : '0')) {
        await _db.putSetting(kAssistantOn, assistant ? '1' : '0');
      }
      if (refile.isNotEmpty) {
        // Mail from senders the helper decided is filed where the helper says.
        await ref.read(classificationServiceProvider).classifySenders(refile, log: false);
      }
      await _db.refreshDirtyRows();
      if (!page.more) return;
    }
  }

  /// Reads the helper's own state and its list of devices, for Settings.
  Future<void> refreshStatus() async {
    final client = await _client();
    if (client == null) return;
    try {
      final status = await client.status();
      final list = await client.devices();
      state = state.copyWith(status: () => status, devices: list.devices, error: () => null);
    } on HelperException catch (e) {
      await _problem(e);
    }
  }

  /// Turns the assistant on or off for every device, or sets its monthly
  /// ceiling. Off means nothing more is sent to it and its readings hide.
  Future<void> setAssistant({bool? on, int? ceilingMicro}) async {
    final client = await _client();
    if (client == null) throw const HelperException('This PC does not follow a helper.');
    final a = await client.setAssistant(on: on, ceiling: ceilingMicro);
    if (a['on'] is bool) await _db.putSetting(kAssistantOn, a['on'] == true && a['hasKey'] == true ? '1' : '0');
    final status = {...?state.status, 'assistant': a};
    state = state.copyWith(status: () => status, error: () => null);
  }

  /// A joining code for the next device, good for ten minutes.
  Future<String> newDeviceCode() async {
    final client = await _client();
    if (client == null) throw const HelperException('This PC does not follow a helper.');
    return client.newCode();
  }

  Future<void> signOutDevice(int id) async {
    final client = await _client();
    if (client == null) return;
    await client.signOut(id);
    await refreshStatus();
  }

  /// Stops following the helper. What this device has stays; from here on
  /// it sorts by itself again.
  Future<void> disconnect() async {
    final client = await _client();
    if (client != null) {
      try {
        await client.signOut(state.deviceId);
      } on HelperException {
        // Unreachable or already signed out: forgetting it here still happens.
      }
    }
    await _forget();
    state = const HelperLink(loaded: true);
  }

  Future<void> _forget() async {
    await _vault.delete(tokenKey);
    for (final k in const [_kUrl, _kDevice, _kName, _kCursor, _kSentUp, _kSeedAt, _kSeedIndex]) {
      await _db.putSetting(k, '');
    }
    await _db.setHelperConnected(false);
  }
}
