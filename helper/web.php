<?php
declare(strict_types=1);

/**
 * The helper's front door. The small index.php in the web folder requires
 * this file; everything else lives outside the web folder.
 */

use Precis\App;
use Precis\CurlHttp;
use Precis\Request;
use Precis\Session;

require __DIR__ . '/src/bootstrap.php';

ini_set('display_errors', '0');
$request = Request::fromGlobals();
$device = str_starts_with($request->path, '/api/') || str_starts_with($request->path, '/hook/');
// Devices and Google's notice carry no cookie, so no session is opened for them.
$session = $device ? new Session() : Session::live($request->https);
(new App(PRECIS_HOME, new CurlHttp(), $session))->handle($request)->send();
