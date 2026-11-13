<?php
declare(strict_types=1);

namespace Precis\Tests;

use Precis\Body;
use Precis\Readings;
use Precis\Trips;

/** A reading that says nothing needs the owner, with what kind of thing the email is. */
$first = static fn (string $details, string $line = 'A plain email.', string $place = 'feed'): array => ['line' => $line, 'thing' => 'Trip', 'needs_owner' => false, 'ask' => '', 'due' => '', 'place' => $place, 'know' => false, 'details' => $details, 'reasons' => ['Nothing is asked of you.']];

/** One leg, as the assistant reports it. */
$leg = static fn (string $number, string $from, string $to, string $departs, string $arrives, array $more = []): array => $more + [
    'mode' => 'flight', 'carrier' => 'American Airlines', 'number' => $number,
    'from_code' => $from, 'from_city' => ['RDU' => 'Raleigh/Durham', 'DFW' => 'Dallas/Fort Worth', 'LAX' => 'Los Angeles', 'CLT' => 'Charlotte', 'LGA' => 'New York LaGuardia'][$from] ?? '',
    'to_code' => $to, 'to_city' => ['RDU' => 'Raleigh/Durham', 'DFW' => 'Dallas/Fort Worth', 'LAX' => 'Los Angeles', 'CLT' => 'Charlotte', 'LGA' => 'New York LaGuardia'][$to] ?? '',
    'departs' => $departs, 'departs_zone' => ['RDU' => 'America/New_York', 'DFW' => 'America/Chicago', 'LAX' => 'America/Los_Angeles', 'CLT' => 'America/New_York', 'LGA' => 'America/New_York'][$from] ?? '',
    'arrives' => $arrives, 'arrives_zone' => ['RDU' => 'America/New_York', 'DFW' => 'America/Chicago', 'LAX' => 'America/Los_Angeles', 'CLT' => 'America/New_York', 'LGA' => 'America/New_York'][$to] ?? '',
    'locator' => 'HEYLVT', 'was_departs' => '', 'was_arrives' => '',
];

/** The fuller reading's answer. */
$found = static fn (array $legs, string $what = 'confirmed', array $more = []): array => $more + ['legs' => $legs, 'bookings' => [], 'what' => $what, 'automated' => true, 'checkin_link' => 0, 'missing' => [], 'draft' => ''];

/**
 * A helper with the assistant on. [$says] answers each email: its first
 * reading from 'first', its fuller reading from 'detail'.
 *
 * @return array{0: World, 1: Trips}
 */
$world = static function (\Closure $says): array {
    $w = new World();
    $w->arrive(['From' => 'me@example.com', 'To' => 'nicole@agency.example', 'Subject' => 'Hello'], ['SENT'], '', $w->clock->now - 86400);
    $w->store->db->run('UPDATE {emails} SET read_state = ? WHERE is_from_me = 1', [Readings::SKIPPED]);
    $w->readings->setZone(-300);
    $w->assistantOn();
    $w->claude->answer = static function (string $email, array $body) use ($says): array {
        $full = str_contains((string) json_encode($body['system'] ?? ''), 'take out of it the travel');
        return $says($email, $full, $body);
    };
    return [$w, new Trips($w->store, $w->google, $w->readings)];
};

/** Reads what is waiting: first readings, then the fuller ones. */
$read = static function (World $w, Trips $t): int {
    $w->readings->plan();
    $w->readings->work();
    return $t->work();
};

$airline = ['From' => 'American Airlines <no-reply@info.aa.example>', 'To' => 'me@example.com', 'List-Unsubscribe' => '<mailto:u@aa.example>'];
$nicole = ['From' => 'Nicole Gotlin <nicole@agency.example>', 'To' => 'me@example.com'];
$at = static fn (string $local, string $zone): int => (new \DateTimeImmutable($local, new \DateTimeZone($zone)))->getTimestamp();

