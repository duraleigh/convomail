<?php
declare(strict_types=1);

namespace Precis;

use InvalidArgumentException;

/**
 * The helper as a web program: takes a request, gives an answer.
 *
 * Three kinds of caller, each let in a different way:
 *  - the owner's browser, by passphrase (the setup page, the owner's page);
 *  - a device (a PC or phone running Précis), by its own token;
 *  - Google's "new mail" notice, by a secret that is part of its address.
 */
final class App
{
    private const IDLE = 1800;

    public function __construct(
        private readonly string $home,
        private readonly Http $http,
        private readonly Session $session,
        private readonly ?\Closure $clock = null,
        private ?Store $store = null,
    ) {
    }

    private function now(): int
    {
        return $this->clock !== null ? (int) ($this->clock)() : time();
    }

    public function configFile(): string
    {
        return $this->home . DIRECTORY_SEPARATOR . 'config.php';
    }

    public function isSetUp(): bool
    {
        return $this->store !== null || is_file($this->configFile());
    }

    public function store(): Store
    {
        if ($this->store === null) {
            /** @var array<string, mixed> $config */
            $config = require $this->configFile();
            $db = Db::connect($config);
            Schema::migrate($db);
            $this->store = new Store($db, Crypto::fromFile($this->home . DIRECTORY_SEPARATOR . 'master.key'), $this->clock);
        }
        return $this->store;
    }

    private ?Sorter $sorter = null;

    public function sorter(): Sorter
    {
        return $this->sorter ??= new Sorter($this->store());
    }

    public function google(): Google
    {
        return new Google($this->store(), $this->http);
    }

    public function reader(): Reader
    {
        return new Reader($this->store(), $this->google(), $this->sorter());
    }

    public function devices(): Devices
    {
        return new Devices($this->store());
    }

    public function handle(Request $r): Response
    {
        try {
            if (!$r->https && !$r->isLocal()) {
                return str_starts_with($r->path, '/api/') || str_starts_with($r->path, '/hook/')
                    ? Response::error('Use https.', 400)
                    : Response::redirect('https://' . $r->host . $r->path);
            }
            if (!$this->isSetUp()) {
                return $this->setup($r);
            }
            // The helper answers at its own address only. Its web folder sits
            // inside the main website's folder on some hosts, which would make
            // it reachable under the website's address too; that is refused.
            $own = strtolower((string) parse_url($this->base($r), PHP_URL_HOST));
            $asked = strtolower((string) preg_replace('~:\d+$~', '', $r->host));
            if ($own !== '' && $asked !== $own && !$r->isLocal()) {
                return new Response(404);
            }
            return match (true) {
                str_starts_with($r->path, '/api/') => $this->api($r),
                $r->path === '/hook/gmail' => $this->hook($r),
                default => $this->pages($r),
            };
        } catch (InvalidArgumentException $e) {
            return Response::error($e->getMessage(), 400);
        } catch (\Throwable $e) {
            try {
                $this->store?->log('error', 'A request failed: ' . get_class($e) . ' at ' . basename($e->getFile()) . ':' . $e->getLine());
            } catch (\Throwable) {
            }
            error_log('precis helper: ' . get_class($e) . ': ' . $e->getMessage() . ' at ' . basename($e->getFile()) . ':' . $e->getLine());
            return str_starts_with($r->path, '/api/') ? Response::error('The helper had a problem.', 500) : Response::html(Pages::message('Something went wrong', 'The helper had a problem. Nothing was changed. Go back and try again.'), 500);
        }
    }

    // ---- first-time setup ------------------------------------------------------------------

