import 'package:convomail/domain/threading.dart';
import 'package:flutter_test/flutter_test.dart';

ThreadInput m(int id, {String? mid, String? irt, List<String> refs = const [], String subject = '', Set<String> who = const {'me', 'a'}, int day = 0, int account = 1, String? pid}) => ThreadInput(
      id: id,
      accountId: account,
      ts: DateTime(2026, 9, 1).add(Duration(days: day)),
      participantKeys: who,
      messageId: mid,
      inReplyTo: irt,
      references: refs,
      subject: subject,
      providerThreadId: pid,
    );

void main() {
  final builder = ThreadBuilder();

  group('normalizeSubject', () {
    test('strips repeated reply/forward prefixes in several languages', () {
      expect(normalizeSubject('Re: RE: Fwd: AW: WG: Budget'), (normalized: 'budget', hadPrefix: true));
      expect(normalizeSubject('Re[2]: Budget'), (normalized: 'budget', hadPrefix: true));
      expect(normalizeSubject('Budget   plan'), (normalized: 'budget plan', hadPrefix: false));
      expect(normalizeSubject('Reminder: budget'), (normalized: 'reminder: budget', hadPrefix: false), reason: 'only real prefixes count');
    });
  });

  group('ThreadBuilder (spec 4.20)', () {
    test('headers link a reply chain into one thread keyed by the root Message-ID', () {
      final r = builder.build([
        m(1, mid: '<a@x>', subject: 'Plan'),
        m(2, mid: '<b@x>', irt: '<a@x>', subject: 'Re: Plan', day: 1),
        m(3, mid: '<c@x>', irt: '<b@x>', refs: ['<a@x>', '<b@x>'], subject: 'Re: Plan', day: 2),
        m(4, mid: '<d@x>', subject: 'Unrelated', day: 2),
      ]);
      expect(r.threadKeyByMessage[1], '<a@x>');
      expect(r.threadKeyByMessage[2], '<a@x>');
      expect(r.threadKeyByMessage[3], '<a@x>');
      expect(r.threadKeyByMessage[4], '<d@x>');
    });

    test('a reply that drops a participant stays in the thread', () {
      final r = builder.build([
        m(1, mid: '<a@x>', subject: 'Plan', who: {'me', 'simon', 'joann'}),
        m(2, mid: '<b@x>', irt: '<a@x>', subject: 'Re: Plan', who: {'me', 'sarah'}, day: 1),
      ]);
      expect(r.threadKeyByMessage[2], '<a@x>');
    });

    test('a subject change mid-thread does not split it when headers are present', () {
      final r = builder.build([
        m(1, mid: '<a@x>', subject: 'Plan'),
        m(2, mid: '<b@x>', irt: '<a@x>', subject: 'Totally different', day: 1),
      ]);
      expect(r.threadKeyByMessage[2], '<a@x>');
    });

    test('threads span accounts via Message-ID', () {
      final r = builder.build([
        m(1, mid: '<a@x>', subject: 'Plan', account: 1),
        m(2, mid: '<b@x>', irt: '<a@x>', subject: 'Re: Plan', account: 2, day: 1),
      ]);
      expect(r.threadKeyByMessage[2], '<a@x>');
    });

    test('a forward without headers starts a new thread', () {
      final r = builder.build([
        m(1, mid: '<a@x>', subject: 'Plan', who: {'me', 'a'}),
        m(2, mid: '<f@x>', subject: 'Fwd: Plan', who: {'me', 'zed'}, day: 1),
      ]);
      expect(r.threadKeyByMessage[2], '<f@x>', reason: 'no participant overlap besides me... zed is new, a is missing');
    });

    test('subject fallback joins a header-less reply with a shared participant inside the window', () {
      final r = builder.build([
        m(1, mid: '<a@x>', subject: 'Plan', who: {'me', 'a'}),
        m(2, mid: '<b@x>', subject: 'RE: Plan', who: {'me', 'a'}, day: 3),
      ]);
      expect(r.threadKeyByMessage[2], '<a@x>');
    });

    test('subject fallback refuses beyond 30 days', () {
      final r = builder.build([
        m(1, mid: '<a@x>', subject: 'Plan', who: {'me', 'a'}),
        m(2, mid: '<b@x>', subject: 'Re: Plan', who: {'me', 'a'}, day: 45),
      ]);
      expect(r.threadKeyByMessage[2], '<b@x>');
    });

    test('recurring identical subjects without a reply prefix never merge', () {
      final r = builder.build([
        m(1, mid: '<w1@x>', subject: 'Weekly Update', who: {'me', 'news'}),
        m(2, mid: '<w2@x>', subject: 'Weekly Update', who: {'me', 'news'}, day: 7),
        m(3, mid: '<w3@x>', subject: 'Weekly Update', who: {'me', 'news'}, day: 14),
      ]);
      expect(r.messagesByThread.length, 3);
    });

    test('subject fallback is never applied to a message that has reply headers', () {
      final r = builder.build([
        m(1, mid: '<a@x>', subject: 'Plan', who: {'me', 'a'}),
        m(2, mid: '<b@x>', irt: '<missing@x>', subject: 'Re: Plan', who: {'me', 'a'}, day: 1),
      ]);
      expect(r.threadKeyByMessage[2], '<b@x>', reason: 'its parent is unknown; do not guess by subject');
    });

    test('provider thread id joins messages within one account only', () {
      final r = builder.build([
        m(1, mid: '<a@x>', subject: 'A', pid: 'T1', account: 1),
        m(2, mid: '<b@x>', subject: 'B', pid: 'T1', account: 1, day: 1),
        m(3, mid: '<c@x>', subject: 'C', pid: 'T1', account: 2, day: 1),
      ]);
      expect(r.threadKeyByMessage[2], '<a@x>');
      expect(r.threadKeyByMessage[3], '<c@x>');
    });

    test('incremental assignment adopts existing keys and reports merges', () {
      final existing = [m(1, mid: '<a@x>', subject: 'Plan'), m(2, mid: '<z@x>', subject: 'Other', day: 1)];
      final existingKeys = {1: '<a@x>', 2: '<z@x>'};
      // A late-arriving message replies to both: merges the threads.
      final incoming = [m(3, mid: '<c@x>', irt: '<z@x>', refs: ['<a@x>', '<z@x>'], subject: 'Re: Plan', day: 2)];
      final out = builder.assignIncremental(existing, existingKeys, incoming);
      expect(out[3], '<a@x>');
      expect(out[2], '<a@x>', reason: 'the Other thread merged into Plan');
      expect(out.containsKey(1), isFalse, reason: 'unchanged keys are not reported');
    });

    test('messages without Message-ID get a stable m:<id> key', () {
      final r = builder.build([m(7, subject: 'No id')]);
      expect(r.threadKeyByMessage[7], 'm:7');
    });
  });
}
