<?php
declare(strict_types=1);

namespace Precis;

/**
 * Outgoing web requests. The live helper uses curl; the checks swap in a
 * stand-in, so no check ever reaches the internet.
 */
interface Http
{
    /**
     * @param array<string, string> $headers
     * @return array{status: int, body: string}
     */
    public function request(string $method, string $url, array $headers = [], ?string $body = null): array;

    /**
     * Several GET requests at once, answers in the same order.
     *
     * @param list<string> $urls
     * @param array<string, string> $headers
     * @return list<array{status: int, body: string}>
     */
    public function getMany(array $urls, array $headers = []): array;
}
