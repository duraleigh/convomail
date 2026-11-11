import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/account_scope.dart';
import '../../../app/compose_state.dart';
import '../../../app/destinations.dart';
import '../../../app/people_state.dart';
import '../../../app/search_state.dart';
import '../../../app/settings_navigation.dart';
import '../../../app/timely_state.dart';
import '../../../domain/classifier.dart';
import '../../../domain/filing.dart';
import '../../../domain/piles.dart';
import '../../../store/classification_queries.dart';
import '../../../store/database.dart';
import '../../../store/merge_queries.dart';
import '../../../store/people_queries.dart';
import '../../../store/planner_queries.dart';
import '../../../sync/classification_service.dart';
import '../../../sync/row_actions.dart';
import '../../theme/tokens.dart';
import '../../widgets/category_color.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/tonal_avatar.dart';
import 'edit_sender_dialog.dart';
import 'later_dialogs.dart';
import 'merge_people_dialog.dart';
import 'person_row.dart';
import 'search_results_view.dart';
import 'selective_keep_dialog.dart';

/// The middle pane of the Chats destination (spec 5.3): headline, search,
/// filter menu behind the tune icon, People/Feeds group, and the grouped People list with
/// hover actions, context menu, and keyboard navigation.
class PeopleListPane extends ConsumerStatefulWidget {
  const PeopleListPane({super.key});

  @override
  ConsumerState<PeopleListPane> createState() => _PeopleListPaneState();
}

class _PeopleListPaneState extends ConsumerState<PeopleListPane> {
  final _listFocus = FocusNode(debugLabel: 'people-list');
  bool _autoOpened = false;

  /// Picking rows one by one: from the third, offer to pick them all, once
  /// per selection.
  static const _offerSelectAllAt = 3;
  bool _offeredSelectAll = false;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _selectAllToast;

