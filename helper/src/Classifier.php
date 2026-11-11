<?php
declare(strict_types=1);

namespace Precis;

/**
 * Chats or not: the same fixed rules the app runs (lib/domain/classifier.dart),
 * carried over line for line. Its word lists and patterns are in
 * ClassifierData, which a script copies from the app. A shared set of worked
 * examples (tests/golden) is checked on both sides, so the two cannot come to
 * disagree without a check failing.
 *
 * Sender facts are arrays with these keys (all but `address` optional):
 * address, otherAddresses, messagesReceived (default 1), messagesSentTo,
 * repliesToAutomated, recipientNames, messagesWithTimely, name,
 * userHasWrittenTo, inAddressBook, messagesWithBulkHeaders,
 * messagesWithKnownSignals, listIds, override ('people'|'feeds'|null),
 * providerCategories (category => count), subjects (newest first).
 *
 * Message facts: from, fromName, subject, snippet, signals (a Signals),
 * isReplyToMine, providerCategory, hasTimelyItem.
 *
 * Rules: field, pattern, bucket ('people'|'feeds'|null), category.
 */
final class Classifier
{
    public const NEWSLETTER = 'Newsletter';
    public const RECEIPT = 'Receipt';
    public const NOTIFICATION = 'Notification';
    public const SOCIAL = 'Social';
    public const PROMOTION = 'Promotion';
    public const UPDATES = 'Updates';
    public const DELIVERY = 'Delivery';
    public const TRAVEL = 'Travel';
    public const OTP = 'OTP';

    private const SPACE = '[\s\x{A0}\x{1680}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}\x{FEFF}]';

    /**
     * @param list<array<string, mixed>> $rules
     * @param list<string> $userFirstNames lower-cased
     */
    public function __construct(private readonly array $rules = [], private readonly array $userFirstNames = [])
    {
    }

    // ---- small tools ------------------------------------------------------------------

    public static function rx(string $name, string $subject): bool
    {
        return preg_match(ClassifierData::RX[$name], self::clean($subject)) === 1;
    }

    private static function hit(string $pattern, string $subject): bool
    {
        return preg_match($pattern, self::clean($subject)) === 1;
    }

    /** Text PCRE can read: broken bytes become a replacement mark. */
    public static function clean(string $s): string
    {
        return mb_check_encoding($s, 'UTF-8') ? $s : mb_scrub($s, 'UTF-8');
    }

    public static function lower(string $s): string
    {
        return mb_strtolower(self::clean($s), 'UTF-8');
    }

    public static function trim(string $s): string
    {
        return (string) preg_replace('~^' . self::SPACE . '+|' . self::SPACE . '+$~uD', '', self::clean($s));
    }

    private static function ltrim(string $s): string
    {
        return (string) preg_replace('~^' . self::SPACE . '+~uD', '', self::clean($s));
    }

    public static function localPart(string $address): string
    {
        $at = strpos($address, '@');
        return self::lower($at === false ? $address : substr($address, 0, $at));
    }

    public static function domainOf(string $address): string
    {
        $at = strpos($address, '@');
        return $at === false ? '' : self::lower(substr($address, $at + 1));
    }

    /** Whether [$domain] is one of [$domains] or under one. */
    private static function onDomain(string $domain, array $domains): bool
    {
        if ($domain === '') {
            return false;
        }
        if (isset($domains[$domain])) {
            return true;
        }
        // Every parent of a.b.c.com: b.c.com, c.com, com.
        $pos = 0;
        while (($pos = strpos($domain, '.', $pos)) !== false) {
            $pos++;
            if (isset($domains[substr($domain, $pos)])) {
                return true;
            }
        }
        return false;
    }

    /**
     * An address as the app stores it: trimmed, lower-cased, no angle
     * brackets; for Gmail, dots and any +tag in the name are dropped.
     */
    public static function normalizeAddress(string $raw): string
    {
        $s = self::lower(self::trim($raw));
        if (str_starts_with($s, '<') && str_ends_with($s, '>')) {
            $s = substr($s, 1, -1);
        }
        $at = strrpos($s, '@');
        if ($at === false || $at <= 0) {
            return $s;
        }
        $local = substr($s, 0, $at);
        $domain = substr($s, $at + 1);
        if ($domain === 'googlemail.com') {
            $domain = 'gmail.com';
        }
        if ($domain === 'gmail.com') {
            $plus = strpos($local, '+');
            if ($plus !== false && $plus > 0) {
                $local = substr($local, 0, $plus);
            }
            $local = str_replace('.', '', $local);
        }
        return $local . '@' . $domain;
    }

