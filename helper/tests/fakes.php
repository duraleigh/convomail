<?php
declare(strict_types=1);

namespace Precis\Tests;

/**
 * A stand-in for Google: a small mailbox in memory that answers the same
 * addresses the helper calls. No check ever reaches the internet.
 */
final class FakeGoogle implements \Precis\Http
{
    /** @var array<string, array<string, mixed>> Gmail id => message */
    public array $messages = [];

    /** @var list<array{id: int, message: string, kind: string}> */
    public array $history = [];

    public int $historyId = 1000;
    public string $email = 'me@example.com';
    public bool $refuseRefresh = false;
    public bool $historyTooOld = false;
    public int $tokensGiven = 0;
    public int $watchCalls = 0;
    public ?string $watchTopic = null;
    public bool $refuseWatch = false;

    /** @var list<array{email: string, name: string}> */
    public array $sendAs = [];

    /** What Google says was allowed at sign-in; null means everything asked for. */
    public ?string $scope = null;

    /** @var list<array{token: string, data: array<string, string>}> alerts sent to phones */
    public array $pushed = [];

    /** @var list<string> phones that no longer have the app */
    public array $gonePhones = [];
    public bool $refuseServiceAccount = false;
    public int $serviceTokens = 0;

    /** @var list<string> every address called, for checks that count calls */
    public array $calls = [];
    private int $next = 1;

    public function __construct(private readonly Clock $clock)
    {
    }

    /**
     * Puts an email in the mailbox and returns its Gmail id.
     *
     * @param array<string, string> $headers
     * @param list<string> $labels
     */
    public function add(array $headers, array $labels = ['INBOX', 'UNREAD'], string $snippet = '', ?int $at = null): string
    {
        $id = sprintf('g%05d', $this->next++);
        $headers += ['Message-ID' => "<$id@mail.example>"];
        $list = [];
        foreach ($headers as $k => $v) {
            $list[] = ['name' => $k, 'value' => $v];
        }
        $this->messages[$id] = ['id' => $id, 'threadId' => 't' . $id, 'labelIds' => $labels, 'snippet' => $snippet, 'internalDate' => (string) (($at ?? $this->clock->now) * 1000), 'payload' => ['headers' => $list]];
        $this->history[] = ['id' => ++$this->historyId, 'message' => $id, 'kind' => 'messagesAdded'];
        return $id;
    }

    /** Gives an email its words, as Gmail would hand them over in full. */
    public function setBody(string $id, string $plain, ?string $html = null): void
    {
        $enc = static fn (string $s): string => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
        $parts = [['mimeType' => 'text/plain', 'filename' => '', 'body' => ['data' => $enc($plain)]]];
        if ($html !== null) {
            $parts[] = ['mimeType' => 'text/html', 'filename' => '', 'body' => ['data' => $enc($html)]];
        }
        $this->messages[$id]['payload']['mimeType'] = 'multipart/alternative';
        $this->messages[$id]['payload']['parts'] = $plain === '' && $html !== null ? [$parts[1]] : $parts;
    }

    /** @param list<string> $labels */
    public function relabel(string $id, array $labels): void
    {
        $this->messages[$id]['labelIds'] = $labels;
        $this->history[] = ['id' => ++$this->historyId, 'message' => $id, 'kind' => 'labelsAdded'];
    }

    public function delete(string $id): void
    {
        unset($this->messages[$id]);
    }

