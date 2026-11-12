import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/database.dart';
import '../store/helper_queries.dart' show kClockFormat;

export '../store/helper_queries.dart' show kClockFormat;

/// Whether clock times are shown the 24-hour way. One switch for the whole
/// app: every place that writes a time asks [clockTime].
bool use24Hour = false;

/// The setting as kept in this device's notes ('24' for 15:00, anything
/// else for 3:00 PM). The app's root watches it, sets [use24Hour], and
/// draws everything again when it changes.
final clock24Provider = StreamProvider<bool>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.settings)..where((s) => s.key.equals(kClockFormat))).watchSingleOrNull().map((row) => row?.value == '24');
});

/// A clock time the way the user chose: "3:05 PM" or "15:05". [t] is used
/// as it stands (turn it to local time first).
String clockTime(DateTime t) => clockOf(t.hour, t.minute);

String clockOf(int hour, int minute) {
  final m = minute.toString().padLeft(2, '0');
  if (use24Hour) return '${hour.toString().padLeft(2, '0')}:$m';
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h:$m ${hour < 12 ? 'AM' : 'PM'}';
}

/// "3 PM", "3:00pm", "3:00 p.m.".
final _twelve = RegExp(r'\b(1[0-2]|0?[1-9])(?::([0-5]\d))?\s?(?:([AaPp])[Mm]\b|([AaPp])\.[Mm]\.)');

/// Only what can be nothing but a 24-hour time: "15:00", "09:30", "00:15".
/// "3:16" is left alone: it may be a score or a verse, not a time.
final _twentyFour = RegExp(r'(?<![\d:.])(0\d|1[3-9]|2[0-3]):([0-5]\d)(?![\d:])(?!\s?[AaPp]\.?[Mm])');

/// Rewrites the clock times inside a sentence someone else wrote (the
/// assistant's lines, The Lede) the way the user chose, so "by 3:00 PM"
/// reads "by 15:00" for someone who reads the clock that way, and the
/// other way round.
String timesInText(String text) {
  if (text.isEmpty) return text;
  if (use24Hour) {
    return text.replaceAllMapped(_twelve, (m) {
      var h = int.parse(m.group(1)!) % 12;
      if ((m.group(3) ?? m.group(4))!.toLowerCase() == 'p') h += 12;
      return '${h.toString().padLeft(2, '0')}:${m.group(2) ?? '00'}';
    });
  }
  return text.replaceAllMapped(_twentyFour, (m) => clockOf(int.parse(m.group(1)!), int.parse(m.group(2)!)));
}