    // ---- rules --------------------------------------------------------------------------

    public static function ruleMatchesSender(array $rule, array $s): bool
    {
        $p = self::lower((string) $rule['pattern']);
        $domain = self::domainOf((string) $s['address']);
        switch ($rule['field']) {
            case 'sender':
                if (self::lower((string) $s['address']) === $p) {
                    return true;
                }
                foreach ($s['otherAddresses'] ?? [] as $a) {
                    if (self::lower((string) $a) === $p) {
                        return true;
                    }
                }
                return false;
            case 'domain':
                return $domain === $p || str_ends_with($domain, '.' . $p);
            case 'listId':
                return in_array($p, $s['listIds'] ?? [], true);
            default:
                return false;
        }
    }

    public static function ruleMatchesMessage(array $rule, array $m): bool
    {
        $p = self::lower((string) $rule['pattern']);
        $from = (string) $m['from'];
        switch ($rule['field']) {
            case 'sender':
                return self::lower($from) === $p;
            case 'domain':
                $d = self::domainOf($from);
                return $d === $p || str_ends_with($d, '.' . $p);
            case 'listId':
                return (self::signalsOf($m)->listIdValue ?? '') === $p;
            case 'subject':
                $subject = self::lower((string) ($m['subject'] ?? ''));
                foreach (explode('|', $p) as $w) {
                    $w = self::trim($w);
                    if ($w !== '' && str_contains($subject, $w)) {
                        return true;
                    }
                }
                return false;
            default:
                return false;
        }
    }

    public static function describeRule(array $rule): string
    {
        $parts = [];
        if (($rule['bucket'] ?? null) !== null) {
            $parts[] = $rule['bucket'] === 'feeds' ? 'Feed or Noise' : 'Chats';
        }
        if (($rule['category'] ?? null) !== null) {
            $parts[] = (string) $rule['category'];
        }
        $target = implode(' · ', $parts);
        $pattern = (string) $rule['pattern'];
        return match ($rule['field']) {
            'sender' => "Mail from $pattern → $target",
            'domain' => "Mail from anyone at $pattern → $target",
            'listId' => "The mailing list $pattern → $target",
            'subject' => 'Subject contains ' . implode(' or ', array_map(static fn (string $w): string => "'" . self::trim($w) . "'", explode('|', $pattern))) . " → $target",
            default => $rule['field'] . " $pattern → $target",
        };
    }

    private static function signalsOf(array $m): Signals
    {
        $s = $m['signals'] ?? null;
        return $s instanceof Signals ? $s : Signals::decode(is_string($s) ? $s : null);
    }

    // ---- the sender ---------------------------------------------------------------------

