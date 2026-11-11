<?php
declare(strict_types=1);

namespace Precis;

/**
 * What rings a phone, and what takes an alert away again.
 *
 *  - An email that newly needs the owner: one alert, saying who wrote and
 *    what they ask (not the subject).
 *  - One notice an hour before a "by" time.
 *  - A reminder the owner set, at its time.
 *  - Nothing else. Feed and Noise never ring.
 *
 * One alert, not three: when Précis is open and in front on a PC, phones
 * stay silent for that email. When something is finished on any device
 * (Done, Not Focus, Later, or answered), its alert is taken off the others.
 * During quiet hours an alert still arrives, but makes no sound.
 *
 * Each thing is alerted once, however many times the timer looks.
 */
final class Alerts
{
    /** A PC counts as "in front of the owner" for this long after it last said so. */
    private const FRONT = 90;

    /** How long before a "by" time its notice goes out. */
    private const SOON = 3600;

    public function __construct(private readonly Store $store, private readonly Readings $readings, private readonly Push $push)
    {
    }

    /** @return list<array{id: int, push_token: string, ring: int}> phones that can be alerted */
    private function phones(): array
    {
        return $this->store->db->all("SELECT id, push_token, ring FROM {devices} WHERE revoked = 0 AND push_token IS NOT NULL AND push_token <> ''");
    }

    private function pcInFront(): bool
    {
        return $this->store->db->val("SELECT 1 FROM {devices} WHERE revoked = 0 AND kind = 'windows' AND front_at > ? LIMIT 1", [$this->store->now() - self::FRONT]) !== null;
    }

    /** Whether it is quiet hours where the owner is. */
    public function quiet(): bool
    {
        $q = $this->store->item('pref', 'quiet');
        if ($q === null || ($q['on'] ?? false) !== true) {
            return false;
        }
        $from = self::minutes((string) ($q['from'] ?? '22:00'));
        $to = self::minutes((string) ($q['to'] ?? '07:00'));
        $now = intdiv(($this->store->now() + $this->readings->zone() * 60) % 86400, 60);
        return $from === $to ? false : ($from < $to ? ($now >= $from && $now < $to) : ($now >= $from || $now < $to));
    }

    private static function minutes(string $clock): int
    {
        return preg_match('~^(\d{1,2}):(\d{2})$~', $clock, $m) === 1 ? ((int) $m[1] % 24) * 60 + (int) $m[2] % 60 : 0;
    }

    private function seen(string $k): bool
    {
        return $this->store->db->val('SELECT 1 FROM {alerts} WHERE k = ?', [Store::key($k)]) !== null;
    }

    private function note(string $k): void
    {
        $this->store->db->upsert('alerts', ['k' => Store::key($k)], ['at' => $this->store->now(), 'cleared' => 0]);
    }

    /** A number an alert keeps for its whole life, so it can be replaced or taken away. */
    public static function number(string $k): int
    {
        return (int) (hexdec(substr(sha1($k), 0, 7)));
    }

