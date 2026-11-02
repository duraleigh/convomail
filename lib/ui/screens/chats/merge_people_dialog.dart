import 'package:flutter/material.dart';

/// One person offered for merging.
class MergeCandidate {
  const MergeCandidate({required this.contactKey, required this.name, required this.addresses});
  final String contactKey;
  final String name;
  final List<String> addresses;
}

/// Confirms a merge and asks which name to keep. Returns the contact key of
/// the person to keep, or null when cancelled.
Future<String?> showMergePeopleDialog(BuildContext context, List<MergeCandidate> people) =>
    showDialog<String>(context: context, builder: (_) => _MergePeopleDialog(people: people));

class _MergePeopleDialog extends StatefulWidget {
  const _MergePeopleDialog({required this.people});
  final List<MergeCandidate> people;

  @override
  State<_MergePeopleDialog> createState() => _MergePeopleDialogState();
}

class _MergePeopleDialogState extends State<_MergePeopleDialog> {
  late String _keep = widget.people.first.contactKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('merge-dialog'),
      title: Text('Merge ${widget.people.length} people into one'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('All their mail becomes one conversation, including future mail from any of these addresses. Pick the name to keep.', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _keep,
                onChanged: (v) => setState(() => _keep = v ?? _keep),
                child: Column(
                  children: [
                    for (final p in widget.people)
                      RadioListTile<String>(
                        key: ValueKey('merge-keep-${p.contactKey}'),
                        contentPadding: EdgeInsets.zero,
                        value: p.contactKey,
                        title: Text(p.name),
                        subtitle: Text(p.addresses.join('\n'), style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('merge-confirm'), onPressed: () => Navigator.pop(context, _keep), child: const Text('Merge')),
      ],
    );
  }
}

/// Picks one person to merge with, by name or address. Returns null when
/// cancelled.
Future<MergeCandidate?> showMergePickerDialog(BuildContext context, {required String forName, required List<MergeCandidate> people}) =>
    showDialog<MergeCandidate>(context: context, builder: (_) => _MergePickerDialog(forName: forName, people: people));

class _MergePickerDialog extends StatefulWidget {
  const _MergePickerDialog({required this.forName, required this.people});
  final String forName;
  final List<MergeCandidate> people;

  @override
  State<_MergePickerDialog> createState() => _MergePickerDialogState();
}

class _MergePickerDialogState extends State<_MergePickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final matches = widget.people.where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.addresses.any((a) => a.contains(q))).take(50).toList();
    return AlertDialog(
      key: const ValueKey('merge-picker'),
      title: Text('Merge ${widget.forName} with…'),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('merge-picker-search'),
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Name or address'),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? Center(child: Text('Nobody matches', style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final p = matches[i];
                        return ListTile(
                          key: ValueKey('merge-pick-${p.contactKey}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(p.addresses.first, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
