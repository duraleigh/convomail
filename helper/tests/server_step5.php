<?php
declare(strict_types=1);

/**
 * How step 5 stands on the live helper:  php server_step5.php
 *
 * Says yes or no and prints Google's answer codes. Prints no addresses, no
 * names, no mail, no keys. Reads; changes nothing. (Asking Google "is this
 * allowed" reads one calendar name and one contact, which are thrown away.)
 */

use Precis\App;
use Precis\CurlHttp;
use Precis\Google;
use Precis\Session;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

$http = new CurlHttp();
$app = new App(PRECIS_HOME, $http, new Session());
$yes = static fn (bool $b): string => $b ? 'yes' : 'no';
$store = $app->store();
$db = $store->db;
echo 'storage version: ' . $db->val("SELECT v FROM {meta} WHERE k = 'schema'") . "\n";

$account = $app->reader()->accounts()[0] ?? null;
if ($account === null) {
    echo "no mailbox connected\n";
    exit(0);
}
$google = $app->google();
$id = (int) $account['id'];
echo 'Google allows: mail in full ' . $yes($google->grants($id, Google::MAIL)) . ' | calendar ' . $yes($google->grants($id, Google::CALENDAR)) . ' | contacts ' . $yes($google->grants($id, Google::CONTACTS)) . "\n";
try {
    $pass = $google->devicePass($id);
    echo 'a pass for devices: yes, ' . ($pass['expires'] - time()) . " s left on it\n";
    $h = ['Authorization' => 'Bearer ' . $pass['access']];
    $cal = $http->request('GET', 'https://www.googleapis.com/calendar/v3/users/me/calendarList?maxResults=1&fields=items(id)', $h);
    echo 'calendar, asked with that pass: answer ' . $cal['status'] . (str_contains($cal['body'], 'has not been used') || str_contains($cal['body'], 'is disabled') ? ' (the Calendar service is not switched on in the Google project)' : '') . "\n";
    $who = $http->request('GET', 'https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=' . rawurlencode($pass['access']));
    $scopes = explode(' ', (string) (json_decode($who['body'], true)['scope'] ?? ''));
    echo 'what the pass itself carries: mail in full ' . $yes(in_array(Google::MAIL, $scopes, true)) . ' | calendar ' . $yes(in_array(Google::CALENDAR, $scopes, true)) . ' | contacts ' . $yes(in_array(Google::CONTACTS, $scopes, true)) . "\n";
} catch (Throwable $e) {
    echo 'a pass for devices: no (' . get_class($e) . ': ' . mb_substr($e->getMessage(), 0, 160) . ")\n";
}

$push = $app->push();
echo 'alerts: service account file ' . $yes($push->hasKey()) . ' | app settings file ' . $yes($push->hasApp()) . "\n";
$d = $db->one("SELECT COUNT(*) AS n, SUM(kind = 'android') AS phones, SUM(push_token IS NOT NULL) AS reachable, SUM(ring = 0) AS silent FROM {devices} WHERE revoked = 0") ?? [];
echo 'devices: ' . (int) ($d['n'] ?? 0) . ' | phones ' . (int) ($d['phones'] ?? 0) . ' | phones that can be alerted ' . (int) ($d['reachable'] ?? 0) . ' | set not to ring ' . (int) ($d['silent'] ?? 0) . "\n";
$sending = $app->sending();
echo 'sending addresses kept: ' . $sending->count() . ' | with a password for a server of their own ' . $sending->withPassword() . "\n";
echo 'alerts sent so far: ' . (int) $db->val('SELECT COUNT(*) FROM {alerts}') . ' | quiet hours on: ' . $yes($app->alerts()->quiet()) . "\n";
