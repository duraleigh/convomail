<?php
declare(strict_types=1);

namespace Precis;

/**
 * The helper's notes: small settings, sealed secrets, the one stream of
 * items that devices keep in step, and a short log.
 */
final class Store
{
    /** Kinds of item a device may send up. */
    public const DEVICE_KINDS = ['sender', 'rule', 'tag', 'rowpref', 'reminder', 'done', 'msgfix', 'addr', 'me', 'book', 'names'];

    /** Kinds only the helper writes. */
    public const HELPER_KINDS = ['sort'];

    public function __construct(public readonly Db $db, public readonly Crypto $crypto, private readonly ?\Closure $clock = null)
    {
    }

    public function now(): int
    {
        return $this->clock !== null ? (int) ($this->clock)() : time();
    }

    // ---- settings ---------------------------------------------------------------

    public function get(string $key, ?string $default = null): ?string
    {
        $v = $this->db->val('SELECT v FROM {meta} WHERE k = ?', [$key]);
        return $v === null ? $default : (string) $v;
    }

    public function set(string $key, ?string $value): void
    {
        if ($value === null) {
            $this->db->run('DELETE FROM {meta} WHERE k = ?', [$key]);
            return;
        }
        $this->db->upsert('meta', ['k' => $key], ['v' => $value]);
    }

    public function getSecret(string $key): ?string
    {
        $v = $this->get($key);
        return $v === null ? null : $this->crypto->open($v);
    }

    public function setSecret(string $key, ?string $value): void
    {
        $this->set($key, $value === null ? null : $this->crypto->seal($value));
    }

    // ---- the stream of items -------------------------------------------------------

    /** The next number in the stream. Call inside a transaction. */
    public function nextSeq(): int
    {
        $this->db->run('UPDATE {counters} SET n = n + 1 WHERE name = ?', ['seq']);
        return (int) $this->db->val('SELECT n FROM {counters} WHERE name = ?', ['seq']);
    }

    public function seq(): int
    {
        return (int) $this->db->val('SELECT n FROM {counters} WHERE name = ?', ['seq']);
    }

    /** Long keys (a rare, very long Message-ID) are stored by their hash. */
    public static function key(string $k): string
    {
        return strlen($k) <= 400 ? $k : 'sha1:' . sha1($k);
    }

    /**
     * Writes one item. Nothing is written when it would not change, so the
     * stream only moves when something did. Returns whether it changed.
     */
    public function put(string $kind, string $k, array $data, ?int $origin = null): bool
    {
        $k = self::key($k);
        $json = self::json($data);
        return (bool) $this->db->transaction(function () use ($kind, $k, $json, $origin): bool {
            $old = $this->db->one('SELECT data, deleted FROM {items} WHERE kind = ? AND k = ?', [$kind, $k]);
            if ($old !== null && (int) $old['deleted'] === 0 && $old['data'] === $json) {
                return false;
            }
            $this->db->upsert('items', ['kind' => $kind, 'k' => $k], ['data' => $json, 'deleted' => 0, 'seq' => $this->nextSeq(), 'origin' => $origin, 'at' => $this->now()]);
            return true;
        });
    }

    /** Marks an item gone. Devices hear about it like any other change. */
    public function remove(string $kind, string $k, ?int $origin = null): bool
    {
        $k = self::key($k);
        return (bool) $this->db->transaction(function () use ($kind, $k, $origin): bool {
            $old = $this->db->one('SELECT deleted FROM {items} WHERE kind = ? AND k = ?', [$kind, $k]);
            if ($old === null || (int) $old['deleted'] === 1) {
                return false;
            }
            $this->db->run('UPDATE {items} SET data = ?, deleted = 1, seq = ?, origin = ?, at = ? WHERE kind = ? AND k = ?', ['{}', $this->nextSeq(), $origin, $this->now(), $kind, $k]);
            return true;
        });
    }

    /** @return array<string, mixed>|null */
    public function item(string $kind, string $k): ?array
    {
        $row = $this->db->one('SELECT data FROM {items} WHERE kind = ? AND k = ? AND deleted = 0', [$kind, self::key($k)]);
        return $row === null ? null : self::decode((string) $row['data']);
    }

    /** @return array<string, array<string, mixed>> every live item of a kind, by key */
    public function itemsOf(string $kind): array
    {
        $out = [];
        foreach ($this->db->all('SELECT k, data FROM {items} WHERE kind = ? AND deleted = 0', [$kind]) as $r) {
            $out[(string) $r['k']] = self::decode((string) $r['data']);
        }
        return $out;
    }

    /**
     * What changed after [$since], oldest first, leaving out what [$device]
     * itself sent.
     *
     * @return array{items: list<array<string, mixed>>, next: int, more: bool}
     */
    public function since(int $since, ?int $device, int $limit = 500): array
    {
        $rows = $this->db->all('SELECT kind, k, data, deleted, seq, origin FROM {items} WHERE seq > ? ORDER BY seq LIMIT ' . ($limit + 1), [$since]);
        $more = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);
        $next = $since;
        $items = [];
        foreach ($rows as $r) {
            $next = (int) $r['seq'];
            if ($device !== null && $r['origin'] !== null && (int) $r['origin'] === $device) {
                continue;
            }
            $items[] = ['kind' => $r['kind'], 'k' => $r['k'], 'data' => self::decode((string) $r['data']), 'deleted' => (int) $r['deleted'] === 1, 'seq' => (int) $r['seq']];
        }
        return ['items' => $items, 'next' => $next, 'more' => $more];
    }

    // ---- log -------------------------------------------------------------------------

    /** A short line for the status page. Never holds an email's words. */
    public function log(string $level, string $msg): void
    {
        $this->db->insert('log', ['at' => $this->now(), 'level' => $level, 'msg' => mb_substr($msg, 0, 500)]);
        if (random_int(1, 50) === 1) {
            $this->db->run('DELETE FROM {log} WHERE at < ?', [$this->now() - 7 * 86400]);
        }
    }

    public static function json(array $data): string
    {
        ksort($data);
        return json_encode((object) $data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE | JSON_THROW_ON_ERROR);
    }

    /** @return array<string, mixed> */
    public static function decode(string $json): array
    {
        $v = json_decode($json, true);
        return is_array($v) ? $v : [];
    }
}
