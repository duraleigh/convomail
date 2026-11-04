import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mail/sending_route.dart';
import '../../../platform/credential_store.dart';
import '../../../store/compose_queries.dart';
import '../../../store/database.dart';
import '../../theme/tokens.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/tonal_avatar.dart';
import '../chats/compose/compose_form.dart';
import 'sending_setup_dialog.dart';

/// Settings → Accounts → Identities & signatures (spec 4.4): per identity a
/// display name, a plain-text signature inserted into new messages and
/// replies, and which identity an account sends from by default.
class SignaturesSection extends ConsumerWidget {
  const SignaturesSection({super.key, required this.accounts});
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final identities = ref.watch(allIdentitiesProvider).value ?? const <Identity>[];
    if (accounts.isEmpty || identities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.xl),
        Text('Identities & signatures', style: text.titleMedium),
        const SizedBox(height: 4),
        Text('Signatures are added to new messages and replies and can be edited before sending.', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpace.md),
        GroupedList(
          children: [for (final i in identities) _IdentityTile(key: ValueKey('identity-${i.id}'), identity: i, account: accounts.where((a) => a.id == i.accountId).firstOrNull)],
        ),
      ],
    );
  }
}

class _IdentityTile extends ConsumerStatefulWidget {
  const _IdentityTile({super.key, required this.identity, required this.account});
  final Identity identity;
  final Account? account;

  @override
  ConsumerState<_IdentityTile> createState() => _IdentityTileState();
}

class _IdentityTileState extends ConsumerState<_IdentityTile> {
  late final _name = TextEditingController(text: widget.identity.name);
  late final _signature = TextEditingController(text: widget.identity.signature);
  Timer? _debounce;
  bool _saved = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _signature.dispose();
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      await ref.read(databaseProvider).updateIdentity(widget.identity.id, name: _name.text.trim(), signature: _signature.text.trimRight());
      if (mounted) setState(() => _saved = true);
    });
    if (_saved) setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final i = widget.identity;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TonalAvatar(identityKey: i.email, name: i.name.isEmpty ? i.email : i.name, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${i.email}${i.discovered ? '  ·  send-as alias' : ''}${widget.account != null && widget.account!.email != i.email ? '  ·  ${widget.account!.email}' : ''}',
                  style: text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_saved)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('Saved', style: text.labelSmall!.copyWith(color: scheme.primary)),
                ),
              ChoiceChip(
                label: const Text('Default'),
                selected: i.isDefault,
                onSelected: i.isDefault ? null : (_) => ref.read(databaseProvider).setDefaultIdentity(i.accountId, i.id),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (widget.account != null) _SendingRow(identity: i, account: widget.account!),
          const SizedBox(height: AppSpace.md),
          TextField(
            key: ValueKey('identity-name-${i.id}'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Display name', isDense: true, border: OutlineInputBorder()),
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            key: ValueKey('identity-signature-${i.id}'),
            controller: _signature,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Signature', hintText: 'Best,\nYour name', isDense: true, border: OutlineInputBorder(), alignLabelWithHint: true),
            onChanged: (_) => _changed(),
          ),
        ],
      ),
    );
  }
}

/// Whether the address can send, and the way to set it up when it can't.
class _SendingRow extends ConsumerWidget {
  const _SendingRow({required this.identity, required this.account});
  final Identity identity;
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final i = identity;
    final blocked = needsSendingSetup(i, account);
    final own = identityServer(i);
    final status = blocked
        ? "Can't send yet: mail from this address needs its own password, or it bounces."
        : own != null
        ? 'Sends through ${own.host}'
        : 'Sends through ${account.email}';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Row(
        children: [
          Icon(blocked ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, size: 18, color: blocked ? scheme.error : scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              key: ValueKey('identity-sending-${i.id}'),
              style: text.bodySmall!.copyWith(color: blocked ? scheme.error : scheme.onSurfaceVariant),
            ),
          ),
          if (blocked)
            FilledButton.tonal(key: ValueKey('identity-setup-${i.id}'), onPressed: () => showSendingSetupDialog(context, i), child: const Text('Set up sending'))
          else if (own != null) ...[
            TextButton(key: ValueKey('identity-setup-${i.id}'), onPressed: () => showSendingSetupDialog(context, i), child: const Text('Change')),
            TextButton(
              key: ValueKey('identity-unset-${i.id}'),
              onPressed: () async {
                await ref.read(databaseProvider).setIdentityServer(i.id, null);
                await ref.read(credentialStoreProvider).delete(CredentialStore.identityPasswordKey(i.id));
              },
              child: const Text('Remove'),
            ),
          ],
        ],
      ),
    );
  }
}
