<?php
declare(strict_types=1);

namespace Precis;

/**
 * The addresses the owner sends from, kept so every device has them: the
 * name, the signature and its pictures, and, for an address that sends
 * through a mail server of its own, that server and its password.
 *
 * Each address is kept locked, the same way the Google sign-in is. It is
 * handed only to a device that has joined, and only over https. Nothing
 * here is ever shown on the owner's page or written to the notes.
 */
final class Sending
{
    /** The most one address may weigh, pictures included. */
    public const MAX_BYTES = 3_000_000;
    public const MAX_ADDRESSES = 60;

    public function __construct(private readonly Store $store)
    {
    }

    /** A number that grows with every change, so devices know when to look again. */
    public function rev(): int
    {
        return (int) $this->store->get('sending.rev', '0');
    }

    public function count(): int
    {
        return (int) $this->store->db->val('SELECT COUNT(*) FROM {vault}');
    }

    /** How many of the kept addresses carry a password for a server of their own. */
    public function withPassword(): int
    {
        $n = 0;
        foreach ($this->all() as $a) {
            $n += (int) (($a['password'] ?? '') !== '');
        }
        return $n;
    }

    /** @return list<array<string, mixed>> every address, as the devices gave it */
    public function all(): array
    {
        $out = [];
        foreach ($this->store->db->all('SELECT k, v FROM {vault} ORDER BY k') as $row) {
            $a = Store::decode($this->store->crypto->open((string) $row['v']));
            if ($a !== []) {
                $out[] = ['email' => (string) $row['k']] + $a;
            }
        }
        return $out;
    }

    /**
     * Takes in addresses a device changed. An entry with `deleted` is
     * forgotten. Returns how many changed.
     *
     * @param list<mixed> $addresses
     */
    public function put(array $addresses): int
    {
        if (count($addresses) > self::MAX_ADDRESSES) {
            throw new \InvalidArgumentException('Too many addresses in one go.');
        }
        $db = $this->store->db;
        $changed = 0;
        foreach ($addresses as $a) {
            if (!is_array($a)) {
                throw new \InvalidArgumentException('An address must be an object.');
            }
            $email = strtolower(trim((string) ($a['email'] ?? '')));
            if ($email === '' || strlen($email) > 320 || !str_contains($email, '@')) {
                throw new \InvalidArgumentException('An address is missing its email.');
            }
            unset($a['email']);
            if (!empty($a['deleted'])) {
                $changed += $db->run('DELETE FROM {vault} WHERE k = ?', [$email])->rowCount();
                continue;
            }
            $json = Store::json($a);
            if (strlen($json) > self::MAX_BYTES) {
                throw new \InvalidArgumentException('That address’s signature pictures are too large to keep.');
            }
            $old = $db->val('SELECT v FROM {vault} WHERE k = ?', [$email]);
            if ($old !== null && $this->store->crypto->open((string) $old) === $json) {
                continue;
            }
            $db->upsert('vault', ['k' => $email], ['v' => $this->store->crypto->seal($json), 'at' => $this->store->now()]);
            $changed++;
        }
        if ($changed > 0) {
            $this->store->set('sending.rev', (string) ($this->rev() + 1));
        }
        return $changed;
    }

    /** Forgets every address and password kept here. Devices keep their own copies. */
    public function forget(): void
    {
        $this->store->db->run('DELETE FROM {vault}');
        $this->store->set('sending.rev', (string) ($this->rev() + 1));
        $this->store->log('info', 'The sending addresses kept for devices were forgotten.');
    }
}
