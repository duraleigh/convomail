<?php
declare(strict_types=1);

namespace Precis;

/**
 * Takes the header facts of an email, files them, and decides where the
 * email and its sender belong: Chats, Feed or Noise.
 *
 * What a sender is rests on everything known about it. For mail older than
 * the helper's own reading, that is what a device knew when it first sent its
 * state up (the "seed"); to that the helper adds every email it has read
 * since.
 */
final class Sorter
{
    private ?Classifier $classifier = null;

    /** @var array<string, string>|null address => sender key */
    private ?array $addr = null;

    /** @var array<string, true>|null the owner's own addresses */
    private ?array $me = null;

    public function __construct(private readonly Store $store)
    {
    }

    /** Forget what was read from the store; call after rules, names or addresses change. */
    public function reset(): void
    {
        $this->classifier = null;
        $this->addr = null;
        $this->me = null;
    }

    public function classifier(): Classifier
    {
        if ($this->classifier === null) {
            $rules = [];
            foreach ($this->store->itemsOf('rule') as $r) {
                $rules[] = ['field' => (string) ($r['field'] ?? ''), 'pattern' => (string) ($r['pattern'] ?? ''), 'bucket' => $r['bucket'] ?? null, 'category' => $r['category'] ?? null, 'at' => (int) ($r['at'] ?? 0), 'uid' => (string) ($r['uid'] ?? '')];
            }
            // Oldest first, as the app applies them.
            usort($rules, static fn (array $a, array $b): int => [$a['at'], $a['uid']] <=> [$b['at'], $b['uid']]);
            $names = $this->store->item('names', 'user')['first'] ?? [];
            $this->classifier = new Classifier($rules, array_values(array_map('strval', is_array($names) ? $names : [])));
        }
        return $this->classifier;
    }

    /** The sender key an address belongs to: 'me' for the owner's own, else the person it was merged into, else itself. */
    public function resolve(string $address): string
    {
        $n = Classifier::normalizeAddress($address);
        if ($this->me === null) {
            $this->me = [];
            foreach (array_keys($this->store->itemsOf('me')) as $a) {
                $this->me[(string) $a] = true;
            }
            $this->addr = [];
            foreach ($this->store->itemsOf('addr') as $a => $d) {
                $this->addr[(string) $a] = (string) ($d['key'] ?? $a);
            }
        }
        if (isset($this->me[$n])) {
            return 'me';
        }
        return $this->addr[$n] ?? $n;
    }

    /** Remembers the owner's sending addresses read from Gmail itself. */
    public function learnOwnAddresses(array $addresses): void
    {
        foreach ($addresses as $a) {
            $email = Classifier::normalizeAddress((string) ($a['email'] ?? ''));
            if ($email !== '' && $this->store->item('me', $email) === null) {
                $this->store->put('me', $email, ['name' => (string) ($a['name'] ?? '')]);
            }
        }
        $this->reset();
    }

    // ---- taking in emails ------------------------------------------------------------------

    /**
     * Files the header facts of emails as Gmail gave them (id => metadata, or
     * null for one that is gone) and sorts every sender they touch.
     *
     * @param array<string, array<string, mixed>|null> $metas
     * @return array{stored: int, senders: int}
     */
    public function takeIn(int $accountId, array $metas): array
    {
        $touched = [];
        $stored = 0;
        foreach ($metas as $gmailId => $meta) {
            if ($meta === null) {
                $this->store->db->run('UPDATE {emails} SET gone = 1 WHERE account_id = ? AND gmail_id = ?', [$accountId, (string) $gmailId]);
                continue;
            }
            foreach ($this->file($accountId, $meta) as $key) {
                $touched[$key] = true;
            }
            $stored++;
        }
        unset($touched['me'], $touched['']);
        foreach (array_keys($touched) as $key) {
            $this->resort((string) $key);
        }
        return ['stored' => $stored, 'senders' => count($touched)];
    }

