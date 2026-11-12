<?php
declare(strict_types=1);

namespace Precis;

/**
 * The assistant, as the helper sees it: something that is handed standing
 * instructions and one email, and answers in a fixed shape.
 *
 * There is one real one (Claude, through the owner's own Anthropic key) and
 * a stand-in for the checks. A newer or cheaper reader is a setting here,
 * not a change anywhere else.
 */
interface Assistant
{
    /**
     * @param array<string, mixed> $shape the JSON shape the answer must have
     * @param bool $keepReady ask Anthropic to keep the instructions ready for the next few minutes. That costs a
     *   quarter more once and a small fraction after, so it pays only when many emails are read close together.
     * @param list<array{mime: string, data: string, name: string}> $files files attached to the email (a PDF or a picture,
     *   base64), shown to the assistant before the email itself
     * @param int $room how long the answer may be, when it needs more than a short reading does
     * @return array{data: ?array<string, mixed>, refused: bool, cut: bool, model: string, in: int, out: int, cacheRead: int, cacheWrite: int}
     *
     * @throws AssistantError when the assistant could not be reached or said no
     */
    public function read(string $model, string $instructions, string $email, array $shape, bool $keepReady = false, array $files = [], int $room = 0): array;

    /** Whether the key is let in. Costs nothing. */
    public function keyWorks(): bool;
}
