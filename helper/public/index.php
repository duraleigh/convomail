<?php
// The only file of the helper inside the web folder. PRECIS_ROOT is where
// the rest lives, outside the web folder.
require (getenv('PRECIS_ROOT') ?: dirname(__DIR__)) . '/web.php';
