import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/compose_queries.dart';
import '../../../store/database.dart';
import '../../theme/tokens.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/tonal_avatar.dart';
import '../chats/compose/compose_form.dart';

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
          children: [
            for (final i in identities) _IdentityTile(key: ValueKey('identity-${i.id}'), identity: i, account: accounts.where((a) => a.id == i.accountId).firstOrNull),
          ],
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
              if (_saved) Padding(padding: const EdgeInsets.only(right: 8), child: Text('Saved', style: text.labelSmall!.copyWith(color: scheme.primary))),
              ChoiceChip(
                label: const Text('Default'),
                selected: i.isDefault,
                onSelected: i.isDefault ? null : (_) => ref.read(databaseProvider).setDefaultIdentity(i.accountId, i.id),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
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
