<?php
declare(strict_types=1);

namespace Precis;

/**
 * Sends alerts to phones through Google's alert service for apps
 * (Firebase Cloud Messaging). It is the only way Android lets an app be
 * told something while it is closed.
 *
 * The owner's Firebase project gives the helper a "service account" file.
 * The helper keeps it sealed and uses it to prove to Google who is sending.
 * What is sent is small: who wrote and what they ask, never an email's text.
 */
final class Push
{
    private const TOKEN = 'https://oauth2.googleapis.com/token';
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function __construct(private readonly Store $store, private readonly Http $http)
    {
    }

    public function hasKey(): bool
    {
        return $this->store->get('push.account') !== null;
    }

    public function project(): string
    {
        return (string) $this->store->get('push.project', '');
    }

    /**
     * Keeps a service-account file, sealed, after checking it is one and
     * that Google accepts it. Returns null when kept, else what is wrong.
     */
    public function setKey(string $json): ?string
    {
        $a = json_decode(trim($json), true);
        if (!is_array($a) || ($a['type'] ?? '') !== 'service_account' || !is_string($a['client_email'] ?? null) || !is_string($a['private_key'] ?? null) || !is_string($a['project_id'] ?? null)) {
            return 'That is not a service account file from Firebase. It is the file that downloads when you press "Generate new private key".';
        }
        if (@openssl_pkey_get_private($a['private_key']) === false) {
            return 'The private key inside that file cannot be read. Download a new one.';
        }
        $keep = ['client_email' => $a['client_email'], 'private_key' => $a['private_key'], 'project_id' => $a['project_id']];
        try {
            $this->fetchAccess($keep);
        } catch (\Throwable $e) {
            return 'Google did not accept that file: ' . mb_substr($e->getMessage(), 0, 160);
        }
        $this->store->setSecret('push.account', Store::json($keep));
        $this->store->set('push.project', $a['project_id']);
        $this->store->set('push.since', (string) $this->store->now());
        $this->store->log('info', 'Alerts to phones were set up.');
        return null;
    }

    /** The Android app's own name inside the owner's Firebase project. */
    public const APP = 'com.clayaiken.precis';

    /**
     * Keeps what the phone app needs to sign up for alerts, read from the
     * app settings file Firebase gives for the Android app
     * (google-services.json). Returns null when kept, else what is wrong.
     */
    public function setApp(string $json): ?string
    {
        $a = json_decode(trim($json), true);
        $info = is_array($a) ? ($a['project_info'] ?? null) : null;
        if (!is_array($info) || !is_array($a['client'] ?? null)) {
            return 'That is not the app settings file from Firebase. It is the file named google-services.json.';
        }
        foreach ($a['client'] as $c) {
            $package = (string) ($c['client_info']['android_client_info']['package_name'] ?? '');
            if ($package !== self::APP) {
                continue;
            }
            $app = (string) ($c['client_info']['mobilesdk_app_id'] ?? '');
            $key = (string) ($c['api_key'][0]['current_key'] ?? '');
            $sender = (string) ($info['project_number'] ?? '');
            $project = (string) ($info['project_id'] ?? '');
            if ($app === '' || $key === '' || $sender === '' || $project === '') {
                return 'That file is missing parts. Download it again from Firebase.';
            }
            if ($this->hasKey() && $this->project() !== $project) {
                return 'That file is from a different Firebase project than the service account file.';
            }
            $this->store->setSecret('push.app', Store::json(['apiKey' => $key, 'appId' => $app, 'senderId' => $sender, 'projectId' => $project]));
            $this->store->log('info', 'The phone app’s alert settings were saved.');
            return null;
        }
        return 'That file is for a different app. In Firebase, the Android app’s package name must be ' . self::APP . '.';
    }

    public function hasApp(): bool
    {
        return $this->store->get('push.app') !== null;
    }

    /** @return array{apiKey: string, appId: string, senderId: string, projectId: string}|null for a joined phone only */
    public function app(): ?array
    {
        $s = $this->store->getSecret('push.app');
        $a = $s === null ? null : json_decode($s, true);
        return is_array($a) ? $a : null;
    }

