<?php
declare(strict_types=1);

/**
 * Run once on the hosting account after setup:  php server_check.php
 *
 * The helper's own checks run on a PC against SQLite. The live helper uses
 * MySQL. This proves the same storage and sorting work there, in scratch
 * tables of their own (prefix pxcheck_) that are removed at the end. The
 * helper's real tables are not touched, and nothing is sent anywhere.
 */

use Precis\Crypto;
use Precis\Db;
use Precis\Devices;
use Precis\Schema;
use Precis\Sorter;
use Precis\Store;
use Precis\Sync;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

$configFile = PRECIS_HOME . '/config.php';
if (!is_file($configFile)) {
    fwrite(STDERR, "The helper is not set up yet.\n");
    exit(2);
}
/** @var array<string, mixed> $config */
$config = require $configFile;
$config['prefix'] = 'pxcheck_';
$db = Db::connect($config);
$tables = ['meta', 'counters', 'accounts', 'emails', 'rcpts', 'items', 'sender_facts', 'my_ids', 'devices', 'pair_codes', 'throttle', 'log'];
$drop = static function () use ($db, $tables): void {
    foreach ($tables as $t) {
        $db->exec('DROP TABLE IF EXISTS {' . $t . '}');
    }
};
$n = 0;
$ok = static function (bool $pass, string $what) use (&$n): void {
    if (!$pass) {
        throw new RuntimeException('FAILED: ' . $what);
    }
    $n++;
};

