<?php
declare(strict_types=1);

namespace Precis\Tests;

use Precis\Crypto;
use Precis\Db;
use Precis\Schema;
use Precis\Store;

final class Failed extends \Exception
{
}

function check(bool $ok, string $why = 'expected true'): void
{
    if (!$ok) {
        throw new Failed($why);
    }
}

function same(mixed $want, mixed $got, string $what = ''): void
{
    if ($want !== $got) {
        throw new Failed(($what === '' ? '' : "$what\n") . 'want: ' . show($want) . "\n got: " . show($got));
    }
}

function show(mixed $v): string
{
    $s = json_encode($v, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PARTIAL_OUTPUT_ON_ERROR);
    return strlen((string) $s) > 600 ? substr((string) $s, 0, 600) . '…' : (string) $s;
}

/** Runs [$work] and returns the exception it threw, failing when it threw none. */
function throws(callable $work, string $what = 'expected a failure'): \Throwable
{
    try {
        $work();
    } catch (Failed $e) {
        throw $e;
    } catch (\Throwable $e) {
        return $e;
    }
    throw new Failed($what);
}

/** A clock a check can move. */
final class Clock
{
    public function __construct(public int $now = 1_794_000_000)
    {
    }

    public function __invoke(): int
    {
        return $this->now;
    }
}

/** A fresh, empty helper store in memory. */
function store(?Clock $clock = null): Store
{
    $db = Db::memory();
    Schema::migrate($db);
    return new Store($db, new Crypto(str_repeat("\x07", 32)), $clock === null ? null : \Closure::fromCallable($clock));
}
