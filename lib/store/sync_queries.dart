import 'package:drift/drift.dart';

import '../domain/filing.dart';
import '../domain/identity.dart';
import '../mail/models.dart';
import '../mail/outgoing.dart';
import 'database.dart';
import 'people_queries.dart';
import 'thread_queries.dart';

/// Database operations used by the sync engine and account setup.
extension SyncQueries on AppDatabase {
  // ---- identity and groups -------------------------------------------------

  /// Builds the resolver from every account/identity address (me) and the
  /// stored address → contact merges.
  Future<IdentityResolver> loadIdentityResolver() async {
    final accountRows = await select(accounts).get();
    final identityRows = await select(identities).get();
    final mine = <String>[...accountRows.map((a) => a.email), ...identityRows.map((i) => i.email)];
    final merges = <String, String>{};
    for (final ca in await select(contactAddresses).get()) {
      if (ca.address != ca.contactKey) merges[ca.address] = ca.contactKey;
    }
    return IdentityResolver(myAddresses: mine, addressToContact: merges);
  }

  Future<List<GroupDefinition>> loadGroupDefinitions() async {
    final members = await select(groupMembers).get();
    final byGroup = <int, List<String>>{};
    for (final m in members) {
      byGroup.putIfAbsent(m.groupId, () => []).add(m.contactKey);
    }
    return [for (final e in byGroup.entries) GroupDefinition(id: e.key, memberKeys: e.value)];
  }

  Future<FilingRule> loadFilingRule() async => FilingRule(await loadIdentityResolver(), groups: await loadGroupDefinitions());

  /// Every From address in the account's Sent folder was written by the
  /// user (Gmail "send as" aliases, custom domains). Adds any not yet known
  /// as identities and returns how many were new (spec 4.1 aliases).
  Future<int> discoverIdentitiesFromSent(int accountId, int sentFolderId) async {
    final known = <String>{};
    final acct = await accountById(accountId);
    if (acct != null) known.add(normalizeAddress(acct.email));
    for (final i in await (select(identities)..where((i) => i.accountId.equals(accountId))).get()) {
      known.add(normalizeAddress(i.email));
    }
    final fromQuery = selectOnly(messages, distinct: true)
      ..addColumns([messages.fromAddress, messages.fromName])
      ..where(messages.folderId.equals(sentFolderId) & messages.fromAddress.isNotValue(''));
    var added = 0;
    for (final row in await fromQuery.get()) {
      final address = normalizeAddress(row.read(messages.fromAddress)!);
      if (known.contains(address)) continue;
      known.add(address);
      await into(identities).insert(IdentitiesCompanion.insert(
        accountId: accountId,
        email: address,
        name: Value(row.read(messages.fromName) ?? ''),
        discovered: const Value(true),
      ));
      added++;
    }
    return added;
  }

  /// Recomputes identity resolution and filing for every message of an
  /// account. Run when the set of "me" addresses or groups changes.
  Future<void> refileAccount(int accountId) async {
    final filing = await loadFilingRule();
    final identity = filing.identity;
    await transaction(() async {
      final msgs = await (select(messages)..where((m) => m.accountId.equals(accountId))).get();
      for (final m in msgs) {
        await refileMessage(m, filing);
      }
      // Contacts that turned out to be the user are not people.
      for (final address in identity.myAddresses) {
        await (delete(contacts)..where((c) => c.key.equals(address))).go();
        await (delete(contactAddresses)..where((c) => c.address.equals(address))).go();
      }
    });
    await refreshDirtyRows();
  }

