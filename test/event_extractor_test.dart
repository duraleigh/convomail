import 'package:convomail/domain/event_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Event extraction (spec 4.10, plan M9 acceptance): iCalendar invites and
/// explicit date-time phrases produce events; ambiguous text does not.
void main() {
  const x = EventExtractor();
  // A Tuesday.
  final ref = DateTime(2026, 10, 20, 9, 30);

  group('iCalendar', () {
    test('a VEVENT with DTSTART/DTEND, folded SUMMARY, LOCATION, and UID', () {
      const ics = 'BEGIN:VCALENDAR\r\nMETHOD:REQUEST\r\nBEGIN:VEVENT\r\nUID:abc-123@cal\r\nDTSTART;TZID=America/New_York:20261022T140000\r\nDTEND;TZID=America/New_York:20261022T150000\r\nSUMMARY:Design review\r\n  with the team\r\nLOCATION:Room 4\\, 2nd floor\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
      final events = x.fromICalendar(ics);
      expect(events, hasLength(1));
      final e = events.single;
      expect(e.title, 'Design review with the team');
      expect(e.start, DateTime(2026, 10, 22, 14, 0));
      expect(e.end, DateTime(2026, 10, 22, 15, 0));
      expect(e.location, 'Room 4, 2nd floor');
      expect(e.uid, 'abc-123@cal');
      expect(e.source, 'invite');
      expect(e.allDay, isFalse);
    });

    test('all-day, UTC, DURATION, and cancellations', () {
      final allDay = x.fromICalendar('BEGIN:VEVENT\nDTSTART;VALUE=DATE:20261101\nDTEND;VALUE=DATE:20261102\nSUMMARY:Offsite\nEND:VEVENT').single;
      expect(allDay.allDay, isTrue);
      expect(allDay.start, DateTime(2026, 11, 1));

      final utc = x.fromICalendar('BEGIN:VEVENT\nDTSTART:20261022T180000Z\nDURATION:PT30M\nSUMMARY:Standup\nEND:VEVENT').single;
      expect(utc.start, DateTime.utc(2026, 10, 22, 18).toLocal());
      expect(utc.end, DateTime.utc(2026, 10, 22, 18, 30).toLocal());

      expect(x.fromICalendar('BEGIN:VCALENDAR\nMETHOD:CANCEL\nBEGIN:VEVENT\nDTSTART:20261022T180000Z\nSUMMARY:Gone\nEND:VEVENT\nEND:VCALENDAR'), isEmpty);
      expect(x.fromICalendar('BEGIN:VEVENT\nSTATUS:CANCELLED\nDTSTART:20261022T180000Z\nSUMMARY:Gone\nEND:VEVENT'), isEmpty);
      expect(x.fromICalendar('BEGIN:VEVENT\nSUMMARY:No start\nEND:VEVENT'), isEmpty);
    });
  });

  group('text: explicit phrases produce events', () {
    test('weekday + time + appointment word', () {
      final e = x.fromText("Let's do the design review on Thursday at 2pm in Room 4.", reference: ref).single;
      expect(e.start, DateTime(2026, 10, 22, 14, 0));
      expect(e.end, DateTime(2026, 10, 22, 15, 0));
      expect(e.title, 'Review');
      expect(e.location, 'Room 4');
      expect(e.confidence, greaterThan(0.8));
    });

    test('"tomorrow", 24h clock, time ranges, noon', () {
      expect(x.fromText('Call tomorrow at 15:30 to go over the budget.', reference: ref).single.start, DateTime(2026, 10, 21, 15, 30));
      final range = x.fromText('Workshop on Friday 10-11:30am.', reference: ref).single;
      expect(range.start, DateTime(2026, 10, 23, 10, 0));
      expect(range.end, DateTime(2026, 10, 23, 11, 30));
      expect(x.fromText('Lunch with Sarah on Wednesday at noon?', reference: ref).single.title, 'Lunch with Sarah');
      expect(x.fromText('Lunch with Sarah on Wednesday at noon?', reference: ref).single.start, DateTime(2026, 10, 21, 12, 0));
    });

    test('month-name and numeric dates, "next" weekday, year rollover', () {
      expect(x.fromText('Your dentist appointment is on November 3rd at 9:15 AM.', reference: ref).single.start, DateTime(2026, 11, 3, 9, 15));
      expect(x.fromText('Interview scheduled for 11/5 at 1 PM.', reference: ref).single.start, DateTime(2026, 11, 5, 13, 0));
      expect(x.fromText('Flight departs 2026-12-01 at 6:45am.', reference: ref).single.start, DateTime(2026, 12, 1, 6, 45));
      expect(x.fromText('Standup next Tuesday at 9.', reference: ref).single.start, DateTime(2026, 10, 27, 9, 0));
      // January in a message from late December refers to next year.
      expect(x.fromText('Kickoff meeting January 6 at 10am.', reference: DateTime(2026, 12, 20)).single.start, DateTime(2027, 1, 6, 10, 0));
    });

    test('date with an appointment word but no time is an all-day event', () {
      final e = x.fromText('The conference is on Friday.', reference: ref).single;
      expect(e.allDay, isTrue);
      expect(e.start, DateTime(2026, 10, 23));
      expect(e.confidence, lessThan(0.7));
    });

    test('subject seeds the title when the sentence has no appointment word', () {
      final e = x.fromText('See you Thursday at 3pm.', reference: ref, subject: 'Re: Garage estimate').single;
      expect(e.title, 'Garage estimate');
    });
  });

  group('text: ambiguous phrasing yields nothing', () {
    test('no date, vague timing, choices, questions about availability', () {
      expect(x.fromText("Let's meet soon to discuss.", reference: ref), isEmpty);
      expect(x.fromText('Sometime next week would be great for a call.', reference: ref), isEmpty);
      expect(x.fromText('Are you free Tuesday or Wednesday?', reference: ref), isEmpty);
      expect(x.fromText('We could do 2pm or 4pm on Friday.', reference: ref), isEmpty);
      expect(x.fromText('Maybe a meeting on Friday?', reference: ref), isEmpty);
      expect(x.fromText('I sent 3 emails yesterday about the budget.', reference: ref), isEmpty);
      expect(x.fromText('Thanks for the call on Monday, it was helpful.', reference: ref), isEmpty, reason: 'past event');
      expect(x.fromText('The quarterly numbers look fine.', reference: ref), isEmpty);
      expect(x.fromText('Page 12 of 30.', reference: ref), isEmpty);
    });

    test('a bare weekday with no time and no appointment word is not an event', () {
      expect(x.fromText('I will send the draft on Friday.', reference: ref), isEmpty);
    });

    test('duplicate mentions collapse to one event', () {
      const text = 'Meeting Thursday at 2pm. Reminder: meeting Thursday at 2pm.';
      expect(x.fromText(text, reference: ref), hasLength(1));
    });
  });
}
