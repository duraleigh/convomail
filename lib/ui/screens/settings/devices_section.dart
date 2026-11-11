import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../helper/device_join.dart';
import '../../../helper/helper_client.dart';
import '../../../helper/helper_sync.dart';
import '../../../platform/phone_alerts.dart';
import '../../widgets/grouped_list.dart';

/// The helper's address offered when nothing is typed yet.
const defaultHelperAddress = 'precis.clayaiken.com';

/// Settings → Your devices: joining the helper, how it is doing, and every
/// PC and phone that follows it.
class DevicesDetail extends ConsumerStatefulWidget {
  const DevicesDetail({super.key});

  @override
  ConsumerState<DevicesDetail> createState() => _DevicesDetailState();
}

class _DevicesDetailState extends ConsumerState<DevicesDetail> {
  final _address = TextEditingController(text: defaultHelperAddress);
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _newCode;
  Timer? _tick;

  /// This device joined by code: it has no mail of its own without the helper.
  bool _joined = false;

  /// "PC" or "phone", for the words on this page.
  static final _device = Platform.isAndroid ? 'phone' : 'PC';

  @override
  void initState() {
    super.initState();
    unawaited(_open());
    // The page stays current while it is open.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && ref.read(helperProvider).connected) unawaited(ref.read(helperProvider.notifier).refreshStatus());
    });
  }

  Future<void> _open() async {
    final joined = await ref.read(deviceJoinProvider).joined;
    if (mounted && joined != _joined) setState(() => _joined = joined);
    final helper = ref.read(helperProvider.notifier);
    if (!ref.read(helperProvider).loaded) await helper.load();
    if (ref.read(helperProvider).connected) await helper.refreshStatus();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } on HelperException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _join() => _run(() async {
        await ref.read(helperProvider.notifier).connect(_address.text, _code.text);
        _code.clear();
        await ref.read(helperProvider.notifier).refreshStatus();
      });

  /// Signs a joined device out: the helper stops handing it anything, and
  /// Précis removes its copy of the mail from this device.
  Future<void> _signOutHere() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign this $_device out?'),
        content: Text('Précis removes its copy of your mail from this $_device, and the helper stops handing it anything. Your mail itself and your other devices are not changed. You can join again with a new code.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('devices-signout-here-confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(helperProvider.notifier).disconnect();
      await ref.read(phoneAlertsProvider).forget();
      await ref.read(deviceJoinProvider).wipe();
    });
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop following the helper?'),
        content: const Text('This PC keeps all its mail and goes back to sorting by itself. Your other devices are not changed. You can join again with a new code.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('devices-leave-confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Stop following')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => ref.read(helperProvider.notifier).disconnect());
    if (mounted) setState(() => _newCode = null);
  }

  static String _ago(int? secs, int now) {
    if (secs == null || secs <= 0) return 'never';
    final d = now - secs;
    if (d < 90) return 'just now';
    if (d < 5400) return '${(d / 60).round()} minutes ago';
    if (d < 129600) return '${(d / 3600).round()} hours ago';
    return '${(d / 86400).round()} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final link = ref.watch(helperProvider);
    if (!link.loaded) return const SizedBox.shrink();
    final error = _error ?? link.error;

    Widget heading(String s) => Padding(padding: const EdgeInsets.fromLTRB(0, 24, 0, 8), child: Text(s, style: text.labelSmall!.copyWith(letterSpacing: 1)));

    if (!link.connected) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'The helper is a small program on your own web hosting. It reads your mail around the clock, sorts it, and keeps every PC and phone in step. This PC does not follow one yet.',
              style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          GroupedList(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const ValueKey('devices-address'),
                      controller: _address,
                      enabled: !_busy,
                      decoration: const InputDecoration(labelText: 'The helper’s address', hintText: defaultHelperAddress),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('devices-code'),
                      controller: _code,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 -]')), LengthLimitingTextInputFormatter(12)],
                      decoration: const InputDecoration(labelText: 'Joining code', helperText: 'On the helper’s own page: Your devices, Add a device. A code lasts 10 minutes and works once.'),
                      onSubmitted: (_) => _join(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(key: const ValueKey('devices-join'), onPressed: _busy ? null : _join, child: const Text('Join')),
                  ],
                ),
              ),
            ],
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error, key: const ValueKey('devices-error'), style: text.bodyMedium!.copyWith(color: scheme.error))),
          heading('WHAT JOINING DOES'),
          Text(
            'This PC sends the helper what it knows: who is a person and who is not, your tags and rules, what you marked done or put off. It does not send your mail; the helper reads that from Google itself. From then on the helper decides where new mail goes, and this PC follows. If the helper cannot be reached, Précis carries on by itself.',
            style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    final status = link.status;
    final now = (status?['now'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final accounts = [for (final a in (status?['accounts'] as List?) ?? const []) (a as Map).cast<String, Object?>()];
    final timer = (status?['timer'] as num?)?.toInt() ?? 0;
    final host = Uri.tryParse(link.address!)?.host ?? link.address!;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('The helper reads your mail around the clock, sorts it, and keeps every PC and phone in step.', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
        ),
        GroupedList(
          children: [
            ListTile(
              key: const ValueKey('devices-status'),
              leading: Icon(error == null ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, color: error == null ? null : scheme.error),
              title: Text('Following $host'),
              subtitle: Text(error ?? (link.inStepAt == null ? 'Getting in step…' : 'In step. This PC is “${link.deviceName}”.')),
              trailing: TextButton(key: const ValueKey('devices-sync-now'), onPressed: _busy ? null : () => _run(() async {
                    await ref.read(helperProvider.notifier).syncNow();
                    await ref.read(helperProvider.notifier).refreshStatus();
                  }), child: const Text('Check now')),
            ),
            if (!link.sentUp)
              ListTile(
                key: const ValueKey('devices-sending'),
                leading: const Icon(Icons.upload_rounded),
                title: const Text('Sending up what this PC knows'),
                subtitle: Text(link.sendingTotal == 0 ? 'Starting…' : '${link.sendingDone} of ${link.sendingTotal} senders'),
              ),
          ],
        ),
        if (_busy || (link.busy && !link.sentUp)) Padding(padding: const EdgeInsets.only(top: 12), child: LinearProgressIndicator(value: !link.sentUp && link.sendingTotal > 0 ? link.sendingDone / link.sendingTotal : null)),
        heading('THE HELPER'),
        GroupedList(
          children: [
            if (status == null)
              const ListTile(leading: Icon(Icons.hourglass_empty_rounded), title: Text('Asking the helper how it is doing…'))
            else ...[
              if (accounts.isEmpty)
                const ListTile(
                  key: ValueKey('devices-no-mailbox'),
                  leading: Icon(Icons.link_off_rounded),
                  title: Text('No mailbox is connected to the helper yet'),
                  subtitle: Text('Open the helper’s own page in your browser and press Connect Google.'),
                ),
              for (final a in accounts)
                ListTile(
                  key: ValueKey('devices-mailbox-${a['email']}'),
                  leading: Icon(a['error'] == null ? Icons.mark_email_read_outlined : Icons.error_outline_rounded, color: a['error'] == null ? null : scheme.error),
                  title: Text('${a['email']}'),
                  subtitle: Text([
                    if (a['error'] != null) '${a['error']}' else 'Last looked ${_ago((a['lastChecked'] as num?)?.toInt(), now)}',
                    a['firstReadDone'] == true ? 'First read of 30 days finished' : 'First read of 30 days: ${a['firstRead']} emails so far',
                    a['notice'] == true ? 'Google tells it about new mail at once' : 'It looks every minute',
                  ].join(' · ')),
                ),
              ListTile(
                key: const ValueKey('devices-timer'),
                leading: Icon(timer > 0 && now - timer < 300 ? Icons.timer_outlined : Icons.timer_off_outlined, color: timer > 0 && now - timer < 300 ? null : scheme.error),
                title: Text(timer > 0 && now - timer < 300 ? 'Its every-minute timer is running' : 'Its every-minute timer is not running'),
                subtitle: Text('Last ran ${_ago(timer, now)}'),
              ),
            ],
          ],
        ),
        heading('DEVICES · ${link.devices.length}'),
        GroupedList(
          children: [
            for (final d in link.devices)
              ListTile(
                key: ValueKey('devices-row-${d['id']}'),
                leading: Icon(d['kind'] == 'android' ? Icons.smartphone_rounded : Icons.computer_rounded),
                title: Text('${d['name']}${(d['id'] as num?)?.toInt() == link.deviceId ? ' (this $_device)' : ''}'),
                subtitle: Text('Last seen ${_ago((d['last_seen'] as num?)?.toInt(), now)}'),
                trailing: (d['id'] as num?)?.toInt() == link.deviceId
                    ? null
                    : TextButton(
                        key: ValueKey('devices-signout-${d['id']}'),
                        onPressed: _busy ? null : () => _run(() => ref.read(helperProvider.notifier).signOutDevice((d['id'] as num).toInt())),
                        child: const Text('Sign out'),
                      ),
              ),
            ListTile(
              key: const ValueKey('devices-add'),
              leading: const Icon(Icons.add_rounded),
              title: const Text('Add a device'),
              subtitle: _newCode == null
                  ? const Text('Makes a code to type into Précis on the other PC or phone.')
                  : Text.rich(TextSpan(children: [
                      const TextSpan(text: 'Code: '),
                      TextSpan(text: _newCode, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 3, fontFeatures: [FontFeature.tabularFigures()])),
                      const TextSpan(text: '  · good for 10 minutes, works once'),
                    ])),
              trailing: TextButton(
                key: const ValueKey('devices-new-code'),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final code = await ref.read(helperProvider.notifier).newDeviceCode();
                          if (mounted) setState(() => _newCode = code);
                        }),
                child: Text(_newCode == null ? 'Make a code' : 'New code'),
              ),
            ),
          ],
        ),
        heading('THIS ${_device.toUpperCase()}'),
        GroupedList(
          children: [
            if (_joined)
              ListTile(
                key: const ValueKey('devices-signout-here'),
                leading: const Icon(Icons.logout_rounded),
                title: Text('Sign this $_device out'),
                subtitle: Text('Removes Précis’s copy of your mail from this $_device. Other devices are not changed.'),
                trailing: TextButton(onPressed: _busy ? null : _signOutHere, child: const Text('Sign out')),
              )
            else
              ListTile(
                key: const ValueKey('devices-leave'),
                leading: const Icon(Icons.link_off_rounded),
                title: const Text('Stop following the helper'),
                subtitle: const Text('This PC keeps its mail and sorts by itself again. Other devices are not changed.'),
                trailing: TextButton(onPressed: _busy ? null : _leave, child: const Text('Stop')),
              ),
          ],
        ),
      ],
    );
  }
}
