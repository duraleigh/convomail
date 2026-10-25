import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/destinations.dart';
import '../../../app/people_state.dart';
import '../../../store/compose_queries.dart';
import '../../../store/database.dart';
import '../../../store/group_queries.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/tonal_avatar.dart';

final groupsProvider = StreamProvider<List<GroupInfo>>((ref) => ref.watch(databaseProvider).watchGroups());

/// Settings → People Groups (spec 4.18, 4.19): the groups the user created,
/// an in-place editor for name and members, and the exact-match rule in
/// plain words. Nothing here is ever suggested or created automatically.
class PeopleGroupsDetail extends ConsumerStatefulWidget {
  const PeopleGroupsDetail({super.key});

  @override
  ConsumerState<PeopleGroupsDetail> createState() => _PeopleGroupsDetailState();
}

class _PeopleGroupsDetailState extends ConsumerState<PeopleGroupsDetail> {
  /// null = list; -1 = creating; otherwise the id being edited.
  int? _editing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final groups = ref.watch(groupsProvider);

    if (_editing != null) {
      final existing = _editing == -1 ? null : (groups.value ?? const <GroupInfo>[]).where((g) => g.id == _editing).firstOrNull;
      return _GroupEditor(
        key: ValueKey('group-editor-$_editing'),
        existing: existing,
        onDone: () => setState(() => _editing = null),
      );
    }

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(AppShapes.lg)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How groups work', style: text.titleSmall),
              const SizedBox(height: 4),
              Text(
                'A group gets its own row in Chats. A message lands there only when the sender plus everyone on To and CC, apart from you, '
                'is exactly the group. Anyone missing or anyone extra, and the message files under its sender as usual. '
                'Groups are never created for you.',
                style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        groups.when(
          loading: () => const SizedBox(height: 48),
          error: (e, _) => Text('$e', style: text.bodyMedium!.copyWith(color: scheme.error)),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(icon: Icons.group_outlined, title: 'No groups yet', message: 'Create one for the people you regularly email together.'),
                )
              : GroupedList(
                  children: [
                    for (final g in list)
                      ListTile(
                        key: ValueKey('group-${g.id}'),
                        leading: StackedAvatars(members: g.members, size: 40),
                        title: Text(g.name),
                        subtitle: Text(
                          '${g.members.map((m) => m.$2).join(', ')} · ${g.filedCount} conversation${g.filedCount == 1 ? '' : 's'} filed',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Show in Chats',
                              onPressed: g.filedCount == 0
                                  ? null
                                  : () {
                                      ref.read(selectedRowProvider.notifier).select(g.rowKey);
                                      ref.read(destinationProvider.notifier).select(Destination.chats);
                                    },
                              icon: const Icon(Icons.forum_outlined),
                            ),
                            IconButton(tooltip: 'Edit', onPressed: () => setState(() => _editing = g.id), icon: const Icon(Icons.edit_outlined)),
                            IconButton(tooltip: 'Delete', onPressed: () => _confirmDelete(g), icon: const Icon(Icons.delete_outline_rounded)),
                          ],
                        ),
                        onTap: () => setState(() => _editing = g.id),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const ValueKey('new-group'),
            onPressed: () => setState(() => _editing = -1),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('New group'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(GroupInfo g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${g.name}?'),
        content: Text('Its ${g.filedCount} conversation${g.filedCount == 1 ? '' : 's'} go back under each sender. No mail is deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.read(databaseProvider).deleteGroup(g.id);
  }
}

/// Name field plus a member picker with autocomplete from known contacts.
class _GroupEditor extends ConsumerStatefulWidget {
  const _GroupEditor({super.key, required this.existing, required this.onDone});
  final GroupInfo? existing;
  final VoidCallback onDone;

  @override
  ConsumerState<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends ConsumerState<_GroupEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  final _picker = TextEditingController();
  final _pickerFocus = FocusNode(debugLabel: 'group-member-picker');
  late final List<(String, String)> _members = [...?widget.existing?.members];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _picker.dispose();
    _pickerFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final db = ref.read(databaseProvider);
    try {
      final keys = _members.map((m) => m.$1);
      if (widget.existing == null) {
        await db.createGroup(_name.text, keys);
      } else {
        await db.renameGroup(widget.existing!.id, _name.text);
        await db.setGroupMembers(widget.existing!.id, keys);
      }
      if (mounted) widget.onDone();
    } on GroupValidationException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final db = ref.watch(databaseProvider);
    return ListView(
      children: [
        Text(widget.existing == null ? 'New group' : 'Edit group', style: text.titleMedium),
        const SizedBox(height: AppSpace.md),
        TextField(
          key: const ValueKey('group-name'),
          controller: _name,
          autofocus: widget.existing == null,
          decoration: const InputDecoration(labelText: 'Group name', hintText: 'e.g. Simon & Joann', border: OutlineInputBorder(), isDense: true),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _pickerFocus.requestFocus(),
        ),
        const SizedBox(height: AppSpace.lg),
        Text('Members', style: text.labelLarge),
        const SizedBox(height: 4),
        Text('At least two people. You are part of every group, so you are not listed.', style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _members)
              InputChip(
                key: ValueKey('member-${m.$1}'),
                avatar: TonalAvatar(identityKey: m.$1, name: m.$2, size: 24),
                label: Text(m.$2),
                tooltip: m.$1,
                onDeleted: () => setState(() => _members.remove(m)),
                shape: const StadiumBorder(),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        RawAutocomplete<RecipientSuggestion>(
          textEditingController: _picker,
          focusNode: _pickerFocus,
          displayStringForOption: (o) => o.name.isEmpty ? o.address : o.name,
          optionsBuilder: (v) async {
            if (v.text.trim().isEmpty) return const Iterable<RecipientSuggestion>.empty();
            final found = await db.searchRecipients(v.text, limit: 12);
            final seen = <String>{for (final m in _members) m.$1};
            final out = <RecipientSuggestion>[];
            for (final s in found) {
              if (seen.add(s.contactKey)) out.add(s);
            }
            return out;
          },
          onSelected: (s) {
            setState(() => _members.add((s.contactKey, s.name.isEmpty ? s.address : s.name)));
            _picker.clear();
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
            key: const ValueKey('group-member-picker'),
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.person_add_alt_outlined), hintText: 'Add a person by name or address', border: OutlineInputBorder(), isDense: true),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 3,
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppShapes.md),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 420,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final o in options)
                      ListTile(
                        dense: true,
                        leading: TonalAvatar(identityKey: o.contactKey, name: o.name.isEmpty ? o.address : o.name, size: 32),
                        title: Text(o.name.isEmpty ? o.address : o.name),
                        subtitle: o.name.isEmpty ? null : Text(o.address),
                        onTap: () => onSelected(o),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(_error!, style: text.bodyMedium!.copyWith(color: scheme.error)),
        ],
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            FilledButton(key: const ValueKey('group-save'), onPressed: _saving ? null : _save, child: Text(widget.existing == null ? 'Create group' : 'Save')),
            const SizedBox(width: 8),
            TextButton(onPressed: _saving ? null : widget.onDone, child: const Text('Cancel')),
            if (_saving) ...[const SizedBox(width: 16), const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))],
          ],
        ),
      ],
    );
  }
}
