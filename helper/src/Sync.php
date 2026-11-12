<?php
declare(strict_types=1);

namespace Precis;

use InvalidArgumentException;

/**
 * What devices send up, and what happens because of it.
 *
 * A device sends items (a sender it moved, a rule, a tag, something marked
 * done, a row put off, a reminder). Each is stored, passed on to the other
 * devices through the stream, and, where it changes how mail is sorted, the
 * senders it touches are sorted again.
 */
final class Sync
{
    public const MAX_ITEMS = 2000;
    private const MAX_DATA = 65536;

    public function __construct(private readonly Store $store, private readonly Sorter $sorter)
    {
    }

    /**
     * Applies a list of changes from a device.
     *
     * Each entry is `{kind, k, data}` to set, `{kind, k, deleted: true}` to
     * remove, or an action: `{op: 'rename-tag', from, to}`,
     * `{op: 'delete-tag', name}`.
     *
     * @return array{applied: int, seq: int}
     */
    public function push(int $device, array $entries, bool $echo = false): array
    {
        // A change made from an alert on a phone, with the app closed, is
        // written as nobody's, so that phone's own app hears it back too.
        $origin = $echo ? null : $device;
        if (count($entries) > self::MAX_ITEMS) {
            throw new InvalidArgumentException('Too many changes in one go.');
        }
        $applied = 0;
        $resort = [];
        $rules = [];
        foreach ($entries as $e) {
            if (!is_array($e)) {
                throw new InvalidArgumentException('A change must be an object.');
            }
            if (isset($e['op'])) {
                $applied += $this->action($device, $e);
                continue;
            }
            $kind = (string) ($e['kind'] ?? '');
            $k = (string) ($e['k'] ?? '');
            if (!in_array($kind, Store::DEVICE_KINDS, true) || $k === '' || strlen($k) > 2000) {
                throw new InvalidArgumentException('That kind of change is not one a device may send.');
            }
            $old = $this->store->item($kind, $k);
            if (!empty($e['deleted'])) {
                $changed = $this->store->remove($kind, $k, $origin);
                $data = null;
            } else {
                $data = $e['data'] ?? null;
                if (!is_array($data) || strlen(Store::json($data)) > self::MAX_DATA) {
                    throw new InvalidArgumentException('A change is missing its contents, or they are too large.');
                }
                if ($kind === 'sender') {
                    $data = self::mergeSender($old, $data);
                } elseif (($kind === 'msgfix' || $kind === 'cardfix') && $old !== null) {
                    // A fix to the tag and a fix to the place are kept side by side.
                    $data += $old;
                }
                $changed = $this->store->put($kind, $k, $data, $origin);
            }
            if (!$changed) {
                continue;
            }
            $applied++;
            switch ($kind) {
                case 'sender':
                    // A move by hand, or one taken back, changes where the sender's mail goes.
                    if (($old['src'] ?? '') === 'override' || ($data['src'] ?? '') === 'override' || ($old['cat'] ?? null) !== ($data['cat'] ?? null) || ($old['pile'] ?? null) !== ($data['pile'] ?? null)) {
                        $resort[$k] = true;
                    }
                    break;
                case 'rule':
                    if ($old !== null) {
                        $rules[] = $old;
                    }
                    if ($data !== null) {
                        $rules[] = $data;
                    }
                    break;
                case 'addr':
                    $this->sorter->reset();
                    $resort[(string) ($data['key'] ?? $k)] = true;
                    if ($old !== null) {
                        $resort[(string) ($old['key'] ?? $k)] = true;
                    }
                    $resort[$k] = true;
                    break;
                case 'me':
                case 'names':
                    $this->sorter->reset();
                    break;
                case 'book':
                    $resort[$k] = true;
                    break;
                case 'msgfix':
                    $from = $this->store->db->val('SELECT from_key FROM {emails} WHERE message_id = ? LIMIT 1', [Store::key($k)]);
                    if ($from !== null) {
                        $resort[(string) $from] = true;
                    }
                    break;
            }
        }
        if ($rules !== []) {
            foreach ($rules as $rule) {
                $this->sorter->resortForRule($rule);
            }
        }
        $this->sorter->reset();
        foreach (array_keys($resort) as $key) {
            $this->sorter->resort((string) $key);
        }
        return ['applied' => $applied, 'seq' => $this->store->seq()];
    }

