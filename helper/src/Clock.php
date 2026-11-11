<?php
declare(strict_types=1);

namespace Precis;

/**
 * What the every-minute timer does: look at each mailbox (the fallback for
 * Google's notice), read a little more of the first 30 days, keep the notice
 * alive, and move along the things that depend on the clock (reminders that
 * are due, rows put off until a time that has come).
 */
final class Clock
{
    public function __construct(private readonly Store $store, private readonly Reader $reader, private readonly ?Readings $readings = null, private readonly ?Alerts $alerts = null)
    {
    }

    /**
     * One tick. Only one runs at a time: a tick that finds another still
     * going does nothing.
     *
     * @return array<string, int>
     */
    public function tick(string $lockFile, int $seconds = 48): array
    {
        $lock = fopen($lockFile, 'c');
        if ($lock === false || !flock($lock, LOCK_EX | LOCK_NB)) {
            return ['skipped' => 1];
        }
        try {
            return $this->run($seconds);
        } finally {
            flock($lock, LOCK_UN);
            fclose($lock);
        }
    }

    /** @return array<string, int> */
    public function run(int $seconds = 48): array
    {
        $started = microtime(true);
        $out = ['new' => 0, 'older' => 0, 'reminders' => 0, 'back' => 0, 'queued' => 0, 'read' => 0, 'day' => 0, 'alerts' => 0];
        foreach ($this->reader->accounts() as $a) {
            $id = (int) $a['id'];
            $this->reader->renewWatch($id);
            $this->reader->markInbox($id);
            $out['new'] += $this->reader->poll($id);
            // The first read goes a little at a time, so the website is never crowded.
            if ((int) $a['backfill_done'] === 0 && microtime(true) - $started < $seconds) {
                $out['older'] += $this->reader->backfill($id, max(1, (int) $this->store->get('backfill.pages_per_tick', '1')));
            }
        }
        $out['reminders'] = $this->fireReminders();
        $out['back'] = $this->bringBack();
        $this->store->set('clock.last_run', (string) $this->store->now());
        // The assistant reads what is waiting with the time that is left.
        // The next tick is a minute away, so this one stops well before it.
        if ($this->readings !== null) {
            $out['queued'] = $this->readings->plan();
            $left = $seconds - (microtime(true) - $started);
            if ($left > 5) {
                $out['read'] = $this->readings->work($left - 4);
            }
            // What newly needs the owner rings their phones; what is finished stops showing there.
            if ($this->alerts !== null) {
                $out['alerts'] = $this->alerts->sweep();
            }
            // The sentence at the top of Today, when the page under it has changed.
            if ($seconds - (microtime(true) - $started) > 6) {
                $out['day'] = (int) (new Day($this->store, $this->readings))->refresh();
            }
        }
        return $out;
    }

    /** Marks reminders whose time has come, so devices alert. */
    public function fireReminders(): int
    {
        $n = 0;
        $now = $this->store->now();
        foreach ($this->store->itemsOf('reminder') as $uid => $r) {
            if (empty($r['done']) && empty($r['fired']) && (int) ($r['due'] ?? 0) > 0 && (int) $r['due'] <= $now) {
                $r['fired'] = $now;
                $this->store->put('reminder', (string) $uid, $r);
                $n++;
            }
        }
        return $n;
    }

    /** Rows put off until a time that has come return to their list. */
    public function bringBack(): int
    {
        $n = 0;
        $now = $this->store->now();
        foreach ($this->store->itemsOf('rowpref') as $row => $p) {
            if (($p['snoozed'] ?? null) !== null && (int) $p['snoozed'] <= $now) {
                $p['snoozed'] = null;
                $p['resurfaced'] = $now;
                $this->store->put('rowpref', (string) $row, $p);
                $n++;
            }
        }
        return $n;
    }
}
