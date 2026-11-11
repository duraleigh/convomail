<?php
declare(strict_types=1);

namespace Precis\Tests;

use Precis\App;
use Precis\Request;
use Precis\Session;

/** A helper in a scratch folder, as a browser and a device would meet it. */
final class Site
{
    public string $home;
    public Session $session;
    public FakeGoogle $fake;
    public Clock $clock;
    public App $app;
    public string $key = 'setup-key-123';
    public string $pass = 'correct horse battery';

    public function __construct(bool $setUp = true)
    {
        $this->home = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'precis-site-' . bin2hex(random_bytes(5));
        mkdir($this->home, 0700, true);
        file_put_contents($this->home . DIRECTORY_SEPARATOR . 'setup.key', $this->key);
        $this->clock = new Clock();
        $this->fake = new FakeGoogle($this->clock);
        $this->session = new Session();
        $this->app = $this->fresh();
        if ($setUp) {
            $r = $this->post('/setup', ['key' => $this->key, 'db_name' => 'sqlite_helper', 'db_user' => '', 'db_pass' => '', 'db_host' => 'localhost', 'pass' => $this->pass, 'pass2' => $this->pass]);
            same(303, $r->status, 'setup should finish: ' . strip_tags($r->body));
        }
    }

    /** A new App on the same folder, as the next request would get. */
    public function fresh(): App
    {
        return $this->app = new App($this->home, $this->fake, $this->session, \Closure::fromCallable($this->clock));
    }

    public function get(string $path, array $query = [], array $headers = [], string $host = 'localhost', bool $https = false): \Precis\Response
    {
        return $this->app->handle(new Request('GET', $path, $query, [], $headers, '', '10.0.0.1', $https, $host));
    }

    public function post(string $path, array $form = [], array $query = [], string $ip = '10.0.0.1'): \Precis\Response
    {
        return $this->app->handle(new Request('POST', $path, $query, $form, [], '', $ip, false, 'localhost'));
    }

    /** A form post from the signed-in owner, carrying the form token. */
    public function owner(string $path, array $form = []): \Precis\Response
    {
        return $this->post($path, $form + ['csrf' => $this->session->formToken()]);
    }

    public function api(string $method, string $path, ?array $json = null, ?string $token = null, array $query = [], string $ip = '10.0.0.2'): \Precis\Response
    {
        return $this->app->handle(new Request($method, $path, $query, [], $token === null ? [] : ['x-precis-token' => $token], $json === null ? '' : (string) json_encode($json), $ip, false, 'localhost'));
    }

    /** Joins a device and returns its token. */
    public function join(string $name = 'Clay PC'): string
    {
        $this->owner('/devices/code');
        $code = (string) $this->session->get('code');
        $r = $this->api('POST', '/api/pair', ['code' => $code, 'name' => $name, 'kind' => 'windows']);
        same(200, $r->status, $r->body);
        return (string) $r->data()['token'];
    }

    public function connectGoogle(): void
    {
        $this->owner('/google/client', ['client_id' => '1234567890-abcdefghijklmnop.apps.googleusercontent.com', 'client_secret' => 'the-secret']);
        $start = $this->owner('/google/start');
        parse_str((string) parse_url($start->headers['Location'], PHP_URL_QUERY), $q);
        $back = $this->get('/google/callback', ['code' => 'good-code', 'state' => (string) $q['state']]);
        same(303, $back->status);
    }

    public function __destruct()
    {
        // Let go of the database before its file is removed.
        unset($this->app);
        gc_collect_cycles();
        foreach (glob($this->home . DIRECTORY_SEPARATOR . '*') ?: [] as $f) {
            @unlink($f);
        }
        @rmdir($this->home);
    }
}

