<?php
declare(strict_types=1);

/**
 * How the live helper is doing, in counts only:  php server_counts.php
 *
 * Prints no email addresses, names or subjects. Reads; changes nothing.
 */

use Precis\Db;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

/** @var array<string, mixed> $config */
$config = require PRECIS_HOME . '/config.php';
$db = Db::connect($config);
$now = time();
$ago = static fn (int $t): string => $t <= 0 ? 'never' : ($now - $t) . ' s ago';

foreach ($db->all('SELECT id, backfill_done, backfill_read, last_checked, last_notice, watch_expires, last_error, created FROM {accounts}') as $a) {
    echo 'mailbox ' . $a['id'] . ': first read ' . ((int) $a['backfill_done'] === 1 ? 'finished' : 'in progress') . ', ' . $a['backfill_read'] . ' emails listed; last looked ' . $ago((int) $a['last_checked'])
        . '; notice ' . ((int) $a['watch_expires'] > $now ? 'on' : 'off') . '; problem: ' . ($a['last_error'] === null ? 'none' : mb_substr((string) $a['last_error'], 0, 200)) . "\n";
}
echo 'timer last ran: ' . $ago((int) ($db->val('SELECT v FROM {meta} WHERE k = ?', ['clock.last_run']) ?? 0)) . "\n";
$e = $db->one("SELECT COUNT(*) AS n, SUM(cls = 'people') AS people, SUM(cls = 'feeds') AS feeds, SUM(cls = '') AS undecided, SUM(is_from_me) AS mine, SUM(gone) AS gone, MIN(at) AS oldest, MAX(at) AS newest FROM {emails}") ?? [];
echo 'emails held (header facts only): ' . (int) $e['n'] . ' | in Chats ' . (int) $e['people'] . ' | not from a person ' . (int) $e['feeds'] . ' | undecided ' . (int) $e['undecided'] . ' | sent by the owner ' . (int) $e['mine'] . ' | in trash or spam ' . (int) $e['gone']
    . ' | oldest ' . ((int) $e['oldest'] > 0 ? round(($now - (int) $e['oldest']) / 86400, 1) . ' days' : '-') . ' | newest ' . $ago((int) $e['newest']) . "\n";
$u = $db->one("SELECT COUNT(*) AS n, SUM(e.is_from_me) AS mine, SUM(e.from_key = '') AS nofrom, SUM(e.from_key = 'me') AS fromme,
        SUM(i.k IS NOT NULL) AS has_sender, SUM(f.skey IS NOT NULL) AS has_seed, SUM(e.gone) AS gone
    FROM {emails} e LEFT JOIN {items} i ON i.kind = 'sender' AND i.k = e.from_key AND i.deleted = 0 LEFT JOIN {sender_facts} f ON f.skey = e.from_key
    WHERE e.cls = ''") ?? [];
if ((int) ($u['n'] ?? 0) > 0) {
    echo 'undecided emails: ' . (int) $u['n'] . ' | marked sent by owner ' . (int) $u['mine'] . ' | no From ' . (int) $u['nofrom'] . ' | from one of the owner\'s addresses ' . (int) $u['fromme'] . ' | sender has a row ' . (int) $u['has_sender'] . ' | sender has device facts ' . (int) $u['has_seed'] . ' | in trash or spam ' . (int) $u['gone'] . "\n";
}
$kinds = [];
foreach ($db->all('SELECT kind, COUNT(*) AS n, SUM(deleted) AS gone, SUM(origin IS NULL) AS by_helper FROM {items} GROUP BY kind ORDER BY kind') as $r) {
    $kinds[] = $r['kind'] . ' ' . $r['n'] . ((int) $r['gone'] > 0 ? ' (' . $r['gone'] . ' removed)' : '') . ((int) $r['by_helper'] > 0 ? ' [' . $r['by_helper'] . ' written by the helper]' : '');
}
echo 'kept in step: ' . implode(' | ', $kinds) . "\n";
$s = $db->one("SELECT COUNT(*) AS n FROM {sender_facts}") ?? [];
echo 'senders with facts sent up by a device: ' . (int) $s['n'] . ' | sent-mail ids: ' . (int) $db->val('SELECT COUNT(*) FROM {my_ids}') . ' | devices: ' . (int) $db->val('SELECT COUNT(*) FROM {devices} WHERE revoked = 0') . ' | stream at ' . (int) $db->val("SELECT n FROM {counters} WHERE name = 'seq'") . "\n";
foreach ($db->all('SELECT at, level, msg FROM {log} ORDER BY id DESC LIMIT 8') as $l) {
    echo '  note ' . gmdate('H:i:s', (int) $l['at']) . ' ' . $l['level'] . ': ' . mb_substr((string) $l['msg'], 0, 160) . "\n";
}
