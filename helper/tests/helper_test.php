<?php
declare(strict_types=1);

namespace Precis\Tests;

use Precis\Addr;
use Precis\Clock as Timer;
use Precis\Crypto;
use Precis\Devices;
use Precis\GoogleError;
use Precis\Sorter;
use Precis\Store;

$person = static fn (string $name, string $address): array => ['From' => "$name <$address>", 'To' => 'me@example.com', 'Subject' => 'Lunch on Friday'];
$brief = static fn (int $n): array => ['From' => 'The Daily Brief <hello@dailybrief.com>', 'To' => 'me@example.com', 'Subject' => "Daily Brief #$n", 'List-Unsubscribe' => '<mailto:u@dailybrief.com>', 'List-Id' => 'Brief <brief.dailybrief.com>'];

return [
    // ---- storage ------------------------------------------------------------------------------
    'an item is written once: the same contents again move nothing' => function (): void {
        $s = store();
        check($s->put('tag', 'Receipt', ['pos' => 1]));
        $seq = $s->seq();
        check(!$s->put('tag', 'Receipt', ['pos' => 1]), 'the same contents should not count as a change');
        same($seq, $s->seq());
        check($s->put('tag', 'Receipt', ['pos' => 2]));
        same(['pos' => 2], $s->item('tag', 'Receipt'));
    },

    'what changed since a point comes back in order, without the asker\'s own changes' => function (): void {
        $s = store();
        $s->put('tag', 'A', ['pos' => 1], 7);
        $s->put('tag', 'B', ['pos' => 2], 8);
        $s->put('done', '<m1@x>', ['at' => 5]);
        $all = $s->since(0, null);
        same(['A', 'B', '<m1@x>'], array_column($all['items'], 'k'));
        same(3, $all['next']);
        check(!$all['more']);
        $forSeven = $s->since(0, 7);
        same(['B', '<m1@x>'], array_column($forSeven['items'], 'k'), 'device 7 already has what it sent');
        same(3, $forSeven['next'], 'but its place in the stream still moves past it');
        same([], $s->since(3, 7)['items']);
        $page = $s->since(0, null, 2);
        check($page['more']);
        same(2, $page['next']);
    },

    'removing leaves a marker devices hear about; writing again brings it back' => function (): void {
        $s = store();
        $s->put('rule', 'r1', ['field' => 'sender', 'pattern' => 'a@x.com', 'bucket' => 'feeds']);
        check($s->remove('rule', 'r1'));
        check(!$s->remove('rule', 'r1'), 'already gone');
        same(null, $s->item('rule', 'r1'));
        $last = $s->since(0, null)['items'];
        same(true, end($last)['deleted']);
        check($s->put('rule', 'r1', ['field' => 'sender', 'pattern' => 'a@x.com', 'bucket' => 'feeds']), 'back again counts as a change');
        same([], array_filter($s->since(0, null)['items'], static fn (array $i): bool => $i['deleted']));
    },

    'a very long key is stored by its hash, the same way every time' => function (): void {
        $long = '<' . str_repeat('a', 600) . '@x>';
        same(45, strlen(Store::key($long)));
        $s = store();
        $s->put('done', $long, ['at' => 1]);
        same(['at' => 1], $s->item('done', $long));
    },

    'secrets are sealed: not readable in the table, not openable with another key, not if tampered with' => function (): void {
        $s = store();
        $s->setSecret('google.client_secret', 'hunter2-not-really');
        $raw = (string) $s->get('google.client_secret');
        check(!str_contains($raw, 'hunter2'), 'stored in the clear');
        same('hunter2-not-really', $s->getSecret('google.client_secret'));
        throws(static fn () => (new Crypto(str_repeat("\x09", 32)))->open($raw), 'another key opened it');
        $bytes = base64_decode(substr($raw, 3));
        $bytes[strlen($bytes) - 1] = $bytes[strlen($bytes) - 1] === 'x' ? 'y' : 'x';
        throws(static fn () => (new Crypto(str_repeat("\x07", 32)))->open('v1:' . base64_encode($bytes)), 'a changed value opened');
        check((new Crypto(str_repeat("\x07", 32)))->seal('a') !== (new Crypto(str_repeat("\x07", 32)))->seal('a'), 'the same text should seal differently each time');
    },

    // ---- devices ------------------------------------------------------------------------------
    'a device joins with a code, once, within ten minutes' => function (): void {
        $clock = new Clock();
        $d = new Devices(store($clock));
        $code = $d->newCode();
        same(8, strlen($code));
        same(null, $d->join('WRONG123', 'PC', 'windows'));
        $joined = $d->join(strtolower($code[0]) . substr($code, 1, 3) . '-' . substr($code, 4), 'Clay\'s PC', 'windows');
        check($joined !== null, 'the right code, typed in lower case with a dash, should work');
        same(null, $d->join($code, 'Second', 'windows'), 'a code works once');
        $old = $d->newCode();
        $clock->now += 601;
        same(null, $d->join($old, 'Late', 'android'), 'a code older than ten minutes is refused');
        same('Clay\'s PC', $d->check($joined['token'])['name']);
        same(null, $d->check($joined['id'] . '.' . str_repeat('x', 43)), 'a made-up token');
        same(null, $d->check('nonsense'));
        same(null, $d->check(null));
        $d->signOut($joined['id']);
        same(null, $d->check($joined['token']), 'signed out');
    },

    'the helper keeps only a token\'s hash' => function (): void {
        $s = store();
        $d = new Devices($s);
        $joined = $d->join($d->newCode(), 'PC', 'windows');
        $secret = explode('.', $joined['token'])[1];
        foreach ($s->db->all('SELECT * FROM {devices}') as $row) {
            check(!str_contains(implode('|', array_map('strval', $row)), $secret), 'the token itself is in the table');
        }
        same([], $s->db->all('SELECT * FROM {pair_codes} WHERE used = 0'));
    },

    'eight wrong guesses lock the door for fifteen minutes' => function (): void {
        $clock = new Clock();
        $d = new Devices(store($clock));
        for ($i = 0; $i < 7; $i++) {
            $d->miss('signin:1.2.3.4');
        }
        check(!$d->blocked('signin:1.2.3.4'));
        $d->miss('signin:1.2.3.4');
        check($d->blocked('signin:1.2.3.4'));
        check(!$d->blocked('signin:5.6.7.8'), 'someone else is not locked out');
        $clock->now += 901;
        check(!$d->blocked('signin:1.2.3.4'));
    },

    // ---- reading header lines ------------------------------------------------------------------
    'names and addresses are read out of header lines' => function (): void {
        same([['name' => 'Sarah Chen', 'address' => 'sarah@x.com']], Addr::parseList('Sarah Chen <Sarah@X.com>'));
        same([['name' => 'Chen, Sarah', 'address' => 'sarah@x.com'], ['name' => '', 'address' => 'tom@x.com']], Addr::parseList('"Chen, Sarah" <sarah@x.com>, tom@x.com'));
        same([['name' => 'José Núñez', 'address' => 'jose@x.com']], Addr::parseList('=?UTF-8?B?Sm9zw6kgTsO6w7Flego=?= <jose@x.com>'));
        same([['name' => '', 'address' => 'a@x.com'], ['name' => '', 'address' => 'b@x.com']], Addr::parseList('Team: a@x.com, b@x.com;'));
        same([], Addr::parseList('undisclosed-recipients:;'));
        same([], Addr::parseList(null));
        same([['name' => 'A "B" C', 'address' => 'abc@x.com']], Addr::parseList('"A \"B\" C" <abc@x.com>'));
    },

    // ---- reading the mailbox -----------------------------------------------------------------
    'new mail is read and sorted: a person to Chats, a mailer not' => function () use ($person, $brief): void {
        $w = new World();
        $lunch = $w->arrive($person('Sarah Chen', 'sarah@x.com'), snippet: 'Are you free?');
        $news = $w->arrive($brief(1));
        same('people', $w->sender('sarah@x.com')['cls']);
        same('No bulk signals', $w->sender('sarah@x.com')['reasons']);
        same('Sarah Chen', $w->sender('sarah@x.com')['name']);
        same(['cat' => null, 'cls' => 'people'], $w->sort($lunch));
        same('feeds', $w->sender('hello@dailybrief.com')['cls']);
        same('Newsletter', $w->sender('hello@dailybrief.com')['cat']);
        same('feeds', $w->sort($news)['cls']);
        same('noise', $w->sorter->pileOf('hello@dailybrief.com'), 'a newsletter nobody opens');
        same(null, $w->sorter->pileOf('sarah@x.com'), 'a person has no pile');
    },

    'only header facts are kept: no email body is ever asked for' => function () use ($person): void {
        $w = new World();
        $w->arrive($person('Sarah Chen', 'sarah@x.com'));
        foreach ($w->fake->calls as $call) {
            check(!str_contains($call, 'format=full') && !str_contains($call, 'format=raw') && !str_contains($call, '/attachments'), "asked for more than headers: $call");
        }
        $cols = array_keys($w->store->db->one('SELECT * FROM {emails} LIMIT 1') ?? []);
        check(!in_array('body', $cols, true) && !in_array('html', $cols, true));
    },

    'the helper picks up where it left off, and reads each email once' => function () use ($person): void {
        $w = new World();
        $w->arrive($person('Sarah Chen', 'sarah@x.com'));
        $before = count($w->fake->calls);
        same(0, $w->reader->poll($w->account), 'nothing new');
        check(count(array_filter(array_slice($w->fake->calls, $before), static fn (string $c): bool => str_contains($c, '/messages/'))) === 0, 'an email was fetched again');
        $w->fake->add($person('Tom Andersen', 'tom@x.com'));
        $w->fake->add($person('Tom Andersen', 'tom@x.com'));
        same(2, $w->reader->poll($w->account));
        same(3, (int) $w->store->db->val('SELECT COUNT(*) FROM {emails}'));
    },

    'when too long has passed for Google to list changes, the last days are read again' => function () use ($person): void {
        $w = new World();
        $w->arrive($person('Sarah Chen', 'sarah@x.com'));
        $w->fake->add($person('Tom Andersen', 'tom@x.com'));
        $w->fake->historyTooOld = true;
        $w->reader->poll($w->account);
        same('people', $w->sender('tom@x.com')['cls']);
        $w->fake->historyTooOld = false;
        $w->fake->add($person('Ann', 'ann@x.com'));
        same(1, $w->reader->poll($w->account), 'and it carries on from there');
    },

    'day one: the last 30 days are read a page at a time, newest first, older mail left alone' => function () use ($person): void {
        $w = new World();
        $now = $w->clock->now;
        for ($i = 0; $i < 230; $i++) {
            $w->fake->add($person("Person $i", "p$i@x.com"), at: $now - $i * 3600);
        }
        $w->fake->add($person('Long Ago', 'old@x.com'), at: $now - 45 * 86400);
        same(100, $w->reader->backfill($w->account));
        same(0, (int) $w->store->db->val('SELECT backfill_done FROM {accounts}'));
        check($w->sender('p0@x.com') !== null && $w->sender('p150@x.com') === null, 'newest first');
        same(100, $w->reader->backfill($w->account));
        same(30, $w->reader->backfill($w->account));
        same(1, (int) $w->store->db->val('SELECT backfill_done FROM {accounts}'));
        same(230, (int) $w->store->db->val('SELECT backfill_read FROM {accounts}'));
        same(0, $w->reader->backfill($w->account), 'finished');
        same(null, $w->sender('old@x.com'), 'older than 30 days is not read');
    },

    'a short-lived pass is renewed on its own; if Google ends the sign-in, the page says so' => function () use ($person): void {
        $w = new World();
        $w->arrive($person('Sarah Chen', 'sarah@x.com'));
        $given = $w->fake->tokensGiven;
        $w->later(3700);
        $w->arrive($person('Tom', 'tom@x.com'));
        same($given + 1, $w->fake->tokensGiven, 'one renewal');
        $w->later(3700);
        $w->fake->refuseRefresh = true;
        $w->fake->add($person('Ann', 'ann@x.com'));
        same(0, $w->reader->poll($w->account));
        check(str_contains((string) $w->store->db->val('SELECT last_error FROM {accounts}'), 'Connect Google again'), 'the owner is not told what to do');
        $e = throws(fn () => $w->google->accessToken($w->account));
        check($e instanceof GoogleError && $e->needsSignIn);
    },

    'the sign-in is kept sealed, and disconnecting gives it back and forgets the mailbox' => function () use ($person): void {
        $w = new World();
        $w->arrive($person('Sarah Chen', 'sarah@x.com'));
        $row = (string) $w->store->db->val('SELECT tokens FROM {accounts}');
        check(!str_contains($row, 'refresh-1') && str_starts_with($row, 'v1:'), 'the sign-in is stored in the clear');
        $w->google->disconnect($w->account);
        check(in_array('POST https://oauth2.googleapis.com/revoke', $w->fake->calls, true), 'the sign-in was not given back to Google');
        same(0, (int) $w->store->db->val('SELECT COUNT(*) FROM {accounts}'));
        same(0, (int) $w->store->db->val('SELECT COUNT(*) FROM {emails}'));
    },

    'a sign-in that does not allow reading mail is refused' => function (): void {
        $w = new World(false);
        $w->google->setClient('1234567890-abcdefghijklmnop.apps.googleusercontent.com', 'wrong');
        throws(fn () => $w->google->finishSignIn('good-code', 'https://helper.example/google/callback'));
        $w->google->setClient('1234567890-abcdefghijklmnop.apps.googleusercontent.com', 'the-secret');
        throws(fn () => $w->google->finishSignIn('bad-code', 'https://helper.example/google/callback'));
        same(0, (int) $w->store->db->val('SELECT COUNT(*) FROM {accounts}'));
        $url = $w->google->signInUrl('https://helper.example/google/callback', 'st8');
        // Mail in full (so a joined phone or second PC can do all the first PC does), calendar and contacts to read.
        check(str_contains($url, rawurlencode('https://mail.google.com/')) || str_contains($url, urlencode('https://mail.google.com/')), 'does not ask for mail');
        check(str_contains($url, 'calendar.readonly') && str_contains($url, 'contacts.readonly') && str_contains($url, 'access_type=offline') && str_contains($url, 'state=st8'));
        check(!str_contains($url, 'auth%2Fcalendar+') && !str_contains($url, 'auth%2Fcontacts+') && !str_contains($url, 'drive'), 'asks for more than it says');
    },

    'the instant notice is asked for when a topic is set, and asked again before it lapses' => function () use ($person): void {
        $w = new World();
        check(!$w->reader->renewWatch($w->account), 'no topic, no asking');
        $w->store->set('google.topic', 'projects/my-proj/topics/precis-mail');
        check($w->reader->renewWatch($w->account));
        same('projects/my-proj/topics/precis-mail', $w->fake->watchTopic);
        check(!$w->reader->renewWatch($w->account), 'not again the same minute');
        $w->later(86400 + 60);
        check($w->reader->renewWatch($w->account), 'a day later, again');
        same(2, $w->fake->watchCalls);
        $w->fake->add($person('Sarah Chen', 'sarah@x.com'));
        same(1, $w->reader->notice('ME@example.com'), 'a notice reads the mailbox at once');
        same(0, $w->reader->notice('someone-else@example.com'));
        $w->later(86400 * 2);
        $w->fake->refuseWatch = true;
        check(!$w->reader->renewWatch($w->account));
        check(str_contains((string) $w->store->db->val('SELECT last_error FROM {accounts}'), 'new-mail notice'));
    },

    // ---- sorting ------------------------------------------------------------------------------
    'drafts are passed over; trash and spam are kept out of the counts' => function () use ($person): void {
        $w = new World();
        $w->arrive($person('Sarah Chen', 'sarah@x.com'), ['DRAFT']);
        same(0, (int) $w->store->db->val('SELECT COUNT(*) FROM {emails}'));
        $w->arrive($person('Spam King', 'king@spam.biz'), ['SPAM']);
        same(1, (int) $w->store->db->val('SELECT gone FROM {emails}'));
    },

    'mail I sent makes the person I wrote to a person, and my own addresses are never senders' => function () use ($person): void {
        $w = new World();
        $w->fake->sendAs = [['email' => 'Clay@Studio.example', 'name' => 'Clay Example']];
        $w->arrive(['From' => 'Clay <clay@studio.example>', 'To' => 'New Person <new@x.com>, "Second, One" <second@x.com>', 'Cc' => 'me@example.com', 'Subject' => 'Hello'], ['SENT']);
        same('people', $w->sender('new@x.com')['cls']);
        same('You wrote to this person', $w->sender('new@x.com')['reasons']);
        same('people', $w->sender('second@x.com')['cls']);
        same(null, $w->sender('me'));
        same(null, $w->sender('clay@studio.example'));
        same(null, $w->sender('me@example.com'));
        same(1, (int) $w->store->db->val('SELECT is_from_me FROM {emails}'));
        check($w->store->item('me', 'clay@studio.example') !== null, 'the sending address read from Gmail is remembered');
    },

    'an answer to my own email shows in Chats even from a mailer, that one email only' => function (): void {
        $w = new World();
        $mine = $w->arrive(['From' => 'me@example.com', 'To' => 'help@shop.com', 'Subject' => 'Order problem'], ['SENT']);
        $auto = $w->arrive(['From' => 'Shop Orders <noreply@shop.com>', 'To' => 'me@example.com', 'Subject' => 'Your order has shipped']);
        $reply = $w->arrive(['From' => 'Shop Orders <noreply@shop.com>', 'To' => 'me@example.com', 'Subject' => 'Re: Order problem', 'In-Reply-To' => $mine]);
        same('feeds', $w->sender('noreply@shop.com')['cls']);
        same(['cat' => 'Delivery', 'cls' => 'feeds', 'pile' => 'feed'], $w->sort($auto));
        same(['cat' => null, 'cls' => 'people'], $w->sort($reply));
        same(null, $w->sort($mine), 'my own mail needs no verdict');
    },

    'an answer to mail sent before the helper began reading is still known to be an answer' => function (): void {
        $w = new World();
        $w->sorter->addMyIds(['<old-1@example.com>']);
        $reply = $w->arrive(['From' => 'Shop <noreply@shop.com>', 'To' => 'me@example.com', 'Subject' => 'Re: Question', 'In-Reply-To' => '<old-1@example.com>']);
        same('people', $w->sort($reply)['cls']);
    },

    '"Hi Clay," from a mailer is personal unless Gmail files it as bulk' => function (): void {
        $w = new World();
        $a = $w->arrive(['From' => 'Billing <billing@vendor.com>', 'To' => 'me@example.com', 'Subject' => 'About your account'], snippet: 'Hi Clay, I wanted to follow up');
        $b = $w->arrive(['From' => 'Billing <billing@vendor.com>', 'To' => 'me@example.com', 'Subject' => 'About your account'], ['INBOX', 'CATEGORY_UPDATES'], 'Hi Clay, your statement');
        same('feeds', $w->sender('billing@vendor.com')['cls']);
        same('people', $w->sort($a)['cls']);
        same('feeds', $w->sort($b)['cls']);
    },

    'Gmail\'s own filing decides a sender with no other signs' => function (): void {
        $w = new World();
        for ($i = 0; $i < 3; $i++) {
            $w->arrive(['From' => 'Mark at Vendorco <mark@vendorco.com>', 'To' => 'me@example.com', 'Subject' => 'New styles'], ['INBOX', 'CATEGORY_PROMOTIONS']);
        }
        $s = $w->sender('mark@vendorco.com');
        same('feeds', $s['cls']);
        same('Promotion', $s['cat']);
        check(str_starts_with($s['reasons'], 'Gmail files this sender under Promotions'));
        same('noise', $w->sorter->pileOf('mark@vendorco.com'));
        $w->arrive(['From' => 'Pat <pat@friend.org>', 'To' => 'me@example.com', 'Subject' => 'Hello'], ['INBOX', 'CATEGORY_PERSONAL']);
        same('Gmail files this sender under Primary', $w->sender('pat@friend.org')['reasons']);
    },

    'what a device knew before the helper started is added to what the helper reads after' => function () use ($brief): void {
        $w = new World();
        $at = $w->clock->now;
        // The device has seen 9 plain emails from this address, none bulk.
        $w->sync->seed(1, [[
            'k' => 'hello@dailybrief.com',
            'item' => ['cls' => 'people', 'src' => 'auto', 'cat' => null, 'pile' => null, 'counts' => false, 'reasons' => 'No bulk signals', 'name' => 'The Daily Brief'],
            'facts' => ['address' => 'hello@dailybrief.com', 'messagesReceived' => 9, 'messagesWithKnownSignals' => 9, 'messagesWithBulkHeaders' => 0, 'subjects' => ['Hello', 'Thanks'], 'providerCategories' => ['primary' => 9]],
        ]], $at);
        same('people', $w->sender('hello@dailybrief.com')['cls'], 'the device\'s answer stands until new mail arrives');
        // Mail from before the seed is not counted twice.
        $w->fake->add($brief(0), at: $at - 3600);
        $w->reader->backfill($w->account);
        $f = $w->sorter->facts('hello@dailybrief.com');
        same(9, $f['messagesReceived']);
        // One bulk email after: 1 of 10, still a person.
        $w->later(60);
        $w->arrive($brief(1));
        $f = $w->sorter->facts('hello@dailybrief.com');
        same([10, 1, 10], [$f['messagesReceived'], $f['messagesWithBulkHeaders'], $f['messagesWithKnownSignals']]);
        same('people', $w->sender('hello@dailybrief.com')['cls']);
        // Three bulk emails: enough.
        $w->later(60);
        $w->arrive($brief(2));
        $w->later(60);
        $w->arrive($brief(3));
        same('feeds', $w->sender('hello@dailybrief.com')['cls']);
        check(str_starts_with($w->sender('hello@dailybrief.com')['reasons'], 'Bulk-mail headers on 3 of 12 messages'), $w->sender('hello@dailybrief.com')['reasons']);
    },

    'a sender moved by hand stays moved, whatever arrives' => function () use ($brief): void {
        $w = new World();
        $w->arrive($brief(1));
        $row = $w->sender('hello@dailybrief.com');
        $w->sync->push(1, [['kind' => 'sender', 'k' => 'hello@dailybrief.com', 'data' => ['cls' => 'people', 'src' => 'override'] + $row]]);
        $s = $w->sender('hello@dailybrief.com');
        same(['people', 'override', 'Moved by you'], [$s['cls'], $s['src'], $s['reasons']]);
        $m = $w->arrive($brief(2));
        $w->arrive($brief(3));
        $w->arrive($brief(4));
        same(['people', 'override'], [$w->sender('hello@dailybrief.com')['cls'], $w->sender('hello@dailybrief.com')['src']]);
        same('people', $w->sort($m)['cls']);
        // Handing the choice back lets the rules decide again.
        $w->sync->push(1, [['kind' => 'sender', 'k' => 'hello@dailybrief.com', 'data' => ['src' => 'auto'] + $w->sender('hello@dailybrief.com')]]);
        same(['feeds', 'auto'], [$w->sender('hello@dailybrief.com')['cls'], $w->sender('hello@dailybrief.com')['src']]);
    },

    'a pile, a tag and a name a device set on a sender are kept through later sorting' => function () use ($brief): void {
        $w = new World();
        $w->arrive($brief(1));
        $w->sync->push(1, [['kind' => 'sender', 'k' => 'hello@dailybrief.com', 'data' => ['pile' => 'feed', 'cat' => 'Mine', 'label' => 'Brief', 'counts' => true] + $w->sender('hello@dailybrief.com')]]);
        $w->arrive($brief(2));
        $s = $w->sender('hello@dailybrief.com');
        same(['feed', 'Mine', 'Brief', true], [$s['pile'], $s['cat'], $s['label'], $s['counts']]);
        same('feed', $w->sorter->pileOf('hello@dailybrief.com'), 'the owner\'s pile wins');
    },

    'a rule from a device sorts mail already read and mail still to come' => function () use ($person): void {
        $w = new World();
        $m1 = $w->arrive($person('Sarah Chen', 'sarah@x.com'));
        same('people', $w->sender('sarah@x.com')['cls']);
        $w->sync->push(1, [['kind' => 'rule', 'k' => 'r-1', 'data' => ['uid' => 'r-1', 'field' => 'sender', 'pattern' => 'sarah@x.com', 'bucket' => 'feeds', 'category' => null, 'at' => 5]]]);
        $s = $w->sender('sarah@x.com');
        same(['feeds', 'rule', 'Mail from sarah@x.com → Feed or Noise'], [$s['cls'], $s['src'], $s['reasons']]);
        same('feeds', $w->sort($m1)['cls']);
        $w->sync->push(1, [['kind' => 'rule', 'k' => 'r-2', 'data' => ['uid' => 'r-2', 'field' => 'domain', 'pattern' => 'x.com', 'bucket' => 'feeds', 'category' => 'Receipt', 'at' => 6]]]);
        $w->arrive($person('Tom Andersen', 'tom@x.com'));
        same(['feeds', 'Receipt'], [$w->sender('tom@x.com')['cls'], $w->sender('tom@x.com')['cat']]);
        // Removing the rules hands both back.
        $w->sync->push(1, [['kind' => 'rule', 'k' => 'r-1', 'deleted' => true], ['kind' => 'rule', 'k' => 'r-2', 'deleted' => true]]);
        same('people', $w->sender('sarah@x.com')['cls']);
        same('people', $w->sender('tom@x.com')['cls']);
    },

    'what the owner set on one email wins over the rules for that email' => function () use ($brief): void {
        $w = new World();
        $m = $w->arrive($brief(1));
        $w->sync->push(1, [['kind' => 'msgfix', 'k' => $m, 'data' => ['cat' => 'Receipt']]]);
        same(['cat' => 'Receipt', 'cls' => 'feeds', 'pile' => 'feed'], $w->sort($m));
        $w->sync->push(1, [['kind' => 'msgfix', 'k' => $m, 'data' => ['cls' => 'people']]]);
        same(['cat' => null, 'cls' => 'people'], $w->sort($m));
        $w->arrive($brief(2));
        same('people', $w->sort($m)['cls'], 'still, after more mail from the sender');
    },

    'two addresses a device merged into one person are sorted as one' => function () use ($person): void {
        $w = new World();
        $w->arrive($person('Sarah Chen', 'sarah@x.com'));
        $w->sync->push(1, [['kind' => 'addr', 'k' => 'sarah.chen@work.com', 'data' => ['key' => 'sarah@x.com']]]);
        $m = $w->arrive($person('Sarah Chen', 'Sarah.Chen@work.com'));
        same(null, $w->sender('sarah.chen@work.com'), 'no second sender');
        same('people', $w->sort($m)['cls']);
        $f = $w->sorter->facts('sarah@x.com');
        $all = [$f['address'], ...$f['otherAddresses']];
        sort($all);
        same(['sarah.chen@work.com', 'sarah@x.com'], $all);
        same(2, $w->sorter->facts('sarah@x.com')['messagesReceived']);
    },

    'a person in the address book is a person even with bulk signs' => function () use ($brief): void {
        $w = new World();
        $w->arrive($brief(1));
        same('feeds', $w->sender('hello@dailybrief.com')['cls']);
        $w->sync->push(1, [['kind' => 'book', 'k' => 'hello@dailybrief.com', 'data' => ['in' => true]]]);
        same(['people', 'In your contacts'], [$w->sender('hello@dailybrief.com')['cls'], $w->sender('hello@dailybrief.com')['reasons']]);
        $w->sync->push(1, [['kind' => 'book', 'k' => 'hello@dailybrief.com', 'deleted' => true]]);
        same('feeds', $w->sender('hello@dailybrief.com')['cls']);
    },

    'Feed or Noise goes by what a sender mostly sends, and opened newsletters stay in Feed' => function () use ($brief): void {
        $w = new World();
        $ids = [];
        for ($i = 1; $i <= 3; $i++) {
            $ids[] = $w->fake->add($brief($i));
        }
        $w->reader->poll($w->account);
        same('noise', $w->sorter->pileOf('hello@dailybrief.com'));
        $w->fake->relabel($ids[0], ['INBOX']);
        $w->reader->poll($w->account);
        same('feed', $w->sorter->pileOf('hello@dailybrief.com'), 'one of three opened');
        $w->arrive(['From' => 'Shop <orders@shop.com>', 'To' => 'me@example.com', 'Subject' => 'Your receipt']);
        same('feed', $w->sorter->pileOf('orders@shop.com'));
    },

    // ---- what devices send ---------------------------------------------------------------------
    'a device may send only its own kinds of change' => function (): void {
        $w = new World();
        throws(fn () => $w->sync->push(1, [['kind' => 'sort', 'k' => '<m@x>', 'data' => ['cls' => 'people']]]), 'a device wrote a verdict');
        throws(fn () => $w->sync->push(1, [['kind' => 'nonsense', 'k' => 'a', 'data' => []]]));
        throws(fn () => $w->sync->push(1, [['kind' => 'tag', 'k' => '', 'data' => []]]));
        throws(fn () => $w->sync->push(1, [['kind' => 'tag', 'k' => 'A']]), 'no contents');
        throws(fn () => $w->sync->push(1, [['kind' => 'tag', 'k' => 'A', 'data' => ['x' => str_repeat('y', 70000)]]]), 'too large');
        throws(fn () => $w->sync->push(1, array_fill(0, 2001, ['kind' => 'tag', 'k' => 'A', 'data' => []])), 'too many');
        throws(fn () => $w->sync->push(1, [['op' => 'drop-everything']]));
        same(0, (int) $w->store->db->val('SELECT COUNT(*) FROM {items} WHERE kind = ?', ['tag']));
    },

    'done, later, reminders and tags pass from one device to the others' => function (): void {
        $w = new World();
        $before = $w->store->seq();
        $out = $w->sync->push(1, [
            ['kind' => 'done', 'k' => '<m1@x>', 'data' => ['at' => 100]],
            ['kind' => 'rowpref', 'k' => 'c:sarah@x.com', 'data' => ['snoozed' => 999, 'pinned' => false, 'muted' => false]],
            ['kind' => 'reminder', 'k' => 'rem-1', 'data' => ['title' => 'Call back', 'due' => 500, 'done' => false]],
            ['kind' => 'tag', 'k' => 'Mine', 'data' => ['pos' => 10]],
        ]);
        same(4, $out['applied']);
        same([], $w->store->since($before, 1)['items'], 'the sender does not get its own changes back');
        same(['done', 'rowpref', 'reminder', 'tag'], array_column($w->store->since($before, 2)['items'], 'kind'), 'another device gets all four');
        same(0, $w->sync->push(1, [['kind' => 'done', 'k' => '<m1@x>', 'data' => ['at' => 100]]])['applied'], 'sent twice, applied once');
        $w->sync->push(2, [['kind' => 'done', 'k' => '<m1@x>', 'deleted' => true]]);
        same(null, $w->store->item('done', '<m1@x>'));
        same(['<m1@x>'], array_column(array_filter($w->store->since($before, 1)['items'], static fn (array $i): bool => $i['deleted']), 'k'), 'the first device hears it was undone');
    },

    'renaming a tag renames it on senders, rules and emails; deleting clears it' => function () use ($brief): void {
        $w = new World();
        $m = $w->arrive($brief(1));
        $w->sync->push(1, [
            ['kind' => 'tag', 'k' => 'Newsletter', 'data' => ['pos' => 1]],
            ['kind' => 'rule', 'k' => 'r-1', 'data' => ['uid' => 'r-1', 'field' => 'subject', 'pattern' => 'digest', 'bucket' => null, 'category' => 'Newsletter', 'at' => 1]],
        ]);
        $w->sync->push(1, [['op' => 'rename-tag', 'from' => 'Newsletter', 'to' => 'Reading']]);
        same(null, $w->store->item('tag', 'Newsletter'));
        same(['pos' => 1], $w->store->item('tag', 'Reading'));
        same('Reading', $w->sender('hello@dailybrief.com')['cat']);
        same('Reading', $w->store->item('rule', 'r-1')['category']);
        $w->sync->push(1, [['op' => 'delete-tag', 'name' => 'Reading']]);
        same(null, $w->store->item('tag', 'Reading'));
        same(null, $w->sender('hello@dailybrief.com')['cat']);
        same(null, $w->store->item('rule', 'r-1'), 'a rule that only set that tag goes with it');
        check($m !== '');
    },

    'the first sending-up takes a device\'s answers as they are and decides nothing again' => function (): void {
        $w = new World();
        $senders = [];
        for ($i = 0; $i < 50; $i++) {
            // By the rules alone these would be mailers; the device says people.
            $senders[] = ['k' => "noreply$i@brand.com", 'item' => ['cls' => 'people', 'src' => 'auto', 'cat' => null, 'reasons' => 'No bulk signals'], 'facts' => ['address' => "noreply$i@brand.com", 'messagesReceived' => 4]];
        }
        $senders[] = ['k' => 'me', 'item' => ['cls' => 'people'], 'facts' => []];
        $out = $w->sync->seed(3, $senders, $w->clock->now, ['<a@x>', '<b@x>', '<a@x>']);
        same(50, $out['senders']);
        same('people', $w->sender('noreply7@brand.com')['cls']);
        same(null, $w->sender('me'));
        same(2, (int) $w->store->db->val('SELECT COUNT(*) FROM {my_ids}'));
        same([], $w->store->since(0, 3)['items'] === [] ? [] : array_filter($w->store->since(0, 3)['items'], static fn (array $i): bool => $i['kind'] === 'sender'), 'nothing comes back to the device that sent it');
    },

    'mail read before a device sent up its facts is sorted again once they arrive' => function (): void {
        $w = new World();
        // The helper reads one plain email from a mailer it knows nothing about: it looks like a person.
        $m = $w->arrive(['From' => 'Mark <mark@vendorco.com>', 'To' => 'me@example.com', 'Subject' => 'Checking in']);
        same('people', $w->sender('mark@vendorco.com')['cls']);
        same('people', $w->sort($m)['cls']);
        // The device knows better: 40 emails, all with bulk headers, Gmail files them as promotions.
        $w->later(60);
        $w->sync->seed(1, [[
            'k' => 'mark@vendorco.com',
            'item' => ['cls' => 'feeds', 'src' => 'auto', 'cat' => 'Promotion', 'pile' => null, 'counts' => false, 'reasons' => 'Gmail files this sender under Promotions', 'name' => 'Mark'],
            'facts' => ['address' => 'mark@vendorco.com', 'messagesReceived' => 40, 'messagesWithKnownSignals' => 40, 'messagesWithBulkHeaders' => 40, 'providerCategories' => ['promotions' => 40]],
        ]], $w->clock->now);
        same('feeds', $w->sender('mark@vendorco.com')['cls']);
        same('Promotion', $w->sender('mark@vendorco.com')['cat']);
        same('feeds', $w->sort($m)['cls'], 'the email read earlier follows');
        // And the other way: the device's own move stands.
        $m2 = $w->arrive(['From' => 'News <news@paper.com>', 'To' => 'me@example.com', 'Subject' => 'Top stories today', 'List-Unsubscribe' => '<mailto:u@paper.com>']);
        same('feeds', $w->sort($m2)['cls']);
        $w->later(60);
        $w->sync->seed(1, [['k' => 'news@paper.com', 'item' => ['cls' => 'people', 'src' => 'override', 'cat' => null, 'reasons' => 'Moved by you'], 'facts' => ['address' => 'news@paper.com', 'messagesReceived' => 9, 'messagesWithKnownSignals' => 9, 'messagesWithBulkHeaders' => 9]]], $w->clock->now);
        same(['people', 'override'], [$w->sender('news@paper.com')['cls'], $w->sender('news@paper.com')['src']]);
        same('people', $w->sort($m2)['cls']);
    },

    'older mail from a sender a device knew, but had no mail from, still gets its place' => function (): void {
        $w = new World();
        // The device knows this sender (it was on a Cc line, say) but holds no mail from it.
        $w->sync->seed(1, [['k' => 'quiet@x.com', 'item' => ['cls' => 'feeds', 'src' => 'auto', 'cat' => 'Receipt', 'reasons' => 'x'], 'facts' => ['address' => 'quiet@x.com', 'messagesReceived' => 0]]], $w->clock->now);
        // The helper then reads an email from it that is older than the sending-up.
        $id = $w->fake->add(['From' => 'Quiet <quiet@x.com>', 'To' => 'me@example.com', 'Subject' => 'Hello', 'Message-ID' => '<quiet-1@x.com>'], at: $w->clock->now - 86400);
        $w->reader->backfill($w->account);
        // No tag of its own: it shows under the sender's tag, as on the app.
        same(['cat' => null, 'cls' => 'feeds', 'pile' => 'feed'], $w->sort('<quiet-1@x.com>'));
        same(0, (int) $w->store->db->val("SELECT COUNT(*) FROM {emails} WHERE cls = ''"));
        same('feeds', $w->sender('quiet@x.com')['cls'], 'and the sender stays where the device had it');
        check($id !== '');
    },

    'my own mail is in Chats from the moment it is filed' => function (): void {
        $w = new World();
        $w->arrive(['From' => 'me@example.com', 'To' => 'sarah@x.com', 'Subject' => 'Hello'], ['SENT']);
        same('people', (string) $w->store->db->val('SELECT cls FROM {emails}'));
    },

    // ---- the timer ------------------------------------------------------------------------------
    'the timer reads new mail, fires due reminders once, and brings back rows whose time has come' => function () use ($person): void {
        $w = new World();
        $timer = new Timer($w->store, $w->reader);
        $w->sync->push(1, [
            ['kind' => 'reminder', 'k' => 'rem-1', 'data' => ['title' => 'Call back', 'due' => $w->clock->now + 120, 'done' => false]],
            ['kind' => 'reminder', 'k' => 'rem-2', 'data' => ['title' => 'Already done', 'due' => $w->clock->now - 5, 'done' => true]],
            ['kind' => 'rowpref', 'k' => 'c:sarah@x.com', 'data' => ['snoozed' => $w->clock->now + 60, 'pinned' => true, 'muted' => false]],
        ]);
        $w->fake->add($person('Sarah Chen', 'sarah@x.com'));
        $out = $timer->run();
        same([1, 0, 0], [$out['new'], $out['reminders'], $out['back']]);
        $w->later(61);
        same(1, $timer->run()['back']);
        $pref = $w->store->item('rowpref', 'c:sarah@x.com');
        same([null, true], [$pref['snoozed'], $pref['pinned']]);
        same($w->clock->now, $pref['resurfaced']);
        $w->later(60);
        same(1, $timer->run()['reminders']);
        same($w->clock->now, $w->store->item('reminder', 'rem-1')['fired']);
        same(0, $timer->run()['reminders'], 'once only');
        same((string) $w->clock->now, $w->store->get('clock.last_run'));
    },

    'only one timer runs at a time' => function (): void {
        $w = new World();
        $timer = new Timer($w->store, $w->reader);
        $file = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'precis-test-' . bin2hex(random_bytes(4)) . '.lock';
        $held = fopen($file, 'c');
        flock($held, LOCK_EX);
        same(['skipped' => 1], $timer->tick($file));
        flock($held, LOCK_UN);
        fclose($held);
        check(!isset($timer->tick($file)['skipped']));
        @unlink($file);
    },

    'the sorter reads rules oldest first, as the app does' => function () use ($person): void {
        $w = new World();
        $w->sync->push(1, [
            ['kind' => 'rule', 'k' => 'r-b', 'data' => ['uid' => 'r-b', 'field' => 'domain', 'pattern' => 'x.com', 'bucket' => 'people', 'category' => null, 'at' => 20]],
            ['kind' => 'rule', 'k' => 'r-a', 'data' => ['uid' => 'r-a', 'field' => 'sender', 'pattern' => 'noreply@x.com', 'bucket' => 'feeds', 'category' => null, 'at' => 10]],
        ]);
        $w->arrive($person('No Reply', 'noreply@x.com'));
        same('feeds', $w->sender('noreply@x.com')['cls'], 'the older rule is read first');
        check((new Sorter($w->store))->classifier() !== null);
    },
];
