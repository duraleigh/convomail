import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/board_queries.dart';
import '../../../store/database.dart';
import '../../theme/tokens.dart';

final tagsProvider = StreamProvider<List<Tag>>((ref) => ref.watch(databaseProvider).watchTags());

/// Checkbox tree of tags with inline creation (spec 4.8: unlimited
/// sub-tags). Returns the selected ids, or null when cancelled.
Future<Set<int>?> showTagPicker(BuildContext context, {required Set<int> selected, String title = 'Tags'}) {
  return showDialog<Set<int>>(context: context, builder: (_) => _TagPickerDialog(selected: selected, title: title));
}

class _TagPickerDialog extends ConsumerStatefulWidget {
  const _TagPickerDialog({required this.selected, required this.title});
  final Set<int> selected;
  final String title;

  @override
  ConsumerState<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends ConsumerState<_TagPickerDialog> {
  late final Set<int> _selected = {...widget.selected};
  final _newName = TextEditingController();
  int? _newParent;

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final tree = BoardQueries.buildTagTree(tags);

    List<Widget> rows(List<TagNode> nodes, int depth) => [
          for (final n in nodes) ...[
            CheckboxListTile(
              key: ValueKey('tag-check-${n.tag.id}'),
              dense: true,
              contentPadding: EdgeInsets.only(left: 8.0 + depth * 20),
              controlAffinity: ListTileControlAffinity.leading,
              value: _selected.contains(n.tag.id),
              onChanged: (v) => setState(() => v == true ? _selected.add(n.tag.id) : _selected.remove(n.tag.id)),
              title: Text(n.name),
            ),
            ...rows(n.children, depth + 1),
          ],
        ];

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            Expanded(
              child: tags.isEmpty
                  ? Center(child: Text('No tags yet. Create one below.', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)))
                  : ListView(children: rows(tree, 0)),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('new-tag-name'),
                    controller: _newName,
                    decoration: const InputDecoration(hintText: 'New tag', isDense: true, border: OutlineInputBorder()),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int?>(
                  value: _newParent,
                  hint: const Text('Top level'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Top level')),
                    for (final t in tags) DropdownMenuItem<int?>(value: t.id, child: Text('under ${BoardQueries.tagPath(tags, t)}')),
                  ],
                  onChanged: (v) => setState(() => _newParent = v),
                ),
                IconButton(key: const ValueKey('new-tag-add'), tooltip: 'Add tag', onPressed: _create, icon: const Icon(Icons.add_rounded)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('tags-done'), onPressed: () => Navigator.pop(context, _selected), child: const Text('Done')),
      ],
    );
  }

  Future<void> _create() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    final id = await ref.read(databaseProvider).createTag(name, parentId: _newParent);
    if (!mounted) return;
    setState(() {
      _selected.add(id);
      _newName.clear();
    });
  }
}

/// Small tag chip used on cards and in Settings.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.color});
  final String label;
  final int? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color == null ? scheme.secondaryContainer : Color(color!).withValues(alpha: 0.18);
    final fg = color == null ? scheme.onSecondaryContainer : Color(color!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppShapes.full)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: fg, letterSpacing: 0)),
    );
  }
}