    public function request(string $method, string $url, array $headers = [], ?string $body = null): array
    {
        $this->calls[] = "$method " . preg_replace('~\?.*$~', '', $url);
        $path = (string) parse_url($url, PHP_URL_PATH);
        parse_str((string) parse_url($url, PHP_URL_QUERY), $q);
        $json = static fn (array $d, int $s = 200): array => ['status' => $s, 'body' => (string) json_encode($d)];
        if (str_contains($url, 'fcm.googleapis.com/v1/projects/')) {
            if (!str_starts_with($headers['Authorization'] ?? '', 'Bearer fcm-')) {
                return $json(['error' => ['status' => 'UNAUTHENTICATED']], 401);
            }
            $m = json_decode((string) $body, true)['message'] ?? [];
            if (in_array((string) ($m['token'] ?? ''), $this->gonePhones, true)) {
                return $json(['error' => ['status' => 'NOT_FOUND', 'details' => [['errorCode' => 'UNREGISTERED']]]], 404);
            }
            $this->pushed[] = ['token' => (string) ($m['token'] ?? ''), 'data' => (array) ($m['data'] ?? [])];
            return $json(['name' => 'projects/x/messages/1']);
        }
        if (str_contains($url, 'oauth2.googleapis.com/token')) {
            parse_str((string) $body, $f);
            if (($f['grant_type'] ?? '') === 'urn:ietf:params:oauth:grant-type:jwt-bearer') {
                // A service account proving itself with a signed note.
                if ($this->refuseServiceAccount || substr_count((string) ($f['assertion'] ?? ''), '.') !== 2) {
                    return $json(['error' => 'invalid_grant'], 400);
                }
                return $json(['access_token' => 'fcm-' . (++$this->serviceTokens), 'expires_in' => 3600]);
            }
            if (($f['client_secret'] ?? '') !== 'the-secret') {
                return $json(['error' => 'invalid_client'], 401);
            }
            if (($f['grant_type'] ?? '') === 'refresh_token') {
                if ($this->refuseRefresh || ($f['refresh_token'] ?? '') !== 'refresh-1') {
                    return $json(['error' => 'invalid_grant'], 400);
                }
                return $json(['access_token' => 'access-' . (++$this->tokensGiven), 'expires_in' => 3600]);
            }
            if (($f['code'] ?? '') !== 'good-code') {
                return $json(['error' => 'invalid_grant'], 400);
            }
            return $json(['access_token' => 'access-' . (++$this->tokensGiven), 'expires_in' => 3600, 'refresh_token' => 'refresh-1', 'scope' => $this->scope ?? implode(' ', \Precis\Google::SCOPES)]);
        }
        if (str_contains($url, 'oauth2.googleapis.com/revoke')) {
            return $json([]);
        }
        if (!str_starts_with($headers['Authorization'] ?? '', 'Bearer access-')) {
            return $json(['error' => ['message' => 'no pass']], 401);
        }
        $rest = substr($path, strlen('/gmail/v1/users/me/'));
        if ($rest === 'profile') {
            return $json(['emailAddress' => $this->email, 'historyId' => (string) $this->historyId]);
        }
        if ($rest === 'watch') {
            $this->watchCalls++;
            if ($this->refuseWatch) {
                return $json(['error' => ['message' => 'the topic was not found']], 404);
            }
            $this->watchTopic = (string) (json_decode((string) $body, true)['topicName'] ?? '');
            return $json(['historyId' => (string) $this->historyId, 'expiration' => (string) (($this->clock->now + 7 * 86400) * 1000)]);
        }
        if ($rest === 'stop') {
            $this->watchTopic = null;
            return $json([]);
        }
        if ($rest === 'settings/sendAs') {
            return $json(['sendAs' => array_map(static fn (array $s): array => ['sendAsEmail' => $s['email'], 'displayName' => $s['name']], $this->sendAs)]);
        }
        if ($rest === 'history') {
            if ($this->historyTooOld) {
                return $json(['error' => ['message' => 'too old']], 404);
            }
            $start = (int) ($q['startHistoryId'] ?? 0);
            $out = [];
            foreach ($this->history as $h) {
                if ($h['id'] > $start) {
                    $out[] = ['id' => (string) $h['id'], $h['kind'] => [['message' => ['id' => $h['message']]]]];
                }
            }
            return $json(['history' => $out, 'historyId' => (string) $this->historyId]);
        }
        if ($rest === 'messages') {
            $days = preg_match('~newer_than:(\d+)d~', (string) ($q['q'] ?? ''), $m) === 1 ? (int) $m[1] : 3650;
            $ids = [];
            foreach ($this->messages as $id => $msg) {
                if ((int) $msg['internalDate'] / 1000 >= $this->clock->now - $days * 86400 && !in_array('DRAFT', $msg['labelIds'], true)) {
                    $ids[$id] = (int) $msg['internalDate'];
                }
            }
            arsort($ids);
            $all = array_map('strval', array_keys($ids));
            $offset = (int) ($q['pageToken'] ?? 0);
            $max = (int) ($q['maxResults'] ?? 100);
            $page = array_slice($all, $offset, $max);
            $d = ['messages' => array_map(static fn (string $id): array => ['id' => $id, 'threadId' => "t$id"], $page)];
            if ($offset + $max < count($all)) {
                $d['nextPageToken'] = (string) ($offset + $max);
            }
            return $json($d);
        }
        if (str_starts_with($rest, 'threads/')) {
            $tid = substr($rest, 8);
            $in = array_values(array_filter($this->messages, static fn (array $m): bool => (string) $m['threadId'] === $tid));
            usort($in, static fn (array $a, array $b): int => (int) $a['internalDate'] <=> (int) $b['internalDate']);
            return $in === [] ? $json(['error' => ['message' => 'gone']], 404) : $json(['id' => $tid, 'messages' => $in]);
        }
        if (str_starts_with($rest, 'messages/')) {
            $id = substr($rest, 9);
            return isset($this->messages[$id]) ? $json($this->messages[$id]) : $json(['error' => ['message' => 'gone']], 404);
        }
        return $json(['error' => ['message' => 'unknown address']], 400);
    }

