<?php
declare(strict_types=1);

namespace Precis;

/**
 * The owner's browser session on the helper's own page. The live one rides
 * on a cookie only sent over https; the checks use a plain one in memory.
 */
class Session
{
    /** @var array<string, mixed> */
    protected array $data = [];

    public function get(string $key): mixed
    {
        return $this->data[$key] ?? null;
    }

    public function set(string $key, mixed $value): void
    {
        $this->data[$key] = $value;
    }

    public function clear(): void
    {
        $this->data = [];
    }

    /** A fresh session id after signing in, so an old one cannot be reused. */
    public function renew(): void
    {
    }

    /** A token every form must carry back, so another site cannot post for the owner. */
    public function formToken(): string
    {
        $t = $this->get('csrf');
        if (!is_string($t) || $t === '') {
            $t = Crypto::token(24);
            $this->set('csrf', $t);
        }
        return $t;
    }

    public static function live(bool $secure): self
    {
        return new class($secure) extends Session {
            public function __construct(bool $secure)
            {
                session_name('precis');
                session_set_cookie_params(['lifetime' => 0, 'path' => '/', 'secure' => $secure, 'httponly' => true, 'samesite' => 'Lax']);
                ini_set('session.use_strict_mode', '1');
                ini_set('session.use_only_cookies', '1');
                session_start();
                $this->data = &$_SESSION;
            }

            public function clear(): void
            {
                $_SESSION = [];
                session_regenerate_id(true);
            }

            public function renew(): void
            {
                session_regenerate_id(true);
            }
        };
    }
}
