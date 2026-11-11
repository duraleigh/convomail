<?php
declare(strict_types=1);

namespace Precis;

/** One incoming web request, in a form the checks can also build by hand. */
final class Request
{
    /**
     * @param array<string, string> $query
     * @param array<string, string> $form
     * @param array<string, string> $headers lower-cased names
     */
    public function __construct(
        public readonly string $method,
        public readonly string $path,
        public readonly array $query = [],
        public readonly array $form = [],
        public readonly array $headers = [],
        public readonly string $body = '',
        public readonly string $ip = '',
        public readonly bool $https = true,
        public readonly string $host = '',
    ) {
    }

    public static function fromGlobals(): self
    {
        $headers = [];
        foreach ($_SERVER as $k => $v) {
            if (str_starts_with($k, 'HTTP_') && is_string($v)) {
                $headers[strtolower(str_replace('_', '-', substr($k, 5)))] = $v;
            }
        }
        if (isset($_SERVER['CONTENT_TYPE'])) {
            $headers['content-type'] = (string) $_SERVER['CONTENT_TYPE'];
        }
        if (!isset($headers['authorization']) && isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
            $headers['authorization'] = (string) $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        }
        $path = (string) parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH);
        $https = (($_SERVER['HTTPS'] ?? '') !== '' && $_SERVER['HTTPS'] !== 'off') || ($headers['x-forwarded-proto'] ?? '') === 'https';
        $strings = static fn (array $a): array => array_map('strval', array_filter($a, 'is_scalar'));
        return new self(
            strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET')),
            '/' . trim($path, '/'),
            $strings($_GET),
            $strings($_POST),
            $headers,
            (string) file_get_contents('php://input'),
            (string) ($_SERVER['REMOTE_ADDR'] ?? ''),
            $https,
            strtolower((string) ($_SERVER['HTTP_HOST'] ?? '')),
        );
    }

    /** @return array<string, mixed>|null the body as JSON, or null when it is not an object */
    public function json(): ?array
    {
        if ($this->body === '') {
            return null;
        }
        $v = json_decode($this->body, true, 64);
        return is_array($v) ? $v : null;
    }

    public function deviceToken(): ?string
    {
        if (($this->headers['x-precis-token'] ?? '') !== '') {
            return $this->headers['x-precis-token'];
        }
        $auth = $this->headers['authorization'] ?? '';
        return str_starts_with($auth, 'Bearer ') ? substr($auth, 7) : null;
    }

    public function isLocal(): bool
    {
        $h = preg_replace('~:\d+$~', '', $this->host);
        return $h === 'localhost' || $h === '127.0.0.1' || $h === '[::1]';
    }
}
