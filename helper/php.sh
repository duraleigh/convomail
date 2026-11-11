#!/bin/sh
# Runs PHP with the extra pieces the helper's checks need on this PC.
exec php -d extension_dir=C:/PHP/ext -d extension=pdo_sqlite -d extension=sqlite3 -d memory_limit=512M "$@"
