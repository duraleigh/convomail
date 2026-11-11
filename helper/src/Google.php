<?php
declare(strict_types=1);

namespace Precis;

use RuntimeException;

/**
 * The helper's own sign-in to the owner's Gmail, and the few Gmail calls it
 * makes. It asks Google for two things only: reading mail, and sending mail
 * (used from a later step, and only on the owner's tap).
 *
 * The sign-in client (id and secret) comes from the owner's own Google
 * project. The secret and the sign-in itself are kept sealed.
 */
final class Google
{
    public const SCOPES = ['https://www.googleapis.com/auth/gmail.readonly', 'https://www.googleapis.com/auth/gmail.send'];

    private const AUTH = 'https://accounts.google.com/o/oauth2/v2/auth';
    private const TOKEN = 'https://oauth2.googleapis.com/token';
    private const REVOKE = 'https://oauth2.googleapis.com/revoke';
    private const GMAIL = 'https://gmail.googleapis.com/gmail/v1/users/me/';

    /** Headers asked for with each email when it is filed: who, what, when, and the signs of bulk mail. */
    public const HEADERS = ['From', 'To', 'Cc', 'Bcc', 'Subject', 'Date', 'Message-ID', 'In-Reply-To', 'List-Unsubscribe', 'List-Id', 'List-Post', 'Feedback-ID', 'Precedence', 'Auto-Submitted'];

    public function __construct(private readonly Store $store, private readonly Http $http)
    {
    }

    // ---- the sign-in client -------------------------------------------------------------

    public function hasClient(): bool
    {
        return ($this->store->get('google.client_id') ?? '') !== '' && $this->store->get('google.client_secret') !== null;
    }

    public function setClient(string $id, string $secret): void
    {
        $this->store->set('google.client_id', trim($id));
        $this->store->setSecret('google.client_secret', trim($secret));
    }

    public function clientId(): string
    {
        return (string) $this->store->get('google.client_id', '');
    }

    // ---- signing in -----------------------------------------------------------------------

    /** Where to send the owner's browser to give the helper access. */
    public function signInUrl(string $redirect, string $state): string
    {
        return self::AUTH . '?' . http_build_query([
            'client_id' => $this->clientId(),
            'redirect_uri' => $redirect,
            'response_type' => 'code',
            'scope' => implode(' ', self::SCOPES),
            'access_type' => 'offline',
            'prompt' => 'consent',
            'state' => $state,
        ]);
    }

    /**
     * Finishes a sign-in: trades the code Google sent back for the lasting
     * sign-in, finds out whose mailbox it is, and stores it sealed.
     * Returns the account id.
     */
    public function finishSignIn(string $code, string $redirect): int
    {
        $t = $this->token(['grant_type' => 'authorization_code', 'code' => $code, 'redirect_uri' => $redirect]);
        if (($t['refresh_token'] ?? '') === '') {
            throw new GoogleError('Google did not give a lasting sign-in. Remove Précis from your Google Account’s connected apps and try again.');
        }
        $granted = explode(' ', (string) ($t['scope'] ?? ''));
        if (!in_array(self::SCOPES[0], $granted, true)) {
            throw new GoogleError('Reading mail was not allowed on Google’s screen, so the helper cannot work. Sign in again and leave the boxes ticked.');
        }
        $tokens = ['refresh' => $t['refresh_token'], 'access' => $t['access_token'], 'exp' => $this->store->now() + (int) ($t['expires_in'] ?? 3000), 'scope' => $t['scope'] ?? ''];
        $profile = $this->call('GET', self::GMAIL . 'profile', (string) $tokens['access']);
        $email = Classifier::lower((string) ($profile['emailAddress'] ?? ''));
        if ($email === '') {
            throw new GoogleError('Google did not say whose mailbox this is.');
        }
        $db = $this->store->db;
        $sealed = $this->store->crypto->seal(Store::json($tokens));
        $existing = $db->val('SELECT id FROM {accounts} WHERE email = ?', [$email]);
        if ($existing !== null) {
            $db->run('UPDATE {accounts} SET tokens = ?, last_error = NULL WHERE id = ?', [$sealed, (int) $existing]);
            return (int) $existing;
        }
        return $db->insert('accounts', ['email' => $email, 'tokens' => $sealed, 'history_id' => (string) ($profile['historyId'] ?? ''), 'created' => $this->store->now()]);
    }

