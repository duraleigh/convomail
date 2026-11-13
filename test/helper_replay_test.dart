import 'dart:async';

import 'package:convomail/store/database.dart';
import 'package:convomail/store/helper_queries.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_db.dart';

/// After some upgrades the app takes in the helper's whole list again from
/// the start. Being told what it already knows must cost next to nothing:
/// nothing written, no sender filed again, no list drawn again. (Filing
/// every sender again took minutes on a phone and held Chats and Feed back.)
void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<Set<String>> says(String kind, String k, Map<String, Object?> data) => db.applyingFromHelper(() => db.applyHelperItem(kind, k, data, deleted: false));

  /// The tables written while [work] runs.
  Future<Set<String>> written(Future<void> Function() work) async {
    final seen = <String>{};
    final sub = db.tableUpdates().listen((updates) => seen.addAll(updates.map((u) => u.table)));
    await work();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    // Every take-in marks that it is the helper speaking; that is not a change.
    return seen..remove('helper_state');
  }

  test('a sender told again is not filed again; one that changed is', () async {
    const item = {'cls': 'feeds', 'src': 'auto', 'cat': 'Receipt', 'reasons': 'It sends receipts.', 'pile': 'feed', 'counts': false, 'label': null, 'subtitle': null};
    expect(await says('sender', 'shop@x.example', item), {'shop@x.example'}, reason: 'new: its mail is filed');
    late Set<String> again;
    final tables = await written(() async => again = await says('sender', 'shop@x.example', item));
    expect(again, isEmpty, reason: 'already known: nothing to file again');
    expect(tables, isEmpty, reason: 'and nothing written');
    expect(await says('sender', 'shop@x.example', {...item, 'pile': 'noise'}), {'shop@x.example'}, reason: 'moved on another device: filed again');
    expect((await (db.select(db.helperSenders)..where((s) => s.key.equals('shop@x.example'))).getSingle()).pile, 'noise');
  });

  test('a sender told again whose contact here says something else is put right', () async {
    const item = {'cls': 'feeds', 'src': 'override', 'cat': 'Receipt', 'reasons': ''};
    await db.into(db.contacts).insert(ContactsCompanion.insert(key: 'shop@x.example', displayName: const Value('Shop')));
    await says('sender', 'shop@x.example', item);
    // Something here changed the contact behind the helper's back.
    await db.customStatement("UPDATE contacts SET classification = 'people', classification_source = 'auto' WHERE key = 'shop@x.example'");
    expect(await says('sender', 'shop@x.example', item), {'shop@x.example'});
    final c = await (db.select(db.contacts)..where((c) => c.key.equals('shop@x.example'))).getSingle();
    expect([c.classification, c.classificationSource], ['feeds', 'override'], reason: 'a move made by hand is never lost to the shortcut');
  });

  test('an email\'s place and its reading told again write nothing; a change is written', () async {
    const place = {'cls': 'feeds', 'cat': 'Notification', 'pile': 'feed'};
    const reading = {'line': 'Your order shipped.', 'focus': false, 'ask': '', 'due': null, 'why': ['It is a shipping notice.'], 'answered': false, 'at': 1790000000, 'know': true, 'thing': 'Hard case'};
    await says('sort', '<a@x>', place);
    await says('read', '<a@x>', reading);
    expect(await written(() async {
      await says('sort', '<a@x>', place);
      await says('read', '<a@x>', reading);
    }), isEmpty);
    expect(await written(() => says('sort', '<a@x>', {...place, 'pile': 'noise'})), contains('helper_verdicts'));
    expect(await written(() => says('read', '<a@x>', {...reading, 'know': false})), contains('helper_readings'));
    expect(await written(() => says('read', '<a@x>', {...reading, 'know': false, 'draft': 'Hi,\n\nWhat is the code?'})), contains('helper_readings'));
    expect((await (db.select(db.helperReadings)..where((r) => r.messageId.equals('<a@x>'))).getSingle()).draft, 'Hi,\n\nWhat is the code?');
  });
}
