<?php
declare(strict_types=1);

/**
 * The test week: the same real emails read by more than one reader, with
 * the meter running, so their cost and their answers can be compared.
 *
 *   php server_trial.php run SHARD OF     read (this worker takes emails whose number % OF == SHARD)
 *   php server_trial.php report           what it cost and how the readers compare, in counts only
 *   php server_trial.php zone MINUTES     tell the helper the owner's clock (minutes ahead of UTC)
 *   php server_trial.php choose MODEL     keep that reader's answers for the test week and use it from now on
 *   php server_trial.php ceiling DOLLARS  set the monthly ceiling
 *   php server_trial.php on | off         turn the assistant on or off
 *   php server_trial.php status           how the assistant is doing, in counts only
 *   php server_trial.php threads          read again the emails from people that sit in a thread, now with the
 *                                         earlier emails shown, and say what changed and what it cost (counts only)
 *   php server_trial.php step4            sent mail read, the day's sentence, and this month's cost by purpose (counts only)
 *
 * Prints no email addresses, names, subjects or words. Stops itself when the
 * test has cost ten dollars.
 */

use Precis\App;
use Precis\AssistantError;
use Precis\CurlHttp;
use Precis\Prices;
use Precis\Readings;
use Precis\Session;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

const TRIAL_DAYS = 7;
const TRIAL_CAP = 10_000_000;
const TRIAL_MODELS = ['claude-opus-5-5', 'claude-sonnet-5-5', 'claude-haiku-5-5'];

$app = new App(PRECIS_HOME, new CurlHttp(), new Session());
$store = $app->store();
$db = $store->db;
$readings = $app->readings();
$now = time();
$money = static fn (int $micro): string => '$' . number_format($micro / 1_000_000, 4);

/** The emails of the test week that the assistant would be shown. */
$week = static function () use ($db, $readings, $now): array {
    $out = [];
    foreach ($db->all("SELECT * FROM {emails} WHERE inbox = 1 AND gone = 0 AND is_from_me = 0 AND cls <> '' AND message_id <> '' AND at > ? ORDER BY at DESC", [$now - TRIAL_DAYS * 86400]) as $e) {
        if ($readings->wanted($e)) {
            $out[] = $e;
        }
    }
    return $out;
};

