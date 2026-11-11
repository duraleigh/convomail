import 'dart:convert';
import 'dart:io';

import 'package:convomail/domain/classifier.dart';
import 'package:convomail/domain/identity.dart';
import 'package:convomail/domain/piles.dart';
import 'package:flutter_test/flutter_test.dart';

/// The helper sorts mail with its own copy of these rules (helper/src). This
/// file writes a few thousand worked examples with the app's answers, and
/// the helper's own checks must give the same answer for every one.
///
/// When the rules change on purpose, write the examples again:
///
///     PRECIS_WRITE_GOLDEN=1 flutter test test/helper_golden_test.dart
///     python tool/gen_helper_classifier_data.py
///
/// and then make the helper's checks pass (php helper/tests/run.php).
const goldenPath = 'helper/tests/golden/classifier.json';

/// A small fixed number source, so the examples are the same on every run
/// and every version of the tools.
class _Rng {
  _Rng(this._s);
  int _s;
  int next(int n) {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return (_s >> 8) % n;
  }

  bool chance(int outOf) => next(outOf) == 0;
  T pick<T>(List<T> from) => from[next(from.length)];
}

const _locals = [
  'noreply', 'no-reply', 'do-not-reply', 'notifications', 'notify', 'billing', 'team', 'orders', 'newsletter', 'info', 'hello', 'support', 'sales', 'john.smith',
  'mary', 'j.doe+tag', 'bounce+abc123=x', 'prvs=1234abcd=user', 'reply-9f8a7b6c5d4e3f2a1b0c9d8e', 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4', '12345abcdefghijklmnop',
  'shipment-tracking', 'receipts', 'weekly-digest', 'marketing', 'promo', 'security', 'account', 'josé', 'clay', 'x', 'JOHN', 'customer-care', 'user+12345678x',
  'alerts', 'offers', 'statement', 'payment', 'daily', 'srs0=ab=cd', 'msprvs1=1234', 'help', 'office', 'verify', 'password-reset', 'deals', 'a-very-long-automated-name-noreply',
];
const _domains = [
  'gmail.com', 'googlemail.com', 'example.com', 'brand.com', 'e.brand.com', 'email.brand.co.uk', 'mail.brand.com', 'tr.shop.com', 'service.bank.com',
  'bounces.mailer.org', 'mta3.host.net', 'mailchimp.com', 'us5.mcsv.net', 'linkedin.com', 'facebookmail.com', 'delta.com', 't.delta.com', 'ups.com',
  'amazon.com', 'substack.com', 'company.org', 'zendesk.com', 'sub.zendesk.com', 'x.com', 'accounts.google.com', 'notice.example.org', 'Example.COM',
  'smtp.out.vendor.io', 'go.vendor.io', 'm.friend.net', 'news.paper.com', 'booking.com', 'marriott.com', 'fedex.com', 'care.clinic.org', 'crm.agency.co',
];
const _names = [
  '', 'John Smith', 'Acme Team', 'The Acme Team', 'Customer Service', 'Delta Air Lines', 'Newsletter', 'Rewards', 'Sarah', 'Support', 'Do Not Reply',
  'Billing Dept', 'José Núñez', 'Help Desk', 'Member Services', 'Mark at Vendorco', 'no-reply', 'The Daily News', 'Orders', 'Team',
];
const _subjects = [
  'Your order has shipped', 'Receipt for your payment', 'Your verification code is 123456', 'Your promo code is SAVE20', '20% off everything', 'Weekly digest',
  'Re: lunch tomorrow', 'Fwd: plans', 'Lunch?', 'Your flight confirmation', 'Check-in is now open', 'Your statement is ready', 'John mentioned you in a comment',
  'New follower', 'Security alert', 'Your payout is on the way', 'Don’t miss our sale', 'What’s new this week', 'Invoice 1234', 'Quick question',
  'Meeting notes', 'Issue #12 is out', 'Sign-in from a new device', 'Your package was delivered', 'Itinerary for your trip', 'Reminder: appointment tomorrow',
  'Top stories today', 'Happy birthday!', 'Out for delivery', 'Tracking number for order', 'Limited time offer', 'Your bill is ready', 'Password reset', '',
  'RE : Hello', 'TR: Bonjour', 'Your Acme code is 4821', 'Booking confirmation', 'Your reservation', 'Free shipping today', 'Your refund', 'New login to your account',
  'Wants to connect', 'Order #5512 received', 'A gift for you', 'Rewards points update', 'This week in tech', 'In case you missed it', 'Build failed',
  'Your trip to Denver', 'Seat upgrade available', 'Car rental receipt', 'Delivery attempt', 'Your transfer is on the way', 'Magic link', 'Your subscription renewal',
  'Hello', 'Thanks!', 'Contract draft v2', 'Photos from Saturday', 'OTP 882211', 'Your one-time passcode', ' Re: spaced', 'Sale ends tonight', 'Black Friday deals',
];
const _snippets = [
  'Hi Clay, thanks for the note', 'Hello clay', 'Dear Clay’s team', '  Hey Clay-Anne how are you', 'Good morning Clay', 'Hi there', 'hi clay', '',
  'Hello Bob', 'Dear CLAY,', 'hey', 'Good evening  clay!', 'Clay, your order', 'Hi Clayton', "hi clay's friends",
];
const _providers = ['primary', 'updates', 'promotions', 'social', 'forums'];
const _categories = [FeedsCategories.newsletter, FeedsCategories.receipt, FeedsCategories.notification, FeedsCategories.social, FeedsCategories.promotion, FeedsCategories.updates, 'Delivery', 'Travel', 'OTP', 'Mine'];

