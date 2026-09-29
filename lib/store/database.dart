import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'settings_store.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables. See plan section 1.3. Every message row carries its RFC Message-ID,
// account, folder and UID so user metadata keyed on Message-ID survives
// re-syncs (plan 1.2).
// ---------------------------------------------------------------------------

/// Key/value app settings (spec 4.18).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// A connected mail account (spec 4.1). Passwords never live here; they are
/// in the platform credential store keyed by [Accounts.id].
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text().unique()();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  TextColumn get imapHost => text()();
  IntColumn get imapPort => integer()();
  /// 'ssl' | 'starttls' | 'none'
  TextColumn get imapSecurity => text()();
  TextColumn get smtpHost => text()();
  IntColumn get smtpPort => integer()();
  TextColumn get smtpSecurity => text()();
  TextColumn get username => text()();
  /// 'password' | 'oauth2'
  TextColumn get authMethod => text().withDefault(const Constant('password'))();
  TextColumn get providerId => text().withDefault(const Constant('custom'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
}

/// Send-from identities/aliases for an account (spec 4.1, 4.4).
class Identities extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get email => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get signature => text().withDefault(const Constant(''))();
  TextColumn get smtpHost => text().nullable()();
  IntColumn get smtpPort => integer().nullable()();
  TextColumn get smtpSecurity => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// True when the identity was learned from the account's Sent folder
  /// (a "send as" alias) rather than entered by the user.
  BoolColumn get discovered => boolean().withDefault(const Constant(false))();
}

/// IMAP folders with sync state per folder.
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  TextColumn get name => text()();
  /// 'inbox' | 'sent' | 'drafts' | 'trash' | 'junk' | 'archive' | 'other'
  TextColumn get role => text().withDefault(const Constant('other'))();
  BoolColumn get selectable => boolean().withDefault(const Constant(true))();
  IntColumn get uidValidity => integer().nullable()();
  IntColumn get uidNext => integer().nullable()();
  IntColumn get highestModSeq => integer().nullable()();
  /// Highest UID whose headers we have stored; incremental sync fetches above it.
  IntColumn get lastSyncedUid => integer().withDefault(const Constant(0))();
  IntColumn get messagesExists => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {accountId, path},
      ];
}

/// One row per message per folder. Bodies are fetched on demand.
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get folderId => integer().references(Folders, #id, onDelete: KeyAction.cascade)();
  IntColumn get uid => integer()();
  TextColumn get messageId => text().nullable()();
  TextColumn get inReplyTo => text().nullable()();
  /// Space-separated Message-IDs from the References header.
  TextColumn get referencesHeader => text().nullable()();
  TextColumn get subject => text().withDefault(const Constant(''))();
  /// Normalized sender address (see IdentityResolver.normalize).
  TextColumn get fromAddress => text().withDefault(const Constant(''))();
  TextColumn get fromName => text().withDefault(const Constant(''))();
  /// Canonical contact key of the sender after identity resolution.
  TextColumn get fromContactKey => text().withDefault(const Constant(''))();
  BoolColumn get isFromMe => boolean().withDefault(const Constant(false))();
  DateTimeColumn get date => dateTime().nullable()();
  DateTimeColumn get internalDate => dateTime().nullable()();
  BoolColumn get isSeen => boolean().withDefault(const Constant(false))();
  BoolColumn get isFlagged => boolean().withDefault(const Constant(false))();
  BoolColumn get isAnswered => boolean().withDefault(const Constant(false))();
  BoolColumn get isDraft => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get size => integer().withDefault(const Constant(0))();
  BoolColumn get hasAttachments => boolean().withDefault(const Constant(false))();
  TextColumn get snippet => text().withDefault(const Constant(''))();
  TextColumn get bodyText => text().nullable()();
  TextColumn get bodyHtml => text().nullable()();
  DateTimeColumn get bodyFetchedAt => dateTime().nullable()();
  /// Provider thread id (Gmail X-GM-THRID) when available (spec 4.20).
  TextColumn get providerThreadId => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {folderId, uid},
      ];
}

