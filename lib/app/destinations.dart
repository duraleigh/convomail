import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top-level navigation destinations on the rail (spec 5.3).
enum Destination {
  chats('Chats', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  feeds('Feeds', Icons.rss_feed_rounded, Icons.rss_feed_rounded),
  boards('Boards', Icons.view_kanban_outlined, Icons.view_kanban_rounded),
  planner('Planner', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
  settings('Settings', Icons.settings_outlined, Icons.settings_rounded);

  const Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Rail destinations, in order. Settings is pinned to the bottom of the rail.
  static const List<Destination> rail = [chats, feeds, boards, planner];
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

/// Which list the shared chat layout shows (spec 4.11): the people on Chats,
/// the automated senders on Feeds. Follows the destination; everything
/// outside Feeds reads as people, so Boards and Planner open into Chats.
enum InboxMode { people, feeds }

final inboxModeProvider = Provider<InboxMode>((ref) => ref.watch(destinationProvider) == Destination.feeds ? InboxMode.feeds : InboxMode.people);
