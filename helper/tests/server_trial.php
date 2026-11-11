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

    default:
        echo "run SHARD OF | report | zone MINUTES | choose MODEL | ceiling DOLLARS | on | off | status\n";
        exit(2);
}
