<?php
declare(strict_types=1);

/**
 * Travel and bookings on the live helper, in counts and amounts only.
 *
 *   php server_trips.php        how many recent emails look like travel or a booking, what is kept, the meter
 *   php server_trips.php go     also puts those emails back in line, to be read again with the new lesson
 *
 * Only mail that came into the inbox is read. Prints no names, no subjects,
 * no places, no numbers from any email.
 */

use Precis\App;
use Precis\CurlHttp;
use Precis\Readings;
use Precis\Schema;
use Precis\Session;
use Precis\Trips;

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

echo 'program ' . \Precis\VERSION . ' | storage version ' . (int) $db->val("SELECT v FROM {meta} WHERE k = 'schema'") . ' of ' . Schema::VERSION . "\n";

// Mail in the inbox whose subject reads like travel or a booking. The
// first reading decides; this only chooses what is worth reading again.
$words = 'flight|itinerary|e-?ticket|boarding|check[- ]?in|your trip|trip confirmation|reservation|booking|hotel|your stay|rental|amtrak|train|delayed|cancel|appointment|car service|chauffeur';
$mine = 'inbox = 1 AND is_from_me = 0 AND gone = 0 AND at > ?';
$since = $now - Readings::DAYS * 86400;
$looks = [];
foreach ($db->all("SELECT id, subject, read_state, cat FROM {emails} WHERE $mine", [$since]) as $e) {
    if (preg_match('~' . $words . '~i', (string) $e['subject']) === 1 || strcasecmp((string) ($e['cat'] ?? ''), 'Travel') === 0) {
        $looks[] = $e;
    }
}
$read = count(array_filter($looks, static fn (array $e): bool => (int) $e['read_state'] === Readings::READ));
echo 'in the inbox, last ' . Readings::DAYS . ' days: ' . (int) $db->val("SELECT COUNT(*) FROM {emails} WHERE $mine", [$since])
    . ' | that read like travel or a booking by their subject or tag: ' . count($looks) . ' | of those, already read once: ' . $read . "\n";

if (($argv[1] ?? '') === 'go') {
    $n = 0;
    foreach ($looks as $e) {
        if ((int) $e['read_state'] === Readings::READ) {
            $n += $db->run('UPDATE {emails} SET read_state = ?, read_tries = 0, read_after = 0 WHERE id = ?', [Readings::NEW, (int) $e['id']])->rowCount();
        }
    }
    echo 'put back in line to be read again: ' . $n . "\n";
}

echo 'first readings that said travel: ' . (int) $db->val("SELECT COUNT(*) FROM {readings} WHERE kind = 'travel'")
    . ' | that said booking: ' . (int) $db->val("SELECT COUNT(*) FROM {readings} WHERE kind = 'booking'")
    . ' | waiting for the fuller reading: ' . (int) $db->val('SELECT COUNT(*) FROM {readings} WHERE detail = ?', [Trips::WANTED])
    . ' | done: ' . (int) $db->val('SELECT COUNT(*) FROM {readings} WHERE detail = ?', [Trips::DONE])
    . ' | given up on: ' . (int) $db->val('SELECT COUNT(*) FROM {readings} WHERE detail = ?', [Trips::GAVE_UP]) . "\n";

$legs = $store->itemsOf('leg');
$bookings = $store->itemsOf('booking');
$ahead = count(array_filter($legs, static fn (array $l): bool => (int) ($l['arr_at'] ?? $l['dep_at'] ?? 0) > $now));
$states = array_count_values(array_map(static fn (array $l): string => (string) ($l['state'] ?? ''), $legs));
ksort($states);
$types = array_count_values(array_map(static fn (array $b): string => (string) ($b['type'] ?? ''), $bookings));
ksort($types);
echo 'legs kept: ' . count($legs) . ' | still ahead: ' . $ahead . ' | by where they stand: ' . ($states === [] ? 'none' : implode(', ', array_map(static fn (string $k, int $v): string => "$k $v", array_keys($states), $states)))
    . ' | with something missing: ' . count(array_filter($legs, static fn (array $l): bool => ($l['missing'] ?? []) !== [])) . "\n";
echo 'bookings kept: ' . count($bookings) . ' | by kind: ' . ($types === [] ? 'none' : implode(', ', array_map(static fn (string $k, int $v): string => "$k $v", array_keys($types), $types))) . "\n";
echo 'emails carrying an email written for the owner to look over: ' . (int) $db->val("SELECT COUNT(*) FROM {readings} WHERE draft IS NOT NULL AND draft <> ''") . "\n";
echo 'waiting for a first reading now: ' . (int) $db->val('SELECT COUNT(*) FROM {emails} WHERE (inbox = 1 OR is_from_me = 1) AND gone = 0 AND read_state IN (?, ?, ?)', [Readings::NEW, Readings::WAITING, Readings::RETRY]) . "\n";

foreach (['mail' => 'first readings', 'detail' => 'fuller readings of travel and bookings', 'day' => 'The Lede'] as $purpose => $name) {
    $row = $db->one('SELECT COALESCE(SUM(calls), 0) AS calls, COALESCE(SUM(tin), 0) AS tin, COALESCE(SUM(tout), 0) AS tout, COALESCE(SUM(micro), 0) AS micro FROM {spend} WHERE purpose = ?', [$purpose]);
    echo 'the meter, ' . $name . ', all time: ' . (int) $row['calls'] . ' | ' . (int) $row['tin'] . ' in | ' . (int) $row['tout'] . ' out | $' . number_format(((int) $row['micro']) / 1_000_000, 4) . "\n";
}
echo 'this month so far: $' . number_format($readings->monthSpend() / 1_000_000, 4) . ' of a ceiling of $' . number_format($readings->ceiling() / 1_000_000, 2) . "\n";
