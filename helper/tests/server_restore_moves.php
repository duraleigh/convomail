<?php
declare(strict_types=1);

/**
 * Puts back the owner's moves by hand that a newly joined device wrongly
 * replaced with its own guess (fixed in 0.6.1). The senders are given only
 * as fingerprints (sha256 of the sender's key), worked out on the owner's
 * PC from its safety copy, so no name or address is typed or printed.
 *
 *   php server_restore_moves.php HASH...        says what it would do
 *   php server_restore_moves.php go HASH...     does it
 *
 * Each one is marked "moved by hand" again in the place it is in (the place
 * the owner put it), and the tag the device guessed for it is taken off
 * (it had none). Every device hears of it like any other change.
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
$store = $app->store();
$db = $store->db;
$args = array_slice($argv, 1);
$go = ($args[0] ?? '') === 'go';
$want = array_flip($go ? array_slice($args, 1) : $args);
$found = 0;
$fixed = 0;
foreach ($db->all("SELECT k, data FROM {items} WHERE kind = 'sender' AND deleted = 0") as $row) {
    if (!isset($want[hash('sha256', (string) $row['k'])])) {
        continue;
    }
    $found++;
    $data = json_decode((string) $row['data'], true) ?: [];
    $was = ($data['cls'] ?? '?') . ', marked ' . ($data['src'] ?? '?') . ', tag ' . (($data['cat'] ?? null) === null ? 'none' : 'one');
    if (($data['src'] ?? '') === 'override') {
        echo "sender $found: already moved by hand ($was)\n";
        continue;
    }
    if (($data['cls'] ?? '') !== 'feeds') {
        echo "sender $found: not where the owner put it ($was); left alone\n";
        continue;
    }
    if ($go) {
        $fixed += (int) $store->put('sender', (string) $row['k'], ['src' => 'override', 'cat' => null, 'reasons' => 'Moved by you'] + $data);
        $app->sorter()->reset();
        $app->sorter()->resort((string) $row['k']);
        $now = $store->item('sender', (string) $row['k']) ?? [];
        echo "sender $found: was $was -> now " . ($now['cls'] ?? '?') . ', marked ' . ($now['src'] ?? '?') . ', tag ' . (($now['cat'] ?? null) === null ? 'none' : 'one') . "\n";
    } else {
        echo "sender $found: $was -> would be marked moved by hand, tag taken off\n";
    }
}
echo "found $found of " . count($want) . ($go ? " | put back: $fixed" : ' | nothing changed (say "go" to do it)') . "\n";
echo 'senders moved by hand now: ' . count(array_filter($db->all("SELECT data FROM {items} WHERE kind = 'sender' AND deleted = 0"), static fn (array $r): bool => ((json_decode((string) $r['data'], true) ?: [])['src'] ?? '') === 'override')) . "\n";
