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
import '../../../app/shortcuts.dart';
import '../../../domain/classifier.dart';
import '../../../domain/filing.dart';
import '../../../store/classification_queries.dart';
import '../../../store/database.dart';
import '../../../store/people_queries.dart';
import '../../../store/planner_queries.dart';
import '../../../sync/classification_service.dart';
import '../../../sync/row_actions.dart';
import '../../theme/tokens.dart';
import '../../widgets/connected_button_group.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/tonal_avatar.dart';
import '../planner/event_dialogs.dart';
import 'person_row.dart';
import 'search_results_view.dart';
import 'selective_keep_dialog.dart';

/// The middle pane of the Chats destination (spec 5.3): headline, search,
/// filter chips, People/Feeds group, and the grouped People list with
/// hover actions, context menu, and keyboard navigation.
class PeopleListPane extends ConsumerStatefulWidget {
  const PeopleListPane({super.key});

  @override
  ConsumerState<PeopleListPane> createState() => _PeopleListPaneState();
}

class _PeopleListPaneState extends ConsumerState<PeopleListPane> {
  final _listFocus = FocusNode(debugLabel: 'people-list');
  final _searchController = TextEditingController();
  bool _autoOpened = false;

  static const _filterLabels = {
    PeopleFilter.all: 'All',
    PeopleFilter.unread: 'Unread',
    PeopleFilter.starred: 'Starred',
    PeopleFilter.thisWeek: 'This Week',
    PeopleFilter.sent: 'Sent',
    PeopleFilter.hasAttachments: 'Has attachments',
    PeopleFilter.fromContacts: 'From contacts',
    PeopleFilter.snoozed: 'Snoozed',
  };

  @override
  void dispose() {
    _listFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _moveSelection(List<PeopleRow> rows, int delta) {
    if (rows.isEmpty) return;
    final current = ref.read(selectedRowProvider);
    var i = rows.indexWhere((r) => r.rowKey == current);
    i = (i + delta).clamp(0, rows.length - 1);
    ref.read(selectedRowProvider.notifier).select(rows[i].rowKey);
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
      case RowAction.moveToFeeds:
      case RowAction.moveToPeople:
        // Spec 4.11: a manual move is permanent until changed.
        if (row.ref case ContactRow(:final contactKey)) {
          final target = action == RowAction.moveToFeeds ? Bucket.feeds : Bucket.people;
          await ref.read(classificationServiceProvider).moveSender(contactKey, target);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(SnackBar(
            content: Text('${row.title} moved to ${target == Bucket.feeds ? 'Feeds' : 'People'}. Rules will not move it back.'),
            behavior: SnackBarBehavior.floating,
            width: 460,
            action: SnackBarAction(label: 'Undo', onPressed: () => ref.read(classificationServiceProvider).moveSender(contactKey, null)),
          ));
        }
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
          content: Text(until == SnoozeChoice.unsnooze ? '${row.title} is back in the list' : '${row.title} snoozed until ${describeSnooze(until)}'),
          behavior: SnackBarBehavior.floating,
          width: 420,
          action: until == SnoozeChoice.unsnooze ? null : SnackBarAction(label: 'Undo', onPressed: () => ref.read(databaseProvider).snoozeRow(row.rowKey, null)),
        ));
        if (ref.read(selectedRowProvider) == row.rowKey && until != SnoozeChoice.unsnooze) ref.read(selectedRowProvider.notifier).select(null);
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
    final rows = ref.watch(peopleRowsProvider);
    final selected = ref.watch(selectedRowProvider);
    final searchFocus = ref.watch(searchFocusProvider);

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
                  if (current == null) return Text('Chats', style: text.headlineMedium);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Chats', style: text.headlineMedium),
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
              IconButton(tooltip: 'Filters', onPressed: () {}, icon: const Icon(Icons.tune_rounded)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SearchBar(
            controller: _searchController,
            focusNode: searchFocus,
            hintText: 'Search people and mail',
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(peopleSearchProvider.notifier).set('');
                  },
                ),
            ],
            onChanged: (v) => ref.read(peopleSearchProvider.notifier).set(v),
            onSubmitted: (_) => _listFocus.requestFocus(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in PeopleFilter.values)
                FilterChip(
                  label: Text(_filterLabels[f]!),
                  selected: f == filter,
                  onSelected: (_) => ref.read(peopleFilterProvider.notifier).select(f),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: ConnectedButtonGroup<InboxMode>(
            selected: mode,
            onSelected: (m) => ref.read(inboxModeProvider.notifier).select(m),
            items: const [
              ButtonGroupItem(value: InboxMode.people, label: 'People', icon: Icons.person_outline_rounded),
              ButtonGroupItem(value: InboxMode.feeds, label: 'Feeds', icon: Icons.rss_feed_rounded),
            ],
          ),
        ),
        Expanded(
          child: rows.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e', style: text.bodyMedium!.copyWith(color: scheme.error))),
            data: (list) {
              if (mode == InboxMode.feeds && list.isEmpty && !ref.watch(searchActiveProvider)) {
                return const EmptyState(icon: Icons.rss_feed_rounded, title: 'Nothing in Feeds', message: 'Newsletters, receipts, and notifications land here automatically.');
              }
              if (ref.watch(searchActiveProvider)) {
                return SearchResultsView(
                  people: list,
                  onOpenRow: (row) {
                    ref.read(selectedRowProvider.notifier).select(row.rowKey);
                    _listFocus.requestFocus();
                  },
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) return mode == InboxMode.people ? const _FeedsBanner() : const SizedBox.shrink();
                    final row = list[i - 1];
                    return Padding(
                      padding: EdgeInsets.only(top: i == 1 ? 0 : 2),
                      child: GroupedListItem(
                        radius: GroupedList.radiusFor(i - 1, list.length),
                        selected: row.rowKey == selected,
                        onTap: () {
                          ref.read(selectedRowProvider.notifier).select(row.rowKey);
                          _listFocus.requestFocus();
                        },
                        child: PersonRow(row: row, selected: row.rowKey == selected, onAction: (a) => _act(row, a)),
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
    if (filter != PeopleFilter.all || _searchController.text.isNotEmpty) {
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

/// "N filed to Feeds this week" (spec 4.11): shows how much was sorted
/// out of People, and jumps to the Feeds tab.
class _FeedsBanner extends ConsumerWidget {
  const _FeedsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(feedsFiledThisWeekProvider).value ?? 0;
    if (n == 0) return const SizedBox.shrink();
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
          onTap: () => ref.read(inboxModeProvider.notifier).select(InboxMode.feeds),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Icon(Icons.rss_feed_rounded, size: 18, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(child: Text('$n message${n == 1 ? '' : 's'} filed to Feeds this week', style: text.labelLarge!.copyWith(color: scheme.onTertiaryContainer))),
                Icon(Icons.chevron_right_rounded, size: 20, color: scheme.onTertiaryContainer),
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
enum RowAction { archive, trash, markRead, pin, moveToFeeds, moveToPeople, toggleCounts, category, snooze, mute }

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
  return TonalAvatar(identityKey: row.identityKey, name: row.title, size: size);
}

/// Space reserved so the FAB never covers the last row.
const double peopleListBottomInset = AppSpace.lg;