switch ($argv[1] ?? '') {
    case 'zone':
        $readings->setZone((int) ($argv[2] ?? 0));
        echo 'the owner\'s clock is ' . $readings->zone() . " minutes from UTC\n";
        break;

    case 'run':
        $shard = (int) ($argv[2] ?? 0);
        $of = max(1, (int) ($argv[3] ?? 1));
        if (!$readings->hasKey()) {
            echo "no key is saved yet\n";
            exit(1);
        }
        $assistant = $readings->assistant();
        $done = 0;
        foreach ($week() as $e) {
            $id = (int) $e['id'];
            if ($id % $of !== $shard) {
                continue;
            }
            $have = [];
            foreach ($db->all('SELECT model FROM {trial} WHERE email_id = ? AND error IS NULL', [$id]) as $r) {
                $have[(string) $r['model']] = true;
            }
            $todo = array_values(array_filter(TRIAL_MODELS, static fn (string $m): bool => !isset($have[$m])));
            if ($todo === []) {
                continue;
            }
            $ctx = $readings->prepare($e);
            if ($ctx === null) {
                continue;
            }
            foreach ($todo as $model) {
                if ((int) $db->val('SELECT COALESCE(SUM(micro), 0) FROM {trial}') >= TRIAL_CAP) {
                    echo "stopped: the test reached its ten-dollar limit\n";
                    exit(0);
                }
                $answer = null;
                $error = null;
                $t = microtime(true);
                for ($try = 0; $try < 4; $try++) {
                    try {
                        $answer = $assistant->read($model, Readings::INSTRUCTIONS, $ctx['prompt'], Readings::SHAPE, true);
                        $error = null;
                        break;
                    } catch (AssistantError $err) {
                        $error = $err->kind . ': ' . $err->getMessage();
                        if ($err->kind === 'key' || $err->kind === 'credit') {
                            echo 'stopped: ' . $err->getMessage() . "\n";
                            exit(1);
                        }
                        sleep(4 * ($try + 1));
                    }
                }
                $ms = (int) round((microtime(true) - $t) * 1000);
                if ($answer === null) {
                    $db->upsert('trial', ['email_id' => $id, 'model' => $model], ['result' => '{}', 'ms' => $ms, 'error' => mb_substr((string) $error, 0, 200)]);
                    continue;
                }
                $micro = $readings->count($model, 'trial', $answer);
                $result = $answer['refused'] || $answer['data'] === null ? null : Readings::normalize($answer['data'], $ctx);
                $db->upsert('trial', ['email_id' => $id, 'model' => $model], [
                    'result' => $result === null ? '{}' : (string) json_encode($result + ['person' => $ctx['person'], 'chars' => $ctx['chars']], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                    'tin' => $answer['in'], 'tout' => $answer['out'], 'tcr' => $answer['cacheRead'], 'tcw' => $answer['cacheWrite'],
                    'micro' => $micro, 'ms' => $ms,
                    'error' => $result === null ? ($answer['refused'] ? 'declined' : 'no answer') : null,
                ]);
                $done++;
            }
        }
        echo "worker $shard of $of finished: $done readings\n";
        break;

    case 'report':
        $emails = $week();
        $people = count(array_filter($emails, static fn (array $e): bool => (string) $e['cls'] === 'people'));
        $inbox = (int) $db->val("SELECT COUNT(*) FROM {emails} WHERE inbox = 1 AND gone = 0 AND is_from_me = 0 AND at > ?", [$now - TRIAL_DAYS * 86400]);
        echo 'test week: ' . $inbox . ' emails arrived in the inbox in 7 days | shown to the assistant: ' . count($emails) . ' (from people ' . $people . ', not from people ' . (count($emails) - $people) . ') | never shown (settled Noise, sign-in codes): ' . ($inbox - count($emails)) . "\n";
        $ids = array_map(static fn (array $e): int => (int) $e['id'], $emails);
        $by = [];
        foreach ($db->all('SELECT * FROM {trial}') as $r) {
            if (in_array((int) $r['email_id'], $ids, true)) {
                $by[(string) $r['model']][(int) $r['email_id']] = $r;
            }
        }
        $best = TRIAL_MODELS[0];
        foreach (TRIAL_MODELS as $model) {
            $rows = $by[$model] ?? [];
            $ok = array_filter($rows, static fn (array $r): bool => $r['error'] === null);
            $sum = static fn (string $k): int => (int) array_sum(array_map(static fn (array $r): int => (int) $r[$k], $rows));
            $micro = $sum('micro');
            $n = count($ok);
            echo "\n" . Prices::name($model) . ': read ' . $n . ' of ' . count($emails) . ' | could not read ' . (count($rows) - $n) . "\n";
            if ($n === 0) {
                continue;
            }
            echo '  cost for the week: ' . $money($micro) . ' | per email ' . $money((int) round($micro / max(1, count($rows)))) . ' | a 30-day month at this week\'s pace: ' . $money((int) round($micro * 30 / TRIAL_DAYS)) . "\n";
            echo '  used: fresh input ' . $sum('tin') . ' | kept-ready input ' . $sum('tcr') . ' | stored-for-reuse input ' . $sum('tcw') . ' | output (thinking included) ' . $sum('tout') . ' | average wait ' . number_format($sum('ms') / max(1, count($rows)) / 1000, 1) . " s\n";
            $focus = 0;
            $due = 0;
            $noise = 0;
            $feed = 0;
            $same = ['focus' => 0, 'place' => 0, 'n' => 0, 'placeN' => 0];
            foreach ($ok as $id => $r) {
                $d = json_decode((string) $r['result'], true) ?: [];
                $focus += (int) (($d['focus'] ?? false) === true);
                $due += (int) (($d['due'] ?? null) !== null);
                $noise += (int) (($d['place'] ?? '') === 'noise');
                $feed += (int) (($d['place'] ?? '') === 'feed');
                $b = isset($by[$best][$id]) && $by[$best][$id]['error'] === null ? (json_decode((string) $by[$best][$id]['result'], true) ?: null) : null;
                if ($b !== null) {
                    $same['n']++;
                    $same['focus'] += (int) (($b['focus'] ?? false) === ($d['focus'] ?? false));
                    if (($b['place'] ?? '') !== '') {
                        $same['placeN']++;
                        $same['place'] += (int) (($b['place'] ?? '') === ($d['place'] ?? ''));
                    }
                }
            }
            echo '  said "needs you": ' . $focus . ' (with a "by" time: ' . $due . ') | said Feed: ' . $feed . ' | said Noise: ' . $noise . "\n";
            if ($model !== $best && $same['n'] > 0) {
                echo '  agrees with ' . Prices::name($best) . ' on "needs you": ' . $same['focus'] . ' of ' . $same['n'] . ' | on Feed or Noise: ' . $same['place'] . ' of ' . $same['placeN'] . "\n";
            }
        }
        echo "\nthe test has cost " . $money((int) $db->val('SELECT COALESCE(SUM(micro), 0) FROM {trial}')) . ' in all (limit ' . $money(TRIAL_CAP) . ")\n";
        break;

    case 'choose':
        $model = (string) ($argv[2] ?? '');
        if (!Prices::known($model)) {
            echo "not a reader the helper knows\n";
            exit(1);
        }
        $readings->setModel($model);
        $kept = 0;
        foreach ($db->all('SELECT t.email_id, t.result FROM {trial} t LEFT JOIN {readings} r ON r.email_id = t.email_id WHERE t.model = ? AND t.error IS NULL AND r.email_id IS NULL', [$model]) as $r) {
            $d = json_decode((string) $r['result'], true);
            if (!is_array($d) || !isset($d['line'])) {
                continue;
            }
            $readings->keep((int) $r['email_id'], $model, ['line' => (string) $d['line'], 'focus' => ($d['focus'] ?? false) === true, 'ask' => (string) ($d['ask'] ?? ''), 'due' => isset($d['due']) ? (int) $d['due'] : null, 'place' => (string) ($d['place'] ?? ''), 'why' => array_values(array_map('strval', $d['why'] ?? []))]);
            $kept++;
        }
        echo 'reader set to ' . Prices::name($model) . "; kept $kept readings from the test week\n";
        break;

    case 'ceiling':
        $readings->setCeiling((int) round(((float) ($argv[2] ?? 0)) * 1_000_000));
        echo 'ceiling: ' . Prices::dollars($readings->ceiling()) . " a month\n";
        break;

    case 'on':
    case 'off':
        $readings->turn($argv[1] === 'on');
        echo 'the assistant is ' . ($readings->on() ? 'on' : 'off') . "\n";
        break;

    case 'status':
        $s = $readings->status();
        $queued = $readings->plan();
        echo 'key saved: ' . ($s['hasKey'] ? 'yes' : 'no') . ' | on: ' . ($s['on'] ? 'yes' : 'no') . ' | reader: ' . ($s['modelName'] === '' ? '(not chosen)' : $s['modelName']) . ' | clock: ' . $readings->zone() . " min from UTC\n";
        echo 'spent this month: ' . Prices::dollars((int) $s['month']) . ' of ' . Prices::dollars((int) $s['ceiling']) . ' | today: ' . Prices::dollars((int) $s['today']) . ' | problem: ' . ($s['problem'] === '' ? 'none' : $s['problem']) . "\n";
        $s = $readings->status();
        echo 'emails read: ' . $s['read'] . ' | waiting: ' . $s['waiting'] . ' (newly queued just now: ' . $queued . ') | need the owner now: ' . $s['focus'] . "\n";
        $states = [];
        foreach ($db->all('SELECT read_state, COUNT(*) AS n FROM {emails} WHERE inbox = 1 AND gone = 0 GROUP BY read_state ORDER BY read_state') as $r) {
            $states[] = ['not looked at', 'waiting', 'read', 'not to be read', 'will retry', 'given up'][(int) $r['read_state']] . ' ' . (int) $r['n'];
        }
        echo 'inbox emails by state: ' . implode(' | ', $states) . "\n";
        $p = $db->one("SELECT SUM(pile = 'feed') AS feed, SUM(pile = 'noise') AS noise, SUM(cls = 'people') AS people FROM {emails} WHERE inbox = 1 AND gone = 0 AND is_from_me = 0") ?? [];
        echo 'inbox emails by place: Chats ' . (int) $p['people'] . ' | Feed ' . (int) $p['feed'] . ' | Noise ' . (int) $p['noise'] . "\n";
        break;

    case 'threads':
        if (!$readings->ready()) {
            echo "the assistant is not on\n";
            exit(1);
        }
        $assistant = $readings->assistant();
        $model = $readings->model();
        $rows = $db->all("SELECT e.* FROM {emails} e JOIN {readings} r ON r.email_id = e.id
            WHERE e.cls = 'people' AND e.is_from_me = 0 AND e.inbox = 1 AND e.gone = 0 AND e.at > ? AND e.thread_id <> ''
              AND (SELECT COUNT(*) FROM {emails} t WHERE t.thread_id = e.thread_id AND t.gone = 0) > 1
            ORDER BY e.at DESC", [$now - Readings::DAYS * 86400]);
        $t = ['read' => 0, 'shown' => 0, 'gained' => 0, 'lost' => 0, 'moved' => 0, 'kept' => 0, 'none' => 0, 'focusOn' => 0, 'focusOff' => 0, 'in' => 0, 'out' => 0, 'cr' => 0, 'cw' => 0, 'micro' => 0, 'failed' => 0];
        foreach ($rows as $e) {
            $old = $db->one('SELECT focus, due FROM {readings} WHERE email_id = ?', [(int) $e['id']]);
            $ctx = $readings->prepare($e);
            if ($ctx === null) {
                continue;
            }
            try {
                $answer = $assistant->read($model, Readings::INSTRUCTIONS, $ctx['prompt'], Readings::SHAPE, true);
            } catch (AssistantError $err) {
                if ($err->kind === 'key' || $err->kind === 'credit') {
                    echo 'stopped: ' . $err->getMessage() . "\n";
                    break;
                }
                $t['failed']++;
                continue;
            }
            $t['micro'] += $readings->count($model, 'thread', $answer);
            $t['in'] += $answer['in'];
            $t['out'] += $answer['out'];
            $t['cr'] += $answer['cacheRead'];
            $t['cw'] += $answer['cacheWrite'];
            if ($answer['refused'] || $answer['data'] === null) {
                $t['failed']++;
                continue;
            }
            $new = Readings::normalize($answer['data'], $ctx);
            $t['read']++;
            $t['shown'] += (int) ($ctx['earlier'] > 0);
            $had = $old !== null && $old['due'] !== null;
            $has = $new['due'] !== null;
            $t[$had ? ($has ? ((int) $old['due'] === $new['due'] ? 'kept' : 'moved') : 'lost') : ($has ? 'gained' : 'none')]++;
            $wasFocus = $old !== null && (int) $old['focus'] === 1;
            $t['focusOn'] += (int) (!$wasFocus && $new['focus']);
            $t['focusOff'] += (int) ($wasFocus && !$new['focus']);
            $readings->keep((int) $e['id'], $model, $new);
        }
        echo 'emails from people that sit in a thread (inbox, 30 days): ' . count($rows) . ' | read again: ' . $t['read'] . ' | earlier emails were shown for: ' . $t['shown'] . ' | could not read: ' . $t['failed'] . "\n";
        echo '"by" time: gained ' . $t['gained'] . ' | changed ' . $t['moved'] . ' | same ' . $t['kept'] . ' | lost ' . $t['lost'] . ' | none before or after ' . $t['none'] . "\n";
        echo '"needs you": newly yes ' . $t['focusOn'] . ' | newly no ' . $t['focusOff'] . "\n";
        echo 'cost of this pass: ' . $money($t['micro']) . ' | per email ' . $money((int) round($t['micro'] / max(1, $t['read'] + $t['failed']))) . ' | fresh input ' . $t['in'] . ' | kept-ready input ' . $t['cr'] . ' | stored-for-reuse input ' . $t['cw'] . ' | output ' . $t['out'] . "\n";
        break;

    case 'setthreads':
        $readings->setThreads(($argv[2] ?? '') === 'on');
        echo 'earlier emails of a thread are ' . ($readings->threads() ? 'shown' : 'not shown') . " to the assistant\n";
        break;

    case 'step4':
        $s4 = $db->one("SELECT COUNT(*) AS n, SUM(r.asks) AS asks FROM {readings} r JOIN {emails} e ON e.id = r.email_id WHERE e.is_from_me = 1") ?? [];
        $mineAll = (int) $db->val('SELECT COUNT(*) FROM {emails} WHERE is_from_me = 1 AND gone = 0 AND at > ?', [$now - Readings::DAYS * 86400]);
        $mineWait = (int) $db->val('SELECT COUNT(*) FROM {emails} WHERE is_from_me = 1 AND gone = 0 AND at > ? AND read_state IN (0, 1, 4)', [$now - Readings::DAYS * 86400]);
        echo 'emails the owner sent, 30 days: ' . $mineAll . ' | read: ' . (int) $s4['n'] . ' | of those, asked for something: ' . (int) $s4['asks'] . ' | still waiting to be looked at: ' . $mineWait . "\n";
        $dayItem = $store->item('day', 'today');
        echo 'the day\'s sentence: ' . ($dayItem === null ? 'not written yet' : (($dayItem['text'] ?? '') === '' ? 'empty (nothing below it)' : mb_strlen((string) $dayItem['text']) . ' characters') . ', written ' . ($now - (int) ($dayItem['at'] ?? 0)) . ' s ago, after ' . (int) ($dayItem['after'] ?? 0) . ' new emails') . "\n";
        $st = $readings->status();
        echo 'earlier emails of a thread shown: ' . ($readings->threads() ? 'yes' : 'no') . "\n";
        echo 'need the owner now: ' . $st['focus'] . ' | past week: ' . $st['made7'] . ' lines made, ' . $st['fixed7'] . " corrected by the owner\n";
        foreach ($db->all("SELECT purpose, SUM(calls) AS calls, SUM(micro) AS micro FROM {spend} WHERE day LIKE ? GROUP BY purpose ORDER BY purpose", [gmdate('Y-m', $now + $readings->zone() * 60) . '-%']) as $r) {
            echo '  this month, ' . $r['purpose'] . ': ' . (int) $r['calls'] . ' readings, ' . $money((int) $r['micro']) . ((int) $r['calls'] > 0 ? ' (' . $money((int) round((int) $r['micro'] / (int) $r['calls'])) . ' each)' : '') . "\n";
        }
        break;

    default:
        echo "run SHARD OF | report | zone MINUTES | choose MODEL | ceiling DOLLARS | on | off | status | threads | step4\n";
        exit(2);
}
