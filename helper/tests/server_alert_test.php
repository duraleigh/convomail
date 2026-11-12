<?php
declare(strict_types=1);

/**
 * Sends one test alert to each phone and says what Google's alert service
 * answered:  php server_alert_test.php
 *
 * Prints answer codes and Google's own short reason. No keys, no phone
 * addresses, no mail.
 */

use Precis\App;
use Precis\CurlHttp;
use Precis\Session;
use Precis\Store;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

/** Passes every request through, and keeps the last answer from the alert service. */
final class Listening implements \Precis\Http
{
    /** @var list<array{status: int, reason: string}> */
    public array $answers = [];

    public function __construct(private readonly \Precis\Http $inner)
    {
    }

    public function request(string $method, string $url, array $headers = [], ?string $body = null): array
    {
        $r = $this->inner->request($method, $url, $headers, $body);
        if (str_contains($url, 'fcm.googleapis.com') || str_contains($url, 'oauth2.googleapis.com/token')) {
            $j = json_decode($r['body'], true);
            $reason = is_array($j) ? (string) ($j['error']['status'] ?? (is_string($j['error'] ?? null) ? $j['error'] : '')) . ' ' . mb_substr((string) ($j['error']['message'] ?? ($j['error_description'] ?? '')), 0, 200) : '';
            $this->answers[] = ['where' => str_contains($url, 'fcm.') ? 'alert service' : 'sign-in for the alert service', 'status' => $r['status'], 'reason' => trim($reason)];
        }
        return $r;
    }

    public function getMany(array $urls, array $headers = []): array
    {
        return $this->inner->getMany($urls, $headers);
    }
}

$http = new Listening(new CurlHttp());
$app = new App(PRECIS_HOME, $http, new Session());
$db = $app->store()->db;
$phones = $db->all("SELECT id, kind, ring, LENGTH(push_token) AS len, last_seen FROM {devices} WHERE revoked = 0 AND push_token IS NOT NULL AND push_token <> ''");
echo 'phones with an address for alerts: ' . count($phones) . "\n";
foreach ($phones as $p) {
    echo '  device ' . $p['id'] . ' (' . $p['kind'] . '): may ring ' . ((int) $p['ring'] === 1 ? 'yes' : 'no') . ', address ' . $p['len'] . ' characters long, last seen ' . (time() - (int) $p['last_seen']) . " s ago\n";
}
echo 'project the helper sends through: ' . ($app->push()->project() !== '' ? 'set' : 'not set') . ' | same project in the app settings file: ' . (($app->push()->app()['projectId'] ?? '') === $app->push()->project() ? 'yes' : 'NO') . "\n";
// Start from a fresh sign-in to the alert service, so its answer is seen too.
$app->store()->set('push.access_exp', '0');
$sent = $app->alerts()->test();
echo "test alerts Google accepted: $sent\n";
foreach ($http->answers as $a) {
    echo '  ' . $a['where'] . ': answer ' . $a['status'] . ($a['reason'] === '' ? '' : ' (' . $a['reason'] . ')') . "\n";
}
