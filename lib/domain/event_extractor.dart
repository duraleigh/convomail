/// Rules-based event extraction (spec 4.10, plan M9). Pure Dart.
///
/// Two sources, in order of trust:
/// 1. iCalendar (`text/calendar`) parts: VEVENTs with DTSTART are events.
/// 2. Message text: a sentence that names a concrete day (or a date) and
///    either a clock time or an appointment word ("meeting", "call",
///    "lunch", …). Vague phrasing ("sometime next week", "let's meet
///    soon") yields nothing. Relative days resolve against the message's
///    own date.
library;

class ExtractedEvent {
  const ExtractedEvent({
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    this.location,
    this.source = 'text',
    this.confidence = 0.6,
    this.uid,
    this.evidence = '',
  });

  final String title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String? location;

  /// `invite` (iCalendar) or `text`.
  final String source;
  final double confidence;

  /// iCalendar UID, for de-duplicating updates to the same invite.
  final String? uid;

  /// The sentence the event came from.
  final String evidence;

  @override
  String toString() => '$title @ $start${end == null ? '' : '–$end'} ($source ${confidence.toStringAsFixed(2)})';
}

class EventExtractor {
  const EventExtractor({this.defaultDuration = const Duration(hours: 1)});
  final Duration defaultDuration;

  // ---- iCalendar ------------------------------------------------------------

  /// Parses VEVENTs out of iCalendar text. Handles folded lines, DATE and
  /// DATE-TIME values (UTC `Z` converted to local; TZID values taken as
  /// wall-clock local), DURATION, SUMMARY/LOCATION escapes, and skips
  /// cancellations (METHOD:CANCEL / STATUS:CANCELLED).
  List<ExtractedEvent> fromICalendar(String ics) {
    final unfolded = ics.replaceAll('\r\n', '\n').replaceAll(RegExp(r'\n[ \t]'), '');
    final lines = unfolded.split('\n');
    final method = _prop(lines, 'METHOD')?.toUpperCase();
    final out = <ExtractedEvent>[];
    var i = 0;
    while (i < lines.length) {
      if (lines[i].trim() == 'BEGIN:VEVENT') {
        final block = <String>[];
        i++;
        while (i < lines.length && lines[i].trim() != 'END:VEVENT') {
          block.add(lines[i]);
          i++;
        }
        final ev = _vevent(block, cancelled: method == 'CANCEL');
        if (ev != null) out.add(ev);
      }
      i++;
    }
    return out;
  }

  String? _prop(List<String> lines, String name) {
    for (final l in lines) {
      final m = RegExp('^$name(;[^:]*)?:(.*)\$', caseSensitive: false).firstMatch(l.trim());
      if (m != null) return m.group(2);
    }
    return null;
  }

  Map<String, String> _params(List<String> lines, String name) {
    for (final l in lines) {
      final m = RegExp('^$name(;([^:]*))?:', caseSensitive: false).firstMatch(l.trim());
      if (m != null) {
        final out = <String, String>{};
        for (final p in (m.group(2) ?? '').split(';')) {
          final eq = p.indexOf('=');
          if (eq > 0) out[p.substring(0, eq).toUpperCase()] = p.substring(eq + 1);
        }
        return out;
      }
    }
    return const {};
  }

  ExtractedEvent? _vevent(List<String> b, {required bool cancelled}) {
    if (cancelled || (_prop(b, 'STATUS')?.toUpperCase() == 'CANCELLED')) return null;
    final startRaw = _prop(b, 'DTSTART');
    if (startRaw == null) return null;
    final startParams = _params(b, 'DTSTART');
    final allDay = startParams['VALUE'] == 'DATE' || RegExp(r'^\d{8}$').hasMatch(startRaw.trim());
    final start = _icsDate(startRaw, allDay: allDay);
    if (start == null) return null;
    DateTime? end;
    final endRaw = _prop(b, 'DTEND');
    if (endRaw != null) {
      end = _icsDate(endRaw, allDay: _params(b, 'DTEND')['VALUE'] == 'DATE' || RegExp(r'^\d{8}$').hasMatch(endRaw.trim()));
    } else {
      final dur = _prop(b, 'DURATION');
      if (dur != null) end = start.add(_icsDuration(dur));
    }
    final summary = _unescape(_prop(b, 'SUMMARY') ?? '').trim();
    return ExtractedEvent(
      title: summary.isEmpty ? 'Invitation' : summary,
      start: start,
      end: end ?? (allDay ? null : start.add(defaultDuration)),
      allDay: allDay,
      location: _unescape(_prop(b, 'LOCATION') ?? '').trim().isEmpty ? null : _unescape(_prop(b, 'LOCATION')!).trim(),
      source: 'invite',
      confidence: 0.98,
      uid: _prop(b, 'UID')?.trim(),
      evidence: 'Calendar invitation',
    );
  }

