import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top-level navigation destinations on the rail (spec 5.3).
enum Destination {
  chats('Chats', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  boards('Boards', Icons.view_kanban_outlined, Icons.view_kanban_rounded),
  planner('Planner', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
  settings('Settings', Icons.settings_outlined, Icons.settings_rounded);

  const Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Rail destinations, in order. Settings is pinned to the bottom of the rail.
  static const List<Destination> rail = [chats, boards, planner];
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

/// People / Feeds toggle state on the Chats destination (spec 4.11).
enum InboxMode { people, feeds }

final inboxModeProvider = NotifierProvider<InboxModeNotifier, InboxMode>(InboxModeNotifier.new);

class InboxModeNotifier extends Notifier<InboxMode> {
  InboxModeNotifier({InboxMode? initial}) : _initial = initial ?? InboxMode.people;
  final InboxMode _initial;

  @override
  InboxMode build() => _initial;
  void select(InboxMode m) => state = m;
}