    /**
     * A device's first sending-up of what it knows about senders: for each,
     * its row as the device has it and the facts behind it. A sender the
     * helper holds no mail from is taken as the device has it. One it does
     * hold mail from is decided again, now on the device's facts and the
     * helper's own reading together.
     *
     * @param list<array<string, mixed>> $senders each `{k, item, facts}`
     * @param list<string> $myIds Message-IDs of mail the owner sent
     * @return array{senders: int, seq: int}
     */
    public function seed(int $device, array $senders, int $at, array $myIds = []): array
    {
        if (count($senders) > self::MAX_ITEMS || count($myIds) > 20000) {
            throw new InvalidArgumentException('Too much in one go.');
        }
        $n = 0;
        foreach ($senders as $s) {
            $k = (string) ($s['k'] ?? '');
            if ($k === '' || $k === 'me' || strlen($k) > 191 || !is_array($s['item'] ?? null)) {
                continue;
            }
            if (is_array($s['facts'] ?? null)) {
                $this->sorter->setSeed($k, $s['facts'], $at);
            }
            $this->store->put('sender', $k, self::keepOwnersWord($this->store->item('sender', $k), $s['item']), $device);
            $n++;
            // Mail the helper read before it knew this was decided with next
            // to nothing to go on. Now that the device's facts are here, the
            // sender and its emails are decided again on all of them.
            if ($this->sorter->hasEmailsFrom($k)) {
                $this->sorter->resort($k);
            }
        }
        $this->sorter->addMyIds($myIds);
        return ['senders' => $n, 'seq' => $this->store->seq()];
    }

    /**
     * A sender as a device sends it, laid over what the helper has. The
     * device owns the user's own choices: a move by hand, the pile, the tag,
     * the name, whether it rings. Who is a person is otherwise the helper's
     * to decide, so a device's own guess never replaces the helper's.
     *
     * A move by hand is never undone by a device that merely does not know
     * of it (a phone that just joined, working out its own guess). It is
     * undone only when a device says so in so many words: the "unmove"
     * action. And while a sender is moved by hand, the tag it has is the
     * owner's: a device that does not carry the move cannot change it.
     *
     * @param array<string, mixed>|null $old
     * @param array<string, mixed> $new
     * @return array<string, mixed>
     */
    private static function mergeSender(?array $old, array $new): array
    {
        $out = $old ?? ['cls' => (string) ($new['cls'] ?? 'people'), 'src' => 'auto', 'reasons' => (string) ($new['reasons'] ?? '')];
        $moved = ($old['src'] ?? '') === 'override';
        $knows = ($new['src'] ?? '') === 'override';
        if ($knows && in_array($new['cls'] ?? null, ['people', 'feeds'], true)) {
            $out['cls'] = $new['cls'];
            $out['src'] = 'override';
        }
        foreach (['cat', 'pile', 'counts', 'label', 'subtitle'] as $mine) {
            if (!array_key_exists($mine, $new)) {
                continue;
            }
            // From a device that does not know of the move: only what it
            // actually sets is taken, never an empty value over a set one.
            if ($moved && !$knows && ($mine === 'cat' || $new[$mine] === null || $new[$mine] === false || $new[$mine] === '')) {
                continue;
            }
            $out[$mine] = $new[$mine];
        }
        if (($new['name'] ?? '') !== '') {
            $out['name'] = $new['name'];
        }
        return $out + ['cat' => null, 'pile' => null, 'counts' => false];
    }

