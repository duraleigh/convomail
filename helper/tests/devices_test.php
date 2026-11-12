<?php
declare(strict_types=1);

namespace Precis\Tests;

use Precis\Alerts;
use Precis\Codes;
use Precis\Devices;
use Precis\Google;
use Precis\Push;
use Precis\Readings;
use Precis\Sending;

/** A service account file as Firebase gives it, with a throwaway key made for this run. */
$serviceAccount = static function (string $project = 'precis-alerts'): string {
    static $pem = null;
    if ($pem === null) {
        $cnf = __DIR__ . DIRECTORY_SEPARATOR . 'openssl.cnf';
        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA, 'config' => $cnf]);
        check($key !== false, 'a throwaway key could not be made');
        openssl_pkey_export($key, $pem, null, ['config' => $cnf]);
    }
    return (string) json_encode(['type' => 'service_account', 'project_id' => $project, 'private_key_id' => 'abc', 'private_key' => $pem, 'client_email' => "firebase-adminsdk@$project.iam.gserviceaccount.com", 'client_id' => '1']);
};

/** The app settings file Firebase gives for the Android app. */
$appFile = static fn (string $package = Push::APP, string $project = 'precis-alerts'): string => (string) json_encode([
    'project_info' => ['project_number' => '998877665544', 'project_id' => $project],
    'client' => [['client_info' => ['mobilesdk_app_id' => '1:998877665544:android:abcdef', 'android_client_info' => ['package_name' => $package]], 'api_key' => [['current_key' => 'AIza-test-key']]]],
]);

/** A phone and a PC joined to a store-level helper; returns their device ids. */
$joined = static function (World $w, string $kind, ?string $pushToken = null): int {
    $d = new Devices($w->store);
    $id = $d->join($d->newCode(), $kind === 'android' ? 'Phone' : 'PC', $kind)['id'];
    if ($pushToken !== null) {
        $d->setPush($id, $pushToken, null);
    }
    return $id;
};

/** A helper with alerts set up and one email that needs the owner. Returns [world, alerts, message id]. */
$ringing = static function (?string $due = null) use ($serviceAccount): array {
    $w = new World();
    $w->arrive(['From' => 'me@example.com', 'To' => 'renee@booking.example', 'Subject' => 'Hello'], ['SENT'], '', $w->clock->now - 86400);
    $w->store->db->run('UPDATE {emails} SET read_state = ? WHERE is_from_me = 1', [Readings::SKIPPED]);
    $w->readings->setZone(-300);
    $w->assistantOn();
    $push = new Push($w->store, $w->fake);
    same(null, $push->setKey($serviceAccount()));
    $alerts = new Alerts($w->store, $w->readings, $push);
    $w->later(60);
    $w->claude->answer = static fn (): array => ['line' => 'Renee needs a yes or no.', 'needs_owner' => true, 'ask' => 'Say yes or no to Charlotte.', 'due' => $due ?? '', 'place' => 'none', 'reasons' => ['It asks you a question.']];
    $mid = $w->arriveWith(['From' => 'Renee Calloway <renee@booking.example>', 'To' => 'me@example.com', 'Subject' => 'Re: Spring dates'], 'Yes or no?');
    $w->readings->plan();
    same(1, $w->readings->work());
    return [$w, $alerts, $mid];
};

