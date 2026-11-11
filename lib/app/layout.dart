import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set by tests to try the phone layout (true) or the PC layout (false)
/// whatever they run on. Null lets the device decide.
final forceCompactProvider = Provider<bool?>((ref) => null);

/// Whether this is Android at all (touch first: swipes and long presses,
/// no hovering, no right click). Replaceable in tests.
final isTouchDeviceProvider = Provider<bool>((ref) => Platform.isAndroid);

/// On a phone: whether something is open and filling the screen right now
/// (an email, a conversation, a settings page). The screen that is showing
/// it says so itself, so the bar along the bottom can never disagree with
/// what is on screen.
final compactDetailProvider = NotifierProvider<CompactDetail, bool>(CompactDetail.new);

class CompactDetail extends Notifier<bool> {
  /// The screen that is showing something full screen. One screen leaving
  /// never clears what the next one has just said.
  Object? _by;

  @override
  bool build() => false;

  void set(Object screen, bool showing) {
    if (!ref.mounted) return;
    if (showing) {
      _by = screen;
    } else if (identical(_by, screen)) {
      _by = null;
    }
    final now = _by != null;
    if (state != now) state = now;
  }
}

/// The phone layout: one pane at a time with a bar along the bottom.
///
/// A phone gets it either way up. A tablet gets it upright, and the PC's
/// side-by-side layout when turned sideways. A PC never gets it.
bool isCompactLayout(BuildContext context, WidgetRef ref) {
  final forced = ref.watch(forceCompactProvider);
  if (forced != null) return forced;
  if (!ref.watch(isTouchDeviceProvider)) return false;
  final size = MediaQuery.sizeOf(context);
  return size.shortestSide < 600 || size.width < 900;
}
