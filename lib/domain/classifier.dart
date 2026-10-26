/// People vs Feeds classification (spec 4.11, plan M8). Pure Dart, no I/O.
///
/// Decisions are per sender with per-message exceptions. Phase 1 is
/// deterministic: bulk-mail headers, address patterns, a bundled list of
/// sending domains, reply history, and the address book. Every signal is
/// readable from the message on the device.
library;

import 'identity.dart';

enum Bucket { people, feeds }

/// Header-level bulk-mail evidence carried on each message.
class BulkSignals {
  const BulkSignals({
    this.listUnsubscribe = false,
    this.listId = false,
    this.listPost = false,
    this.feedbackId = false,
    this.precedenceBulk = false,
    this.autoSubmitted = false,
    this.listIdValue,
  });

  static const none = BulkSignals();

  final bool listUnsubscribe;
  final bool listId;
  final bool listPost;
  final bool feedbackId;

  /// `Precedence: bulk` or `Precedence: list`.
  final bool precedenceBulk;

  /// `Auto-Submitted` present with any value other than `no`.
  final bool autoSubmitted;
  final String? listIdValue;

  bool get any => listUnsubscribe || listId || listPost || feedbackId || precedenceBulk || autoSubmitted;

  /// Human-readable names, for reasons and the correction dialog.
  List<String> get names => [
        if (listUnsubscribe) 'List-Unsubscribe',
        if (listId) 'List-Id',
        if (listPost) 'List-Post',
        if (feedbackId) 'Feedback-ID',
        if (precedenceBulk) 'Precedence: bulk',
        if (autoSubmitted) 'Auto-Submitted',
      ];

  /// Compact storage form, e.g. `u,i,p;list.example.com`.
  String encode() {
    final flags = [
      if (listUnsubscribe) 'u',
      if (listId) 'i',
      if (listPost) 'o',
      if (feedbackId) 'f',
      if (precedenceBulk) 'b',
      if (autoSubmitted) 'a',
    ].join(',');
    return listIdValue == null || listIdValue!.isEmpty ? flags : '$flags;${listIdValue!.replaceAll(';', ' ')}';
  }

  static BulkSignals decode(String? s) {
    if (s == null) return none;
    final semi = s.indexOf(';');
    final flags = (semi < 0 ? s : s.substring(0, semi)).split(',').toSet();
    return BulkSignals(
      listUnsubscribe: flags.contains('u'),
      listId: flags.contains('i'),
      listPost: flags.contains('o'),
      feedbackId: flags.contains('f'),
      precedenceBulk: flags.contains('b'),
      autoSubmitted: flags.contains('a'),
      listIdValue: semi < 0 ? null : s.substring(semi + 1),
    );
  }

  /// Builds from raw header values (null when absent).
  static BulkSignals fromHeaders({
    String? listUnsubscribe,
    String? listId,
    String? listPost,
    String? feedbackId,
    String? precedence,
    String? autoSubmitted,
  }) {
    final prec = precedence?.trim().toLowerCase();
    final auto = autoSubmitted?.trim().toLowerCase();
    return BulkSignals(
      listUnsubscribe: listUnsubscribe != null && listUnsubscribe.trim().isNotEmpty,
      listId: listId != null && listId.trim().isNotEmpty,
      listPost: listPost != null && listPost.trim().isNotEmpty,
      feedbackId: feedbackId != null && feedbackId.trim().isNotEmpty,
      precedenceBulk: prec == 'bulk' || prec == 'list' || prec == 'junk',
      autoSubmitted: auto != null && auto.isNotEmpty && auto != 'no',
      listIdValue: listId == null ? null : _listIdCore(listId),
    );
  }

  static String _listIdCore(String v) {
    final m = RegExp(r'<([^>]+)>').firstMatch(v);
    return (m?.group(1) ?? v).trim().toLowerCase();
  }
}

/// What is known about a sender when deciding its bucket.
class SenderFacts {
  const SenderFacts({
    required this.address,
    this.name = '',
    this.userHasWrittenTo = false,
    this.inAddressBook = false,
    this.messagesWithBulkHeaders = 0,
    this.messagesWithKnownSignals = 0,
    this.listIds = const {},
    this.override,
  });

