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
    public function push(int $device, array $entries): array
    {
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
                $changed = $this->store->remove($kind, $k, $device);
                $data = null;
            } else {
                $data = $e['data'] ?? null;
                if (!is_array($data) || strlen(Store::json($data)) > self::MAX_DATA) {
                    throw new InvalidArgumentException('A change is missing its contents, or they are too large.');
                }
                if ($kind === 'sender') {
                    $data = self::mergeSender($old, $data);
                } elseif ($kind === 'msgfix' && $old !== null) {
                    // A fix to the tag and a fix to the place are kept side by side.
                    $data += $old;
                }
                $changed = $this->store->put($kind, $k, $data, $device);
            }
            if (!$changed) {
                continue;
            }
            $applied++;
            switch ($kind) {
                case 'sender':
                    // A move by hand, or one taken back, changes where the sender's mail goes.
                    if (($old['src'] ?? '') === 'override' || ($data['src'] ?? '') === 'override' || ($old['cat'] ?? null) !== ($data['cat'] ?? null)) {
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
     * its row as the device has it and the facts behind it. Nothing is
     * decided again here: the device's standing answers are taken as they
     * are, and only mail that arrives later can change them.
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
            $this->store->put('sender', $k, $s['item'], $device);
            $n++;
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
     * @param array<string, mixed>|null $old
     * @param array<string, mixed> $new
     * @return array<string, mixed>
     */
    private static function mergeSender(?array $old, array $new): array
    {
        $out = $old ?? ['cls' => (string) ($new['cls'] ?? 'people'), 'src' => 'auto', 'reasons' => (string) ($new['reasons'] ?? '')];
        if (($new['src'] ?? '') === 'override' && in_array($new['cls'] ?? null, ['people', 'feeds'], true)) {
            $out['cls'] = $new['cls'];
            $out['src'] = 'override';
        } elseif (($old['src'] ?? '') === 'override') {
            // The move was taken back: the rules decide again.
            $out['src'] = 'auto';
        }
        foreach (['cat', 'pile', 'counts', 'label', 'subtitle'] as $mine) {
            if (array_key_exists($mine, $new)) {
                $out[$mine] = $new[$mine];
            }
        }
        if (($new['name'] ?? '') !== '') {
            $out['name'] = $new['name'];
        }
        return $out + ['cat' => null, 'pile' => null, 'counts' => false];
    }

    private function action(int $device, array $e): int
    {
        switch ($e['op']) {
            case 'rename-tag':
                return $this->renameTag($device, (string) ($e['from'] ?? ''), (string) ($e['to'] ?? ''));
            case 'delete-tag':
                return $this->renameTag($device, (string) ($e['name'] ?? ''), null);
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
        foreach ($db->all('SELECT message_id, cls FROM {emails} WHERE cat = ?', [$from]) as $r) {
            if ((string) $r['message_id'] !== '') {
                $this->store->put('sort', (string) $r['message_id'], ['cls' => (string) $r['cls'], 'cat' => $to], $device);
            }
        }
        $db->run('UPDATE {emails} SET cat = ? WHERE cat = ?', [$to, $from]);
        $this->sorter->reset();
        return $n;
    }
}
