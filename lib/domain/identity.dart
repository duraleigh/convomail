/// Identity resolution (spec 4.14, decision 8).
///
/// All of the user's addresses and aliases resolve to [IdentityResolver.me].
/// A contact's several addresses resolve to one canonical contact key.
/// Pure Dart; the database feeds it the known merges.
library;

/// Normalizes an email address for comparison and storage:
/// trimmed, lower-cased, angle brackets removed. For Gmail domains the
/// local part's dots and any `+tag` are removed, because Gmail treats those
/// as the same mailbox and people write them inconsistently.
String normalizeAddress(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.startsWith('<') && s.endsWith('>')) s = s.substring(1, s.length - 1);
  final at = s.lastIndexOf('@');
  if (at <= 0) return s;
  var local = s.substring(0, at);
  var domain = s.substring(at + 1);
  if (domain == 'googlemail.com') domain = 'gmail.com';
  if (domain == 'gmail.com') {
    final plus = local.indexOf('+');
    if (plus > 0) local = local.substring(0, plus);
    local = local.replaceAll('.', '');
  }
  return '$local@$domain';
}

/// The result of resolving one address.
class ResolvedIdentity {
  const ResolvedIdentity({required this.address, required this.contactKey, required this.isMe});

  /// Normalized address as written.
  final String address;

  /// Canonical contact key. [IdentityResolver.me] for the user's own addresses.
  final String contactKey;
  final bool isMe;

  @override
  bool operator ==(Object other) =>
      other is ResolvedIdentity && other.address == address && other.contactKey == contactKey && other.isMe == isMe;

  @override
  int get hashCode => Object.hash(address, contactKey, isMe);

  @override
  String toString() => 'ResolvedIdentity($address → $contactKey${isMe ? ', me' : ''})';
}

class IdentityResolver {
  IdentityResolver({
    required Iterable<String> myAddresses,
    Map<String, String> addressToContact = const {},
  })  : _me = {for (final a in myAddresses) normalizeAddress(a)},
        _merges = {for (final e in addressToContact.entries) normalizeAddress(e.key): normalizeAddress(e.value)};

  /// The single key every one of the user's addresses resolves to.
  static const String me = 'me';

  final Set<String> _me;
  final Map<String, String> _merges;

  Set<String> get myAddresses => Set.unmodifiable(_me);

  bool isMe(String address) => _me.contains(normalizeAddress(address));

  /// Canonical contact key for an address. Follows user/observed merges one
  /// hop (merges are stored flattened, so one hop is enough).
  String contactKeyFor(String address) {
    final n = normalizeAddress(address);
    if (_me.contains(n)) return me;
    return _merges[n] ?? n;
  }

  ResolvedIdentity resolve(String address) {
    final n = normalizeAddress(address);
    final mine = _me.contains(n);
    return ResolvedIdentity(address: n, contactKey: mine ? me : (_merges[n] ?? n), isMe: mine);
  }

  /// Distinct contact keys for a list of addresses, excluding the user.
  /// This is the participant set used by the group exact-match rule (4.19).
  Set<String> participantKeys(Iterable<String> addresses) {
    final keys = <String>{};
    for (final a in addresses) {
      final r = resolve(a);
      if (!r.isMe) keys.add(r.contactKey);
    }
    return keys;
  }

  /// A resolver with an extra merge applied (used when the user confirms
  /// two addresses are one person).
  IdentityResolver withMerge(String address, String intoContactKey) => IdentityResolver(
        myAddresses: _me,
        addressToContact: {..._merges, normalizeAddress(address): normalizeAddress(intoContactKey)},
      );
}
