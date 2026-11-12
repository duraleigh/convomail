<?php
declare(strict_types=1);

/**
 * After the assistant is taught something new: has it read again the mail
 * that came since yesterday morning, and says what the meter stood at, so
 * the cost of the new lesson can be measured on real mail.
 *
 *   php server_relearn.php        counts and the meter only
 *   php server_relearn.php go     also puts that mail back in line
 *
 * Only mail that came in is read again, not mail the owner sent. Prints
 * counts and amounts only: no names, no subjects, no mail.
 */

use Precis\App;
use Precis\CurlHttp;
use Precis\Readings;
use Precis\Schema;
use Precis\Session;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

$app = new App(PRECIS_HOME, new CurlHttp(), new Session());
$store = $app->store();
$db = $store->db;
$readings = $app->readings();
$zone = $readings->zone();
$now = $store->now();
$midnight = intdiv($now + $zone * 60, 86400) * 86400 - $zone * 60;
$since = $midnight - 86400;

echo 'program ' . \Precis\VERSION . ' | storage version ' . (int) $db->val("SELECT v FROM {meta} WHERE k = 'schema'") . ' of ' . Schema::VERSION . "\n";
$mine = "inbox = 1 AND is_from_me = 0 AND gone = 0 AND at >= ?";
echo 'came in since yesterday morning: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} WHERE $mine", [$since])
    . ' | read by the assistant: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} WHERE $mine AND read_state = ?", [$since, Readings::READ])
    . ' | of those, today: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} WHERE $mine AND read_state = ?", [$midnight, Readings::READ]) . "\n";
echo 'readings marked good to know: ' . (int) $db->val('SELECT COUNT(*) FROM {readings} WHERE know = 1')
    . ' | with a name for what they are about: ' . (int) $db->val("SELECT COUNT(*) FROM {readings} WHERE thing <> ''")
    . ' | answers of the owner that settled something: ' . (int) $db->val('SELECT COUNT(*) FROM {readings} WHERE settles = 1') . "\n";

if (($argv[1] ?? '') === 'go') {
    $db->run("UPDATE {emails} SET read_state = ?, read_tries = 0, read_after = 0 WHERE $mine AND read_state = ?", [Readings::NEW, $since, Readings::READ]);
    echo 'put back in line to be read again: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} WHERE $mine AND read_state = ?", [$since, Readings::NEW]) . "\n";
}
echo 'waiting to be read now: ' . (int) $db->val('SELECT COUNT(*) FROM {emails} WHERE (inbox = 1 OR is_from_me = 1) AND gone = 0 AND read_state IN (?, ?, ?)', [Readings::NEW, Readings::WAITING, Readings::RETRY]) . "\n";

$row = $db->one("SELECT COALESCE(SUM(calls), 0) AS calls, COALESCE(SUM(tin), 0) AS tin, COALESCE(SUM(tout), 0) AS tout, COALESCE(SUM(micro), 0) AS micro FROM {spend} WHERE purpose = 'mail'");
echo 'the meter, reading mail, all time: ' . (int) $row['calls'] . ' readings | ' . (int) $row['tin'] . ' in | ' . (int) $row['tout'] . ' out | $' . number_format(((int) $row['micro']) / 1_000_000, 4) . "\n";
$day = $db->one("SELECT COALESCE(SUM(calls), 0) AS calls, COALESCE(SUM(micro), 0) AS micro FROM {spend} WHERE purpose = 'day'");
echo 'the meter, The Lede, all time: ' . (int) $day['calls'] . ' writings | $' . number_format(((int) $day['micro']) / 1_000_000, 4) . "\n";
echo 'this month so far: $' . number_format($readings->monthSpend() / 1_000_000, 4) . ' of a ceiling of $' . number_format($readings->ceiling() / 1_000_000, 2) . "\n";