String _address(_Rng r) => '${r.pick(_locals)}@${r.pick(_domains)}';

List<ClassificationRule> _rules(_Rng r) {
  if (!r.chance(4)) return const [];
  final out = <ClassificationRule>[];
  final n = 1 + r.next(2);
  for (var i = 0; i < n; i++) {
    final field = r.pick(const ['sender', 'domain', 'listId', 'subject']);
    final pattern = switch (field) {
      'sender' => _address(r),
      'domain' => r.pick(_domains),
      'listId' => r.pick(const ['list.brand.com', 'news.paper.com', 'brief.dailybrief.com']),
      _ => r.pick(const ['order | invoice', 'code', 'Digest', 'flight|trip |', 'lunch']),
    };
    final bucket = field == 'subject' && !r.chance(3) ? null : (r.chance(2) ? Bucket.feeds : Bucket.people);
    final category = r.chance(2) ? r.pick(_categories) : null;
    if (bucket == null && category == null) continue;
    out.add(ClassificationRule(field: field, pattern: pattern, bucket: bucket, category: category));
  }
  return out;
}

Map<String, Object?> _ruleJson(ClassificationRule r) => {'field': r.field, 'pattern': r.pattern, 'bucket': r.bucket?.name, 'category': r.category, 'describe': r.describe()};

String _signals(_Rng r) {
  if (r.chance(2)) return '';
  return BulkSignals(
    listUnsubscribe: r.chance(2),
    listId: r.chance(3),
    listPost: r.chance(5),
    feedbackId: r.chance(5),
    precedenceBulk: r.chance(5),
    autoSubmitted: r.chance(6),
    listIdValue: r.chance(3) ? r.pick(const ['list.brand.com', 'news.paper.com', 'brief.dailybrief.com', 'a;b.example']) : null,
  ).encode();
}