    /**
     * Who a sender is. Order: the user's own move, the user's rules, signs
     * of a person (address book, wrote to them), then signs of a mailer.
     *
     * @return array{bucket: string, category: ?string, reasons: list<string>, source: string}
     */
    public function classifySender(array $s): array
    {
        $s += [
            'otherAddresses' => [], 'messagesReceived' => 1, 'messagesSentTo' => 0, 'repliesToAutomated' => 0, 'recipientNames' => [],
            'messagesWithTimely' => 0, 'name' => '', 'userHasWrittenTo' => false, 'inAddressBook' => false, 'messagesWithBulkHeaders' => 0,
            'messagesWithKnownSignals' => 0, 'listIds' => [], 'override' => null, 'providerCategories' => [], 'subjects' => [],
        ];
        if ($s['override'] !== null) {
            return self::decision((string) $s['override'], null, ['Moved by you'], 'override');
        }
        foreach ($this->rules as $r) {
            if (($r['bucket'] ?? null) !== null && self::ruleMatchesSender($r, $s)) {
                return self::decision((string) $r['bucket'], $r['category'] ?? null, [self::describeRule($r)], 'rule');
            }
        }

        $address = (string) $s['address'];
        $local = self::localPart($address);
        $domain = self::domainOf($address);
        $name = (string) $s['name'];
        $reasons = [];
        $hardLocal = self::rx('bulkLocalParts', $local);
        $softLocal = self::rx('softLocalParts', $local);
        $domainHit = self::isListedSendingDomain($domain);
        $sendingSub = self::isSendingSubdomain($domain);
        $withHeaders = (int) $s['messagesWithBulkHeaders'];
        $known = (int) $s['messagesWithKnownSignals'];
        $headerRatio = $known === 0 ? 0.0 : $withHeaders / $known;
        $bulkByHeaders = $withHeaders > 0 && ($headerRatio >= 0.5 || $withHeaders >= 3);
        [$subjectCat, $subjectShare] = self::subjectProfile($s['subjects']);
        $subjectsAutomated = $subjectCat !== null && count($s['subjects']) >= 2 && $subjectShare >= 0.6;
        $nameAutomated = $name !== '' && self::rx('automatedName', $name) && ($softLocal || $subjectsAutomated || $known >= 3);

        if ($bulkByHeaders) {
            $reasons[] = $withHeaders === $known ? 'Bulk-mail headers on every message' : "Bulk-mail headers on $withHeaders of $known messages";
        }
        if ($hardLocal) {
            $reasons[] = "Automated address ($local@)";
        }
        if ($domainHit) {
            $reasons[] = "Known sending platform ($domain)";
        }
        if ($sendingSub) {
            $reasons[] = "Dedicated sending domain ($domain)";
        }
        if ($softLocal && ($bulkByHeaders || $domainHit || $sendingSub)) {
            $reasons[] = "Generic address ($local@) with bulk signals";
        }
        if ($subjectsAutomated) {
            $reasons[] = 'Subjects look automated (' . (int) round($subjectShare * 100) . "% $subjectCat)";
        }
        if ($nameAutomated) {
            $reasons[] = "Automated sender name ($name)";
        }

        $sendsTimely = (int) $s['messagesWithTimely'] > 0;
        if ($sendsTimely) {
            $reasons[] = 'Sends codes, shipping or travel updates';
        }
        $strong = $bulkByHeaders || $hardLocal || $sendingSub || $domainHit || $sendsTimely;
        $providerPrimary = (int) ($s['providerCategories']['primary'] ?? 0);
        $providerBulk = 0;
        foreach ($s['providerCategories'] as $cat => $n) {
            if ($cat !== 'primary') {
                $providerBulk += (int) $n;
            }
        }
        $providerTotal = $providerPrimary + $providerBulk;

        if ($s['inAddressBook']) {
            return self::decision('people', null, ['In your contacts'], 'people-signal');
        }

        if ((int) $s['messagesReceived'] === 0 && (int) $s['messagesSentTo'] > 0) {
            foreach ([$address, ...$s['otherAddresses']] as $a) {
                $machine = self::machineAddressReason((string) $a);
                if ($machine !== null) {
                    return self::decision('feeds', null, ["Automated address ($machine)"], 'auto');
                }
            }
            if ((int) $s['repliesToAutomated'] * 2 >= (int) $s['messagesSentTo']) {
                return self::decision('feeds', null, ['Your mail to it answered automated mail'], 'auto');
            }
            if ($s['recipientNames'] !== []) {
                $all = true;
                foreach ($s['recipientNames'] as $n) {
                    if (!self::rx('automatedName', (string) $n)) {
                        $all = false;
                        break;
                    }
                }
                if ($all) {
                    return self::decision('feeds', null, ['Your mail to it used an automated name'], 'auto');
                }
            }
            return self::decision('people', null, ['You wrote to this person'], 'people-signal');
        }
        if ($s['userHasWrittenTo']) {
            $plainlyMailer = $providerTotal > 0 && $providerBulk / $providerTotal >= 0.8 && ($bulkByHeaders || $hardLocal || $sendingSub);
            if (!$plainlyMailer) {
                return self::decision('people', null, ['You have written to this address'], 'people-signal');
            }
            $reasons[] = 'You wrote to this sender, but it is a mailer';
        }

        if ($providerTotal > 0) {
            if ($providerBulk / $providerTotal >= 0.5) {
                // The largest bulk category; the first one wins a tie.
                $top = null;
                $topN = -1;
                foreach ($s['providerCategories'] as $cat => $n) {
                    if ($cat !== 'primary' && (int) $n > $topN) {
                        $top = (string) $cat;
                        $topN = (int) $n;
                    }
                }
                array_unshift($reasons, 'Gmail files this sender under ' . self::providerLabel((string) $top));
                return self::decision('feeds', $this->senderCategory($s, $hardLocal, $subjectsAutomated ? $subjectCat : null, $top), $reasons, 'auto');
            }
            if (!$strong) {
                return self::decision('people', null, ['Gmail files this sender under Primary'], 'auto');
            }
        }

        if ($strong || $domainHit || $subjectsAutomated || $nameAutomated) {
            return self::decision('feeds', $this->senderCategory($s, $hardLocal, $subjectsAutomated ? $subjectCat : null, null), $reasons, 'auto');
        }
        return self::decision('people', null, ['No bulk signals'], 'auto');
    }