  final String address;
  final String name;

  /// The user has ever sent mail to this address (People, overrides rules).
  final bool userHasWrittenTo;
  final bool inAddressBook;
  final int messagesWithBulkHeaders;

  /// Messages whose headers were fetched (denominator for the ratio).
  final int messagesWithKnownSignals;
  final Set<String> listIds;

  /// A manual, permanent decision; wins over everything.
  final Bucket? override;

  String get localPart => address.contains('@') ? address.substring(0, address.indexOf('@')).toLowerCase() : address.toLowerCase();
  String get domain => address.contains('@') ? address.substring(address.indexOf('@') + 1).toLowerCase() : '';
}

/// What is known about one message when deciding per-message exceptions
/// and its category.
class MessageFacts {
  const MessageFacts({
    required this.from,
    this.fromName = '',
    this.subject = '',
    this.snippet = '',
    this.signals = BulkSignals.none,
    this.isReplyToMine = false,
  });
  final String from;
  final String fromName;
  final String subject;
  final String snippet;
  final BulkSignals signals;

  /// In-Reply-To names a Message-ID the user sent.
  final bool isReplyToMine;
}

/// A rule the user accepted (spec 4.11 "propose a rule, user confirms").
class ClassificationRule {
  const ClassificationRule({this.id, required this.field, required this.pattern, this.bucket, this.category});

  final int? id;

  /// `sender` (exact address), `domain` (address ends with @domain or a
  /// subdomain), `listId` (List-Id equals), or `subject` (contains, case
  /// insensitive; may hold several words separated by `|`).
  final String field;
  final String pattern;
  final Bucket? bucket;
  final String? category;

  bool matchesSender(SenderFacts s) {
    final p = pattern.toLowerCase();
    switch (field) {
      case 'sender':
        return s.address.toLowerCase() == p;
      case 'domain':
        return s.domain == p || s.domain.endsWith('.$p');
      case 'listId':
        return s.listIds.contains(p);
      default:
        return false;
    }
  }

  bool matchesMessage(MessageFacts m) {
    final p = pattern.toLowerCase();
    switch (field) {
      case 'sender':
        return m.from.toLowerCase() == p;
      case 'domain':
        final d = m.from.contains('@') ? m.from.substring(m.from.indexOf('@') + 1).toLowerCase() : '';
        return d == p || d.endsWith('.$p');
      case 'listId':
        return (m.signals.listIdValue ?? '') == p;
      case 'subject':
        final subj = m.subject.toLowerCase();
        return p.split('|').map((w) => w.trim()).where((w) => w.isNotEmpty).any(subj.contains);
      default:
        return false;
    }
  }

  /// Plain-language statement, e.g. for the proposal dialog and Settings.
  String describe() {
    final target = [if (bucket != null) bucket == Bucket.feeds ? 'Feeds' : 'People', if (category != null) category].join(' · ');
    return switch (field) {
      'sender' => 'Mail from $pattern → $target',
      'domain' => 'Mail from anyone at $pattern → $target',
      'listId' => 'The mailing list $pattern → $target',
      'subject' => 'Subject contains ${pattern.split('|').map((w) => "'${w.trim()}'").join(' or ')} → $target',
      _ => '$field $pattern → $target',
    };
  }
}

class SenderDecision {
  const SenderDecision(this.bucket, {this.category, this.reasons = const [], this.source = 'auto'});
  final Bucket bucket;

  /// Sender-default category when [bucket] is Feeds.
  final String? category;
  final List<String> reasons;

  /// `auto`, `override`, `rule`, or `people-signal`.
  final String source;
}

/// Default category names (spec 4.11). Users may rename or delete them.
abstract final class FeedsCategories {
  static const newsletter = 'Newsletter';
  static const receipt = 'Receipt';
  static const notification = 'Notification';
  static const social = 'Social';
  static const promotion = 'Promotion';
  static const defaults = [newsletter, receipt, notification, social, promotion];
}

class Classifier {
  const Classifier({this.rules = const [], this.userFirstNames = const {}});

  final List<ClassificationRule> rules;

