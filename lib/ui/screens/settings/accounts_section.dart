import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mail/account_setup.dart';
import '../../../mail/models.dart';
import '../../../store/database.dart';
import '../../../store/sync_queries.dart';
import '../../../sync/sync_controller.dart';
import '../../../sync/sync_engine.dart';
import '../../theme/tokens.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/tonal_avatar.dart';
import '../../widgets/wavy_progress.dart';

final accountsStreamProvider = StreamProvider<List<Account>>((ref) => ref.watch(databaseProvider).watchAccounts());

/// Settings → Accounts (spec 4.1, 4.18): the account list with live sync
/// status, and an in-place add-account flow. No dialogs, no new windows.
class AccountsDetail extends ConsumerStatefulWidget {
  const AccountsDetail({super.key, this.startAdding = false});
  final bool startAdding;

  @override
  ConsumerState<AccountsDetail> createState() => _AccountsDetailState();
}

class _AccountsDetailState extends ConsumerState<AccountsDetail> {
  late bool _adding = widget.startAdding;

  @override
  void didUpdateWidget(AccountsDetail old) {
    super.didUpdateWidget(old);
    // Open on the rising edge only; the request flag is cleared right after
    // it is consumed, and that must not close the panel.
    if (widget.startAdding && !old.startAdding) _adding = true;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsStreamProvider);
    final statuses = ref.watch(syncStatusProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListView(
      children: [
        accounts.when(
          loading: () => const SizedBox(height: 48),
          error: (e, _) => Text('$e', style: text.bodyMedium!.copyWith(color: scheme.error)),
          data: (list) => list.isEmpty && !_adding
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.lg),
                  child: Text('No accounts yet. Add one to start syncing.', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
                )
              : GroupedList(
                  children: [
                    for (final a in list) _AccountTile(account: a, status: statuses[a.id]),
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.md),
        if (!_adding)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => setState(() => _adding = true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add account'),
            ),
          )
        else
          _AddAccountPanel(onClose: () => setState(() => _adding = false)),
      ],
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.status});
  final Account account;
  final SyncStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (label, color) = _statusLine(scheme);
    return ListTile(
      leading: TonalAvatar(identityKey: account.email, name: account.displayName.isEmpty ? account.email : account.displayName, size: 40),
      title: Text(account.email),
      subtitle: Text(label, style: text.bodySmall!.copyWith(color: color)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status?.phase == SyncPhase.syncingFolder || status?.phase == SyncPhase.connecting || status?.phase == SyncPhase.listingFolders)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          if (status == null || status?.phase == SyncPhase.error || status?.phase == SyncPhase.stopped)
            IconButton(
              tooltip: 'Sync now',
              icon: const Icon(Icons.sync_rounded),
              onPressed: () => ref.read(syncControllerProvider).restartAccount(account.id),
            ),
          IconButton(
            tooltip: 'Remove account',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _confirmRemove(context, ref),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusLine(ColorScheme scheme) {
    final s = status;
    final provider = account.providerId == 'custom' ? 'IMAP' : account.providerId;
    if (s == null) return ('$provider · not started', scheme.onSurfaceVariant);
    return switch (s.phase) {
      SyncPhase.connecting => ('Connecting…', scheme.onSurfaceVariant),
      SyncPhase.listingFolders => ('Reading folders…', scheme.onSurfaceVariant),
      SyncPhase.syncingFolder => ('Syncing ${s.folderPath ?? ''} · ${s.messagesFetched} messages', scheme.onSurfaceVariant),
      SyncPhase.waitingForMail => ('Up to date · listening for new mail', scheme.primary),
      SyncPhase.idle => ('Synced', scheme.primary),
      SyncPhase.backoff => ('Reconnecting ${s.message ?? ''}', scheme.onSurfaceVariant),
      SyncPhase.error => (s.error ?? 'Error', scheme.error),
      SyncPhase.stopped => ('Stopped', scheme.onSurfaceVariant),
    };
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text('${account.email} and its cached mail are removed from this computer. Nothing changes on the server.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await ref.read(accountSetupProvider).remove(account.id);
  }
}

class _AddAccountPanel extends ConsumerStatefulWidget {
  const _AddAccountPanel({required this.onClose});
  final VoidCallback onClose;

  @override
  ConsumerState<_AddAccountPanel> createState() => _AddAccountPanelState();
}

class _AddAccountPanelState extends ConsumerState<_AddAccountPanel> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _imapHost = TextEditingController();
  final _imapPort = TextEditingController();
  final _smtpHost = TextEditingController();
  final _smtpPort = TextEditingController();
  ConnectionSecurity _imapSecurity = ConnectionSecurity.ssl;
  ConnectionSecurity _smtpSecurity = ConnectionSecurity.ssl;

  AccountProposal? _proposal;
  bool _advanced = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    for (final c in [_email, _name, _password, _username, _imapHost, _imapPort, _smtpHost, _smtpPort]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onEmailChanged() {
    final e = _email.text.trim();
    if (!e.contains('@') || e.endsWith('@')) return;
    final p = ref.read(accountSetupProvider).propose(e);
    if (_proposal?.providerId == p.providerId && _proposal?.imap.host == p.imap.host) return;
    setState(() {
      _proposal = p;
      _username.text = p.username;
      _imapHost.text = p.imap.host;
      _imapPort.text = '${p.imap.port}';
      _imapSecurity = p.imap.security;
      _smtpHost.text = p.smtp.host;
      _smtpPort.text = '${p.smtp.port}';
      _smtpSecurity = p.smtp.security;
    });
  }

  AccountProposal _effectiveProposal() {
    final base = _proposal ?? ref.read(accountSetupProvider).propose(_email.text.trim());
    if (!_advanced) return base.copyWith(username: _username.text.trim().isEmpty ? base.username : _username.text.trim());
    return base.copyWith(
      username: _username.text.trim(),
      imap: ServerConfig(host: _imapHost.text.trim(), port: int.tryParse(_imapPort.text.trim()) ?? 993, security: _imapSecurity),
      smtp: ServerConfig(host: _smtpHost.text.trim(), port: int.tryParse(_smtpPort.text.trim()) ?? 465, security: _smtpSecurity),
    );
  }

  Future<void> _connect() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final setup = ref.read(accountSetupProvider);
    final proposal = _effectiveProposal();
    final result = await setup.testImap(proposal, _password.text);
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.error;
      });
      return;
    }
    await setup.save(proposal.copyWith(imap: result.imap), _password.text, displayName: _name.text.trim());
    _password.clear();
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final help = _proposal?.profile?.appPasswordHelp;

    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(AppShapes.xl)),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Add account', style: text.titleMedium)),
                IconButton(tooltip: 'Cancel', onPressed: _busy ? null : widget.onClose, icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              width: 440,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email address'),
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    validator: (v) => (v ?? '').contains('@') ? null : 'Enter an email address',
                    enabled: !_busy,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Your name (shown on sent mail)'),
                    enabled: !_busy,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: _proposal?.profile?.appPasswordHelp != null ? 'App password' : 'Password',
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show' : 'Hide',
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v ?? '').isEmpty ? 'Enter the password' : null,
                    onFieldSubmitted: (_) => _connect(),
                    enabled: !_busy,
                  ),
                ],
              ),
            ),
            if (help != null) ...[
              const SizedBox(height: AppSpace.md),
              Container(
                width: 440,
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.key_outlined, size: 18, color: scheme.onPrimaryContainer),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(child: Text(help, style: text.bodySmall!.copyWith(color: scheme.onPrimaryContainer))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpace.md),
            TextButton.icon(
              onPressed: _busy ? null : () => setState(() => _advanced = !_advanced),
              icon: Icon(_advanced ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: Text(_advanced ? 'Hide server settings' : 'Server settings'),
            ),
            if (_advanced)
              _AdvancedFields(
                username: _username,
                imapHost: _imapHost,
                imapPort: _imapPort,
                smtpHost: _smtpHost,
                smtpPort: _smtpPort,
                imapSecurity: _imapSecurity,
                smtpSecurity: _smtpSecurity,
                onImapSecurity: (v) => setState(() => _imapSecurity = v),
                onSmtpSecurity: (v) => setState(() => _smtpSecurity = v),
              ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              Text(_error!, style: text.bodyMedium!.copyWith(color: scheme.error)),
            ],
            const SizedBox(height: AppSpace.lg),
            if (_busy) ...[
              const SizedBox(width: 440, child: WavyLinearProgress(semanticsLabel: 'Connecting')),
              const SizedBox(height: AppSpace.sm),
              Text('Connecting to ${_effectiveProposal().imap.host}…', style: text.bodySmall),
            ] else
              FilledButton.icon(onPressed: _connect, icon: const Icon(Icons.login_rounded), label: const Text('Connect')),
          ],
        ),
      ),
    );
  }
}

