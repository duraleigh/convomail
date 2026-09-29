import 'dart:io';

import 'package:convomail/store/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The Documents → AppData database move (AppDatabase.resolveDatabasePath).
void main() {
  late Directory root;
  late Directory support;
  late Directory documents;

  setUp(() {
    root = Directory.systemTemp.createTempSync('convomail_dbpath_');
    support = Directory(p.join(root.path, 'support'));
    documents = Directory(p.join(root.path, 'docs'))..createSync(recursive: true);
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<void> writeDb(String path, {int accounts = 0}) async {
    final db = AppDatabase(NativeDatabase(File(path)));
    await db.select(db.accounts).get(); // force the file to be created
    for (var i = 0; i < accounts; i++) {
      await db.into(db.accounts).insert(AccountsCompanion.insert(
            email: 'a$i@example.com',
            imapHost: 'x',
            imapPort: 993,
            imapSecurity: 'ssl',
            smtpHost: 'x',
            smtpPort: 465,
            smtpSecurity: 'ssl',
            username: 'a$i',
            providerId: const Value('custom'),
          ));
    }
    await db.close();
  }

  Future<int> accountCount(String path) async {
    final db = AppDatabase(NativeDatabase(File(path)));
    final n = (await db.select(db.accounts).get()).length;
    await db.close();
    return n;
  }

  test('no legacy file: target path returned, nothing created', () async {
    final target = await AppDatabase.resolveDatabasePath(support: support, documents: documents);
    expect(target, p.join(support.path, 'convomail.sqlite'));
    expect(File(target).existsSync(), isFalse);
  });

  test('legacy with accounts and no target: moved', () async {
    final legacy = p.join(documents.path, 'convomail.sqlite');
    await writeDb(legacy, accounts: 1);
    final target = await AppDatabase.resolveDatabasePath(support: support, documents: documents);
    expect(File(target).existsSync(), isTrue);
    expect(File(legacy).existsSync(), isFalse);
    expect(await accountCount(target), 1);
  });

  test('empty target beside a populated legacy: target replaced by legacy', () async {
    final legacy = p.join(documents.path, 'convomail.sqlite');
    await writeDb(legacy, accounts: 1);
    support.createSync(recursive: true);
    final targetPath = p.join(support.path, 'convomail.sqlite');
    await writeDb(targetPath, accounts: 0);
    final target = await AppDatabase.resolveDatabasePath(support: support, documents: documents);
    expect(await accountCount(target), 1);
    expect(File(legacy).existsSync(), isFalse);
  });

  test('populated target is never replaced', () async {
    final legacy = p.join(documents.path, 'convomail.sqlite');
    await writeDb(legacy, accounts: 1);
    support.createSync(recursive: true);
    final targetPath = p.join(support.path, 'convomail.sqlite');
    await writeDb(targetPath, accounts: 2);
    final target = await AppDatabase.resolveDatabasePath(support: support, documents: documents);
    expect(await accountCount(target), 2);
    expect(File(legacy).existsSync(), isTrue, reason: 'legacy left alone');
  });

  test('empty legacy is ignored', () async {
    final legacy = p.join(documents.path, 'convomail.sqlite');
    await writeDb(legacy, accounts: 0);
    final target = await AppDatabase.resolveDatabasePath(support: support, documents: documents);
    expect(File(target).existsSync(), isFalse);
    expect(File(legacy).existsSync(), isTrue);
  });
}
