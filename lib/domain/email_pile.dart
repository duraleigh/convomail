import 'classifier.dart';
import 'piles.dart';

/// Who settled where one email sits.
enum PileBy {
  /// The user moved this one email.
  you,

  /// The user's standing choice for the sender.
  sender,

  /// A fixed rule about the kind of mail (a receipt, a promotion).
  kind,

  /// The assistant, having read the subject and the first part.
  assistant,

  /// Nothing has settled it: the sender's usual place.
  usual,
}

/// Tags that are always worth knowing.
const alwaysFeedCategories = {FeedsCategories.receipt, FeedsCategories.delivery, FeedsCategories.travel, FeedsCategories.otp};

/// Feed or Noise for one email that is not from a person.
///
/// It is decided for each email, not for the sender as a whole, because one
/// sender can send both kinds. The same questions, in the same order, as
/// the helper asks (helper/src/EmailPile.php):
///
///  1. Did the user decide? ([fix] for this one email, [senderChosen] for
///     the sender.)
///  2. Is it plainly the user's own business? A receipt, a delivery, a trip
///     or a sign-in code is Feed.
///  3. Is it plainly advertising? Mail Gmail files under Promotions or
///     Social, or tagged Promotion or Social, is Noise.
///  4. Otherwise what the helper said ([helper]); [readByAssistant] tells
///     whether that came from the assistant reading it.
///  5. With no helper, the tag alone: a newsletter is Noise, the rest Feed.
({FeedsPile pile, PileBy by}) emailPile({String? fix, String? senderChosen, String? tag, String? gmailTab, String? helper, bool readByAssistant = false}) {
  final own = FeedsPile.parse(fix);
  if (own != null) return (pile: own, by: PileBy.you);
  final chosen = FeedsPile.parse(senderChosen);
  if (chosen != null) return (pile: chosen, by: PileBy.sender);
  if (tag != null && alwaysFeedCategories.contains(tag)) return (pile: FeedsPile.feed, by: PileBy.kind);
  if ((tag != null && noiseCategories.contains(tag)) || gmailTab == 'promotions' || gmailTab == 'social') return (pile: FeedsPile.noise, by: PileBy.kind);
  final said = FeedsPile.parse(helper);
  if (said != null) return (pile: said, by: readByAssistant ? PileBy.assistant : PileBy.usual);
  return (pile: tag == FeedsCategories.newsletter ? FeedsPile.noise : FeedsPile.feed, by: PileBy.usual);
}

/// One plain sentence saying why an email is where it is, for the "?".
String pileReason(FeedsPile pile, PileBy by, {String? tag, String? gmailTab}) {
  final where = pile == FeedsPile.feed ? 'Feed' : 'Noise';
  return switch (by) {
    PileBy.you => 'You moved this email to $where.',
    PileBy.sender => 'You chose $where for everything from this sender.',
    PileBy.kind when pile == FeedsPile.feed => switch (tag) {
        FeedsCategories.receipt => 'It is a receipt. Receipts always go to Feed.',
        FeedsCategories.delivery => 'It is about a delivery. Those always go to Feed.',
        FeedsCategories.travel => 'It is about a trip. Those always go to Feed.',
        FeedsCategories.otp => 'It is a sign-in code. Codes always go to Feed, and the assistant never reads them.',
        _ => 'This kind of mail always goes to Feed.',
      },
    PileBy.kind => gmailTab == 'promotions'
        ? 'Gmail files it under Promotions. The assistant does not read it.'
        : gmailTab == 'social'
            ? 'Gmail files it under Social. The assistant does not read it.'
            : 'It is tagged ${tag ?? 'as advertising'}. The assistant does not read it.',
    PileBy.assistant => 'The assistant read the subject and the first part and put it in $where.',
    PileBy.usual => pile == FeedsPile.noise ? 'Mail like this from this sender usually goes to Noise.' : 'Nothing marks it as advertising, so it is in Feed.',
  };
}
