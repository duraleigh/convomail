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

/// The pile for a sender that is not a person.
///
/// The user's own choice ([chosen]) always wins. Otherwise promotions and
/// social notices are Noise, a newsletter is Feed only when it gets opened,
/// and everything else (receipts, deliveries, travel, codes, notifications,
/// updates, the user's own tags) is Feed.
FeedsPile pileFor({String? chosen, String? category, required int total, required int unread}) {
  final own = FeedsPile.parse(chosen);
  if (own != null) return own;
  if (noiseCategories.contains(category)) return FeedsPile.noise;
  if (category == FeedsCategories.newsletter) {
    final opened = total - unread;
    return total > 0 && opened >= total * newsletterOpenedShare ? FeedsPile.feed : FeedsPile.noise;
  }
  return FeedsPile.feed;
}
