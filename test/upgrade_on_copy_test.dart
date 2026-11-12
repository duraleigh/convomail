import 'dart:io';

import 'package:convomail/store/database.dart';
import 'package:convomail/store/mail_queries.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// One-off: opens a private copy of the real data with this version of the
/// app, so its storage upgrade is tried before the real app ever runs it.
/// Prints counts only. Not part of the app's checks (needs PRECIS_COPY).
void main() {
  final path = Platform.environment['PRECIS_COPY'];
  test('the storage upgrade works on a copy of the real data', () async {
    final db = AppDatabase(NativeDatabase(File(path!)));
    addTearDown(db.close);
    Future<int> n(String sql) async => (await db.customSelect(sql).getSingle()).data.values.first as int;
    // ignore: avoid_print
    print('storage version after opening: ${await n('PRAGMA user_version')}');
    // ignore: avoid_print
    print('messages: ${await n('SELECT COUNT(*) FROM messages')} | readings: ${await n('SELECT COUNT(*) FROM helper_readings')} | good to know: ${await n('SELECT COUNT(*) FROM helper_readings WHERE know = 1')} | named: ${await n("SELECT COUNT(*) FROM helper_readings WHERE thing <> ''")}');
    // ignore: avoid_print
    print('senders moved by hand: ${await n("SELECT COUNT(*) FROM contacts WHERE classification_source = 'override'")} | chosen piles: ${await n('SELECT COUNT(*) FROM contacts WHERE feeds_pile IS NOT NULL')} | done: ${await n('SELECT COUNT(*) FROM messages WHERE done_at IS NOT NULL')}');
    // ignore: avoid_print
    print('helper cursor set back to the start: ${(await db.getSetting('helper.cursor')) == '0'}');
    final focus = await db.watchFocus().first;
    final know = await db.watchGoodToKnow(since: DateTime.now().subtract(const Duration(days: 2))).first;
    // ignore: avoid_print
    print('in Focus: ${focus.length} | good to know (before the helper says so): ${know.length}');
    expect(await n('PRAGMA user_version'), 25);
  }, skip: path == null ? 'no copy given' : false);
}