/// From/To/CC/BCC/Reply-To participants of a message.
class MessageParticipants extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get messageId => integer().references(Messages, #id, onDelete: KeyAction.cascade)();
  /// 'from' | 'to' | 'cc' | 'bcc' | 'replyTo'
  TextColumn get role => text()();
  TextColumn get address => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get contactKey => text()();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
}

/// A person (spec 4.14). The key is the canonical normalized address the
/// contact was first seen with; other addresses map to it via
/// [ContactAddresses].
class Contacts extends Table {
  TextColumn get key => text()();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  TextColumn get photoPath => text().nullable()();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
  BoolColumn get inAddressBook => boolean().withDefault(const Constant(false))();
  DateTimeColumn get firstSeenAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSeenAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// Address → contact mapping (many addresses, one person).
class ContactAddresses extends Table {
  TextColumn get address => text()();
  TextColumn get contactKey => text().references(Contacts, #key, onDelete: KeyAction.cascade)();
  /// 'observed' | 'user' | 'addressbook'
  TextColumn get source => text().withDefault(const Constant('observed'))();

  @override
  Set<Column> get primaryKey => {address};
}

/// Attachment metadata; file content is fetched on demand (spec 4.5).
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get messageId => integer().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get partId => text()();
  TextColumn get fileName => text().withDefault(const Constant(''))();
  TextColumn get mimeType => text().withDefault(const Constant('application/octet-stream'))();
  IntColumn get size => integer().withDefault(const Constant(0))();
  TextColumn get contentId => text().nullable()();
  BoolColumn get isInline => boolean().withDefault(const Constant(false))();
  TextColumn get localPath => text().nullable()();
}

/// User-defined groups (spec 4.19).
class PeopleGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class GroupMembers extends Table {
  IntColumn get groupId => integer().references(PeopleGroups, #id, onDelete: KeyAction.cascade)();
  TextColumn get contactKey => text()();

  @override
  Set<Column> get primaryKey => {groupId, contactKey};
}

/// Per-row user preferences: pin, mute, snooze (spec 4.2, 4.9, 4.17).
/// rowKey matches [MessageRowAssignments.rowKey].
class RowPrefs extends Table {
  TextColumn get rowKey => text()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {rowKey};
}

/// Pre-aggregated People-list data, one row per row_key, maintained
/// incrementally: triggers record touched row keys in [DirtyRows] and
/// `refreshDirtyRows()` recomputes only those. The list query reads this
/// table instead of scanning messages (plan M2 performance target).
class RowSummaries extends Table {
  TextColumn get rowKey => text()();
  IntColumn get total => integer()();
  IntColumn get unread => integer()();
  /// Newest message not from me (ordering for contact rows, decision 4).
  DateTimeColumn get lastReceived => dateTime().nullable()();
  /// Newest message of any sender (ordering for group rows, preview).
  DateTimeColumn get lastAny => dateTime().nullable()();
  BoolColumn get hasStarred => boolean()();
  BoolColumn get hasAttachments => boolean()();
  BoolColumn get hasSent => boolean()();
  IntColumn get newestMessageId => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {rowKey};
}

/// Row keys whose summary is stale. Filled by triggers, drained by refresh.
class DirtyRows extends Table {
  TextColumn get rowKey => text()();

  @override
  Set<Column> get primaryKey => {rowKey};
}

/// Which People-list row(s) a message lives in (spec 4.3, 4.19).
/// rowKey is `c:<contactKey>` or `g:<groupId>`. Stored separately from
/// threading (plan 1.2).
class MessageRowAssignments extends Table {
  IntColumn get messageId => integer().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get rowKey => text()();

