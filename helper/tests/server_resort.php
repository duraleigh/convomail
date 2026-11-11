<?php
declare(strict_types=1);

/**
 * Sorts again every sender the live helper holds mail from, and says how
 * much changed, in counts only:  php server_resort.php
 *
 * For when something changed underneath the helper's decisions (a device's
 * first sending-up arriving after the helper had already read some mail).
 * Safe to run more than once: the second run changes nothing.
 */

use Precis\Crypto;
use Precis\Db;
use Precis\Sorter;
use Precis\Store;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

/** @var array<string, mixed> $config */
$config = require PRECIS_HOME . '/config.php';
$db = Db::connect($config);
$store = new Store($db, Crypto::fromFile(PRECIS_HOME . '/master.key'));
$sorter = new Sorter($store);

$before = [];
foreach ($db->all("SELECT id, cls, cat FROM {emails} WHERE is_from_me = 0") as $e) {
    $before[(int) $e['id']] = $e['cls'] . '|' . ($e['cat'] ?? '');
}
$db->run("UPDATE {emails} SET cls = 'people' WHERE is_from_me = 1 AND cls = ''");
$keys = $sorter->sendersWithEmails();
$moved = 0;
foreach ($keys as $key) {
    $moved += (int) $sorter->resort($key);
}
$place = 0;
$tag = 0;
foreach ($db->all("SELECT id, cls, cat FROM {emails} WHERE is_from_me = 0") as $e) {
    $was = $before[(int) $e['id']] ?? '|';
    $now = $e['cls'] . '|' . ($e['cat'] ?? '');
    if ($was === $now) {
        continue;
    }
    if (explode('|', $was)[0] !== $e['cls']) {
        $place++;
    } else {
        $tag++;
    }
}
echo 'senders sorted again: ' . count($keys) . ' | senders whose place changed: ' . $moved . ' | emails whose place changed: ' . $place . ' | emails whose tag only changed: ' . $tag . ' | of ' . count($before) . " emails\n";