  /// Re-resolves one message's participants and sender and rewrites its row
  /// assignments when the filing outcome changed. Call inside a transaction.
  Future<void> refileMessage(Message m, FilingRule filing) async {
    final identity = filing.identity;
    final parts = await (select(messageParticipants)..where((p) => p.messageId.equals(m.id))).get();
    final to = <String>[];
    final cc = <String>[];
    for (final part in parts) {
      final r = identity.resolve(part.address);
      if (r.contactKey != part.contactKey || r.isMe != part.isMe) {
        await (update(messageParticipants)..where((p) => p.id.equals(part.id))).write(MessageParticipantsCompanion(contactKey: Value(r.contactKey), isMe: Value(r.isMe)));
      }
      if (part.role == 'to') to.add(part.address);
      if (part.role == 'cc') cc.add(part.address);
    }
    final sender = identity.resolve(m.fromAddress);
    if (sender.contactKey != m.fromContactKey || sender.isMe != m.isFromMe) {
      await (update(messages)..where((x) => x.id.equals(m.id))).write(MessagesCompanion(fromContactKey: Value(sender.contactKey), isFromMe: Value(sender.isMe)));
    }
    final filed = filing.file(MessageEnvelope(from: m.fromAddress, to: to, cc: cc));
    final current = (await (select(messageRowAssignments)..where((r) => r.messageId.equals(m.id))).get()).map((r) => r.rowKey).toSet();
    final wanted = filed.rows.map((r) => r.key).toSet();
    if (current.length != wanted.length || !current.containsAll(wanted)) {
      await (delete(messageRowAssignments)..where((r) => r.messageId.equals(m.id))).go();
      for (final key in wanted) {
        await into(messageRowAssignments).insert(MessageRowAssignmentsCompanion.insert(messageId: m.id, rowKey: key), mode: InsertMode.insertOrIgnore);
      }
    }
  }

  // ---- folders ---------------------------------------------------------------

  /// Inserts new folders, updates names/roles of known ones, and removes
  /// folders that no longer exist on the server. Returns path → row.
  Future<Map<String, Folder>> upsertFolders(int accountId, List<RemoteFolder> remote) async {
    return transaction(() async {
      final existing = {for (final f in await (select(folders)..where((f) => f.accountId.equals(accountId))).get()) f.path: f};
      final seen = <String>{};
      for (final r in remote) {
        seen.add(r.path);
        final row = existing[r.path];
        if (row == null) {
          await into(folders).insert(FoldersCompanion.insert(
            accountId: accountId,
            path: r.path,
            name: r.name,
            role: Value(r.role.name),
            selectable: Value(r.selectable),
          ));
        } else if (row.name != r.name || row.role != r.role.name || row.selectable != r.selectable) {
          await (update(folders)..where((f) => f.id.equals(row.id))).write(FoldersCompanion(
            name: Value(r.name),
            role: Value(r.role.name),
            selectable: Value(r.selectable),
          ));
        }
      }
      for (final gone in existing.keys.where((p) => !seen.contains(p))) {
        await (delete(folders)..where((f) => f.id.equals(existing[gone]!.id))).go();
      }
      return {for (final f in await (select(folders)..where((f) => f.accountId.equals(accountId))).get()) f.path: f};
    });
  }

  Future<Folder?> folderById(int id) => (select(folders)..where((f) => f.id.equals(id))).getSingleOrNull();

  Future<List<Folder>> foldersForAccount(int accountId) => (select(folders)..where((f) => f.accountId.equals(accountId))).get();

  Future<void> updateFolderState(
    int folderId, {
    int? uidValidity,
    int? uidNext,
    int? highestModSeq,
    int? lastSyncedUid,
    int? messagesExists,
    bool touchSyncTime = true,
  }) =>
      (update(folders)..where((f) => f.id.equals(folderId))).write(FoldersCompanion(
        uidValidity: uidValidity == null ? const Value.absent() : Value(uidValidity),
        uidNext: uidNext == null ? const Value.absent() : Value(uidNext),
        highestModSeq: highestModSeq == null ? const Value.absent() : Value(highestModSeq),
        lastSyncedUid: lastSyncedUid == null ? const Value.absent() : Value(lastSyncedUid),
        messagesExists: messagesExists == null ? const Value.absent() : Value(messagesExists),
        lastSyncAt: touchSyncTime ? Value(DateTime.now()) : const Value.absent(),
      ));

  /// UIDVALIDITY changed: every cached UID is meaningless. Wipe the folder.
  Future<void> clearFolderMessages(int folderId) async {
    await (delete(messages)..where((m) => m.folderId.equals(folderId))).go();
    await updateFolderState(folderId, lastSyncedUid: 0, highestModSeq: 0, touchSyncTime: false);
    await refreshDirtyRows();
  }

  // ---- messages --------------------------------------------------------------

