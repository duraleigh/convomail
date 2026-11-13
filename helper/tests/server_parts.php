<?php
declare(strict_types=1);

/**
 * The shape of one email, as Gmail holds it: each part's kind, whether it is
 * a file, the file's ending (never its name), its size, and how deep it is
 * nested. Prints no names, no subjects, no words of the email.
 *
 *   php server_parts.php WORD     the newest email whose sender's name contains WORD
 */

use Precis\App;
use Precis\CurlHttp;
use Precis\Session;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

$app = new App(PRECIS_HOME, new CurlHttp(), new Session());
$store = $app->store();
$db = $store->db;
$word = (string) ($argv[1] ?? '');
if ($word === '') {
    fwrite(STDERR, "say part of the sender's name\n");
    exit(2);
}
$e = $db->one('SELECT id, account_id, gmail_id, at, cls, inbox FROM {emails} WHERE is_from_me = 0 AND gone = 0 AND from_name LIKE ? ORDER BY at DESC LIMIT 1', ['%' . $word . '%']);
if ($e === null) {
    echo "no email from a sender with that in their name\n";
    exit(0);
}
$zone = $app->readings()->zone();
echo 'newest email from that sender: came ' . gmdate('D M j H:i', (int) $e['at'] + $zone * 60) . ' | filed as ' . $e['cls'] . ' | in the inbox: ' . ((int) $e['inbox'] === 1 ? 'yes' : 'no') . "\n";
$full = $app->google()->full((int) $e['account_id'], (string) $e['gmail_id']);
if ($full === null) {
    echo "Gmail no longer has it\n";
    exit(0);
}
$files = 0;
$walk = static function (array $part, int $depth) use (&$walk, &$files): void {
    $headers = [];
    foreach ($part['headers'] ?? [] as $h) {
        $headers[strtolower((string) ($h['name'] ?? ''))] = (string) ($h['value'] ?? '');
    }
    $name = (string) ($part['filename'] ?? '');
    $ending = $name === '' ? '' : strtolower(pathinfo($name, PATHINFO_EXTENSION));
    $how = strtolower(trim(explode(';', $headers['content-disposition'] ?? '')[0]));
    $isFile = $name !== '' || isset($part['body']['attachmentId']);
    $files += (int) ($name !== '');
    echo str_repeat('  ', $depth) . '- ' . strtolower((string) ($part['mimeType'] ?? '?'))
        . ($name === '' ? '' : ' | a file ending .' . ($ending === '' ? '(none)' : $ending))
        . ($how === '' ? '' : ' | sent as ' . $how)
        . (isset($headers['content-id']) ? ' | has a content id' : '')
        . ($isFile ? ' | ' . (int) ($part['body']['size'] ?? 0) . ' bytes' . (isset($part['body']['attachmentId']) ? ', fetched separately' : ', carried inside') : '')
        . "\n";
    foreach ($part['parts'] ?? [] as $child) {
        if (is_array($child)) {
            $walk($child, $depth + 1);
        }
    }
};
$walk(is_array($full['payload'] ?? null) ? $full['payload'] : [], 0);
echo 'parts with a file name, at any depth: ' . $files . "\n";