return [
    'a round trip in one email is kept as one leg for each flight, each with its own times in its own cities\' clocks' => function () use ($world, $read, $first, $leg, $found, $airline, $at): void {
        [$w, $trips] = $world(static fn (string $email, bool $full): array => $full ? $found([
            $leg('AA1201', 'RDU', 'DFW', '2026-11-20T07:05', '2026-11-20T09:10'),
            $leg('AA2302', 'DFW', 'LAX', '2026-11-20T10:15', '2026-11-20T11:40'),
            $leg('AA0455', 'LAX', 'CLT', '2026-11-24T13:00', '2026-11-24T20:45'),
            $leg('AA5120', 'CLT', 'RDU', '2026-11-24T21:50', '2026-11-24T22:48'),
        ]) : $first('travel', 'Your trip to Los Angeles is booked.'));
        $mid = $w->arriveWith($airline + ['Subject' => 'Your trip confirmation'], 'Thanks for booking. Your record locator is HEYLVT.');
        same(1, $read($w, $trips));
        $legs = $w->store->itemsOf('leg');
        same(4, count($legs));
        same(['AA0455|2026-11-24|LAX|CLT', 'AA1201|2026-11-20|RDU|DFW', 'AA2302|2026-11-20|DFW|LAX', 'AA5120|2026-11-24|CLT|RDU'], array_keys($legs));
        $l = $legs['AA2302|2026-11-20|DFW|LAX'];
        same(['flight', 'American Airlines', 'AA2302', 'DFW', 'Dallas/Fort Worth', 'LAX', 'Los Angeles', 'HEYLVT'], [$l['mode'], $l['carrier'], $l['number'], $l['fc'], $l['fcity'], $l['tc'], $l['tcity'], $l['loc']]);
        same(['2026-11-20T10:15', '2026-11-20T11:40'], [$l['dep'], $l['arr']]);
        // It leaves on Dallas time and lands on Los Angeles time: 3 h 25 min in the air, not 1 h 25.
        same([$at('2026-11-20 10:15', 'America/Chicago'), $at('2026-11-20 11:40', 'America/Los_Angeles')], [$l['dep_at'], $l['arr_at']]);
        same(3 * 3600 + 25 * 60, $l['arr_at'] - $l['dep_at']);
        same(['confirmed', $mid, true, []], [$l['state'], $l['mid'], $l['auto'], $l['missing']]);
        same($w->clock->now, $l['news_at'], 'a booking is news for a day from when its email came');
        // Read once: the timer finds nothing more to do, and nothing was put in front of the owner.
        same(0, $trips->work());
        same(false, $w->reading($mid)['focus']);
        same(2, count($w->claude->readings()));
    },

    'only mail that is travel or a booking is read in full; the rest, and Noise, never is' => function () use ($world, $read, $first, $found, $airline): void {
        [$w, $trips] = $world(static fn (string $email, bool $full): array => match (true) {
            $full => $found([]),
            str_contains($email, 'fare sale') => $first('travel', 'A fare sale.', 'noise'),
            default => $first('none'),
        });
        $w->arriveWith($airline + ['Subject' => 'Statement'], 'Your miles statement is ready.');
        $w->arriveWith(['From' => 'Deals <deals@fly.example>', 'To' => 'me@example.com', 'Subject' => 'Big fare sale', 'List-Unsubscribe' => '<mailto:u@fly.example>'], 'A fare sale to everywhere.');
        same(0, $read($w, $trips));
        foreach ($w->claude->readings() as $asked) {
            check(!str_contains((string) json_encode($asked['body']['system'] ?? ''), 'take out of it the travel'), 'no fuller reading was asked for');
        }
        check(count($w->claude->readings()) >= 1);
        same([], $w->store->itemsOf('leg'));
        same(0, (int) $w->store->db->val('SELECT COUNT(*) FROM {readings} WHERE detail <> 0'));
    },

    'later mail about a leg updates it: the check-in link, checked in, a delay with the old times kept, a cancellation' => function () use ($world, $read, $first, $leg, $found, $airline, $at): void {
        $shown = [];
        [$w, $trips] = $world(static function (string $email, bool $full) use ($first, $leg, $found, &$shown): array {
            if (!$full) {
                return $first('travel');
            }
            $shown[] = $email;
            return match (true) {
                str_contains($email, 'Subject: Your trip confirmation') => $found([$leg('AA4704', 'RDU', 'LGA', '2026-11-16T19:57', '2026-11-16T22:00')]),
                str_contains($email, 'Subject: Time to check in') => $found([$leg('AA4704', 'RDU', 'LGA', '2026-11-16T19:57', '')], 'checkin_open', ['checkin_link' => 2]),
                str_contains($email, 'Subject: You are checked in') => $found([$leg('AA4704', 'RDU', 'LGA', '2026-11-16T19:57', '2026-11-16T22:00')], 'checked_in'),
                str_contains($email, 'Subject: Your flight is delayed') => $found([$leg('AA4704', 'RDU', 'LGA', '2026-11-16T21:10', '2026-11-16T23:15', ['was_departs' => '2026-11-16T19:57', 'was_arrives' => '2026-11-16T22:00'])], 'delayed'),
                default => $found([$leg('AA4704', 'RDU', 'LGA', '2026-11-16T21:10', '')], 'cancelled'),
            };
        });
        $key = 'AA4704|2026-11-16|RDU|LGA';
        $booked = $w->arriveWith($airline + ['Subject' => 'Your trip confirmation'], 'Booked.');
        $read($w, $trips);
        same(['confirmed', ''], [$w->store->item('leg', $key)['state'], $w->store->item('leg', $key)['checkin']]);

        // The invitation to check in: the link the email's own button leads to.
        $w->later(3 * 86400);
        $invite = $w->arriveWith($airline + ['Subject' => 'Time to check in'], 'Check in now.', '<p>Check in now.</p><a href="https://aa.example/manage?r=HEYLVT">Check in for a better seat offer</a> <a href="https://aa.example/checkin?r=HEYLVT&amp;x=1"><img src="b.png" alt="Check in"></a> <a href="https://aa.example/help">Help</a>');
        $read($w, $trips);
        $l = $w->store->item('leg', $key);
        same(['checkin', 'https://aa.example/checkin?r=HEYLVT&x=1', $invite], [$l['state'], $l['checkin'], $l['mid']]);
        same('2026-11-16T22:00', $l['arr'], 'a notice with less to say does not blank what was known');
        same(1, count($w->store->itemsOf('leg')), 'the same leg, not a second one');
        // The assistant is shown what each link says, never where it leads.
        check(str_contains($shown[1], "Links:\n1. Check in for a better seat offer\n2. Check in") && !str_contains($shown[1], 'aa.example/checkin'), 'links by what they say only');
        same($w->clock->now - 3 * 86400, $l['news_at'], 'a check-in notice is not a new booking');

        $w->later(3600);
        $in = $w->arriveWith($airline + ['Subject' => 'You are checked in'], 'You are checked in.');
        $read($w, $trips);
        same(['checked', $in], [$w->store->item('leg', $key)['state'], $w->store->item('leg', $key)['mid']]);

        // A delay: the new times, with the old ones kept to strike through.
        $w->later(3600);
        $late = $w->arriveWith($airline + ['Subject' => 'Your flight is delayed'], 'New departure 9:10 PM.');
        $read($w, $trips);
        $l = $w->store->item('leg', $key);
        same(['delayed', '2026-11-16T21:10', '2026-11-16T23:15', '2026-11-16T19:57', '2026-11-16T22:00', $late], [$l['state'], $l['dep'], $l['arr'], $l['was_dep'], $l['was_arr'], $l['mid']]);
        same($at('2026-11-16 23:15', 'America/New_York'), $l['arr_at']);
        same('https://aa.example/checkin?r=HEYLVT&x=1', $l['checkin'], 'the check-in link is kept');

        $w->later(600);
        $off = $w->arriveWith($airline + ['Subject' => 'Your flight is cancelled'], 'We are sorry.');
        $read($w, $trips);
        same(['cancelled', $off], [$w->store->item('leg', $key)['state'], $w->store->item('leg', $key)['mid']]);
        same(1, count($w->store->itemsOf('leg')));
    },

    'an itinerary a person attached is opened and read; with details missing, their email needs you and carries one email to them asking for all of it' => function () use ($world, $read, $first, $leg, $found, $nicole): void {
        $seen = [];
        [$w, $trips] = $world(static function (string $email, bool $full, array $body) use ($first, $leg, $found, &$seen): array {
            if (!$full) {
                $seen['first'] = $email;
                return $first('travel', 'Nicole sent your travel for the Dallas shoot.', 'none');
            }
            $seen['content'] = $body['messages'][0]['content'];
            return $found(
                [$leg('AA1201', 'RDU', 'DFW', '2026-11-20T07:05', '2026-11-20T09:10', ['locator' => '']), $leg('', 'DFW', 'RDU', '2026-11-22', '', ['carrier' => '', 'locator' => ''])],
                'confirmed',
                [
                    'automated' => false,
                    'bookings' => [
                        ['type' => 'hotel', 'name' => 'The Joule', 'starts' => '2026-11-20', 'ends' => '2026-11-22', 'zone' => 'America/Chicago', 'place' => 'Dallas', 'to' => '', 'address' => '', 'conf' => '', 'phone' => '', 'person' => '', 'party' => ''],
                        // A dinner a person mentions is not a booking for the card.
                        ['type' => 'restaurant', 'name' => 'Town Hearth', 'starts' => '2026-11-20T19:30', 'ends' => '', 'zone' => 'America/Chicago', 'place' => 'Dallas', 'to' => '', 'address' => '', 'conf' => '', 'phone' => '', 'person' => '', 'party' => '4'],
                    ],
                    'missing' => ['the confirmation code for the flight to Dallas', 'the flight number and times for the flight home', 'the hotel\'s address and confirmation number'],
                    'draft' => "Hi Nicole,\n\nCould you send me these for the Dallas trip?\n- the confirmation code for the flight to Dallas\n- the flight number and times for the flight home\n- the hotel's address and confirmation number\n\nThank you,\nClay",
                ],
            );
        });
        $pdf = "%PDF-1.4 the itinerary";
        $mid = $w->arriveWithFiles($nicole + ['Subject' => 'Dallas travel'], 'Hi, your travel is attached. Dinner Friday at Town Hearth, 7:30.', [
            ['Dallas itinerary.pdf', 'application/pdf', $pdf],
            ['logo.png', 'image/png', str_repeat('x', 900)],
            ['notes.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', str_repeat('y', 5000)],
        ]);
        same(1, $read($w, $trips));
        // The first reading is told only what the files are called.
        check(str_contains($seen['first'], 'Attached files (names only): Dallas itinerary.pdf, logo.png, notes.docx'), 'names of the attached files');
        // The fuller one is given the PDF itself, before the email. The logo and the Word file are not sent.
        same(1, $w->fake->fetched);
        same(['document', 'text'], array_column($seen['content'], 'type'));
        same(['type' => 'base64', 'media_type' => 'application/pdf', 'data' => base64_encode($pdf)], $seen['content'][0]['source']);
        check(str_contains($seen['content'][1]['text'], 'Dallas itinerary.pdf (application/pdf)') && str_contains($seen['content'][1]['text'], '(1 of them given to you before this text)'));

        $legs = $w->store->itemsOf('leg');
        same(['?|2026-11-22|DFW|RDU', 'AA1201|2026-11-20|RDU|DFW'], array_keys($legs));
        same(['the confirmation code'], $legs['AA1201|2026-11-20|RDU|DFW']['missing']);
        same(['the departure time', 'the arrival time', 'the carrier', 'the flight number', 'the confirmation code'], $legs['?|2026-11-22|DFW|RDU']['missing']);
        same(false, $legs['AA1201|2026-11-20|RDU|DFW']['auto']);
        // The hotel is kept; the dinner is not.
        $bookings = $w->store->itemsOf('booking');
        same(['hotel|the-joule|2026-11-20'], array_keys($bookings));
        same(['the address', 'the confirmation number'], $bookings['hotel|the-joule|2026-11-20']['missing']);

        // Their email now needs the owner, with the one email written for them to look over.
        $r = $w->reading($mid);
        same([true, 'Ask Nicole for the travel details that are missing.'], [$r['focus'], $r['ask']]);
        check(str_starts_with($r['draft'], "Hi Nicole,\n\nCould you send me these") && str_ends_with($r['draft'], "Thank you,\nClay"), 'the email keeps its lines');
        same(1, count($w->readings->focusNow()));
        // Nothing was sent anywhere: the helper only wrote it down.
        same([], $w->fake->sent ?? []);
    },

    'the airline\'s own confirmation wins over what a person wrote, fills what was missing, and takes the request back' => function () use ($world, $read, $first, $leg, $found, $nicole, $airline): void {
        [$w, $trips] = $world(static fn (string $email, bool $full): array => match (true) {
            !$full => $first('travel', 'Travel.', str_contains($email, 'Nicole') ? 'none' : 'feed'),
            str_contains($email, 'Subject: Dallas travel') => $found([$leg('AA1201', 'RDU', 'DFW', '2026-11-20T07:00', '', ['locator' => '', 'carrier' => 'American'])], 'confirmed', ['automated' => false, 'missing' => ['the arrival time', 'the confirmation code'], 'draft' => "Hi Nicole,\n\nWhat is the confirmation code?\n\nThank you,\nClay"]),
            str_contains($email, 'Subject: Reminder from Nicole') => $found([$leg('AA1201', 'RDU', 'DFW', '2026-11-20T06:00', '2026-11-20T08:00', ['locator' => 'WRONG1', 'carrier' => 'AA'])], 'reminder', ['automated' => false]),
            default => $found([$leg('AA1201', 'RDU', 'DFW', '2026-11-20T07:05', '2026-11-20T09:10')]),
        });
        $key = 'AA1201|2026-11-20|RDU|DFW';
        $asked = $w->arriveWith($nicole + ['Subject' => 'Dallas travel'], 'You are on the 7 AM to Dallas on the 20th.');
        $read($w, $trips);
        same(true, $w->reading($asked)['focus']);
        same($asked, $w->store->item('leg', $key)['ask']);

        // American's own email arrives for the same flight.
        $w->later(1800);
        $own = $w->arriveWith($airline + ['Subject' => 'Your trip confirmation'], 'Booked. Record locator HEYLVT.');
        $read($w, $trips);
        $l = $w->store->item('leg', $key);
        same(['American Airlines', '2026-11-20T07:05', '2026-11-20T09:10', 'HEYLVT', true, [], '', $own], [$l['carrier'], $l['dep'], $l['arr'], $l['loc'], $l['auto'], $l['missing'], $l['ask'], $l['mid']]);
        same(1, count($w->store->itemsOf('leg')));
        // Nothing is missing any more: Nicole's email stops needing the owner and the request is let go.
        $r = $w->reading($asked);
        same([false, false], [$r['focus'], isset($r['draft'])]);
        same(0, count($w->readings->focusNow()));

        // A person's later word does not write over the airline's.
        $w->later(600);
        $w->arriveWith($nicole + ['Subject' => 'Reminder from Nicole'], 'Wheels up at 6!');
        $read($w, $trips);
        $l = $w->store->item('leg', $key);
        same(['American Airlines', '2026-11-20T07:05', 'HEYLVT', true], [$l['carrier'], $l['dep'], $l['loc'], $l['auto']]);
        same(0, count($w->readings->focusNow()));
    },

    'an automated booking is kept with everything its card shows; a change updates it by its confirmation number; what is over is forgotten' => function () use ($world, $read, $first, $found): void {
        $hotel = ['type' => 'hotel', 'name' => 'The Joule', 'starts' => '2026-11-20T15:00', 'ends' => '2026-11-22T11:00', 'zone' => 'America/Chicago', 'place' => 'Dallas', 'to' => '', 'address' => '1530 Main St, Dallas, TX', 'conf' => '88412207', 'phone' => '214-555-0100', 'person' => '', 'party' => ''];
        [$w, $trips] = $world(static fn (string $email, bool $full): array => match (true) {
            !$full => $first('booking', 'Your stay is confirmed.'),
            str_contains($email, 'Subject: Your reservation has changed') => $found([], 'changed', ['bookings' => [['starts' => '2026-11-21T15:00'] + $hotel]]),
            default => $found([], 'confirmed', ['bookings' => [$hotel, ['type' => 'car_service', 'name' => 'Carey', 'starts' => '2026-11-20T09:30', 'ends' => '', 'zone' => 'America/Chicago', 'place' => 'DFW Terminal C', 'to' => 'The Joule', 'address' => '', 'conf' => 'CR-5521', 'phone' => '800-555-0199', 'person' => 'Luis M.', 'party' => '']]]),
        });
        $from = ['From' => 'The Joule <reservations@joule.example>', 'To' => 'me@example.com', 'List-Unsubscribe' => '<mailto:u@joule.example>'];
        $w->arriveWith($from + ['Subject' => 'Your reservation is confirmed'], 'See you soon.');
        same(1, $read($w, $trips));
        $all = $w->store->itemsOf('booking');
        same(['car_service|cr-5521', 'hotel|88412207'], array_keys($all));
        $h = $all['hotel|88412207'];
        same(['The Joule', 'Dallas', '1530 Main St, Dallas, TX', '2026-11-20T15:00', '2026-11-22T11:00', '88412207', 'confirmed'], [$h['name'], $h['place'], $h['address'], $h['starts'], $h['ends'], $h['conf'], $h['state']]);
        same(['Carey', 'DFW Terminal C', 'The Joule', 'Luis M.', '800-555-0199'], array_map(static fn (string $f): string => $all['car_service|cr-5521'][$f], ['name', 'place', 'to', 'person', 'phone']));

        $w->later(3600);
        $changed = $w->arriveWith($from + ['Subject' => 'Your reservation has changed'], 'New dates.');
        $read($w, $trips);
        $h = $w->store->item('booking', 'hotel|88412207');
        same(['2026-11-21T15:00', 'changed', $changed, $w->clock->now], [$h['starts'], $h['state'], $h['mid'], $h['news_at']]);
        same(2, count($w->store->itemsOf('booking')));

        // Long after check-out, both are forgotten; devices are told.
        $w->clock->now = (new \DateTimeImmutable('2026-11-26 12:00', new \DateTimeZone('America/Chicago')))->getTimestamp();
        same(2, $trips->prune());
        same([], $w->store->itemsOf('booking'));
    },

    'what one device finds for Deliveries and Payments reaches the others; the newer email wins whoever speaks last; a dismissal is relayed; what is past is forgotten' => function (): void {
        $w = new World();
        $d = new \Precis\Devices($w->store);
        $pc = $d->join($d->newCode(), 'PC', 'windows')['id'];
        $phone = $d->join($d->newCode(), 'Phone', 'android')['id'];
        $now = $w->clock->now;
        $tuesday = ['type' => 'delivery', 'title' => 'Acme', 'detail' => '', 'starts' => $now + 86400, 'mat' => $now - 3600, 'mid' => '<p2@x>', 'from' => 'ship@acme.example', 'until' => $now + 2 * 86400];
        $monday = ['starts' => $now, 'mat' => $now - 90000, 'mid' => '<p1@x>', 'until' => $now + 86400] + $tuesday;
        // The PC read the newer email; the phone, later, only the older one.
        $w->sync->push($pc, [['kind' => 'timely', 'k' => 'parcel:1Z9', 'data' => $tuesday]]);
        $w->sync->push($phone, [['kind' => 'timely', 'k' => 'parcel:1Z9', 'data' => $monday]]);
        $kept = $w->store->item('timely', 'parcel:1Z9');
        same(['<p2@x>', $now + 86400, $now - 3600], [$kept['mid'], $kept['starts'], $kept['mat']], 'the newer email stands');
        // The phone hears what the PC found; the PC is not told its own word back.
        $forPhone = array_values(array_filter($w->store->since(0, $phone)['items'], static fn (array $i): bool => $i['kind'] === 'timely'));
        same([['parcel:1Z9', '<p2@x>']], array_map(static fn (array $i): array => [$i['k'], $i['data']['mid']], $forPhone));
        same([], array_values(array_filter($w->store->since(0, $pc)['items'], static fn (array $i): bool => $i['kind'] === 'timely')));
        // A newer email on the phone does replace it.
        $wednesday = ['status' => 'out-for-delivery', 'mat' => $now, 'mid' => '<p3@x>'] + $tuesday;
        $w->sync->push($phone, [['kind' => 'timely', 'k' => 'parcel:1Z9', 'data' => $wednesday]]);
        same('out-for-delivery', $w->store->item('timely', 'parcel:1Z9')['status']);
        // Dismissed on the phone, then put off on the PC: both are kept, and each device hears the other's.
        $w->sync->push($phone, [['kind' => 'cardfix', 'k' => 'timely:parcel:1Z9', 'data' => ['off' => true]]]);
        $w->sync->push($pc, [['kind' => 'cardfix', 'k' => 'timely:parcel:1Z9', 'data' => ['later' => $now + 7200]]]);
        same(['later' => $now + 7200, 'off' => true], $w->store->item('cardfix', 'timely:parcel:1Z9'));
        // Days after it is over, the helper forgets it and what was done to it.
        $w->later(6 * 86400);
        check((new Trips($w->store, $w->google, $w->readings))->prune() >= 1);
        same([null, null], [$w->store->item('timely', 'parcel:1Z9'), $w->store->item('cardfix', 'timely:parcel:1Z9')]);
    },

    'the files attached to an email, and its links, are found; times are worked out in the place\'s own clock' => function (): void {
        $enc = static fn (string $s): string => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
        $m = ['payload' => ['mimeType' => 'multipart/mixed', 'parts' => [
            ['mimeType' => 'multipart/alternative', 'filename' => '', 'parts' => [
                ['mimeType' => 'text/plain', 'filename' => '', 'body' => ['data' => $enc('Hello')]],
                ['mimeType' => 'text/html', 'filename' => '', 'body' => ['data' => $enc('<a class="b" href="https://x.example/a?b=1&amp;c=2">  Check&nbsp;in <b>now</b></a><a href="mailto:x@y.example">Write</a><a href=\'https://x.example/b\'></a>')]],
            ]],
            ['mimeType' => 'application/pdf', 'filename' => 'Itinerary.pdf', 'body' => ['attachmentId' => 'A1', 'size' => 2048]],
        ]]];
        same([['name' => 'Itinerary.pdf', 'mime' => 'application/pdf', 'size' => 2048, 'id' => 'A1']], Body::attachments($m));
        same([['text' => 'Check in now', 'url' => 'https://x.example/a?b=1&c=2']], Body::links($m));

        same('2026-11-20T07:05', Trips::when('2026-11-20T07:05:00-05:00'));
        same('2026-11-20', Trips::when('2026-11-20'));
        same('', Trips::when('Friday at 7'));
        same('', Trips::when('2026-13-40T07:05'));
        same('America/Los_Angeles', Trips::zone('America/Los_Angeles'));
        same('', Trips::zone('Pacific time'));
        // 11:40 AM in Los Angeles in November is 19:40 UTC.
        same(gmmktime(19, 40, 0, 11, 20, 2026), Trips::moment('2026-11-20T11:40', 'America/Los_Angeles', -300));
        // No zone known: the owner's own clock (here UTC-5).
        same(gmmktime(16, 40, 0, 11, 20, 2026), Trips::moment('2026-11-20T11:40', '', -300));
        // A day with no time is the end of that day there.
        same(gmmktime(4, 59, 0, 11, 21, 2026), Trips::moment('2026-11-20', 'America/New_York', -300));
        same(null, Trips::moment('', 'America/New_York', -300));
    },
];
