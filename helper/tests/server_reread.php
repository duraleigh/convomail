<?php
declare(strict_types=1);

/**
 * Has the assistant read again every email whose reading may name someone
 * the email itself does not:  php server_reread.php [go]
 *
 * A reading is suspect when it is of a reply from a person, and its line
 * or its ask uses a name that is in the Subject but is not the sender's or
 * the owner's. Without "go" it only counts. With "go" those emails are put
 * back in line; the every-minute timer reads them again under the current
 * rules. Prints counts only: no names, no subjects, no mail.
 */

use Precis\App;
use Precis\CurlHttp;
use Precis\Readings;
use Precis\Session;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

$app = new App(PRECIS_HOME, new CurlHttp(), new Session());
$db = $app->store()->db;
$owner = '';
foreach ($app->store()->itemsOf('me') as $address => $d) {
    $owner .= ' ' . $address . ' ' . (string) ($d['name'] ?? '');
}
$rows = $db->all("SELECT e.id, e.subject, e.from_name, e.from_addr, e.inbox, r.line, r.ask, r.focus
    FROM {emails} e JOIN {readings} r ON r.email_id = e.id
    WHERE e.is_from_me = 0 AND e.cls = 'people' AND e.gone = 0 AND e.read_state = ?", [Readings::READ]);
$suspect = [];
$focus = 0;
foreach ($rows as $r) {
    $ctx = ['person' => true, 'subject' => (string) $r['subject'], 'shown' => (string) $r['from_name'] . ' ' . (string) $r['from_addr'] . $owner];
    if (Readings::borrowedNames(['line' => (string) $r['line'], 'ask' => (string) $r['ask']], $ctx) !== []) {
        $suspect[] = (int) $r['id'];
        $focus += (int) $r['focus'];
    }
}
echo 'readings of replies from people: ' . count($rows) . ' | that use a name found in the Subject and not in who it is from: ' . count($suspect) . ' | of those, in Focus: ' . $focus . "\n";
if (($argv[1] ?? '') === 'go' && $suspect !== []) {
    foreach (array_chunk($suspect, 200) as $chunk) {
        $db->run('UPDATE {emails} SET read_state = ?, read_tries = 0, read_after = 0 WHERE inbox = 1 AND id IN (' . implode(',', array_map('intval', $chunk)) . ')', [Readings::NEW]);
    }
    echo 'put back in line to be read again: ' . (int) $db->val('SELECT COUNT(*) FROM {emails} WHERE read_state = ? AND id IN (' . implode(',', array_map('intval', $suspect)) . ')', [Readings::NEW]) . " (only mail still in the inbox is read)\n";
}
echo 'waiting to be read now: ' . (int) $db->val('SELECT COUNT(*) FROM {emails} WHERE read_state IN (?, ?, ?)', [Readings::NEW, Readings::WAITING, Readings::RETRY]) . "\n";
