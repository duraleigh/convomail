import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The words highlighted inside a designed email.
///
/// A designed email (a hotel's, a bank's) is shown in a small browser box.
/// The box takes the mouse, so words in it can be highlighted, but it never
/// receives key presses and has no menu of its own. So the page tells the
/// app what is highlighted, and the app does the copying: on Ctrl+C, and
/// from the menu a right-click brings up.
///
/// Only one email holds the highlight at a time: the one last highlighted in.
abstract final class WebSelection {
  static Object? _owner;
  static String _text = '';
  static VoidCallback? _clear;

  /// Tells listeners (and checks) when the highlighted words change.
  static final ValueNotifier<String> changed = ValueNotifier('');

  /// The highlighted words, or null when nothing in a designed email is.
  static String? get text => _text.isEmpty ? null : _text;

  /// [owner]'s page reports what is highlighted in it now. [clear] removes
  /// the highlight from that page.
  static void report(Object owner, String text, VoidCallback clear) {
    if (text.isEmpty) {
      drop(owner);
      return;
    }
    // A highlight started in another email replaces the earlier one.
    if (_owner != null && !identical(_owner, owner)) _clear?.call();
    _owner = owner;
    _text = text;
    _clear = clear;
    changed.value = text;
  }

  /// [owner] has nothing highlighted any more (or is gone).
  static void drop(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _text = '';
    _clear = null;
    changed.value = '';
  }

  /// Removes the highlight: the user clicked somewhere else in the app.
  static void clear() {
    final clear = _clear;
    _owner = null;
    _text = '';
    _clear = null;
    changed.value = '';
    clear?.call();
  }

  /// Puts the highlighted words on the clipboard. Returns whether there
  /// were any.
  static Future<bool> copy() async {
    final t = text;
    if (t == null) return false;
    await Clipboard.setData(ClipboardData(text: t));
    return true;
  }
}