    /**
     * Looks at what needs the owner now and sends what is due. Returns how
     * many messages went to phones.
     */
    public function sweep(): int
    {
        if (!$this->push->hasKey()) {
            return 0;
        }
        $db = $this->store->db;
        $now = $this->store->now();
        // Nothing from before alerts were set up rings: no flood on the first day.
        $since = (int) $this->store->get('push.since', (string) $now);
        $focus = $this->readings->focusNow();
        $phones = $this->phones();
        $quiet = $this->quiet();
        $front = $this->pcInFront();
        $sent = 0;
        $count = count($focus);

        $ring = function (array $data, bool $silentIfFront) use ($phones, $quiet, $front, &$sent): void {
            foreach ($phones as $p) {
                if ((int) $p['ring'] !== 1) {
                    continue;
                }
                if ($silentIfFront && $front) {
                    continue;
                }
                $r = $this->push->send((string) $p['push_token'], $data + ['quiet' => $quiet]);
                if ($r === 'gone') {
                    $this->store->db->run('UPDATE {devices} SET push_token = NULL WHERE id = ?', [(int) $p['id']]);
                }
                $sent += (int) ($r === 'sent');
            }
        };

        $live = [];
        foreach ($focus as $f) {
            $mid = $f['message_id'];
            $live[Store::key('focus:' . $mid)] = true;
            $read = (int) $db->val('SELECT at FROM {readings} WHERE email_id = ?', [$f['id']]);
            if (!$this->seen('focus:' . $mid)) {
                $this->note('focus:' . $mid);
                if (max($read, $f['at']) >= $since) {
                    $ring(['t' => 'focus', 'id' => self::number(Store::key('focus:' . $mid)), 'mid' => $mid, 'who' => $f['name'], 'ask' => $f['ask'], 'by' => $f['due'], 'n' => $count], true);
                }
            }
            if ($f['due'] !== null && $f['due'] > $now && $f['due'] - $now <= self::SOON) {
                $live[Store::key('due:' . $mid)] = true;
                if (!$this->seen('due:' . $mid)) {
                    $this->note('due:' . $mid);
                    $ring(['t' => 'due', 'id' => self::number(Store::key('focus:' . $mid)), 'mid' => $mid, 'who' => $f['name'], 'ask' => $f['ask'], 'by' => $f['due'], 'n' => $count], false);
                }
            }
        }

        // Reminders the owner set, as their time comes.
        foreach ($this->store->itemsOf('reminder') as $uid => $r) {
            if (empty($r['done']) && !empty($r['fired']) && (int) $r['fired'] >= $since) {
                $live[Store::key('rem:' . $uid)] = true;
                if (!$this->seen('rem:' . $uid)) {
                    $this->note('rem:' . $uid);
                    $ring(['t' => 'reminder', 'id' => self::number(Store::key('rem:' . $uid)), 'uid' => (string) $uid, 'ask' => (string) ($r['title'] ?? 'Reminder'), 'mid' => (string) ($r['mid'] ?? ''), 'n' => $count], false);
                }
            }
        }

        // Finished somewhere: take its alert off every phone.
        foreach ($db->all('SELECT k FROM {alerts} WHERE cleared = 0 AND at > ?', [$now - 14 * 86400]) as $a) {
            $k = (string) $a['k'];
            if (isset($live[$k]) || str_starts_with($k, 'due:')) {
                continue;
            }
            // Put off until later: forgotten, so it rings again when it comes back.
            $later = str_starts_with($k, 'focus:') ? (int) (($this->store->item('msgfix', substr($k, 6)) ?? [])['later'] ?? 0) : 0;
            if ($later > $now) {
                $db->run('DELETE FROM {alerts} WHERE k = ? OR k = ?', [$k, Store::key('due:' . substr($k, 6))]);
            } else {
                $db->run('UPDATE {alerts} SET cleared = 1 WHERE k = ?', [$k]);
            }
            foreach ($phones as $p) {
                // A phone set not to ring never showed it.
                if ((int) $p['ring'] !== 1) {
                    continue;
                }
                $sent += (int) ($this->push->send((string) $p['push_token'], ['t' => 'clear', 'id' => self::number($k), 'n' => $count]) === 'sent');
            }
        }
        $db->run('DELETE FROM {alerts} WHERE at < ?', [$now - 60 * 86400]);
        return $sent;
    }

    /** A test alert to every phone, from the owner's page. */
    public function test(): int
    {
        $n = 0;
        foreach ($this->phones() as $p) {
            $n += (int) ($this->push->send((string) $p['push_token'], ['t' => 'test', 'id' => 1, 'who' => 'Précis', 'ask' => 'Alerts are working on this phone.', 'n' => count($this->readings->focusNow())]) === 'sent');
        }
        return $n;
    }
}