    private function setup(Request $r): Response
    {
        if (str_starts_with($r->path, '/api/') || str_starts_with($r->path, '/hook/')) {
            return Response::error('The helper is not set up yet.', 503);
        }
        $keyFile = $this->home . DIRECTORY_SEPARATOR . 'setup.key';
        $real = is_file($keyFile) ? trim((string) file_get_contents($keyFile)) : '';
        $given = (string) ($r->method === 'POST' ? ($r->form['key'] ?? '') : ($r->query['key'] ?? ''));
        if ($real === '' || !hash_equals($real, $given)) {
            return Response::html(Pages::message('Précis helper', 'The helper is installed but not set up yet. Open the setup link you were given.'), 403);
        }
        if ($r->method !== 'POST' || $r->path !== '/setup') {
            return Response::html(Pages::setup($given, null, []));
        }
        $f = $r->form;
        $fail = static fn (string $why): Response => Response::html(Pages::setup($given, $why, $f), 400);
        $pass = (string) ($f['pass'] ?? '');
        if (mb_strlen($pass) < 12) {
            return $fail('The passphrase needs at least 12 characters.');
        }
        if ($pass !== (string) ($f['pass2'] ?? '')) {
            return $fail('The two passphrases are not the same.');
        }
        $name = trim((string) ($f['db_name'] ?? ''));
        $host = trim((string) ($f['db_host'] ?? 'localhost'));
        if (!preg_match('~^[A-Za-z0-9_]{1,64}$~', $name) || !preg_match('~^[A-Za-z0-9_.:\-]{1,255}$~', $host)) {
            return $fail('The database name or server has characters it should not.');
        }
        $config = [
            'dsn' => str_starts_with($name, 'sqlite_') && $r->isLocal() ? 'sqlite:' . $this->home . DIRECTORY_SEPARATOR . $name . '.db' : "mysql:host=$host;dbname=$name;charset=utf8mb4",
            'user' => trim((string) ($f['db_user'] ?? '')),
            'pass' => (string) ($f['db_pass'] ?? ''),
            'prefix' => 'px_',
            'base_url' => ($r->https ? 'https://' : 'http://') . $r->host,
        ];
        try {
            $db = Db::connect($config);
            Schema::migrate($db);
        } catch (\Throwable $e) {
            return $fail('The helper could not open that database. Check the name, username and password. (' . mb_substr(preg_replace('~\s+~', ' ', $e->getMessage()) ?? '', 0, 160) . ')');
        }
        file_put_contents($this->configFile(), "<?php\nreturn " . var_export($config, true) . ";\n", LOCK_EX);
        @chmod($this->configFile(), 0600);
        $this->store = new Store($db, Crypto::fromFile($this->home . DIRECTORY_SEPARATOR . 'master.key'), $this->clock);
        $this->store->set('owner.pass', password_hash($pass, PASSWORD_DEFAULT));
        $this->store->set('hook.secret', Crypto::token(24));
        $this->store->log('info', 'The helper was set up.');
        @unlink($keyFile);
        $this->session->renew();
        $this->session->set('owner', $this->now());
        return Response::redirect('/');
    }

    // ---- the owner's pages ---------------------------------------------------------------------

    private function base(Request $r): string
    {
        /** @var array<string, mixed> $config */
        $config = is_file($this->configFile()) ? require $this->configFile() : [];
        return (string) ($config['base_url'] ?? (($r->https ? 'https://' : 'http://') . $r->host));
    }

    private function signedIn(): bool
    {
        $at = $this->session->get('owner');
        if (!is_int($at) || $this->now() - $at > self::IDLE) {
            return false;
        }
        $this->session->set('owner', $this->now());
        return true;
    }

