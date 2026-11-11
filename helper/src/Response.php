<?php
declare(strict_types=1);

namespace Precis;

final class Response
{
    /** @param array<string, string> $headers */
    public function __construct(public readonly int $status, public readonly string $body = '', public readonly array $headers = [])
    {
    }

    public static function json(array $data, int $status = 200): self
    {
        return new self($status, json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE | JSON_THROW_ON_ERROR), ['Content-Type' => 'application/json; charset=utf-8']);
    }

    public static function error(string $message, int $status): self
    {
        return self::json(['error' => $message], $status);
    }

    public static function html(string $html, int $status = 200): self
    {
        return new self($status, $html, ['Content-Type' => 'text/html; charset=utf-8']);
    }

    public static function redirect(string $to): self
    {
        return new self(303, '', ['Location' => $to]);
    }

    /** @return array<string, mixed> */
    public function data(): array
    {
        return Store::decode($this->body);
    }

    public function send(): void
    {
        http_response_code($this->status);
        $always = [
            'Cache-Control' => 'no-store',
            'X-Content-Type-Options' => 'nosniff',
            'X-Frame-Options' => 'DENY',
            'Referrer-Policy' => 'no-referrer',
            'Content-Security-Policy' => "default-src 'none'; style-src 'unsafe-inline'; form-action 'self' https://accounts.google.com; base-uri 'none'; frame-ancestors 'none'",
            'Strict-Transport-Security' => 'max-age=31536000',
            'X-Robots-Tag' => 'noindex, nofollow',
        ];
        foreach ($this->headers + $always as $k => $v) {
            header("$k: $v");
        }
        echo $this->body;
    }
}
