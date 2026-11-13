import 'package:flutter/material.dart';

import '../../app/time_format.dart';

// The type and small furniture every line on the Précis page shares.
//
// Six sizes and three weights, so that at any text-size setting a label, a
// line and a headline are plainly three different things:
//   40 and 30  airport codes and the greeting
//   16         The Lede, a flight's route when it is drawn large, a code
//   14         a line's title, its time or amount
//   12         a line's second line
//   10.5       a group's label
// Weights: regular, medium, bold.

/// A line's title.
TextStyle rowTitle(BuildContext context, {bool strong = false}) {
  final t = Theme.of(context);
  return t.textTheme.labelLarge!.copyWith(fontSize: 14, height: 1.25, letterSpacing: 0.1, fontWeight: strong ? FontWeight.w700 : FontWeight.w500, color: t.colorScheme.onSurface);
}

/// A line's second line.
TextStyle rowSmall(BuildContext context) {
  final t = Theme.of(context);
  return t.textTheme.bodySmall!.copyWith(fontSize: 12, height: 1.3, letterSpacing: 0.2, fontWeight: FontWeight.w400, color: t.colorScheme.onSurfaceVariant);
}

/// The small label over a group ("TRAVEL"), and over a state ("UPCOMING").
TextStyle sectionLabel(BuildContext context, {Color? color}) {
  final t = Theme.of(context);
  return t.textTheme.labelSmall!.copyWith(fontSize: 10.5, height: 1.2, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: color ?? t.colorScheme.onSurfaceVariant);
}

/// The green of something done or going to plan: a package delivered, a
/// flight on time. Yellow and red are kept for a delay and a cancellation.
const okColor = Color(0xFF5FBF6B);
const warnColor = Color(0xFFFFCA28);
const badColor = Color(0xFFEF5350);

/// Times, amounts and codes line up in columns.
const tabularFigures = [FontFeature.tabularFigures()];

/// The quiet square at the start of a line that says what kind of thing it is.
class RowIcon extends StatelessWidget {
  const RowIcon(this.icon, {super.key, this.color});
  final IconData icon;

  /// Only for trouble (a cancelled booking); otherwise gray.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, size: 19, color: color ?? scheme.onSurfaceVariant),
    );
  }
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _fullDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// A day in a word, as a person would say it from [now]: Today, Tomorrow,
/// the weekday for the coming week ([long] writes it out), else "Nov 20".
String dayWord(DateTime day, DateTime now, {bool long = false}) {
  final diff = DateTime(day.year, day.month, day.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1 && diff < 7) return (long ? _fullDays : _days)[day.weekday - 1];
  return '${_months[day.month - 1]} ${day.day}';
}

/// A clock time as the user reads the clock.
String clockWord(DateTime t) => clockTime(t);
