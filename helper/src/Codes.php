<?php
declare(strict_types=1);

namespace Precis;

/**
 * Finds a sign-in code ("Your verification code is 482913") in an email's
 * subject and first words, by plain rules: nothing is sent to the
 * assistant and it costs nothing. The same rules the app uses on a device.
 *
 * A code is never written down by the helper: it is found, sent to the
 * owner's phones, and forgotten.
 */
final class Codes
{
    /** How long a code is worth showing, in seconds. */
    public const LIFETIME = 900;

    private const TOPIC = '~\b(?:(?:verification|security|log\s?-?in|sign\s?-?in|authentication|authorization|one[\s-]?time|access|confirmation)\s+(?:code|pin|password|passcode)|verification|passcode|otp|2fa|two[\s-]factor|one[\s-]?time\s+password|your\s+code|code\s+to\s+(?:log|sign|verify|confirm|continue))\b~iu';
    private const NOT_A_CODE = '~\b(?:promo|coupon|discount|voucher|gift\s+card|referral|redeem|% off|zip\s+code|postal\s+code|dress\s+code|area\s+code|source\s+code|qr\s+code)\b~iu';
    private const TRAVEL_OR_ORDER = '~\b(?:flight|itinerary|hotel|booking|reservation|order|ticket|trip|shipment)\b~iu';
    private const SIGN_IN_WORDS = '~\b(?:verif|log\s?-?in|sign\s?-?in|one[\s-]?time|otp|passcode)~iu';
    private const AFTER_WORD = '~\b(?:[Cc]ode|CODE|[Pp]in|PIN|[Pp]asscode|otp|OTP|[Pp]assword|[Ss]ign\s?-?in|[Ll]og\s?-?in|[Vv]erify|[Cc]onfirm|[Cc]ontinue)\b(?:\s+is)?\s*[:=\-]?\s*(?:is\s+)?["“]?([A-Z0-9][A-Z0-9-]{2,10}[A-Z0-9])\b~u';
    private const BEFORE_IS_YOUR = '~\b([A-Z0-9][A-Z0-9-]{2,10}[A-Z0-9])\s+is\s+your\b~u';
    private const DIGITS_ALONE = '~(?:^|\s)(\d{3}[ -]\d{3}|\d{4,8})(?=\s|[.,;]?$)~u';

    /** The code in this email, or null when it has none. */
    public static function find(string $subject, string $text): ?string
    {
        $subject = trim(html_entity_decode($subject, ENT_QUOTES | ENT_HTML5, 'UTF-8'));
        $head = mb_substr(trim(html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8')), 0, 1500);
        $topicInSubject = preg_match(self::TOPIC, $subject) === 1;
        if (!$topicInSubject && preg_match(self::TOPIC, $head) !== 1) {
            return null;
        }
        if (preg_match(self::NOT_A_CODE, $subject) === 1) {
            return null;
        }
        // A "confirmation code" on a trip or an order is a booking reference.
        if (preg_match(self::TRAVEL_OR_ORDER, $subject) === 1 && preg_match(self::SIGN_IN_WORDS, $subject) !== 1) {
            return null;
        }
        foreach ([$subject, $head] as $source) {
            foreach ([self::AFTER_WORD, self::BEFORE_IS_YOUR] as $pattern) {
                if (preg_match_all($pattern, $source, $all, PREG_SET_ORDER | PREG_OFFSET_CAPTURE) < 1) {
                    continue;
                }
                foreach ($all as $m) {
                    $start = (int) $m[0][1];
                    $before = substr($source, max(0, $start - 40), min(40, $start));
                    if (preg_match(self::NOT_A_CODE, $before . $m[0][0]) === 1) {
                        continue;
                    }
                    $code = self::plausible((string) $m[1][0]);
                    if ($code !== null) {
                        return $code;
                    }
                }
            }
        }
        // A number standing by itself, in an email that is about a code.
        if ($topicInSubject && preg_match_all(self::DIGITS_ALONE, $head, $all, PREG_SET_ORDER) >= 1) {
            foreach ($all as $m) {
                $code = self::plausible((string) $m[1]);
                if ($code !== null) {
                    return $code;
                }
            }
        }
        return null;
    }

    /** The text tidied when it can be a one-time code, else null. */
    private static function plausible(string $raw): ?string
    {
        $c = str_replace(' ', '', $raw);
        $digits = str_replace('-', '', $c);
        if (preg_match('~^\d+$~', $digits) === 1) {
            if (strlen($digits) < 4 || strlen($digits) > 8) {
                return null;
            }
            // A bare year reads as a code too easily.
            if (strlen($digits) === 4 && preg_match('~^(19|20)\d\d$~', $digits) === 1) {
                return null;
            }
            return $c;
        }
        // Mixed codes need a digit: plain words like "BELOW" are not codes.
        if (preg_match('~^G-\d{4,8}$~', $c) === 1) {
            return $c;
        }
        if (strlen($c) < 5 || strlen($c) > 10) {
            return null;
        }
        if (preg_match('~\d~', $c) !== 1 || preg_match('~[A-Z]~', $c) !== 1) {
            return null;
        }
        return $c;
    }
}
