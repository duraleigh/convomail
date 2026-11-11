import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mail/mail_sender.dart';
import '../../../mail/mail_transport.dart';
import '../../../mail/models.dart';
import '../../../mail/sending_route.dart';
import '../../../platform/credential_store.dart';
import '../../../store/compose_queries.dart';
import '../../../store/database.dart';

/// Adds an address to send from. When another address on the same domain
/// already sends through its own server with a domain-wide password, the new
/// one gets the same password, once the server accepts it for the new address.
Future<void> showAddAddressDialog(BuildContext context, List<Account> accounts) => showDialog<void>(
      context: context,
      builder: (_) => AddAddressDialog(accounts: accounts),
    );

/// Gives [identity] the server and password of another address on its domain,
/// when the server accepts that password for it. Returns true when it did.
Future<bool> reuseDomainSending({
  required AppDatabase db,
  required CredentialStore store,
  required MailSender sender,
  required Identity identity,
}) async {
  final domain = emailDomain(identity.email);
  for (final other in await db.identitiesForAccount(identity.accountId)) {
    if (other.id == identity.id || emailDomain(other.email) != domain) continue;
    final server = identityServer(other);
    // Only a password that signs in as each address itself (a domain-wide one).
    if (server == null || other.smtpUsername != null) continue;
    final password = await store.read(CredentialStore.identityPasswordKey(other.id));
    if (password == null) continue;
    try {
      await sender.verify(server, MailCredentials(username: identity.email, password: password));
    } on MailTransportException {
      continue;
    }
    await store.write(CredentialStore.identityPasswordKey(identity.id), password);
    await db.setIdentityServer(identity.id, server);
    return true;
  }
  return false;
}

class AddAddressDialog extends ConsumerStatefulWidget {
  const AddAddressDialog({super.key, required this.accounts});
  final List<Account> accounts;

  @override
  ConsumerState<AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends ConsumerState<AddAddressDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  late Account _account = widget.accounts.first;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  static final _shape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _add() async {
    final email = _email.text.trim().toLowerCase();
    if (!_shape.hasMatch(email)) {
      setState(() => _error = 'Enter an email address, like name@example.com.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final id = await db.addIdentity(_account.id, email, name: _name.text.trim());
    final identity = (await db.identityById(id))!;
    var ready = !needsSendingSetup(identity, _account);
    if (!ready) {
      ready = await reuseDomainSending(db: db, store: ref.read(credentialStoreProvider), sender: ref.read(mailSenderProvider), identity: identity);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(persist: false, 
      content: Text(ready ? '$email is added and ready to send.' : '$email is added. Click "Set up sending" next to it before sending from it.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add an address'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('An address you send from. Replies to it should already reach this account.', style: text.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('add-address-email'),
              controller: _email,
              autofocus: true,
              enabled: !_working,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address', border: OutlineInputBorder()),
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('add-address-name'),
              controller: _name,
              enabled: !_working,
              decoration: const InputDecoration(labelText: 'Name shown to people (optional)', border: OutlineInputBorder()),
              onSubmitted: (_) => _add(),
            ),
            if (widget.accounts.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<Account>(
                initialValue: _account,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [for (final a in widget.accounts) DropdownMenuItem(value: a, child: Text(a.email))],
                onChanged: _working ? null : (a) => setState(() => _account = a ?? _account),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const ValueKey('add-address-error'), style: text.bodyMedium!.copyWith(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _working ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('add-address-save'),
          onPressed: _working ? null : _add,
          child: _working ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add'),
        ),
      ],
    );
  }
}
