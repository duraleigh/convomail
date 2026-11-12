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
        private readonly ?\Closure $assistant = null,
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

    public function readings(): Readings
    {
        return new Readings($this->store(), $this->google(), $this->sorter(), $this->assistant);
    }

    public function sending(): Sending
    {
        return new Sending($this->store());
    }

    public function push(): Push
    {
        return new Push($this->store(), $this->http);
    }

    public function alerts(): Alerts
    {
        return new Alerts($this->store(), $this->readings(), $this->push());
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
            case '/assistant/key':
                $key = trim((string) ($r->form['key'] ?? ''));
                if ($key === '') {
                    return $this->flash('Paste the key first.', true);
                }
                try {
                    $kept = $this->readings()->setKey($key);
                } catch (AssistantError $e) {
                    return $this->flash($e->getMessage() . ' The key was not saved. Try again in a minute.', true);
                }
                return $kept
                    ? $this->flash('The key works and is saved, locked. Nothing has been read with it yet.')
                    : $this->flash('Anthropic did not accept that key. Copy it again from Anthropic’s page, whole, and paste it here.', true);
            case '/assistant/forget':
                $this->readings()->forgetKey();
                return $this->flash('The key is removed from the helper. The assistant is off.');
            case '/assistant/switch':
                $readings = $this->readings();
                $on = (string) ($r->form['on'] ?? '') === '1';
                if ($on && (!$readings->hasKey() || !Prices::known($readings->model()))) {
                    return $this->flash($readings->hasKey() ? 'Choose a reader first.' : 'Save a key first.', true);
                }
                $readings->turn($on);
                return $this->flash($on ? 'The assistant is on.' : 'The assistant is off. Nothing more is sent to it. Mail keeps being sorted by the fixed rules.');
            case '/assistant/settings':
                $readings = $this->readings();
                $model = (string) ($r->form['model'] ?? '');
                if ($model !== '') {
                    if (!Prices::known($model)) {
                        return $this->flash('The helper does not know that reader.', true);
                    }
                    $readings->setModel($model);
                }
                $ceiling = str_replace(['$', ',', ' '], '', (string) ($r->form['ceiling'] ?? ''));
                if ($ceiling !== '') {
                    if (!is_numeric($ceiling) || (float) $ceiling < 0 || (float) $ceiling > 10000) {
                        return $this->flash('The ceiling is a number of dollars a month, such as 10.', true);
                    }
                    $readings->setCeiling((int) round((float) $ceiling * 1_000_000));
                }
                return $this->flash('Saved.');
            case '/push/key':
                $problem = $this->push()->setKey((string) ($r->form['account'] ?? ''));
                return $problem === null
                    ? $this->flash('Alerts are set up. A phone gets them once Précis is installed on it and has joined.')
                    : $this->flash($problem, true);
            case '/push/app':
                $problem = $this->push()->setApp((string) ($r->form['app'] ?? ''));
                return $problem === null ? $this->flash('Saved. A phone signs up for alerts the next time Précis opens on it.') : $this->flash($problem, true);
            case '/sending/forget':
                $this->sending()->forget();
                return $this->flash('Forgotten. Each device keeps its own copy; a new device will not get them until a device sends them up again.');
            case '/push/forget':
                $this->push()->forgetKey();
                return $this->flash('Alerts to phones are off. The file was removed from the helper.');
            case '/push/test':
                $n = $this->alerts()->test();
                return $this->flash($n > 0 ? "A test alert went to $n phone" . ($n === 1 ? '' : 's') . '.' : 'No phone could be reached. A phone gets alerts once Précis is open on it and has joined.', $n === 0);
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

    /**
     * What Google has allowed the helper for the connected mailbox.
     *
     * @return array{mail: bool, calendar: bool, contacts: bool}
     */
    private function grants(): array
    {
        $a = $this->reader()->accounts()[0] ?? null;
        $google = $this->google();
        return [
            'mail' => $a !== null && $google->grants((int) $a['id'], Google::MAIL),
            'calendar' => $a !== null && $google->grants((int) $a['id'], Google::CALENDAR),
            'contacts' => $a !== null && $google->grants((int) $a['id'], Google::CONTACTS),
        ];
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
            'assistant' => $this->readings()->status(),
            'readers' => Prices::MODELS,
            'push' => ['hasKey' => $this->push()->hasKey(), 'project' => $this->push()->project(), 'hasApp' => $this->push()->hasApp()],
            'sending' => ['count' => $this->sending()->count(), 'passwords' => $this->sending()->withPassword()],
            'grants' => $this->grants(),
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
        // A device says what time it is where the owner is, so "by 3:00 PM" means their 3:00 PM.
        // A PC says when Précis is open and in front of the owner, so phones stay quiet then.
        if (($r->headers['x-precis-front'] ?? '') === '1') {
            $devices->inFront($id);
        }
        $zone = $r->headers['x-precis-zone'] ?? null;
        if ($zone !== null && preg_match('~^-?\d{1,3}$~', $zone) === 1) {
            $this->readings()->setZone((int) $zone);
        }
        switch ($r->method . ' ' . $r->path) {
            case 'GET /api/changes':
                // With each pull a device also hears whether the assistant is
                // on, so its readings show or hide without a second call.
                $readings = $this->readings();
                return Response::json($store->since(max(0, (int) ($r->query['since'] ?? 0)), $id, min(1000, max(1, (int) ($r->query['limit'] ?? 500)))) + ['assistant' => $readings->on() && $readings->hasKey(), 'sending' => $this->sending()->rev(), 'alerts' => $this->push()->hasKey() && $this->push()->hasApp()]);
            case 'POST /api/push':
                $items = $r->json()['items'] ?? null;
                if (!is_array($items)) {
                    return Response::error('Nothing to apply.', 400);
                }
                $out = $sync->push($id, $items, ($r->json()['echo'] ?? false) === true);
                // "Not Focus" on one email changes its reading for every device.
                foreach ($items as $item) {
                    if (is_array($item) && ($item['kind'] ?? '') === 'msgfix' && is_string($item['k'] ?? null)) {
                        $this->readings()->fixed($item['k']);
                    }
                }
                return Response::json(['seq' => $store->seq()] + $out);
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
                    'assistant' => $this->readings()->status(),
                    'alerts' => $this->push()->hasKey(),
                    'grants' => $this->grants(),
                ]);
            case 'POST /api/assistant':
                // A device may turn the assistant off or on and set the ceiling.
                // The key itself is only ever entered on the owner's page.
                $j = $r->json() ?? [];
                $readings = $this->readings();
                if (array_key_exists('ceiling', $j) && is_int($j['ceiling']) && $j['ceiling'] >= 0 && $j['ceiling'] <= 10_000_000_000) {
                    $readings->setCeiling($j['ceiling']);
                }
                if (array_key_exists('on', $j) && is_bool($j['on'])) {
                    if ($j['on'] && (!$readings->hasKey() || !Prices::known($readings->model()))) {
                        return Response::error('The assistant has no key or reader yet. Set it on the helper’s page.', 409);
                    }
                    $readings->turn($j['on']);
                }
                return Response::json(['assistant' => $readings->status()]);
            case 'GET /api/account':
                // What a device that joined by code needs to set up the mailbox: whose it is.
                $a = $this->reader()->accounts()[0] ?? null;
                if ($a === null) {
                    return Response::error('No mailbox is connected to the helper yet.', 409);
                }
                $name = '';
                foreach ($store->itemsOf('me') as $address => $d) {
                    if ((string) $address === (string) $a['email'] || $name === '') {
                        $name = (string) ($d['name'] ?? $name);
                    }
                }
                return Response::json(['email' => (string) $a['email'], 'name' => $name, 'grants' => $this->grants(), 'sending' => $this->sending()->rev()]);
            case 'GET /api/sending':
                // The addresses the owner sends from, with what each needs to send.
                return Response::json(['addresses' => $this->sending()->all(), 'rev' => $this->sending()->rev()]);
            case 'POST /api/sending':
                $list = ($r->json() ?? [])['addresses'] ?? null;
                if (!is_array($list)) {
                    return Response::error('Nothing to keep.', 400);
                }
                try {
                    $n = $this->sending()->put(array_values($list));
                } catch (\InvalidArgumentException $e) {
                    return Response::error($e->getMessage(), 400);
                }
                return Response::json(['changed' => $n, 'rev' => $this->sending()->rev()]);
            case 'GET /api/alerts':
                // What a phone needs to sign up with Google's alert service, once the owner has set alerts up.
                $app = $this->push()->hasKey() ? $this->push()->app() : null;
                return Response::json(['ready' => $app !== null, 'app' => $app]);
            case 'GET /api/google/token':
                // A pass to the mailbox, good for about an hour, for a device that
                // joined by code. Never the lasting sign-in, which stays here.
                $a = $this->reader()->accounts()[0] ?? null;
                if ($a === null) {
                    return Response::error('No mailbox is connected to the helper yet.', 409);
                }
                if (!$this->google()->grants((int) $a['id'], Google::MAIL)) {
                    return Response::error('Google has not allowed this yet. Open the helper’s page and press Connect Google again.', 409);
                }
                try {
                    return Response::json($this->google()->devicePass((int) $a['id']) + ['now' => $this->now()]);
                } catch (GoogleError $e) {
                    return Response::error($e->getMessage(), 409);
                }
            case 'POST /api/devices/push':
                $j = $r->json() ?? [];
                $devices->setPush($id, array_key_exists('token', $j) ? (string) ($j['token'] ?? '') : null, is_bool($j['ring'] ?? null) ? $j['ring'] : null);
                // A phone whose app can show a sign-in code says so.
                if (is_bool($j['kinds'] ?? null)) {
                    $devices->setShowsKinds($id, $j['kinds']);
                }
                if (is_bool($j['codes'] ?? null)) {
                    $devices->setShowsCodes($id, $j['codes']);
                }
                return Response::json(['ok' => true, 'alerts' => $this->push()->hasKey()]);
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
