<?php
declare(strict_types=1);

/**
 * The every-minute timer:  php /home/.../precis-helper/cron.php
 *
 * Looks at each mailbox, reads a little more of the first 30 days, moves
 * along reminders and rows put off, and lets the assistant read what is
 * waiting. Says nothing unless something is wrong.
 */

use Precis\App;
use Precis\Clock;
use Precis\CurlHttp;
use Precis\Session;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/src/bootstrap.php';

$app = new App(PRECIS_HOME, new CurlHttp(), new Session());
if (!$app->isSetUp()) {
    exit(0);
}
try {
    $out = (new Clock($app->store(), $app->reader(), $app->readings()))->tick(PRECIS_HOME . DIRECTORY_SEPARATOR . 'clock.lock');
    if (in_array('-v', $argv, true)) {
        echo json_encode($out), "\n";
    }
} catch (Throwable $e) {
    fwrite(STDERR, 'precis helper timer: ' . get_class($e) . ': ' . $e->getMessage() . "\n");
    exit(1);
}