    public function forgetKey(): void
    {
        foreach (['push.account', 'push.project', 'push.access', 'push.access_exp', 'push.since', 'push.app'] as $k) {
            $this->store->set($k, null);
        }
        $this->store->log('info', 'Alerts to phones were turned off.');
    }

    /** @return array{client_email: string, private_key: string, project_id: string}|null */
    private function account(): ?array
    {
        $s = $this->store->getSecret('push.account');
        $a = $s === null ? null : json_decode($s, true);
        return is_array($a) ? $a : null;
    }

    /** A short-lived pass to Google's alert service, renewed when it is about to run out. */
    private function access(): string
    {
        $exp = (int) $this->store->get('push.access_exp', '0');
        $have = $this->store->getSecret('push.access');
        if ($have !== null && $exp - 120 > $this->store->now()) {
            return $have;
        }
        $a = $this->account();
        if ($a === null) {
            throw new \RuntimeException('Alerts are not set up.');
        }
        $t = $this->fetchAccess($a);
        $this->store->setSecret('push.access', $t['token']);
        $this->store->set('push.access_exp', (string) $t['exp']);
        return $t['token'];
    }

    /**
     * @param array{client_email: string, private_key: string, project_id: string} $a
     * @return array{token: string, exp: int}
     */
    private function fetchAccess(array $a): array
    {
        $now = $this->store->now();
        $b64 = static fn (string $s): string => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
        $head = $b64((string) json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $claims = $b64((string) json_encode(['iss' => $a['client_email'], 'scope' => self::SCOPE, 'aud' => self::TOKEN, 'iat' => $now, 'exp' => $now + 3000]));
        $signature = '';
        if (!openssl_sign("$head.$claims", $signature, $a['private_key'], OPENSSL_ALGO_SHA256)) {
            throw new \RuntimeException('The key could not sign.');
        }
        $r = $this->http->request('POST', self::TOKEN, ['Content-Type' => 'application/x-www-form-urlencoded'], http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => "$head.$claims." . $b64($signature),
        ]));
        $j = Store::decode($r['body']);
        if ($r['status'] !== 200 || !is_string($j['access_token'] ?? null)) {
            throw new \RuntimeException('Google refused (' . $r['status'] . (isset($j['error']) ? ' ' . (is_string($j['error']) ? $j['error'] : 'error') : '') . ').');
        }
        return ['token' => $j['access_token'], 'exp' => $now + (int) ($j['expires_in'] ?? 3000)];
    }

    /**
     * Sends one small message to one phone. Returns 'sent', 'gone' (the
     * phone no longer has the app, or its address for alerts changed), or
     * 'failed'.
     *
     * @param array<string, string|int|bool|null> $data
     */
    public function send(string $deviceToken, array $data): string
    {
        $project = $this->project();
        if ($project === '' || $deviceToken === '') {
            return 'failed';
        }
        $strings = [];
        foreach ($data as $k => $v) {
            if ($v !== null) {
                $strings[$k] = is_bool($v) ? ($v ? '1' : '0') : (string) $v;
            }
        }
        try {
            $r = $this->http->request(
                'POST',
                'https://fcm.googleapis.com/v1/projects/' . rawurlencode($project) . '/messages:send',
                ['Authorization' => 'Bearer ' . $this->access(), 'Content-Type' => 'application/json'],
                // Data only: the app itself draws the alert, so it can carry
                // Done and Later, and be taken away again.
                Store::json(['message' => ['token' => $deviceToken, 'data' => $strings, 'android' => ['priority' => 'HIGH']]]),
            );
        } catch (\Throwable) {
            return 'failed';
        }
        if ($r['status'] === 200) {
            return 'sent';
        }
        $j = Store::decode($r['body']);
        $status = (string) ($j['error']['status'] ?? '');
        $code = (string) ($j['error']['details'][0]['errorCode'] ?? '');
        if ($r['status'] === 404 || $status === 'NOT_FOUND' || $code === 'UNREGISTERED') {
            return 'gone';
        }
        if ($r['status'] === 401) {
            // The pass ran out early: the next send fetches a new one.
            $this->store->set('push.access_exp', '0');
        }
        return 'failed';
    }
}