Map<String, Object?> buildGolden() {
  final r = _Rng(20261111);
  const names = {'clay'};

  final senders = <Map<String, Object?>>[];
  for (var i = 0; i < 2500; i++) {
    final rules = _rules(r);
    final received = r.chance(6) ? 0 : 1 + r.next(12);
    final sentTo = r.chance(3) ? 1 + r.next(5) : 0;
    final known = received == 0 ? 0 : r.next(received + 1);
    final bulk = known == 0 ? 0 : (r.chance(2) ? 0 : r.next(known + 1));
    final provider = <String, int>{};
    if (r.chance(2)) {
      for (final p in _providers) {
        if (r.chance(3)) provider[p] = 1 + r.next(6);
      }
    }
    final subjects = [for (var k = r.next(7); k > 0; k--) r.pick(_subjects)];
    final address = _address(r);
    final facts = SenderFacts(
      address: address,
      otherAddresses: [if (r.chance(8)) _address(r)],
      messagesReceived: received,
      messagesSentTo: sentTo,
      repliesToAutomated: sentTo == 0 ? 0 : r.next(sentTo + 1),
      recipientNames: [if (r.chance(5)) r.pick(_names), if (r.chance(12)) r.pick(_names)].where((n) => n.isNotEmpty).toList(),
      messagesWithTimely: r.chance(9) ? 1 + r.next(3) : 0,
      name: r.pick(_names),
      userHasWrittenTo: sentTo > 0 || r.chance(10),
      inAddressBook: r.chance(12),
      messagesWithBulkHeaders: bulk,
      messagesWithKnownSignals: known,
      listIds: {if (r.chance(6)) r.pick(const ['list.brand.com', 'news.paper.com'])},
      override: r.chance(25) ? (r.chance(2) ? Bucket.feeds : Bucket.people) : null,
      providerCategories: provider,
      subjects: subjects,
    );
    final d = Classifier(rules: rules, userFirstNames: names).classifySender(facts);
    senders.add({
      'rules': rules.map(_ruleJson).toList(),
      'facts': {
        'address': facts.address,
        'otherAddresses': facts.otherAddresses,
        'messagesReceived': facts.messagesReceived,
        'messagesSentTo': facts.messagesSentTo,
        'repliesToAutomated': facts.repliesToAutomated,
        'recipientNames': facts.recipientNames,
        'messagesWithTimely': facts.messagesWithTimely,
        'name': facts.name,
        'userHasWrittenTo': facts.userHasWrittenTo,
        'inAddressBook': facts.inAddressBook,
        'messagesWithBulkHeaders': facts.messagesWithBulkHeaders,
        'messagesWithKnownSignals': facts.messagesWithKnownSignals,
        'listIds': facts.listIds.toList(),
        'override': facts.override?.name,
        'providerCategories': facts.providerCategories,
        'subjects': facts.subjects,
      },
      'want': {'bucket': d.bucket.name, 'category': d.category, 'reasons': d.reasons, 'source': d.source},
    });
  }

  final messages = <Map<String, Object?>>[];
  for (var i = 0; i < 2500; i++) {
    final rules = _rules(r);
    final signals = _signals(r);
    final from = _address(r);
    final subject = r.pick(_subjects);
    final snippet = r.pick(_snippets);
    final provider = r.chance(2) ? r.pick(_providers) : (r.chance(4) ? '' : null);
    final facts = MessageFacts(
      from: from,
      fromName: r.pick(_names),
      subject: subject,
      snippet: snippet,
      signals: BulkSignals.decode(signals),
      isReplyToMine: r.chance(15),
      providerCategory: provider,
      hasTimelyItem: r.chance(12),
    );
    final senderDefault = r.chance(2) ? r.pick(_categories) : null;
    final c = Classifier(rules: rules, userFirstNames: names);
    messages.add({
      'rules': rules.map(_ruleJson).toList(),
      'facts': {
        'from': from,
        'fromName': facts.fromName,
        'subject': subject,
        'snippet': snippet,
        'signals': signals,
        'isReplyToMine': facts.isReplyToMine,
        'providerCategory': provider,
        'hasTimelyItem': facts.hasTimelyItem,
      },
      'senderDefault': senderDefault,
      'want': {
        'exception': c.isPersonalException(facts),
        'greets': c.greetsUserByName(snippet),
        'category': c.messageCategory(facts, senderDefault: senderDefault),
        'inferred': c.inferCategory(facts),
        'specific': Classifier.specificCategory(subject, from),
        'matches': [for (final rule in rules) rule.matchesMessage(facts)],
      },
    });
  }

  final piles = <Map<String, Object?>>[];
  for (var i = 0; i < 600; i++) {
    final chosen = r.chance(8) ? r.pick(const ['feed', 'noise', 'other']) : null;
    final category = r.chance(4) ? null : r.pick(_categories);
    final total = r.next(12);
    final unread = total == 0 ? 0 : r.next(total + 1);
    Map<String?, MailCount>? mail;
    if (r.chance(2)) {
      mail = {};
      for (var k = r.next(4); k > 0; k--) {
        final t = r.next(10);
        mail[r.chance(6) ? null : r.pick(_categories)] = (total: t, unread: t == 0 ? 0 : r.next(t + 1));
      }
    }
    piles.add({
      'chosen': chosen,
      'category': category,
      'total': total,
      'unread': unread,
      'mail': mail == null ? null : {for (final e in mail.entries) e.key ?? '': {'total': e.value.total, 'unread': e.value.unread}},
      'want': pileFor(chosen: chosen, category: category, total: total, unread: unread, mail: mail).name,
    });
  }

  final addresses = <Map<String, Object?>>[];
  for (final raw in [
    for (var i = 0; i < 300; i++) _address(r),
    ' <John.Smith+news@GoogleMail.com> ', 'A.B.C@gmail.com', '+tag@gmail.com', 'no-at-sign', '@nolocal.com', 'x@y@z.com', '<plain@x.com>', 'JOSÉ@Example.com', ' padded@x.com ',
  ]) {
    addresses.add({'raw': raw, 'want': normalizeAddress(raw)});
  }

  final machine = <Map<String, Object?>>[];
  for (var i = 0; i < 600; i++) {
    final a = _address(r);
    machine.add({'address': a, 'want': Classifier.machineAddressReason(a), 'listed': Classifier.isListedSendingDomain(a.substring(a.indexOf('@') + 1)), 'sub': Classifier.isSendingSubdomain(a.substring(a.indexOf('@') + 1))});
  }

  final headers = <Map<String, Object?>>[];
  const values = [null, '', ' ', '<mailto:u@x.com>', 'Brand News <list.Brand.com>', 'list.brand.com', 'bulk', ' List ', 'junk', 'no', 'auto-generated', 'NO', 'first'];
  for (var i = 0; i < 300; i++) {
    final h = {
      'listUnsubscribe': r.pick(values),
      'listId': r.pick(values),
      'listPost': r.pick(values),
      'feedbackId': r.pick(values),
      'precedence': r.pick(values),
      'autoSubmitted': r.pick(values),
    };
    final s = BulkSignals.fromHeaders(listUnsubscribe: h['listUnsubscribe'], listId: h['listId'], listPost: h['listPost'], feedbackId: h['feedbackId'], precedence: h['precedence'], autoSubmitted: h['autoSubmitted']);
    headers.add({'h': h, 'want': s.encode(), 'any': s.any, 'again': BulkSignals.decode(s.encode()).encode()});
  }

  final profiles = <Map<String, Object?>>[];
  for (var i = 0; i < 400; i++) {
    final subjects = [for (var k = r.next(9); k > 0; k--) r.pick(_subjects)];
    final (cat, share) = Classifier.subjectProfile(subjects);
    profiles.add({'subjects': subjects, 'cat': cat, 'share': share});
  }

  return {
    'version': 1,
    'names': names.toList(),
    'senders': senders,
    'messages': messages,
    'piles': piles,
    'addresses': addresses,
    'machine': machine,
    'headers': headers,
    'profiles': profiles,
  };
}

