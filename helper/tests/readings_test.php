<?php
declare(strict_types=1);

namespace Precis\Tests;

use Precis\AnthropicDoor;
use Precis\Body;
use Precis\Clock as Timer;
use Precis\EmailPile;
use Precis\Prices;
use Precis\Readings;

/** A person the owner writes with: the owner has written to them. */
$person = static function (World $w, string $address = 'renee@booking.example'): void {
    $w->arrive(['From' => 'me@example.com', 'To' => $address, 'Subject' => 'Hello'], ['SENT'], '', $w->clock->now - 86400);
};
$renee = ['From' => 'Renee Calloway <renee@booking.example>', 'To' => 'me@example.com', 'Subject' => 'Re: Spring dates'];
$news = static fn (int $n): array => ['From' => 'Pollstar Daily <news@pollstar.example>', 'To' => 'me@example.com', 'Subject' => "Daily #$n", 'List-Unsubscribe' => '<mailto:u@pollstar.example>', 'List-Id' => 'Daily <daily.pollstar.example>'];

return [
    'an email\'s words: plain text is used, and a designed email is turned into plain words' => function (): void {
        $enc = static fn (string $s): string => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
        $plain = ['payload' => ['mimeType' => 'multipart/alternative', 'parts' => [
            ['mimeType' => 'text/plain', 'filename' => '', 'body' => ['data' => $enc("Good news. Charlotte can do Saturday, March 14.\r\n\r\nYes or no?")]],
            ['mimeType' => 'text/html', 'filename' => '', 'body' => ['data' => $enc('<p>Good news.</p>')]],
        ]]];
        same("Good news. Charlotte can do Saturday, March 14.\n\nYes or no?", Body::text($plain));

        $html = ['payload' => ['mimeType' => 'text/html', 'filename' => '', 'body' => ['data' => $enc('<html><head><style>p{color:red}</style><title>x</title></head><body><p>Your order&nbsp;shipped.</p><div>Arrives <b>Thursday</b></div><script>track()</script></body></html>')]]];
        same("Your order shipped.\nArrives Thursday", Body::text($html));

        // An attachment that happens to be text is not the email's words.
        $att = ['payload' => ['mimeType' => 'multipart/mixed', 'parts' => [
            ['mimeType' => 'text/plain', 'filename' => '', 'body' => ['data' => $enc('See the notes attached. They cover everything we discussed on Monday.')]],
            ['mimeType' => 'text/plain', 'filename' => 'notes.txt', 'body' => ['data' => $enc('SECRET NOTES')]],
        ]]];
        check(!str_contains(Body::text($att), 'SECRET'));
    },

    'an email\'s words: hidden padding and long web addresses are dropped' => function (): void {
        $long = 'https://click.shop.example/track/' . str_repeat('a1b2', 40);
        $t = Body::tidy("Sale\u{200B}\u{200C}\u{034F} today \n\n\n\n See $long now. Short: https://shop.example/x");
        same("Sale today\n\nSee [link: click.shop.example] now. Short: https://shop.example/x", $t);
    },

    'only the new words are kept: the copied history under a reply is cut away' => function (): void {
        same('They will hold it until 3 today. Yes or no?', Body::newWords("They will hold it until 3 today. Yes or no?\n\nOn Fri, Nov 6, 2026 at 9:02 AM Clay <me@example.com> wrote:\n> Could we look at mid-March?\n> Thanks"));
        same('Sounds good.', Body::newWords("Sounds good.\n\nOn Friday, November 6, 2026 at 9:02 AM, Clay Aiken\n<me@example.com> wrote:\n\nCould we look at mid-March?"));
        same('Fine by me.', Body::newWords("Fine by me.\n\n-----Original Message-----\nFrom: Clay\nSent: Friday\nold words"));
        same('Agreed.', Body::newWords("Agreed.\n\nFrom: Clay Aiken <me@example.com>\nSent: Friday, November 6, 2026 9:02 AM\nTo: Renee\nSubject: dates\n\nold words"));
        same('Thanks!', Body::newWords("Thanks!\n\n> earlier line one\n> earlier line two\n"));
        // A forwarded email is the point of the email: it is kept.
        $fwd = "Can you look at this?\n\n---------- Forwarded message ---------\nFrom: Venue <v@venue.example>\nDate: Mon\n\nThe hold ends Friday.";
        same($fwd, Body::newWords($fwd));
        // A reply written wholly inside the quoted part has nothing above the cut.
        same("> Could we do noon?\nYes, noon works.", Body::newWords("> Could we do noon?\nYes, noon works."));
    },

    'a long email is cut to a fixed length, and says so' => function (): void {
        $cut = Body::clip(str_repeat('word ', 1000), 200);
        check(mb_strlen($cut) < 240);
        check(str_ends_with($cut, '[the rest is not shown]'));
        same('short', Body::clip('short', 200));
    },

    'Feed or Noise for one email: your word, then the kind of mail, then the assistant, then the sender\'s usual place' => function (): void {
        same(['pile' => 'noise', 'by' => 'you'], EmailPile::decide('noise', 'feed', 'Receipt', null, 'feed', 'feed'));
        same(['pile' => 'feed', 'by' => 'sender'], EmailPile::decide(null, 'feed', 'Promotion', 'promotions', 'noise', 'noise'));
        same(['pile' => 'feed', 'by' => 'kind'], EmailPile::decide(null, null, 'Receipt', 'promotions', 'noise', 'noise'));
        same(['pile' => 'noise', 'by' => 'kind'], EmailPile::decide(null, null, 'Promotion', null, 'feed', 'feed'));
        same(['pile' => 'noise', 'by' => 'kind'], EmailPile::decide(null, null, 'Newsletter', 'social', 'feed', 'feed'));
        same(['pile' => 'noise', 'by' => 'assistant'], EmailPile::decide(null, null, 'Newsletter', 'updates', 'noise', 'feed'));
        same(['pile' => 'feed', 'by' => 'assistant'], EmailPile::decide(null, null, 'Notification', null, 'feed', 'noise'));
        same(['pile' => 'noise', 'by' => 'usual'], EmailPile::decide(null, null, 'Newsletter', null, null, 'noise'));
        same(['pile' => 'feed', 'by' => 'usual'], EmailPile::decide(null, null, null, null, null, null));
    },

    'what waits for the assistant: inbox mail from people and unclear mail; never settled Noise, codes, archived or sent mail' => function () use ($person, $renee, $news): void {
        $w = new World();
        $person($w);
        $state = static fn (World $w, string $mid): int => (int) $w->store->db->val('SELECT read_state FROM {emails} WHERE message_id = ?', [$mid]);
        $ask = $w->arriveWith($renee, 'Yes or no?');
        $letter = $w->arriveWith($news(1), 'Five stories today.');
        $promo = $w->arriveWith(['From' => 'FlashDeals <deals@flash.example>', 'To' => 'me@example.com', 'Subject' => '70% off today', 'List-Unsubscribe' => '<mailto:u@flash.example>'], '70% off', null, ['INBOX', 'UNREAD', 'CATEGORY_PROMOTIONS']);
        $code = $w->arriveWith(['From' => 'Dropbox <no-reply@dropbox.example>', 'To' => 'me@example.com', 'Subject' => 'Your verification code is 482913', 'Auto-Submitted' => 'auto-generated'], 'Your verification code is 482913');
        $archived = $w->arriveWith($news(2), 'Old stories.', null, ['UNREAD']);
        $w->readings->plan();
        same(Readings::WAITING, $state($w, $ask), 'mail from a person waits to be read');
        same(Readings::WAITING, $state($w, $letter), 'a newsletter no fixed rule settles waits to be read');
        same(Readings::SKIPPED, $state($w, $promo), 'mail Gmail files as Promotions is never read');
        same('OTP', (string) ($w->sort($code)['cat'] ?? $w->sender('no-reply@dropbox.example')['cat']), 'the code email is tagged as a code');
        same(Readings::SKIPPED, $state($w, $code), 'a sign-in code is never sent anywhere');
        same(Readings::NEW, $state($w, $archived), 'mail that is not in the inbox is left alone');
        same('noise', $w->sort($promo)['pile']);
        same(0, (int) $w->store->db->val('SELECT COUNT(*) FROM {emails} WHERE is_from_me = 1 AND read_state = ?', [Readings::WAITING]));
        // Nothing has been sent anywhere: planning asks the assistant nothing.
        same([], $w->claude->requests);
    },

    'with no key, or switched off, nothing is ever sent to the assistant' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->arriveWith($renee, 'Yes or no?');
        $w->readings->plan();
        same(0, $w->readings->work());
        same([], $w->claude->requests);
        check($w->readings->setKey(FakeClaude::KEY));
        $w->readings->setModel('claude-opus-5-5');
        same(0, $w->readings->work(), 'a key alone does not turn it on');
        same([], $w->claude->readings());
        $w->readings->turn(true);
        same(1, $w->readings->work());
        $w->readings->turn(false);
        $w->arriveWith($renee, 'One more thing.');
        $w->readings->plan();
        same(0, $w->readings->work(), 'off means off');
        same(1, count($w->claude->readings()));
    },

    'a reading: the assistant is shown the new words only, and its answer reaches devices' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->readings->setZone(-300);
        $w->assistantOn();
        $w->claude->answer = static fn (): array => ['line' => 'Renee needs your yes or no on Charlotte, March 14.', 'needs_owner' => true, 'ask' => 'Say yes or no to Charlotte, March 14.', 'due' => '2026-11-10T15:00', 'place' => 'none', 'reasons' => ['It asks you for a yes or no.', 'The venue releases the date at 3:00 PM.']];
        $mid = $w->arriveWith($renee, "They will hold it until 3 today. Yes or no?\n\nOn Fri, Nov 6, 2026 at 9:02 AM Clay <me@example.com> wrote:\n> SECRET-OLD-WORDS could we look at mid-March?");
        $w->readings->plan();
        same(1, $w->readings->work());

        $sent = $w->claude->readings()[0];
        same(FakeClaude::KEY, $sent['key']);
        same('claude-opus-5-5', $sent['body']['model']);
        same('low', $sent['body']['output_config']['effort']);
        same('json_schema', $sent['body']['output_config']['format']['type']);
        same(['type' => 'ephemeral'], $sent['body']['system'][0]['cache_control']);
        check(!isset($sent['body']['thinking']) && !isset($sent['body']['temperature']), 'no settings the readers refuse');
        $shown = (string) $sent['body']['messages'][0]['content'];
        check(str_contains($shown, 'They will hold it until 3 today. Yes or no?'));
        check(!str_contains($shown, 'SECRET-OLD-WORDS'), 'the copied history is never shown');
        check(str_contains($shown, 'Kind: from a person the owner writes with'));
        check(str_contains($shown, 'The owner is: in To'));
        check(str_contains($shown, '(UTC-05:00)'));
        check(str_contains($shown, 'The owner has already answered this email: no'));

        $r = $w->reading($mid);
        same('Renee needs your yes or no on Charlotte, March 14.', $r['line']);
        same(true, $r['focus']);
        same('Say yes or no to Charlotte, March 14.', $r['ask']);
        // 3:00 PM where the owner is (five hours behind UTC) is 20:00 UTC.
        same(gmmktime(20, 0, 0, 11, 10, 2026), $r['due']);
        same(['It asks you for a yes or no.', 'The venue releases the date at 3:00 PM.'], $r['why']);
        same(false, $r['answered']);
        // The email's words are not kept anywhere.
        foreach (['readings', 'emails', 'items', 'log'] as $table) {
            foreach ($w->store->db->all("SELECT * FROM {{$table}}") as $row) {
                check(!str_contains((string) json_encode($row), 'They will hold it until 3'), "the email's words were kept in $table");
            }
        }
        // Read once: a second pass asks for nothing.
        same(0, $w->readings->work());
        same(1, count($w->claude->readings()));
    },

    'mail that is not from a person: only the first part is shown, and the assistant says Feed or Noise' => function () use ($news): void {
        $w = new World();
        $w->assistantOn('claude-haiku-5-5');
        $w->claude->answer = static fn (string $email): array => str_contains($email, 'Daily #1')
            ? ['line' => 'Five stories, one about spring theater tours.', 'needs_owner' => true, 'ask' => 'Read it', 'due' => '', 'place' => 'noise', 'reasons' => ['It is a general newsletter sent to a list.']]
            : ['line' => 'Your subscription renews Friday.', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'feed', 'reasons' => ['It is about your own account.']];
        $long = str_repeat('Story text. ', 400) . 'THE-VERY-END';
        $m1 = $w->arriveWith($news(1), $long);
        $m2 = $w->arriveWith($news(2), 'Your subscription renews Friday.');
        $w->readings->plan();
        same(2, $w->readings->work());
        $shown = (string) $w->claude->readings()[1]['body']['messages'][0]['content'];
        check(str_contains($shown, 'Text (the first part only):'));
        check(!str_contains($shown, 'THE-VERY-END'), 'only the first part is shown');
        check(str_contains($shown, 'Kind: not from a person'));
        // One sender, two emails, two places.
        same('noise', $w->sort($m1)['pile']);
        same('feed', $w->sort($m2)['pile']);
        // Something the assistant itself calls Noise never reaches Focus.
        same(false, $w->reading($m1)['focus']);
        same('', $w->reading($m1)['ask']);
        same('claude-haiku-5-5', $w->claude->readings()[0]['body']['model']);
    },

    'a fixed rule or your own choice is not overturned by the assistant' => function () use ($news): void {
        $w = new World();
        $w->assistantOn();
        $w->claude->answer = static fn (): array => ['line' => 'Order placed, $46.80.', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'noise', 'reasons' => ['It looked like advertising.']];
        $receipt = $w->arriveWith(['From' => 'Amazon <auto-confirm@amazon.example>', 'To' => 'me@example.com', 'Subject' => 'Your order receipt', 'Auto-Submitted' => 'auto-generated'], 'Order total $46.80. Thank you for your purchase. Receipt attached.');
        $w->readings->plan();
        $w->readings->work();
        same('Receipt', $w->sort($receipt)['cat'] ?? $w->sender('auto-confirm@amazon.example')['cat']);
        same('feed', $w->sort($receipt)['pile'], 'a receipt stays in Feed whatever the assistant says');
        same('Order placed, $46.80.', $w->reading($receipt)['line'], 'it still gets its line');

        // The owner sends a sender to Noise for good: its mail is no longer read at all.
        $m = $w->arriveWith($news(1), 'Stories.');
        $w->sync->push(1, [['kind' => 'sender', 'k' => 'news@pollstar.example', 'data' => ['cls' => 'feeds', 'src' => 'auto', 'pile' => 'noise']]]);
        same('noise', $w->sort($m)['pile']);
        $before = count($w->claude->readings());
        $w->readings->plan();
        $w->readings->work();
        same($before, count($w->claude->readings()), 'mail the owner sent to Noise is never read');
        // And one email moved by hand keeps its place.
        $w->sync->push(1, [['kind' => 'sender', 'k' => 'news@pollstar.example', 'data' => ['cls' => 'feeds', 'src' => 'auto', 'pile' => null]]]);
        $w->sync->push(1, [['kind' => 'msgfix', 'k' => $m, 'data' => ['pile' => 'feed']]]);
        same('feed', $w->sort($m)['pile']);
    },

    'an email you have answered no longer needs you' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        $w->claude->answer = static fn (): array => ['line' => 'Renee asks for a yes or no.', 'needs_owner' => true, 'ask' => 'Say yes or no.', 'due' => '', 'place' => 'none', 'reasons' => ['It asks you a question.']];
        $mid = $w->arriveWith($renee, 'Yes or no?');
        $w->readings->plan();
        $w->readings->work();
        same(true, $w->reading($mid)['focus']);
        same(false, $w->reading($mid)['answered']);
        same(1, $w->readings->status()['focus']);
        // The owner answers in the same thread.
        $w->later(600);
        $gid = (string) $w->store->db->val('SELECT gmail_id FROM {emails} WHERE message_id = ?', [$mid]);
        $reply = $w->fake->add(['From' => 'me@example.com', 'To' => 'renee@booking.example', 'Subject' => 'Re: Spring dates', 'In-Reply-To' => $mid], ['SENT']);
        $w->fake->messages[$reply]['threadId'] = $w->fake->messages[$gid]['threadId'];
        $w->reader->poll($w->account);
        $w->readings->plan();
        same(true, $w->reading($mid)['answered']);
        same(0, $w->readings->status()['focus']);
        // An email that arrives after the owner already answered is told so, and is never Focus.
        $late = $w->fake->add($renee + ['Message-ID' => '<late@x>'], ['INBOX'], '', $w->clock->now - 3600);
        $w->fake->messages[$late]['threadId'] = $w->fake->messages[$gid]['threadId'];
        $w->fake->setBody($late, 'Any news?');
        $w->reader->poll($w->account);
        $w->readings->plan();
        $w->readings->work();
        $shown = (string) $w->claude->readings()[1]['body']['messages'][0]['content'];
        check(str_contains($shown, 'The owner has already answered this email: yes'));
        same(false, $w->reading('<late@x>')['focus']);
    },

    'the meter counts what Anthropic reports, at the listed prices' => function () use ($person, $renee): void {
        same(4000 + 3000, Prices::micro('claude-opus-5-5', 1000, 150));
        same((int) ceil(1000 * 0.10 + 150 * 0.50), Prices::micro('claude-haiku-5-5', 1000, 150));
        same((int) ceil(100 * 2.0 + 150 * 10.0 + 800 * 0.10 + 50 * 2.5), Prices::micro('claude-sonnet-5-5', 100, 150, 800, 50));
        same('$1.23', Prices::dollars(1_230_000));
        same('$0.004', Prices::dollars(4_000));

        $w = new World();
        $person($w);
        $w->assistantOn();
        $w->claude->in = 200;
        $w->claude->out = 150;
        $w->claude->cacheRead = 700;
        $w->arriveWith($renee, 'One.');
        $w->arriveWith($renee, 'Two.');
        $w->readings->plan();
        same(2, $w->readings->work());
        $each = Prices::micro('claude-opus-5-5', 200, 150, 700, 0);
        same(2 * $each, $w->readings->monthSpend());
        $row = $w->store->db->one('SELECT calls, tin, tout, tcr FROM {spend}');
        same([2, 400, 300, 1400], [(int) $row['calls'], (int) $row['tin'], (int) $row['tout'], (int) $row['tcr']]);
        same(2 * $each, $w->readings->status()['today']);
    },

    'when the month\'s ceiling is reached the assistant pauses; raising it lets it go on' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        $each = Prices::micro('claude-opus-5-5', 900, 150);
        $w->readings->setCeiling($each + 1);
        for ($i = 0; $i < 4; $i++) {
            $w->arriveWith($renee, "Note $i");
        }
        $w->readings->plan();
        same(2, $w->readings->work(), 'it stops as soon as the ceiling is passed');
        same(0, $w->readings->work());
        same(2, count($w->claude->readings()));
        same('ceiling', $w->readings->status()['problemKind']);
        check(str_contains($w->readings->status()['problem'], 'ceiling'));
        same(2, $w->readings->status()['waiting']);
        $w->readings->setCeiling(10_000_000);
        same(2, $w->readings->work());
        same('', $w->readings->status()['problem']);
    },

    'a key Anthropic refuses is not kept; one that stops working pauses the assistant and says so' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        same(false, $w->readings->setKey('sk-ant-wrong'));
        same(false, $w->readings->hasKey());
        $w->assistantOn();
        // The key is kept sealed, never as it was typed.
        $stored = (string) $w->store->get('assistant.key');
        check($stored !== '' && !str_contains($stored, FakeClaude::KEY));
        $w->arriveWith($renee, 'Hello?');
        $w->readings->plan();
        $w->claude->fail = [401, 'authentication_error', 'invalid x-api-key'];
        same(0, $w->readings->work());
        same('key', $w->readings->status()['problemKind']);
        same(0, $w->readings->work(), 'nothing more is sent until the key is replaced');
        same(1, count($w->claude->readings()));
        $w->claude->fail = null;
        check($w->readings->setKey(FakeClaude::KEY));
        same(1, $w->readings->work());
    },

    'no credit at Anthropic pauses the assistant; a busy moment is simply tried again' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        $w->arriveWith($renee, 'Hello?');
        $w->readings->plan();
        $w->claude->fail = [529, 'overloaded_error', 'Overloaded'];
        same(0, $w->readings->work());
        same('', $w->readings->status()['problem'], 'being busy is not a problem to report');
        same(1, $w->readings->status()['waiting']);
        $w->claude->fail = [400, 'invalid_request_error', 'Your credit balance is too low to access the Anthropic API.'];
        same(0, $w->readings->work());
        same('credit', $w->readings->status()['problemKind']);
        $w->claude->fail = null;
        same(0, $w->readings->work(), 'paused until the owner turns it back on');
        $w->readings->turn(true);
        same(1, $w->readings->work());
    },

    'a reading the assistant declines, or that comes back broken, is not shown' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        $mid = $w->arriveWith($renee, 'Hello?');
        $w->readings->plan();
        $w->claude->refuse = true;
        same(0, $w->readings->work());
        same(null, $w->reading($mid));
        same(Readings::GAVE_UP, (int) $w->store->db->val('SELECT read_state FROM {emails} WHERE message_id = ?', [$mid]));
        check($w->readings->monthSpend() > 0, 'a declined reading is still counted on the meter');
        // What it says is cleaned before it is kept.
        $r = Readings::normalize(['line' => "Two\nlines " . str_repeat('x', 400), 'needs_owner' => true, 'ask' => 'Do it', 'due' => 'next week', 'place' => 'feed', 'reasons' => ['a', '', 'b', 'c', 'd']], ['person' => true, 'answered' => false, 'zone' => 0]);
        check(mb_strlen($r['line']) <= 200 && !str_contains($r['line'], "\n"));
        same(null, $r['due'], 'a date it cannot state exactly is no date');
        same(['a', 'b', 'c'], $r['why']);
        same('', $r['place'], 'mail from a person has no Feed or Noise');
    },

    'the way out to the assistant opens to Anthropic\'s own address and nowhere else' => function (): void {
        $fake = new FakeClaude();
        $door = new AnthropicDoor($fake);
        $ok = $door->sendRequest(new \GuzzleHttp\Psr7\Request('GET', 'https://api.anthropic.com/v1/models/claude-haiku-5-5', ['x-api-key' => FakeClaude::KEY]));
        same(200, $ok->getStatusCode());
        foreach (['https://evil.example/v1/messages', 'http://api.anthropic.com/v1/messages', 'https://api.anthropic.com.evil.example/v1/messages', 'https://api.anthropic.com:8443/v1/messages'] as $url) {
            throws(static fn () => $door->sendRequest(new \GuzzleHttp\Psr7\Request('POST', $url)), "should refuse $url");
        }
        same(1, count($fake->requests));
    },

    'the every-minute timer queues and reads what is waiting' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        $id = $w->fake->add($renee);
        $w->fake->setBody($id, 'Yes or no?');
        $out = (new Timer($w->store, $w->reader, $w->readings))->run(20);
        same(1, $out['queued']);
        same(1, $out['read']);
        same(1, $w->readings->status()['read']);
    },

    'emails held from before are marked as in the inbox once, from Google\'s own list' => function () use ($renee): void {
        $w = new World();
        $in = $w->arrive($renee);
        $out = $w->arrive($renee + ['Message-ID' => '<archived@x>'], ['UNREAD']);
        $w->store->db->run('UPDATE {emails} SET inbox = 0');
        check($w->reader->markInbox($w->account));
        // The stand-in mailbox lists everything recent; what matters is that it runs once.
        same(false, $w->reader->markInbox($w->account));
        check((int) $w->store->db->val('SELECT inbox FROM {emails} WHERE message_id = ?', [$in]) === 1);
    },

    'the owner\'s page: the key is saved there, checked first, and never shown again' => function (): void {
        $s = new Site();
        $s->connectGoogle();
        check(str_contains($s->get('/')->body, 'No key yet'));
        $s->owner('/assistant/key', ['key' => 'sk-ant-wrong']);
        check(str_contains($s->get('/')->body, 'did not accept that key'));
        $s->owner('/assistant/key', ['key' => FakeClaude::KEY]);
        $page = $s->get('/')->body;
        check(str_contains($page, 'The key works and is saved'));
        check(!str_contains($page, FakeClaude::KEY), 'the key is never printed on the page');
        $s->owner('/assistant/switch', ['on' => '1']);
        check(str_contains($s->get('/')->body, 'Choose a reader first'));
        $s->owner('/assistant/settings', ['model' => 'claude-sonnet-5-5', 'ceiling' => '$12.50']);
        $s->owner('/assistant/switch', ['on' => '1']);
        $page = $s->get('/')->body;
        check(str_contains($page, 'Reading with Claude Sonnet 5.5'));
        check(str_contains($page, 'of a $12.50 ceiling'));
        $s->owner('/assistant/settings', ['model' => 'not-a-reader']);
        check(str_contains($s->get('/')->body, 'does not know that reader'));
        $s->owner('/assistant/forget');
        check(str_contains($s->get('/')->body, 'No key yet'));
        // Without the form token nothing changes.
        same(400, $s->post('/assistant/key', ['key' => FakeClaude::KEY])->status);
    },

    'a device sees how the assistant is doing, can switch it off and on, and says what time it is there' => function (): void {
        $s = new Site();
        $s->connectGoogle();
        $token = $s->join();
        $a = $s->api('GET', '/api/status', null, $token)->data()['assistant'];
        same([false, false, ''], [$a['hasKey'], $a['on'], $a['model']]);
        same(409, $s->api('POST', '/api/assistant', ['on' => true], $token)->status, 'no key: a device cannot turn it on');
        $s->owner('/assistant/key', ['key' => FakeClaude::KEY]);
        $s->owner('/assistant/settings', ['model' => 'claude-haiku-5-5']);
        $r = $s->api('POST', '/api/assistant', ['on' => true, 'ceiling' => 5_000_000], $token);
        same(200, $r->status, $r->body);
        same([true, 'claude-haiku-5-5', 5_000_000], [$r->data()['assistant']['on'], $r->data()['assistant']['model'], $r->data()['assistant']['ceiling']]);
        same(false, $s->api('POST', '/api/assistant', ['on' => false], $token)->data()['assistant']['on']);
        same(401, $s->api('POST', '/api/assistant', ['on' => true], 'not-a-token')->status);
        // No device call ever carries the key back.
        check(!str_contains($s->api('GET', '/api/status', null, $token)->body, FakeClaude::KEY));
        $s->api('GET', '/api/changes', null, $token, ['since' => '0'], '10.0.0.2', ['x-precis-zone' => '-300']);
        same(-300, $s->app->readings()->zone());
        $s->api('GET', '/api/changes', null, $token, ['since' => '0'], '10.0.0.2', ['x-precis-zone' => '99999']);
        same(-300, $s->app->readings()->zone());
    },
];
