import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/board_queries.dart';
import '../../../store/database.dart';
import '../../theme/tokens.dart';
import '../../widgets/grouped_list.dart';
import '../boards/tag_picker.dart';

/// Settings → Groups & Tags (spec 4.8, 4.18): the Kanban tag tree with
/// add / add sub-tag / rename / delete. Feeds categories live elsewhere.
class TagsDetail extends ConsumerWidget {
  const TagsDetail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final tree = BoardQueries.buildTagTree(tags);
    final db = ref.read(databaseProvider);

    List<Widget> rows(List<TagNode> nodes, int depth) => [
          for (final n in nodes) ...[
            ListTile(
              key: ValueKey('settings-tag-${n.tag.id}'),
              contentPadding: EdgeInsets.only(left: 16.0 + depth * 24, right: 8),
              leading: Icon(depth == 0 ? Icons.label_outline_rounded : Icons.subdirectory_arrow_right_rounded, color: scheme.primary),
              title: Text(n.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(tooltip: 'Add sub-tag', icon: const Icon(Icons.add_rounded), onPressed: () => _prompt(context, 'New sub-tag of ${n.name}', onSave: (v) => db.createTag(v, parentId: n.tag.id))),
                  IconButton(tooltip: 'Rename', icon: const Icon(Icons.edit_outlined), onPressed: () => _prompt(context, 'Rename ${n.name}', initial: n.name, onSave: (v) => db.renameTag(n.tag.id, v))),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Delete ${n.name}?'),
                          content: Text(n.children.isEmpty ? 'Cards keep their other tags.' : 'Its ${n.children.length} sub-tag${n.children.length == 1 ? '' : 's'} go too. Cards stay on the board.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
                        ),
                      );
                      if (ok == true) await db.deleteTag(n.tag.id);
                    },
                  ),
                ],
              ),
            ),
            ...rows(n.children, depth + 1),
          ],
        ];

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(AppShapes.lg)),
          child: Text(
            'Tags describe what you are doing with a conversation and organize the Boards view. They can nest without limit. Feeds categories (what a message is) are a separate list under Settings → Feeds.',
            style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        if (tags.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('No tags yet.', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)))
        else
          GroupedList(children: rows(tree, 0)),
        const SizedBox(height: AppSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const ValueKey('new-tag'),
            onPressed: () => _prompt(context, 'New tag', onSave: (v) => db.createTag(v)),
            icon: const Icon(Icons.new_label_outlined),
            label: const Text('New tag'),
          ),
        ),
      ],
    );
  }

  Future<void> _prompt(BuildContext context, String title, {String? initial, required Future<void> Function(String) onSave}) async {
    final controller = TextEditingController(text: initial ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(key: const ValueKey('tag-name'), controller: controller, autofocus: true, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), onSubmitted: (s) => Navigator.pop(ctx, s)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(key: const ValueKey('tag-save'), onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save'))],
      ),
    );
    if (v != null && v.trim().isNotEmpty) await onSave(v);
  }
}
