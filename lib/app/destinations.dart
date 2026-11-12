import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/people_queries.dart';

/// Top-level navigation destinations on the rail.
enum Destination {
  today('Précis', Icons.today_outlined, Icons.today_rounded),
  focus('Focus', Icons.adjust_rounded, Icons.adjust_rounded),
  chats('Chats', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  feed('Feed', Icons.rss_feed_rounded, Icons.rss_feed_rounded),
  noise('Noise', Icons.volume_off_outlined, Icons.volume_off_rounded),
  attachments('Attachments', Icons.attach_file_rounded, Icons.attach_file_rounded),
  settings('Settings', Icons.settings_outlined, Icons.settings_rounded);

  const Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Rail destinations, in order. Settings is pinned to the bottom of the rail.
  static const List<Destination> rail = [today, focus, chats, feed, noise, attachments];

  /// Chats is the list of people with the open conversation. (Focus, Feed
  /// and Noise are lists of emails, each with its own screen.)
  bool get isList => this == chats;
}

/// Currently selected destination.
final destinationProvider = NotifierProvider<DestinationNotifier, Destination>(DestinationNotifier.new);

class DestinationNotifier extends Notifier<Destination> {
  DestinationNotifier({Destination? initial}) : _initial = initial ?? Destination.chats;
  final Destination _initial;

  @override
  Destination build() => _initial;

  /// Goes to [d]. [fromToday] says the user got here by clicking something
  /// on Today, so the way back is offered; going anywhere any other way
  /// takes that offer away.
  void select(Destination d, {bool fromToday = false}) {
    ref.read(cameFromTodayProvider.notifier).set(fromToday && d != Destination.today);
    state = d;
  }
}

/// Whether the screen showing was reached by clicking something on Today
/// (so "Back to Today" is offered above it).
final cameFromTodayProvider = NotifierProvider<CameFromToday, bool>(CameFromToday.new);

class CameFromToday extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) {
    if (state != v) state = v;
  }
}

/// Which list the shared layout shows: the people on Chats, or the senders
/// that are not people on Feed and on Noise. Everything else reads as
/// people, so Today and Focus open into Chats.
enum InboxMode {
  people('Chats', InboxTab.people, Destination.chats),
  feed('Feed', InboxTab.feed, Destination.feed),
  noise('Noise', InboxTab.noise, Destination.noise);

  const InboxMode(this.label, this.tab, this.destination);
  final String label;
  final InboxTab tab;
  final Destination destination;

  /// Feed or Noise: senders that are not people.
  bool get isFeeds => this != people;
}

final inboxModeProvider = Provider<InboxMode>((ref) => switch (ref.watch(destinationProvider)) {
      Destination.feed => InboxMode.feed,
      Destination.noise => InboxMode.noise,
      _ => InboxMode.people,
    });