class _AdvancedFields extends StatelessWidget {
  const _AdvancedFields({
    required this.username,
    required this.imapHost,
    required this.imapPort,
    required this.smtpHost,
    required this.smtpPort,
    required this.imapSecurity,
    required this.smtpSecurity,
    required this.onImapSecurity,
    required this.onSmtpSecurity,
  });

  final TextEditingController username;
  final TextEditingController imapHost;
  final TextEditingController imapPort;
  final TextEditingController smtpHost;
  final TextEditingController smtpPort;
  final ConnectionSecurity imapSecurity;
  final ConnectionSecurity smtpSecurity;
  final ValueChanged<ConnectionSecurity> onImapSecurity;
  final ValueChanged<ConnectionSecurity> onSmtpSecurity;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget security(ConnectionSecurity value, ValueChanged<ConnectionSecurity> onChanged) => DropdownButtonFormField<ConnectionSecurity>(
          initialValue: value,
          decoration: const InputDecoration(labelText: 'Security'),
          items: const [
            DropdownMenuItem(value: ConnectionSecurity.ssl, child: Text('SSL/TLS')),
            DropdownMenuItem(value: ConnectionSecurity.starttls, child: Text('STARTTLS')),
            DropdownMenuItem(value: ConnectionSecurity.none, child: Text('None')),
          ],
          onChanged: (v) => onChanged(v ?? ConnectionSecurity.ssl),
        );

    return SizedBox(
      width: 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: AppSpace.lg),
          Text('Incoming (IMAP)', style: text.labelSmall),
          const SizedBox(height: AppSpace.xs),
          Row(children: [
            Expanded(flex: 3, child: TextFormField(controller: imapHost, decoration: const InputDecoration(labelText: 'Host'))),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: TextFormField(controller: imapPort, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number)),
            const SizedBox(width: AppSpace.sm),
            Expanded(flex: 2, child: security(imapSecurity, onImapSecurity)),
          ]),
          const SizedBox(height: AppSpace.lg),
          Text('Outgoing (SMTP)', style: text.labelSmall),
          const SizedBox(height: AppSpace.xs),
          Row(children: [
            Expanded(flex: 3, child: TextFormField(controller: smtpHost, decoration: const InputDecoration(labelText: 'Host'))),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: TextFormField(controller: smtpPort, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number)),
            const SizedBox(width: AppSpace.sm),
            Expanded(flex: 2, child: security(smtpSecurity, onSmtpSecurity)),
          ]),
        ],
      ),
    );
  }
}
