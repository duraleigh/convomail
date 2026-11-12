<?php
declare(strict_types=1);

/**
 * For senders given only as fingerprints (sha256 of the sender's key, so no
 * name or address is typed or printed):  php server_whomoved.php HASH...
 *
 * Says, for each, how the helper holds it now and which device last wrote
 * it and when. Reads only. Prints no names, no addresses.
 */

use Precis\App;
use Precis\CurlHttp;
use Precis\Session;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

$app = new App(PRECIS_HOME, new CurlHttp(), new Session());
$db = $app->store()->db;
$want = array_flip(array_slice($argv, 1));
$devices = [];
foreach ($db->all('SELECT id, kind, created, revoked FROM {devices}') as $d) {
    $devices[(int) $d['id']] = (string) $d['kind'] . ((int) $d['revoked'] === 1 ? ' (signed out)' : '') . ', joined ' . gmdate('m-d H:i', (int) $d['created']) . ' UTC';
}
echo 'devices: ' . json_encode($devices) . "\n";
$n = 0;
foreach ($db->all("SELECT k, data, deleted, seq, origin, at FROM {items} WHERE kind = 'sender'") as $row) {
    $h = hash('sha256', (string) $row['k']);
    if (!isset($want[$h])) {
        continue;
    }
    $n++;
    $data = json_decode((string) $row['data'], true) ?: [];
    echo 'sender ' . $n . ': ' . ((int) $row['deleted'] === 1 ? 'removed' : 'place ' . ($data['cls'] ?? '?') . ', marked ' . ($data['src'] ?? '?') . ', pile ' . json_encode($data['pile'] ?? null))
        . ' | last written by ' . ($row['origin'] === null ? 'the helper itself' : 'device ' . (int) $row['origin'] . ' (' . ($devices[(int) $row['origin']] ?? 'unknown') . ')')
        . ' at ' . gmdate('m-d H:i', (int) $row['at']) . ' UTC, change number ' . (int) $row['seq'] . "\n";
}
echo 'found ' . $n . ' of ' . count($want) . "\n";
echo 'all senders the helper holds, by mark: ' . json_encode(array_count_values(array_map(static fn (array $r): string => (string) ((json_decode((string) $r['data'], true) ?: [])['src'] ?? '?'), $db->all("SELECT data FROM {items} WHERE kind = 'sender' AND deleted = 0")))) . "\n";
// Every time a device sent up all it knew about senders (the first sending-up), from the helper's own notes.
foreach ($db->all("SELECT at, msg FROM {log} WHERE msg LIKE '%joined%' OR msg LIKE '%sent up%' OR msg LIKE '%signed out%' ORDER BY id DESC LIMIT 8") as $l) {
    echo '  note ' . gmdate('m-d H:i', (int) $l['at']) . ' UTC: ' . (string) $l['msg'] . "\n";
}
