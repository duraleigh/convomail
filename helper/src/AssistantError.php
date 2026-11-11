<?php
declare(strict_types=1);

namespace Precis;

use RuntimeException;

/**
 * The assistant could not do a reading. `kind` says what to do about it:
 *  - key:    the key was refused; nothing more is sent until it is replaced
 *  - credit: the Anthropic account has no credit or hit its own limit; paused
 *  - busy:   too many requests or Anthropic is overloaded; try again shortly
 *  - other:  this one reading failed; it is tried again later
 */
final class AssistantError extends RuntimeException
{
    public function __construct(string $message, public readonly string $kind = 'other', public readonly int $status = 0)
    {
        parent::__construct($message);
    }
}
