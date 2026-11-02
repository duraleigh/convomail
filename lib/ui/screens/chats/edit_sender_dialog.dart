import 'package:flutter/material.dart';

/// Asks for the user's own name and optional subtitle for a sender (spec
/// 4.2). A blank name goes back to the name in the mail headers; a blank
/// subtitle shows none. Returns null when cancelled.
Future<({String name, String subtitle})?> showEditSenderDialog(
  BuildContext context, {
  required String name,
  required String subtitle,
  required List<String> addresses,
  Future<void> Function(String address)? onSeparate,
}) =>
    showDialog<({String name, String subtitle})>(context: context, builder: (_) => _EditSenderDialog(name: name, subtitle: subtitle, addresses: addresses, onSeparate: onSeparate));

class _EditSenderDialog extends StatefulWidget {
  const _EditSenderDialog({required this.name, required this.subtitle, required this.addresses, this.onSeparate});
  final String name;
  final String subtitle;

  /// The person's addresses, the contact's own first.
  final List<String> addresses;
  final Future<void> Function(String address)? onSeparate;

  @override
  State<_EditSenderDialog> createState() => _EditSenderDialogState();
}

class _EditSenderDialogState extends State<_EditSenderDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.name)..selection = TextSelection(baseOffset: 0, extentOffset: widget.name.length);
  late final TextEditingController _subtitle = TextEditingController(text: widget.subtitle);
  late final List<String> _addresses = [...widget.addresses];

  Future<void> _separate(String address) async {
    await widget.onSeparate?.call(address);
    if (mounted) setState(() => _addresses.remove(address));
  }

  @override
  void dispose() {
    _name.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, (name: _name.text.trim(), subtitle: _subtitle.text.trim()));

  void _useOriginalName() => Navigator.pop(context, (name: '', subtitle: _subtitle.text.trim()));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('rename-dialog'),
      title: const Text('Edit sender'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('rename-field'),
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name in your chat list'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('subtitle-field'),
              controller: _subtitle,
              decoration: const InputDecoration(labelText: 'Subtitle (optional)', hintText: 'For example: Talent agent'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            Text(
              'Applies to all future mail from this sender, even if you delete the conversation.',
              style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            for (final (i, address) in _addresses.indexed)
              Row(
                children: [
                  Expanded(child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
                  // The first address names the contact, so it stays.
                  if (i > 0 && widget.onSeparate != null)
                    TextButton(key: ValueKey('separate-$address'), onPressed: () => _separate(address), child: const Text('Separate')),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const ValueKey('rename-reset'), onPressed: _useOriginalName, child: const Text('Use original name')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('rename-save'), onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