    public function getMany(array $urls, array $headers = []): array
    {
        return array_map(fn (string $u): array => $this->request('GET', $u, $headers), $urls);
    }
}

/**
 * A stand-in for Anthropic: answers the two addresses the assistant's
 * library calls, in the shape Anthropic answers. No check ever reaches the
 * internet or spends anything.
 */
final class FakeClaude implements \Psr\Http\Client\ClientInterface
{
    public const KEY = 'sk-ant-test-key';

    /** @var list<array{path: string, key: string, body: array<string, mixed>}> every request made */
    public array $requests = [];

    /** @var (\Closure(string, array<string, mixed>): array<string, mixed>)|null given the email text and the request, what to answer */
    public ?\Closure $answer = null;

    /** When set, every reading is answered with this status and error type. */
    public ?array $fail = null;

    public bool $refuse = false;
    public int $in = 900;
    public int $out = 150;
    public int $cacheRead = 0;
    public int $cacheWrite = 0;

    public function sendRequest(\Psr\Http\Message\RequestInterface $request): \Psr\Http\Message\ResponseInterface
    {
        $path = $request->getUri()->getPath();
        // The library sends the key either way, depending on its version.
        $key = $request->getHeaderLine('x-api-key');
        if ($key === '' && str_starts_with($request->getHeaderLine('Authorization'), 'Bearer ')) {
            $key = substr($request->getHeaderLine('Authorization'), 7);
        }
        $body = json_decode((string) $request->getBody(), true);
        $this->requests[] = ['path' => $path, 'key' => $key, 'body' => is_array($body) ? $body : []];
        $json = static fn (array $d, int $s = 200): \Psr\Http\Message\ResponseInterface => new \GuzzleHttp\Psr7\Response($s, ['content-type' => 'application/json', 'request-id' => 'req_test'], (string) json_encode($d));
        if ($key !== self::KEY) {
            return $json(['type' => 'error', 'error' => ['type' => 'authentication_error', 'message' => 'invalid x-api-key']], 401);
        }
        if (str_starts_with($path, '/v1/models/')) {
            return $json(['id' => basename($path), 'type' => 'model', 'display_name' => 'A reader', 'created_at' => '2026-01-01T00:00:00Z', 'max_input_tokens' => 1000000, 'max_tokens' => 128000, 'capabilities' => null]);
        }
        if ($this->fail !== null) {
            return $json(['type' => 'error', 'error' => ['type' => $this->fail[1], 'message' => $this->fail[2] ?? 'no']], $this->fail[0]);
        }
        $email = (string) ($body['messages'][0]['content'] ?? '');
        $data = $this->answer !== null ? ($this->answer)($email, $body) : ['line' => 'A plain email.', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'none', 'reasons' => ['Nothing is asked of you.']];
        return $json([
            'id' => 'msg_test',
            'type' => 'message',
            'role' => 'assistant',
            'model' => (string) ($body['model'] ?? ''),
            'content' => $this->refuse ? [] : [['type' => 'text', 'text' => (string) json_encode($data)]],
            'stop_reason' => $this->refuse ? 'refusal' : 'end_turn',
            'stop_sequence' => null,
            'usage' => ['input_tokens' => $this->in, 'output_tokens' => $this->out, 'cache_creation_input_tokens' => $this->cacheWrite, 'cache_read_input_tokens' => $this->cacheRead],
        ]);
    }

