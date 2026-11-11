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
        if (str_contains($url, 'oauth2.googleapis.com/token')) {
            parse_str((string) $body, $f);
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
            return $json(['access_token' => 'access-' . (++$this->tokensGiven), 'expires_in' => 3600, 'refresh_token' => 'refresh-1', 'scope' => implode(' ', \Precis\Google::SCOPES)]);
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
