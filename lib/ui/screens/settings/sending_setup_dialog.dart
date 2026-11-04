import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mail/mail_sender.dart';
import '../../../mail/mail_transport.dart';
import '../../../mail/models.dart';
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
  bool _showServer = false;
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
      await ref.read(credentialStoreProvider).write(CredentialStore.identityPasswordKey(widget.identity.id), credentials.password);
      await ref.read(databaseProvider).setIdentityServer(widget.identity.id, server, username: credentials.username == widget.identity.email ? null : credentials.username);
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
    final forwardEmail = _host.text.trim().toLowerCase().endsWith('forwardemail.net');
    return AlertDialog(
      title: Text('Send from $email'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enter the password for this address once. ConvoMail checks it, then mail from $email goes out properly.', style: text.bodyMedium),
            if (forwardEmail) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                'It is the password Forward Email made for this address (on forwardemail.net, open the address and choose Generate Password), '
                'the same one Gmail uses to send as $email.',
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
