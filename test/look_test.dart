import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:convomail/app/destinations.dart';
import 'package:convomail/app/layout.dart';
import 'package:convomail/domain/timely_extractor.dart';
import 'package:convomail/helper/helper_sync.dart';
import 'package:convomail/mail/models.dart';
import 'package:convomail/mail/transport_factory.dart';
import 'package:convomail/main.dart';
import 'package:convomail/platform/credential_store.dart';
import 'package:convomail/store/database.dart' hide ClassificationRule;
import 'package:convomail/store/helper_queries.dart';
import 'package:convomail/store/people_queries.dart';
import 'package:convomail/store/settings_store.dart';
import 'package:convomail/store/timely_queries.dart';
import 'package:convomail/sync/calendar_sync.dart';
import 'package:convomail/sync/sync_engine.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_helper.dart';
import 'support/fake_mail_transport.dart';
import 'support/test_db.dart';

/// Draws the Précis page, with made-up mail, to pictures: at a phone's size
/// with the text set to 130%, and at a PC's. Not a check: it runs only when
/// PRECIS_LOOK names a folder for the pictures, so the page can be looked at
/// without opening the app.
///
///   PRECIS_LOOK=C:\some\folder flutter test test/look_test.dart
void main() {
  final out = Platform.environment['PRECIS_LOOK'];
  const me = RemoteAddress('me@example.com');
  const brief = BulkSignals(listUnsubscribe: true, listId: true, listIdValue: 'brief.dailybrief.com');
  late AppDatabase db;
  late FakeMailTransport imap;
  late Account account;

  DateTime ago({int days = 0, int hours = 0}) => DateTime.now().subtract(Duration(days: days, hours: hours));
  int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
  void got(String address, String name, String subject, {required String id, BulkSignals signals = BulkSignals.none, DateTime? at}) =>
      imap.folder('INBOX').add(RemoteMessageHeader(uid: 0, from: RemoteAddress(address, name), to: const [me], subject: subject, messageId: id, date: at ?? ago(hours: 3), signals: signals));
  Future<void> says(String kind, String key, Map<String, Object?> data) => db.applyingFromHelper(() => db.applyHelperItem(kind, key, data, deleted: false));
  Future<Message> message(String messageId) async => (await (db.select(db.messages)..where((m) => m.messageId.equals(messageId))).get()).first;

  Future<void> fonts() async {
    final flutter = File(Platform.resolvedExecutable).parent.path;
    // .../bin/cache/artifacts/engine/windows-x64 -> .../bin/cache/artifacts/material_fonts
    final dir = Directory('$flutter/../../material_fonts');
    Future<ByteData> bytes(String path) async => ByteData.view((await File(path).readAsBytes()).buffer);
    final roboto = FontLoader('Roboto');
    for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-light.ttf']) {
      roboto.addFont(bytes('${dir.path}/$f'));
    }
    await roboto.load();
    await (FontLoader('MaterialIcons')..addFont(bytes('${dir.path}/materialicons-regular.otf'))).load();
    final segoe = File(r'C:\Windows\Fonts\SegUIVar.ttf');
    if (segoe.existsSync()) {
      await (FontLoader('Segoe UI Variable Text')..addFont(bytes(segoe.path))).load();
    }
  }

  /// Fills the page. [close]: the first flight leaves tomorrow (drawn large)
  /// and is delayed; otherwise it leaves in three days (a pass).
  Future<void> fill({required bool close, bool delayed = false}) async {
    db = testDatabase();
    imap = FakeMailTransport();
    account = await insertTestAccount(db);
    await db.into(db.identities).insert(IdentitiesCompanion.insert(accountId: account.id, email: 'me@example.com', name: const Value('Clay Example'), isDefault: const Value(true)));
    imap.folder('INBOX', role: FolderRole.inbox);
    imap.folder('Sent', role: FolderRole.sent);
    imap.folder('Sent').add(RemoteMessageHeader(uid: 0, from: me, to: const [RemoteAddress('renee@booking.example')], subject: 'Spring dates', messageId: '<mine@example.com>', date: ago(days: 3)));
    got('renee@booking.example', 'Renee Calloway', 'Re: Spring dates', id: '<renee@x>', at: ago(hours: 2));
    got('alerts@bank.example', 'First Citizens Bank', 'Your automatic payment did not go through', id: '<bank@x>', at: ago(days: 2));
    got('ship@fi.example', 'Google Fi Wireless', 'Your order has shipped', id: '<fi-ship@x>', signals: brief, at: ago(hours: 6));
    got('ship@amazon.example', 'Amazon', 'Delivered: your package', id: '<amz@x>', signals: brief, at: ago(hours: 1));
    got('bill@boost.example', 'Boost Mobile', 'Your bill is ready', id: '<boost@x>', signals: brief, at: ago(hours: 7));
    got('bill@fi.example', 'Google Fi', 'Your statement', id: '<fi-bill@x>', signals: brief, at: ago(hours: 8));
    got('no-reply@login.example', 'Hostinger', 'Your sign-in code', id: '<code@x>', signals: brief, at: ago());
    got('aa@aa.example', 'American Airlines', 'Your trip confirmation', id: '<aa@x>', signals: brief, at: ago(hours: 9));
    final syncer = AccountSyncer(db: db, transport: imap, account: account, credentials: () async => const MailCredentials(username: 'me@example.com', password: 'secret'));
    await syncer.syncOnce();
    await db.refreshDirtyRows();
    await db.setHelperConnected(true);
    await db.putSetting('helper.assistantOn', '1');
    for (final id in ['<fi-ship@x>', '<amz@x>', '<boost@x>', '<fi-bill@x>', '<code@x>', '<aa@x>']) {
      await says('sort', id, {'cls': 'feeds', 'cat': 'Notification', 'pile': 'feed'});
    }
    await says('read', '<renee@x>', {'line': 'Renee needs your yes or no on Charlotte, March 14.', 'focus': true, 'ask': 'Say yes or no to the Charlotte date.', 'due': secs(DateTime.now().add(const Duration(days: 1))), 'why': ['It asks you for a yes or no.'], 'answered': false, 'at': 1});
    await says('read', '<bank@x>', {'line': 'A payment failed.', 'focus': true, 'ask': 'Update the card on file.', 'due': null, 'why': ['A payment failed.'], 'answered': false, 'at': 1});
    await says('read', '<fi-ship@x>', {'line': 'Your SIM kit is on its way.', 'focus': false, 'ask': '', 'due': null, 'why': <String>[], 'answered': false, 'at': 1, 'thing': 'Google Fi Data Only SIM Kit'});
    await says('read', '<amz@x>', {'line': 'Your hard case was delivered.', 'focus': false, 'ask': '', 'due': null, 'why': <String>[], 'answered': false, 'at': 1, 'thing': 'Hard case and more'});
    final now = DateTime.now();
    await db.upsertTimely(await message('<fi-ship@x>'), [TimelyFact(type: TimelyType.delivery, dedupeKey: 'parcel:1', title: 'Google Fi Wireless', detail: 'FedEx', startsAt: DateTime(now.year, now.month, now.day + 1), actionUrl: 'https://example.com/track', actionLabel: 'Track')], ago(hours: 6));
    await db.upsertTimely(await message('<amz@x>'), [const TimelyFact(type: TimelyType.delivery, dedupeKey: 'parcel:2', title: 'Amazon', detail: 'UPS', status: 'delivered')], ago(hours: 1));
    await db.upsertTimely(await message('<boost@x>'), [TimelyFact(type: TimelyType.bill, dedupeKey: 'bill:1', title: 'Boost Mobile', detail: r'$16.58 due', startsAt: DateTime(now.year, now.month, now.day + 2))], ago(hours: 7));
    await db.upsertTimely(await message('<fi-bill@x>'), [TimelyFact(type: TimelyType.bill, dedupeKey: 'bill:2', title: 'Google Fi', detail: r'$183.49 due', startsAt: DateTime(now.year, now.month, now.day + 3), actionUrl: 'https://example.com/pay', actionLabel: 'Pay')], ago(hours: 8));
    await db.upsertTimely(await message('<code@x>'), [const TimelyFact(type: TimelyType.code, dedupeKey: 'code:1', title: 'Hostinger', code: '482913')], now);
    final leaves = close ? now.add(const Duration(hours: 20)) : now.add(const Duration(days: 3));
    Map<String, Object?> leg(String number, String fc, String fcity, String tc, String tcity, DateTime dep, {String state = 'confirmed', String wasDep = '', String wasArr = '', String dep0 = '2026-11-16T19:57', String arr0 = '2026-11-16T22:00'}) => {
          'mode': 'flight', 'carrier': 'American Airlines', 'number': number, 'fc': fc, 'fcity': fcity, 'tc': tc, 'tcity': tcity,
          'dep': dep0, 'arr': arr0, 'dep_at': secs(dep), 'arr_at': secs(dep.add(const Duration(hours: 2, minutes: 3))), 'loc': 'HEYLVT',
          'state': state, 'news_at': 0, 'was_dep': wasDep, 'was_arr': wasArr, 'checkin': '', 'mid': '<aa@x>', 'missing': <String>[],
        };
    await says('leg', 'AA4704|2026-11-16|RDU|LGA', delayed ? leg('AA4704', 'RDU', 'Raleigh/Durham', 'LGA', 'New York LaGuardia', leaves, state: 'delayed', wasDep: '2026-11-16T19:57', wasArr: '2026-11-16T22:00', dep0: '2026-11-16T21:10', arr0: '2026-11-16T23:15') : leg('AA4704', 'RDU', 'Raleigh/Durham', 'LGA', 'New York LaGuardia', leaves));
    await says('leg', 'AA1187|2026-11-18|LGA|RDU', leg('AA1187', 'LGA', 'New York LaGuardia', 'RDU', 'Raleigh/Durham', leaves.add(const Duration(days: 2)), dep0: '2026-11-18T08:15', arr0: '2026-11-18T10:04'));
    final start = leaves.add(const Duration(hours: 4));
    await says('booking', 'car_service|cr-5521', {
      'type': 'car_service', 'name': 'Carey', 'starts': '2026-11-16T23:30', 'ends': '', 'start_at': secs(start), 'end_at': null,
      'place': 'LGA Terminal B', 'to': 'The Ludlow', 'address': '', 'conf': 'CR-5521', 'phone': '800-555-0199', 'person': 'Luis M.', 'party': '', 'state': 'confirmed', 'news_at': 0, 'mid': '<aa@x>',
    });
    await says('booking', 'hotel|88412207', {
      'type': 'hotel', 'name': 'The Ludlow', 'starts': '2026-11-16T15:00', 'ends': '2026-11-18T11:00', 'start_at': secs(start), 'end_at': secs(start.add(const Duration(days: 2))),
      'place': 'New York', 'to': '', 'address': '180 Ludlow St', 'conf': '88412207', 'phone': '', 'person': '', 'party': '', 'state': 'confirmed', 'news_at': 0, 'mid': '<aa@x>',
    });
    await says('day', 'today', {'text': 'Renee needs your yes or no on Charlotte by tomorrow, and the bank payment failed. Your hard case was delivered today, and you fly to New York on Monday at 7:57 PM.', 'at': secs(now) - 600, 'after': 4});
    await db.putSetting(CalendarSync.calendarsKey, jsonEncode([const GoogleCalendarInfo(id: 'work', name: 'Work', color: 0xFF4285F4, writable: true, primary: true).toJson()]));
    if (close) {
      await db.into(db.plannerEvents).insert(PlannerEventsCompanion.insert(title: 'Call with the label', kind: 'google', startAt: Value(DateTime(now.year, now.month, now.day, 15, 30)), endAt: Value(DateTime(now.year, now.month, now.day, 16))));
      await db.into(db.plannerEvents).insert(PlannerEventsCompanion.insert(title: 'Car to RDU', kind: 'google', startAt: Value(DateTime(now.year, now.month, now.day, 17, 30)), endAt: Value(DateTime(now.year, now.month, now.day, 18))));
    }
    await db.delete(db.helperOutbox).go();
    await db.refreshDirtyRows();
  }

  Future<void> shoot(WidgetTester tester, String name, {required Size size, required bool phone, double textScale = 1}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(db.close);
    final store = InMemorySettingsStore();
    await store.putSetting('appearance.themeMode', 'dark');
    final c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWith((ref) => store),
        databaseProvider.overrideWith((ref) => db),
        credentialStoreProvider.overrideWith((ref) => InMemoryCredentialStore()),
        transportFactoryProvider.overrideWith((ref) => () => imap),
        helperHttpProvider.overrideWith((ref) => FakeHelper().call),
        htmlRendererProvider.overrideWith((ref) => (context, html, {maxHeight = 1200}) => PlainHtmlFallback(html: html)),
        destinationProvider.overrideWith(() => DestinationNotifier(initial: Destination.today)),
        forceCompactProvider.overrideWith((ref) => phone ? true : null),
        isTouchDeviceProvider.overrideWith((ref) => phone),
      ],
    );
    addTearDown(c.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: UncontrolledProviderScope(container: c, child: const PrecisApp(startSync: false))));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    final overflow = tester.takeException();
    // ignore: avoid_print
    print('LOOK $name: ${overflow == null ? 'drawn, nothing runs off an edge' : 'PROBLEM: $overflow'}');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('the page, drawn to pictures', skip: out == null ? 'set PRECIS_LOOK to a folder to draw the pictures' : false, () {
    testWidgets('phone, text at 130%, a flight three days off', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.runAsync(fonts);
      await tester.runAsync(() => fill(close: false));
      await shoot(tester, 'phone-pass', size: const Size(412, 2500), phone: true, textScale: 1.3);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('phone, text at 130%, the first screen only', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.runAsync(fonts);
      await tester.runAsync(() => fill(close: false));
      await shoot(tester, 'phone-first-screen', size: const Size(412, 915), phone: true, textScale: 1.3);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('phone, text at 130%, a delayed flight tomorrow and a busy calendar', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.runAsync(fonts);
      await tester.runAsync(() => fill(close: true, delayed: true));
      await shoot(tester, 'phone-large-delayed', size: const Size(412, 2900), phone: true, textScale: 1.3);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('phone, text at 130%, a day with nothing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.runAsync(fonts);
      await tester.runAsync(() async {
        db = testDatabase();
        imap = FakeMailTransport();
        account = await insertTestAccount(db);
        await db.putSetting(CalendarSync.calendarsKey, jsonEncode([const GoogleCalendarInfo(id: 'work', name: 'Work', color: 0xFF4285F4, writable: true, primary: true).toJson()]));
      });
      await shoot(tester, 'phone-quiet', size: const Size(412, 915), phone: true, textScale: 1.3);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('PC, a flight tomorrow', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.runAsync(fonts);
      await tester.runAsync(() => fill(close: true));
      await shoot(tester, 'pc-large', size: const Size(1500, 1500), phone: false);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
