import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/database.dart';
import '../store/sync_queries.dart';

/// Which account the Chats list shows (spec 4.14): null is the unified view.
final accountScopeProvider = NotifierProvider<AccountScopeNotifier, int?>(AccountScopeNotifier.new);

class AccountScopeNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? accountId) => state = accountId;
}

final accountsProvider = StreamProvider<List<Account>>((ref) => ref.watch(databaseProvider).watchAccounts());

/// True when more than one account exists, so account markers are shown.
final multiAccountProvider = Provider<bool>((ref) => (ref.watch(accountsProvider).value?.length ?? 0) > 1);

/// Stable color per account for the row dot and message marker.
Color accountColor(int accountId, ColorScheme scheme) {
  const palette = [Color(0xFF4653D0), Color(0xFF00897B), Color(0xFFD81B60), Color(0xFFF4511E), Color(0xFF6A1B9A), Color(0xFF2E7D32), Color(0xFF0277BD), Color(0xFFC0CA33)];
  return palette[accountId % palette.length];
}

/// Short label for an account: the part before @ when names repeat, else
/// the display name.
String accountShortLabel(Account a) {
  if (a.displayName.trim().isNotEmpty) return a.displayName.trim();
  final at = a.email.indexOf('@');
  return at > 0 ? a.email.substring(0, at) : a.email;
}
