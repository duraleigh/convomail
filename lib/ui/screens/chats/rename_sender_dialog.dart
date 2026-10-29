import 'package:flutter/material.dart';

/// Asks for the user's own name for a sender (spec 4.2). Returns the new
/// name, `''` to go back to the name in the mail headers, or null when
/// cancelled.
Future<String?> showRenameSenderDialog(BuildContext context, {required String current, required String address}) =>
    showDialog<String>(context: context, builder: (_) => _RenameSenderDialog(current: current, address: address));

class _RenameSenderDialog extends StatefulWidget {
  const _RenameSenderDialog({required this.current, required this.address});
  final String current;
  final String address;

  @override
  State<_RenameSenderDialog> createState() => _RenameSenderDialogState();
}

class _RenameSenderDialogState extends State<_RenameSenderDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.current)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.current.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('rename-dialog'),
      title: const Text('Rename sender'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('rename-field'),
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name in your chat list'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            Text(
              'Applies to ${widget.address} and to all future mail from this sender, even if you delete the conversation.',
              style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const ValueKey('rename-reset'), onPressed: () => Navigator.pop(context, ''), child: const Text('Use original name')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('rename-save'), onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
