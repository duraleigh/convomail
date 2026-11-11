<?php
declare(strict_types=1);

namespace Precis;

use RuntimeException;

/** Something Google refused, or that needs the owner to sign in again. */
final class GoogleError extends RuntimeException
{
    public function __construct(string $message, public readonly int $status = 0, public readonly bool $needsSignIn = false)
    {
        parent::__construct($message);
    }
}
