import 'package:convomail/store/database.dart';
import 'package:drift/drift.dart' show Value;

/// In-memory database for tests. The sqlite3 package builds and bundles its
/// native library through Dart native-assets hooks, so this works under
/// `flutter test` on Windows without a system SQLite.
AppDatabase testDatabase() => AppDatabase.memory();

/// Inserts a minimal account row and returns it.
Future<Account> insertTestAccount(AppDatabase db, {String email = 'me@example.com'}) async {
  final id = await db.into(db.accounts).insert(AccountsCompanion.insert(
        email: email,
        imapHost: 'imap.example.com',
        imapPort: 993,
        imapSecurity: 'ssl',
        smtpHost: 'smtp.example.com',
        smtpPort: 465,
        smtpSecurity: 'ssl',
        username: email,
        providerId: const Value('custom'),
      ));
  return (await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle());
}
