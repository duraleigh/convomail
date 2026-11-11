<?php
declare(strict_types=1);

namespace Precis\Tests;

use Precis\Classifier;
use Precis\Piles;
use Precis\Signals;

/**
 * The helper must sort exactly as the app does. tests/golden/classifier.json
 * holds worked examples written by the app (test/helper_golden_test.dart);
 * every one must come out the same here.
 */
$golden = static function (): array {
    static $g = null;
    $g ??= json_decode((string) file_get_contents(__DIR__ . '/golden/classifier.json'), true, 512, JSON_THROW_ON_ERROR);
    return $g;
};

$rules = static fn (array $list): array => array_map(static fn (array $r): array => ['field' => $r['field'], 'pattern' => $r['pattern'], 'bucket' => $r['bucket'], 'category' => $r['category']], $list);

/** Fails with the first few differences and how many there were. */
$report = static function (array $wrong, int $total, string $what): void {
    if ($wrong === []) {
        return;
    }
    throw new Failed(count($wrong) . " of $total $what differ. First:\n" . implode("\n", array_slice($wrong, 0, 4)));
};

return [
    'senders: who is a person, with the same reasons' => function () use ($golden, $rules, $report): void {
        $g = $golden();
        $wrong = [];
        foreach ($g['senders'] as $i => $case) {
            $got = (new Classifier($rules($case['rules']), $g['names']))->classifySender($case['facts']);
            if ($got !== $case['want']) {
                $wrong[] = "#$i " . show($case['facts']) . "\n  want " . show($case['want']) . "\n   got " . show($got);
            }
        }
        check(count($g['senders']) >= 2000, 'too few examples');
        $report($wrong, count($g['senders']), 'senders');
    },

    'rules read the same in words' => function () use ($golden): void {
        $wrong = [];
        $n = 0;
        foreach ($golden()['senders'] as $case) {
            foreach ($case['rules'] as $r) {
                $n++;
                if (Classifier::describeRule($r) !== $r['describe']) {
                    $wrong[] = show($r) . ' got ' . Classifier::describeRule($r);
                }
            }
        }
        check($n > 100, 'too few rules in the examples');
        if ($wrong !== []) {
            throw new Failed(count($wrong) . " rule descriptions differ. First:\n" . $wrong[0]);
        }
    },

    'emails: personal exceptions, greetings, tags and rule matches' => function () use ($golden, $rules, $report): void {
        $g = $golden();
        $wrong = [];
        foreach ($g['messages'] as $i => $case) {
            $list = $rules($case['rules']);
            $c = new Classifier($list, $g['names']);
            $f = $case['facts'];
            $got = [
                'exception' => $c->isPersonalException($f),
                'greets' => $c->greetsUserByName($f['snippet']),
                'category' => $c->messageCategory($f, $case['senderDefault']),
                'inferred' => Classifier::inferCategory($f),
                'specific' => Classifier::specificCategory($f['subject'], $f['from']),
                'matches' => array_map(static fn (array $r): bool => Classifier::ruleMatchesMessage($r, $f), $list),
            ];
            if ($got !== $case['want']) {
                $wrong[] = "#$i " . show($f) . "\n  want " . show($case['want']) . "\n   got " . show($got);
            }
        }
        $report($wrong, count($g['messages']), 'emails');
    },

    'Feed or Noise' => function () use ($golden, $report): void {
        $g = $golden();
        $wrong = [];
        foreach ($g['piles'] as $i => $case) {
            $got = Piles::pileFor($case['chosen'], $case['category'], $case['total'], $case['unread'], $case['mail']);
            if ($got !== $case['want']) {
                $wrong[] = "#$i " . show($case) . ' got ' . $got;
            }
        }
        $report($wrong, count($g['piles']), 'piles');
    },

    'addresses are tidied the same way' => function () use ($golden, $report): void {
        $g = $golden();
        $wrong = [];
        foreach ($g['addresses'] as $case) {
            $got = Classifier::normalizeAddress($case['raw']);
            if ($got !== $case['want']) {
                $wrong[] = show($case) . ' got ' . show($got);
            }
        }
        $report($wrong, count($g['addresses']), 'addresses');
    },

    'machine addresses and sending domains' => function () use ($golden, $report): void {
        $g = $golden();
        $wrong = [];
        foreach ($g['machine'] as $case) {
            $domain = substr($case['address'], strpos($case['address'], '@') + 1);
            $got = [Classifier::machineAddressReason($case['address']), Classifier::isListedSendingDomain($domain), Classifier::isSendingSubdomain($domain)];
            if ($got !== [$case['want'], $case['listed'], $case['sub']]) {
                $wrong[] = show($case) . ' got ' . show($got);
            }
        }
        $report($wrong, count($g['machine']), 'addresses');
    },

    'bulk signs read from headers' => function () use ($golden, $report): void {
        $g = $golden();
        $wrong = [];
        foreach ($g['headers'] as $case) {
            $h = $case['h'];
            $s = Signals::fromHeaders($h['listUnsubscribe'], $h['listId'], $h['listPost'], $h['feedbackId'], $h['precedence'], $h['autoSubmitted']);
            $got = [$s->encode(), $s->any(), Signals::decode($s->encode())->encode()];
            if ($got !== [$case['want'], $case['any'], $case['again']]) {
                $wrong[] = show($case) . ' got ' . show($got);
            }
        }
        $report($wrong, count($g['headers']), 'header sets');
    },

    'what a run of subjects says about a sender' => function () use ($golden, $report): void {
        $g = $golden();
        $wrong = [];
        foreach ($g['profiles'] as $case) {
            [$cat, $share] = Classifier::subjectProfile($case['subjects']);
            if ($cat !== $case['cat'] || abs($share - (float) $case['share']) > 1e-9) {
                $wrong[] = show($case) . ' got ' . show([$cat, $share]);
            }
        }
        $report($wrong, count($g['profiles']), 'subject runs');
    },

    'first names for greetings' => function (): void {
        same(['clay', 'mary-ann', 'oneil'], Classifier::firstNames(['Clay Example', '  ', 'Mary-Ann  Smith', 'clay other', 'J', "O'Neil X"]));
    },
];
