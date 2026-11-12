<?php
declare(strict_types=1);

namespace Precis;

/**
 * The PCs and phones allowed to talk to the helper.
 *
 * A device joins with a short code made by the owner (on the helper's own
 * page, or later from a device already signed in). It then holds a long
 * random token; the helper keeps only that token's hash.
 */
final class Devices
{
    public const CODE_LIFE = 600;

    public function __construct(private readonly Store $store)
    {
    }

    /** Makes a joining code, good for ten minutes and one use. */
    public function newCode(): string
    {
        $db = $this->store->db;
        $db->run('DELETE FROM {pair_codes} WHERE expires < ? OR used = 1', [$this->store->now()]);
        $code = Crypto::code(8);
        $db->insert('pair_codes', ['code_hash' => self::hash($code), 'expires' => $this->store->now() + self::CODE_LIFE, 'used' => 0]);
        return $code;
    }

    /**
     * Trades a joining code for a device token.
     *
     * @return array{id: int, token: string}|null null when the code is wrong, used or too old
     */
    public function join(string $code, string $name, string $kind): ?array
    {
        $db = $this->store->db;
        $code = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $code) ?? '');
        if ($code === '') {
            return null;
        }
        return $db->transaction(function () use ($db, $code, $name, $kind): ?array {
            $n = $db->run('UPDATE {pair_codes} SET used = 1 WHERE code_hash = ? AND used = 0 AND expires >= ?', [self::hash($code), $this->store->now()])->rowCount();
            if ($n !== 1) {
                return null;
            }
            $secret = Crypto::token(32);
            $id = $db->insert('devices', [
                'name' => mb_substr(trim($name) === '' ? 'Device' : trim($name), 0, 100),
                'kind' => in_array($kind, ['windows', 'android'], true) ? $kind : 'other',
                'token_hash' => self::hash($secret),
                'created' => $this->store->now(),
                'last_seen' => $this->store->now(),
            ]);
            return ['id' => $id, 'token' => $id . '.' . $secret];
        });
    }

    /** The device a token belongs to, or null. Notes that it was seen. */
    public function check(?string $token): ?array
    {
        if ($token === null || !preg_match('/^(\d{1,18})\.([A-Za-z0-9_-]{20,})$/', $token, $m)) {
            return null;
        }
        $db = $this->store->db;
        $row = $db->one('SELECT id, name, kind, token_hash, last_seen FROM {devices} WHERE id = ? AND revoked = 0', [(int) $m[1]]);
        if ($row === null || !hash_equals((string) $row['token_hash'], self::hash($m[2]))) {
            return null;
        }
        if ($this->store->now() - (int) $row['last_seen'] >= 60) {
            $db->run('UPDATE {devices} SET last_seen = ? WHERE id = ?', [$this->store->now(), (int) $row['id']]);
        }
        return ['id' => (int) $row['id'], 'name' => (string) $row['name'], 'kind' => (string) $row['kind']];
    }

    /** @return list<array<string, mixed>> */
    public function all(): array
    {
        return $this->store->db->all('SELECT id, name, kind, created, last_seen, revoked, ring, (push_token IS NOT NULL) AS alerts FROM {devices} ORDER BY id');
    }

    /** Signs a device out: it is cut off at once, and no more alerts go to it. */
    public function signOut(int $id): void
    {
        $this->store->db->run('UPDATE {devices} SET revoked = 1, push_token = NULL WHERE id = ?', [$id]);
    }

    /** Where to send a phone its alerts (null forgets it), and whether it may ring. */
    public function setPush(int $id, ?string $token, ?bool $ring): void
    {
        $db = $this->store->db;
        if ($token !== null) {
            $token = trim($token);
            // One phone, one address: an address that moved to another device row leaves the old one.
            if ($token !== '') {
                $db->run('UPDATE {devices} SET push_token = NULL WHERE push_token = ? AND id <> ?', [$token, $id]);
            }
            $db->run('UPDATE {devices} SET push_token = ? WHERE id = ?', [$token === '' ? null : mb_substr($token, 0, 400), $id]);
        }
        if ($ring !== null) {
            $db->run('UPDATE {devices} SET ring = ? WHERE id = ?', [(int) $ring, $id]);
        }
    }

    /** Whether this phone's app can show a sign-in code alert (older ones cannot). */
    public function setShowsCodes(int $id, bool $shows): void
    {
        $this->store->set('push.codes.' . $id, $shows ? '1' : null);
    }

    /** Whether this phone's app has a channel of its own for "Good to know" and for "Chats". */
    public function setShowsKinds(int $id, bool $shows): void
    {
        $this->store->set('push.kinds.' . $id, $shows ? '1' : null);
    }

    public function showsCodes(int $id): bool
    {
        return $this->store->get('push.codes.' . $id) === '1';
    }

    /** A PC says Précis is open and in front of the owner right now. */
    public function inFront(int $id): void
    {
        $this->store->db->run('UPDATE {devices} SET front_at = ? WHERE id = ?', [$this->store->now(), $id]);
    }

    public function rename(int $id, string $name): void
    {
        $this->store->db->run('UPDATE {devices} SET name = ? WHERE id = ?', [mb_substr(trim($name), 0, 100), $id]);
    }

    // ---- slowing down guesses ---------------------------------------------------------

    /** Whether [$what] (a sign-in from one address, say) is locked out right now. */
    public function blocked(string $what): bool
    {
        $row = $this->store->db->one('SELECT n, until FROM {throttle} WHERE k = ?', [self::throttleKey($what)]);
        return $row !== null && (int) $row['n'] >= 8 && (int) $row['until'] > $this->store->now();
    }

    /** Counts a wrong guess. Eight in fifteen minutes locks [$what] for fifteen more. */
    public function miss(string $what): void
    {
        $db = $this->store->db;
        $k = self::throttleKey($what);
        $now = $this->store->now();
        $row = $db->one('SELECT n, until FROM {throttle} WHERE k = ?', [$k]);
        if ($row === null || (int) $row['until'] <= $now) {
            $db->upsert('throttle', ['k' => $k], ['n' => 1, 'until' => $now + 900]);
            return;
        }
        $db->run('UPDATE {throttle} SET n = n + 1, until = ? WHERE k = ?', [$now + 900, $k]);
    }

    public function clear(string $what): void
    {
        $this->store->db->run('DELETE FROM {throttle} WHERE k = ?', [self::throttleKey($what)]);
    }

    private static function throttleKey(string $what): string
    {
        return substr(hash('sha256', $what), 0, 40);
    }

    private static function hash(string $s): string
    {
        return hash('sha256', $s);
    }
}