    /** @return array{bucket: string, category: ?string, reasons: list<string>, source: string} */
    private static function decision(string $bucket, ?string $category, array $reasons, string $source): array
    {
        return ['bucket' => $bucket, 'category' => $category, 'reasons' => array_values($reasons), 'source' => $source];
    }

    private static function providerLabel(string $category): string
    {
        return match ($category) {
            'updates' => 'Updates',
            'promotions' => 'Promotions',
            'social' => 'Social',
            'forums' => 'Forums',
            default => $category,
        };
    }

    /**
     * The most common strict subject category and the share of all subjects
     * that matched any strict pattern. Replies and forwards never match.
     *
     * @param list<string> $subjects
     * @return array{0: ?string, 1: float}
     */
    public static function subjectProfile(array $subjects): array
    {
        if ($subjects === []) {
            return [null, 0.0];
        }
        $counts = [];
        foreach ($subjects as $subject) {
            $subject = (string) $subject;
            if (self::rx('replyPrefix', $subject)) {
                continue;
            }
            $c = self::strictSubjectCategory($subject);
            if ($c !== null) {
                $counts[$c] = ($counts[$c] ?? 0) + 1;
            }
        }
        if ($counts === []) {
            return [null, 0.0];
        }
        $top = null;
        $topN = -1;
        foreach ($counts as $c => $n) {
            if ($n > $topN) {
                $top = (string) $c;
                $topN = $n;
            }
        }
        return [$top, array_sum($counts) / count($subjects)];
    }

    private static function strictSubjectCategory(string $subject): ?string
    {
        if (self::rx('socialSubject', $subject)) {
            return self::SOCIAL;
        }
        if (self::rx('otpSubject', $subject) && !self::rx('codeOffer', $subject)) {
            return self::NOTIFICATION;
        }
        if (self::rx('travelSubject', $subject)) {
            return self::TRAVEL;
        }
        if (self::rx('deliverySubject', $subject) && !self::rx('moneyMoving', $subject)) {
            return self::DELIVERY;
        }
        if (self::rx('strictReceipt', $subject)) {
            return self::RECEIPT;
        }
        if (self::rx('strictNotification', $subject)) {
            return self::NOTIFICATION;
        }
        if (self::rx('strictPromotion', $subject)) {
            return self::PROMOTION;
        }
        if (self::rx('strictNewsletter', $subject)) {
            return self::NEWSLETTER;
        }
        return null;
    }

    /** OTP, Travel or Delivery from the subject and sender alone; null when none fits. */
    public static function specificCategory(string $subject, string $from): ?string
    {
        $at = strrpos($from, '@');
        $domain = $at === false ? '' : self::lower(substr($from, $at + 1));
        $local = $at === false ? '' : self::lower(substr($from, 0, $at));
        if (self::rx('otpSubject', $subject) && !self::rx('codeOffer', $subject)) {
            return self::OTP;
        }
        if (self::rx('travelSubject', $subject)) {
            return self::TRAVEL;
        }
        if (self::onDomain($domain, ClassifierData::TRAVEL_DOMAINS) && self::rx('travelBookingWord', $subject)) {
            return self::TRAVEL;
        }
        if (self::rx('deliverySubject', $subject) && !self::rx('moneyMoving', $subject)) {
            return self::DELIVERY;
        }
        if (self::onDomain($domain, ClassifierData::DELIVERY_DOMAINS) || self::rx('deliveryLocalPart', $local)) {
            return self::DELIVERY;
        }
        return null;
    }