return [
    'before setup, nothing opens without the setup link' => function (): void {
        $s = new Site(false);
        same(403, $s->get('/')->status);
        same(403, $s->get('/', ['key' => 'wrong'])->status);
        same(503, $s->api('GET', '/api/ping')->status);
        $page = $s->get('/', ['key' => $s->key]);
        same(200, $page->status);
        check(str_contains($page->body, 'Set up the Précis helper'));
    },

    'setup needs a long passphrase typed twice, and a database that opens' => function (): void {
        $s = new Site(false);
        $form = ['key' => $s->key, 'db_name' => 'sqlite_helper', 'db_user' => '', 'db_pass' => '', 'db_host' => 'localhost'];
        check(str_contains($s->post('/setup', $form + ['pass' => 'short', 'pass2' => 'short'])->body, 'at least 12'));
        check(str_contains($s->post('/setup', $form + ['pass' => 'long enough here', 'pass2' => 'long enough HERE'])->body, 'not the same'));
        check(str_contains($s->post('/setup', ['db_name' => 'bad name;drop'] + $form + ['pass' => 'long enough here', 'pass2' => 'long enough here'])->body, 'characters it should not'));
        check(!is_file($s->app->configFile()), 'nothing is written until it all checks out');
        same(403, $s->post('/setup', ['key' => 'nope'] + $form + ['pass' => 'long enough here', 'pass2' => 'long enough here'])->status);
    },

    'setup works once: the link is used up and the passphrase is kept only as a hash' => function (): void {
        $s = new Site();
        check(is_file($s->app->configFile()));
        check(!is_file($s->home . DIRECTORY_SEPARATOR . 'setup.key'), 'the setup link still works');
        check(is_file($s->home . DIRECTORY_SEPARATOR . 'master.key'));
        check(!str_contains((string) file_get_contents($s->app->configFile()), $s->pass));
        $hash = (string) $s->app->store()->get('owner.pass');
        check($hash !== $s->pass && password_verify($s->pass, $hash));
        // A later visit with the old link is just the sign-in page.
        $s->session->clear();
        $s->fresh();
        $again = $s->post('/setup', ['key' => $s->key, 'db_name' => 'sqlite_other', 'db_user' => '', 'db_pass' => '', 'db_host' => 'localhost', 'pass' => 'another passphrase', 'pass2' => 'another passphrase']);
        same(303, $again->status);
        check(password_verify($s->pass, (string) $s->app->store()->get('owner.pass')), 'setup ran a second time');
    },

    'the owner\'s page opens with the passphrase, closes after half an hour idle, and locks after wrong tries' => function (): void {
        $s = new Site();
        $s->session->clear();
        check(str_contains($s->get('/')->body, 'Passphrase'));
        same(403, $s->post('/signin', ['pass' => 'wrong wrong wrong'])->status);
        same(303, $s->post('/signin', ['pass' => $s->pass])->status);
        check(str_contains($s->get('/')->body, 'Your devices'));
        $s->clock->now += 1801;
        check(str_contains($s->get('/')->body, 'Passphrase'), 'still open after half an hour idle');
        for ($i = 0; $i < 8; $i++) {
            $s->post('/signin', ['pass' => 'guess number ' . $i]);
        }
        same(429, $s->post('/signin', ['pass' => $s->pass])->status, 'the right passphrase still waits out the lock');
        same(303, $s->post('/signin', ['pass' => $s->pass], [], '10.9.9.9')->status, 'from another address it is not locked');
    },

    'a form without its token changes nothing' => function (): void {
        $s = new Site();
        same(400, $s->post('/devices/code')->status);
        same(400, $s->post('/google/client', ['client_id' => 'x', 'client_secret' => 'y', 'csrf' => 'made-up'])->status);
        same(null, $s->session->get('code'));
    },

    'over plain http, pages are sent to https and devices are refused' => function (): void {
        $s = new Site();
        $page = $s->get('/', [], [], 'precis.example.com', false);
        same(303, $page->status);
        same('https://precis.example.com/', $page->headers['Location']);
        same(400, $s->app->handle(new Request('GET', '/api/ping', [], [], [], '', '1.1.1.1', false, 'precis.example.com'))->status);
        same(200, $s->app->handle(new Request('GET', '/api/ping', [], [], [], '', '1.1.1.1', true, 'precis.example.com'))->status);
    },

    'a device joins with the code from the owner\'s page and then talks with its token' => function (): void {
        $s = new Site();
        same(401, $s->api('GET', '/api/status')->status);
        same(401, $s->api('GET', '/api/changes', null, '1.' . str_repeat('a', 43))->status);
        same(403, $s->api('POST', '/api/pair', ['code' => 'AAAAAAAA', 'name' => 'x', 'kind' => 'windows'])->status);
        $s->owner('/devices/code');
        $page = $s->get('/');
        $code = (string) preg_match('~class="big">([A-Z0-9]{8})<~', $page->body, $m) ? $m[1] : '';
        check($code !== '', 'the code is shown on the page');
        check(!str_contains($s->get('/')->body, $code), 'and shown once only');
        $r = $s->api('POST', '/api/pair', ['code' => $code, 'name' => 'Clay PC', 'kind' => 'windows']);
        same(200, $r->status);
        $token = (string) $r->data()['token'];
        $status = $s->api('GET', '/api/status', null, $token);
        same(200, $status->status);
        same('Clay PC', $status->data()['device']['name']);
        check(str_contains($s->get('/')->body, 'Clay PC'), 'the device is listed for the owner');
        check(!str_contains($s->get('/')->body, explode('.', $token)[1]), 'its token is not');
    },

    'wrong joining codes lock joining for that address' => function (): void {
        $s = new Site();
        for ($i = 0; $i < 8; $i++) {
            $s->api('POST', '/api/pair', ['code' => 'WRONG' . $i . 'AA', 'name' => 'x', 'kind' => 'windows']);
        }
        $s->owner('/devices/code');
        same(429, $s->api('POST', '/api/pair', ['code' => (string) $s->session->get('code'), 'name' => 'x', 'kind' => 'windows'])->status);
    },

    'two devices keep in step through the helper' => function (): void {
        $s = new Site();
        $pc = $s->join('PC');
        $phone = $s->join('Phone');
        $pushed = $s->api('POST', '/api/push', ['items' => [['kind' => 'done', 'k' => '<m1@x>', 'data' => ['at' => 5]], ['kind' => 'tag', 'k' => 'Mine', 'data' => ['pos' => 9]]]], $pc);
        same(2, $pushed->data()['applied']);
        same([], $s->api('GET', '/api/changes', null, $pc, ['since' => '0'])->data()['items']);
        $got = $s->api('GET', '/api/changes', null, $phone, ['since' => '0'])->data();
        same(['<m1@x>', 'Mine'], array_column($got['items'], 'k'));
        same([], $s->api('GET', '/api/changes', null, $phone, ['since' => (string) $got['next']])->data()['items']);
        same(400, $s->api('POST', '/api/push', ['items' => [['kind' => 'sort', 'k' => '<m@x>', 'data' => []]]], $pc)->status);
        same(400, $s->api('POST', '/api/push', ['nothing' => true], $pc)->status);
        // One device signs the other out.
        $devices = $s->api('GET', '/api/devices', null, $pc)->data();
        same(2, count($devices['devices']));
        $other = array_values(array_filter($devices['devices'], static fn (array $d): bool => (int) $d['id'] !== (int) $devices['me']))[0];
        $s->api('POST', '/api/devices/signout', ['id' => $other['id']], $pc);
        same(401, $s->api('GET', '/api/changes', null, $phone)->status);
        // A signed-in device can make the code for the next one.
        $code = (string) $s->api('POST', '/api/devices/code', [], $pc)->data()['code'];
        same(200, $s->api('POST', '/api/pair', ['code' => $code, 'name' => 'New phone', 'kind' => 'android'])->status);
    },

    'connecting Google: the client is saved sealed, the sign-in must start from this page, and reading begins' => function (): void {
        $s = new Site();
        check(str_contains($s->get('/')->body, 'No mailbox is connected yet'));
        $s->owner('/google/client', ['client_id' => 'not-a-client-id', 'client_secret' => 'x']);
        check(str_contains($s->get('/')->body, 'Paste both'));
        $s->owner('/google/client', ['client_id' => '1234567890-abcdefghijklmnop.apps.googleusercontent.com', 'client_secret' => 'the-secret']);
        check(!str_contains((string) $s->app->store()->get('google.client_secret'), 'the-secret'), 'the secret is stored in the clear');
        $start = $s->owner('/google/start');
        check(str_starts_with($start->headers['Location'], 'https://accounts.google.com/o/oauth2/v2/auth?'));
        parse_str((string) parse_url($start->headers['Location'], PHP_URL_QUERY), $q);
        same('http://localhost/google/callback', $q['redirect_uri']);
        // Someone else's link back, with a made-up state, connects nothing.
        $s->get('/google/callback', ['code' => 'good-code', 'state' => 'made-up']);
        check(str_contains($s->get('/')->body, 'did not start from this page'));
        same(0, (int) $s->app->store()->db->val('SELECT COUNT(*) FROM {accounts}'));
        // Cancelling at Google connects nothing.
        $start = $s->owner('/google/start');
        parse_str((string) parse_url($start->headers['Location'], PHP_URL_QUERY), $q);
        $s->get('/google/callback', ['error' => 'access_denied', 'state' => (string) $q['state']]);
        check(str_contains($s->get('/')->body, 'was not finished'));
        // The real thing.
        $s->fake->add(['From' => 'Sarah Chen <sarah@x.com>', 'To' => 'me@example.com', 'Subject' => 'Lunch']);
        $s->connectGoogle();
        $page = $s->get('/')->body;
        check(str_contains($page, 'Google is connected') && str_contains($page, 'me@example.com') && str_contains($page, 'Working'));
        check(!str_contains($page, 'the-secret') && !str_contains($page, 'refresh-1') && !str_contains($page, 'access-'), 'a secret is shown on the page');
        $s->owner('/google/disconnect', ['id' => '1']);
        check(str_contains($s->get('/')->body, 'No mailbox is connected yet'));
    },

    'Google\'s notice needs its secret address, and makes the helper read at once' => function (): void {
        $s = new Site();
        $s->connectGoogle();
        $secret = (string) $s->app->store()->get('hook.secret');
        check(strlen($secret) >= 30);
        $body = (string) json_encode(['message' => ['data' => base64_encode((string) json_encode(['emailAddress' => 'me@example.com', 'historyId' => '1']))]]);
        $hook = static fn (Site $s, array $q, string $method = 'POST'): \Precis\Response => $s->app->handle(new Request($method, '/hook/gmail', $q, [], [], $body, '8.8.8.8', false, 'localhost'));
        same(404, $hook($s, [])->status);
        same(404, $hook($s, ['k' => 'guess'])->status);
        same(404, $hook($s, ['k' => $secret], 'GET')->status);
        $s->fake->add(['From' => 'Sarah Chen <sarah@x.com>', 'To' => 'me@example.com', 'Subject' => 'Lunch']);
        same(204, $hook($s, ['k' => $secret])->status);
        same('people', $s->app->store()->item('sender', 'sarah@x.com')['cls']);
        check(str_contains($s->get('/')->body, 'hook/gmail?k=' . $secret), 'the owner can copy the address for Google');
        // A notice with nonsense in it is still acknowledged, so Google does not keep resending.
        same(204, $s->app->handle(new Request('POST', '/hook/gmail', ['k' => $secret], [], [], 'not json', '8.8.8.8', false, 'localhost'))->status);
    },

    'setting the topic turns the instant notice on; clearing it turns it off' => function (): void {
        $s = new Site();
        $s->connectGoogle();
        $s->owner('/google/topic', ['topic' => 'not a topic']);
        check(str_contains($s->get('/')->body, 'A topic name looks like'));
        $s->owner('/google/topic', ['topic' => 'projects/my-proj/topics/precis-mail']);
        same('projects/my-proj/topics/precis-mail', $s->fake->watchTopic);
        check(str_contains($s->get('/')->body, 'Google will now tell the helper'));
        $s->owner('/google/topic', ['topic' => '']);
        same(null, $s->fake->watchTopic);
        $s->fake->refuseWatch = true;
        $s->owner('/google/topic', ['topic' => 'projects/my-proj/topics/missing']);
        check(str_contains($s->get('/')->body, 'Google refused'));
    },

    'a device reads the helper\'s state: the mailbox, the first read, the timer' => function (): void {
        $s = new Site();
        $token = $s->join();
        $s->connectGoogle();
        $st = $s->api('GET', '/api/status', null, $token)->data();
        same('me@example.com', $st['accounts'][0]['email']);
        same(false, $st['accounts'][0]['firstReadDone']);
        same(null, $st['accounts'][0]['error']);
        check(!isset($st['accounts'][0]['tokens']) && !str_contains((string) json_encode($st), 'refresh'));
        same(404, $s->api('GET', '/api/nothing-here', null, $token)->status);
    },

    'the first sending-up goes through the same door and is kept for sorting' => function (): void {
        $s = new Site();
        $token = $s->join();
        $r = $s->api('POST', '/api/seed', ['at' => $s->clock->now, 'senders' => [['k' => 'sarah@x.com', 'item' => ['cls' => 'people', 'src' => 'auto', 'name' => 'Sarah Chen'], 'facts' => ['address' => 'sarah@x.com', 'messagesReceived' => 3]]], 'myIds' => ['<a@x>']], $token);
        same(200, $r->status, $r->body);
        same(1, $r->data()['senders']);
        same('Sarah Chen', $s->app->store()->item('sender', 'sarah@x.com')['name']);
        same(3, $s->app->sorter()->facts('sarah@x.com')['messagesReceived']);
    },

    'a problem inside the helper says so plainly and gives nothing away' => function (): void {
        $s = new Site();
        $token = $s->join();
        $s->app->store()->db->exec('DROP TABLE {items}');
        $r = $s->api('GET', '/api/changes', null, $token);
        same(500, $r->status);
        same(['error' => 'The helper had a problem.'], $r->data());
    },
];