  /// Lower-cased first names of the user, for the salutation exception.
  final Set<String> userFirstNames;

  // Local parts that mark automated senders on their own.
  static final _bulkLocalParts = RegExp(
    r'^(no-?reply|do-?not-?reply|donotreply|noreply-[\w.-]+|[\w.-]*-?noreply|notifications?|notify|alerts?|mailer-daemon|postmaster|newsletters?|digest|updates?|bounces?|[\w.-]*bounce[\w.-]*|marketing|promotions?|news|support-noreply|automated|auto-?confirm|confirm(ation)?s?|orders?|receipts?|billing|invoices?|statements?|security|account(s)?|team|robot|bot|system|daemon|ping)$',
    caseSensitive: false,
  );

  // Local parts that are bulk only together with a bulk header.
  static final _softLocalParts = RegExp(r'^(info|hello|hi|contact|mail|email|admin|help|service|customerservice|customer-service|sales)$', caseSensitive: false);

  /// Bundled sending domains (ESPs, platforms, transactional senders).
  /// Matched on the domain or any subdomain.
  static const bulkDomains = {
    // ESPs / delivery platforms
    'mailchimp.com', 'list-manage.com', 'mcsv.net', 'rsgsv.net', 'sendgrid.net', 'sendgrid.me', 'amazonses.com', 'mailgun.org', 'mailgun.net',
    'constantcontact.com', 'ccsend.com', 'createsend.com', 'cmail19.com', 'cmail20.com', 'exacttarget.com', 'et.e.mail', 'sailthru.com', 'klaviyo.com',
    'klaviyomail.com', 'hubspotemail.net', 'hs-send.com', 'substack.com', 'substackcdn.com', 'beehiiv.com', 'convertkit.com', 'ck.page', 'mailerlite.com',
    'sparkpostmail.com', 'postmarkapp.com', 'mandrillapp.com', 'braze.com', 'iterable.com', 'customeriomail.com', 'drip.com', 'activehosted.com', 'getresponse.com',
    'aweber.com', 'campaign-archive.com', 'e.emailsrvr.com', 'em.', 'news.', 'newsletter.',
    // social / platforms (notification mail)
    // (x.com is left out on purpose: X's notifications carry list headers
    // and automated local parts, and the bare domain is also a common
    // placeholder.)
    'facebookmail.com', 'linkedin.com', 'twitter.com', 'instagram.com', 'nextdoor.com', 'pinterest.com', 'tiktok.com', 'redditmail.com', 'reddit.com',
    'discord.com', 'slack.com', 'youtube.com', 'quora.com', 'meetup.com', 'strava.com', 'snapchat.com', 'threads.net',
    // common transactional
    'github.com', 'gitlab.com', 'atlassian.net', 'atlassian.com', 'trello.com', 'dropbox.com', 'docusign.net', 'docusign.com', 'paypal.com', 'stripe.com',
    'squareup.com', 'venmo.com', 'intuit.com', 'quickbooks.com', 'shopify.com', 'amazon.com', 'ebay.com', 'etsy.com', 'uber.com', 'lyft.com', 'doordash.com',
    'grubhub.com', 'instacart.com', 'airbnb.com', 'booking.com', 'expedia.com', 'hotels.com', 'ticketmaster.com', 'eventbrite.com', 'zillow.com', 'indeed.com',
    'glassdoor.com', 'accounts.google.com', 'google.com', 'apple.com', 'icloud.com', 'microsoft.com', 'microsoftonline.com', 'live.com', 'spotify.com',
    'netflix.com', 'hulu.com', 'disneyplus.com', 'adobe.com', 'zoom.us', 'calendly.com', 'medium.com', 'patreon.com', 'kickstarter.com', 'coinbase.com',
    'robinhood.com', 'chase.com', 'bankofamerica.com', 'wellsfargo.com', 'capitalone.com', 'americanexpress.com', 'discover.com', 'citi.com', 'usps.com',
    'ups.com', 'fedex.com', 'dhl.com',
  };

  static const _socialDomains = {
    'facebookmail.com', 'linkedin.com', 'twitter.com', 'instagram.com', 'nextdoor.com', 'pinterest.com', 'tiktok.com', 'redditmail.com', 'reddit.com',
    'discord.com', 'slack.com', 'youtube.com', 'quora.com', 'meetup.com', 'strava.com', 'snapchat.com', 'threads.net',
  };

