<?php
declare(strict_types=1);

/**
 * Précis helper: loads classes and settles where its private files live.
 *
 * The helper's code and its private folder (PRECIS_HOME) sit outside the web
 * folder. Only a small index.php is reachable from the web.
 */

namespace Precis;

if (!defined('PRECIS_SRC')) {
    define('PRECIS_SRC', __DIR__);
}
if (!defined('PRECIS_HOME')) {
    $home = getenv('PRECIS_HOME');
    define('PRECIS_HOME', $home !== false && $home !== '' ? rtrim($home, '/\\') : dirname(__DIR__) . DIRECTORY_SEPARATOR . 'data');
}

spl_autoload_register(static function (string $class): void {
    if (!str_starts_with($class, 'Precis\\')) {
        return;
    }
    $file = PRECIS_SRC . DIRECTORY_SEPARATOR . str_replace('\\', DIRECTORY_SEPARATOR, substr($class, 7)) . '.php';
    if (is_file($file)) {
        require $file;
    }
});

// The assistant's library (Anthropic's own) and what it needs, fetched by
// composer into vendor/. The rest of the helper needs no outside code.
if (is_file(dirname(__DIR__) . DIRECTORY_SEPARATOR . 'vendor' . DIRECTORY_SEPARATOR . 'autoload.php')) {
    require_once dirname(__DIR__) . DIRECTORY_SEPARATOR . 'vendor' . DIRECTORY_SEPARATOR . 'autoload.php';
}

mb_internal_encoding('UTF-8');

const VERSION = '0.6.0';
