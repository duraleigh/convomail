import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

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
  /// 'password': this device holds the mailbox password itself.
  /// 'helper': this device joined by code and holds no password; the helper
  /// hands it a pass to the mailbox that lasts about an hour.
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
  /// The signature as an editor document (text, links, pictures). Null
  /// means the plain-text [signature] is used.
  TextColumn get signatureJson => text().nullable()();
  TextColumn get smtpHost => text().nullable()();
  IntColumn get smtpPort => integer().nullable()();
  TextColumn get smtpSecurity => text().nullable()();

  /// Login for the identity's own server (see sending_route.dart); its
  /// password is in the credential store. Null means the email address.
  TextColumn get smtpUsername => text().nullable()();
  /// Removed by the user: never offered for sending, never re-discovered,
  /// still counted as "me" so its old mail files as before.
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
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

  /// When this message was read for timely information (spec 4.21), and
  /// whether it held any.
  DateTimeColumn get timelyCheckedAt => dateTime().nullable()();
  BoolColumn get hasTimelyItem => boolean().withDefault(const Constant(false))();
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

  /// Thread key from the hybrid threading model (spec 4.20): the root
  /// message's Message-ID, or `m:<id>`. Null until assigned.
  TextColumn get threadKey => text().nullable()();

  /// The user chose "Load images" for this message (spec 4.13).
  BoolColumn get imagesAllowed => boolean().withDefault(const Constant(false))();

  /// Encoded [BulkSignals]; null until the list headers were fetched.
  TextColumn get bulkSignals => text().nullable()();

  /// The provider's own inbox category when it exposes one (Gmail:
  /// `primary`, `updates`, `promotions`, `social`, `forums`); null until
  /// read, `''` when the provider has none for this message.
  TextColumn get providerCategory => text().nullable()();

  /// `people` or `feeds` for this message (sender bucket with per-message
  /// exceptions, spec 4.11).
  TextColumn get classification => text().withDefault(const Constant('people'))();

  /// Message-level category when it differs from the sender default.
  TextColumn get feedsCategory => text().nullable()();

  /// The `text/calendar` part of an invitation, when the message has one.
  TextColumn get icsText => text().nullable()();

  /// When event extraction last ran on this message (spec 4.10).
  DateTimeColumn get extractedAt => dateTime().nullable()();

  /// When the user marked this email done; null while it is open.
  DateTimeColumn get doneAt => dateTime().nullable()();

  /// The user's own choice for this one email: 'feed' or 'noise'. It wins
  /// over every rule and over the assistant.
  TextColumn get pileFix => text().nullable()();

  /// The user's own word on whether this email needs them: 'no' ("Not
  /// Focus") or 'yes' (put in Focus by hand). Null leaves it to the assistant.
  TextColumn get focusFix => text().nullable()();

  /// "Later": the user put this Focus email off until this time. It stays
  /// out of Focus until then, and comes back by itself.
  DateTimeColumn get laterUntil => dateTime().nullable()();

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

  /// A name the user gave this sender; shown instead of [displayName]
  /// everywhere and kept for all future mail from any of its addresses.
  TextColumn get userLabel => text().nullable()();

  /// A short note the user put under this sender's name in the chat list,
  /// such as a job title. Optional; kept like [userLabel].
  TextColumn get userSubtitle => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
  BoolColumn get inAddressBook => boolean().withDefault(const Constant(false))();

  /// Effective bucket (`people` | `feeds`) and how it was decided
  /// (`auto` | `override` | `rule` | `people-signal`).
  TextColumn get classification => text().withDefault(const Constant('people'))();
  TextColumn get classificationSource => text().withDefault(const Constant('auto'))();

  /// Sender-default Feeds category.
  TextColumn get feedsCategory => text().nullable()();

  /// Spec 4.11: a Feeds sender whose unread mail still counts.
  BoolColumn get countsTowardUnread => boolean().withDefault(const Constant(false))();

  /// For a Feeds sender: the pile the user put it in (`feed` | `noise`).
  /// Null lets the app decide from its category and whether it is opened.
  TextColumn get feedsPile => text().nullable()();
  TextColumn get classReasons => text().withDefault(const Constant(''))();
  DateTimeColumn get firstSeenAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSeenAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

extension ContactShownName on Contact {
  /// The user's label, else the name from the headers, else the address.
  String get shownName => (userLabel?.trim().isNotEmpty ?? false) ? userLabel!.trim() : (displayName.isNotEmpty ? displayName : key);
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

