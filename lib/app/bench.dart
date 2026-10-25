import 'dart:io';

import 'package:drift/drift.dart';

import '../store/database.dart';
import '../store/people_queries.dart';
import '../store/search_queries.dart';

/// `--bench-people`: seeds an in-memory database with 50,000 messages from
/// 5,000 senders, times the People rows query, writes the result to
/// `%TEMP%\convomail-bench.txt`, and exits. Used to verify the plan's M2
/// performance criterion on the release binary.
/// `--bench-search`: seeds 50,000 messages with varied subjects and bodies,
/// times five full-text queries, and writes `%TEMP%\\convomail-search-bench.txt`.
/// Verifies the plan's M6 criterion (under 200 ms over 50k messages).
Future<void> runSearchBench() async {
  final db = AppDatabase.memory();
  final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
        email: 'bench@example.com',
        imapHost: 'x',
        imapPort: 993,
        imapSecurity: 'ssl',
        smtpHost: 'x',
        smtpPort: 465,
        smtpSecurity: 'ssl',
        username: 'bench',
      ));
  final folderId = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: accountId, path: 'INBOX', name: 'INBOX', role: const Value('inbox')));
  const words = ['invoice', 'figma', 'budget', 'standup', 'contract', 'photos', 'flight', 'renewal', 'dashboard', 'lunch', 'quarterly', 'offer', 'shipping', 'password', 'agenda'];
  final t0 = DateTime(2026, 1, 1);
  final seedSw = Stopwatch()..start();
  await db.batch((b) {
    for (var i = 0; i < 50000; i++) {
      final sender = 'p${i % 5000}@x.com';
      final w1 = words[i % words.length];
      final w2 = words[(i * 7) % words.length];
      b.insert(
        db.messages,
        MessagesCompanion.insert(
          accountId: accountId,
          folderId: folderId,
          uid: i + 1,
          subject: Value('$w1 update $i'),
          fromAddress: Value(sender),
          fromName: Value('Person ${i % 5000}'),
          fromContactKey: Value(sender),
          date: Value(t0.add(Duration(minutes: i))),
          bodyText: Value('Hello, about the $w2 for project ${i % 97}: the $w1 numbers look fine and the deadline is next week. Regards, Person ${i % 5000}.'),
          snippet: Value('Hello, about the $w2 for project ${i % 97}'),
        ),
      );
    }
  });
  final ids = await (db.selectOnly(db.messages)..addColumns([db.messages.id, db.messages.fromContactKey])).get();
  await db.batch((b) {
    for (final r in ids) {
      b.insert(db.messageRowAssignments, MessageRowAssignmentsCompanion.insert(messageId: r.read(db.messages.id)!, rowKey: 'c:${r.read(db.messages.fromContactKey)}'));
    }
  });
  seedSw.stop();

  final times = <String, int>{};
  for (final q in ['figma', 'quarterly budget', 'Person 42', '"next week" offer', 'ship']) {
    final sw = Stopwatch()..start();
    final hits = await db.searchMessages(q);
    sw.stop();
    times['$q (${hits.length} hits)'] = sw.elapsedMilliseconds;
  }
  final report = StringBuffer()
    ..writeln('seed 50k messages (with FTS triggers): ${seedSw.elapsedMilliseconds} ms')
    ..writeln('index size: ${await db.searchIndexSize()}');
  for (final e in times.entries) {
    report.writeln('${e.key}: ${e.value} ms');
  }
  final out = File('${Platform.environment['TEMP'] ?? '.'}\\convomail-search-bench.txt');
  await out.writeAsString(report.toString());
  await db.close();
}

Future<void> runPeopleBench() async {
  final db = AppDatabase.memory();
  final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
        email: 'bench@example.com',
        imapHost: 'x',
        imapPort: 993,
        imapSecurity: 'ssl',
        smtpHost: 'x',
        smtpPort: 465,
        smtpSecurity: 'ssl',
        username: 'bench',
      ));
  final folderId = await db.into(db.folders).insert(FoldersCompanion.insert(accountId: accountId, path: 'INBOX', name: 'INBOX', role: const Value('inbox')));
  final t0 = DateTime(2026, 1, 1);
  await db.batch((b) {
    for (var i = 0; i < 50000; i++) {
      final sender = 'p${i % 5000}@x.com';
      b.insert(
        db.messages,
        MessagesCompanion.insert(
          accountId: accountId,
          folderId: folderId,
          uid: i + 1,
          subject: Value('subject $i'),
          fromAddress: Value(sender),
          fromContactKey: Value(sender),
          date: Value(t0.add(Duration(minutes: i))),
          isSeen: Value(i % 3 == 0),
        ),
      );
    }
  });
  final ids = await (db.selectOnly(db.messages)..addColumns([db.messages.id, db.messages.fromContactKey])).get();
  await db.batch((b) {
    for (final r in ids) {
      b.insert(db.messageRowAssignments, MessageRowAssignmentsCompanion.insert(messageId: r.read(db.messages.id)!, rowKey: 'c:${r.read(db.messages.fromContactKey)}'));
    }
  });

  // First refresh = full summary build after a first sync of 50k messages.
  final refreshSw = Stopwatch()..start();
  await db.refreshDirtyRows();
  refreshSw.stop();

  final times = <int>[];
  for (var run = 0; run < 5; run++) {
    final sw = Stopwatch()..start();
    final rows = await db.peopleRows();
    sw.stop();
    times.add(sw.elapsedMilliseconds);
    assert(rows.length == 5000);
  }

  // Incremental refresh after touching 500 messages (one sync page).
  await (db.update(db.messages)..where((m) => m.uid.isSmallerOrEqualValue(500))).write(const MessagesCompanion(isSeen: Value(true)));
  final incSw = Stopwatch()..start();
  await db.refreshDirtyRows();
  incSw.stop();
  await db.close();

  final out = File('${Directory.systemTemp.path}${Platform.pathSeparator}convomail-bench.txt');
  final median = (List.of(times)..sort())[times.length ~/ 2];
  await out.writeAsString(
    'people rows over 50k messages / 5k senders (release): list runs=${times.join(',')} ms, median=$median ms; '
    'full summary build=${refreshSw.elapsedMilliseconds} ms; incremental refresh (500 msgs)=${incSw.elapsedMilliseconds} ms\n',
  );
}
