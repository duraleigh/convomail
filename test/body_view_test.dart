import 'package:convomail/app/conversation_state.dart';
import 'package:convomail/store/database.dart';
import 'package:convomail/ui/screens/chats/html_body_view.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_db.dart';

void main() {
  testWidgets('plain-text mail is drawn directly: links are links, search terms are marked', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PlainTextBody(text: 'See https://example.com/a.\nOr write to sam@example.com about the budget.', highlight: ['budget'])),
    ));
    final rich = tester.widget<SelectableText>(find.byKey(const ValueKey('plain-body'))).textSpan!;
    final parts = <TextSpan>[];
    rich.visitChildren((s) {
      if (s is TextSpan && s.text != null) parts.add(s);
      return true;
    });
    final link = parts.firstWhere((s) => s.text == 'https://example.com/a');
    expect(link.recognizer, isNotNull, reason: 'the trailing full stop is not part of the link');
    expect(parts.firstWhere((s) => s.text == 'sam@example.com').recognizer, isNotNull);
    expect(parts.firstWhere((s) => s.text == 'budget').style?.backgroundColor, isNotNull);
  });

  test('opening a chat downloads its other recent bodies ahead, in order, skipping ones already stored', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final account = await insertTestAccount(db);
    final folder = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: account.id, path: 'INBOX', name: 'INBOX'));
    for (var uid = 1; uid <= 4; uid++) {
      await db.into(db.messages).insert(MessagesCompanion.insert(accountId: account.id, folderId: folder, uid: uid, bodyFetchedAt: Value(uid == 2 ? DateTime(2026) : null)));
    }
    final all = (await db.select(db.messages).get())..sort((a, b) => a.uid.compareTo(b.uid));
    final asked = <int>[];
    await prefetchBodies((id) async {
      final m = all.firstWhere((x) => x.id == id);
      asked.add(m.uid);
      if (m.uid == 3) throw StateError('offline');
      return m;
    }, all, limit: 3);
    expect(asked, [1, 3, 4], reason: 'stored ones skipped; one failure does not stop the rest');
  });
}
