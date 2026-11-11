import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../helper/sending_sync.dart';
import '../../../mail/mail_sender.dart';
import '../../../mail/mail_transport.dart';
import '../../../mail/models.dart';
import '../../../mail/provider_config.dart';
import '../../../mail/sending_route.dart';
import '../../../platform/credential_store.dart';
import '../../../store/compose_queries.dart';
import '../../../store/database.dart';
import '../../theme/tokens.dart';

/// Sets up an address to send through its own mail server: one password,
/// checked against the server before it is saved. Returns true when saved.
Future<bool> showSendingSetupDialog(BuildContext context, Identity identity) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => SendingSetupDialog(identity: identity),
    ) ??
    false;

class SendingSetupDialog extends ConsumerStatefulWidget {
  const SendingSetupDialog({super.key, required this.identity});
  final Identity identity;

  @override
  ConsumerState<SendingSetupDialog> createState() => _SendingSetupDialogState();
}

class _SendingSetupDialogState extends ConsumerState<SendingSetupDialog> {
  late final ServerConfig _start = identityServer(widget.identity) ?? suggestedServerFor(widget.identity.email);
  late final _host = TextEditingController(text: _start.host);
  late final _port = TextEditingController(text: '${_start.port}');
  late final _username = TextEditingController(text: widget.identity.smtpUsername ?? widget.identity.email);
  final _password = TextEditingController();
  late ConnectionSecurity _security = _start.security;
  late final String _domain = emailDomain(widget.identity.email);
  bool _wholeDomain = true;
  List<String> _peers = const [];
  bool _showServer = false;

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider).identitiesForAccount(widget.identity.accountId).then((all) {
      if (!mounted) return;
      setState(() => _peers = [for (final i in all) if (i.id != widget.identity.id && i.smtpHost == null && emailDomain(i.email) == _domain) i.email]);
    });
  }
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_host, _port, _username, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter the password.');
      return;
    }
    final server = ServerConfig(host: _host.text.trim(), port: int.tryParse(_port.text.trim()) ?? 465, security: _security);
    final credentials = MailCredentials(username: _username.text.trim(), password: _password.text);
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      // Signs in without sending, so a wrong password shows up here and
      // not as a bounced email later.
      await ref.read(mailSenderProvider).verify(server, credentials);
      final db = ref.read(databaseProvider);
      final store = ref.read(credentialStoreProvider);
      final ownUsername = credentials.username.toLowerCase() == widget.identity.email.toLowerCase();
      // A domain-wide password (Forward Email's catch-all password) works
      // for every address on the domain, each signing in as itself.
      final targets = [
        widget.identity,
        if (_wholeDomain && ownUsername && _peers.isNotEmpty)
          for (final i in await db.identitiesForAccount(widget.identity.accountId))
            if (_peers.contains(i.email)) i,
      ];
      for (final i in targets) {
        await store.write(CredentialStore.identityPasswordKey(i.id), credentials.password);
        ref.read(sendingSyncProvider).passwordChanged();
        await db.setIdentityServer(i.id, server, username: i.id == widget.identity.id && !ownUsername ? credentials.username : null);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on MailTransportException catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = e.isAuthFailure ? 'That password was not accepted. Check it and try again.' : e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final email = widget.identity.email;
    final provider = ProviderProfiles.forEmail(email);
    final forwardEmail =_host.text.trim().toLowerCase().endsWith('forwardemail.net');
    return AlertDialog(
      title: Text('Send from $email'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enter the password for this address once. Précis checks it, then mail from $email goes out properly.', style: text.bodyMedium),
            if (provider != null && provider.appPasswordHelp != null && _host.text.trim().toLowerCase() == provider.smtp.host) ...[
              const SizedBox(height: AppSpace.sm),
              Text(provider.appPasswordHelp!, key: const ValueKey('sending-provider-help'), style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
              if (provider.appPasswordUrl != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse(provider.appPasswordUrl!)),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text('Open ${Uri.parse(provider.appPasswordUrl!).host}'),
                  ),
                ),
            ],
            if (forwardEmail) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                'Use the Forward Email password for this address, or the catch-all password for $_domain, which works for every address on it.',
                style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            TextField(
              key: const ValueKey('sending-password'),
              controller: _password,
              autofocus: true,
              obscureText: true,
              enabled: !_working,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              onSubmitted: (_) => _save(),
            ),
            if (_peers.isNotEmpty)
              CheckboxListTile(
                key: const ValueKey('sending-whole-domain'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                value: _wholeDomain,
                onChanged: _working ? null : (v) => setState(() => _wholeDomain = v ?? false),
                title: Text('Also use it for ${_peers.join(', ')}'),
              )
            else
              const SizedBox(height: AppSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('sending-server-toggle'),
                onPressed: () => setState(() => _showServer = !_showServer),
                child: Text(_showServer ? 'Hide server settings' : 'Server: ${_host.text.trim()}'),
              ),
            ),
            if (_showServer) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _host,
                      decoration: const InputDecoration(labelText: 'Server'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: TextField(
                      controller: _port,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<ConnectionSecurity>(
                      initialValue: _security,
                      decoration: const InputDecoration(labelText: 'Security'),
                      items: const [
                        DropdownMenuItem(value: ConnectionSecurity.ssl, child: Text('SSL/TLS')),
                        DropdownMenuItem(value: ConnectionSecurity.starttls, child: Text('STARTTLS')),
                      ],
                      onChanged: (v) => setState(() => _security = v ?? ConnectionSecurity.ssl),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              Text(
                _error!,
                key: const ValueKey('sending-error'),
                style: text.bodyMedium!.copyWith(color: scheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _working ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('sending-save'),
          onPressed: _working ? null : _save,
          child: _working ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Check and save'),
        ),
      ],
    );
  }
}
