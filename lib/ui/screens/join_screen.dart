import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../helper/device_join.dart';
import '../../helper/helper_client.dart';
import '../theme/tokens.dart';
import 'settings/devices_section.dart' show defaultHelperAddress;

/// Joins this phone or PC to the helper with a code, with no Gmail
/// sign-in here: the helper already holds it, and hands this device what
/// it needs. Mail, sending addresses and signatures follow by themselves.
class JoinDeviceForm extends ConsumerStatefulWidget {
  const JoinDeviceForm({super.key, this.onCancel});

  /// Shown as "Back" when set (the PC's welcome screen has another way in).
  final VoidCallback? onCancel;

  @override
  ConsumerState<JoinDeviceForm> createState() => _JoinDeviceFormState();
}

class _JoinDeviceFormState extends ConsumerState<JoinDeviceForm> {
  final _address = TextEditingController(text: defaultHelperAddress);
  final _code = TextEditingController();
  final _name = TextEditingController(text: Platform.isAndroid ? 'My phone' : Platform.localHostname);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_code.text.trim().isEmpty) {
      setState(() => _error = 'Type the code first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(deviceJoinProvider).join(_address.text, _code.text, name: _name.text);
    } on HelperException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Joining did not work ($e).');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Join with a code', style: text.headlineSmall),
        const SizedBox(height: AppSpace.sm),
        Text(
          'On a PC that already runs Précis, open Settings, then Your devices, then Add a device, and press Make a code. Type that code here. There is no Gmail sign-in on this device: your mail, your sending addresses and your signatures arrive by themselves.',
          style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          key: const ValueKey('join-code'),
          controller: _code,
          autofocus: true,
          enabled: !_busy,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          style: text.headlineSmall!.copyWith(letterSpacing: 4),
          decoration: const InputDecoration(labelText: 'Joining code', helperText: 'A code lasts 10 minutes and works once.', border: OutlineInputBorder()),
          onSubmitted: (_) => _join(),
        ),
        const SizedBox(height: AppSpace.md),
        TextField(
          key: const ValueKey('join-name'),
          controller: _name,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'A name for this device', helperText: 'Shown in your list of devices, so you can sign it out if it is ever lost.', border: OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpace.md),
        TextField(
          key: const ValueKey('join-address'),
          controller: _address,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'The helper’s address', border: OutlineInputBorder()),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(_error!, key: const ValueKey('join-error'), style: text.bodyMedium!.copyWith(color: scheme.error)),
        ],
        const SizedBox(height: AppSpace.lg),
        Row(
          children: [
            FilledButton.icon(
              key: const ValueKey('join-go'),
              onPressed: _busy ? null : _join,
              icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link_rounded),
              label: Text(_busy ? 'Joining…' : 'Join'),
            ),
            if (widget.onCancel != null) ...[
              const SizedBox(width: AppSpace.md),
              TextButton(key: const ValueKey('join-back'), onPressed: _busy ? null : widget.onCancel, child: const Text('Back')),
            ],
          ],
        ),
      ],
    );
  }
}