  /// Set when a snooze ends: the row sorts as if newly received (spec 4.9).
  DateTimeColumn get resurfacedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {rowKey};
}

/// Remote hosts seen while rendering a message: blocked by default, or
/// loaded when the user chose "Load images" (spec 4.13 tracker log and
/// aggregate stats).
class TrackerEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get messageId => integer().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get host => text()();
  BoolColumn get isTracker => boolean().withDefault(const Constant(false))();
  BoolColumn get blocked => boolean().withDefault(const Constant(true))();
  DateTimeColumn get at => dateTime().withDefault(currentDateAndTime)();
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

  /// Per-bucket figures (spec 4.11): a row shows in People when it has
  /// People messages and in Feeds when it has Feeds messages.
  IntColumn get peopleTotal => integer().withDefault(const Constant(0))();
  IntColumn get peopleUnread => integer().withDefault(const Constant(0))();
  IntColumn get feedsTotal => integer().withDefault(const Constant(0))();
  IntColumn get feedsUnread => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPeople => dateTime().nullable()();
  DateTimeColumn get lastFeeds => dateTime().nullable()();
  IntColumn get newestPeopleId => integer().nullable()();
  IntColumn get newestFeedsId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {rowKey};
}

/// Feeds categories (spec 4.11): five defaults plus the user's own.
/// One email address from the user's Google contacts (spec 4.2), kept so a
/// sender first seen later still matches without asking Google again.
@DataClassName('AddressBookEntry')
class AddressBookEntryRows extends Table {
  TextColumn get address => text()();
  TextColumn get resourceName => text()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get photoUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {address};
}

class TimelyItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// A [TimelyType] name.
  TextColumn get type => text()();
  TextColumn get dedupeKey => text().unique()();
  IntColumn get messageId => integer().nullable().references(Messages, #id, onDelete: KeyAction.cascade)();
  IntColumn get accountId => integer().nullable()();
  TextColumn get contactKey => text().withDefault(const Constant(''))();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get detail => text().withDefault(const Constant(''))();
  DateTimeColumn get startsAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  DateTimeColumn get showFrom => dateTime()();
  DateTimeColumn get hideAfter => dateTime()();
  TextColumn get actionUrl => text().nullable()();
  TextColumn get actionLabel => text().nullable()();
  TextColumn get code => text().nullable()();
  TextColumn get status => text().nullable()();
  DateTimeColumn get dismissedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class FeedsCategoryRows extends Table {
  @override
  String get tableName => 'feeds_categories';
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get builtin => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Rules the user accepted from the correction flow (spec 4.11).
class ClassificationRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The rule's name across devices (the helper keeps rules by it).
  TextColumn get uid => text().nullable().clientDefault(newSyncId)();
  TextColumn get field => text()();
  TextColumn get pattern => text()();
  TextColumn get bucket => text().nullable()();
  TextColumn get category => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Labeled decisions and corrections, kept as training data for a later
/// on-device model (spec 4.11, 4.15).
class ClassificationEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get messageId => integer().nullable()();
  TextColumn get contactKey => text()();
  TextColumn get decision => text()();
  TextColumn get category => text().nullable()();
  TextColumn get reasons => text().withDefault(const Constant(''))();
  TextColumn get source => text()();
  DateTimeColumn get at => dateTime().withDefault(currentDateAndTime)();
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

/// Compose drafts (spec 4.4 autosave). One row per open composition; a
/// reply draft is keyed by the row it belongs to so it comes back when the
/// conversation is reopened.
class Drafts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get identityId => integer().nullable()();

  /// `new`, `reply`, `replyAll`, or `forward`.
  TextColumn get kind => text().withDefault(const Constant('new'))();

  /// People-list row the composer was opened from (replies/forwards).
  TextColumn get rowKey => text().nullable()();

  /// Local id of the message being replied to / forwarded.
  IntColumn get inReplyToMessageId => integer().nullable()();
  TextColumn get recipientsTo => text().withDefault(const Constant('[]'))();
  TextColumn get recipientsCc => text().withDefault(const Constant('[]'))();
  TextColumn get recipientsBcc => text().withDefault(const Constant('[]'))();
  TextColumn get subject => text().withDefault(const Constant(''))();

  /// Editor document (appflowy JSON) so formatting survives a restart.
  TextColumn get bodyJson => text().nullable()();
  TextColumn get bodyHtml => text().withDefault(const Constant(''))();
  TextColumn get attachmentsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get includeQuote => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Kanban tags (spec 4.8): unlimited nesting through [parentId]. Separate
/// from Feeds categories.
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get parentId => integer().nullable()();
  IntColumn get color => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Board columns, renameable; seeded with Next / In Progress / Done.
class BoardColumns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A conversation (thread) placed on the board.
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get threadKey => text().unique()();
  IntColumn get columnId => integer().references(BoardColumns, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class CardTags extends Table {
  IntColumn get cardId => integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {cardId, tagId};
}

/// Reminders (spec 4.9): alert at a time without hiding anything.
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The reminder's name across devices (the helper keeps reminders by it).
  TextColumn get uid => text().nullable().clientDefault(newSyncId)();
  TextColumn get title => text()();
  DateTimeColumn get dueAt => dateTime()();
  IntColumn get messageId => integer().nullable()();
  TextColumn get threadKey => text().nullable()();
  TextColumn get rowKey => text().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get firedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Planner items (spec 4.10): events (manual, extracted from text, or
/// from an invitation) and to-dos, each optionally linked to a message.
class PlannerEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();

  /// `manual` (added here, not in Google), `google` (an event in the user's
  /// Google Calendar), or `todo`. Older installs also had `extracted` and
  /// `invite`, removed in schema 18.
  TextColumn get kind => text()();

  /// Color key: `personal`, `work`, `travel`, `health`, `other`.
  TextColumn get colorKey => text().withDefault(const Constant('other'))();
  IntColumn get sourceMessageId => integer().nullable()();
  TextColumn get threadKey => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  RealColumn get confidence => real().withDefault(const Constant(1.0))();
  /// For `google` events: the Google event ID.
  TextColumn get uid => text().nullable()();
  TextColumn get evidence => text().withDefault(const Constant(''))();

  /// For `google` events: the Google calendar it is in.
  TextColumn get calendarId => text().nullable()();

  /// For `google` events: the calendar's colour (ARGB).
  IntColumn get color => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------------------

/// A random name for something kept in step across devices.
String newSyncId() {
  final r = Random.secure();
  return [for (var i = 0; i < 12; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}

/// Changes made on this device that have not reached the helper yet.
///
/// Mostly a list of what changed, not the change itself: when [data] is
/// empty, the row is read as it stands at the moment it is sent, so several
/// edits to one thing go up as one. Filled by triggers (see
/// `_createHelperTriggers`), so no screen has to remember to do it.
class HelperOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get k => text()();

  /// JSON to send as it is, for the few changes that are not a row's state.
  TextColumn get data => text().withDefault(const Constant(''))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {kind, k, data},
      ];
}

/// What the helper decided about a sender. While this device follows a
/// helper, these stand in place of its own sorting.
class HelperSenders extends Table {
  TextColumn get key => text()();
  TextColumn get cls => text()();
  TextColumn get src => text().withDefault(const Constant('auto'))();
  TextColumn get cat => text().nullable()();
  TextColumn get reasons => text().withDefault(const Constant(''))();

  /// What the user set on this sender on any device. Kept here too because
  /// it can arrive before this device has seen any mail from the sender.
  TextColumn get pile => text().nullable()();
  BoolColumn get counts => boolean().nullable()();
  TextColumn get label => text().nullable()();
  TextColumn get subtitle => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// What the user set on one email on any device (done, put off, Focus or
/// not, Feed or Noise), by its Message-ID. Kept because it can arrive
/// before the email itself does: the email takes these on the moment it
/// lands here.
class HelperMarks extends Table {
  TextColumn get messageId => text()();
  DateTimeColumn get doneAt => dateTime().nullable()();
  DateTimeColumn get laterUntil => dateTime().nullable()();
  TextColumn get focusFix => text().nullable()();
  TextColumn get pileFix => text().nullable()();

  @override
  Set<Column> get primaryKey => {messageId};
}

/// What the helper decided about one email, by its Message-ID. It can
/// arrive before the email itself does.
class HelperVerdicts extends Table {
  TextColumn get messageId => text()();
  TextColumn get cls => text()();
  TextColumn get cat => text().nullable()();

  /// Feed or Noise for this one email ('feed' | 'noise'); null for mail
  /// from a person, or when the helper has not said.
  TextColumn get pile => text().nullable()();

  @override
  Set<Column> get primaryKey => {messageId};
}

/// What the assistant said about one email, by its Message-ID: one
/// sentence, whether it needs the user, what is asked, by when, and why.
/// The email's own words are never part of it.
class HelperReadings extends Table {
  TextColumn get messageId => text()();
  TextColumn get line => text().withDefault(const Constant(''))();
  BoolColumn get focus => boolean().withDefault(const Constant(false))();
  TextColumn get ask => text().withDefault(const Constant(''))();
  DateTimeColumn get due => dateTime().nullable()();

  /// Up to three plain reasons, as a JSON list.
  TextColumn get why => text().withDefault(const Constant('[]'))();

  /// The user has answered this email since.
  BoolColumn get answered => boolean().withDefault(const Constant(false))();
  DateTimeColumn get readAt => dateTime().nullable()();

  /// This is an email the user sent (the reading says whether it asked for
  /// something, for Waiting on).
  BoolColumn get sent => boolean().withDefault(const Constant(false))();

  /// For an email the user sent: it asked its recipient for something.
  BoolColumn get asks => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {messageId};
}

/// One row: whether this device follows a helper, and whether a change
/// being written right now came from it (so it is not sent back).
class HelperState extends Table {
  IntColumn get id => integer()();
  BoolColumn get connected => boolean().withDefault(const Constant(false))();
  BoolColumn get applying => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

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
  TrackerEvents,
  Drafts,
  FeedsCategoryRows,
  ClassificationRules,
  ClassificationEvents,
  Tags,
  BoardColumns,
  Cards,
  CardTags,
  Reminders,
  PlannerEvents, TimelyItems, AddressBookEntryRows, HelperOutbox, HelperSenders, HelperVerdicts, HelperState, HelperReadings, HelperMarks])
class AppDatabase extends _$AppDatabase implements SettingsStore {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// Bumped when who-is-who changes (merge, separate). A sync already running
  /// checks it, so mail it filed under the old rule is filed again.
  int filingGeneration = 0;

  /// While above zero, the Chats and Feeds lists are not refreshed: new mail
  /// is being sorted, and shows only once it has its place. See
  /// [PeopleQueries.whileSorting].
  int listRefreshHold = 0;

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 24;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
          await _createTriggers();
          await _createSearchIndex();
          await _seedFeedsCategories();
          await _seedBoardColumns();
          await _createHelperTriggers();
          await _createHeldTriggers();
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
          if (from < 5) {
            await m.addColumn(messages, messages.threadKey);
            await m.addColumn(messages, messages.imagesAllowed);
            await m.createTable(trackerEvents);
            await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_thread ON messages(thread_key)');
            await customStatement('CREATE INDEX IF NOT EXISTS idx_tracker_message ON tracker_events(message_id)');
            // thread_key stays null; ThreadQueries.rebuildAllThreads runs on
            // the first conversation open / sync after this migration.
          }
          if (from < 6) {
            await m.createTable(drafts);
            await customStatement('CREATE INDEX IF NOT EXISTS idx_drafts_row ON drafts(row_key)');
          }
          if (from < 7) {
            await _createSearchIndex();
            await customStatement(
              "INSERT INTO message_fts(message_id, subject, sender, body) SELECT id, subject, from_name || ' ' || from_address, COALESCE(body_text, snippet) FROM messages",
            );
          }
          if (from < 8) {
            await m.addColumn(messages, messages.bulkSignals);
            await m.addColumn(messages, messages.classification);
            await m.addColumn(messages, messages.feedsCategory);
            await m.addColumn(contacts, contacts.classification);
            await m.addColumn(contacts, contacts.classificationSource);
            await m.addColumn(contacts, contacts.feedsCategory);
            await m.addColumn(contacts, contacts.countsTowardUnread);
            await m.addColumn(contacts, contacts.classReasons);
            for (final c in [rowSummaries.peopleTotal, rowSummaries.peopleUnread, rowSummaries.feedsTotal, rowSummaries.feedsUnread, rowSummaries.lastPeople, rowSummaries.lastFeeds, rowSummaries.newestPeopleId, rowSummaries.newestFeedsId]) {
              await m.addColumn(rowSummaries, c);
            }
            await m.createTable(feedsCategoryRows);
            await m.createTable(classificationRules);
            await m.createTable(classificationEvents);
            await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_classification ON messages(classification)');
            await customStatement('DROP TRIGGER IF EXISTS trg_msg_upd');
            await _createTriggers();
            await _seedFeedsCategories();
            // Everything is re-summarized with per-bucket figures; senders are
            // classified by the backfill pass on the next sync.
            await customStatement('INSERT OR IGNORE INTO dirty_rows(row_key) SELECT DISTINCT row_key FROM message_row_assignments');
          }
          if (from < 9) {
            await m.addColumn(messages, messages.icsText);
            await m.addColumn(messages, messages.extractedAt);
            await m.addColumn(rowPrefs, rowPrefs.resurfacedAt);
            for (final t in <TableInfo<Table, dynamic>>[tags, boardColumns, cards, cardTags, reminders, plannerEvents]) {
              await m.createTable(t);
            }
            await customStatement('CREATE INDEX IF NOT EXISTS idx_events_start ON planner_events(start_at)');
            await customStatement('CREATE INDEX IF NOT EXISTS idx_events_source ON planner_events(source_message_id)');
            await customStatement('CREATE INDEX IF NOT EXISTS idx_reminders_due ON reminders(due_at)');
            await _seedBoardColumns();
          }
          if (from < 10) {
            await m.addColumn(messages, messages.providerCategory);
            await m.addColumn(contacts, contacts.userLabel);
            await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_provider_category ON messages(folder_id, provider_category)');
          }
          if (from < 11) {
            await m.addColumn(contacts, contacts.userSubtitle);
          }
          if (from < 12) {
            await _seedFeedsCategories();
          }
          if (from < 13) {
            await m.addColumn(messages, messages.timelyCheckedAt);
            await m.addColumn(messages, messages.hasTimelyItem);
            await m.createTable(timelyItems);
            await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_timely ON messages(account_id, timely_checked_at)');
          }
          if (from < 14) {
            await m.createTable(addressBookEntryRows);
          }
          if (from < 15) {
            await m.addColumn(identities, identities.smtpUsername);
          }
          if (from < 16) {
            await m.addColumn(identities, identities.hidden);
          }
          if (from < 17) {
            await m.addColumn(identities, identities.signatureJson);
          }
          if (from < 18) {
            await m.addColumn(plannerEvents, plannerEvents.calendarId);
            await m.addColumn(plannerEvents, plannerEvents.color);
            // Dates read out of mail and invitations: the user adds their own.
            await customStatement("DELETE FROM planner_events WHERE kind IN ('extracted', 'invite')");
          }
          if (from < 19) {
            await m.addColumn(messages, messages.doneAt);
            await m.addColumn(contacts, contacts.feedsPile);
          }
          if (from < 20) {
            await m.createTable(helperOutbox);
            await m.createTable(helperSenders);
            await m.createTable(helperVerdicts);
            await m.createTable(helperState);
            await m.addColumn(classificationRules, classificationRules.uid);
            await m.addColumn(reminders, reminders.uid);
            await customStatement('UPDATE classification_rules SET uid = lower(hex(randomblob(12))) WHERE uid IS NULL');
            await customStatement('UPDATE reminders SET uid = lower(hex(randomblob(12))) WHERE uid IS NULL');
            await _createHelperTriggers();
          }
          if (from < 21) {
            await m.addColumn(messages, messages.pileFix);
            await m.addColumn(messages, messages.focusFix);
            if (from >= 20) {
              await m.addColumn(helperVerdicts, helperVerdicts.pile);
              // The helper has since said where each email sits and what the
              // assistant read; an older version of the app let those go by.
              // Asking again from the start brings them all in, once.
              await customStatement("UPDATE settings SET value = '0' WHERE key = 'helper.cursor'");
            }
            await m.createTable(helperReadings);
            await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_message_id ON messages (message_id)');
          }
          if (from < 22) {
            await m.addColumn(messages, messages.laterUntil);
          }
          if (from < 23) {
            if (from >= 21) {
              await m.addColumn(helperReadings, helperReadings.sent);
              await m.addColumn(helperReadings, helperReadings.asks);
            }
            // The helper now also sends the day's sentence and its readings
            // of sent mail; an older version of the app let those go by.
            if (from >= 20) await customStatement("UPDATE settings SET value = '0' WHERE key = 'helper.cursor'");
          }
          if (from < 24) {
            await m.createTable(helperMarks);
            if (from >= 20) {
              await m.addColumn(helperSenders, helperSenders.pile);
              await m.addColumn(helperSenders, helperSenders.counts);
              await m.addColumn(helperSenders, helperSenders.label);
              await m.addColumn(helperSenders, helperSenders.subtitle);
              // What was set on other devices is taken in again, now that it is kept.
              await customStatement("UPDATE settings SET value = '0' WHERE key = 'helper.cursor'");
            }
            await _createHeldTriggers();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Full-text index over subject, sender, and body (spec 4.6, plan M6),
  /// kept in step with `messages` by triggers so the sync engine needs no
  /// extra code path. Bodies are indexed once fetched; until then the
  /// snippet stands in.
  Future<void> _createSearchIndex() async {
    await customStatement("CREATE VIRTUAL TABLE IF NOT EXISTS message_fts USING fts5(subject, sender, body, message_id UNINDEXED, tokenize = 'unicode61 remove_diacritics 2')");
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_fts_ins AFTER INSERT ON messages BEGIN
        INSERT INTO message_fts(message_id, subject, sender, body)
          VALUES (new.id, new.subject, new.from_name || ' ' || new.from_address, COALESCE(new.body_text, new.snippet));
      END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_fts_upd AFTER UPDATE OF subject, from_name, from_address, body_text, snippet ON messages BEGIN
        DELETE FROM message_fts WHERE message_id = old.id;
        INSERT INTO message_fts(message_id, subject, sender, body)
          VALUES (new.id, new.subject, new.from_name || ' ' || new.from_address, COALESCE(new.body_text, new.snippet));
      END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_fts_del AFTER DELETE ON messages BEGIN
        DELETE FROM message_fts WHERE message_id = old.id;
      END''');
  }

  Future<void> _seedBoardColumns() async {
    final n = (await customSelect('SELECT COUNT(*) AS n FROM board_columns').getSingle()).read<int>('n');
    if (n > 0) return;
    const defaults = ['Next', 'In Progress', 'Done'];
    for (var i = 0; i < defaults.length; i++) {
      await customStatement("INSERT INTO board_columns(name, sort_order) VALUES ('${defaults[i]}', $i)");
    }
  }

  Future<void> _seedFeedsCategories() async {
    const defaults = ['Newsletter', 'Receipt', 'Delivery', 'Travel', 'OTP', 'Notification', 'Social', 'Promotion', 'Updates'];
    for (var i = 0; i < defaults.length; i++) {
      await customStatement("INSERT OR IGNORE INTO feeds_categories(name, builtin, sort_order) VALUES ('${defaults[i]}', 1, $i)");
    }
  }

  Future<void> _createIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_message_id ON messages(message_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_timely ON messages(account_id, timely_checked_at)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_from_key ON messages(from_contact_key)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_participants_message ON message_participants(message_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_participants_key ON message_participants(contact_key)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_row_assign_row ON message_row_assignments(row_key)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_attachments_message ON attachments(message_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_thread ON messages(thread_key)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_tracker_message ON tracker_events(message_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_messages_provider_category ON messages(folder_id, provider_category)');
  }

  /// Triggers that mark People rows stale whenever anything that feeds a
  /// summary changes. Drift does not manage triggers, so they live here.
  /// Notes in `helper_outbox` whatever the user changes that the helper
  /// keeps for every device. Nothing is noted unless this device follows a
  /// helper, and nothing while a change from the helper is being written
  /// (that would send it straight back).
  Future<void> _createHelperTriggers() async {
    await customStatement('INSERT OR IGNORE INTO helper_state (id, connected, applying) VALUES (1, 0, 0)');
    const on = '(SELECT connected = 1 AND applying = 0 FROM helper_state WHERE id = 1)';
    String note(String kind, String key) => "INSERT OR IGNORE INTO helper_outbox (kind, k, data) VALUES ('$kind', $key, '')";
    final triggers = <String, String>{
      'trg_h_rowpref_i': 'AFTER INSERT ON row_prefs WHEN $on BEGIN ${note('rowpref', 'NEW.row_key')}; END',
      'trg_h_rowpref_u': 'AFTER UPDATE OF pinned, muted, snoozed_until, resurfaced_at ON row_prefs WHEN $on BEGIN ${note('rowpref', 'NEW.row_key')}; END',
      'trg_h_rowpref_d': 'AFTER DELETE ON row_prefs WHEN $on BEGIN ${note('rowpref', 'OLD.row_key')}; END',
      'trg_h_reminder_i': 'AFTER INSERT ON reminders WHEN $on AND NEW.uid IS NOT NULL BEGIN ${note('reminder', 'NEW.uid')}; END',
      'trg_h_reminder_u': 'AFTER UPDATE ON reminders WHEN $on AND NEW.uid IS NOT NULL BEGIN ${note('reminder', 'NEW.uid')}; END',
      'trg_h_reminder_d': 'AFTER DELETE ON reminders WHEN $on AND OLD.uid IS NOT NULL BEGIN ${note('reminder', 'OLD.uid')}; END',
      'trg_h_rule_i': 'AFTER INSERT ON classification_rules WHEN $on AND NEW.uid IS NOT NULL BEGIN ${note('rule', 'NEW.uid')}; END',
      'trg_h_rule_u': 'AFTER UPDATE ON classification_rules WHEN $on AND NEW.uid IS NOT NULL BEGIN ${note('rule', 'NEW.uid')}; END',
      'trg_h_rule_d': 'AFTER DELETE ON classification_rules WHEN $on AND OLD.uid IS NOT NULL BEGIN ${note('rule', 'OLD.uid')}; END',
      'trg_h_tag_i': 'AFTER INSERT ON feeds_categories WHEN $on BEGIN ${note('tag', 'NEW.name')}; END',
      'trg_h_tag_u': 'AFTER UPDATE OF sort_order ON feeds_categories WHEN $on BEGIN ${note('tag', 'NEW.name')}; END',
      'trg_h_tag_d': 'AFTER DELETE ON feeds_categories WHEN $on BEGIN ${note('tag', 'OLD.name')}; END',
      // A sender: only what the user owns. Who is a person is the helper's
      // to decide, unless the user moved the sender by hand.
      'trg_h_sender_u': '''AFTER UPDATE OF classification, classification_source, feeds_category, feeds_pile, counts_toward_unread, user_label, user_subtitle ON contacts
        WHEN $on AND NEW.is_me = 0 AND (
          (NEW.classification_source <> OLD.classification_source AND (NEW.classification_source = 'override' OR OLD.classification_source = 'override'))
          OR (NEW.classification_source = 'override' AND NEW.classification <> OLD.classification)
          OR COALESCE(NEW.feeds_category, '') <> COALESCE(OLD.feeds_category, '')
          OR COALESCE(NEW.feeds_pile, '') <> COALESCE(OLD.feeds_pile, '')
          OR NEW.counts_toward_unread <> OLD.counts_toward_unread
          OR COALESCE(NEW.user_label, '') <> COALESCE(OLD.user_label, '')
          OR COALESCE(NEW.user_subtitle, '') <> COALESCE(OLD.user_subtitle, ''))
        BEGIN ${note('sender', 'NEW.key')}; END''',
      'trg_h_book_i': 'AFTER INSERT ON contacts WHEN $on AND NEW.in_address_book = 1 BEGIN ${note('book', 'NEW.key')}; END',
      'trg_h_book_u': 'AFTER UPDATE OF in_address_book ON contacts WHEN $on AND NEW.in_address_book <> OLD.in_address_book BEGIN ${note('book', 'NEW.key')}; END',
      'trg_h_done_u': '''AFTER UPDATE OF done_at ON messages
        WHEN $on AND NEW.message_id IS NOT NULL AND NEW.message_id <> '' AND COALESCE(NEW.done_at, 0) <> COALESCE(OLD.done_at, 0)
        BEGIN ${note('done', 'NEW.message_id')}; END''',
      'trg_h_addr_i': 'AFTER INSERT ON contact_addresses WHEN $on AND NEW.address <> NEW.contact_key BEGIN ${note('addr', 'NEW.address')}; END',
      'trg_h_addr_u': 'AFTER UPDATE ON contact_addresses WHEN $on BEGIN ${note('addr', 'NEW.address')}; END',
      'trg_h_addr_d': 'AFTER DELETE ON contact_addresses WHEN $on BEGIN ${note('addr', 'OLD.address')}; END',
      'trg_h_me_i': "AFTER INSERT ON identities WHEN $on BEGIN ${note('me', "'*'")}; END",
      'trg_h_me_u': "AFTER UPDATE OF email, name ON identities WHEN $on BEGIN ${note('me', "'*'")}; END",
      'trg_h_me_d': "AFTER DELETE ON identities WHEN $on BEGIN ${note('me', "'*'")}; END",
    };
    for (final e in triggers.entries) {
      await customStatement('CREATE TRIGGER IF NOT EXISTS ${e.key} ${e.value}');
    }
  }

  /// Empties every table and gives the space back, leaving a database as
  /// new. Used when a device that joined by code is signed out.
  Future<void> wipeEverything() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        await customStatement('UPDATE helper_state SET connected = 0, applying = 0');
        // Twice: emptying one table can leave notes in another.
        for (var pass = 0; pass < 2; pass++) {
          for (final t in allTables) {
            await delete(t).go();
          }
        }
        await customStatement('DELETE FROM message_fts');
        await _seedFeedsCategories();
        await _seedBoardColumns();
        await customStatement('INSERT OR IGNORE INTO helper_state (id, connected, applying) VALUES (1, 0, 0)');
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
    try {
      await customStatement('VACUUM');
    } catch (_) {
      // Busy right now: the space is given back the next time.
    }
  }

  /// An email or a sender that lands here after its marks did takes them on
  /// at once. (The helper's word can travel faster than the mail itself:
  /// "done" pressed on the PC a minute ago, mail fetched on the phone now.)
  Future<void> _createHeldTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_held_msg AFTER INSERT ON messages
      WHEN NEW.message_id IS NOT NULL AND NEW.message_id <> '' AND EXISTS (SELECT 1 FROM helper_marks WHERE message_id = NEW.message_id)
      BEGIN
        UPDATE messages SET
          done_at = (SELECT done_at FROM helper_marks WHERE message_id = NEW.message_id),
          later_until = (SELECT later_until FROM helper_marks WHERE message_id = NEW.message_id),
          focus_fix = (SELECT focus_fix FROM helper_marks WHERE message_id = NEW.message_id),
          pile_fix = (SELECT pile_fix FROM helper_marks WHERE message_id = NEW.message_id)
        WHERE id = NEW.id;
      END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_held_contact AFTER INSERT ON contacts
      WHEN NEW.is_me = 0 AND EXISTS (SELECT 1 FROM helper_senders WHERE key = NEW.key)
      BEGIN
        UPDATE contacts SET
          feeds_pile = COALESCE((SELECT pile FROM helper_senders WHERE key = NEW.key), feeds_pile),
          counts_toward_unread = COALESCE((SELECT counts FROM helper_senders WHERE key = NEW.key), counts_toward_unread),
          user_label = COALESCE((SELECT label FROM helper_senders WHERE key = NEW.key), user_label),
          user_subtitle = COALESCE((SELECT subtitle FROM helper_senders WHERE key = NEW.key), user_subtitle)
        WHERE key = NEW.key;
      END''');
  }

  Future<void> _createTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_assign_ins AFTER INSERT ON message_row_assignments
      BEGIN INSERT OR IGNORE INTO dirty_rows(row_key) VALUES (NEW.row_key); END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_assign_del AFTER DELETE ON message_row_assignments
      BEGIN INSERT OR IGNORE INTO dirty_rows(row_key) VALUES (OLD.row_key); END''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_msg_upd AFTER UPDATE OF is_seen, is_flagged, is_deleted, has_attachments, classification,
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
    Directory? documents;
    try {
      documents = await getApplicationDocumentsDirectory();
    } catch (_) {}
    return resolveDatabasePath(support: support, documents: documents);
  }

  /// Pure part of [databasePath], testable with temp directories.
  ///
  /// Moves `documents/convomail.sqlite` to `support/convomail.sqlite` when
  /// the target is missing, or when the target exists but holds no accounts
  /// (a blank file created while the legacy one was still locked by an
  /// older running instance).
  static Future<String> resolveDatabasePath({required Directory support, required Directory? documents}) async {
    final target = p.join(support.path, 'convomail.sqlite');
    final legacy = documents == null ? null : p.join(documents.path, 'convomail.sqlite');
    if (legacy == null || !File(legacy).existsSync()) return target;
    try {
      final targetExists = File(target).existsSync();
      if (targetExists && !_isEmptyDatabase(target)) return target;
      if (!_hasAccounts(legacy)) return target;
      await support.create(recursive: true);
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final t = File('$target$suffix');
        if (t.existsSync()) await t.delete();
        final f = File('$legacy$suffix');
        if (f.existsSync()) await f.rename('$target$suffix');
      }
    } catch (_) {
      // Locked or unreadable: keep using the target; retried next launch.
    }
    return target;
  }

  static bool _isEmptyDatabase(String path) => !_hasAccounts(path);

  /// True when the file is a readable SQLite database with at least one
  /// account. Unreadable/locked files count as "has accounts" so they are
  /// never deleted.
  static bool _hasAccounts(String path) {
    sqlite.Database? db;
    try {
      db = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
      final hasTable = db.select("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'accounts'").isNotEmpty;
      if (!hasTable) return false;
      final n = db.select('SELECT COUNT(*) AS n FROM accounts').first['n'] as int;
      return n > 0;
    } catch (_) {
      return true;
    } finally {
      db?.close();
    }
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