    private function pages(Request $r): Response
    {
        $store = $this->store();
        if ($r->path === '/signin' && $r->method === 'POST') {
            $who = 'signin:' . $r->ip;
            $devices = $this->devices();
            if ($devices->blocked($who) || $devices->blocked('signin:all')) {
                return Response::html(Pages::signIn('Too many wrong tries. Wait fifteen minutes.'), 429);
            }
            if (!password_verify((string) ($r->form['pass'] ?? ''), (string) $store->get('owner.pass', ''))) {
                $devices->miss($who);
                usleep(400000);
                return Response::html(Pages::signIn('That is not the passphrase.'), 403);
            }
            $devices->clear($who);
            $this->session->renew();
            $this->session->set('owner', $this->now());
            return Response::redirect('/');
        }
        // Google sends the owner's browser back here; the session cookie comes with it.
        if ($r->path === '/google/callback' && $r->method === 'GET') {
            return $this->googleCallback($r);
        }
        if (!$this->signedIn()) {
            return $r->path === '/' && $r->method === 'GET' ? Response::html(Pages::signIn(null)) : Response::redirect('/');
        }
        if ($r->method === 'GET') {
            return $r->path === '/' ? $this->ownerPage($r) : Response::redirect('/');
        }
        if (!hash_equals($this->session->formToken(), (string) ($r->form['csrf'] ?? ''))) {
            return Response::html(Pages::message('Please try again', 'That page was open too long. Go back, reload it, and try again.'), 400);
        }
        switch ($r->path) {
            case '/signout':
                $this->session->clear();
                return Response::redirect('/');
            case '/google/client':
                $id = trim((string) ($r->form['client_id'] ?? ''));
                $secret = trim((string) ($r->form['client_secret'] ?? ''));
                if (!preg_match('~^[0-9A-Za-z._\-]{20,200}\.apps\.googleusercontent\.com$~', $id) || $secret === '') {
                    return $this->flash('Paste both the Client ID (it ends in .apps.googleusercontent.com) and the Client secret.', true);
                }
                $this->google()->setClient($id, $secret);
                return $this->flash('Saved. Now press Connect Google.');
            case '/google/start':
                if (!$this->google()->hasClient()) {
                    return $this->flash('Save the sign-in client first.', true);
                }
                $state = Crypto::token(24);
                $this->session->set('oauth', $state);
                return Response::redirect($this->google()->signInUrl($this->base($r) . '/google/callback', $state));
            case '/google/disconnect':
                $this->google()->disconnect((int) ($r->form['id'] ?? 0));
                $store->log('info', 'A mailbox was disconnected.');
                return $this->flash('Disconnected. The helper gave its sign-in back to Google and forgot that mailbox.');
            case '/google/topic':
                $topic = trim((string) ($r->form['topic'] ?? ''));
                if ($topic !== '' && !preg_match('#^projects/[a-z0-9\-:.]{4,60}/topics/[A-Za-z0-9\-_.~+%]{3,255}$#', $topic)) {
                    return $this->flash('A topic name looks like projects/your-project/topics/precis-mail.', true);
                }
                $store->set('google.topic', $topic === '' ? null : $topic);
                $reader = $this->reader();
                $asked = 0;
                foreach ($reader->accounts() as $a) {
                    if ($topic === '') {
                        try {
                            $this->google()->stopWatch((int) $a['id']);
                        } catch (\Throwable) {
                        }
                        $store->db->run('UPDATE {accounts} SET watch_expires = 0 WHERE id = ?', [(int) $a['id']]);
                    } else {
                        $store->db->run('UPDATE {accounts} SET watch_expires = 0 WHERE id = ?', [(int) $a['id']]);
                        $asked += (int) $reader->renewWatch((int) $a['id']);
                    }
                }
                if ($topic === '') {
                    return $this->flash('The instant notice is off. The helper looks every minute.');
                }
                $problem = $store->db->val('SELECT last_error FROM {accounts} WHERE last_error IS NOT NULL LIMIT 1');
                return $asked > 0 ? $this->flash('Saved. Google will now tell the helper about new mail.') : $this->flash($problem === null ? 'Saved. Connect Google to turn the notice on.' : 'Saved, but Google refused: ' . $problem, $problem !== null);
            case '/devices/code':
                $this->session->set('code', $this->devices()->newCode());
                return Response::redirect('/');
            case '/devices/signout':
                $this->devices()->signOut((int) ($r->form['id'] ?? 0));
                return $this->flash('That device is signed out.');
            default:
                return Response::redirect('/');
        }
    }