    /**
     * Stores one email's facts. Returns the sender keys whose standing may
     * have changed. Drafts and chat lines are passed over.
     *
     * @return list<string>
     */
    private function file(int $accountId, array $meta): array
    {
        $labels = array_map('strval', $meta['labelIds'] ?? []);
        if (in_array('DRAFT', $labels, true) || in_array('CHAT', $labels, true)) {
            return [];
        }
        $h = [];
        foreach ($meta['payload']['headers'] ?? [] as $header) {
            $name = strtolower((string) ($header['name'] ?? ''));
            $h[$name] ??= (string) ($header['value'] ?? '');
        }
        $from = Addr::parseList($h['from'] ?? null)[0] ?? ['name' => '', 'address' => ''];
        $fromKey = $from['address'] === '' ? '' : $this->resolve($from['address']);
        $isMine = in_array('SENT', $labels, true) || $fromKey === 'me';
        $gone = in_array('TRASH', $labels, true) || in_array('SPAM', $labels, true);
        $signals = Signals::fromHeaders($h['list-unsubscribe'] ?? null, $h['list-id'] ?? null, $h['list-post'] ?? null, $h['feedback-id'] ?? null, $h['precedence'] ?? null, $h['auto-submitted'] ?? null);
        $category = '';
        foreach (['CATEGORY_PROMOTIONS' => 'promotions', 'CATEGORY_SOCIAL' => 'social', 'CATEGORY_UPDATES' => 'updates', 'CATEGORY_FORUMS' => 'forums', 'CATEGORY_PERSONAL' => 'primary'] as $label => $name) {
            if (in_array($label, $labels, true)) {
                $category = $name;
                break;
            }
        }
        $db = $this->store->db;
        $row = [
            'thread_id' => (string) ($meta['threadId'] ?? ''),
            'message_id' => self::cap(trim($h['message-id'] ?? ''), 400),
            'in_reply_to' => self::cap(self::firstId($h['in-reply-to'] ?? ''), 400),
            'from_addr' => self::cap(Classifier::normalizeAddress($from['address']), 191),
            'from_key' => self::cap($fromKey, 191),
            'from_name' => self::cap($from['name'], 255),
            'rcpt' => '',
            'subject' => self::cap(Addr::decodeWords($h['subject'] ?? ''), 1000),
            'snippet' => self::cap(html_entity_decode((string) ($meta['snippet'] ?? ''), ENT_QUOTES | ENT_HTML5, 'UTF-8'), 300),
            'at' => intdiv((int) ($meta['internalDate'] ?? 0), 1000),
            'is_from_me' => (int) $isMine,
            'signals' => self::cap($signals->encode(), 255),
            'provider_category' => $category,
            'unread' => (int) in_array('UNREAD', $labels, true),
            'gone' => (int) $gone,
        ];
        $gmailId = (string) ($meta['id'] ?? '');
        $existing = $db->val('SELECT id FROM {emails} WHERE account_id = ? AND gmail_id = ?', [$accountId, $gmailId]);
        if ($existing !== null) {
            $id = (int) $existing;
            $db->upsert('emails', ['id' => $id], $row);
        } else {
            $id = $db->insert('emails', ['account_id' => $accountId, 'gmail_id' => $gmailId] + $row);
        }
        $touched = [$fromKey];
        if ($isMine) {
            $db->run('DELETE FROM {rcpts} WHERE email_id = ?', [$id]);
            $seen = [];
            foreach (['to', 'cc', 'bcc'] as $role) {
                foreach (Addr::parseList($h[$role] ?? null) as $r) {
                    $key = $this->resolve($r['address']);
                    if ($key === 'me' || isset($seen[$key . '|' . $role])) {
                        continue;
                    }
                    $seen[$key . '|' . $role] = true;
                    $db->insert('rcpts', ['email_id' => $id, 'skey' => self::cap($key, 191), 'role' => $role, 'name' => self::cap($r['name'], 255)]);
                    $touched[] = $key;
                }
            }
            // A reply from the owner can make the email it answers personal.
            if ($row['message_id'] !== '') {
                foreach ($db->all('SELECT DISTINCT from_key FROM {emails} WHERE in_reply_to = ? AND is_from_me = 0', [$row['message_id']]) as $r) {
                    $touched[] = (string) $r['from_key'];
                }
            }
        }
        return $touched;
    }