return [
    'Google is asked for mail in full, calendar and contacts; an older sign-in that only reads is told apart' => function (): void {
        $w = new World(false);
        $w->fake->scope = 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.send';
        $w->google->setClient('1234567890-abcdefghijklmnop.apps.googleusercontent.com', 'the-secret');
        $account = $w->google->finishSignIn('good-code', 'https://helper.example/google/callback');
        // The helper's own reading still works on the older sign-in.
        check(!$w->google->grants($account, Google::MAIL) && !$w->google->grants($account, Google::CALENDAR));
        // Signing in again, with every box ticked.
        $w->fake->scope = null;
        $again = $w->google->finishSignIn('good-code', 'https://helper.example/google/callback');
        same($account, $again);
        check($w->google->grants($account, Google::MAIL) && $w->google->grants($account, Google::CALENDAR) && $w->google->grants($account, Google::CONTACTS));
    },

    'a joined device is handed a pass that lasts about an hour, never the lasting sign-in' => function (): void {
        $s = new Site();
        $phone = $s->join('Phone');
        same(409, $s->api('GET', '/api/google/token', null, $phone)->status);
        same(409, $s->api('GET', '/api/account', null, $phone)->status);
        $s->connectGoogle();
        $who = $s->api('GET', '/api/account', null, $phone)->data();
        same('me@example.com', $who['email']);
        same(['mail' => true, 'calendar' => true, 'contacts' => true], $who['grants']);
        $r = $s->api('GET', '/api/google/token', null, $phone);
        same(200, $r->status, $r->body);
        $pass = $r->data();
        same('me@example.com', $pass['email']);
        check(str_starts_with($pass['access'], 'access-') && $pass['expires'] - $pass['now'] >= 900);
        check(!str_contains($r->body, 'refresh-1') && !str_contains($r->body, 'the-secret'), 'the lasting sign-in left the helper');
        // The same pass is handed out again while it has time left; a new one once it runs low.
        same($pass['access'], $s->api('GET', '/api/google/token', null, $phone)->data()['access']);
        $pc = $s->join('PC');
        $s->clock->now += 3000;
        $s->fresh();
        $next = $s->api('GET', '/api/google/token', null, $phone)->data();
        check($next['access'] !== $pass['access'] && $next['expires'] - $next['now'] >= 900);
        // No token, no pass. A signed-out device gets nothing more.
        same(401, $s->api('GET', '/api/google/token')->status);
        $list = $s->api('GET', '/api/devices', null, $pc)->data();
        $other = array_values(array_filter($list['devices'], static fn (array $d): bool => (int) $d['id'] !== (int) $list['me']))[0];
        $s->api('POST', '/api/devices/signout', ['id' => $other['id']], $pc);
        same(401, $s->api('GET', '/api/google/token', null, $phone)->status);
        same(401, $s->api('GET', '/api/sending', null, $phone)->status);
    },

    'an older sign-in gives devices no pass, and the page asks for one more Allow' => function (): void {
        $s = new Site();
        $s->fake->scope = 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.send';
        $s->connectGoogle();
        $phone = $s->join('Phone');
        $r = $s->api('GET', '/api/google/token', null, $phone);
        same(409, $r->status);
        check(str_contains($r->body, 'Connect Google again'));
        same(false, $s->api('GET', '/api/status', null, $phone)->data()['grants']['mail']);
        check(str_contains($s->get('/')->body, 'One more Allow is needed'));
        $s->fake->scope = null;
        $s->connectGoogle();
        same(200, $s->api('GET', '/api/google/token', null, $phone)->status);
        check(str_contains($s->get('/')->body, 'Google allows everything devices need'));
    },

    'the addresses the owner sends from are kept locked and handed to every joined device' => function (): void {
        $s = new Site();
        $pc = $s->join('PC');
        $phone = $s->join('Phone');
        same(0, $s->api('GET', '/api/changes', null, $phone)->data()['sending']);
        $ca = ['email' => 'CA@clayaiken.example', 'name' => 'Clay', 'signature' => 'Clay', 'host' => 'smtp.forwardemail.example', 'port' => 465, 'security' => 'ssl', 'user' => 'ca@clayaiken.example', 'password' => 'app-pass-PLAIN-123', 'pics' => ['a.png' => base64_encode('picture')]];
        $r = $s->api('POST', '/api/sending', ['addresses' => [$ca, ['email' => 'me@example.com', 'name' => 'Clay Aiken']]], $pc);
        same(200, $r->status, $r->body);
        same(2, $r->data()['changed']);
        // Kept locked: the password is nowhere in the helper's notes as written.
        $raw = implode('|', array_map(static fn (array $row): string => (string) $row['v'], $s->app->store()->db->all('SELECT v FROM {vault}')));
        check(!str_contains($raw, 'app-pass-PLAIN-123') && !str_contains($raw, 'forwardemail'), 'an address is stored in the clear');
        // The other device hears there is something new, and gets all of it.
        same(1, $s->api('GET', '/api/changes', null, $phone)->data()['sending']);
        $got = $s->api('GET', '/api/sending', null, $phone)->data();
        same(1, $got['rev']);
        same(['ca@clayaiken.example', 'me@example.com'], array_column($got['addresses'], 'email'));
        same('app-pass-PLAIN-123', $got['addresses'][0]['password']);
        same(base64_encode('picture'), $got['addresses'][0]['pics']['a.png']);
        // Sending the same again changes nothing; one changed address moves the number on.
        same(0, $s->api('POST', '/api/sending', ['addresses' => [$ca]], $phone)->data()['changed']);
        same(1, $s->api('POST', '/api/sending', ['addresses' => [['signature' => 'Clay A.'] + $ca]], $phone)->data()['changed']);
        same(2, $s->api('GET', '/api/sending', null, $pc)->data()['rev']);
        // Removing one.
        same(1, $s->api('POST', '/api/sending', ['addresses' => [['email' => 'me@example.com', 'deleted' => true]]], $pc)->data()['changed']);
        same(['ca@clayaiken.example'], array_column($s->api('GET', '/api/sending', null, $pc)->data()['addresses'], 'email'));
        // Nonsense is refused; nobody without a token gets anything.
        same(400, $s->api('POST', '/api/sending', ['addresses' => [['name' => 'no email']]], $pc)->status);
        same(400, $s->api('POST', '/api/sending', ['addresses' => [['email' => 'big@x.example', 'pics' => ['x' => str_repeat('a', Sending::MAX_BYTES)]]]], $pc)->status);
        same(401, $s->api('GET', '/api/sending')->status);
        // The owner's page says how many are kept, never what they are, and can forget them.
        $page = $s->get('/')->body;
        check(str_contains($page, '1 address kept') && str_contains($page, '1 with the password'));
        check(!str_contains($page, 'app-pass-PLAIN-123') && !str_contains($page, 'forwardemail') && !str_contains($page, 'ca@clayaiken'), 'the page shows what is kept');
        $s->owner('/sending/forget');
        same([], $s->api('GET', '/api/sending', null, $pc)->data()['addresses']);
    },

    'alerts are set up with two files from Firebase, both kept locked' => function () use ($serviceAccount, $appFile): void {
        $s = new Site();
        $phone = $s->join('Phone', 'android');
        same(['ready' => false, 'app' => null], $s->api('GET', '/api/alerts', null, $phone)->data());
        $s->owner('/push/key', ['account' => 'not a file']);
        check(str_contains($s->get('/')->body, 'That is not a service account file'));
        $s->fake->refuseServiceAccount = true;
        $s->owner('/push/key', ['account' => $serviceAccount()]);
        check(str_contains($s->get('/')->body, 'Google did not accept that file'));
        $s->fake->refuseServiceAccount = false;
        $s->owner('/push/key', ['account' => $serviceAccount()]);
        $page = $s->get('/')->body;
        check(str_contains($page, 'Alerts are set up') && str_contains($page, 'precis-alerts'));
        check(!str_contains($page, 'BEGIN PRIVATE KEY') && !str_contains((string) $s->app->store()->get('push.account'), 'PRIVATE KEY'), 'the key is shown or stored in the clear');
        // The service account alone is not enough: the phone app needs its own settings.
        same(false, $s->api('GET', '/api/alerts', null, $phone)->data()['ready']);
        $s->owner('/push/app', ['app' => $appFile('com.someone.else')]);
        check(str_contains($s->get('/')->body, 'for a different app'));
        $s->owner('/push/app', ['app' => $appFile(Push::APP, 'another-project')]);
        check(str_contains($s->get('/')->body, 'different Firebase project'));
        $s->owner('/push/app', ['app' => $appFile()]);
        $ready = $s->api('GET', '/api/alerts', null, $phone)->data();
        same(true, $ready['ready']);
        same(['apiKey' => 'AIza-test-key', 'appId' => '1:998877665544:android:abcdef', 'projectId' => 'precis-alerts', 'senderId' => '998877665544'], $ready['app']);
        check(!str_contains($s->get('/')->body, 'AIza-test-key'), 'the page shows the app key');
        same(true, $s->api('GET', '/api/changes', null, $phone)->data()['alerts']);
        // The phone says where to reach it; a test alert goes there.
        same(200, $s->api('POST', '/api/devices/push', ['token' => 'phone-address-1'], $phone)->status);
        $s->owner('/push/test');
        same(1, count($s->fake->pushed));
        same('phone-address-1', $s->fake->pushed[0]['token']);
        same('test', $s->fake->pushed[0]['data']['t']);
        check(str_contains($s->get('/')->body, 'rings'));
        // "Do not ring on this device".
        $s->api('POST', '/api/devices/push', ['ring' => false], $phone);
        check(str_contains($s->get('/')->body, 'silent'));
        // Turning alerts off forgets both files.
        $s->owner('/push/forget');
        same(false, $s->api('GET', '/api/alerts', null, $phone)->data()['ready']);
        same(null, $s->app->store()->get('push.account'));
    },

    'an email that needs you rings each phone once, saying who and what they ask' => function () use ($ringing, $joined): void {
        [$w, $alerts, $mid] = $ringing();
        $joined($w, 'android', 'phone-1');
        $joined($w, 'android', 'phone-2');
        $joined($w, 'windows');
        same(2, $alerts->sweep());
        same(['phone-1', 'phone-2'], array_column($w->fake->pushed, 'token'));
        $d = $w->fake->pushed[0]['data'];
        same('focus', $d['t']);
        same('Renee Calloway', $d['who']);
        same('Say yes or no to Charlotte.', $d['ask']);
        same($mid, $d['mid']);
        same('1', $d['n']);
        same('0', $d['quiet']);
        check(!isset($d['subject']) && !str_contains(implode(' ', $d), 'Spring dates'), 'the subject is not what an alert says');
        // The timer looks again and again: nothing more is sent.
        $w->later(48);
        same(0, $alerts->sweep());
        same(0, $alerts->sweep());
        same(2, count($w->fake->pushed));
    },

    'one alert, not three: phones stay silent while Précis is open in front on a PC' => function () use ($ringing, $joined): void {
        [$w, $alerts] = $ringing();
        $joined($w, 'android', 'phone-1');
        $pc = $joined($w, 'windows');
        (new Devices($w->store))->inFront($pc);
        same(0, $alerts->sweep());
        same([], $w->fake->pushed);
        // It was seen on the PC: the phone does not ring for it later either.
        $w->later(600);
        same(0, $alerts->sweep());
    },

    'feed and noise never ring, and nothing from before alerts were set up rings' => function () use ($serviceAccount, $joined): void {
        $w = new World();
        $w->assistantOn();
        $w->claude->answer = static fn (string $email): array => str_contains($email, 'Old question')
            ? ['line' => 'An old question.', 'needs_owner' => true, 'ask' => 'Answer the old question.', 'due' => '', 'place' => 'none', 'reasons' => ['It asks you a question.']]
            : ['line' => 'A newsletter.', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'feed', 'reasons' => ['Nothing is asked of you.']];
        $w->arriveWith(['From' => 'Dana <dana@x.example>', 'To' => 'me@example.com', 'Subject' => 'Old question'], 'Old question: can you call me?');
        $w->readings->plan();
        $w->readings->work();
        same(1, count($w->readings->focusNow()));
        // Alerts are set up after that email was already waiting.
        $w->later(3600);
        $push = new Push($w->store, $w->fake);
        same(null, $push->setKey($serviceAccount()));
        $alerts = new Alerts($w->store, $w->readings, $push);
        $joined($w, 'android', 'phone-1');
        $w->later(60);
        $w->arriveWith(['From' => 'Pollstar Daily <news@pollstar.example>', 'To' => 'me@example.com', 'Subject' => 'Daily', 'List-Unsubscribe' => '<mailto:u@pollstar.example>'], 'Today in touring.');
        $w->readings->plan();
        $w->readings->work();
        same(0, $alerts->sweep());
        same([], $w->fake->pushed);
    },

    '"Good to know" and a new email from a person each ring as their own kind, once, only on a phone that has a channel for them, and never for mail that needs you' => function () use ($ringing, $joined): void {
        [$w, $alerts, $needs] = $ringing();
        $phone = $joined($w, 'android', 'phone-1');
        // A phone still on the older app would show these as "Needs you": it is sent none.
        $joined($w, 'android', 'phone-old');
        (new Devices($w->store))->setShowsKinds($phone, true);
        same(2, $alerts->sweep());
        $w->fake->pushed = [];
        $w->later(30);
        $w->claude->answer = static fn (string $email): array => match (true) {
            str_contains($email, 'Your order') => ['line' => 'Your hard case was delivered.', 'thing' => 'Hard case', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'feed', 'know' => true, 'reasons' => ['It arrived.']],
            str_contains($email, 'Lunch') => ['line' => 'Dana says Friday at 12:30 works.', 'thing' => 'Lunch', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'none', 'know' => false, 'reasons' => ['Nothing is asked of you.']],
            default => ['line' => 'A newsletter.', 'thing' => 'Newsletter', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'feed', 'know' => false, 'reasons' => ['Nothing is asked of you.']],
        };
        $order = $w->arriveWith(['From' => 'Shop <orders@shop.example>', 'To' => 'me@example.com', 'Subject' => 'Your order', 'List-Unsubscribe' => '<mailto:u@shop.example>'], 'Your order was delivered.');
        $lunch = $w->arriveWith(['From' => 'Renee Calloway <renee@booking.example>', 'To' => 'me@example.com', 'Subject' => 'Lunch'], 'Friday at 12:30 works.');
        $w->arriveWith(['From' => 'Pollstar Daily <news@pollstar.example>', 'To' => 'me@example.com', 'Subject' => 'Daily', 'List-Unsubscribe' => '<mailto:u@pollstar.example>'], 'Today in touring.');
        // Not read yet: nothing rings, so nothing can ring twice.
        $w->readings->plan();
        same(0, $alerts->sweep());
        $w->readings->work();
        same(2, $alerts->sweep());
        $byKind = [];
        foreach ($w->fake->pushed as $p) {
            same('phone-1', $p['token']);
            $byKind[$p['data']['t']] = $p['data'];
        }
        same(['chat', 'know'], (function (array $k): array { sort($k); return $k; })(array_keys($byKind)));
        same([$order, 'Shop', 'Your hard case was delivered.'], [$byKind['know']['mid'], $byKind['know']['who'], $byKind['know']['ask']]);
        same([$lunch, 'Renee Calloway', 'Dana says Friday at 12:30 works.'], [$byKind['chat']['mid'], $byKind['chat']['who'], $byKind['chat']['ask']]);
        check(!in_array($needs, array_column(array_column($w->fake->pushed, 'data'), 'mid'), true), 'what needs you rang as "Needs you" and not again');
        // The timer looks again: nothing more.
        $w->later(60);
        same(0, $alerts->sweep());
        // "Does not belong here" on a device: its alert comes off the phone.
        $w->sync->push(99, [['kind' => 'msgfix', 'k' => $order, 'data' => ['know' => false]]]);
        same(2, $alerts->sweep(), 'taken off every phone (one that never showed it loses nothing)');
        same(['t' => 'clear', 'id' => $byKind['know']['id']], array_intersect_key($w->fake->pushed[2]['data'], ['t' => 1, 'id' => 1]));
    },

    'done on any device takes the alert off the phones; later brings it back when its time comes' => function () use ($ringing, $joined): void {
        [$w, $alerts, $mid] = $ringing();
        $joined($w, 'android', 'phone-1');
        same(1, $alerts->sweep());
        $number = $w->fake->pushed[0]['data']['id'];
        // Put off for two hours from the PC: the alert leaves the phone.
        $w->sync->push(99, [['kind' => 'msgfix', 'k' => $mid, 'data' => ['later' => $w->clock->now + 7200]]]);
        same(1, $alerts->sweep());
        same(['t' => 'clear', 'id' => $number, 'n' => '0'], $w->fake->pushed[1]['data']);
        same(0, $alerts->sweep());
        // Its time comes: it needs you again, and rings again.
        $w->later(7300);
        same(1, $alerts->sweep());
        same('focus', $w->fake->pushed[2]['data']['t']);
        // Done: gone from the phone, and it stays gone.
        $w->sync->push(99, [['kind' => 'done', 'k' => $mid, 'data' => ['at' => $w->clock->now]]]);
        same(1, $alerts->sweep());
        same('clear', $w->fake->pushed[3]['data']['t']);
        $w->later(86400);
        same(0, $alerts->sweep());
        same(4, count($w->fake->pushed));
    },

    'a sign-in code goes to the phones with the code itself, once, even with Précis open on the PC, and is taken away when it is no longer good' => function () use ($ringing, $joined): void {
        [$w, $alerts] = $ringing();
        $phone = $joined($w, 'android', 'phone-1');
        // A phone still on the older app: it cannot show a code, so it is sent none.
        $joined($w, 'android', 'phone-old');
        $pc = $joined($w, 'windows');
        (new Devices($w->store))->setShowsCodes($phone, true);
        same(2, $alerts->sweep());
        $w->fake->pushed = [$w->fake->pushed[0]];
        (new Devices($w->store))->inFront($pc);
        $w->later(30);
        $mid = $w->arrive(['From' => 'Acme Bank <no-reply@acme.example>', 'To' => 'me@example.com', 'Subject' => 'Your verification code'], ['INBOX', 'UNREAD'], 'Your verification code is 482913. It expires in 10 minutes.');
        // Mail that only looks a little like it does not ring.
        $w->arrive(['From' => 'Shop <deals@shop.example>', 'To' => 'me@example.com', 'Subject' => 'Use promo code SAVE20 today'], ['INBOX', 'UNREAD'], 'Your discount code is SAVE20.');
        $w->arrive(['From' => 'Dana <dana@x.example>', 'To' => 'me@example.com', 'Subject' => 'Lunch'], ['INBOX', 'UNREAD'], 'See you at 1230 on Friday.');
        same(1, $alerts->sweep());
        same('phone-1', $w->fake->pushed[1]['token']);
        $d = $w->fake->pushed[1]['data'];
        same('code', $d['t']);
        same('482913', $d['code']);
        same('Acme Bank', $d['who']);
        same($mid, $d['mid']);
        check((int) $d['until'] > $w->clock->now && (int) $d['until'] <= $w->clock->now + Codes::LIFETIME);
        // The helper keeps no copy of the code.
        foreach ($w->store->db->all('SELECT k FROM {alerts}') as $row) {
            check(!str_contains((string) $row['k'], '482913'));
        }
        // The timer looks again: nothing more.
        $w->later(60);
        same(0, $alerts->sweep());
        // Fifteen minutes on, the code is no good: its alert is taken off the phone.
        $w->later(Codes::LIFETIME);
        $alerts->sweep();
        same(['t' => 'clear', 'id' => $d['id']], array_intersect_key($w->fake->pushed[2]['data'], ['t' => 1, 'id' => 1]));
        same(0, $alerts->sweep());
    },

    'what is and is not a sign-in code' => function (): void {
        same('482913', Codes::find('Your verification code', 'Your verification code is 482913.'));
        same('123456', Codes::find('123456 is your Facebook confirmation code', ''));
        same('G-481516', Codes::find('Your Google verification code', 'G-481516 is your Google verification code.'));
        same('739-204', Codes::find('Sign in to Slack', 'Your sign-in code: 739-204 Enter it to continue.'));
        same('4821', Codes::find('Your one-time passcode', 'Use 4821 to finish signing in.') ?? Codes::find('Your one-time passcode', '4821'));
        same('58KQ2M', Codes::find('Security code', 'Your security code is 58KQ2M'));
        same(null, Codes::find('Use promo code SAVE20', 'Your discount code is SAVE20.'));
        same(null, Codes::find('Your flight confirmation code', 'Confirmation code: QX7R2P for your trip.'));
        same(null, Codes::find('Lunch', 'See you at 1230 on Friday.'));
        same(null, Codes::find('Verification needed', 'Please verify your account by 2026.'));
        same(null, Codes::find('Dress code for the gala', 'The dress code is BLACK1.'));
    },

    'one notice an hour before a "by" time, even with Précis open on the PC' => function () use ($ringing, $joined): void {
        // The owner's clock is five hours behind; the venue wants an answer three hours from now.
        $clock = new Clock();
        $by = gmdate('Y-m-d\TH:i', $clock->now + 60 - 300 * 60 + 3 * 3600);
        [$w, $alerts] = $ringing($by);
        $joined($w, 'android', 'phone-1');
        $pc = $joined($w, 'windows');
        same(1, $alerts->sweep());
        same('focus', $w->fake->pushed[0]['data']['t']);
        check((int) $w->fake->pushed[0]['data']['by'] > $w->clock->now);
        $w->later(3600);
        same(0, $alerts->sweep(), 'two hours to go: not yet');
        $w->later(3700);
        (new Devices($w->store))->inFront($pc);
        same(1, $alerts->sweep());
        same('due', $w->fake->pushed[1]['data']['t']);
        same($w->fake->pushed[0]['data']['id'], $w->fake->pushed[1]['data']['id'], 'the notice replaces the first alert instead of stacking');
        same(0, $alerts->sweep());
    },

    'a reminder rings at its time; quiet hours make alerts silent; a phone set not to ring is left alone' => function () use ($serviceAccount, $joined): void {
        $w = new World();
        $w->readings->setZone(-300);
        $push = new Push($w->store, $w->fake);
        same(null, $push->setKey($serviceAccount()));
        $alerts = new Alerts($w->store, $w->readings, $push);
        $loud = $joined($w, 'android', 'phone-loud');
        $muted = $joined($w, 'android', 'phone-muted');
        (new Devices($w->store))->setPush($muted, null, false);
        $w->later(60);
        $w->sync->push($loud, [['kind' => 'reminder', 'k' => 'r1', 'data' => ['title' => 'Call the venue', 'due' => $w->clock->now + 600, 'done' => false, 'fired' => null]]]);
        same(0, $alerts->sweep(), 'not its time yet');
        $w->sync->push($loud, [['kind' => 'reminder', 'k' => 'r1', 'data' => ['title' => 'Call the venue', 'due' => $w->clock->now, 'done' => false, 'fired' => $w->clock->now]]]);
        same(1, $alerts->sweep());
        same(['phone-loud'], array_column($w->fake->pushed, 'token'));
        same('reminder', $w->fake->pushed[0]['data']['t']);
        same('Call the venue', $w->fake->pushed[0]['data']['ask']);
        same('r1', $w->fake->pushed[0]['data']['uid']);
        // Done from the alert itself: every device hears it, the phone's own app too, and the alert is taken away.
        same(['applied' => 1, 'seq' => $w->store->seq() + 1], $w->sync->push($loud, [['op' => 'reminder-done', 'uid' => 'r1']]));
        same(true, $w->store->item('reminder', 'r1')['done']);
        check(in_array('r1', array_column($w->store->since(0, $loud)['items'], 'k'), true), 'the phone did not hear its own Done back');
        same(1, $alerts->sweep());
        same('clear', $w->fake->pushed[1]['data']['t']);
        // Quiet hours, in the owner's own time: the alert still arrives, marked silent.
        $local = intdiv(($w->clock->now - 300 * 60) % 86400, 60);
        $clock = static fn (int $m): string => sprintf('%02d:%02d', intdiv(($m + 1440) % 1440, 60), ($m + 1440) % 60);
        $w->sync->push($loud, [['kind' => 'pref', 'k' => 'quiet', 'data' => ['on' => true, 'from' => $clock($local - 30), 'to' => $clock($local + 30)]]]);
        check($alerts->quiet());
        $w->sync->push($loud, [['kind' => 'reminder', 'k' => 'r2', 'data' => ['title' => 'Send the rider', 'due' => $w->clock->now, 'done' => false, 'fired' => $w->clock->now]]]);
        same(1, $alerts->sweep());
        same('1', $w->fake->pushed[2]['data']['quiet']);
        $w->sync->push($loud, [['kind' => 'pref', 'k' => 'quiet', 'data' => ['on' => true, 'from' => $clock($local + 60), 'to' => $clock($local + 120)]]]);
        check(!$alerts->quiet());
    },

    'a phone that no longer has the app is forgotten, and a signed-out phone gets no more alerts' => function () use ($ringing, $joined): void {
        [$w, $alerts] = $ringing();
        $gone = $joined($w, 'android', 'phone-gone');
        $out = $joined($w, 'android', 'phone-out');
        $kept = $joined($w, 'android', 'phone-kept');
        $w->fake->gonePhones = ['phone-gone'];
        (new Devices($w->store))->signOut($out);
        same(1, $alerts->sweep());
        same(['phone-kept'], array_column($w->fake->pushed, 'token'));
        same(null, $w->store->db->val('SELECT push_token FROM {devices} WHERE id = ?', [$gone]));
        same(null, $w->store->db->val('SELECT push_token FROM {devices} WHERE id = ?', [$out]));
        same('phone-kept', $w->store->db->val('SELECT push_token FROM {devices} WHERE id = ?', [$kept]));
        // A phone's address for alerts belongs to one device row only.
        $new = $joined($w, 'android', 'phone-kept');
        same(null, $w->store->db->val('SELECT push_token FROM {devices} WHERE id = ?', [$kept]));
        same('phone-kept', $w->store->db->val('SELECT push_token FROM {devices} WHERE id = ?', [$new]));
    },

    'with alerts not set up, nothing is sent anywhere' => function () use ($joined): void {
        $w = new World();
        $joined($w, 'android', 'phone-1');
        $alerts = new Alerts($w->store, $w->readings, new Push($w->store, $w->fake));
        $before = count($w->fake->calls);
        same(0, $alerts->sweep());
        same(0, $alerts->test());
        same($before, count($w->fake->calls));
    },

    'a change made from an alert comes back to the phone that made it; settings and groups keep in step' => function (): void {
        $s = new Site();
        $pc = $s->join('PC');
        $phone = $s->join('Phone');
        $s->api('POST', '/api/push', ['items' => [['kind' => 'done', 'k' => '<m1@x>', 'data' => ['at' => 5]]], 'echo' => true], $phone);
        same(['<m1@x>'], array_column($s->api('GET', '/api/changes', null, $phone, ['since' => '0'])->data()['items'], 'k'));
        same(['<m1@x>'], array_column($s->api('GET', '/api/changes', null, $pc, ['since' => '0'])->data()['items'], 'k'));
        // Without it, a device does not hear its own change back.
        $s->api('POST', '/api/push', ['items' => [['kind' => 'pref', 'k' => 'quiet', 'data' => ['on' => true, 'from' => '22:00', 'to' => '07:00']], ['kind' => 'group', 'k' => 'g-1', 'data' => ['name' => 'The band']], ['kind' => 'gmember', 'k' => 'g-1|sam@x.example', 'data' => ['at' => 1]]]], $pc);
        same(['<m1@x>'], array_column($s->api('GET', '/api/changes', null, $pc, ['since' => '0'])->data()['items'], 'k'));
        same(['<m1@x>', 'quiet', 'g-1', 'g-1|sam@x.example'], array_column($s->api('GET', '/api/changes', null, $phone, ['since' => '0'])->data()['items'], 'k'));
        // A PC says when it is open in front of the owner.
        $s->api('GET', '/api/changes', null, $pc, [], '10.0.0.2', ['x-precis-front' => '1']);
        check((int) $s->app->store()->db->val("SELECT front_at FROM {devices} WHERE name = 'PC'") === $s->clock->now);
        same(0, (int) $s->app->store()->db->val("SELECT front_at FROM {devices} WHERE name = 'Phone'"));
    },
];