    /**
     * A sender as a device sends it the first time it sends everything up,
     * with whatever the owner already set (on another device) kept: the
     * move by hand and its place, the tag, the pile, the names, whether it
     * counts. A device's first sending-up never takes those away.
     *
     * @param array<string, mixed>|null $old
     * @param array<string, mixed> $new
     * @return array<string, mixed>
     */
    private static function keepOwnersWord(?array $old, array $new): array
    {
        if ($old === null) {
            return $new;
        }
        if (($old['src'] ?? '') === 'override' && ($new['src'] ?? '') !== 'override') {
            $new['cls'] = $old['cls'] ?? ($new['cls'] ?? 'people');
            $new['src'] = 'override';
            $new['cat'] = $old['cat'] ?? null;
        }
        foreach (['cat', 'pile', 'label', 'subtitle'] as $mine) {
            if (($new[$mine] ?? null) === null && ($old[$mine] ?? null) !== null) {
                $new[$mine] = $old[$mine];
            }
        }
        if (($old['counts'] ?? false) === true) {
            $new['counts'] = true;
        }
        return $new;
    }

    private function action(int $device, array $e): int
    {
        switch ($e['op']) {
            case 'unmove':
                // The owner took a move by hand back: the rules decide that sender again.
                $k = (string) ($e['k'] ?? '');
                $old = $k === '' ? null : $this->store->item('sender', $k);
                if ($old === null || ($old['src'] ?? '') !== 'override') {
                    return 0;
                }
                $changed = (int) $this->store->put('sender', $k, ['src' => 'auto'] + $old, $device);
                $this->sorter->reset();
                $this->sorter->resort($k);
                return $changed;
            case 'rename-tag':
                return $this->renameTag($device, (string) ($e['from'] ?? ''), (string) ($e['to'] ?? ''));
            case 'delete-tag':
                return $this->renameTag($device, (string) ($e['name'] ?? ''), null);
            case 'reminder-done':
                // "Done" pressed on a reminder's alert: every device hears it, the phone's own app too.
                $uid = (string) ($e['uid'] ?? '');
                $old = $uid === '' ? null : $this->store->item('reminder', $uid);
                return $old === null ? 0 : (int) $this->store->put('reminder', $uid, ['done' => true] + $old, null);
            default:
                throw new InvalidArgumentException('That action is not known.');
        }
    }

    /** Renames a tag everywhere it is used; with [$to] null, removes it everywhere. */
    private function renameTag(int $device, string $from, ?string $to): int
    {
        if ($from === '' || $to === '') {
            throw new InvalidArgumentException('A tag needs a name.');
        }
        $n = 0;
        $tag = $this->store->item('tag', $from);
        if ($tag !== null) {
            $this->store->remove('tag', $from, $device);
            if ($to !== null) {
                $this->store->put('tag', $to, $tag, $device);
            }
            $n++;
        }
        foreach ($this->store->itemsOf('sender') as $k => $s) {
            if (($s['cat'] ?? null) === $from) {
                $s['cat'] = $to;
                $n += (int) $this->store->put('sender', (string) $k, $s, $device);
            }
        }
        foreach ($this->store->itemsOf('rule') as $k => $r) {
            if (($r['category'] ?? null) === $from) {
                $r['category'] = $to;
                if ($to === null && ($r['bucket'] ?? null) === null) {
                    $n += (int) $this->store->remove('rule', (string) $k, $device);
                } else {
                    $n += (int) $this->store->put('rule', (string) $k, $r, $device);
                }
            }
        }
        foreach ($this->store->itemsOf('msgfix') as $k => $f) {
            if (($f['cat'] ?? null) === $from) {
                $f['cat'] = $to;
                $n += (int) $this->store->put('msgfix', (string) $k, $f, $device);
            }
        }
        $db = $this->store->db;
        foreach ($db->all('SELECT message_id, cls, pile FROM {emails} WHERE cat = ?', [$from]) as $r) {
            if ((string) $r['message_id'] !== '') {
                $this->store->put('sort', (string) $r['message_id'], ['cls' => (string) $r['cls'], 'cat' => $to] + ((string) $r['pile'] === '' ? [] : ['pile' => (string) $r['pile']]), $device);
            }
        }
        $db->run('UPDATE {emails} SET cat = ? WHERE cat = ?', [$to, $from]);
        $this->sorter->reset();
        return $n;
    }
}
