<?php
declare(strict_types=1);

namespace Precis;

/**
 * What each reader costs, in dollars per million tokens, as Anthropic's
 * price page listed them on November 11, 2026. The meter multiplies these by
 * what Anthropic reports each reading used; nothing is estimated.
 */
final class Prices
{
    /** The readers the helper can use: best, middle, cheapest. */
    public const MODELS = [
        'claude-opus-5-5' => ['name' => 'Claude Opus 5.5', 'in' => 4.0, 'out' => 20.0, 'cacheRead' => 0.20, 'cacheWrite' => 5.0],
        'claude-sonnet-5-5' => ['name' => 'Claude Sonnet 5.5', 'in' => 2.0, 'out' => 10.0, 'cacheRead' => 0.10, 'cacheWrite' => 2.50],
        'claude-haiku-5-5' => ['name' => 'Claude Haiku 5.5', 'in' => 0.10, 'out' => 0.50, 'cacheRead' => 0.01, 'cacheWrite' => 0.125],
    ];

    public static function known(string $model): bool
    {
        return isset(self::MODELS[$model]);
    }

    public static function name(string $model): string
    {
        return self::MODELS[$model]['name'] ?? $model;
    }

    /** The cost of one reading in millionths of a dollar, rounded up. */
    public static function micro(string $model, int $in, int $out, int $cacheRead = 0, int $cacheWrite = 0): int
    {
        $p = self::MODELS[$model] ?? self::MODELS['claude-opus-5-5'];
        // Dollars per million tokens is the same number as millionths of a dollar per token.
        return (int) ceil($in * $p['in'] + $out * $p['out'] + $cacheRead * $p['cacheRead'] + $cacheWrite * $p['cacheWrite']);
    }

    /** Millionths of a dollar as "$1.23" (or "$0.004" when under a cent). */
    public static function dollars(int $micro): string
    {
        $d = $micro / 1_000_000;
        return '$' . ($d > 0 && $d < 0.01 ? rtrim(rtrim(number_format($d, 4), '0'), '.') : number_format($d, 2));
    }
}