  @override
  Set<Column> get primaryKey => {messageId, rowKey};
}

// ---------------------------------------------------------------------------

@DriftDatabase(tables: [
  Settings,
  Accounts,
  Identities,
  Folders,
  Messages,
  MessageParticipants,
  Contacts,
  ContactAddresses,
  Attachments,
  PeopleGroups,
  GroupMembers,
  MessageRowAssignments,
  RowPrefs,
  RowSummaries,
  DirtyRows,
])
class AppDatabase extends _$AppDatabase implements SettingsStore {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
          await _createTriggers();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            for (final t in <TableInfo<Table, dynamic>>[
              accounts,
              identities,
              folders,
              messages,
              messageParticipants,
              contacts,
              contactAddresses,
              attachments,
              peopleGroups,
              groupMembers,
              messageRowAssignments,
            ]) {
              await m.createTable(t);
            }
            await _createIndexes();
          }
          if (from < 3) {
            await m.createTable(rowPrefs);
            await m.addColumn(identities, identities.discovered);
          }
          if (from < 4) {
            await m.createTable(rowSummaries);
            await m.createTable(dirtyRows);
            await _createTriggers();
            // Everything is stale until the first refresh.
            await customStatement('INSERT OR IGNORE INTO dirty_rows(row_key) SELECT DISTINCT row_key FROM message_row_assignments');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_message_id ON messages(message_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_from_key ON messages(from_contact_key)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_participants_message ON message_participants(message_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_participants_key ON message_participants(contact_key)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_row_assign_row ON message_row_assignments(row_key)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_attachments_message ON attachments(message_id)');
  }

  /// Triggers that mark People rows stale whenever anything that feeds a
  /// summary changes. Drift does not manage triggers, so they live here.
  Future<void> _createTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_assign_ins AFTER INSERT ON message_row_assignments
      BEGIN INSERT OR IGNORE INTO dirty_rows(row_key) VALUES (NEW.row_key); END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_assign_del AFTER DELETE ON message_row_assignments
      BEGIN INSERT OR IGNORE INTO dirty_rows(row_key) VALUES (OLD.row_key); END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_msg_upd AFTER UPDATE OF is_seen, is_flagged, is_deleted, has_attachments,
        snippet, subject, date, internal_date, is_from_me, folder_id ON messages
      BEGIN INSERT OR IGNORE INTO dirty_rows(row_key) SELECT row_key FROM message_row_assignments WHERE message_id = NEW.id; END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_msg_del BEFORE DELETE ON messages
      BEGIN INSERT OR IGNORE INTO dirty_rows(row_key) SELECT row_key FROM message_row_assignments WHERE message_id = OLD.id; END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_folder_role AFTER UPDATE OF role ON folders
      BEGIN INSERT OR IGNORE INTO dirty_rows(row_key)
        SELECT r.row_key FROM message_row_assignments r JOIN messages m ON m.id = r.message_id WHERE m.folder_id = NEW.id; END''');
  }

  static QueryExecutor _open() => driftDatabase(
        name: 'convomail',
        native: const DriftNativeOptions(shareAcrossIsolates: true, databasePath: databasePath),
      );

  /// The database lives in the per-user application support folder
  /// (`%APPDATA%\com.convomail\convomail` on Windows). Early builds used
  /// drift's default, the Documents folder; a file found there is moved
  /// once so synced mail is not lost.
  static Future<String> databasePath() async {
    final support = await getApplicationSupportDirectory();
    final target = p.join(support.path, 'convomail.sqlite');
    if (!File(target).existsSync()) {
      try {
        final documents = await getApplicationDocumentsDirectory();
        final legacy = p.join(documents.path, 'convomail.sqlite');
        if (File(legacy).existsSync()) {
          await support.create(recursive: true);
          for (final suffix in ['', '-wal', '-shm', '-journal']) {
            final f = File('$legacy$suffix');
            if (f.existsSync()) await f.rename('$target$suffix');
          }
        }
      } catch (_) {
        // Fall through: a fresh database is created at the new location.
      }
    }
    return target;
  }

  @override
  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> putSetting(String key, String value) => into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value),
      );
}

/// The single database instance for the app. Tests override this with
/// [AppDatabase.memory].
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
