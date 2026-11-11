<?php
declare(strict_types=1);

/**
 * Prints a joining code for the helper whose private folder is PRECIS_HOME.
 * Used by the app's live check (test/helper_live_test.dart), which runs a
 * real helper on this computer. Command line only.
 */

use Precis\App;
use Precis\CurlHttp;
use Precis\Devices;
use Precis\Session;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/../src/bootstrap.php';

$app = new App(PRECIS_HOME, new CurlHttp(), new Session());
if (!$app->isSetUp()) {
    fwrite(STDERR, "not set up\n");
    exit(1);
}
echo (new Devices($app->store()))->newCode(), "\n";
