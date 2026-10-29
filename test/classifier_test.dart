import 'dart:math';

import 'package:convomail/domain/classifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rules classifier (spec 4.11) on a generated, labeled corpus of 2,000
/// messages: at least 95% of bulk mail must land in Feeds and no
/// human-to-human reply may (plan M8 acceptance), plus unit cases for the
/// signal order, exceptions, categories, and rule proposals.
void main() {
  const classifier = Classifier(userFirstNames: {'clay'});

  group('corpus', () {
    test('2,000 labeled messages: >= 95% of bulk in Feeds, zero human replies in Feeds', () {
      final rng = Random(7);
      final senders = <SenderFacts>[];
      final labels = <bool>[]; // true = bulk
      final messages = <MessageFacts>[];

      // 1,200 bulk senders across the real-world shapes.
      const espDomains = ['mail.shop-example.com', 'em.brand.com', 'news.dailypaper.com', 'list-manage.com', 'sendgrid.net', 'amazonses.com', 'facebookmail.com', 'linkedin.com', 'github.com', 'substack.com'];
      const bulkLocals = ['noreply', 'no-reply', 'notifications', 'newsletter', 'alerts', 'donotreply', 'updates', 'digest', 'orders', 'billing'];
      const plainLocals = ['hello', 'info', 'team', 'news', 'editor', 'support', 'community', 'deals', 'press', 'contact'];
      for (var i = 0; i < 1200; i++) {
        final shape = i % 9;
        late SenderFacts s;
        var signals = BulkSignals.none;
        switch (shape) {
          case 0: // newsletter with full list headers on an ordinary domain
            signals = BulkSignals(listUnsubscribe: true, listId: true, listIdValue: 'weekly.brand$i.com');
            s = SenderFacts(address: '${plainLocals[i % plainLocals.length]}@brand$i.com', messagesWithBulkHeaders: 4, messagesWithKnownSignals: 4, listIds: {'weekly.brand$i.com'});
          case 1: // noreply with no headers at all
            s = SenderFacts(address: '${bulkLocals[i % bulkLocals.length]}@service$i.io', messagesWithKnownSignals: 2);
          case 2: // ESP / platform domain, human-looking local part, no headers
            s = SenderFacts(address: 'jessica@${espDomains[i % espDomains.length]}', name: 'Jessica from Brand', messagesWithKnownSignals: 1);
          case 3: // precedence bulk on half the messages
            signals = const BulkSignals(precedenceBulk: true);
            s = SenderFacts(address: 'promo$i@store$i.com', messagesWithBulkHeaders: 2, messagesWithKnownSignals: 4);
          case 4: // auto-submitted system mail
            signals = const BulkSignals(autoSubmitted: true);
            s = SenderFacts(address: 'system@corp$i.net', messagesWithBulkHeaders: 1, messagesWithKnownSignals: 1);
          case 6: // no headers at all, sent from a dedicated sending subdomain
            s = SenderFacts(address: 'jessica@e.brand$i.com', name: 'Brand $i', messagesWithKnownSignals: 2);
          case 7: // no headers, ordinary-looking address, receipt subjects
            s = SenderFacts(
              address: 'jessica$i@shopco$i.com',
              name: 'Shop Co',
              messagesWithKnownSignals: 3,
              subjects: const ['Your order #4411 has shipped', 'Receipt for your purchase', 'Your order is out for delivery'],
            );
          case 8: // no headers, nothing in the address, but Gmail files it under Updates
            s = SenderFacts(address: 'mark$i@vendor$i.com', name: 'Mark at Vendor', messagesWithKnownSignals: 3, providerCategories: const {'updates': 3});
          default: // feedback-id marketing with a single message so far
            signals = const BulkSignals(feedbackId: true, listUnsubscribe: true);
            s = SenderFacts(address: 'offers@retail$i.com', messagesWithBulkHeaders: 1, messagesWithKnownSignals: 1);
        }
        senders.add(s);
        labels.add(true);
        messages.add(MessageFacts(from: s.address, subject: 'Update $i', signals: signals));
      }

      // 800 human senders: colleagues, friends, replies to the user's mail,
      // people with generic local parts, people on big consumer domains.
      const humanDomains = ['gmail.com', 'outlook.com', 'yahoo.com', 'company.com', 'university.edu', 'studio.co', 'law-firm.com'];
      const humanLocals = ['sarah.chen', 'tom', 'joann.lee', 'info', 'hello', 'mike.r', 'dr.patel', 'team', 'news', 'alerts'];
      for (var i = 0; i < 800; i++) {
        final local = humanLocals[i % humanLocals.length];
        final domain = humanDomains[i % humanDomains.length];
        final shape = i % 4;
        final s = SenderFacts(
          address: '$local$i@$domain',
          name: 'Person $i',
          // Half of all humans have been written to; a quarter are in contacts.
          userHasWrittenTo: shape == 0 || shape == 1,
          inAddressBook: shape == 2,
          messagesWithKnownSignals: 1 + rng.nextInt(5),
          // One stray forwarded newsletter among several personal mails.
          messagesWithBulkHeaders: shape == 3 && i % 7 == 0 ? 1 : 0,
        );
        senders.add(s);
        labels.add(false);
        messages.add(MessageFacts(from: s.address, subject: 'Re: lunch?', isReplyToMine: shape == 0));
      }

      var bulkInFeeds = 0;
      var bulkTotal = 0;
      var humanRepliesInFeeds = 0;
      var humansInFeeds = 0;
      for (var i = 0; i < senders.length; i++) {
        final d = classifier.classifySender(senders[i]);
        var bucket = d.bucket;
        if (bucket == Bucket.feeds && classifier.isPersonalException(messages[i])) bucket = Bucket.people;
        if (labels[i]) {
          bulkTotal++;
          if (bucket == Bucket.feeds) bulkInFeeds++;
        } else {
          if (bucket == Bucket.feeds) humansInFeeds++;
          if (messages[i].isReplyToMine && bucket == Bucket.feeds) humanRepliesInFeeds++;
        }
      }
      final recall = bulkInFeeds / bulkTotal;
      // ignore: avoid_print
      print('bulk→Feeds ${(recall * 100).toStringAsFixed(1)}% ($bulkInFeeds/$bulkTotal); humans in Feeds: $humansInFeeds/800; human replies in Feeds: $humanRepliesInFeeds');
      expect(recall, greaterThanOrEqualTo(0.95));
      expect(humanRepliesInFeeds, 0);
      // Humans with bulk-looking local parts but no bulk evidence stay People.
      expect(humansInFeeds, lessThanOrEqualTo(800 * 0.05));
    });
  });

  group('sender rules', () {
    test('override wins over everything, then user rules, then People signals, then bulk evidence', () {
      const noisy = SenderFacts(address: 'noreply@bank.com', messagesWithBulkHeaders: 5, messagesWithKnownSignals: 5);
      expect(classifier.classifySender(noisy).bucket, Bucket.feeds);
      expect(classifier.classifySender(const SenderFacts(address: 'noreply@bank.com', override: Bucket.people)).bucket, Bucket.people);
      expect(classifier.classifySender(const SenderFacts(address: 'noreply@bank.com', override: Bucket.people)).source, 'override');

      const ruled = Classifier(rules: [ClassificationRule(field: 'domain', pattern: 'bank.com', bucket: Bucket.people)]);
      expect(ruled.classifySender(noisy).bucket, Bucket.people);
      expect(ruled.classifySender(noisy).source, 'rule');

      // Wrote to them → People even with list headers.
      const friendList = SenderFacts(address: 'alerts@x.com', userHasWrittenTo: true, messagesWithBulkHeaders: 3, messagesWithKnownSignals: 3);
      expect(classifier.classifySender(friendList).bucket, Bucket.people);
      expect(classifier.classifySender(friendList).reasons, contains('You have written to this address'));
      expect(classifier.classifySender(const SenderFacts(address: 'x@y.com', inAddressBook: true)).bucket, Bucket.people);
    });

    test('generic local parts need a bulk header; one stray header does not condemn a person', () {
      expect(classifier.classifySender(const SenderFacts(address: 'info@smallbiz.com', messagesWithKnownSignals: 3)).bucket, Bucket.people);
      expect(classifier.classifySender(const SenderFacts(address: 'info@smallbiz.com', messagesWithBulkHeaders: 3, messagesWithKnownSignals: 3)).bucket, Bucket.feeds);
      expect(classifier.classifySender(const SenderFacts(address: 'tom@gmail.com', messagesWithBulkHeaders: 1, messagesWithKnownSignals: 6)).bucket, Bucket.people);
      expect(classifier.classifySender(const SenderFacts(address: 'tom@gmail.com', messagesWithBulkHeaders: 1, messagesWithKnownSignals: 1)).bucket, Bucket.feeds, reason: 'only message carries bulk headers');
    });

    test('bundled domains match on subdomains and prefixes', () {
      expect(Classifier.isBulkDomain('bounce.mailchimp.com'), isTrue);
      expect(Classifier.isBulkDomain('em.nytimes.com'), isTrue);
      expect(Classifier.isBulkDomain('news.example.org'), isTrue);
      expect(Classifier.isBulkDomain('example.org'), isFalse);
      expect(Classifier.isBulkDomain('mygithub.company.com'), isFalse);
    });
  });

  group('evidence without bulk headers', () {
    test('dedicated sending subdomains are bulk; ordinary three-label domains are not', () {
      expect(Classifier.isSendingSubdomain('e.tovala.com'), isTrue);
      expect(Classifier.isSendingSubdomain('email.electrifyamerica.com'), isTrue);
      expect(Classifier.isSendingSubdomain('info.email.aa.com'), isTrue);
      expect(Classifier.isSendingSubdomain('tr.1800contacts.com'), isTrue);
      expect(Classifier.isSendingSubdomain('tovala.com'), isFalse);
      expect(Classifier.isSendingSubdomain('cs.stanford.edu'), isFalse);
      expect(classifier.classifySender(const SenderFacts(address: 'sarah@e.tovala.com', name: 'Sarah at Tovala', messagesWithKnownSignals: 2)).bucket, Bucket.feeds);
    });

    test('Gmail Updates or Promotions sends a sender to Feeds with a matching category', () {
      final d = classifier.classifySender(const SenderFacts(address: 'mark@vendor.com', messagesWithKnownSignals: 3, providerCategories: {'updates': 3}));
      expect(d.bucket, Bucket.feeds);
      expect(d.reasons.first, contains('Gmail files this sender under Updates'));
      expect(d.category, FeedsCategories.notification);
      final promo = classifier.classifySender(const SenderFacts(address: 'hello@brand.com', messagesWithKnownSignals: 2, providerCategories: {'promotions': 2}));
      expect(promo.category, FeedsCategories.promotion);
      final receipts = classifier.classifySender(const SenderFacts(
        address: 'mark@vendor.com',
        messagesWithKnownSignals: 2,
        providerCategories: {'updates': 2},
        subjects: ['Your order #1 has shipped', 'Receipt for your purchase'],
      ));
      expect(receipts.category, FeedsCategories.receipt);
    });

    test('Gmail Primary keeps a sender in People against weak evidence, not against strong', () {
      // Automated-looking subjects and name, but Gmail says Primary.
      final weak = classifier.classifySender(const SenderFacts(
        address: 'support@smallstudio.com',
        name: 'Studio Support',
        messagesWithKnownSignals: 3,
        providerCategories: {'primary': 3},
        subjects: ['Your order #1 has shipped', 'Receipt for your purchase', 'Your order is out for delivery'],
      ));
      expect(weak.bucket, Bucket.people);
      expect(weak.reasons.single, contains('Primary'));
      // noreply@ is strong evidence even in Primary.
      expect(classifier.classifySender(const SenderFacts(address: 'noreply@bank.com', messagesWithKnownSignals: 1, providerCategories: {'primary': 1})).bucket, Bucket.feeds);
    });

    test('mostly automated subjects send a sender to Feeds; business words between people do not', () {
      final shop = classifier.classifySender(const SenderFacts(
        address: 'jessica@shopco.com',
        messagesWithKnownSignals: 3,
        subjects: ['Your order #4411 has shipped', 'Receipt for your purchase', 'Lunch?'],
      ));
      expect(shop.bucket, Bucket.feeds);
      expect(shop.category, FeedsCategories.receipt);
      final agent = classifier.classifySender(const SenderFacts(
        address: 'dana@agency.com',
        name: 'Dana Smith',
        messagesWithKnownSignals: 4,
        subjects: ['Offer - Cerritos Center', 'Itinerary for Friday', 'Invoice for October', 'Reminder: call at 3'],
      ));
      expect(agent.bucket, Bucket.people);
      // Replies and forwards never count as automated subjects.
      expect(classifier.classifySender(const SenderFacts(address: 'tom@x.com', messagesWithKnownSignals: 2, subjects: ['Fwd: Your order has shipped', 'Re: Receipt for your purchase'])).bucket, Bucket.people);
    });

    test('automated display names count only with supporting evidence', () {
      expect(classifier.classifySender(const SenderFacts(address: 'info@brand.com', name: 'Brand Customer Care', messagesWithKnownSignals: 1)).bucket, Bucket.feeds);
      expect(classifier.classifySender(const SenderFacts(address: 'pat@brand.com', name: 'The Brand Team', messagesWithKnownSignals: 3)).bucket, Bucket.feeds);
      expect(classifier.classifySender(const SenderFacts(address: 'pat@brand.com', name: 'The Brand Team', messagesWithKnownSignals: 1)).bucket, Bucket.people);
      expect(classifier.classifySender(const SenderFacts(address: 'merch@clayfans.com', name: 'Team Clay', messagesWithKnownSignals: 5)).bucket, Bucket.people);
    });

    test('having written to a sender keeps it in People unless it is plainly a mailer', () {
      const person = SenderFacts(address: 'pat@vendor.com', userHasWrittenTo: true, messagesWithKnownSignals: 3, providerCategories: {'updates': 3});
      expect(classifier.classifySender(person).bucket, Bucket.people, reason: 'Gmail alone does not outweigh a conversation');
      const mailer = SenderFacts(address: 'news@shop.com', userHasWrittenTo: true, messagesWithBulkHeaders: 6, messagesWithKnownSignals: 6, providerCategories: {'updates': 6});
      final d = classifier.classifySender(mailer);
      expect(d.bucket, Bucket.feeds);
      expect(d.reasons, contains('You wrote to this sender, but it is a mailer'));
      expect(
        classifier.classifySender(const SenderFacts(address: 'news@shop.com', inAddressBook: true, messagesWithBulkHeaders: 6, messagesWithKnownSignals: 6, providerCategories: {'updates': 6})).bucket,
        Bucket.people,
        reason: 'the address book always wins',
      );
    });

    test('message category uses the provider label when the subject says nothing', () {
      expect(classifier.inferCategory(const MessageFacts(from: 'a@b.com', subject: 'Hello there', providerCategory: 'promotions')), FeedsCategories.promotion);
      expect(classifier.inferCategory(const MessageFacts(from: 'a@b.com', subject: 'Hello there', providerCategory: 'social')), FeedsCategories.social);
      expect(classifier.inferCategory(const MessageFacts(from: 'a@b.com', subject: 'Hello there', providerCategory: 'updates')), isNull);
    });
  });

  group('per-message exceptions', () {
    test('reply to my mail, salutation by name without bulk headers', () {
      expect(classifier.isPersonalException(const MessageFacts(from: 'noreply@x.com', isReplyToMine: true)), isTrue);
      expect(classifier.isPersonalException(const MessageFacts(from: 'support@x.com', snippet: 'Hi Clay, thanks for reaching out')), isTrue);
      expect(classifier.isPersonalException(const MessageFacts(from: 'support@x.com', snippet: "Hello Clay's team")), isFalse);
      expect(classifier.isPersonalException(const MessageFacts(from: 'support@x.com', snippet: 'Hi Clay,', signals: BulkSignals(listUnsubscribe: true))), isFalse, reason: 'bulk headers veto the salutation');
      expect(classifier.isPersonalException(const MessageFacts(from: 'support@x.com', snippet: 'Hi there')), isFalse);
    });
  });

  group('categories', () {
    test('content categories', () {
      expect(classifier.inferCategory(const MessageFacts(from: 'orders@shop.com', subject: 'Your order #1234 has shipped')), FeedsCategories.receipt);
      expect(classifier.inferCategory(const MessageFacts(from: 'noreply@bank.com', subject: 'Your verification code is 123456')), FeedsCategories.notification);
      expect(classifier.inferCategory(const MessageFacts(from: 'notification@facebookmail.com', subject: 'Anna commented on your photo')), FeedsCategories.social);
      expect(classifier.inferCategory(const MessageFacts(from: 'deals@store.com', subject: 'Last chance: 40% off everything')), FeedsCategories.promotion);
      expect(classifier.inferCategory(const MessageFacts(from: 'editor@paper.com', subject: 'The Weekly Edition #42')), FeedsCategories.newsletter);
      expect(classifier.inferCategory(const MessageFacts(from: 'x@y.com', subject: 'hello', signals: BulkSignals(listUnsubscribe: true))), FeedsCategories.newsletter);
      expect(classifier.inferCategory(const MessageFacts(from: 'x@y.com', subject: 'hello')), isNull);
    });

    test('sender default category from local part, list, or platform', () {
      expect(classifier.classifySender(const SenderFacts(address: 'receipts@shop.com')).category, FeedsCategories.receipt);
      expect(classifier.classifySender(const SenderFacts(address: 'noreply@acme.com')).category, FeedsCategories.notification);
      expect(classifier.classifySender(const SenderFacts(address: 'hello@brand.com', messagesWithBulkHeaders: 3, messagesWithKnownSignals: 3, listIds: {'news.brand.com'})).category, FeedsCategories.newsletter);
      expect(classifier.classifySender(const SenderFacts(address: 'notify@linkedin.com')).category, FeedsCategories.social);
    });

    test('a subject rule with a custom category wins over inference', () {
      const c = Classifier(rules: [ClassificationRule(field: 'subject', pattern: 'passcode|verification code', category: 'OTP')]);
      expect(c.messageCategory(const MessageFacts(from: 'noreply@bank.com', subject: 'Your verification code'), senderDefault: 'Notification'), 'OTP');
      expect(c.messageCategory(const MessageFacts(from: 'noreply@bank.com', subject: 'Statement is ready'), senderDefault: 'Notification'), 'Receipt');
      expect(c.messageCategory(const MessageFacts(from: 'noreply@bank.com', subject: 'Hello'), senderDefault: 'Notification'), 'Notification');
    });
  });

  group('rules and proposals', () {
    test('proposal scopes to the list when there is one, else the address', () {
      final viaList = Classifier.proposeRule(m: const MessageFacts(from: 'Digest@News.com', signals: BulkSignals(listId: true, listIdValue: 'daily.news.com')), bucket: Bucket.people);
      expect(viaList.field, 'listId');
      expect(viaList.pattern, 'daily.news.com');
      expect(viaList.describe(), 'The mailing list daily.news.com → People');
      final direct = Classifier.proposeRule(m: const MessageFacts(from: 'Digest@News.com'), category: 'OTP');
      expect(direct.field, 'sender');
      expect(direct.pattern, 'digest@news.com');
      expect(direct.describe(), 'Mail from digest@news.com → OTP');
    });

    test('rule matching: sender, domain and subdomain, list id, subject words', () {
      const domain = ClassificationRule(field: 'domain', pattern: 'bank.com', bucket: Bucket.feeds);
      expect(domain.matchesSender(const SenderFacts(address: 'a@bank.com')), isTrue);
      expect(domain.matchesSender(const SenderFacts(address: 'a@alerts.bank.com')), isTrue);
      expect(domain.matchesSender(const SenderFacts(address: 'a@notbank.com')), isFalse);
      const subj = ClassificationRule(field: 'subject', pattern: 'passcode | one-time', category: 'OTP');
      expect(subj.matchesMessage(const MessageFacts(from: 'x@y', subject: 'Your One-Time code')), isTrue);
      expect(subj.describe(), "Subject contains 'passcode' or 'one-time' → OTP");
    });

    test('BulkSignals round-trips through its storage form', () {
      const s = BulkSignals(listUnsubscribe: true, precedenceBulk: true, listId: true, listIdValue: 'x.list.com');
      final back = BulkSignals.decode(s.encode());
      expect(back.listUnsubscribe, isTrue);
      expect(back.precedenceBulk, isTrue);
      expect(back.listIdValue, 'x.list.com');
      expect(BulkSignals.decode('').any, isFalse);
      expect(BulkSignals.fromHeaders(precedence: 'Bulk', autoSubmitted: 'no').precedenceBulk, isTrue);
      expect(BulkSignals.fromHeaders(autoSubmitted: 'no').any, isFalse);
      expect(BulkSignals.fromHeaders(autoSubmitted: 'auto-generated').autoSubmitted, isTrue);
      expect(BulkSignals.fromHeaders(listId: 'Daily <daily.news.com>').listIdValue, 'daily.news.com');
    });
  });
}
