<?php
declare(strict_types=1);

namespace Precis\Tests;

use Precis\AnthropicDoor;
use Precis\Body;
use Precis\Clock as Timer;
use Precis\EmailPile;
use Precis\Prices;
use Precis\Readings;

/**
 * A person the owner writes with: the owner has written to them. (That
 * setup email is set aside, so each check counts only the mail it is about.)
 */
$person = static function (World $w, string $address = 'renee@booking.example'): void {
    $w->arrive(['From' => 'me@example.com', 'To' => $address, 'Subject' => 'Hello'], ['SENT'], '', $w->clock->now - 86400);
    $w->store->db->run('UPDATE {emails} SET read_state = ? WHERE is_from_me = 1', [Readings::SKIPPED]);
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
        check(is_string($sent['body']['system']), 'one email on its own: the instructions are sent plainly, with no keep-ready charge');
        check(!isset($sent['body']['thinking']) && !isset($sent['body']['temperature']), 'no settings the readers refuse');
        $shown = (string) $sent['body']['messages'][0]['content'];
        check(str_contains($shown, 'They will hold it until 3 today. Yes or no?'));
        check(!str_contains($shown, 'Earlier in this thread'), 'an email on its own is shown on its own');
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
        $late = array_values(array_filter($w->claude->readings(), static fn (array $r): bool => str_contains((string) $r['body']['messages'][0]['content'], 'Any news?')));
        $shown = (string) $late[0]['body']['messages'][0]['content'];
        check(str_contains($shown, 'The owner has already answered this email: yes'));
        same(false, $w->reading('<late@x>')['focus']);
    },

    'your answer does what was asked: the email is done on every device; an answer that only asks back, or puts it off, is not called done' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        $w->claude->answer = static function (string $shown): array {
            if (str_contains($shown, 'Kind: sent by the owner')) {
                return str_contains($shown, 'Yes, March 14 works')
                    ? ['line' => 'You said yes to March 14.', 'asks' => false, 'ask' => '', 'settles' => true, 'reasons' => ['You gave the answer.']]
                    : ['line' => 'You asked Renee which room.', 'asks' => true, 'ask' => 'Which room.', 'settles' => str_contains($shown, 'no thread here'), 'reasons' => ['You asked a question back.']];
            }
            return ['line' => 'Renee asks for a yes or no.', 'thing' => 'Charlotte, March 14', 'needs_owner' => true, 'ask' => 'Say yes or no to March 14.', 'due' => '', 'place' => 'none', 'know' => true, 'reasons' => ['It asks you a question.']];
        };
        $answer = static function (World $w, string $to, string $words, string $mid): void {
            $gid = (string) $w->store->db->val('SELECT gmail_id FROM {emails} WHERE message_id = ?', [$to]);
            $reply = $w->fake->add(['From' => 'me@example.com', 'To' => 'renee@booking.example', 'Subject' => 'Re: Spring dates', 'In-Reply-To' => $to, 'Message-ID' => $mid], ['SENT']);
            $w->fake->messages[$reply]['threadId'] = $w->fake->messages[$gid]['threadId'];
            $w->fake->setBody($reply, $words);
            $w->reader->poll($w->account);
            $w->readings->plan();
            $w->readings->work();
        };
        $first = $w->arriveWith($renee + ['Message-ID' => '<first@x>'], 'Yes or no on March 14?');
        $second = $w->arriveWith(['From' => 'Renee Calloway <renee@booking.example>', 'To' => 'me@example.com', 'Subject' => 'Summer', 'Message-ID' => '<second@x>'], 'Yes or no on June 2?');
        $w->readings->plan();
        $w->readings->work();
        same(true, $w->reading($first)['focus']);
        same(false, $w->reading($first)['know'], 'what needs you is not also "good to know"');
        same('Charlotte, March 14', $w->reading($first)['thing']);

        // An answer that only asks back: it stops needing the owner, and is not done.
        $w->later(600);
        $answer($w, $second, 'Which room would it be in?', '<back@me>');
        same(true, $w->reading($second)['answered']);
        same(null, $w->store->item('done', $second), 'asking back does not finish it');
        $shown = (string) array_values(array_filter($w->claude->readings(), static fn (array $r): bool => str_contains((string) $r['body']['messages'][0]['content'], 'Which room would it be in?')))[0]['body']['messages'][0]['content'];
        check(str_contains($shown, 'This email answers one that asked the owner: Say yes or no to March 14.'), 'the assistant is told what was asked, in its own earlier words');

        // An answer that does what was asked: done, everywhere, as if Done had been pressed.
        $w->later(600);
        $answer($w, $first, 'Yes, March 14 works for us.', '<yes@me>');
        same(['at' => $w->clock->now], $w->store->item('done', $first));
        same(true, $w->reading($first)['answered']);
        same(0, $w->readings->status()['focus']);
        // A new email with nothing asked before it: "settles" from the assistant means nothing.
        $id = $w->fake->add(['From' => 'me@example.com', 'To' => 'renee@booking.example', 'Subject' => 'New', 'Message-ID' => '<new@me>'], ['SENT']);
        $w->fake->setBody($id, 'A question with no thread here?');
        $w->reader->poll($w->account);
        $w->readings->plan();
        $w->readings->work();
        same(0, (int) $w->store->db->val('SELECT r.settles FROM {readings} r JOIN {emails} e ON e.id = r.email_id WHERE e.message_id = ?', ['<new@me>']));
    },

    'good to know: an answer you were waiting for, named for what it is; The Lede is written only from what Today lists' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->readings->setZone(-300);
        $w->assistantOn();
        $day = new \Precis\Day($w->store, $w->readings);
        $w->claude->answer = static function (string $shown): array {
            if (str_contains($shown, 'Needs them (')) {
                return ['sentence' => 'Your hard case was delivered to the front door, and Renee sent the signed copy.'];
            }
            if (str_contains($shown, 'Kind: sent by the owner')) {
                return ['line' => 'You asked Renee for the signed copy.', 'asks' => true, 'ask' => 'The signed copy.', 'settles' => false, 'reasons' => ['You asked for a document.']];
            }
            if (str_contains($shown, 'Here is the signed copy')) {
                return ['line' => 'Renee sent the signed copy.', 'thing' => 'Signed contract', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'none', 'know' => true, 'reasons' => ['It is the answer you were waiting for.']];
            }
            if (str_contains($shown, 'out for delivery')) {
                return ['line' => 'Your hard case is out for delivery today.', 'thing' => 'Amazon hard case', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'feed', 'know' => true, 'reasons' => ['It arrives today.']];
            }
            if (str_contains($shown, 'was delivered')) {
                return ['line' => 'Your hard case was delivered and left at the front door.', 'thing' => 'Amazon hard case', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'feed', 'know' => true, 'reasons' => ['It has arrived.']];
            }
            return ['line' => 'A sale.', 'thing' => 'Sale', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'noise', 'know' => true, 'reasons' => ['It is a sale.']];
        };
        // The owner asks for something; the answer comes back in the same conversation.
        $id = $w->fake->add(['From' => 'me@example.com', 'To' => 'renee@booking.example', 'Subject' => 'The contract', 'Message-ID' => '<ask@me>'], ['SENT']);
        $w->fake->setBody($id, 'Can you send the signed copy?');
        $w->reader->poll($w->account);
        $w->readings->plan();
        $w->readings->work();
        $w->later(600);
        $got = $w->fake->add(['From' => 'Renee Calloway <renee@booking.example>', 'To' => 'me@example.com', 'Subject' => 'Re: The contract', 'In-Reply-To' => '<ask@me>', 'Message-ID' => '<got@x>'], ['INBOX', 'UNREAD']);
        $w->fake->messages[$got]['threadId'] = $w->fake->messages[$id]['threadId'];
        $w->fake->setBody($got, 'Here is the signed copy.');
        $shop = ['From' => 'Amazon.com <ship@amazon.example>', 'To' => 'me@example.com', 'List-Unsubscribe' => '<mailto:u@amazon.example>'];
        $w->arriveWith($shop + ['Subject' => 'Out for delivery', 'Message-ID' => '<out@x>'], 'Your package is out for delivery.');
        $w->later(600);
        $w->arriveWith($shop + ['Subject' => 'Delivered', 'Message-ID' => '<here@x>'], 'Your package was delivered. It was left at the front door.');
        $w->arriveWith(['From' => 'Shop <deals@shop.example>', 'To' => 'me@example.com', 'Subject' => 'Sale', 'Message-ID' => '<sale@x>', 'List-Unsubscribe' => '<mailto:u@shop.example>'], 'Everything is on sale.');
        $w->reader->poll($w->account);
        $w->readings->plan();
        $w->readings->work();

        $shown = (string) array_values(array_filter($w->claude->readings(), static fn (array $r): bool => str_contains((string) $r['body']['messages'][0]['content'], 'Here is the signed copy')))[0]['body']['messages'][0]['content'];
        check(str_contains($shown, 'The owner was waiting for this, from an email they sent: The signed copy.'));
        $r = $w->reading('<got@x>');
        same([true, 'Signed contract', false], [$r['know'], $r['thing'], $r['focus']]);
        same([true, 'Amazon hard case'], [$w->reading('<here@x>')['know'], $w->reading('<here@x>')['thing']]);
        same(false, $w->reading('<sale@x>')['know'] ?? false, 'Noise is never "good to know", whatever the assistant says');

        // The Lede is written from those lines only: each with its time, newest first.
        $w->later(1300);
        check($day->refresh());
        $all = $w->claude->readings();
        $shown = (string) $all[count($all) - 1]['body']['messages'][0]['content'];
        check(str_contains($shown, 'Good to know, came today, newest first (3):'));
        $delivered = strpos($shown, 'Your hard case was delivered and left at the front door.');
        $out = strpos($shown, 'Your hard case is out for delivery today.');
        check($delivered !== false && $out !== false && $delivered < $out, 'the latest word on the delivery comes first');
        check(str_contains($shown, 'Amazon.com (Amazon hard case):'), 'named for what it is');
        check(str_contains($shown, 'Renee Calloway (Signed contract): Renee sent the signed copy.'));
        check(!str_contains($shown, 'A sale.'));
        check(str_contains((string) json_encode($all[count($all) - 1]['body']['system']), 'Only the latest line about a thing is true now'));
        // Marked done on a device: it leaves the page, and so The Lede's lines.
        $w->sync->push(1, [['kind' => 'done', 'k' => '<got@x>', 'data' => ['at' => $w->clock->now]]]);
        same(2, count($day->lines()['feed']));
    },

    '"does not belong here": the item leaves every device, the assistant is shown what you turned down, and the same thing from the same sender stays off' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        $w->claude->answer = static function (string $shown): array {
            if (str_contains($shown, 'Kind: sent by the owner')) {
                return ['line' => 'You asked Renee about the room.', 'asks' => true, 'ask' => 'Which room.', 'settles' => false, 'reasons' => ['You asked a question.']];
            }
            return str_contains($shown, 'From: First Bank')
                ? ['line' => 'Your statement is ready.', 'thing' => 'Bank statement', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'feed', 'know' => true, 'reasons' => ['About your account.']]
                : ['line' => 'Renee asks for a yes or no.', 'thing' => 'Spring dates', 'needs_owner' => true, 'ask' => 'Say yes or no.', 'due' => '', 'place' => 'none', 'know' => false, 'reasons' => ['It asks you a question.']];
        };
        $bank = ['From' => 'First Bank <notice@bank.example>', 'To' => 'me@example.com', 'List-Unsubscribe' => '<mailto:u@bank.example>'];
        $a = $w->arriveWith($bank + ['Subject' => 'Statement', 'Message-ID' => '<s1@bank>'], 'Your statement is ready. WORDS-OF-THE-EMAIL');
        $b = $w->arriveWith($bank + ['Subject' => 'Statement again', 'Message-ID' => '<s0@bank>'], 'Your statement is ready.');
        $w->readings->plan();
        $w->readings->work();
        same([true, true], [$w->reading($a)['know'], $w->reading($b)['know']]);
        $day = new \Precis\Day($w->store, $w->readings);
        same(2, count($day->lines()['feed']));

        // Turned down on a device: gone for every device, and so is the same thing from the same sender.
        $w->sync->push(1, [['kind' => 'msgfix', 'k' => $a, 'data' => ['know' => false]]]);
        $w->readings->fixed($a);
        same([false, false], [$w->reading($a)['know'], $w->reading($b)['know']]);
        same(0, count($day->lines()['feed']), 'and The Lede no longer has it to speak of');

        // The next one from that sender: the assistant is shown what was turned down, in its own earlier words.
        $w->later(60);
        $c = $w->arriveWith($bank + ['Subject' => 'Statement 3', 'Message-ID' => '<s3@bank>'], 'Your statement is ready.');
        $w->readings->plan();
        $w->readings->work();
        $all = $w->claude->readings();
        $shown = (string) $all[count($all) - 1]['body']['messages'][0]['content'];
        check(str_contains($shown, 'What the owner has said about earlier reports (go by it):'));
        check(str_contains($shown, '- NOT worth knowing: from First Bank (Bank statement): Your statement is ready.'));
        check(strpos($shown, 'NOT worth knowing') < strpos($shown, 'Text (the first part only):'), 'before the email, which stays the last thing read');
        check(!str_contains($shown, 'WORDS-OF-THE-EMAIL'), 'never the turned-down email\'s own words');
        check(str_contains((string) json_encode($all[count($all) - 1]['body']['system']), 'They outrank your own view'));
        // The stand-in assistant still says "good to know": the owner's word holds all the same.
        same(false, $w->reading($c)['know']);

        // "This does not need me" is a lesson too, and mail from anyone is shown it.
        $mid = $w->arriveWith($renee + ['Message-ID' => '<yn@x>'], 'Yes or no?');
        $w->readings->plan();
        $w->readings->work();
        same(true, $w->reading($mid)['focus']);
        $w->sync->push(1, [['kind' => 'msgfix', 'k' => $mid, 'data' => ['focus' => false]]]);
        $w->readings->fixed($mid);
        same(false, $w->reading($mid)['focus']);
        $w->later(60);
        $w->arriveWith($bank + ['Subject' => 'Statement 4', 'Message-ID' => '<s4@bank>'], 'Your statement is ready.');
        $w->readings->plan();
        $w->readings->work();
        $all = $w->claude->readings();
        $shown = (string) $all[count($all) - 1]['body']['messages'][0]['content'];
        check(str_contains($shown, '- did NOT need them: from Renee Calloway (Spring dates): Renee asks for a yes or no.'));
        check(strpos($shown, 'First Bank (Bank statement)') < strpos($shown, 'Renee Calloway (Spring dates)'), 'what this same sender sent comes first');

        // "I am not waiting on this", said of an email the owner sent.
        $id = $w->fake->add(['From' => 'me@example.com', 'To' => 'renee@booking.example', 'Subject' => 'Room', 'Message-ID' => '<room@me>'], ['SENT']);
        $w->fake->setBody($id, 'Which room is it?');
        $w->reader->poll($w->account);
        $w->readings->plan();
        $w->readings->work();
        same(true, $w->reading('<room@me>')['asks']);
        $w->sync->push(1, [['kind' => 'msgfix', 'k' => '<room@me>', 'data' => ['asks' => false]]]);
        $w->readings->fixed('<room@me>');
        same(false, $w->reading('<room@me>')['asks']);
        $w->later(60);
        $id = $w->fake->add(['From' => 'me@example.com', 'To' => 'renee@booking.example', 'Subject' => 'Room 2', 'Message-ID' => '<room2@me>'], ['SENT']);
        $w->fake->setBody($id, 'Which room is it this time?');
        $w->reader->poll($w->account);
        $w->readings->plan();
        $w->readings->work();
        $all = $w->claude->readings();
        $shown = (string) $all[count($all) - 1]['body']['messages'][0]['content'];
        check(str_contains($shown, '- NOT something they wait on: You asked Renee about the room.'));
        check(!str_contains($shown, 'NOT worth knowing'), 'an email the owner sent is shown only what was said of sent mail');
    },

    'a deadline set earlier in a thread is found: the earlier emails are shown as background, new words only' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->readings->setZone(-300);
        $w->assistantOn();
        $thread = 'thread-spring';
        $add = static function (World $w, array $headers, string $words, array $labels, int $ago) use ($thread): string {
            $id = $w->fake->add($headers, $labels, '', $w->clock->now - $ago);
            $w->fake->messages[$id]['threadId'] = $thread;
            $w->fake->setBody($id, $words);
            return $id;
        };
        $add($w, $renee + ['Message-ID' => '<t1@x>'], "The venue needs an answer by Friday at noon.\n\nOn Mon Clay wrote:\n> OLD-QUOTED-WORDS", ['INBOX'], 3 * 86400);
        $add($w, ['From' => 'me@example.com', 'To' => 'renee@booking.example', 'Subject' => 'Re: Spring dates', 'Message-ID' => '<t2@x>'], 'Let me check with the band.', ['SENT'], 2 * 86400);
        $add($w, ['From' => 'Renee Calloway <renee@booking.example>', 'To' => 'me@example.com', 'Subject' => 'Re: Spring dates', 'Message-ID' => '<draft@x>'], 'A DRAFT NOBODY SENT', ['DRAFT'], 86400);
        $add($w, $renee + ['Message-ID' => '<t3@x>'], 'Any word yet?', ['INBOX', 'UNREAD'], 600);
        $w->reader->poll($w->account);
        $w->store->db->run('UPDATE {emails} SET read_state = ? WHERE message_id IN (?, ?)', [Readings::SKIPPED, '<t1@x>', '<t2@x>']);
        $w->claude->answer = static fn (): array => ['line' => 'Renee asks again for your answer.', 'needs_owner' => true, 'ask' => 'Give Renee your answer for the venue.', 'due' => '2026-11-13T12:00', 'place' => 'none', 'reasons' => ['She asks for your answer.', 'The deadline was set in the email of November 8.']];
        $w->readings->plan();
        same(1, $w->readings->work());

        $shown = (string) $w->claude->readings()[0]['body']['messages'][0]['content'];
        check(str_contains($shown, 'Earlier in this thread'));
        check(str_contains($shown, 'The venue needs an answer by Friday at noon.'), 'the earlier email that set the deadline is shown');
        check(str_contains($shown, "The owner, "), 'the owner\'s own earlier reply is named as theirs');
        check(str_contains($shown, 'Let me check with the band.'));
        check(!str_contains($shown, 'OLD-QUOTED-WORDS'), 'only the new words of each earlier email');
        check(!str_contains($shown, 'A DRAFT NOBODY SENT'), 'a draft is not part of the thread');
        // Earlier emails come before the email itself, which is last.
        check(strpos($shown, 'The venue needs an answer') < strpos($shown, 'Any word yet?'));
        check(str_contains($shown, 'The owner has already answered this email: no'), 'the owner\'s reply was before this email, not after it');
        same(gmmktime(17, 0, 0, 11, 13, 2026), $w->reading('<t3@x>')['due']);
        // One request to Google brought the whole thread: no second fetch for the email itself.
        same(1, count(array_filter($w->fake->calls, static fn (string $c): bool => str_contains($c, '/threads/'))));
    },

    'showing earlier emails of a thread can be turned off; and the day\'s sentence is written at most 24 times a day' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        $w->readings->setThreads(false);
        foreach ([1, 2] as $i) {
            $id = $w->fake->add($renee + ['Message-ID' => "<off-$i@x>"], ['INBOX'], '', $w->clock->now - (3 - $i) * 3600);
            $w->fake->messages[$id]['threadId'] = 'thread-off';
            $w->fake->setBody($id, "WORDS-OF-$i");
        }
        $w->reader->poll($w->account);
        $w->store->db->run('UPDATE {emails} SET read_state = ? WHERE message_id = ?', [Readings::SKIPPED, '<off-1@x>']);
        $w->readings->plan();
        same(1, $w->readings->work());
        $shown = (string) $w->claude->readings()[0]['body']['messages'][0]['content'];
        check(!str_contains($shown, 'WORDS-OF-1') && str_contains($shown, 'WORDS-OF-2'), 'only the email itself');
        same(0, count(array_filter($w->fake->calls, static fn (string $c): bool => str_contains($c, '/threads/'))));

        // 24 sentences written today: no more today, whatever changes.
        $day = new \Precis\Day($w->store, $w->readings);
        for ($i = 0; $i < \Precis\Day::A_DAY; $i++) {
            $w->readings->count('claude-opus-5-5', 'day', ['in' => 1, 'out' => 1, 'cacheRead' => 0, 'cacheWrite' => 0]);
        }
        $w->claude->answer = static fn (): array => ['line' => 'x', 'needs_owner' => true, 'ask' => 'y', 'due' => '', 'place' => 'none', 'reasons' => []];
        $w->arriveWith($renee + ['Message-ID' => '<cap@x>'], 'Question?');
        $w->readings->plan();
        $w->readings->work();
        $before = count($w->claude->readings());
        same(false, $day->refresh());
        same($before, count($w->claude->readings()));
    },

    'a long earlier thread is trimmed: the newest few emails, each cut short' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        for ($i = 1; $i <= 9; $i++) {
            $id = $w->fake->add($renee + ['Message-ID' => "<long-$i@x>"], ['INBOX'], '', $w->clock->now - (20 - $i) * 3600);
            $w->fake->messages[$id]['threadId'] = 'thread-long';
            $w->fake->setBody($id, "EMAIL-$i-START " . str_repeat('word ', 300) . "EMAIL-$i-END");
        }
        $w->reader->poll($w->account);
        $w->store->db->run('UPDATE {emails} SET read_state = ? WHERE message_id <> ?', [Readings::SKIPPED, '<long-9@x>']);
        $w->readings->plan();
        same(1, $w->readings->work());
        $shown = (string) $w->claude->readings()[0]['body']['messages'][0]['content'];
        check(!str_contains($shown, 'EMAIL-1-START') && !str_contains($shown, 'EMAIL-2-START'), 'the oldest are left out');
        check(str_contains($shown, 'EMAIL-8-START') && str_contains($shown, 'EMAIL-3-START'), 'the six before it are shown');
        check(!str_contains($shown, 'EMAIL-8-END'), 'each earlier email is cut short');
        check(str_contains($shown, 'EMAIL-9-END'), 'the email itself is whole');
        check(mb_strlen($shown) < 6500 + 1600, 'the whole thing stays a fixed size');
    },

    'mail you send to a person is read to tell whether you asked for something; mail to a company is not' => function () use ($person): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        $w->claude->answer = static fn (string $email): array => str_contains($email, 'signed copy')
            ? ['line' => 'You asked Renee to send the signed copy.', 'asks' => true, 'ask' => 'The signed copy.', 'reasons' => ['You asked her to send something.']]
            : ['line' => 'You thanked Renee.', 'asks' => false, 'ask' => 'ignored', 'reasons' => ['Nothing is asked.']];
        $send = static function (World $w, string $to, string $subject, string $words, string $mid): void {
            $id = $w->fake->add(['From' => 'me@example.com', 'To' => $to, 'Subject' => $subject, 'Message-ID' => $mid], ['SENT']);
            $w->fake->setBody($id, $words);
            $w->reader->poll($w->account);
        };
        $send($w, 'Renee Calloway <renee@booking.example>', 'The contract', "Can you send the signed copy?\n\nOn Mon Renee wrote:\n> HER-OLD-WORDS", '<ask@me>');
        $send($w, 'renee@booking.example', 'Thanks', 'Thank you!', '<thanks@me>');
        $send($w, 'help@shop.example', 'Order problem', 'Where is my order?', '<shop@me>');
        // The shop is not a person (the owner said so), so mail to it is not read.
        $w->sync->push(1, [['kind' => 'sender', 'k' => 'help@shop.example', 'data' => ['cls' => 'feeds', 'src' => 'override']]]);
        same('feeds', $w->sender('help@shop.example')['cls']);
        $w->readings->plan();
        $w->readings->work();
        $sent = array_values(array_filter($w->claude->readings(), static fn (array $r): bool => str_contains((string) $r['body']['messages'][0]['content'], 'Kind: sent by the owner')));
        same(2, count($sent), 'the two to a person, not the one to a company');
        $asked = array_values(array_filter($sent, static fn (array $r): bool => str_contains((string) $r['body']['messages'][0]['content'], 'signed copy')))[0];
        $shown = (string) $asked['body']['messages'][0]['content'];
        check(str_contains($shown, 'To: Renee Calloway'));
        check(str_contains($shown, 'Can you send the signed copy?') && !str_contains($shown, 'HER-OLD-WORDS'), 'only what the owner wrote this time');
        check(str_contains((string) json_encode($asked['body']['system']), 'SENT to someone'), 'its own instructions');
        same(['line', 'asks', 'ask', 'settles', 'reasons'], $asked['body']['output_config']['format']['schema']['required']);
        $r = $w->reading('<ask@me>');
        same([true, true, 'The signed copy.', false], [$r['sent'], $r['asks'], $r['ask'], $r['focus']]);
        $r = $w->reading('<thanks@me>');
        same([true, false, ''], [$r['sent'], $r['asks'], $r['ask']]);
        same(null, $w->reading('<shop@me>'));
    },

    'a name is never taken from the subject line to say who "he" is' => function () use ($person): void {
        // The rule is in what the assistant is told, for mail received and mail sent.
        check(str_contains(Readings::INSTRUCTIONS, 'Never take a name from the Subject') && str_contains(Readings::INSTRUCTIONS, 'keep the email\'s own word'));
        check(str_contains(Readings::SENT_INSTRUCTIONS, 'never take a name from it'));

        $w = new World();
        $person($w, 'marya@tour.example');
        $w->assistantOn();
        $reply = ['From' => 'Marya Glur <marya@tour.example>', 'To' => 'Clay Example <me@example.com>', 'Subject' => 'Re: Ruben and Clay musicians'];
        $guess = ['line' => 'Marya agrees the salary is fine and asks whether Ruben can do the tracks.', 'needs_owner' => true, 'ask' => 'Tell Marya whether Ruben can do the tracks.', 'due' => '', 'place' => 'none', 'reasons' => ['It asks you a question.']];
        $plain = ['line' => 'Marya agrees the salary is fine and asks whether he can do the tracks.', 'needs_owner' => true, 'ask' => 'Tell Marya whether he can do the tracks.', 'due' => '', 'place' => 'none', 'reasons' => ['It asks you a question.']];

        // It guesses; the helper catches the name that is only in the Subject and asks once more, saying so.
        $w->claude->answer = static fn (string $email): array => str_contains($email, 'Check before you answer') ? $plain : $guess;
        $mid = $w->arriveWith($reply, "absolutely. I think that salary would be fine.\n\nCan he do the tracks or would that be someone else managing that?");
        $w->readings->plan();
        same(1, $w->readings->work());
        same(2, count($w->claude->readings()), 'asked once more');
        $second = (string) $w->claude->readings()[1]['body']['messages'][0]['content'];
        check(str_contains($second, '"Ruben"') && str_contains($second, 'in the Subject but nowhere in the words of the email'));
        same('Marya agrees the salary is fine and asks whether he can do the tracks.', $w->reading($mid)['line']);
        same('Tell Marya whether he can do the tracks.', $w->reading($mid)['ask']);
        same(2, (int) $w->store->db->val('SELECT SUM(calls) FROM {spend}'), 'both readings are on the meter');

        // It insists on the name: the name is taken out by hand, so a guess is never shown as fact.
        $w->claude->requests = [];
        $w->claude->answer = static fn (): array => $guess;
        $mid2 = $w->arriveWith(['Message-ID' => '<again@tour.example>'] + $reply, 'Can he do the tracks?');
        $w->readings->plan();
        $w->readings->work();
        same(2, count($w->claude->readings()));
        check(!str_contains($w->reading($mid2)['line'] . $w->reading($mid2)['ask'], 'Ruben'), 'a guessed name was shown');
        same('Tell Marya whether someone can do the tracks.', $w->reading($mid2)['ask']);

        // A name the email's own words give is used, with no second asking.
        $w->claude->requests = [];
        $mid3 = $w->arriveWith(['Message-ID' => '<named@tour.example>'] + $reply, 'Can Ruben do the tracks, or is that someone else?');
        $w->readings->plan();
        $w->readings->work();
        same(1, count($w->claude->readings()));
        check(str_contains($w->reading($mid3)['line'], 'Ruben'));

        // In a first email the Subject is part of what the sender is saying now: nothing is second-guessed.
        $w->claude->requests = [];
        $mid4 = $w->arriveWith(['Message-ID' => '<first@tour.example>', 'Subject' => 'Ruben and Clay musicians'] + $reply, 'Can he do the tracks?');
        $w->readings->plan();
        $w->readings->work();
        same(1, count($w->claude->readings()));
        check(str_contains($w->reading($mid4)['line'], 'Ruben'));

        // The sender's and the owner's own names are never taken for guesses, wherever they stand in the sentence.
        same([], Readings::borrowedNames(['line' => 'The salary is fine, says Marya, and Clay should confirm.', 'ask' => ''], ['person' => true, 'subject' => 'Re: Marya and Clay', 'shown' => "ok\nMarya Glur marya@tour.example Clay Example"]));
        same(['Ruben'], Readings::borrowedNames(['line' => 'Marya asks whether Ruben can do it.', 'ask' => 'Tell Marya about Ruben.'], ['person' => true, 'subject' => 'RE: Ruben and Clay musicians', 'shown' => "can he do it\nMarya Glur marya@tour.example Clay Example"]));
        same([], Readings::borrowedNames(['line' => 'Your order from Ruben Foods shipped.', 'ask' => ''], ['person' => false, 'subject' => 'Re: Ruben Foods order', 'shown' => 'it shipped']), 'mail from a company is left alone');
    },

    'Focus as it stands: not what you answered, finished, put off or said was not Focus; and what you added by hand' => function () use ($person, $renee, $news): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        $w->claude->answer = static fn (string $email): array => str_contains($email, 'Daily #')
            ? ['line' => 'Five stories.', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'feed', 'reasons' => ['A newsletter.']]
            : ['line' => 'Renee asks something.', 'needs_owner' => true, 'ask' => 'Answer Renee.', 'due' => '', 'place' => 'none', 'reasons' => ['It asks you a question.']];
        $a = $w->arriveWith($renee + ['Message-ID' => '<a@x>'], 'One?', null, ['INBOX'], $w->clock->now - 400);
        $b = $w->arriveWith($renee + ['Message-ID' => '<b@x>'], 'Two?', null, ['INBOX'], $w->clock->now - 300);
        $c = $w->arriveWith($renee + ['Message-ID' => '<c@x>'], 'Three?', null, ['INBOX'], $w->clock->now - 200);
        $d = $w->arriveWith($renee + ['Message-ID' => '<d@x>'], 'Four?', null, ['INBOX'], $w->clock->now - 100);
        $n = $w->arriveWith($news(1), 'Stories.');
        $w->readings->plan();
        $w->readings->work();
        $ids = static fn (World $w): array => array_map(static fn (array $f): string => $f['message_id'], $w->readings->focusNow());
        same(['<d@x>', '<c@x>', '<b@x>', '<a@x>'], $ids($w), 'newest first');
        $w->sync->push(1, [
            ['kind' => 'done', 'k' => '<a@x>', 'data' => ['at' => $w->clock->now]],
            ['kind' => 'msgfix', 'k' => '<b@x>', 'data' => ['focus' => false]],
            ['kind' => 'msgfix', 'k' => '<c@x>', 'data' => ['later' => $w->clock->now + 3600]],
            ['kind' => 'msgfix', 'k' => $n, 'data' => ['focus' => true]],
        ]);
        same([$n, '<d@x>'], $ids($w));
        same(2, $w->readings->status()['focus']);
        same('Answer Renee.', $w->readings->focusNow()[1]['ask']);
        // Its time comes: the one put off is back.
        $w->later(3700);
        same([$n, '<d@x>', '<c@x>'], $ids($w));
        // For the past week: five lines made, two of them corrected (Not Focus, and This needs me).
        $s = $w->readings->status();
        same([5, 2], [$s['made7'], $s['fixed7']]);
    },

    'the sentence at the top of Today is written from the lines below it, and only when they change' => function () use ($person, $renee, $news): void {
        $w = new World();
        $person($w);
        $w->readings->setZone(-300);
        $w->assistantOn();
        $day = new \Precis\Day($w->store, $w->readings);
        $w->claude->answer = static function (string $shown): array {
            if (str_contains($shown, 'Needs them (')) {
                return ['sentence' => "Renee needs your yes or no by 3:00 PM,\n and your subscription renews Friday."];
            }
            return str_contains($shown, 'Daily #')
                ? ['line' => 'Your subscription renews Friday.', 'thing' => 'Pollstar subscription.', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => 'feed', 'know' => true, 'reasons' => ['About your account.']]
                : ['line' => 'Renee asks for a yes or no on March 14.', 'needs_owner' => true, 'ask' => 'Say yes or no to Charlotte, March 14.', 'due' => gmdate('Y-m-d\TH:i', (new World())->clock->now - 5 * 3600 + 5 * 3600), 'place' => 'none', 'reasons' => ['It asks you.']];
        };
        // Nothing below it: no sentence, and the assistant is not asked.
        check($day->refresh());
        same('', $w->store->item('day', 'today')['text']);
        same(0, count($w->claude->readings()));

        $a = $w->arriveWith($renee + ['Message-ID' => '<a@x>'], 'Yes or no on March 14? SECRET-EMAIL-WORDS');
        $w->arriveWith($news(1), 'Your subscription renews Friday. SECRET-FEED-WORDS');
        $w->readings->plan();
        $w->readings->work();
        $before = count($w->claude->readings());
        same(false, $day->refresh(), 'not twice within twenty minutes');
        $w->later(1300);
        check($day->refresh());
        same($before + 1, count($w->claude->readings()));
        $sent = $w->claude->readings()[$before];
        $shown = (string) $sent['body']['messages'][0]['content'];
        check(str_contains($shown, 'Needs them (1):'));
        check(str_contains($shown, 'From Renee Calloway'));
        check(str_contains($shown, 'Say yes or no to Charlotte, March 14.'));
        check(str_contains($shown, '(needed by '));
        check(str_contains($shown, 'Good to know, came today, newest first (1):'));
        check(preg_match('~^- \d\d:\d\d, Pollstar Daily \(Pollstar subscription\): Your subscription renews Friday\.$~m', $shown) === 1, 'when it came, who from, what it is, and the line');
        check(!str_contains($shown, 'SECRET'), 'only the assistant\'s own lines are shown, never an email\'s words');
        check(str_contains((string) json_encode($sent['body']['system']), 'ONE sentence'));
        $item = $w->store->item('day', 'today');
        same('Renee needs your yes or no by 3:00 PM, and your subscription renews Friday.', $item['text']);
        same($w->clock->now, $item['at']);
        check($w->store->db->val("SELECT micro FROM {spend} WHERE purpose = 'day'") > 0, 'it is on the meter');

        // Nothing changed below it: it is not written again, however long passes.
        $w->later(7200);
        same(false, $day->refresh());
        same($before + 1, count($w->claude->readings()));
        // The by-time passes: that is a change ("comes due").
        $w->later(86400);
        check($day->refresh());
        check(str_contains((string) $w->claude->readings()[$before + 1]['body']['messages'][0]['content'], 'now past'));
        // A line is finished: rewritten, and with nothing left the sentence goes.
        $w->sync->push(1, [['kind' => 'done', 'k' => $a, 'data' => ['at' => $w->clock->now]]]);
        $w->later(1300);
        $n = count($w->claude->readings());
        check($day->refresh());
        same('', $w->store->item('day', 'today')['text'], 'yesterday\'s Feed line is not today\'s, and nothing needs them');
        same($n, count($w->claude->readings()));
        // With the assistant off, nothing is written.
        $w->readings->turn(false);
        $w->arriveWith($renee + ['Message-ID' => '<b@x>'], 'Another?');
        $w->later(1300);
        same(false, $day->refresh());
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

    'several emails waiting at once are read with the instructions kept ready; one on its own is not' => function () use ($person, $renee): void {
        $w = new World();
        $person($w);
        $w->assistantOn();
        for ($i = 0; $i < 5; $i++) {
            $w->arriveWith($renee, "Note $i");
        }
        $w->readings->plan();
        same(5, $w->readings->work());
        foreach ($w->claude->readings() as $r) {
            same(['type' => 'ephemeral'], $r['body']['system'][0]['cache_control']);
        }
        $w->arriveWith($renee, 'One more');
        $w->readings->plan();
        same(1, $w->readings->work());
        check(is_string($w->claude->readings()[5]['body']['system']));
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

    'your own word on one email ("Not Focus", "this needs me") reaches every device with the reading' => function () use ($renee): void {
        $s = new Site();
        $s->connectGoogle();
        $token = $s->join();
        $s->owner('/assistant/key', ['key' => FakeClaude::KEY]);
        $s->owner('/assistant/settings', ['model' => 'claude-haiku-5-5']);
        $s->owner('/assistant/switch', ['on' => '1']);
        $s->claude->answer = static fn (): array => ['line' => 'Renee asks for a yes or no.', 'needs_owner' => true, 'ask' => 'Say yes or no.', 'due' => '', 'place' => 'none', 'reasons' => ['It asks you a question.']];
        $s->fake->add(['From' => 'me@example.com', 'To' => 'renee@booking.example', 'Subject' => 'Hello'], ['SENT'], '', $s->clock->now - 86400);
        $id = $s->fake->add($renee + ['Message-ID' => '<ask@x>']);
        $s->fake->setBody($id, 'Yes or no?');
        (new Timer($s->app->store(), $s->app->reader(), $s->app->readings()))->run(20);
        $read = static fn (Site $s): array => $s->app->store()->item('read', '<ask@x>') ?? [];
        same(true, $read($s)['focus']);
        // With each pull a device hears that the assistant is on.
        same(true, $s->api('GET', '/api/changes', null, $token, ['since' => '0'])->data()['assistant']);
        // "Not Focus" from a device: the reading every device follows says so.
        $r = $s->api('POST', '/api/push', ['items' => [['kind' => 'msgfix', 'k' => '<ask@x>', 'data' => ['focus' => false]]]], $token);
        same(200, $r->status, $r->body);
        same(false, $read($s)['focus']);
        // Taken back, the assistant's own answer stands again.
        $s->api('POST', '/api/push', ['items' => [['kind' => 'msgfix', 'k' => '<ask@x>', 'data' => ['focus' => null]]]], $token);
        same(true, $read($s)['focus']);
        $s->owner('/assistant/switch', ['on' => '0']);
        same(false, $s->api('GET', '/api/changes', null, $token, ['since' => '0'])->data()['assistant']);
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