  static final _receiptSubject = RegExp(
    r'\b(receipt|invoice|order (confirmation|confirmed|#|number|received|update|placed|shipped)|your order|has shipped|out for delivery|delivered|delivery (update|confirmation)|payment (received|confirmation|successful|processed)|purchase|statement is (ready|available)|bill is ready|your (bill|statement)|transaction|refund|subscription (renewal|renewed|receipt)|booking confirmation|reservation|itinerary|e-?ticket|tracking number)\b',
    caseSensitive: false,
  );
  static final _notificationSubject = RegExp(
    r'\b(security alert|sign-?in|new login|verify (your|this)|verification code|one-?time (passcode|password|code)|passcode|otp|your code|password (reset|changed)|2-?step|two-?factor|reminder|alert|action required|confirm your|account (activity|update)|was (added|removed|changed)|new device|mentioned you|assigned to you|commented|new comment|pull request|build (failed|passed|succeeded)|run failed|deployment|job alert|appointment)\b',
    caseSensitive: false,
  );
  static final _socialSubject = RegExp(
    r'\b(friend request|followed you|new follower|tagged you|liked your|commented on your|mentioned you in|sent you a message|wants to connect|connection request|invitation to connect|new message from|reacted to|shared a post|is live|new post from)\b',
    caseSensitive: false,
  );
  static final _promotionSubject = RegExp(
    r'(\d{1,2}% off|% off|\$\d+ off|sale\b|deal(s)?\b|offer(s)?\b|save (up to|\$|\d)|free shipping|coupon|promo|limited time|last chance|ends (tonight|today|soon)|don.t miss|black friday|cyber monday|clearance|exclusive|flash sale|new arrivals|just dropped|gift guide|bogo|rewards|points)',
    caseSensitive: false,
  );
  static final _newsletterSubject = RegExp(r'\b(newsletter|digest|weekly|daily|monthly|edition|issue #?\d+|roundup|round-up|this week in|the week in|top stories|briefing|bulletin|recap|what.s new|in case you missed)\b', caseSensitive: false);

  /// Sender-level decision. Order (spec 4.11): manual override → user
  /// rules → People signals (wrote to them, address book) → bulk evidence.
  SenderDecision classifySender(SenderFacts s) {
    if (s.override != null) return SenderDecision(s.override!, reasons: const ['Moved by you'], source: 'override');

    for (final r in rules) {
      if (r.bucket != null && r.matchesSender(s)) return SenderDecision(r.bucket!, category: r.category, reasons: [r.describe()], source: 'rule');
    }

    final peopleReasons = <String>[
      if (s.userHasWrittenTo) 'You have written to this address',
      if (s.inAddressBook) 'In your contacts',
    ];
    if (peopleReasons.isNotEmpty) return SenderDecision(Bucket.people, reasons: peopleReasons, source: 'people-signal');

    final reasons = <String>[];
    final hardLocal = _bulkLocalParts.hasMatch(s.localPart);
    final softLocal = _softLocalParts.hasMatch(s.localPart);
    final domainHit = isBulkDomain(s.domain);
    final withHeaders = s.messagesWithBulkHeaders;
    final known = s.messagesWithKnownSignals;
    // A sender is "bulk by headers" when a meaningful share of its mail
    // carries bulk headers (one stray forward does not condemn a person).
    final headerRatio = known == 0 ? 0.0 : withHeaders / known;
    final bulkByHeaders = withHeaders > 0 && (headerRatio >= 0.5 || withHeaders >= 3);

    if (bulkByHeaders) reasons.add(withHeaders == known ? 'Bulk-mail headers on every message' : 'Bulk-mail headers on $withHeaders of $known messages');
    if (hardLocal) reasons.add('Automated address (${s.localPart}@)');
    if (domainHit) reasons.add('Known sending platform (${s.domain})');
    if (softLocal && (bulkByHeaders || domainHit)) reasons.add('Generic address (${s.localPart}@) with bulk signals');

    if (bulkByHeaders || hardLocal || domainHit) {
      return SenderDecision(Bucket.feeds, category: _senderCategory(s, hardLocal: hardLocal), reasons: reasons);
    }
    return const SenderDecision(Bucket.people, reasons: ['No bulk signals']);
  }

