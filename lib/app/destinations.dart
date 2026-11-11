import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/people_queries.dart';

/// Top-level navigation destinations on the rail.
enum Destination {
  today('Today', Icons.today_outlined, Icons.today_rounded),
  focus('Focus', Icons.adjust_rounded, Icons.adjust_rounded),
  chats('Chats', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  feed('Feed', Icons.rss_feed_rounded, Icons.rss_feed_rounded),
  noise('Noise', Icons.volume_off_outlined, Icons.volume_off_rounded),
  settings('Settings', Icons.settings_outlined, Icons.settings_rounded);

  const Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Rail destinations, in order. Settings is pinned to the bottom of the rail.
  static const List<Destination> rail = [today, focus, chats, feed, noise];

  /// Chats, Feed and Noise share one layout: a list and the open conversation.
  bool get isList => this == chats || this == feed || this == noise;
}

/// Currently selected destination.
final destinationProvider = NotifierProvider<DestinationNotifier, Destination>(DestinationNotifier.new);

class DestinationNotifier extends Notifier<Destination> {
  DestinationNotifier({Destination? initial}) : _initial = initial ?? Destination.chats;
  final Destination _initial;

  @override
  Destination build() => _initial;
  void select(Destination d) => state = d;
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