    private function flash(string $text, bool $bad = false): Response
    {
        $this->session->set('flash', [$text, $bad]);
        return Response::redirect('/');
    }

    private function googleCallback(Request $r): Response
    {
        if (!$this->signedIn()) {
            return Response::redirect('/');
        }
        $state = $this->session->get('oauth');
        $this->session->set('oauth', null);
        if (!is_string($state) || !hash_equals($state, (string) ($r->query['state'] ?? ''))) {
            return $this->flash('That sign-in did not start from this page. Press Connect Google again.', true);
        }
        if (($r->query['error'] ?? '') !== '' || ($r->query['code'] ?? '') === '') {
            return $this->flash('Google sign-in was not finished. Nothing was connected.', true);
        }
        try {
            $id = $this->google()->finishSignIn((string) $r->query['code'], $this->base($r) . '/google/callback');
        } catch (GoogleError $e) {
            return $this->flash($e->getMessage(), true);
        }
        $this->store()->log('info', 'Google was connected.');
        $reader = $this->reader();
        $reader->renewWatch($id);
        $reader->poll($id);
        return $this->flash('Google is connected. The helper has started reading the last 30 days, a little at a time.');
    }

    private function ownerPage(Request $r): Response
    {
        $store = $this->store();
        $flash = $this->session->get('flash');
        $code = $this->session->get('code');
        $this->session->set('flash', null);
        $this->session->set('code', null);
        $db = $store->db;
        return Response::html(Pages::owner([
            'csrf' => $this->session->formToken(),
            'flash' => is_array($flash) ? (string) $flash[0] : '',
            'flashBad' => is_array($flash) && $flash[1],
            'code' => is_string($code) ? $code : '',
            'now' => $this->now(),
            'base' => $this->base($r),
            'version' => VERSION,
            'accounts' => $this->reader()->accounts(),
            'hasClient' => $this->google()->hasClient(),
            'clientId' => $this->google()->clientId(),
            'topic' => (string) $store->get('google.topic', ''),
            'hookSecret' => (string) $store->get('hook.secret', ''),
            'devices' => $this->devices()->all(),
            'clockLast' => (int) $store->get('clock.last_run', '0'),
            'log' => $db->all('SELECT at, level, msg FROM {log} ORDER BY id DESC LIMIT 12'),
            'counts' => [
                'emails' => (int) $db->val('SELECT COUNT(*) FROM {emails}'),
                'people' => (int) $db->val('SELECT COUNT(*) FROM {emails} WHERE cls = ?', ['people']),
                'feeds' => (int) $db->val('SELECT COUNT(*) FROM {emails} WHERE cls = ?', ['feeds']),
                'senders' => (int) $db->val('SELECT COUNT(*) FROM {items} WHERE kind = ? AND deleted = 0', ['sender']),
            ],
        ]));
    }

    // ---- Google's notice -----------------------------------------------------------------------

    private function hook(Request $r): Response
    {
        $store = $this->store();
        $secret = (string) $store->get('hook.secret', '');
        if ($r->method !== 'POST' || $secret === '' || !hash_equals($secret, (string) ($r->query['k'] ?? ''))) {
            return new Response(404);
        }
        $data = base64_decode(strtr((string) ($r->json()['message']['data'] ?? ''), '-_', '+/'), true);
        $email = is_string($data) ? (string) (Store::decode($data)['emailAddress'] ?? '') : '';
        if ($email !== '') {
            // One reader at a time: the notice waits its turn behind the
            // every-minute look (a few seconds at most), so the same new email
            // is never filed twice at once. If the wait is too long, the
            // every-minute look picks the email up instead.
            $lock = @fopen($this->home . DIRECTORY_SEPARATOR . 'clock.lock', 'c');
            $mine = false;
            for ($i = 0; $lock !== false && $i < 16 && !($mine = flock($lock, LOCK_EX | LOCK_NB)); $i++) {
                usleep(500000);
            }
            try {
                if ($mine) {
                    $this->reader()->notice($email);
                }
            } catch (\Throwable $e) {
                // The every-minute look will catch up; Google is still told "received".
                $store->log('error', 'Acting on a notice failed: ' . mb_substr($e->getMessage(), 0, 200));
            } finally {
                if ($lock !== false) {
                    if ($mine) {
                        flock($lock, LOCK_UN);
                    }
                    fclose($lock);
                }
            }
        }
        return new Response(204);
    }

