import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_log.dart';
import '../app/conversation_state.dart';
import '../app/destinations.dart';
import '../app/mail_state.dart';
import '../app/people_state.dart';
import '../app/search_state.dart';
import '../helper/helper_client.dart';
import '../helper/helper_sync.dart';
import '../store/database.dart';
import '../store/mail_queries.dart';
import '../ui/shell/compact_shell.dart';
import 'android_bridge.dart';

/// The setting that says whether this phone may ring ('0' means it may not).
const kPhoneRing = 'alerts.ringHere';

/// How alerts stand on this phone, for Settings.
enum PhoneAlertState { notAPhone, notJoined, notSetUp, blocked, off, on, failed }

final phoneAlertStateProvider = NotifierProvider<PhoneAlertStateNotifier, PhoneAlertState>(PhoneAlertStateNotifier.new);

class PhoneAlertStateNotifier extends Notifier<PhoneAlertState> {
  @override
  PhoneAlertState build() => Platform.isAndroid ? PhoneAlertState.notJoined : PhoneAlertState.notAPhone;
  void set(PhoneAlertState s) => state = s;
}

/// Alerts on a phone: an email that needs you, a reminder at its time, one
/// notice an hour before a "by" time. The helper decides what rings; this
/// signs the phone up for it, sends on what was pressed with no signal, and
/// opens the right email when an alert is tapped.
class PhoneAlerts {
  PhoneAlerts(this._ref);
  final Ref _ref;
  StreamSubscription<String>? _opened;
  Future<void>? _setting;
  String? _sentToken;

  AndroidBridge get _bridge => _ref.read(androidBridgeProvider);
  AppDatabase get _db => _ref.read(databaseProvider);

  /// Call once the app is up. Does nothing on a PC.
  void start() {
    if (!Platform.isAndroid) return;
    _ref.listen(helperProvider.select((h) => (h.connected, h.alertsReady)), (_, _) => unawaited(setUp()), fireImmediately: true);
    _opened ??= _bridge.opened.listen((mid) => unawaited(open(mid)));
    unawaited(_bridge.takeOpened().then((mid) {
      if (mid != null && mid.isNotEmpty) return open(mid);
    }).catchError((Object _) {}));
  }

  void stop() => _opened?.cancel();

  /// Signs this phone up for alerts when everything needed is in place.
  /// With [ask], asks the user to allow alerts if the phone has not yet.
  Future<void> setUp({bool ask = true}) => _setting ??= _setUp(ask).whenComplete(() => _setting = null);

  Future<void> _setUp(bool ask) async {
    final state = _ref.read(phoneAlertStateProvider.notifier);
    try {
      final link = _ref.read(helperProvider);
      if (!link.connected) return state.set(PhoneAlertState.notJoined);
      final client = await _ref.read(helperProvider.notifier).client();
      if (client == null) return state.set(PhoneAlertState.notJoined);
      await _sendWaiting(client);
      if (!link.alertsReady) return state.set(PhoneAlertState.notSetUp);
      final ring = await _db.getSetting(kPhoneRing) != '0';
      await _bridge.setRing(ring);
      if (!ring) {
        await client.setPush(ring: false);
        return state.set(PhoneAlertState.off);
      }
      final allowed = ask ? await _bridge.askForAlerts() : await _bridge.alertsAllowed();
      if (!allowed) return state.set(PhoneAlertState.blocked);
      final app = await client.alerts();
      if (app == null) return state.set(PhoneAlertState.notSetUp);
      final token = await _bridge.startAlerts(app, client.base.toString());
      if (token == null || token.isEmpty) return state.set(PhoneAlertState.failed);
      if (token != _sentToken) {
        await client.setPush(token: token, ring: true);
        _sentToken = token;
      }
      state.set(PhoneAlertState.on);
    } on HelperException {
      // Out of reach: tried again the next time the link comes up.
    } catch (e, st) {
      AppLog.current?.error('setting alerts up on this phone failed', AppLog.scrub(e), st);
      state.set(PhoneAlertState.failed);
    }
  }

  /// "Ring on this phone" switched on or off.
  Future<void> setRing(bool ring) async {
    await _db.putSetting(kPhoneRing, ring ? '1' : '0');
    _sentToken = null;
    await setUp();
  }

  /// Done and Later pressed on alerts while there was no signal.
  Future<void> _sendWaiting(HelperClient client) async {
    final waiting = await _bridge.waitingChanges();
    if (waiting.isEmpty) return;
    await client.push(waiting, echo: true);
    await _bridge.clearWaiting();
    unawaited(_ref.read(helperProvider.notifier).syncNow());
  }

  /// An alert was tapped: Focus opens on that email. If the email has not
  /// reached this phone yet, Focus opens on its list. An email that is not
  /// from a person (a sign-in code, say) opens in Feed, where it lives.
  Future<void> open(String messageId) async {
    try {
      final m = await (_db.select(_db.messages)..where((m) => m.messageId.equals(messageId))..limit(1)).getSingleOrNull();
      _ref.read(compactPageProvider.notifier).show(CompactPage.main);
      if (m != null && m.classification == 'feeds' && (await _db.watchMailItem(m.id).first)?.needsYou != true) {
        _ref.read(destinationProvider.notifier).select(Destination.feed);
        _ref.read(openMailProvider('feed').notifier).open(m.id);
        return;
      }
      // From a person and not in Focus: its place is that person's chat.
      if (m != null && (await _db.watchMailItem(m.id).first)?.needsYou != true) {
        _ref.read(expandedMessagesProvider.notifier).expand(m.id);
        _ref.read(scrollToMessageProvider.notifier).request(m.id);
        await openRow(_ref.read, 'c:${m.fromContactKey}');
        return;
      }
      _ref.read(destinationProvider.notifier).select(Destination.focus);
      _ref.read(openMailProvider('focus').notifier).open(m?.id);
    } catch (e, st) {
      AppLog.current?.error('opening the email behind an alert failed', AppLog.scrub(e), st);
    }
  }

  /// Signed out: alerts stop on this phone.
  Future<void> forget() async {
    if (!Platform.isAndroid) return;
    _sentToken = null;
    try {
      await _bridge.stopAlerts();
    } catch (_) {}
  }
}

final phoneAlertsProvider = Provider<PhoneAlerts>((ref) {
  final a = PhoneAlerts(ref);
  ref.onDispose(a.stop);
  return a;
});
