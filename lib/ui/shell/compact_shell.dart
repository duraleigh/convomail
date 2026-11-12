import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/compose_state.dart';
import '../../app/conversation_state.dart';
import '../../app/destinations.dart';
import '../../app/layout.dart';
import '../../app/mail_state.dart';
import '../../app/people_state.dart';
import '../../app/settings_navigation.dart';
import '../../helper/device_join.dart';
import '../../store/people_queries.dart';
import '../screens/today_screen.dart' show DoneTodayList;
import '../theme/tokens.dart';

/// What the phone layout is showing: one of the main screens, the More
/// list, or a page reached from More.
enum CompactPage { main, more, done }

final compactPageProvider = NotifierProvider<CompactPageNotifier, CompactPage>(CompactPageNotifier.new);

class CompactPageNotifier extends Notifier<CompactPage> {
  @override
  CompactPage build() => CompactPage.main;
  void show(CompactPage p) => state = p;
}

/// On a phone, Settings shows its list first; this is whether one of its
/// pages is open.
final settingsDetailOpenProvider = NotifierProvider<SettingsDetailOpen, bool>(SettingsDetailOpen.new);

class SettingsDetailOpen extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool open) => state = open;
}

/// The phone layout: one screen at a time, with a bar along the bottom for
/// Today, Focus, Chats, Feed and More. More holds Noise, Done, Sent and
/// Settings. Opening an email, a conversation or a settings page fills the
/// screen; Back returns to the list.
class CompactShell extends ConsumerWidget {
  const CompactShell({super.key, required this.content, required this.searchBar});

  /// The screen for a destination (the same screens the PC shows).
  final Widget Function(Destination d) content;
  final Widget searchBar;

  static const tabs = [Destination.today, Destination.focus, Destination.chats, Destination.feed];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final destination = ref.watch(destinationProvider);
    final page = ref.watch(compactPageProvider);

    // Something is open and filling the screen: the bar and the compose
    // button step aside, and Back belongs to what is open.
    // The screen itself says when it is showing something full screen, so
    // the bar is hidden exactly when a Back arrow is on screen, never otherwise.
    final detail = page == CompactPage.main && (destination == Destination.today ? ref.watch(openThreadProvider) != null : ref.watch(compactDetailProvider));
    final underMore = page != CompactPage.main || destination == Destination.noise || destination == Destination.attachments || destination == Destination.settings;
    final index = underMore ? tabs.length : tabs.indexOf(destination);
    final focusCount = ref.watch(focusMailProvider).value?.length ?? 0;
    final feedNew = ref.watch(feedsHasNewProvider) && destination != Destination.feed;
    final chatsUnread = ref.watch(chatsUnreadProvider) > 0;
    final notice = ref.watch(joinNoticeProvider);

    void go(Destination d) {
      ref.read(compactPageProvider.notifier).show(CompactPage.main);
      ref.read(destinationProvider.notifier).select(d);
    }

