import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/database.dart';
import '../../../store/people_queries.dart';
import '../../theme/tokens.dart';
import 'people_list_pane.dart';

/// "Delete all from this sender, but keep some" (spec 4.16). Lists the
/// row's messages with every one checked; the user unchecks what to keep.
/// Returns the ids to delete, or null if cancelled. Rendered as an in-window
/// dialog, not an OS window.
Future<List<int>?> showSelectiveKeepDialog(BuildContext context, PeopleRow row) {
  return showDialog<List<int>>(
    context: context,
    builder: (ctx) => _SelectiveKeepDialog(row: row),
  );
}

class _SelectiveKeepDialog extends ConsumerStatefulWidget {
  const _SelectiveKeepDialog({required this.row});
  final PeopleRow row;

  @override
  ConsumerState<_SelectiveKeepDialog> createState() => _SelectiveKeepDialogState();
}

class _SelectiveKeepDialogState extends ConsumerState<_SelectiveKeepDialog> {
  List<Message>? _messages;
  final Set<int> _delete = {};

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider).messagesForRow(widget.row.rowKey).then((m) {
      if (!mounted) return;
      setState(() {
        _messages = m;
        _delete.addAll(m.map((x) => x.id));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final msgs = _messages;
    final total = msgs?.length ?? 0;
    return AlertDialog(
      title: Text('Delete mail from ${widget.row.title}'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: msgs == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uncheck anything you want to keep. ${_delete.length} of $total will go to Trash.',
                    style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      TextButton(onPressed: () => setState(() => _delete.addAll(msgs.map((m) => m.id))), child: const Text('Select all')),
                      TextButton(onPressed: () => setState(_delete.clear), child: const Text('Keep all')),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: msgs.length,
                      itemBuilder: (context, i) {
                        final m = msgs[i];
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _delete.contains(m.id),
                          onChanged: (v) => setState(() => v == true ? _delete.add(m.id) : _delete.remove(m.id)),
                          title: Text(m.subject.isEmpty ? '(no subject)' : m.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${m.isFromMe ? 'You · ' : ''}${relativeTime(m.date ?? m.internalDate)}', style: text.bodySmall),
                          secondary: m.hasAttachments ? const Icon(Icons.attach_file_rounded, size: 18) : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _delete.isEmpty ? null : () => Navigator.pop(context, _delete.toList()),
          child: Text(_delete.length == total ? 'Delete all' : 'Delete ${_delete.length}'),
        ),
      ],
    );
  }
}