    /** Gives the sign-in back to Google and forgets the mailbox. */
    public function disconnect(int $accountId): void
    {
        $row = $this->store->db->one('SELECT tokens FROM {accounts} WHERE id = ?', [$accountId]);
        if ($row === null) {
            return;
        }
        try {
            $tokens = Store::decode($this->store->crypto->open((string) $row['tokens']));
            try {
                $this->call('POST', self::GMAIL . 'stop', $this->accessToken($accountId), '{}');
            } catch (\Throwable) {
                // No notice was running, or the sign-in is already gone.
            }
            $this->http->request('POST', self::REVOKE, ['Content-Type' => 'application/x-www-form-urlencoded'], http_build_query(['token' => (string) ($tokens['refresh'] ?? '')]));
        } catch (\Throwable) {
            // Forgetting it here still happens.
        }
        $db = $this->store->db;
        $db->run('DELETE FROM {rcpts} WHERE email_id IN (SELECT id FROM {emails} WHERE account_id = ?)', [$accountId]);
        $db->run('DELETE FROM {emails} WHERE account_id = ?', [$accountId]);
        $db->run('DELETE FROM {accounts} WHERE id = ?', [$accountId]);
    }

    /** A short-lived pass for calls, renewed from the lasting sign-in when it is about to run out. */
    public function accessToken(int $accountId): string
    {
        $db = $this->store->db;
        $row = $db->one('SELECT tokens FROM {accounts} WHERE id = ?', [$accountId]);
        if ($row === null) {
            throw new GoogleError('That mailbox is not connected.', 0, true);
        }
        $tokens = Store::decode($this->store->crypto->open((string) $row['tokens']));
        if ((int) ($tokens['exp'] ?? 0) - 90 > $this->store->now() && ($tokens['access'] ?? '') !== '') {
            return (string) $tokens['access'];
        }
        try {
            $t = $this->token(['grant_type' => 'refresh_token', 'refresh_token' => (string) ($tokens['refresh'] ?? '')]);
        } catch (GoogleError $e) {
            if ($e->needsSignIn) {
                $db->run('UPDATE {accounts} SET last_error = ? WHERE id = ?', ['Google ended the sign-in. Connect Google again on the helper’s page.', $accountId]);
            }
            throw $e;
        }
        $tokens['access'] = $t['access_token'];
        $tokens['exp'] = $this->store->now() + (int) ($t['expires_in'] ?? 3000);
        $db->run('UPDATE {accounts} SET tokens = ? WHERE id = ?', [$this->store->crypto->seal(Store::json($tokens)), $accountId]);
        return (string) $tokens['access'];
    }

    /** @return array<string, mixed> */
    private function token(array $fields): array
    {
        $fields += ['client_id' => $this->clientId(), 'client_secret' => (string) $this->store->getSecret('google.client_secret')];
        $r = $this->http->request('POST', self::TOKEN, ['Content-Type' => 'application/x-www-form-urlencoded'], http_build_query($fields));
        $json = Store::decode($r['body']);
        if ($r['status'] !== 200 || !isset($json['access_token'])) {
            $error = (string) ($json['error'] ?? '');
            throw new GoogleError('Google refused the sign-in' . ($error === '' ? '.' : " ($error)."), $r['status'], in_array($error, ['invalid_grant', 'invalid_client', 'unauthorized_client'], true));
        }
        return $json;
    }

    // ---- Gmail ------------------------------------------------------------------------------

    /** @return array<string, mixed> */
    public function profile(int $accountId): array
    {
        return $this->call('GET', self::GMAIL . 'profile', $this->accessToken($accountId));
    }

    /**
     * Asks Google to tell the helper about new mail. Lasts seven days, so it
     * is asked again daily.
     *
     * @return array{historyId: string, expires: int}
     */
    public function watch(int $accountId, string $topic): array
    {
        $r = $this->call('POST', self::GMAIL . 'watch', $this->accessToken($accountId), Store::json(['topicName' => $topic]));
        return ['historyId' => (string) ($r['historyId'] ?? ''), 'expires' => intdiv((int) ($r['expiration'] ?? 0), 1000)];
    }

    public function stopWatch(int $accountId): void
    {
        $this->call('POST', self::GMAIL . 'stop', $this->accessToken($accountId), '{}');
    }