    return PopScope(
      // Back always goes somewhere: from a page under More to More; from
      // More, Focus, Chats or Feed to Today; and only from Today does it
      // leave Précis.
      canPop: !detail && !underMore && destination == Destination.today,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || detail) return;
        if (page == CompactPage.main && underMore) {
          ref.read(compactPageProvider.notifier).show(CompactPage.more);
        } else if (page == CompactPage.done) {
          ref.read(compactPageProvider.notifier).show(CompactPage.more);
        } else {
          go(Destination.today);
        }
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchBar,
              if (notice != null)
                Material(
                  key: const ValueKey('join-notice'),
                  color: scheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Text(notice, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: scheme.onTertiaryContainer)),
                  ),
                ),
              Expanded(
                child: switch (page) {
                  CompactPage.main => KeyedSubtree(key: ValueKey(destination), child: content(destination)),
                  CompactPage.more => _MorePage(onGo: go),
                  CompactPage.done => const _DonePage(),
                },
              ),
            ],
          ),
        ),
        floatingActionButton: detail || page != CompactPage.main || !tabs.contains(destination)
            ? null
            : FloatingActionButton(
                key: const ValueKey('compact-compose'),
                heroTag: 'compose-fab',
                tooltip: 'New message',
                onPressed: () {
                  ref.read(destinationProvider.notifier).select(Destination.chats);
                  ref.read(composeProvider.notifier).open();
                },
                child: const Icon(Icons.edit_outlined),
              ),
        bottomNavigationBar: detail
            ? null
            : NavigationBar(
                key: const ValueKey('compact-bar'),
                selectedIndex: index,
                onDestinationSelected: (i) {
                  if (i < tabs.length) {
                    go(tabs[i]);
                  } else {
                    ref.read(compactPageProvider.notifier).show(CompactPage.more);
                  }
                },
                destinations: [
                  for (final d in tabs)
                    NavigationDestination(
                      icon: _icon(d, d.icon, focusCount, feedNew, chatsUnread, scheme),
                      selectedIcon: _icon(d, d.selectedIcon, focusCount, feedNew, chatsUnread, scheme),
                      label: d.label,
                    ),
                  const NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
                ],
              ),
      ),
    );
  }

  /// Focus carries the one number (how many emails need the user); Chats a
  /// plain dot while a chat has unread mail; Feed one when something new came in.
  static Widget _icon(Destination d, IconData icon, int focusCount, bool feedNew, bool chatsUnread, ColorScheme scheme) => switch (d) {
        // A plain dot while any chat has unread mail from a person.
        Destination.chats => Badge(key: const ValueKey('chats-badge'), isLabelVisible: chatsUnread, backgroundColor: scheme.primary, smallSize: 8, child: Icon(icon)),
        Destination.focus => Badge(
            key: const ValueKey('focus-badge'),
            isLabelVisible: focusCount > 0,
            label: Text('$focusCount'),
            backgroundColor: const Color(0xFFF48FB1),
            textColor: const Color(0xFF3E0A1F),
            child: Icon(icon),
          ),
        Destination.feed => Badge(key: const ValueKey('feeds-badge'), isLabelVisible: feedNew, backgroundColor: scheme.primary, smallSize: 8, child: Icon(icon)),
        _ => Icon(icon),
      };
}

class _MorePage extends ConsumerWidget {
  const _MorePage({required this.onGo});
  final void Function(Destination d) onGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget row(String key, IconData icon, String title, String line, VoidCallback onTap) => ListTile(
          key: ValueKey('more-$key'),
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(line),
          trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          onTap: onTap,
        );
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 14, 12, 6), child: Text('More', style: text.headlineMedium)),
        row('noise', Destination.noise.icon, 'Noise', 'Promotions and notices kept out of your way.', () => onGo(Destination.noise)),
        row('attachments', Destination.attachments.icon, 'Attachments', 'Every file sent to you or by you, to search and sort.', () => onGo(Destination.attachments)),
        row('done', Icons.check_circle_outline_rounded, 'Done', 'What you marked done today.', () => ref.read(compactPageProvider.notifier).show(CompactPage.done)),
        row('sent', Icons.send_outlined, 'Sent', 'The people you wrote to, newest first.', () {
          onGo(Destination.chats);
          ref.read(peopleFilterProvider.notifier).select(PeopleFilter.sent);
        }),
        row('settings', Destination.settings.icon, 'Settings', 'Your devices, alerts, the assistant, and the rest.', () {
          ref.read(settingsDetailOpenProvider.notifier).set(false);
          onGo(Destination.settings);
        }),
      ],
    );
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(8, 14, 12, 10), child: Text('Done', style: text.headlineMedium)),
        const DoneTodayList(),
      ],
    );
  }
}

/// The settings pages a phone shows. The rest are about a PC (its
/// keyboard, being the default mail app) or need a mouse.
bool settingsSectionOnPhone(SettingsSection s) => s != SettingsSection.keyboard && s != SettingsSection.defaultApp;