  /// Inserts or refreshes headers, participants, contacts and row
  /// assignments in one transaction. Returns the number of new messages.
  Future<int> upsertHeaders(int accountId, int folderId, List<RemoteMessageHeader> headers, FilingRule filing, {List<int>? newIds}) async {
    if (headers.isEmpty) return 0;
    var inserted = 0;
    await transaction(() async {
      for (final h in headers) {
        final env = MessageEnvelope(from: h.from.address, to: [for (final a in h.to) a.address], cc: [for (final a in h.cc) a.address]);
        final filed = filing.file(env);
        final sender = filing.identity.resolve(h.from.address);

        final existing = await (select(messages)..where((m) => m.folderId.equals(folderId) & m.uid.equals(h.uid))).getSingleOrNull();
        final companion = MessagesCompanion(
          accountId: Value(accountId),
          folderId: Value(folderId),
          uid: Value(h.uid),
          messageId: Value(h.messageId),
          inReplyTo: Value(h.inReplyTo),
          referencesHeader: Value(h.references.isEmpty ? null : h.references.join(' ')),
          subject: Value(h.subject),
          fromAddress: Value(sender.address),
          fromName: Value(h.from.name),
          fromContactKey: Value(sender.contactKey),
          isFromMe: Value(sender.isMe),
          date: Value(h.date),
          internalDate: Value(h.internalDate),
          isSeen: Value(h.flags.seen),
          isFlagged: Value(h.flags.flagged),
          isAnswered: Value(h.flags.answered),
          isDraft: Value(h.flags.draft),
          isDeleted: Value(h.flags.deleted),
          size: Value(h.size),
          hasAttachments: Value(h.hasAttachments),
          snippet: Value(h.snippet),
          providerThreadId: Value(h.providerThreadId),
          bulkSignals: Value(h.signals.encode()),
        );

        int messageDbId;
        if (existing == null) {
          messageDbId = await into(messages).insert(companion);
          inserted++;
          newIds?.add(messageDbId);
        } else {
          messageDbId = existing.id;
          await (update(messages)..where((m) => m.id.equals(messageDbId))).write(companion);
          await (delete(messageParticipants)..where((p) => p.messageId.equals(messageDbId))).go();
          await (delete(messageRowAssignments)..where((r) => r.messageId.equals(messageDbId))).go();
        }

        await _insertParticipants(messageDbId, h, filing.identity);
        for (final row in filed.rows) {
          await into(messageRowAssignments).insert(
            MessageRowAssignmentsCompanion.insert(messageId: messageDbId, rowKey: row.key),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
    await refreshDirtyRows();
    // Thread the batch (new and refreshed headers alike).
    final dbIds = await (selectOnly(messages)
          ..addColumns([messages.id])
          ..where(messages.folderId.equals(folderId) & messages.uid.isIn(headers.map((h) => h.uid).toList())))
        .map((r) => r.read(messages.id)!)
        .get();
    await assignThreads(dbIds);
    return inserted;
  }

  Future<void> _insertParticipants(int messageDbId, RemoteMessageHeader h, IdentityResolver identity) async {
    final now = DateTime.now();
    Future<void> add(String role, RemoteAddress a) async {
      if (a.address.trim().isEmpty) return;
      final r = identity.resolve(a.address);
      await into(messageParticipants).insert(MessageParticipantsCompanion.insert(
        messageId: messageDbId,
        role: role,
        address: r.address,
        name: Value(a.name),
        contactKey: r.contactKey,
        isMe: Value(r.isMe),
      ));
      if (!r.isMe) await _touchContact(r, a.name, now);
    }

    await add('from', h.from);
    for (final a in h.to) {
      await add('to', a);
    }
    for (final a in h.cc) {
      await add('cc', a);
    }
  }

  Future<void> _touchContact(ResolvedIdentity r, String name, DateTime now) async {
    final existing = await (select(contacts)..where((c) => c.key.equals(r.contactKey))).getSingleOrNull();
    if (existing == null) {
      await into(contacts).insert(
        ContactsCompanion.insert(key: r.contactKey, displayName: Value(name), firstSeenAt: Value(now), lastSeenAt: Value(now)),
        mode: InsertMode.insertOrIgnore,
      );
    } else {
      await (update(contacts)..where((c) => c.key.equals(r.contactKey))).write(ContactsCompanion(
        lastSeenAt: Value(now),
        displayName: existing.displayName.isEmpty && name.isNotEmpty ? Value(name) : const Value.absent(),
      ));
    }
    await into(contactAddresses).insert(
      ContactAddressesCompanion.insert(address: r.address, contactKey: r.contactKey),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Removes local messages in [folderId] whose UID is in [lowUid]..[highUid]
  /// but no longer on the server. Returns how many were removed.
  Future<int> deleteVanished(int folderId, Set<int> serverUids, {required int lowUid, required int highUid}) async {
    final local = await (select(messages)
          ..where((m) => m.folderId.equals(folderId) & m.uid.isBiggerOrEqualValue(lowUid) & m.uid.isSmallerOrEqualValue(highUid)))
        .get();
    final gone = [for (final m in local) if (!serverUids.contains(m.uid)) m.id];
    if (gone.isEmpty) return 0;
    await (delete(messages)..where((m) => m.id.isIn(gone))).go();
    await refreshDirtyRows();
    return gone.length;
  }

  Future<int> applyFlagUpdates(int folderId, List<RemoteFlagUpdate> updates) async {
    var changed = 0;
    await transaction(() async {
      for (final u in updates) {
        final n = await (update(messages)..where((m) => m.folderId.equals(folderId) & m.uid.equals(u.uid))).write(MessagesCompanion(
          isSeen: Value(u.flags.seen),
          isFlagged: Value(u.flags.flagged),
          isAnswered: Value(u.flags.answered),
          isDraft: Value(u.flags.draft),
          isDeleted: Value(u.flags.deleted),
        ));
        changed += n;
      }
    });
    await refreshDirtyRows();
    return changed;
  }

  Future<void> storeBody(int messageDbId, RemoteMessageBody body) async {
    await transaction(() async {
      // HTML-only mail gets a derived text body so search can index it;
      // the renderer still prefers bodyHtml when present.
      final text = body.text ?? (body.html == null ? null : MimeFactory.htmlToPlainText(body.html!));
      final snippet = _snippetFrom(text ?? '');
      await (update(messages)..where((m) => m.id.equals(messageDbId))).write(MessagesCompanion(
        bodyText: Value(text),
        icsText: Value(body.calendar),
        bodyHtml: Value(body.html),
        bodyFetchedAt: Value(DateTime.now()),
        snippet: snippet.isEmpty ? const Value.absent() : Value(snippet),
        hasAttachments: Value(body.attachments.any((a) => !a.isInline)),
      ));
      await (delete(attachments)..where((a) => a.messageId.equals(messageDbId))).go();
      for (final a in body.attachments) {
        await into(attachments).insert(AttachmentsCompanion.insert(
          messageId: messageDbId,
          partId: a.partId,
          fileName: Value(a.fileName),
          mimeType: Value(a.mimeType),
          size: Value(a.size),
          contentId: Value(a.contentId),
          isInline: Value(a.isInline),
        ));
      }
    });
    await refreshDirtyRows();
  }

  static String _snippetFrom(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length <= 160 ? collapsed : '${collapsed.substring(0, 157)}…';
  }


  Future<Message?> messageById(int id) => (select(messages)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<int> messageCountForFolder(int folderId) async {
    final c = messages.id.count();
    final q = selectOnly(messages)
      ..addColumns([c])
      ..where(messages.folderId.equals(folderId));
    return (await q.getSingle()).read(c) ?? 0;
  }

  Future<int> messageCountForAccount(int accountId) async {
    final c = messages.id.count();
    final q = selectOnly(messages)
      ..addColumns([c])
      ..where(messages.accountId.equals(accountId));
    return (await q.getSingle()).read(c) ?? 0;
  }

  // ---- accounts --------------------------------------------------------------

  Future<List<Account>> allAccounts() => (select(accounts)..orderBy([(a) => OrderingTerm.asc(a.sortOrder), (a) => OrderingTerm.asc(a.id)])).get();

  Stream<List<Account>> watchAccounts() => (select(accounts)..orderBy([(a) => OrderingTerm.asc(a.sortOrder), (a) => OrderingTerm.asc(a.id)])).watch();

  Future<Account?> accountById(int id) => (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<void> setAccountSyncResult(int accountId, {String? error}) => (update(accounts)..where((a) => a.id.equals(accountId))).write(AccountsCompanion(
        lastSyncAt: Value(DateTime.now()),
        lastError: Value(error),
      ));

  Future<void> deleteAccount(int accountId) => (delete(accounts)..where((a) => a.id.equals(accountId))).go();
}