    /** Why an address is a machine's and not a person's, or null when it may be a person's. */
    public static function machineAddressReason(string $address): ?string
    {
        $a = self::lower($address);
        $at = strrpos($a, '@');
        if ($at === false || $at < 1) {
            return null;
        }
        $local = substr($a, 0, $at);
        $domain = substr($a, $at + 1);
        $labels = explode('.', $domain);
        if (self::rx('bulkLocalParts', $local)) {
            return 'automated name ' . (mb_strlen($local, 'UTF-8') > 20 ? 'part' : $local) . '@';
        }
        if (str_contains($local, '=') || self::rx('bounceToken', $local) || self::rx('plusToken', $local)) {
            return 'bounce or reply token';
        }
        $alnum = (string) preg_replace('~[^a-z0-9]~u', '', self::clean($local));
        if ((strlen($alnum) >= 24 && self::hit('~\d~', $alnum)) || self::hit('~^\d[a-z0-9]{15,}$~uD', $local)) {
            return 'random token';
        }
        if (count($labels) > 2) {
            foreach (array_slice($labels, 0, count($labels) - 2) as $l) {
                if (str_contains($l, 'bounce') || $l === 'bnc' || $l === 'mta' || $l === 'smtp') {
                    return 'bounce domain';
                }
            }
        }
        if (self::onDomain($domain, ClassifierData::SENDING_PLATFORMS)) {
            return 'mailing platform';
        }
        if (count($labels) >= 3) {
            $first = $labels[0];
            $sharedWithPeople = ['mail' => 1, 'email' => 1, 'm' => 1, 's' => 1, 'go' => 1, 't' => 1, 'e' => 1];
            $always = ['service' => 1, 'services' => 1, 'notice' => 1, 'notices' => 1, 'mailings' => 1, 'subscriptions' => 1, 'e' => 1, 'em' => 1, 't' => 1, 'tr' => 1, 'tx' => 1, 's' => 1, 'go' => 1];
            if ((isset(ClassifierData::SENDING_SUBDOMAIN_LABELS[$first]) && !isset($sharedWithPeople[$first])) || isset($always[$first])) {
                return "sending domain $domain";
            }
        }
        return null;
    }

    public static function isListedSendingDomain(string $domain): bool
    {
        return self::onDomain(self::lower($domain), ClassifierData::BULK_DOMAINS);
    }

    /** `e.brand.com`: three or more labels whose first is a known sending label. */
    public static function isSendingSubdomain(string $domain): bool
    {
        $labels = explode('.', self::lower($domain));
        return count($labels) >= 3 && isset(ClassifierData::SENDING_SUBDOMAIN_LABELS[$labels[0]]);
    }

    private function senderCategory(array $s, bool $hardLocal, ?string $subjectCat, ?string $providerTop): string
    {
        $domain = self::domainOf((string) $s['address']);
        if (self::onDomain($domain, ClassifierData::SOCIAL_DOMAINS)) {
            return self::SOCIAL;
        }
        switch ($providerTop) {
            case 'promotions':
                return $subjectCat === self::RECEIPT ? self::RECEIPT : self::PROMOTION;
            case 'social':
                return self::SOCIAL;
            case 'forums':
                return self::NEWSLETTER;
        }
        if ($subjectCat !== null) {
            return $subjectCat;
        }
        if (self::onDomain($domain, ClassifierData::DELIVERY_DOMAINS)) {
            return self::DELIVERY;
        }
        if (self::onDomain($domain, ClassifierData::TRAVEL_DOMAINS)) {
            return self::TRAVEL;
        }
        $lp = self::localPart((string) $s['address']);
        if (self::rx('deliveryLocalPart', $lp)) {
            return self::DELIVERY;
        }
        if (self::hit('~receipt|order|billing|invoice|statement|payment~u', $lp)) {
            return self::RECEIPT;
        }
        if (self::hit('~newsletter|digest|news|weekly|daily~u', $lp)) {
            return self::NEWSLETTER;
        }
        if (self::hit('~marketing|promo|offers?|deals?|sales?~u', $lp)) {
            return self::PROMOTION;
        }
        if ($providerTop === 'updates') {
            return self::hit('~notif|alert|security|verif|no-?reply|do-?not-?reply|account|password~u', $lp) ? self::NOTIFICATION : self::UPDATES;
        }
        if (($s['listIds'] ?? []) !== [] || ((int) $s['messagesWithBulkHeaders'] > 0 && !$hardLocal)) {
            return self::NEWSLETTER;
        }
        return self::NOTIFICATION;
    }

