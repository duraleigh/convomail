<?php
declare(strict_types=1);

namespace Precis;

/**
 * Keeps up with the mailbox: what is new since last time, the day-one read
 * of the last 30 days, and Google's "new mail" notice.
 */
final class Reader
{
    public const BACKFILL_DAYS = 30;

    /** Emails fetched from Gmail in one go. */
    private const CHUNK = 40;

    public function __construct(private readonly Store $store, private readonly Google $google, private readonly Sorter $sorter)
    {
    }

    /** @return list<array<string, mixed>> */
    public function accounts(): array
    {
        return $this->store->db->all('SELECT id, email, history_id, watch_expires, backfill_page, backfill_done, backfill_read, last_checked, last_notice, last_error, created FROM {accounts} ORDER BY id');
    }

    /**
     * Reads what changed in a mailbox since the last look. Returns how many
     * emails were taken in.
     */
    public function poll(int $accountId): int
    {
        $db = $this->store->db;
        $account = $db->one('SELECT id, email, history_id FROM {accounts} WHERE id = ?', [$accountId]);
        if ($account === null) {
            return 0;
        }
        try {
            if ($this->store->get("account.$accountId.sendas") === null) {
                $own = $this->google->sendingAddresses($accountId);
                $own[] = ['email' => (string) $account['email'], 'name' => ''];
                $this->sorter->learnOwnAddresses($own);
                $this->store->set("account.$accountId.sendas", (string) $this->store->now());
            }
            $start = (string) ($account['history_id'] ?? '');
            if ($start === '') {
                $start = (string) ($this->google->profile($accountId)['historyId'] ?? '');
                $db->run('UPDATE {accounts} SET history_id = ? WHERE id = ?', [$start, $accountId]);
            }
            $h = $this->google->history($accountId, $start);
            $ids = $h['changed'];
            if ($h['tooOld']) {
                // Too long since the last look for Google to list the changes:
                // read the last few days again and start from now.
                $ids = $this->google->listIds($accountId, 'newer_than:3d', null, 500)['ids'];
                $h['historyId'] = (string) ($this->google->profile($accountId)['historyId'] ?? $start);
            }
            $taken = 0;
            foreach (array_chunk($ids, self::CHUNK) as $chunk) {
                $taken += $this->sorter->takeIn($accountId, $this->google->metadata($accountId, $chunk))['stored'];
            }
            $db->run('UPDATE {accounts} SET history_id = ?, last_checked = ?, last_error = NULL WHERE id = ?', [$h['historyId'], $this->store->now(), $accountId]);
            return $taken;
        } catch (\Throwable $e) {
            $this->fail($accountId, $e);
            return 0;
        }
    }

    /**
     * Reads one more batch of the last 30 days, newest first. Returns how
     * many emails it took in; 0 when the day-one read is finished.
     */
    public function backfill(int $accountId, int $pages = 1): int
    {
        $db = $this->store->db;
        $taken = 0;
        for ($i = 0; $i < $pages; $i++) {
            $account = $db->one('SELECT backfill_page, backfill_done FROM {accounts} WHERE id = ?', [$accountId]);
            if ($account === null || (int) $account['backfill_done'] === 1) {
                return $taken;
            }
            try {
                $list = $this->google->listIds($accountId, 'newer_than:' . self::BACKFILL_DAYS . 'd', $account['backfill_page'] === null ? null : (string) $account['backfill_page'], 100);
                $have = [];
                if ($list['ids'] !== []) {
                    foreach ($db->all('SELECT gmail_id FROM {emails} WHERE account_id = ? AND gmail_id IN (' . Db::marks(count($list['ids'])) . ')', [$accountId, ...$list['ids']]) as $r) {
                        $have[(string) $r['gmail_id']] = true;
                    }
                }
                $new = array_values(array_filter($list['ids'], static fn (string $id): bool => !isset($have[$id])));
                foreach (array_chunk($new, self::CHUNK) as $chunk) {
                    $taken += $this->sorter->takeIn($accountId, $this->google->metadata($accountId, $chunk))['stored'];
                }
                $db->run('UPDATE {accounts} SET backfill_page = ?, backfill_done = ?, backfill_read = backfill_read + ? WHERE id = ?', [$list['next'], $list['next'] === null ? 1 : 0, count($list['ids']), $accountId]);
                if ($list['next'] === null) {
                    $this->store->log('info', 'The first read of the last ' . self::BACKFILL_DAYS . ' days is finished.');
                    return $taken;
                }
            } catch (\Throwable $e) {
                $this->fail($accountId, $e);
                return $taken;
            }
        }
        return $taken;
    }

    /**
     * Once per mailbox: learns which of the emails already held are in the
     * inbox. (Emails filed from now on carry that fact with them.)
     */
    public function markInbox(int $accountId): bool
    {
        if ($this->store->get("account.$accountId.inbox") !== null) {
            return false;
        }
        try {
            $db = $this->store->db;
            $page = null;
            do {
                $list = $this->google->listIds($accountId, 'in:inbox newer_than:' . (self::BACKFILL_DAYS + 1) . 'd', $page, 500);
                foreach (array_chunk($list['ids'], 200) as $chunk) {
                    $db->run('UPDATE {emails} SET inbox = 1 WHERE account_id = ? AND gmail_id IN (' . Db::marks(count($chunk)) . ')', [$accountId, ...$chunk]);
                }
                $page = $list['next'];
            } while ($page !== null);
            $this->store->set("account.$accountId.inbox", (string) $this->store->now());
            return true;
        } catch (\Throwable $e) {
            $this->fail($accountId, $e);
            return false;
        }
    }

    /**
     * Asks Google (again) to send the "new mail" notice, when a topic is set
     * and the current asking has less than six days left. Asked daily, it
     * never lapses.
     */
    public function renewWatch(int $accountId): bool
    {
        $topic = (string) $this->store->get('google.topic', '');
        if ($topic === '') {
            return false;
        }
        $db = $this->store->db;
        $expires = (int) $db->val('SELECT watch_expires FROM {accounts} WHERE id = ?', [$accountId]);
        if ($expires - $this->store->now() > 6 * 86400) {
            return false;
        }
        try {
            $w = $this->google->watch($accountId, $topic);
            $db->run('UPDATE {accounts} SET watch_expires = ? WHERE id = ?', [$w['expires'], $accountId]);
            return true;
        } catch (\Throwable $e) {
            $this->fail($accountId, $e, 'Asking Google for the new-mail notice failed');
            return false;
        }
    }

    /** Google's notice arrived for [$email]: look at that mailbox now. */
    public function notice(string $email): int
    {
        $id = $this->store->db->val('SELECT id FROM {accounts} WHERE email = ?', [Classifier::lower($email)]);
        if ($id === null) {
            return 0;
        }
        $this->store->db->run('UPDATE {accounts} SET last_notice = ? WHERE id = ?', [$this->store->now(), (int) $id]);
        return $this->poll((int) $id);
    }

    private function fail(int $accountId, \Throwable $e, string $what = 'Reading the mailbox failed'): void
    {
        // The message says what failed, never an email's words.
        $msg = $e instanceof GoogleError && $e->needsSignIn
            ? 'Google ended the sign-in. Connect Google again on the helper’s page.'
            : $what . ': ' . mb_substr($e->getMessage(), 0, 300);
        $this->store->db->run('UPDATE {accounts} SET last_error = ? WHERE id = ?', [$msg, $accountId]);
        $this->store->log('error', $msg);
    }
}