  void _onPickedChanged(Set<String>? prev, Set<String> next, InboxMode mode) {
    if (next.isEmpty) {
      _offeredSelectAll = false;
      _selectAllToast?.close();
      _selectAllToast = null;
      return;
    }
    final list = ref.read(peopleRowsProvider).value ?? const <PeopleRow>[];
    if (_offeredSelectAll || (prev?.length ?? 0) >= _offerSelectAllAt || next.length < _offerSelectAllAt || next.length >= list.length) return;
    _offeredSelectAll = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    _selectAllToast = messenger.showSnackBar(SnackBar(
      key: const ValueKey('select-all-toast'),
      content: Text(mode == InboxMode.people ? 'Select all ${list.length} chats?' : 'Select all ${list.length} in ${mode.label}?'),
      behavior: SnackBarBehavior.floating,
      width: 420,
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Select all',
        onPressed: () {
          final now = ref.read(peopleRowsProvider).value ?? list;
          ref.read(multiSelectProvider.notifier).setAll([for (final r in now) r.rowKey]);
        },
      ),
    ));
    _selectAllToast!.closed.then((_) => _selectAllToast = null);
  }

  static const _sortLabels = {
    PeopleSort.newest: 'Most recent first',
    PeopleSort.oldest: 'Oldest first',
    PeopleSort.nameAZ: 'Name A to Z',
    PeopleSort.nameZA: 'Name Z to A',
  };

  static const _filterLabels = {
    PeopleFilter.all: 'All',
    PeopleFilter.unread: 'Unread',
    PeopleFilter.starred: 'Starred',
    PeopleFilter.thisWeek: 'This Week',
    PeopleFilter.sent: 'Sent',
    PeopleFilter.hasAttachments: 'Has attachments',
    PeopleFilter.fromContacts: 'From contacts',
    PeopleFilter.snoozed: 'Later',
  };

  @override
  void dispose() {
    _listFocus.dispose();
    super.dispose();
  }

  void _moveSelection(List<PeopleRow> rows, int delta) {
    if (rows.isEmpty) return;
    final current = ref.read(selectedRowProvider);
    var i = rows.indexWhere((r) => r.rowKey == current);
    i = (i + delta).clamp(0, rows.length - 1);
    ref.read(selectedRowProvider.notifier).select(rows[i].rowKey);
  }

  /// Click: open the row, or toggle it while rows are picked. Ctrl-click
  /// toggles, Shift-click picks a range; the open row joins the selection
  /// when picking starts, as in Explorer.
  void _onRowTap(PeopleRow row, List<PeopleRow> list) {
    final multi = ref.read(multiSelectProvider.notifier);
    final picked = ref.read(multiSelectProvider);
    final keyboard = HardwareKeyboard.instance;
    final open = ref.read(selectedRowProvider);
    if (keyboard.isControlPressed || keyboard.isShiftPressed) {
      if (picked.isEmpty && open != null && open != row.rowKey && list.any((r) => r.rowKey == open)) multi.toggle(open);
      if (keyboard.isShiftPressed) {
        multi.extendTo(row.rowKey, [for (final r in list) r.rowKey]);
      } else {
        multi.toggle(row.rowKey);
      }
      _listFocus.requestFocus();
      return;
    }
    if (picked.isNotEmpty) {
      multi.toggle(row.rowKey);
      return;
    }
    ref.read(selectedRowProvider.notifier).select(row.rowKey);
    _listFocus.requestFocus();
  }

  Future<void> _bulk(BulkAction action, List<PeopleRow> list) async {
    final picked = ref.read(multiSelectProvider);
    final rows = [for (final r in list) if (picked.contains(r.rowKey)) r];
    if (rows.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(rowActionsProvider);
    ref.read(multiSelectProvider.notifier).clear();
    switch (action) {
      case BulkAction.moveToChats:
        await _moveRowsTo(rows, InboxMode.people);
      case BulkAction.moveToFeed:
        await _moveRowsTo(rows, InboxMode.feed);
      case BulkAction.moveToNoise:
        await _moveRowsTo(rows, InboxMode.noise);
      case BulkAction.merge:
        await _merge([for (final r in rows) if (r.ref case ContactRow(:final contactKey)) if (contactKey != 'me') (contactKey, r.title)]);
      case BulkAction.markRead:
        for (final r in rows) {
          await actions.markRowRead(r.rowKey);
        }
      case BulkAction.archive:
        final pending = <PendingAction>[];
        for (final r in rows) {
          final p = await actions.archiveRow(r.rowKey);
          if (p != null) pending.add(p);
        }
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text('Archived ${pending.length} conversation${pending.length == 1 ? '' : 's'}'),
          duration: actions.undoWindow,
          behavior: SnackBarBehavior.floating,
          width: 420,
          action: SnackBarAction(label: 'Undo', onPressed: () async {
            for (final p in pending) {
              await actions.undo(p);
            }
          }),
        ));
        if (rows.any((r) => r.rowKey == ref.read(selectedRowProvider))) ref.read(selectedRowProvider.notifier).select(null);
    }
  }

  /// Moves senders to Chats, Feed or Noise. The user's move stays until they
  /// change it: the app never moves a sender back on its own.
  Future<void> _moveRowsTo(List<PeopleRow> rows, InboxMode target) async {
    final service = ref.read(classificationServiceProvider);
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    // (sender, was not a person before, the pile chosen before)
    final moved = <(String, bool, FeedsPile?)>[];
    String? name;
    for (final r in rows) {
      if (r.ref case ContactRow(:final contactKey) when contactKey != 'me') {
        moved.add((contactKey, r.isFeeds, r.chosenPile));
        name ??= r.title;
        if (target == InboxMode.people) {
          await service.moveSender(contactKey, Bucket.people);
        } else {
          if (!r.isFeeds) await service.moveSender(contactKey, Bucket.feeds);
          await db.setSenderPile(contactKey, target == InboxMode.noise ? FeedsPile.noise : FeedsPile.feed);
        }
      }
    }
    if (moved.isEmpty || !mounted) return;
    final one = moved.length == 1;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('${one ? name : '${moved.length} senders'} moved to ${target.label}. ${one ? 'It stays' : 'They stay'} there until you change it.'),
      behavior: SnackBarBehavior.floating,
      width: 480,
      action: SnackBarAction(label: 'Undo', onPressed: () async {
        for (final (key, wasFeeds, pile) in moved) {
          if (wasFeeds != target.isFeeds) await service.moveSender(key, null);
          await db.setSenderPile(key, pile);
        }
      }),
    ));
    if (rows.any((r) => r.rowKey == ref.read(selectedRowProvider))) ref.read(selectedRowProvider.notifier).select(null);
  }

  /// Archives everything in Noise, after asking, with one Undo.
  Future<void> _archiveAllNoise(List<PeopleRow> rows) async {
    if (rows.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive everything in Noise?'),
        content: Text('Mail from ${rows.length} sender${rows.length == 1 ? '' : 's'} leaves Noise and goes to your archive. Nothing is deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('noise-archive-confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive all')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    ref.read(multiSelectProvider.notifier).setAll([for (final r in rows) r.rowKey]);
    await _bulk(BulkAction.archive, rows);
  }

  /// Asks which name to keep, merges, and offers one Undo.
  Future<void> _merge(List<(String, String)> people) async {
    if (people.length < 2) return;
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final candidates = [for (final (key, name) in people) MergeCandidate(contactKey: key, name: name, addresses: await db.addressesOf(key))];
    if (!mounted) return;
    final keep = await showMergePeopleDialog(context, candidates);
    if (keep == null || !mounted) return;
    final service = ref.read(classificationServiceProvider);
    final name = candidates.firstWhere((c) => c.contactKey == keep).name;
    final snapshot = await service.mergePeople(keep, [for (final c in candidates) c.contactKey]);
    if (!mounted) return;
    final selected = ref.read(selectedRowProvider);
    if (selected != null && candidates.any((c) => 'c:${c.contactKey}' == selected)) ref.read(selectedRowProvider.notifier).select('c:$keep');
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('Merged ${candidates.length} people into $name'),
      behavior: SnackBarBehavior.floating,
      width: 480,
      action: SnackBarAction(label: 'Undo', onPressed: () => service.undoMerge(snapshot)),
    ));
  }

  /// R / Shift+R / F: open the inline composer on the row's newest message.
  Future<void> _reply(PeopleRow row, {bool all = false, bool forward = false}) async {
    final newest = (await ref.read(databaseProvider).messagesForRow(row.rowKey)).where((m) => !m.isDraft).firstOrNull;
    if (newest == null || !mounted) return;
    final n = ref.read(replyRequestProvider.notifier);
    n.open(forward ? ComposeRequest.forward(newest.id, rowKey: row.rowKey) : ComposeRequest.reply(newest.id, rowKey: row.rowKey, all: all));
  }

  Future<void> _act(PeopleRow row, RowAction action) async {
    final actions = ref.read(rowActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    PendingAction? pending;
    switch (action) {
      case RowAction.archive:
        pending = await actions.archiveRow(row.rowKey);
      case RowAction.trash:
        final keep = await showSelectiveKeepDialog(context, row);
        if (keep == null) return;
        pending = await actions.trashRow(row.rowKey, messageIds: keep);
      case RowAction.markRead:
        await actions.markRowRead(row.rowKey);
      case RowAction.pin:
        await actions.togglePin(row.rowKey);
      case RowAction.moveToChats:
        await _moveRowsTo([row], InboxMode.people);
      case RowAction.moveToFeed:
        await _moveRowsTo([row], InboxMode.feed);
      case RowAction.moveToNoise:
        await _moveRowsTo([row], InboxMode.noise);
      case RowAction.toggleCounts:
        if (row.ref case ContactRow(:final contactKey)) {
          await ref.read(classificationServiceProvider).setCountsTowardUnread(contactKey, !row.countsTowardUnread);
        }
      case RowAction.mute:
        final db = ref.read(databaseProvider);
        final pref = await db.rowPref(row.rowKey);
        final muted = !(pref?.muted ?? false);
        await db.into(db.rowPrefs).insertOnConflictUpdate(RowPrefsCompanion(rowKey: Value(row.rowKey), muted: Value(muted), updatedAt: Value(DateTime.now())));
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text(muted ? 'Notifications muted for ${row.title}' : 'Notifications on for ${row.title}'), behavior: SnackBarBehavior.floating, width: 420));
      case RowAction.snooze:
        final until = await showSnoozePicker(context, currentlySnoozedUntil: row.snoozedUntil);
        if (until == null || !mounted) return;
        await ref.read(databaseProvider).snoozeRow(row.rowKey, until == SnoozeChoice.unsnooze ? null : until);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text(until == SnoozeChoice.unsnooze ? '${row.title} is back in the list' : '${row.title} put off until ${describeSnooze(until)}'),
          behavior: SnackBarBehavior.floating,
          width: 420,
          action: until == SnoozeChoice.unsnooze ? null : SnackBarAction(label: 'Undo', onPressed: () => ref.read(databaseProvider).snoozeRow(row.rowKey, null)),
        ));
        if (ref.read(selectedRowProvider) == row.rowKey && until != SnoozeChoice.unsnooze) ref.read(selectedRowProvider.notifier).select(null);
      case RowAction.rename:
        if (row.ref case ContactRow(:final contactKey)) {
          final db = ref.read(databaseProvider);
          final service = ref.read(classificationServiceProvider);
          final addresses = await db.addressesOf(contactKey);
          if (!mounted) return;
          final edit = await showEditSenderDialog(
            context,
            name: row.title,
            subtitle: row.subtitle ?? '',
            addresses: addresses,
            onSeparate: (address) => service.separateAddress(contactKey, address),
          );
          if (edit == null) return;
          await db.setContactLabel(contactKey, edit.name);
          await db.setContactSubtitle(contactKey, edit.subtitle);
        }
      case RowAction.mergeWith:
        if (row.ref case ContactRow(:final contactKey)) {
          final db = ref.read(databaseProvider);
          final all = [...await db.peopleRows(), ...await db.peopleRows(tab: InboxTab.feeds)];
          final others = <String, MergeCandidate>{};
          for (final r in all) {
            if (r.ref case ContactRow(:final contactKey) when contactKey != row.identityKey && contactKey != 'me') {
              others[contactKey] = MergeCandidate(contactKey: contactKey, name: r.title, addresses: [contactKey]);
            }
          }
          if (!mounted) return;
          final people = others.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          final picked = await showMergePickerDialog(context, forName: row.title, people: people);
          if (picked == null || !mounted) return;
          await _merge([(contactKey, row.title), (picked.contactKey, picked.name)]);
        }
      case RowAction.category:
        if (row.ref case ContactRow(:final contactKey)) {
          final names = await ref.read(databaseProvider).categoryNames();
          if (!mounted) return;
          final picked = await showDialog<String?>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: Text('Category for ${row.title}'),
              children: [
                for (final n in names)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, n),
                    child: Row(children: [
                      Icon(n == row.category ? Icons.radio_button_checked : Icons.radio_button_off, size: 18),
                      const SizedBox(width: 10),
                      Text(n),
                    ]),
                  ),
              ],
            ),
          );
          if (picked != null) await ref.read(classificationServiceProvider).setSenderCategory(contactKey, picked);
        }
    }
    if (pending != null && mounted) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(pending.label),
        duration: actions.undoWindow,
        behavior: SnackBarBehavior.floating,
        width: 420,
        action: SnackBarAction(label: 'Undo', onPressed: () => actions.undo(pending!)),
      ));
      if (ref.read(selectedRowProvider) == row.rowKey) ref.read(selectedRowProvider.notifier).select(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(inboxModeProvider);
    final filter = ref.watch(peopleFilterProvider);
    final sort = ref.watch(peopleSortProvider).value ?? PeopleSort.newest;
    final rows = ref.watch(peopleRowsProvider);
    final selected = ref.watch(selectedRowProvider);
    final picked = ref.watch(multiSelectProvider);
    final liveCodes = {
      for (final i in timelyDue(ref.watch(timelyItemsProvider).value ?? const [], DateTime.now()).reversed)
        if (i.code != null) 'c:${i.contactKey}': i.code!,
    };

    ref.listen(multiSelectProvider, (prev, next) => _onPickedChanged(prev, next, mode));

    // Chats and Feeds share this pane: each keeps its own search text, and
    // picked rows do not carry across.
    ref.listen(inboxModeProvider, (_, _) {
      ref.read(multiSelectProvider.notifier).clear();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Builder(builder: (context) {
                  final scope = ref.watch(accountScopeProvider);
                  final accounts = ref.watch(accountsProvider).value ?? const [];
                  final current = accounts.where((a) => a.id == scope).firstOrNull;
                  if (current == null) return Text(mode.label, style: text.headlineMedium);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(mode.label, style: text.headlineMedium),
                      const SizedBox(width: 10),
                      Flexible(
                        child: InputChip(
                          key: const ValueKey('scope-chip'),
                          avatar: CircleAvatar(backgroundColor: accountColor(current.id, scheme), radius: 5),
                          label: Text(current.email, overflow: TextOverflow.ellipsis),
                          onDeleted: () => ref.read(accountScopeProvider.notifier).select(null),
                          deleteButtonTooltipMessage: 'Show all accounts',
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  );
                }),
              ),
              // Search opens a bar across the top of the app; no search box
              // takes room here.
              IconButton(
                key: const ValueKey('search-button'),
                tooltip: 'Search (Ctrl+F)',
                isSelected: ref.watch(searchBarShownProvider),
                icon: const Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.search_rounded, color: scheme.primary),
                onPressed: () => ref.read(searchOpenProvider.notifier).toggle(),
              ),
              PopupMenuButton<Object>(
                key: const ValueKey('filter-menu'),
                tooltip: 'Sort and filter',
                onSelected: (v) {
                  if (v is PeopleFilter) ref.read(peopleFilterProvider.notifier).select(v);
                  if (v is PeopleSort) ref.read(peopleSortProvider.notifier).select(v);
                },
                icon: filter == PeopleFilter.all && sort == PeopleSort.newest
                    ? const Icon(Icons.tune_rounded)
                    : Icon(Icons.filter_alt_rounded, color: scheme.primary),
                itemBuilder: (context) {
                  PopupMenuItem<Object> item(Object value, String label, bool checked) => PopupMenuItem<Object>(
                        key: ValueKey('menu-$value'),
                        value: value,
                        height: 40,
                        child: Row(
                          children: [
                            SizedBox(width: 24, child: checked ? Icon(Icons.check_rounded, size: 20, color: scheme.primary) : null),
                            const SizedBox(width: 12),
                            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                  PopupMenuItem<Object> heading(String label) => PopupMenuItem<Object>(
                        enabled: false,
                        height: 32,
                        child: Text(label, style: text.labelSmall!.copyWith(letterSpacing: 1, color: scheme.onSurfaceVariant)),
                      );
                  return [
                    heading('SORT'),
                    for (final s in PeopleSort.values) item(s, _sortLabels[s]!, s == sort),
                    const PopupMenuDivider(),
                    heading('SHOW'),
                    for (final f in PeopleFilter.values) item(f, _filterLabels[f]!, f == filter),
                  ];
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (mode.isFeeds && !ref.watch(searchActiveProvider)) const _FeedsCategoryPills(),
        if (mode == InboxMode.noise && !ref.watch(searchActiveProvider) && picked.isEmpty) _NoiseHeader(onArchiveAll: () => _archiveAllNoise(ref.read(listRowsProvider(InboxTab.noise)).value ?? const [])),
        if (picked.isNotEmpty) _SelectionBar(count: picked.length, mode: mode, canMerge: (rows.value ?? const <PeopleRow>[]).where((r) => picked.contains(r.rowKey) && !r.isGroup && r.identityKey != 'me').length >= 2, onAction: (a) => _bulk(a, rows.value ?? const []), onClear: () => ref.read(multiSelectProvider.notifier).clear()),
        Expanded(
          child: rows.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e', style: text.bodyMedium!.copyWith(color: scheme.error))),
            data: (list) {
              if (mode.isFeeds && list.isEmpty && !ref.watch(searchActiveProvider) && ref.watch(feedsCategoryFilterProvider) == null && filter == PeopleFilter.all) {
                return mode == InboxMode.feed
                    ? const EmptyState(icon: Icons.rss_feed_rounded, title: 'Nothing in Feed', message: 'Receipts, deliveries, travel and other updates land here on their own.')
                    : const EmptyState(icon: Icons.volume_off_outlined, title: 'Nothing in Noise', message: 'Promotions, social notices and newsletters you never open are kept here, out of the way.');
              }
              if (ref.watch(searchActiveProvider)) {
                // People found by search can be picked like the full list, the
                // quickest way to gather everyone to merge.
                return SearchResultsView(
                  people: list,
                  onOpenRow: (row) => _onRowTap(row, list),
                  picked: picked,
                  onCheck: (row) => ref.read(multiSelectProvider.notifier).toggle(row.rowKey),
                );
              }
              if (list.isEmpty) return _empty(filter);
              if (ref.read(autoOpenFirstProvider) && selected == null && !_autoOpened) {
                _autoOpened = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(selectedRowProvider.notifier).select(list.first.rowKey));
              }
              return Focus(
                focusNode: _listFocus,
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                  final key = event.logicalKey;
                  if (key == LogicalKeyboardKey.arrowDown) {
                    _moveSelection(list, 1);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.arrowUp) {
                    _moveSelection(list, -1);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.keyA && HardwareKeyboard.instance.isControlPressed) {
                    ref.read(multiSelectProvider.notifier).setAll([for (final r in list) r.rowKey]);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.escape && ref.read(multiSelectProvider).isNotEmpty) {
                    ref.read(multiSelectProvider.notifier).clear();
                    return KeyEventResult.handled;
                  }
                  final current = list.where((r) => r.rowKey == selected).firstOrNull;
                  if (current == null) return KeyEventResult.ignored;
                  if (key == LogicalKeyboardKey.keyE) {
                    _act(current, RowAction.archive);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.delete) {
                    _act(current, RowAction.trash);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.keyP) {
                    _act(current, RowAction.pin);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.keyS) {
                    _act(current, RowAction.snooze);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.keyR) {
                    _reply(current, all: HardwareKeyboard.instance.isShiftPressed);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.keyF) {
                    _reply(current, forward: true);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: ListView.builder(
                  key: PageStorageKey(mode),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) return mode == InboxMode.people ? const _FeedsBanner() : const SizedBox.shrink();
                    final row = list[i - 1];
                    return Padding(
                      padding: EdgeInsets.only(top: i == 1 ? 0 : 2),
                      child: GroupedListItem(
                        radius: GroupedList.radiusFor(i - 1, list.length),
                        selected: row.rowKey == selected || picked.contains(row.rowKey),
                        onTap: () => _onRowTap(row, list),
                        child: PersonRow(
                          row: row,
                          liveCode: mode.isFeeds ? liveCodes['c:${row.identityKey}'] : null,
                          selected: row.rowKey == selected,
                          onAction: (a) => _act(row, a),
                          checked: picked.contains(row.rowKey),
                          selectionMode: picked.isNotEmpty,
                          onCheck: () => ref.read(multiSelectProvider.notifier).toggle(row.rowKey),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _empty(PeopleFilter filter) {
    if (filter != PeopleFilter.all || ref.read(peopleSearchProvider).isNotEmpty || ref.read(feedsCategoryFilterProvider) != null) {
      return const EmptyState(icon: Icons.filter_list_off_rounded, title: 'Nothing matches', message: 'Try another filter or search.');
    }
    return EmptyState(
      icon: Icons.forum_outlined,
      title: 'No conversations yet',
      message: 'Add an account in Settings to start syncing.',
      action: FilledButton.tonalIcon(
        onPressed: () {
          ref.read(settingsSectionProvider.notifier).select(SettingsSection.accounts);
          ref.read(settingsAddAccountRequestProvider.notifier).set(true);
          ref.read(destinationProvider.notifier).select(Destination.settings);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add account'),
      ),
    );
  }
}

/// Shown while rows are picked: the count and the bulk actions.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.mode, required this.canMerge, required this.onAction, required this.onClear});
  final bool canMerge;
  final int count;
  final InboxMode mode;
  final ValueChanged<BulkAction> onAction;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        key: const ValueKey('selection-bar'),
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppShapes.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          child: Row(
            children: [
              IconButton(tooltip: 'Clear selection (Esc)', icon: const Icon(Icons.close_rounded, size: 20), onPressed: onClear),
              Expanded(child: Text('$count selected', maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge!.copyWith(color: scheme.onSecondaryContainer))),
              if (mode != InboxMode.people)
                IconButton(key: const ValueKey('bulk-move-chats'), tooltip: 'Move to Chats', icon: const Icon(Icons.person_outline_rounded, size: 20), onPressed: () => onAction(BulkAction.moveToChats)),
              if (mode != InboxMode.feed)
                IconButton(key: const ValueKey('bulk-move-feed'), tooltip: 'Move to Feed', icon: const Icon(Icons.rss_feed_rounded, size: 20), onPressed: () => onAction(BulkAction.moveToFeed)),
              if (mode != InboxMode.noise)
                IconButton(key: const ValueKey('bulk-move-noise'), tooltip: 'Move to Noise', icon: const Icon(Icons.volume_off_outlined, size: 20), onPressed: () => onAction(BulkAction.moveToNoise)),
              if (canMerge)
                IconButton(key: const ValueKey('bulk-merge'), tooltip: 'Merge into one person', icon: const Icon(Icons.merge_rounded, size: 20), onPressed: () => onAction(BulkAction.merge)),
              IconButton(key: const ValueKey('bulk-read'), tooltip: 'Mark as read', icon: const Icon(Icons.mark_email_read_outlined, size: 20), onPressed: () => onAction(BulkAction.markRead)),
              IconButton(key: const ValueKey('bulk-archive'), tooltip: 'Archive', icon: const Icon(Icons.archive_outlined, size: 20), onPressed: () => onAction(BulkAction.archive)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pills under the search bar on Feeds: All, then each category with
/// mail. Scrolls sideways when the pane is narrow.
class _FeedsCategoryPills extends ConsumerWidget {
  const _FeedsCategoryPills();

  static String _label(String category) => switch (category) {
        'Newsletter' => 'Newsletters',
        'Receipt' => 'Receipts',
        'Notification' => 'Notifications',
        'Promotion' => 'Promotions',
        'Delivery' => 'Deliveries',
        'OTP' => 'OTPs',
        _ => category,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(feedsCategoriesInUseProvider).value ?? const <String>[];
    final selected = ref.watch(feedsCategoryFilterProvider);
    // The picked category was renamed, deleted or emptied: back to All.
    if (selected != null && ref.watch(feedsCategoriesInUseProvider).hasValue && !categories.contains(selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(feedsCategoryFilterProvider.notifier).select(null));
    }
    if (categories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _FeedsPill(key: const ValueKey('feeds-pill-all'), label: 'All', selected: selected == null, onTap: () => ref.read(feedsCategoryFilterProvider.notifier).select(null)),
            for (final c in categories) ...[
              const SizedBox(width: 6),
              _FeedsPill(key: ValueKey('feeds-pill-$c'), label: _label(c), category: c, selected: selected == c, onTap: () => ref.read(feedsCategoryFilterProvider.notifier).select(selected == c ? null : c)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedsPill extends StatelessWidget {
  const _FeedsPill({super.key, required this.label, required this.selected, required this.onTap, this.category});
  final String label;

  /// The category it filters to, for its colour; null for All.
  final String? category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium!;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppShapes.full),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (category != null) ...[CategoryDot(category: category!, size: 8), const SizedBox(width: 6)],
                Text(label, style: style.copyWith(color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, letterSpacing: 0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The line at the top of Noise: how much was kept out of the way this week
/// (shown only once the whole count is known), and one button to clear it.
class _NoiseHeader extends ConsumerWidget {
  const _NoiseHeader({required this.onArchiveAll});
  final VoidCallback onArchiveAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final n = ref.watch(noiseThisWeekProvider).value;
    final senders = ref.watch(listRowsProvider(InboxTab.noise)).value?.length ?? 0;
    if (senders == 0) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('noise-header'),
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              n == null ? 'Kept out of your way. None of it rings.' : '$n email${n == 1 ? '' : 's'} this week, kept out of your way.',
              style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            key: const ValueKey('noise-archive-all'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: onArchiveAll,
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('Archive all'),
          ),
        ],
      ),
    );
  }
}

/// The calendar week [now] falls in, named by its Monday (local time).
String feedsBannerWeek(DateTime now) {
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - DateTime.monday));
  return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}

const feedsBannerDismissedKey = 'feedsBanner.dismissedWeek';

/// The week the user last dismissed the Feeds banner, from the database so
/// the choice survives a restart.
final feedsBannerDismissedProvider = AsyncNotifierProvider<FeedsBannerDismissed, String?>(FeedsBannerDismissed.new);

class FeedsBannerDismissed extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.read(databaseProvider).getSetting(feedsBannerDismissedKey);

  Future<void> dismiss(DateTime now) async {
    final week = feedsBannerWeek(now);
    state = AsyncData(week);
    await ref.read(databaseProvider).putSetting(feedsBannerDismissedKey, week);
  }
}

/// "N filed to Feeds this week" (spec 4.11): shows how much was sorted
/// out of People, and jumps to the Feeds tab. Dismissing it hides it until
/// the next calendar week.
class _FeedsBanner extends ConsumerWidget {
  const _FeedsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(feedsFiledThisWeekProvider).value ?? 0;
    final dismissed = ref.watch(feedsBannerDismissedProvider);
    if (n == 0 || dismissed.isLoading || dismissed.value == feedsBannerWeek(DateTime.now())) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: const ValueKey('feeds-banner'),
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppShapes.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ref.read(destinationProvider.notifier).select(Destination.feed),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Icon(Icons.rss_feed_rounded, size: 18, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(child: Text('$n message${n == 1 ? '' : 's'} filed to Feed and Noise this week', style: text.labelLarge!.copyWith(color: scheme.onTertiaryContainer))),
                IconButton(
                  key: const ValueKey('feeds-banner-dismiss'),
                  tooltip: 'Dismiss until next week',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  color: scheme.onTertiaryContainer,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => ref.read(feedsBannerDismissedProvider.notifier).dismiss(DateTime.now()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final feedsFiledThisWeekProvider = StreamProvider<int>((ref) => ref.watch(databaseProvider).watchFeedsFiledSince(DateTime.now().subtract(const Duration(days: 7))));

/// Small helper so both the row and the pane agree on action names.
enum RowAction { archive, trash, markRead, pin, moveToChats, moveToFeed, moveToNoise, toggleCounts, category, snooze, mute, rename, mergeWith }

/// Actions on every picked row at once.
enum BulkAction { moveToChats, moveToFeed, moveToNoise, merge, markRead, archive }

/// Relative timestamp per spec 4.2: time today, "Yesterday", weekday this
/// week, date otherwise.
String relativeTime(DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final n = now ?? DateTime.now();
  final local = t.toLocal();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return TimeOfDay.fromDateTime(local).format2();
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][local.weekday - 1];
  if (local.year == n.year) return '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][local.month - 1]} ${local.day}';
  return '${local.month}/${local.day}/${local.year % 100}';
}

extension on TimeOfDay {
  String format2() {
    final h = hourOfPeriod == 0 ? 12 : hourOfPeriod;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m ${period == DayPeriod.am ? 'AM' : 'PM'}';
  }
}

/// Avatar for a row: stacked for groups, tonal circle otherwise.
Widget rowAvatar(PeopleRow row, {double size = 40}) {
  if (row.isGroup) return StackedAvatars(members: row.members, size: size);
  final photo = row.photoPath;
  // Initials if the file is gone; the next contacts sync restores it.
  final image = photo != null && File(photo).existsSync() ? FileImage(File(photo)) : null;
  return TonalAvatar(identityKey: row.identityKey, name: row.title, size: size, image: image);
}

/// Space reserved so the FAB never covers the last row.
const double peopleListBottomInset = AppSpace.lg;