    /** The readings asked for (not the key checks). */
    public function readings(): array
    {
        return array_values(array_filter($this->requests, static fn (array $r): bool => $r['path'] === '/v1/messages'));
    }

    /** How the helper reaches this stand-in. */
    public function maker(): \Closure
    {
        return fn (string $key): \Precis\Assistant => new \Precis\Claude($key, $this, 5.0, 0);
    }
}

/** A helper wired to the stand-in Google, with one mailbox already connected. */
final class World
{
    public Clock $clock;
    public \Precis\Store $store;
    public FakeGoogle $fake;
    public \Precis\Google $google;
    public \Precis\Sorter $sorter;
    public \Precis\Reader $reader;
    public \Precis\Sync $sync;
    public FakeClaude $claude;
    public \Precis\Readings $readings;
    public int $account = 0;

    public function __construct(bool $connect = true)
    {
        $this->clock = new Clock();
        $this->store = store($this->clock);
        $this->fake = new FakeGoogle($this->clock);
        $this->google = new \Precis\Google($this->store, $this->fake);
        $this->sorter = new \Precis\Sorter($this->store);
        $this->reader = new \Precis\Reader($this->store, $this->google, $this->sorter);
        $this->sync = new \Precis\Sync($this->store, $this->sorter);
        $this->claude = new FakeClaude();
        $this->readings = new \Precis\Readings($this->store, $this->google, $this->sorter, $this->claude->maker());
        $this->store->put('names', 'user', ['first' => ['clay']]);
        if ($connect) {
            $this->google->setClient('1234567890-abcdefghijklmnop.apps.googleusercontent.com', 'the-secret');
            $this->account = $this->google->finishSignIn('good-code', 'https://helper.example/google/callback');
        }
    }

    /** Puts an email in the mailbox and lets the helper read it. Returns its Message-ID. */
    public function arrive(array $headers, array $labels = ['INBOX', 'UNREAD'], string $snippet = '', ?int $at = null): string
    {
        $id = $this->fake->add($headers, $labels, $snippet, $at);
        $this->reader->poll($this->account);
        foreach ($this->fake->messages[$id]['payload']['headers'] as $h) {
            if ($h['name'] === 'Message-ID') {
                return $h['value'];
            }
        }
        return '';
    }

    /**
     * Puts an email with words in the mailbox and lets the helper file it.
     * Returns its Message-ID.
     */
    public function arriveWith(array $headers, string $plain, ?string $html = null, array $labels = ['INBOX', 'UNREAD'], ?int $at = null): string
    {
        $id = $this->fake->add($headers, $labels, '', $at);
        $this->fake->setBody($id, $plain, $html);
        $this->reader->poll($this->account);
        foreach ($this->fake->messages[$id]['payload']['headers'] as $h) {
            if ($h['name'] === 'Message-ID') {
                return $h['value'];
            }
        }
        return '';
    }

    /** Saves the stand-in key, picks a reader and turns the assistant on. */
    public function assistantOn(string $model = 'claude-opus-5-5'): void
    {
        check($this->readings->setKey(FakeClaude::KEY), 'the key should be kept');
        $this->readings->setModel($model);
        $this->readings->turn(true);
    }

    public function reading(string $messageId): ?array
    {
        return $this->store->item('read', $messageId);
    }

    public function sender(string $key): ?array
    {
        return $this->store->item('sender', $key);
    }

    public function sort(string $messageId): ?array
    {
        return $this->store->item('sort', $messageId);
    }

    /** Lets time pass. */
    public function later(int $seconds): void
    {
        $this->clock->now += $seconds;
    }
}