    /**
     * What happened in the mailbox since [$startHistoryId].
     *
     * @return array{changed: list<string>, historyId: string, tooOld: bool} Gmail ids of emails that are new or whose labels changed
     */
    public function history(int $accountId, string $startHistoryId): array
    {
        $changed = [];
        $latest = $startHistoryId;
        $page = null;
        $token = $this->accessToken($accountId);
        for ($i = 0; $i < 20; $i++) {
            $q = 'startHistoryId=' . rawurlencode($startHistoryId) . '&maxResults=500&historyTypes=messageAdded&historyTypes=labelAdded&historyTypes=labelRemoved' . ($page === null ? '' : '&pageToken=' . rawurlencode($page));
            try {
                $r = $this->call('GET', self::GMAIL . 'history?' . $q, $token);
            } catch (GoogleError $e) {
                if ($e->status === 404) {
                    return ['changed' => [], 'historyId' => $startHistoryId, 'tooOld' => true];
                }
                throw $e;
            }
            foreach ($r['history'] ?? [] as $h) {
                foreach (['messagesAdded', 'labelsAdded', 'labelsRemoved'] as $kind) {
                    foreach ($h[$kind] ?? [] as $entry) {
                        $id = (string) ($entry['message']['id'] ?? '');
                        if ($id !== '') {
                            $changed[$id] = true;
                        }
                    }
                }
            }
            $latest = (string) ($r['historyId'] ?? $latest);
            $page = $r['nextPageToken'] ?? null;
            if ($page === null) {
                break;
            }
        }
        return ['changed' => array_map('strval', array_keys($changed)), 'historyId' => $latest, 'tooOld' => false];
    }

    /**
     * One page of Gmail ids matching [$query], newest first.
     *
     * @return array{ids: list<string>, next: ?string}
     */
    public function listIds(int $accountId, string $query, ?string $page = null, int $max = 100): array
    {
        $q = 'maxResults=' . $max . '&q=' . rawurlencode($query) . ($page === null ? '' : '&pageToken=' . rawurlencode($page));
        $r = $this->call('GET', self::GMAIL . 'messages?' . $q, $this->accessToken($accountId));
        $ids = [];
        foreach ($r['messages'] ?? [] as $m) {
            $ids[] = (string) $m['id'];
        }
        return ['ids' => $ids, 'next' => isset($r['nextPageToken']) ? (string) $r['nextPageToken'] : null];
    }

    /**
     * The header facts of several emails. An id Gmail no longer has comes
     * back as null.
     *
     * @param list<string> $ids
     * @return array<string, array<string, mixed>|null>
     */
    public function metadata(int $accountId, array $ids): array
    {
        if ($ids === []) {
            return [];
        }
        $fields = implode('', array_map(static fn (string $h): string => '&metadataHeaders=' . rawurlencode($h), self::HEADERS));
        $urls = array_map(static fn (string $id): string => self::GMAIL . 'messages/' . rawurlencode($id) . '?format=metadata' . $fields, $ids);
        $answers = $this->http->getMany($urls, ['Authorization' => 'Bearer ' . $this->accessToken($accountId)]);
        $out = [];
        foreach ($ids as $i => $id) {
            $a = $answers[$i] ?? ['status' => 599, 'body' => ''];
            if ($a['status'] === 404) {
                $out[$id] = null;
                continue;
            }
            if ($a['status'] !== 200) {
                throw new GoogleError('Gmail did not answer for an email (' . $a['status'] . ').', $a['status'], $a['status'] === 401);
            }
            $out[$id] = Store::decode($a['body']);
        }
        return $out;
    }

    /**
     * One whole email, words included, for the assistant to read. It is
     * handed on and let go; the helper does not keep it. Null when Gmail no
     * longer has it.
     *
     * @return array<string, mixed>|null
     */
    public function full(int $accountId, string $id): ?array
    {
        try {
            return $this->call('GET', self::GMAIL . 'messages/' . rawurlencode($id) . '?format=full', $this->accessToken($accountId));
        } catch (GoogleError $e) {
            if ($e->status === 404) {
                return null;
            }
            throw $e;
        }
    }

    /** The addresses the owner sends from, lower-cased. */
    public function sendingAddresses(int $accountId): array
    {
        $r = $this->call('GET', self::GMAIL . 'settings/sendAs', $this->accessToken($accountId));
        $out = [];
        foreach ($r['sendAs'] ?? [] as $s) {
            $out[] = ['email' => Classifier::lower((string) ($s['sendAsEmail'] ?? '')), 'name' => (string) ($s['displayName'] ?? '')];
        }
        return $out;
    }

    /** @return array<string, mixed> */
    private function call(string $method, string $url, string $accessToken, ?string $body = null): array
    {
        $headers = ['Authorization' => 'Bearer ' . $accessToken, 'Accept' => 'application/json'];
        if ($body !== null) {
            $headers['Content-Type'] = 'application/json';
        }
        $r = $this->http->request($method, $url, $headers, $body);
        if ($r['status'] < 200 || $r['status'] >= 300) {
            $json = Store::decode($r['body']);
            $why = (string) ($json['error']['message'] ?? '');
            throw new GoogleError('Gmail said no (' . $r['status'] . ($why === '' ? '' : ': ' . mb_substr($why, 0, 200)) . ').', $r['status'], $r['status'] === 401);
        }
        return Store::decode($r['body']);
    }
}
