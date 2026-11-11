<?php
declare(strict_types=1);

namespace Precis;

/**
 * Feed or Noise for one email that is not from a person.
 *
 * It is decided for each email, not for the sender as a whole, because one
 * sender can send both kinds. The questions are asked in this order:
 *
 *  1. Did the owner decide? (this one email, or "always" for the sender)
 *  2. Is it plainly about the owner's own business? A receipt, a delivery,
 *     a trip or a sign-in code is Feed.
 *  3. Is it plainly advertising? Mail Gmail files under Promotions or
 *     Social, or tagged Promotion or Social, is Noise.
 *  4. Otherwise the assistant says, having read the subject and first part.
 *  5. Until it has (or when it is switched off), the sender's usual place.
 */
final class EmailPile
{
    public const FEED = 'feed';
    public const NOISE = 'noise';

    /** Tags that are always worth knowing. */
    public const ALWAYS_FEED = [Classifier::RECEIPT => true, Classifier::DELIVERY => true, Classifier::TRAVEL => true, Classifier::OTP => true];

    /** Tags that are always advertising or chatter. */
    public const ALWAYS_NOISE = [Classifier::PROMOTION => true, Classifier::SOCIAL => true];

    /**
     * @return array{pile: string, by: string} `by` is who decided: 'you', 'sender' (the owner's standing choice for the
     *   sender), 'kind' (a fixed rule), 'assistant', or 'usual' (the sender's usual place)
     */
    public static function decide(?string $fixed, ?string $senderChosen, ?string $tag, ?string $gmailTab, ?string $assistant, ?string $usual): array
    {
        if ($fixed === self::FEED || $fixed === self::NOISE) {
            return ['pile' => $fixed, 'by' => 'you'];
        }
        if ($senderChosen === self::FEED || $senderChosen === self::NOISE) {
            return ['pile' => $senderChosen, 'by' => 'sender'];
        }
        if ($tag !== null && isset(self::ALWAYS_FEED[$tag])) {
            return ['pile' => self::FEED, 'by' => 'kind'];
        }
        if (($tag !== null && isset(self::ALWAYS_NOISE[$tag])) || $gmailTab === 'promotions' || $gmailTab === 'social') {
            return ['pile' => self::NOISE, 'by' => 'kind'];
        }
        if ($assistant === self::FEED || $assistant === self::NOISE) {
            return ['pile' => $assistant, 'by' => 'assistant'];
        }
        return ['pile' => $usual === self::NOISE ? self::NOISE : self::FEED, 'by' => 'usual'];
    }
}