    // ---- devices ---------------------------------------------------------------------------------

    private function api(Request $r): Response
    {
        $devices = $this->devices();
        $store = $this->store();
        if ($r->path === '/api/ping') {
            return Response::json(['ok' => true, 'name' => 'Précis helper', 'version' => VERSION]);
        }
        if ($r->path === '/api/pair' && $r->method === 'POST') {
            $who = 'pair:' . $r->ip;
            if ($devices->blocked($who) || $devices->blocked('pair:all')) {
                return Response::error('Too many wrong codes. Wait fifteen minutes.', 429);
            }
            $j = $r->json() ?? [];
            $joined = $devices->join((string) ($j['code'] ?? ''), (string) ($j['name'] ?? ''), (string) ($j['kind'] ?? ''));
            if ($joined === null) {
                $devices->miss($who);
                $devices->miss('pair:all');
                return Response::error('That code is not right, or it is more than 10 minutes old.', 403);
            }
            $devices->clear($who);
            $store->log('info', 'A device joined.');
            return Response::json(['device' => $joined['id'], 'token' => $joined['token'], 'seq' => 0]);
        }
        $device = $devices->check($r->deviceToken());
        if ($device === null) {
            return Response::error('This device is not signed in to the helper.', 401);
        }
        $id = (int) $device['id'];
        $sync = new Sync($store, $this->sorter());
        switch ($r->method . ' ' . $r->path) {
            case 'GET /api/changes':
                return Response::json($store->since(max(0, (int) ($r->query['since'] ?? 0)), $id, min(1000, max(1, (int) ($r->query['limit'] ?? 500)))));
            case 'POST /api/push':
                $items = $r->json()['items'] ?? null;
                if (!is_array($items)) {
                    return Response::error('Nothing to apply.', 400);
                }
                return Response::json($sync->push($id, $items));
            case 'POST /api/seed':
                $j = $r->json() ?? [];
                return Response::json($sync->seed($id, is_array($j['senders'] ?? null) ? $j['senders'] : [], (int) ($j['at'] ?? $this->now()), is_array($j['myIds'] ?? null) ? $j['myIds'] : []));
            case 'GET /api/status':
                $accounts = [];
                foreach ($this->reader()->accounts() as $a) {
                    $accounts[] = [
                        'email' => (string) $a['email'],
                        'lastChecked' => (int) $a['last_checked'],
                        'firstReadDone' => (int) $a['backfill_done'] === 1,
                        'firstRead' => (int) $a['backfill_read'],
                        'notice' => (int) $a['watch_expires'] > $this->now(),
                        'error' => $a['last_error'],
                    ];
                }
                return Response::json([
                    'version' => VERSION,
                    'now' => $this->now(),
                    'seq' => $store->seq(),
                    'device' => $device,
                    'accounts' => $accounts,
                    'timer' => (int) $store->get('clock.last_run', '0'),
                    'emails' => (int) $store->db->val('SELECT COUNT(*) FROM {emails}'),
                ]);
            case 'GET /api/devices':
                return Response::json(['devices' => array_values(array_filter($devices->all(), static fn (array $d): bool => (int) $d['revoked'] === 0)), 'me' => $id]);
            case 'POST /api/devices/code':
                return Response::json(['code' => $devices->newCode(), 'minutes' => intdiv(Devices::CODE_LIFE, 60)]);
            case 'POST /api/devices/signout':
                $devices->signOut((int) (($r->json() ?? [])['id'] ?? $id));
                return Response::json(['ok' => true]);
            default:
                return Response::error('The helper does not know that address.', 404);
        }
    }
}
