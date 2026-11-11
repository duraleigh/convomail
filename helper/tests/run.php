<?php
declare(strict_types=1);

/**
 * Runs the helper's checks:  php helper/tests/run.php [word in a name]
 *
 * Each *_test.php file returns a list of named checks. No outside packages.
 */

namespace Precis\Tests;

require __DIR__ . '/../src/bootstrap.php';
require __DIR__ . '/support.php';
require __DIR__ . '/fakes.php';

error_reporting(E_ALL);
set_error_handler(static function (int $no, string $msg, string $file, int $line): bool {
    // A call silenced with @ stays silent.
    if (!(error_reporting() & $no)) {
        return true;
    }
    throw new \ErrorException($msg, 0, $no, $file, $line);
});
// Problems the helper notes for its own log are not part of a check's output.
ini_set('error_log', PHP_OS_FAMILY === 'Windows' ? 'NUL' : '/dev/null');

$only = $argv[1] ?? null;
$passed = 0;
$failed = [];
$started = microtime(true);
foreach (glob(__DIR__ . '/*_test.php') ?: [] as $file) {
    $checks = require $file;
    foreach ($checks as $name => $check) {
        $full = basename($file, '_test.php') . ': ' . $name;
        if ($only !== null && stripos($full, $only) === false) {
            continue;
        }
        try {
            $check();
            $passed++;
        } catch (\Throwable $e) {
            $failed[] = $full;
            $where = '';
            foreach ($e->getTrace() as $frame) {
                if (isset($frame['file']) && str_ends_with($frame['file'], '_test.php')) {
                    $where = ' (' . basename($frame['file']) . ':' . $frame['line'] . ')';
                    break;
                }
            }
            if ($where === '' && str_ends_with($e->getFile(), '_test.php')) {
                $where = ' (' . basename($e->getFile()) . ':' . $e->getLine() . ')';
            }
            fwrite(STDOUT, "FAIL  $full$where\n      " . str_replace("\n", "\n      ", $e->getMessage()) . "\n");
            if (!$e instanceof Failed) {
                fwrite(STDOUT, '      ' . get_class($e) . ' at ' . basename($e->getFile()) . ':' . $e->getLine() . "\n");
            }
        }
    }
}
$secs = number_format(microtime(true) - $started, 1);
if ($failed === []) {
    fwrite(STDOUT, "All $passed checks passed ($secs s).\n");
    exit(0);
}
fwrite(STDOUT, count($failed) . " failed, $passed passed ($secs s).\n");
exit(1);
