<?php
declare(strict_types=1);

/**
 * What the assistant marked "good to know", in counts by kind of mail:
 *   php server_know_counts.php
 * Reads only. Prints counts only: no names, no subjects, no mail.
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
$zone = $app->readings()->zone();
$now = $store->now();
$midnight = intdiv($now + $zone * 60, 86400) * 86400 - $zone * 60;
foreach (['today' => $midnight, 'since yesterday morning' => $midnight - 86400] as $name => $since) {
    $rows = $db->all("SELECT e.cls, COALESCE(e.cat, '') AS cat, e.pile, e.inbox, r.know, r.focus, e.message_id FROM {readings} r JOIN {emails} e ON e.id = r.email_id WHERE e.is_from_me = 0 AND e.gone = 0 AND e.at >= ?", [$since]);
    $kinds = [];
    $know = 0;
    $shown = 0;
    foreach ($rows as $r) {
        $kind = (string) $r['cls'] === 'people' ? 'from a person' : ('not a person, ' . ((string) $r['cat'] === '' ? 'no tag' : 'tag ' . (string) $r['cat']) . ', ' . ((string) $r['pile'] === '' ? 'no pile' : (string) $r['pile']));
        $kinds[$kind] ??= ['read' => 0, 'know' => 0];
        $kinds[$kind]['read']++;
        if ((int) $r['know'] === 1) {
            $kinds[$kind]['know']++;
            $know++;
            $shown += (int) ((int) $r['inbox'] === 1 && (int) $r['focus'] === 0 && (string) $r['pile'] !== 'noise' && $store->item('done', (string) $r['message_id']) === null);
        }
    }
    ksort($kinds);
    echo "$name: read " . count($rows) . " | good to know $know | of those, would show on Today $shown\n";
    foreach ($kinds as $kind => $c) {
        echo "    $kind: read {$c['read']}, good to know {$c['know']}\n";
    }
}
echo 'in Focus now: ' . count($app->readings()->focusNow()) . "\n";
