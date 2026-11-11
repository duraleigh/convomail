<?php
declare(strict_types=1);

namespace Precis;

/** Signs in an email's headers that it was sent in bulk. Same as the app's BulkSignals. */
final class Signals
{
    public function __construct(
        public readonly bool $listUnsubscribe = false,
        public readonly bool $listId = false,
        public readonly bool $listPost = false,
        public readonly bool $feedbackId = false,
        public readonly bool $precedenceBulk = false,
        public readonly bool $autoSubmitted = false,
        public readonly ?string $listIdValue = null,
    ) {
    }

    public function any(): bool
    {
        return $this->listUnsubscribe || $this->listId || $this->listPost || $this->feedbackId || $this->precedenceBulk || $this->autoSubmitted;
    }

    /** Compact form for storing, e.g. `u,i;list.example.com`. */
    public function encode(): string
    {
        $flags = implode(',', array_keys(array_filter([
            'u' => $this->listUnsubscribe,
            'i' => $this->listId,
            'o' => $this->listPost,
            'f' => $this->feedbackId,
            'b' => $this->precedenceBulk,
            'a' => $this->autoSubmitted,
        ])));
        return $this->listIdValue === null || $this->listIdValue === '' ? $flags : $flags . ';' . str_replace(';', ' ', $this->listIdValue);
    }

    public static function decode(?string $s): self
    {
        if ($s === null) {
            return new self();
        }
        $semi = strpos($s, ';');
        $flags = array_flip(explode(',', $semi === false ? $s : substr($s, 0, $semi)));
        return new self(
            listUnsubscribe: isset($flags['u']),
            listId: isset($flags['i']),
            listPost: isset($flags['o']),
            feedbackId: isset($flags['f']),
            precedenceBulk: isset($flags['b']),
            autoSubmitted: isset($flags['a']),
            listIdValue: $semi === false ? null : substr($s, $semi + 1),
        );
    }

    /** From raw header values (null when the header is absent). */
    public static function fromHeaders(?string $listUnsubscribe = null, ?string $listId = null, ?string $listPost = null, ?string $feedbackId = null, ?string $precedence = null, ?string $autoSubmitted = null): self
    {
        $prec = $precedence === null ? null : Classifier::lower(Classifier::trim($precedence));
        $auto = $autoSubmitted === null ? null : Classifier::lower(Classifier::trim($autoSubmitted));
        $has = static fn (?string $v): bool => $v !== null && Classifier::trim($v) !== '';
        return new self(
            listUnsubscribe: $has($listUnsubscribe),
            listId: $has($listId),
            listPost: $has($listPost),
            feedbackId: $has($feedbackId),
            precedenceBulk: $prec === 'bulk' || $prec === 'list' || $prec === 'junk',
            autoSubmitted: $auto !== null && $auto !== '' && $auto !== 'no',
            listIdValue: $listId === null ? null : self::listIdCore($listId),
        );
    }

    private static function listIdCore(string $v): string
    {
        $v = Classifier::clean($v);
        $core = preg_match('~<([^>]+)>~u', $v, $m) === 1 ? $m[1] : $v;
        return Classifier::lower(Classifier::trim($core));
    }
}