    // ---- one email ----------------------------------------------------------------------

    /** A mailer's email that is plainly personal shows in Chats, that one email only. */
    public function isPersonalException(array $m): bool
    {
        if (!empty($m['isReplyToMine'])) {
            return true;
        }
        if (self::signalsOf($m)->any()) {
            return false;
        }
        if (!empty($m['hasTimelyItem']) || in_array($m['providerCategory'] ?? null, ['updates', 'promotions', 'social', 'forums'], true)) {
            return false;
        }
        return $this->greetsUserByName((string) ($m['snippet'] ?? ''));
    }

    /** "Hi Clay," / "Hello Clay" / "Dear Clay" at the start. */
    public function greetsUserByName(string $snippet): bool
    {
        if ($this->userFirstNames === []) {
            return false;
        }
        $head = self::lower(self::ltrim($snippet));
        if (mb_strlen($head, 'UTF-8') < 3) {
            return false;
        }
        if (preg_match('~^(hi|hello|hey|dear|good (morning|afternoon|evening))' . self::SPACE . '+([a-z\'’\-]+)~u', $head, $m) !== 1) {
            return false;
        }
        return in_array($m[3], $this->userFirstNames, true);
    }

    /** The tag for one email. The user's rules first, then its content, else the sender's own. */
    public function messageCategory(array $m, ?string $senderDefault = null): ?string
    {
        foreach ($this->rules as $r) {
            if (($r['category'] ?? null) !== null && self::ruleMatchesMessage($r, $m)) {
                return (string) $r['category'];
            }
        }
        return self::inferCategory($m) ?? $senderDefault;
    }

    /** A tag read from the email itself; null when nothing fits. */
    public static function inferCategory(array $m): ?string
    {
        $subject = (string) ($m['subject'] ?? '');
        $from = (string) $m['from'];
        $domain = self::domainOf($from);
        $provider = $m['providerCategory'] ?? null;
        $signals = self::signalsOf($m);
        if (self::onDomain($domain, ClassifierData::SOCIAL_DOMAINS) || self::rx('socialSubject', $subject) || $provider === 'social') {
            return self::SOCIAL;
        }
        $specific = self::specificCategory($subject, $from);
        if ($specific !== null) {
            return $specific;
        }
        if (self::rx('receiptSubject', $subject)) {
            return self::RECEIPT;
        }
        if (self::rx('notificationSubject', $subject)) {
            return self::NOTIFICATION;
        }
        if (self::rx('promotionSubject', $subject) || $provider === 'promotions') {
            return self::PROMOTION;
        }
        if (self::rx('newsletterSubject', $subject) || $signals->listId || $signals->listUnsubscribe || $provider === 'forums') {
            return self::NEWSLETTER;
        }
        return null;
    }

    /** The user's first names as the sorter wants them, from display names. */
    public static function firstNames(array $displayNames): array
    {
        $out = [];
        foreach ($displayNames as $display) {
            $t = self::trim((string) $display);
            if ($t === '') {
                continue;
            }
            $first = preg_split('~' . self::SPACE . '+~u', $t)[0] ?? '';
            $first = (string) preg_replace('~[^a-z\-]~u', '', self::lower($first));
            if (strlen($first) >= 2) {
                $out[$first] = true;
            }
        }
        return array_keys($out);
    }
}