try {
    $drop();
    Schema::migrate($db);
    Schema::migrate($db);
    $store = new Store($db, new Crypto(random_bytes(32)));
    $ok($db->driver === 'mysql', 'this is MySQL');

    // The stream of items.
    $ok($store->put('tag', 'Receipt', ['pos' => 1]), 'a new item is written');
    $ok(!$store->put('tag', 'Receipt', ['pos' => 1]), 'the same contents again change nothing');
    $ok($store->put('tag', 'Reçu 🎟', ['pos' => 2], 7), 'accents and emoji in a key');
    $ok($store->item('tag', 'Reçu 🎟') === ['pos' => 2], 'and they read back');
    $ok($store->item('tag', 'receipt') === null, 'keys tell capitals from small letters');
    $ok($store->remove('tag', 'Receipt'), 'removing');
    $since = $store->since(0, 7);
    $ok(count($since['items']) === 1 && $since['items'][0]['deleted'] === true && $since['next'] === 3, 'what changed, without the asker\'s own');
    $long = '<' . str_repeat('m', 390) . '@x>';
    $ok($store->put('done', $long, ['at' => 1]) && $store->item('done', $long) === ['at' => 1], 'a 400-character key');
    $store->setSecret('s', 'sealed value');
    $ok($store->getSecret('s') === 'sealed value' && !str_contains((string) $store->get('s'), 'sealed value'), 'secrets are sealed');

    // Devices.
    $devices = new Devices($store);
    $code = $devices->newCode();
    $joined = $devices->join($code, 'Check PC', 'windows');
    $ok($joined !== null && $devices->join($code, 'Again', 'windows') === null, 'a joining code works once');
    $ok($devices->check($joined['token'])['name'] === 'Check PC' && $devices->check('1.' . str_repeat('x', 43)) === null, 'tokens');
    for ($i = 0; $i < 8; $i++) {
        $devices->miss('check');
    }
    $ok($devices->blocked('check'), 'wrong guesses lock');

    // Sorting, from header facts as Gmail gives them.
    $sorter = new Sorter($store);
    $store->put('names', 'user', ['first' => ['clay']]);
    $meta = static fn (string $id, array $headers, array $labels, string $snippet = ''): array => [
        'id' => $id, 'threadId' => 't' . $id, 'labelIds' => $labels, 'snippet' => $snippet, 'internalDate' => (string) (time() * 1000),
        'payload' => ['headers' => array_map(static fn (string $k, string $v): array => ['name' => $k, 'value' => $v], array_keys($headers), $headers)],
    ];
    $account = $db->insert('accounts', ['email' => 'me@example.com', 'tokens' => 'x', 'created' => time()]);
    $sorter->learnOwnAddresses([['email' => 'me@example.com', 'name' => 'Clay']]);
    $out = $sorter->takeIn($account, [
        'a1' => $meta('a1', ['From' => 'José Núñez <jose@x.com>', 'To' => 'me@example.com', 'Subject' => 'Almuerzo 🍽', 'Message-ID' => '<a1@x>'], ['INBOX', 'UNREAD']),
        'a2' => $meta('a2', ['From' => 'The Daily Brief <hello@dailybrief.com>', 'To' => 'me@example.com', 'Subject' => 'Daily Brief #1', 'Message-ID' => '<a2@x>', 'List-Unsubscribe' => '<mailto:u@x>', 'List-Id' => 'Brief <brief.dailybrief.com>'], ['INBOX', 'UNREAD', 'CATEGORY_UPDATES']),
        'a3' => $meta('a3', ['From' => 'me@example.com', 'To' => 'New Person <new@x.com>', 'Subject' => 'Hello', 'Message-ID' => '<a3@x>'], ['SENT']),
        'a4' => null,
    ]);
    $ok($out['stored'] === 3, 'three emails filed');
    $ok(($store->item('sender', 'jose@x.com')['cls'] ?? '') === 'people', 'a person is a person');
    $ok(($store->item('sender', 'jose@x.com')['name'] ?? '') === 'José Núñez', 'names with accents are kept');
    $ok(($store->item('sender', 'hello@dailybrief.com')['cls'] ?? '') === 'feeds', 'a mailer is not');
    $ok(($store->item('sender', 'new@x.com')['reasons'] ?? '') === 'You wrote to this person', 'someone I wrote to');
    $ok($store->item('sort', '<a2@x>') === ['cat' => 'Newsletter', 'cls' => 'feeds'] || ($store->item('sort', '<a2@x>')['cls'] ?? '') === 'feeds', 'each email gets its place');
    $ok($sorter->pileOf('hello@dailybrief.com') !== null, 'Feed or Noise is worked out');
    $ok($sorter->takeIn($account, ['a1' => $meta('a1', ['From' => 'José Núñez <jose@x.com>', 'To' => 'me@example.com', 'Subject' => 'Almuerzo 🍽', 'Message-ID' => '<a1@x>'], ['INBOX'])])['stored'] === 1
        && (int) $db->val('SELECT COUNT(*) FROM {emails}') === 3, 'an email read again is not stored twice');

    // What devices send.
    $sync = new Sync($store, $sorter);
    $sync->push(1, [
        ['kind' => 'sender', 'k' => 'hello@dailybrief.com', 'data' => ['cls' => 'people', 'src' => 'override', 'pile' => null, 'cat' => 'Newsletter']],
        ['kind' => 'rule', 'k' => 'r1', 'data' => ['uid' => 'r1', 'field' => 'sender', 'pattern' => 'jose@x.com', 'bucket' => 'feeds', 'category' => null, 'at' => 1]],
        ['kind' => 'tag', 'k' => 'Newsletter', 'data' => ['pos' => 1]],
        ['kind' => 'done', 'k' => '<a1@x>', 'data' => ['at' => time()]],
    ]);
    $ok(($store->item('sender', 'hello@dailybrief.com')['src'] ?? '') === 'override' && ($store->item('sender', 'hello@dailybrief.com')['cls'] ?? '') === 'people', 'a move by hand is kept');
    $ok(($store->item('sender', 'jose@x.com')['src'] ?? '') === 'rule', 'a rule sorts mail already read');
    $sync->push(1, [['op' => 'rename-tag', 'from' => 'Newsletter', 'to' => 'Reading']]);
    $ok(($store->item('sender', 'hello@dailybrief.com')['cat'] ?? '') === 'Reading' && $store->item('tag', 'Newsletter') === null, 'a tag is renamed everywhere');
    $seeded = $sync->seed(1, [['k' => 'seeded@x.com', 'item' => ['cls' => 'people', 'src' => 'auto'], 'facts' => ['address' => 'seeded@x.com', 'messagesReceived' => 4]]], time(), ['<old@x>', '<old@x>']);
    $ok($seeded['senders'] === 1 && $sorter->facts('seeded@x.com')['messagesReceived'] === 4 && (int) $db->val('SELECT COUNT(*) FROM {my_ids}') === 1, 'the first sending-up is kept');

    // Many writes in a row keep their order.
    $before = $store->seq();
    for ($i = 0; $i < 200; $i++) {
        $store->put('done', "<bulk-$i@x>", ['at' => $i]);
    }
    $page = $store->since($before, null, 150);
    $ok(count($page['items']) === 150 && $page['more'] && $store->seq() === $before + 200, 'two hundred writes, in order, paged');
    $store->log('info', 'server check');
    $ok((int) $db->val('SELECT COUNT(*) FROM {log}') === 1, 'the log');
} catch (Throwable $e) {
    try {
        $drop();
    } catch (Throwable) {
    }
    fwrite(STDOUT, $e->getMessage() . ' (' . basename($e->getFile()) . ':' . $e->getLine() . ")\n");
    exit(1);
}
$drop();
$left = (int) $db->val("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name LIKE 'pxcheck\\_%'");
echo "All $n server checks passed. Scratch tables left behind: $left.\n";