  static String _unescape(String s) => s.replaceAll(r'\n', '\n').replaceAll(r'\,', ',').replaceAll(r'\;', ';').replaceAll(r'\\', r'\');

  static DateTime? _icsDate(String raw, {required bool allDay}) {
    final v = raw.trim();
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$').firstMatch(v);
    if (m == null) return null;
    final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
    if (allDay || m.group(4) == null) return DateTime(y, mo, d);
    final h = int.parse(m.group(4)!), mi = int.parse(m.group(5)!), s = int.parse(m.group(6) ?? '0');
    if (m.group(7) == 'Z') return DateTime.utc(y, mo, d, h, mi, s).toLocal();
    return DateTime(y, mo, d, h, mi, s);
  }

  static Duration _icsDuration(String v) {
    final m = RegExp(r'^(-)?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$').firstMatch(v.trim());
    if (m == null) return const Duration(hours: 1);
    final d = Duration(
      days: int.parse(m.group(2) ?? '0') * 7 + int.parse(m.group(3) ?? '0'),
      hours: int.parse(m.group(4) ?? '0'),
      minutes: int.parse(m.group(5) ?? '0'),
      seconds: int.parse(m.group(6) ?? '0'),
    );
    return m.group(1) == '-' ? -d : d;
  }

  // ---- free text -------------------------------------------------------------

  static const _weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  static const _months = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'];

  static final _appointmentWord = RegExp(
    r'\b(meeting|meet(?: up)?|call|zoom|teams|hangout|lunch|dinner|breakfast|brunch|coffee|appointment|interview|stand-?up|demo|review|sync|catch-?up|webinar|workshop|session|rehearsal|show|concert|game|flight|departs|boarding|check-?in|reservation|visit|tour|class|lesson|conference|kickoff|kick-off|deadline|due|presentation|ceremony|party|dentist|doctor)\b',
    caseSensitive: false,
  );
  static final _vague = RegExp(r'\b(sometime|some time|soon|eventually|whenever|at some point|one of these days|maybe|might|perhaps|possibly|if you can|would you be free|are you free|what time works|let me know when|or)\b', caseSensitive: false);
  static final _time = RegExp(r'\b(?:at\s+|@\s*)?((1[0-2]|0?[1-9])(?::([0-5]\d))?\s*(a\.?m\.?|p\.?m\.?)|([01]?\d|2[0-3]):([0-5]\d)(?!\s*(?:a|p)\.?m)|noon|midday|midnight)\b', caseSensitive: false);
  static final _atHour = RegExp(r'\b(?:at|@)\s*(1[0-2]|0?[1-9])\b(?!\s*(?:a\.?m|p\.?m|:|/|-|%))', caseSensitive: false);
  static final _timeRange = RegExp(r'\b((1[0-2]|0?[1-9])(?::([0-5]\d))?\s*(a\.?m\.?|p\.?m\.?)?)\s*(?:-|–|to|until)\s*((1[0-2]|0?[1-9])(?::([0-5]\d))?\s*(a\.?m\.?|p\.?m\.?))', caseSensitive: false);

  /// Events in [text]. [reference] is the message date (relative days are
  /// resolved against it); [subject] seeds the title when the sentence
  /// itself has no appointment word.
  List<ExtractedEvent> fromText(String text, {required DateTime reference, String subject = ''}) {
    final out = <ExtractedEvent>[];
    final seen = <String>{};
    for (final sentence in _sentences(text)) {
      if (sentence.length > 400) continue;
      final day = _findDay(sentence, reference);
      if (day == null) continue;
      if (_vague.hasMatch(sentence) && !_time.hasMatch(sentence)) continue;
      final word = _appointmentWord.firstMatch(sentence);
      final range = _timeRange.firstMatch(sentence);
      var time = _findTime(sentence);
      if (range != null) {
        // A range starts at its first time; it borrows the end's am/pm.
        final startT = _parseClock(range.group(2)!, range.group(3), range.group(4) ?? range.group(8));
        if (startT != null) time = startT;
      }
      if (time == null && word == null) continue;
      // "or" between two times/days is a choice, not an event.
      if (RegExp(r'\b(or|either)\b', caseSensitive: false).hasMatch(sentence) && (_time.allMatches(sentence).length > 1 || _dayMentions(sentence) > 1)) continue;

      DateTime start;
      DateTime? end;
      var allDay = false;
      if (time != null) {
        start = DateTime(day.year, day.month, day.day, time.$1, time.$2);
        if (range != null) {
          final endT = _parseClock(range.group(6)!, range.group(7), range.group(8));
          if (endT != null) end = DateTime(day.year, day.month, day.day, endT.$1, endT.$2);
        }
        end ??= start.add(defaultDuration);
      } else {
        start = DateTime(day.year, day.month, day.day);
        allDay = true;
      }
      // Past tense describes something that happened; a past date in a
      // current message is a reference, not a plan.
      if (_explicitPast(sentence) || start.isBefore(reference.subtract(const Duration(days: 1)))) continue;
      final title = _title(sentence, word, subject);
      final key = '$title|$start';
      if (!seen.add(key)) continue;
      out.add(ExtractedEvent(
        title: title,
        start: start,
        end: end,
        allDay: allDay,
        location: _location(sentence),
        confidence: time != null && word != null ? 0.85 : (time != null ? 0.7 : 0.55),
        evidence: sentence.trim(),
      ));
    }
    return out;
  }

  static Iterable<String> _sentences(String text) sync* {
    final clean = text.replaceAll(RegExp(r'\r'), '').replaceAll(RegExp(r'[ \t]+'), ' ');
    for (final para in clean.split(RegExp(r'\n{2,}'))) {
      for (final s in para.split(RegExp(r'(?<=[.!?])\s+|\n'))) {
        final t = s.trim();
        if (t.isNotEmpty) yield t;
      }
    }
  }

  static bool _explicitPast(String s) => RegExp(r'\b(was|were|happened|yesterday|last (week|month|year))\b', caseSensitive: false).hasMatch(s);

  int _dayMentions(String s) {
    var n = 0;
    final lower = s.toLowerCase();
    for (final w in _weekdays) {
      if (RegExp('\\b$w\\b').hasMatch(lower)) n++;
    }
    if (RegExp(r'\btomorrow\b').hasMatch(lower)) n++;
    if (RegExp(r'\btoday\b').hasMatch(lower)) n++;
    return n;
  }

  /// The calendar day a sentence refers to, or null.
  DateTime? _findDay(String s, DateTime ref) {
    final lower = s.toLowerCase();
    final today = DateTime(ref.year, ref.month, ref.day);
    if (RegExp(r'\btoday\b').hasMatch(lower) || RegExp(r'\btonight\b').hasMatch(lower)) return today;
    if (RegExp(r'\btomorrow\b').hasMatch(lower)) return today.add(const Duration(days: 1));
    if (RegExp(r'\bday after tomorrow\b').hasMatch(lower)) return today.add(const Duration(days: 2));

    // ISO / numeric dates: 2026-03-05, 3/5, 3/5/26, 03/05/2026
    final iso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').firstMatch(lower);
    if (iso != null) return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
    final num = RegExp(r'\b(1[0-2]|0?[1-9])/([12]\d|3[01]|0?[1-9])(?:/(\d{2}|\d{4}))?\b').firstMatch(lower);
    if (num != null) {
      final y = num.group(3) == null ? ref.year : (num.group(3)!.length == 2 ? 2000 + int.parse(num.group(3)!) : int.parse(num.group(3)!));
      final d = DateTime(y, int.parse(num.group(1)!), int.parse(num.group(2)!));
      return num.group(3) == null && d.isBefore(today.subtract(const Duration(days: 30))) ? DateTime(y + 1, d.month, d.day) : d;
    }

    // Month names: March 5, March 5th, 5 March, Mar 5, 2026
    final monthRe = RegExp(r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?\b');
    final mm = monthRe.firstMatch(lower);
    final dayFirst = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?(?:,?\s+(\d{4}))?\b').firstMatch(lower);
    if (mm != null || dayFirst != null) {
      final monthTok = (mm?.group(1) ?? dayFirst!.group(2))!;
      final dayNum = int.parse((mm?.group(2) ?? dayFirst!.group(1))!);
      final year = mm?.group(3) ?? dayFirst?.group(3);
      final month = _months.indexWhere((m) => m.startsWith(monthTok.substring(0, 3))) + 1;
      if (month > 0 && dayNum >= 1 && dayNum <= 31) {
        var d = DateTime(year == null ? ref.year : int.parse(year), month, dayNum);
        if (year == null && d.isBefore(today.subtract(const Duration(days: 30)))) d = DateTime(ref.year + 1, month, dayNum);
        return d;
      }
    }

    // Weekdays: "on Friday", "this Friday", "next Monday", "Fri"
    for (var i = 0; i < _weekdays.length; i++) {
      final w = _weekdays[i];
      final re = RegExp('\\b(next|this|on|coming)?\\s*(${w.substring(0, 3)}(?:${w.substring(3)})?)\\b');
      final m = re.firstMatch(lower);
      if (m == null) continue;
      // Avoid matching "sun"/"sat"/"mon" inside other words via \\b and the
      // short form only when a qualifier precedes it or it is capitalized.
      final short = m.group(2)!.length == 3;
      if (short && m.group(1) == null && !RegExp('\\b${w.substring(0, 3)}\\b').hasMatch(s)) continue;
      if (short && m.group(1) == null && !RegExp('\\b[A-Z]${w.substring(1, 3)}\\b').hasMatch(s)) continue;
      final target = i + 1; // DateTime weekday: Monday = 1
      var delta = (target - ref.weekday) % 7;
      if (m.group(1) == 'next') {
        delta = delta == 0 ? 7 : delta + 7;
      } else if (delta == 0) {
        delta = m.group(1) == 'this' || m.group(1) == 'on' || m.group(1) == 'coming' ? 7 : 0;
      }
      return today.add(Duration(days: delta));
    }
    return null;
  }

  (int, int)? _findTime(String s) {
    final m = _time.firstMatch(s);
    if (m == null) {
      final h = _atHour.firstMatch(s);
      return h == null ? null : _parseClock(h.group(1)!, null, null);
    }
    final whole = m.group(1)!.toLowerCase();
    if (whole == 'noon' || whole == 'midday') return (12, 0);
    if (whole == 'midnight') return (0, 0);
    if (m.group(2) != null) return _parseClock(m.group(2)!, m.group(3), m.group(4));
    final h = int.parse(m.group(5)!);
    final mi = int.parse(m.group(6)!);
    return (h, mi);
  }

  static (int, int)? _parseClock(String hourStr, String? minuteStr, String? ampm) {
    var h = int.parse(hourStr);
    final mi = int.parse(minuteStr ?? '0');
    if (h > 23 || mi > 59) return null;
    if (ampm != null) {
      final p = ampm.toLowerCase().startsWith('p');
      if (p && h < 12) h += 12;
      if (!p && h == 12) h = 0;
    } else if (h < 7 && minuteStr == null) {
      // "at 3" without am/pm: assume afternoon for small hours.
      h += 12;
    }
    return (h, mi);
  }

  String _title(String sentence, RegExpMatch? word, String subject) {
    if (word != null) {
      final w = word.group(0)!;
      // "lunch with Sarah", "call with the team", "demo for Acme"
      // Case-sensitive on purpose: the name must be capitalized words
      // ("with Sarah", "for Acme Corp"), so "on Wednesday" is not swept in.
      final withRe = RegExp('${RegExp.escape(w)}\\s+(?:with|for|at|about)\\s+([A-Z][\\w.&\'-]*(?:\\s+[A-Z][\\w.&\'-]*){0,3}|the\\s+[a-z]+(?:\\s+[a-z]+)?)');
      final m = withRe.firstMatch(sentence);
      final base = w[0].toUpperCase() + w.substring(1).toLowerCase();
      if (m != null) return '$base ${sentence.substring(m.start + w.length, m.end).trim()}';
      return base;
    }
    final subj = subject.replaceFirst(RegExp(r'^(re|fwd?|fw):\s*', caseSensitive: false), '').trim();
    return subj.isEmpty ? 'Event' : subj;
  }

  String? _location(String sentence) {
    final m = RegExp(r"\b(?:at|in)\s+(the\s+)?([A-Z][\w'&.-]*(?:\s+(?:[A-Z][\w'&.-]*|\d+[A-Za-z]*|St\.?|Ave\.?|Rd\.?))*)(?=[\s,.;!?]|$)").firstMatch(sentence);
    if (m == null) return null;
    final loc = m.group(2)!.trim();
    // Reject weekday / month names and times caught as "at X".
    final lower = loc.toLowerCase();
    if (_weekdays.any((w) => lower.startsWith(w.substring(0, 3))) || _months.any((mo) => lower.startsWith(mo.substring(0, 3)))) return null;
    if (loc.length < 3) return null;
    return loc;
  }
}
