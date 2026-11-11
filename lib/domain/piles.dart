import 'classifier.dart';

/// Where a sender that is not a person shows: Feed (worth knowing) or
/// Noise (kept out of the way).
enum FeedsPile {
  feed,
  noise;

  static FeedsPile? parse(String? v) => switch (v) { 'feed' => feed, 'noise' => noise, _ => null };
}

/// Categories that are Noise unless the user says otherwise.
const noiseCategories = {FeedsCategories.promotion, FeedsCategories.social};

/// A newsletter stays in Feed when the user opens at least this share of it.
const newsletterOpenedShare = 0.3;

/// How many emails of one kind a sender has sent, and how many of those
/// have not been opened.
typedef MailCount = ({int total, int unread});

/// The pile for a sender that is not a person.
///
/// The user's own choice ([chosen]) always wins. Otherwise it goes by what
/// the sender mostly sends ([mail]: its emails counted by category). Mostly
/// promotions and social notices: Noise. Mostly newsletters: Feed only when
/// they get opened. Everything else (receipts, deliveries, travel, codes,
/// notifications, updates, the user's own tags): Feed.
///
/// Without [mail], the sender's one [category] with its [total] and
/// [unread] counts is used the same way.
FeedsPile pileFor({String? chosen, String? category, required int total, required int unread, Map<String?, MailCount>? mail}) {
  final own = FeedsPile.parse(chosen);
  if (own != null) return own;
  final counts = (mail == null || mail.isEmpty) ? <String?, MailCount>{category: (total: total, unread: unread)} : mail;
  var all = 0;
  var noisy = 0;
  for (final e in counts.entries) {
    all += e.value.total;
    if (noiseCategories.contains(e.key)) noisy += e.value.total;
  }
  // With no mail counted, the label alone decides.
  if (all == 0) return noiseCategories.contains(category) || category == FeedsCategories.newsletter ? FeedsPile.noise : FeedsPile.feed;
  if (noisy * 2 > all) return FeedsPile.noise;
  final letters = counts[FeedsCategories.newsletter];
  if (letters != null && letters.total * 2 > all) {
    final opened = letters.total - letters.unread;
    return opened >= letters.total * newsletterOpenedShare ? FeedsPile.feed : FeedsPile.noise;
  }
  return FeedsPile.feed;
}
