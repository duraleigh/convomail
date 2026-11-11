import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/database.dart';
import '../../../sync/contacts_sync.dart';
import '../../widgets/grouped_list.dart';

/// Settings → Google Contacts: connects the address book, for photos.
class GoogleContactsDetail extends ConsumerStatefulWidget {
  const GoogleContactsDetail({super.key});

  @override
  ConsumerState<GoogleContactsDetail> createState() => _GoogleContactsDetailState();
}

class _GoogleContactsDetailState extends ConsumerState<GoogleContactsDetail> {
  bool _loading = true;
  bool _hasClient = false;
  bool _connected = false;
  bool _busy = false;
  String? _lastSync;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final oauth = ref.read(googleOAuthProvider);
    final hasClient = await oauth.hasClient;
    final connected = await oauth.isConnected;
    final last = await ref.read(databaseProvider).getSetting(ContactsSync.lastSyncKey);
    if (!mounted) return;
    setState(() {
      _hasClient = hasClient;
      _connected = connected;
      _lastSync = last == null || last.isEmpty ? null : last;
      _loading = false;
    });
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _refresh();
  }

  Future<void> _chooseClientFile() => _run(() async {
        final file = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'Google client file', extensions: ['json'])]);
        if (file == null) return;
        await ref.read(googleOAuthProvider).saveClientFile(await file.readAsString());
      });

  Future<void> _connect() => _run(() async {
        await ref.read(googleOAuthProvider).connect();
        final sync = await ref.read(contactsSyncProvider.future);
        await sync.syncNow();
        sync.start();
      });

  Future<void> _syncNow() => _run(() async => (await ref.read(contactsSyncProvider.future)).syncNow());

  Future<void> _disconnect() => _run(() async => (await ref.read(contactsSyncProvider.future)).disconnect());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_loading) return const SizedBox.shrink();
    final last = _lastSync == null ? null : DateTime.tryParse(_lastSync!);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            "Shows the photo from each person's Google contact card. People in your contacts also stay in Chats. Précis reads names, addresses and photos only, on this computer, and never changes your contacts.",
            style: theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        GroupedList(
          children: [
            if (!_connected)
              ListTile(
                key: const ValueKey('contacts-client'),
                leading: const Icon(Icons.description_outlined),
                title: Text(_hasClient ? 'OAuth client file chosen' : 'Step 1: choose your OAuth client file'),
                subtitle: const Text('From your own Google Cloud project. Steps are in docs/google-contacts-setup.md.'),
                trailing: TextButton(onPressed: _busy ? null : _chooseClientFile, child: Text(_hasClient ? 'Change' : 'Choose file')),
              ),
            if (!_connected)
              ListTile(
                key: const ValueKey('contacts-connect'),
                leading: const Icon(Icons.login_rounded),
                title: const Text('Step 2: connect'),
                subtitle: const Text('Opens your browser to sign in to Google. Google will warn that the app is unverified, because it is your own.'),
                trailing: FilledButton(onPressed: _busy || !_hasClient ? null : _connect, child: const Text('Connect')),
              ),
            if (_connected)
              ListTile(
                key: const ValueKey('contacts-status'),
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('Connected'),
                subtitle: Text(last == null ? 'Not synced yet' : 'Last synced ${last.toLocal()}'.split('.').first),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(onPressed: _busy ? null : _syncNow, child: const Text('Sync now')),
                    TextButton(key: const ValueKey('contacts-disconnect'), onPressed: _busy ? null : _disconnect, child: const Text('Disconnect')),
                  ],
                ),
              ),
          ],
        ),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, key: const ValueKey('contacts-error'), style: theme.textTheme.bodyMedium!.copyWith(color: scheme.error)),
          ),
      ],
    );
  }
}
