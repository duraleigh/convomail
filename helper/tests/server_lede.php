<?php
declare(strict_types=1);

/**
 * The Lede on the live helper, in counts and times only: when it was last
 * written, whether it is empty, and what it would have to speak of now.
 * Prints no names, no subjects and none of the sentence's words.
 *
 *   php server_lede.php
 */

use Precis\App;
use Precis\CurlHttp;
use Precis\Day;
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
$now = $store->now();
$zone = $readings->zone();
$local = static fn (int $at): string => $at <= 0 ? 'never' : gmdate('D M j H:i', $at + $zone * 60);
$midnight = intdiv($now + $zone * 60, 86400) * 86400 - $zone * 60;

echo 'program ' . \Precis\VERSION . ' | now ' . $local($now) . ' | the assistant is ready to read: ' . ($readings->ready() ? 'yes' : 'no') . "\n";
$item = $store->item('day', 'today');
echo 'the sentence kept now: ' . ($item === null ? 'none' : (mb_strlen((string) ($item['text'] ?? '')) . ' characters, written ' . $local((int) ($item['at'] ?? 0)))) . "\n";
echo 'last time the helper settled the sentence: ' . $local((int) $store->get('day.at', '0')) . ' | written by the assistant today: ' . $readings->writtenToday('day') . " times\n";

$day = new Day($store, $readings);
$lines = $day->lines();
echo 'what it would speak of now: needs you ' . count($lines['needs']) . ' | good to know that came today ' . count($lines['feed']) . ' | same as when it was last settled: ' . ($lines['key'] === $store->get('day.key') ? 'yes' : 'no') . "\n";

// Why "good to know today" is what it is.
$today = 'e.is_from_me = 0 AND e.inbox = 1 AND e.gone = 0 AND e.at >= ?';
echo 'came into the inbox today: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} e WHERE $today", [$midnight])
    . ' | read by the assistant: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} e JOIN {readings} r ON r.email_id = e.id WHERE $today", [$midnight])
    . ' | marked good to know: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} e JOIN {readings} r ON r.email_id = e.id WHERE $today AND r.know = 1", [$midnight])
    . ' | marked as needing you: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} e JOIN {readings} r ON r.email_id = e.id WHERE $today AND r.focus = 1", [$midnight]) . "\n";
$yesterday = $midnight - 86400;
echo 'yesterday, for comparison: came in ' . (int) $db->val("SELECT COUNT(*) FROM {emails} e WHERE e.is_from_me = 0 AND e.inbox = 1 AND e.gone = 0 AND e.at >= ? AND e.at < ?", [$yesterday, $midnight])
    . ' | marked good to know: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} e JOIN {readings} r ON r.email_id = e.id WHERE e.is_from_me = 0 AND e.inbox = 1 AND e.gone = 0 AND e.at >= ? AND e.at < ? AND r.know = 1", [$yesterday, $midnight])
    . ' | marked as needing you: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} e JOIN {readings} r ON r.email_id = e.id WHERE e.is_from_me = 0 AND e.inbox = 1 AND e.gone = 0 AND e.at >= ? AND e.at < ? AND r.focus = 1", [$yesterday, $midnight]) . "\n";
// Readings marked as needing you at all, and what keeps each off the page.
$open = (int) $db->val('SELECT COUNT(*) FROM {readings} r JOIN {emails} e ON e.id = r.email_id WHERE r.focus = 1 AND e.is_from_me = 0 AND e.gone = 0');
$answered = (int) $db->val('SELECT COUNT(*) FROM {readings} r JOIN {emails} e ON e.id = r.email_id WHERE r.focus = 1 AND r.answered = 1 AND e.is_from_me = 0 AND e.gone = 0');
$notInbox = (int) $db->val('SELECT COUNT(*) FROM {readings} r JOIN {emails} e ON e.id = r.email_id WHERE r.focus = 1 AND r.answered = 0 AND e.inbox = 0 AND e.is_from_me = 0 AND e.gone = 0');
echo 'readings that said "needs you", all time: ' . $open . ' | since answered: ' . $answered . ' | no longer in the inbox: ' . $notInbox . ' | dismissed, done, put off or turned down by you: ' . max(0, $open - $answered - $notInbox - count($lines['needs'])) . "\n";
foreach ($db->all("SELECT day, calls FROM {spend} WHERE purpose = 'day' ORDER BY day DESC LIMIT 4") as $r) {
    echo '  The Lede written on ' . $r['day'] . ': ' . (int) $r['calls'] . " times\n";
}
