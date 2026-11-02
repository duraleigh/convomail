import 'package:drift/drift.dart';

import 'database.dart';

/// The user's Google contacts as far as this app needs them: which addresses
/// are in the address book, and each one's photo (spec 4.2).
extension AddressBookQueries on AppDatabase {
  Future<List<AddressBookEntry>> addressBookEntries() => select(addressBookEntryRows).get();

  Future<void> upsertAddressBookPerson(String resourceName, Iterable<String> addresses, {String? photoPath, String? photoUrl}) => transaction(() async {
        await (delete(addressBookEntryRows)..where((e) => e.resourceName.equals(resourceName))).go();
        for (final a in addresses) {
          await into(addressBookEntryRows).insertOnConflictUpdate(AddressBookEntryRowsCompanion.insert(address: a, resourceName: resourceName, photoPath: Value(photoPath), photoUrl: Value(photoUrl)));
        }
      });

  Future<void> removeAddressBookPerson(String resourceName) => (delete(addressBookEntryRows)..where((e) => e.resourceName.equals(resourceName))).go();

  Future<void> clearAddressBook() => delete(addressBookEntryRows).go();

  /// Brings contacts in line with the address book, through every address a
  /// contact files under, so a merged person gets the photo from either.
  /// Returns the contacts whose in-address-book state changed; those need
  /// deciding again.
  Future<Set<String>> applyAddressBook() async {
    final entries = await addressBookEntries();
    final byAddress = {for (final a in await select(contactAddresses).get()) a.address: a.contactKey};
    final people = await select(contacts).get();
    final known = {for (final c in people) c.key};
    final inBook = <String>{};
    final photos = <String, String>{};
    for (final e in entries) {
      final key = byAddress[e.address] ?? (known.contains(e.address) ? e.address : null);
      if (key == null) continue;
      inBook.add(key);
      final path = e.photoPath;
      if (path != null) photos.putIfAbsent(key, () => path);
    }
    final changed = <String>{};
    await transaction(() async {
      for (final c in people) {
        if (c.isMe) continue;
        final book = inBook.contains(c.key);
        final photo = photos[c.key];
        if (c.inAddressBook == book && c.photoPath == photo) continue;
        await (update(contacts)..where((x) => x.key.equals(c.key))).write(ContactsCompanion(inAddressBook: Value(book), photoPath: Value(photo)));
        if (c.inAddressBook != book) changed.add(c.key);
      }
    });
    return changed;
  }
}
