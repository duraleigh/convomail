import 'package:convomail/app/time_format.dart';
import 'package:convomail/ui/screens/chats/later_dialogs.dart';
import 'package:convomail/ui/screens/chats/people_list_pane.dart' show relativeTime;
import 'package:convomail/ui/widgets/reading_line.dart';
import 'package:flutter_test/flutter_test.dart';

/// The clock setting: every time is written one way or the other.
void main() {
  tearDown(() => use24Hour = false);

  test('a time is written 3:05 PM, or 15:05 when the 24-hour clock is chosen', () {
    expect(clockOf(15, 5), '3:05 PM');
    expect(clockOf(0, 0), '12:00 AM');
    expect(clockOf(12, 30), '12:30 PM');
    expect(clockTime(DateTime(2026, 11, 12, 9, 7)), '9:07 AM');
    use24Hour = true;
    expect(clockOf(15, 5), '15:05');
    expect(clockOf(0, 0), '00:00');
    expect(clockOf(9, 7), '09:07');
  });

  test('times inside the assistant\'s sentences are rewritten for the 24-hour clock', () {
    use24Hour = true;
    expect(timesInText('Reply by 3:00 PM today.'), 'Reply by 15:00 today.');
    expect(timesInText('The call is at 9am, then lunch at 12 p.m.'), 'The call is at 09:00, then lunch at 12:00');
    expect(timesInText('Starts 12:15 AM and ends 11:45 pm.'), 'Starts 00:15 and ends 23:45.');
    expect(timesInText('Zoom from 2 PM to 3:30 PM (ET).'), 'Zoom from 14:00 to 15:30 (ET).');
    // Left alone: not times.
    expect(timesInText('I am sending 3 amps and 5 pmol.'), 'I am sending 3 amps and 5 pmol.');
    expect(timesInText('Order 1040 arrives March 14.'), 'Order 1040 arrives March 14.');
    expect(timesInText('It is already 15:00.'), 'It is already 15:00.');
  });

  test('and a 24-hour time is rewritten for the 12-hour clock; what may not be a time is left alone', () {
    expect(timesInText('Doors open at 19:30.'), 'Doors open at 7:30 PM.');
    expect(timesInText('Check-in from 09:00 to 00:15.'), 'Check-in from 9:00 AM to 12:15 AM.');
    expect(timesInText('See John 3:16, the score was 2:15.'), 'See John 3:16, the score was 2:15.');
    expect(timesInText('Reply by 3:00 PM today.'), 'Reply by 3:00 PM today.');
    expect(timesInText('It took 1:13:45 and cost 13:1.'), 'It took 1:13:45 and cost 13:1.');
  });

  test('the same setting reaches every list and label', () {
    final now = DateTime(2026, 11, 12, 10);
    final t = DateTime(2026, 11, 12, 15, 5);
    expect(relativeTime(t, now: now), '3:05 PM');
    expect(dueLabel(t, now: now), '3:05 PM');
    expect(dueLabel(DateTime(2026, 11, 13, 8), now: now), 'tomorrow 8:00 AM');
    use24Hour = true;
    expect(relativeTime(t, now: now), '15:05');
    expect(dueLabel(t, now: now), '15:05');
    expect(dueLabel(DateTime(2026, 11, 13, 8), now: now), 'tomorrow 08:00');
    final far = DateTime.now().add(const Duration(days: 20));
    expect(describeSnooze(DateTime(far.year, far.month, far.day, 17, 30)), endsWith(', 17:30'));
  });
}
