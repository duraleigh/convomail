<?php
declare(strict_types=1);

namespace Precis;

use RuntimeException;

/**
 * Seals the secrets the helper keeps (the Google sign-in, the sign-in
 * client's secret) with a key that lives in a private file outside the web
 * folder and outside the database. A copy of the database alone opens none
 * of them.
 */
final class Crypto
{
    private const CIPHER = 'aes-256-gcm';

    public function __construct(private readonly string $key)
    {
        if (strlen($key) !== 32) {
            throw new RuntimeException('The sealing key must be 32 bytes.');
        }
    }

    /** Loads the key from [$file], making it on first use. */
    public static function fromFile(string $file): self
    {
        if (!is_file($file)) {
            $dir = dirname($file);
            if (!is_dir($dir)) {
                mkdir($dir, 0700, true);
            }
            file_put_contents($file, base64_encode(random_bytes(32)), LOCK_EX);
            @chmod($file, 0600);
        }
        $key = base64_decode(trim((string) file_get_contents($file)), true);
        if ($key === false) {
            throw new RuntimeException('The sealing key file is damaged.');
        }
        return new self($key);
    }

    public function seal(string $plain): string
    {
        $nonce = random_bytes(12);
        $tag = '';
        $cipher = openssl_encrypt($plain, self::CIPHER, $this->key, OPENSSL_RAW_DATA, $nonce, $tag);
        if ($cipher === false) {
            throw new RuntimeException('Sealing failed.');
        }
        return 'v1:' . base64_encode($nonce . $tag . $cipher);
    }

    public function open(string $sealed): string
    {
        if (!str_starts_with($sealed, 'v1:')) {
            throw new RuntimeException('Not a sealed value.');
        }
        $raw = base64_decode(substr($sealed, 3), true);
        if ($raw === false || strlen($raw) < 28) {
            throw new RuntimeException('The sealed value is damaged.');
        }
        $plain = openssl_decrypt(substr($raw, 28), self::CIPHER, $this->key, OPENSSL_RAW_DATA, substr($raw, 0, 12), substr($raw, 12, 16));
        if ($plain === false) {
            throw new RuntimeException('The sealed value could not be opened.');
        }
        return $plain;
    }

    /** A random token as URL-safe text. */
    public static function token(int $bytes = 32): string
    {
        return rtrim(strtr(base64_encode(random_bytes($bytes)), '+/', '-_'), '=');
    }

    /** A short code a person can type: letters and digits that are hard to mix up. */
    public static function code(int $length = 8): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $out = '';
        for ($i = 0; $i < $length; $i++) {
            $out .= $alphabet[random_int(0, strlen($alphabet) - 1)];
        }
        return $out;
    }
}