    /** The first `<...>` in an In-Reply-To line. */
    private static function firstId(string $v): string
    {
        return preg_match('~<[^<>\s]+>~', $v, $m) === 1 ? $m[0] : trim($v);
    }

    private static function cap(string $s, int $max): string
    {
        $s = Classifier::clean($s);
        return mb_strlen($s, 'UTF-8') <= $max ? $s : mb_substr($s, 0, $max, 'UTF-8');
    }

    // ---- what is known about a sender ---------------------------------------------------------

    /** @return array{seed: array<string, mixed>, at: int} */
    private function seed(string $skey): array
    {
        $row = $this->store->db->one('SELECT seed, seed_at FROM {sender_facts} WHERE skey = ?', [$skey]);
        return $row === null ? ['seed' => [], 'at' => 0] : ['seed' => Store::decode((string) $row['seed']), 'at' => (int) $row['seed_at']];
    }

    /** Stores what a device knew about a sender, as of [$at]. */
    public function setSeed(string $skey, array $facts, int $at): void
    {
        $this->store->db->upsert('sender_facts', ['skey' => $skey], ['seed' => Store::json($facts), 'seed_at' => $at]);
    }

    /**
     * Everything the sorter weighs about a sender: the seed, plus the
     * helper's own reading since the seed.
     *
     * @return array<string, mixed>
     */
    public function facts(string $skey): array
    {
        $db = $this->store->db;
        ['seed' => $seed, 'at' => $since] = $this->seed($skey);
        $item = $this->store->item('sender', $skey) ?? [];

        // The sender's own address and any merged into it.
        $others = str_contains($skey, '@') ? [$skey => true] : [];
        $this->resolve($skey);
        foreach ($this->addr ?? [] as $address => $key) {
            if ($key === $skey) {
                $others[$address] = true;
            }
        }
        $top = $db->one('SELECT from_addr AS a, COUNT(*) AS n FROM {emails} WHERE from_key = ? AND is_from_me = 0 AND at > ? GROUP BY from_addr ORDER BY n DESC, from_addr LIMIT 1', [$skey, $since]);
        $address = (string) ($seed['address'] ?? ($top['a'] ?? (array_key_first($others) ?? $skey)));
        unset($others[$address]);
        foreach ($seed['otherAddresses'] ?? [] as $a) {
            if ($a !== $address) {
                $others[(string) $a] = true;
            }
        }

        $agg = $db->one(
            'SELECT COUNT(*) AS received,
                    SUM(CASE WHEN signals IS NOT NULL THEN 1 ELSE 0 END) AS known,
                    SUM(CASE WHEN signals IS NOT NULL AND signals <> \'\' THEN 1 ELSE 0 END) AS bulk
             FROM {emails} WHERE from_key = ? AND is_from_me = 0 AND at > ?',
            [$skey, $since],
        ) ?? [];
        $name = $db->val('SELECT from_name FROM {emails} WHERE from_key = ? AND is_from_me = 0 AND from_name <> \'\' AND at > ? ORDER BY at DESC, id DESC LIMIT 1', [$skey, $since]);

        $listIds = [];
        foreach ($seed['listIds'] ?? [] as $l) {
            $listIds[(string) $l] = true;
        }
        foreach ($db->all('SELECT DISTINCT signals FROM {emails} WHERE from_key = ? AND is_from_me = 0 AND at > ? AND signals LIKE ?', [$skey, $since, '%;%']) as $r) {
            $v = Classifier::lower(trim(substr((string) $r['signals'], strpos((string) $r['signals'], ';') + 1)));
            if ($v !== '') {
                $listIds[$v] = true;
            }
        }

        $provider = [];
        foreach ($seed['providerCategories'] ?? [] as $cat => $n) {
            $provider[(string) $cat] = (int) $n;
        }
        foreach ($db->all('SELECT provider_category AS cat, COUNT(*) AS n FROM {emails} WHERE from_key = ? AND is_from_me = 0 AND at > ? AND provider_category IS NOT NULL AND provider_category <> \'\' GROUP BY provider_category', [$skey, $since]) as $r) {
            $provider[(string) $r['cat']] = ($provider[(string) $r['cat']] ?? 0) + (int) $r['n'];
        }
        ksort($provider);

        $subjects = [];
        foreach ($db->all('SELECT subject FROM {emails} WHERE from_key = ? AND is_from_me = 0 AND gone = 0 AND at > ? ORDER BY at DESC, id DESC LIMIT 20', [$skey, $since]) as $r) {
            $subjects[] = (string) $r['subject'];
        }
        foreach ($seed['subjects'] ?? [] as $s) {
            $subjects[] = (string) $s;
        }
        $subjects = array_slice($subjects, 0, 20);

        $sentTo = (int) $db->val('SELECT COUNT(DISTINCT r.email_id) FROM {rcpts} r JOIN {emails} e ON e.id = r.email_id WHERE r.skey = ? AND e.is_from_me = 1 AND e.at > ?', [$skey, $since]);
        $written = (int) $db->val('SELECT COUNT(DISTINCT r.email_id) FROM {rcpts} r JOIN {emails} e ON e.id = r.email_id WHERE r.skey = ? AND r.role IN (\'to\', \'cc\') AND e.is_from_me = 1 AND e.at > ?', [$skey, $since]);
        $toAutomated = (int) $db->val(
            'SELECT COUNT(DISTINCT e.id) FROM {rcpts} r JOIN {emails} e ON e.id = r.email_id
             WHERE r.skey = ? AND e.is_from_me = 1 AND e.at > ? AND e.in_reply_to <> \'\'
               AND EXISTS (SELECT 1 FROM {emails} o WHERE o.message_id = e.in_reply_to AND o.is_from_me = 0 AND o.cls = \'feeds\')',
            [$skey, $since],
        );
        $recipientNames = [];
        foreach ($seed['recipientNames'] ?? [] as $n) {
            $recipientNames[(string) $n] = true;
        }
        foreach ($db->all('SELECT DISTINCT r.name FROM {rcpts} r JOIN {emails} e ON e.id = r.email_id WHERE r.skey = ? AND r.name <> \'\' AND e.is_from_me = 1 AND e.at > ? LIMIT 10', [$skey, $since]) as $r) {
            $recipientNames[(string) $r['name']] = true;
        }

        $override = ($item['src'] ?? '') === 'override' ? (($item['cls'] ?? '') === 'feeds' ? 'feeds' : 'people') : null;
        return [
            'address' => $address,
            'otherAddresses' => array_map('strval', array_keys($others)),
            'messagesReceived' => (int) ($seed['messagesReceived'] ?? 0) + (int) ($agg['received'] ?? 0),
            'messagesSentTo' => (int) ($seed['messagesSentTo'] ?? 0) + $sentTo,
            'repliesToAutomated' => (int) ($seed['repliesToAutomated'] ?? 0) + $toAutomated,
            'recipientNames' => array_slice(array_map('strval', array_keys($recipientNames)), 0, 10),
            'messagesWithTimely' => (int) ($seed['messagesWithTimely'] ?? 0),
            'name' => (string) ($name ?? ($seed['name'] ?? ($item['name'] ?? ''))),
            'userHasWrittenTo' => !empty($seed['userHasWrittenTo']) || $written > 0,
            'inAddressBook' => $this->store->item('book', $skey) !== null,
            'messagesWithBulkHeaders' => (int) ($seed['messagesWithBulkHeaders'] ?? 0) + (int) ($agg['bulk'] ?? 0),
            'messagesWithKnownSignals' => (int) ($seed['messagesWithKnownSignals'] ?? 0) + (int) ($agg['known'] ?? 0),
            'listIds' => array_map('strval', array_keys($listIds)),
            'override' => $override,
            'providerCategories' => $provider,
            'subjects' => $subjects,
        ];
    }

    // ---- deciding ---------------------------------------------------------------------------------

    /**
     * Decides a sender again and every email the helper holds from it.
     * The owner's own move is never undone. Returns whether the sender's
     * place (person or not) changed.
     */
    public function resort(string $skey): bool
    {
        if ($skey === '' || $skey === 'me') {
            return false;
        }
        return (bool) $this->store->db->transaction(function () use ($skey): bool {
            $facts = $this->facts($skey);
            // Nothing from it and nothing to it: nothing to decide.
            if ($facts['messagesReceived'] === 0 && $facts['messagesSentTo'] === 0 && $facts['override'] === null) {
                return false;
            }
            $old = $this->store->item('sender', $skey);
            $d = $this->classifier()->classifySender($facts);
            $new = $old ?? [];
            $new['cls'] = $d['bucket'];
            if (($old['src'] ?? '') !== 'override') {
                $new['src'] = $d['source'];
            }
            // A tag the sender already has stays; a first one comes from the decision.
            if (($old['cat'] ?? null) === null) {
                $new['cat'] = $d['bucket'] === 'feeds' ? $d['category'] : null;
            }
            $new['reasons'] = implode(' · ', $d['reasons']);
            if (($new['name'] ?? '') === '' && $facts['name'] !== '') {
                $new['name'] = $facts['name'];
            }
            $new += ['pile' => null, 'counts' => false];
            $this->store->put('sender', $skey, $new);
            $this->sortEmailsOf($skey, $d['bucket'], $new['cat'] ?? null);
            return ($old['cls'] ?? null) !== $d['bucket'];
        });
    }

    /** Decides every email the helper holds from a sender, given the sender's place and tag. */
    private function sortEmailsOf(string $skey, string $senderBucket, ?string $senderDefault): void
    {
        $db = $this->store->db;
        $classifier = $this->classifier();
        foreach ($db->all('SELECT id, message_id, in_reply_to, from_addr, from_name, subject, snippet, signals, provider_category, is_from_me, cls, cat FROM {emails} WHERE from_key = ?', [$skey]) as $e) {
            $mine = (int) $e['is_from_me'] === 1;
            $m = [
                'from' => (string) $e['from_addr'],
                'fromName' => (string) $e['from_name'],
                'subject' => (string) $e['subject'],
                'snippet' => (string) $e['snippet'],
                'signals' => Signals::decode($e['signals'] === null ? null : (string) $e['signals']),
                'isReplyToMine' => $this->isReplyToMine((string) $e['in_reply_to']),
                'providerCategory' => $e['provider_category'] === null ? null : (string) $e['provider_category'],
                'hasTimelyItem' => false,
            ];
            $bucket = $mine ? 'people' : $senderBucket;
            if ($bucket === 'feeds' && $classifier->isPersonalException($m)) {
                $bucket = 'people';
            }
            $existing = $e['cat'] === null ? null : (string) $e['cat'];
            $category = null;
            if ($bucket === 'feeds') {
                $inferred = $classifier->messageCategory($m, $senderDefault);
                $category = $inferred === $senderDefault ? $existing : $inferred;
                if ($existing !== null && $existing !== $senderDefault) {
                    $category = $existing;
                }
            }
            // What the owner set on this one email wins.
            $fix = (string) $e['message_id'] === '' ? null : $this->store->item('msgfix', (string) $e['message_id']);
            if ($fix !== null) {
                if (in_array($fix['cls'] ?? null, ['people', 'feeds'], true)) {
                    $bucket = (string) $fix['cls'];
                }
                if (array_key_exists('cat', $fix)) {
                    $category = $fix['cat'] === null ? null : (string) $fix['cat'];
                }
                // An email in Chats carries no tag.
                if ($bucket !== 'feeds') {
                    $category = null;
                }
            }
            if ((string) $e['cls'] !== $bucket || $existing !== $category) {
                $db->run('UPDATE {emails} SET cls = ?, cat = ? WHERE id = ?', [$bucket, $category, (int) $e['id']]);
            }
            if (!$mine && (string) $e['message_id'] !== '') {
                $this->store->put('sort', (string) $e['message_id'], ['cls' => $bucket, 'cat' => $category]);
            }
        }
    }

    /** Whether an email answers one the owner sent. */
    private function isReplyToMine(string $inReplyTo): bool
    {
        if ($inReplyTo === '') {
            return false;
        }
        $db = $this->store->db;
        return $db->val('SELECT 1 FROM {emails} WHERE message_id = ? AND is_from_me = 1 LIMIT 1', [$inReplyTo]) !== null
            || $db->val('SELECT 1 FROM {my_ids} WHERE message_id = ?', [Store::key($inReplyTo)]) !== null;
    }

    /** Remembers Message-IDs of mail the owner sent before the helper started reading. */
    public function addMyIds(array $ids): void
    {
        $db = $this->store->db;
        foreach ($ids as $id) {
            $id = Store::key(trim((string) $id));
            if ($id !== '' && $db->val('SELECT 1 FROM {my_ids} WHERE message_id = ?', [$id]) === null) {
                $db->insert('my_ids', ['message_id' => $id]);
            }
        }
    }

    /**
     * Feed or Noise for a sender that is not a person, from its tag, its
     * emails by tag and how many are unread; null for a person.
     */
    public function pileOf(string $skey): ?string
    {
        $item = $this->store->item('sender', $skey);
        if ($item === null || ($item['cls'] ?? '') !== 'feeds') {
            return null;
        }
        ['seed' => $seed, 'at' => $since] = $this->seed($skey);
        $mail = [];
        foreach ($seed['mail'] ?? [] as $cat => $c) {
            $mail[(string) $cat] = ['total' => (int) ($c['total'] ?? 0), 'unread' => (int) ($c['unread'] ?? 0)];
        }
        $default = (string) ($item['cat'] ?? '');
        foreach ($this->store->db->all('SELECT COALESCE(cat, ?) AS c, COUNT(*) AS n, SUM(unread) AS u FROM {emails} WHERE from_key = ? AND is_from_me = 0 AND gone = 0 AND cls = \'feeds\' AND at > ? GROUP BY COALESCE(cat, ?)', [$default, $skey, $since, $default]) as $r) {
            $c = (string) $r['c'];
            $mail[$c] = ['total' => ($mail[$c]['total'] ?? 0) + (int) $r['n'], 'unread' => ($mail[$c]['unread'] ?? 0) + (int) $r['u']];
        }
        $total = array_sum(array_column($mail, 'total'));
        $unread = array_sum(array_column($mail, 'unread'));
        return Piles::pileFor($item['pile'] ?? null, $item['cat'] ?? null, $total, $unread, $mail);
    }

    /**
     * Sorts again every sender a rule could touch (after a rule is added,
     * changed or removed).
     */
    public function resortForRule(array $rule): int
    {
        $this->reset();
        $pattern = Classifier::lower((string) ($rule['pattern'] ?? ''));
        $keys = [];
        switch ($rule['field'] ?? '') {
            case 'sender':
                $keys[$this->resolve($pattern)] = true;
                break;
            case 'domain':
                foreach (array_keys($this->store->itemsOf('sender')) as $key) {
                    $d = Classifier::domainOf((string) $key);
                    if ($d === $pattern || str_ends_with($d, '.' . $pattern)) {
                        $keys[(string) $key] = true;
                    }
                }
                break;
            case 'listId':
                foreach ($this->store->db->all('SELECT DISTINCT from_key FROM {emails} WHERE signals LIKE ?', ['%;' . $pattern]) as $r) {
                    $keys[(string) $r['from_key']] = true;
                }
                break;
            case 'subject':
                $first = Classifier::trim(explode('|', $pattern)[0]);
                foreach ($this->store->db->all('SELECT DISTINCT from_key FROM {emails} WHERE LOWER(subject) LIKE ?', ['%' . $first . '%']) as $r) {
                    $keys[(string) $r['from_key']] = true;
                }
                break;
        }
        foreach (array_keys($keys) as $key) {
            $this->resort((string) $key);
        }
        return count($keys);
    }
}