  static bool isBulkDomain(String domain) {
    final d = domain.toLowerCase();
    if (d.isEmpty) return false;
    for (final b in bulkDomains) {
      if (b.endsWith('.')) {
        if (d.startsWith(b)) return true; // em., news., newsletter. prefixes
      } else if (d == b || d.endsWith('.$b')) {
        return true;
      }
    }
    return false;
  }

  String _senderCategory(SenderFacts s, {required bool hardLocal}) {
    if (_socialDomains.any((d) => s.domain == d || s.domain.endsWith('.$d'))) return FeedsCategories.social;
    final lp = s.localPart;
    if (RegExp(r'receipt|order|billing|invoice|statement|payment').hasMatch(lp)) return FeedsCategories.receipt;
    if (RegExp(r'newsletter|digest|news|weekly|daily').hasMatch(lp)) return FeedsCategories.newsletter;
    if (RegExp(r'marketing|promo|offers?|deals?|sales?').hasMatch(lp)) return FeedsCategories.promotion;
    if (s.listIds.isNotEmpty || s.messagesWithBulkHeaders > 0 && !hardLocal) return FeedsCategories.newsletter;
    return FeedsCategories.notification;
  }

  /// Per-message exception (spec 4.11): a Feeds sender's message with strong
  /// personal signals is shown in People for that message only.
  bool isPersonalException(MessageFacts m) {
    if (m.isReplyToMine) return true;
    if (m.signals.any) return false;
    return greetsUserByName(m.snippet);
  }

  /// "Hi Clay," / "Hello Clay" / "Dear Clay" at the start of the body.
  bool greetsUserByName(String snippet) {
    if (userFirstNames.isEmpty) return false;
    final head = snippet.trimLeft().toLowerCase();
    if (head.length < 3) return false;
    final m = RegExp(r"^(hi|hello|hey|dear|good (morning|afternoon|evening))\s+([a-z'’\-]+)").firstMatch(head);
    if (m == null) return false;
    // "Clay's team" is not a greeting to Clay.
    return userFirstNames.contains(m.group(3)!);
  }

  /// Category for one message. User subject/sender rules first, then
  /// content; null means "use the sender default".
  String? messageCategory(MessageFacts m, {String? senderDefault}) {
    for (final r in rules) {
      if (r.category != null && r.matchesMessage(m)) return r.category;
    }
    final inferred = inferCategory(m);
    if (inferred == null) return senderDefault;
    return inferred;
  }

  /// Content-based category: Receipt, Notification, Social, Promotion, or
  /// Newsletter; null when nothing fits.
  String? inferCategory(MessageFacts m) {
    final subject = m.subject;
    final domain = m.from.contains('@') ? m.from.substring(m.from.indexOf('@') + 1).toLowerCase() : '';
    if (_socialDomains.any((d) => domain == d || domain.endsWith('.$d')) || _socialSubject.hasMatch(subject)) return FeedsCategories.social;
    if (_receiptSubject.hasMatch(subject)) return FeedsCategories.receipt;
    if (_notificationSubject.hasMatch(subject)) return FeedsCategories.notification;
    if (_promotionSubject.hasMatch(subject)) return FeedsCategories.promotion;
    if (_newsletterSubject.hasMatch(subject) || m.signals.listId || m.signals.listUnsubscribe) return FeedsCategories.newsletter;
    return null;
  }

  /// The rule the app would write for a correction (spec 4.11): scoped to
  /// the list when the message came through one, otherwise the address.
  static ClassificationRule proposeRule({required MessageFacts m, Bucket? bucket, String? category}) {
    final listId = m.signals.listIdValue;
    if (listId != null && listId.isNotEmpty) return ClassificationRule(field: 'listId', pattern: listId, bucket: bucket, category: category);
    return ClassificationRule(field: 'sender', pattern: normalizeAddress(m.from), bucket: bucket, category: category);
  }
}