void main() {
  test('the worked examples the helper is checked against are up to date', () {
    final fresh = jsonEncode(buildGolden());
    final file = File(goldenPath);
    if (Platform.environment['PRECIS_WRITE_GOLDEN'] == '1') {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('$fresh\n');
    }
    expect(file.existsSync(), isTrue, reason: 'write them first: PRECIS_WRITE_GOLDEN=1 flutter test test/helper_golden_test.dart');
    expect(
      file.readAsStringSync().replaceAll('\r\n', '\n').trimRight() == fresh,
      isTrue,
      reason: 'The sorting rules changed. Write the examples again (PRECIS_WRITE_GOLDEN=1 flutter test test/helper_golden_test.dart), '
          'run python tool/gen_helper_classifier_data.py, and make the helper agree (php helper/tests/run.php).',
    );
  });

  test('the examples cover both answers and every tag', () {
    final g = buildGolden();
    final senders = (g['senders']! as List).cast<Map<String, Object?>>();
    final buckets = {for (final s in senders) (s['want']! as Map)['bucket']};
    expect(buckets, {'people', 'feeds'});
    final sources = {for (final s in senders) (s['want']! as Map)['source']};
    expect(sources, containsAll(['auto', 'override', 'rule', 'people-signal']));
    final cats = {for (final m in (g['messages']! as List).cast<Map<String, Object?>>()) (m['want']! as Map)['inferred']};
    expect(cats, containsAll([...FeedsCategories.defaults.where((c) => c != FeedsCategories.updates), null]));
    final piles = {for (final p in (g['piles']! as List).cast<Map<String, Object?>>()) p['want']};
    expect(piles, {'feed', 'noise'});
  });
}
