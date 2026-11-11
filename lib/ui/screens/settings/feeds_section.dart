import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/settings.dart';
import '../../../domain/classifier.dart';
import '../../../domain/piles.dart';
import '../../../store/classification_queries.dart';
import '../../../store/database.dart' hide ClassificationRule;
import '../../../sync/classification_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/tonal_avatar.dart';

final feedsCategoriesProvider = StreamProvider<List<FeedsCategoryRow>>((ref) => ref.watch(databaseProvider).watchCategories());
final classificationRulesProvider = StreamProvider<List<ClassificationRule>>((ref) => ref.watch(databaseProvider).watchRules());
final overriddenSendersProvider = StreamProvider<List<Contact>>((ref) => ref.watch(databaseProvider).watchMovedSenders());
final countingSendersProvider = StreamProvider<List<Contact>>((ref) => ref.watch(databaseProvider).watchCountingSenders());

/// Settings → Feeds (spec 4.18): badge scope, senders that count toward
/// unread, the category list, accepted rules, and manual moves.
class FeedsDetail extends ConsumerWidget {
  const FeedsDetail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    final categories = ref.watch(feedsCategoriesProvider).value ?? const <FeedsCategoryRow>[];
    final rules = ref.watch(classificationRulesProvider).value ?? const <ClassificationRule>[];
    final overrides = ref.watch(overriddenSendersProvider).value ?? const <Contact>[];
    final counting = ref.watch(countingSendersProvider).value ?? const <Contact>[];
    final service = ref.read(classificationServiceProvider);
    final db = ref.read(databaseProvider);

    Widget label(String s) => Padding(padding: const EdgeInsets.fromLTRB(0, AppSpace.xl, 0, AppSpace.sm), child: Text(s, style: text.labelSmall!.copyWith(letterSpacing: 1)));

    return ListView(
      children: [
        GroupedList(
          children: [
            SwitchListTile(
              key: const ValueKey('feeds-badge-scope'),
              secondary: Icon(Icons.notifications_outlined, color: scheme.primary),
              title: const Text('Feed and Noise count toward the unread badge'),
              subtitle: const Text('Off: only Chats (and senders marked below) count.'),
              value: settings.badgeIncludeFeeds,
              onChanged: (v) => ref.read(settingsProvider.notifier).setBadgeIncludeFeeds(v),
            ),
          ],
        ),
        label('COUNTS TOWARD UNREAD · ${counting.length}'),
        if (counting.isEmpty)
          Text('No sender is marked yet. Use "Counts toward unread" on a row in Feed or Noise.', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant))
        else
          GroupedList(
            children: [
              for (final c in counting)
                ListTile(
                  leading: TonalAvatar(identityKey: c.key, name: c.shownName, size: 36),
                  title: Text(c.shownName),
                  subtitle: Text(c.key),
                  trailing: IconButton(tooltip: 'Stop counting', icon: const Icon(Icons.notifications_off_outlined), onPressed: () => service.setCountsTowardUnread(c.key, false)),
                ),
            ],
          ),
        label('CATEGORIES · ${categories.length}'),
        GroupedList(
          children: [
            for (final c in categories)
              ListTile(
                key: ValueKey('category-${c.id}'),
                leading: Icon(_iconFor(c.name), color: scheme.primary),
                title: Text(c.name),
                subtitle: c.builtin ? const Text('Default') : const Text('Custom'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(tooltip: 'Rename', icon: const Icon(Icons.edit_outlined), onPressed: () => _rename(context, db, c)),
                    IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _deleteCategory(context, db, c)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const ValueKey('add-category'),
            onPressed: () => _addCategory(context, db),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add category'),
          ),
        ),
        label('CLASSIFICATION RULES · ${rules.length}'),
        if (rules.isEmpty)
          Text('Rules appear here when you accept one from a correction. Précis never writes a rule on its own.', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant))
        else
          GroupedList(
            children: [
              for (final r in rules)
                ListTile(
                  key: ValueKey('rule-${r.id}'),
                  leading: Icon(Icons.rule_rounded, color: scheme.primary),
                  title: Text(r.describe()),
                  trailing: IconButton(tooltip: 'Delete rule', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => service.deleteRule(r.id!)),
                ),
            ],
          ),
        label('MOVED BY YOU · ${overrides.length}'),
        if (overrides.isEmpty)
          Text('Senders you move between Chats, Feed and Noise are listed here. The app never moves them back.', style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant))
        else
          GroupedList(
            children: [
              for (final c in overrides)
                ListTile(
                  key: ValueKey('override-${c.key}'),
                  leading: TonalAvatar(identityKey: c.key, name: c.shownName, size: 36),
                  title: Text(c.shownName),
                  subtitle: Text('${c.key} · in ${_placeOf(c)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        key: ValueKey('override-move-${c.key}'),
                        tooltip: 'Move',
                        icon: const Icon(Icons.drive_file_move_outline),
                        onSelected: (v) async {
                          if (v == 'Chats') {
                            await service.moveSender(c.key, Bucket.people);
                          } else {
                            if (c.classification != 'feeds') await service.moveSender(c.key, Bucket.feeds);
                            await db.setSenderPile(c.key, v == 'Noise' ? FeedsPile.noise : FeedsPile.feed);
                          }
                        },
                        itemBuilder: (_) => [
                          for (final place in const ['Chats', 'Feed', 'Noise'])
                            if (place != _placeOf(c)) PopupMenuItem(value: place, child: Text('Move to $place')),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Let the app decide again',
                        icon: const Icon(Icons.undo_rounded),
                        onPressed: () async {
                          await db.setSenderPile(c.key, null);
                          await service.moveSender(c.key, null);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSpace.xl),
      ],
    );
  }

  /// Where a sender the user placed by hand is now.
  static String _placeOf(Contact c) => c.classification != 'feeds' ? 'Chats' : (c.feedsPile == 'noise' ? 'Noise' : (c.feedsPile == 'feed' ? 'Feed' : 'Feed or Noise'));

  static IconData _iconFor(String name) => switch (name) {
        'Newsletter' => Icons.newspaper_outlined,
        'Receipt' => Icons.receipt_long_outlined,
        'Notification' => Icons.notifications_none_rounded,
        'Updates' => Icons.update_rounded,
        'Social' => Icons.people_outline_rounded,
        'Promotion' => Icons.local_offer_outlined,
        _ => Icons.label_outline_rounded,
      };

  Future<void> _addCategory(BuildContext context, AppDatabase db) async {
    final name = await _prompt(context, title: 'New category', hint: 'e.g. OTP, Shipping');
    if (name != null && name.trim().isNotEmpty) await db.addCategory(name);
  }

  Future<void> _rename(BuildContext context, AppDatabase db, FeedsCategoryRow c) async {
    final name = await _prompt(context, title: 'Rename ${c.name}', initial: c.name);
    if (name != null) await db.renameCategory(c.id, name);
  }

  Future<void> _deleteCategory(BuildContext context, AppDatabase db, FeedsCategoryRow c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${c.name}?'),
        content: const Text('Senders and messages tagged with it lose the tag; rules that set it keep the part that says where the mail goes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await db.deleteCategory(c.id);
  }

  Future<String?> _prompt(BuildContext context, {required String title, String? hint, String? initial}) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const ValueKey('category-name'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint, isDense: true, border: const OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('category-save'), onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
  }
}
