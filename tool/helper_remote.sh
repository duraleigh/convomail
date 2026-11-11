#!/bin/sh
# Talks to the hosting account that runs the Précis helper, with the
# helper's own access key (never a password).
#
#   tool/helper_remote.sh check           is the key let in? what does the server have?
#   tool/helper_remote.sh install         put the helper's program in place (or update it)
#   tool/helper_remote.sh webroot DIR     put the small index.php and .htaccess in the web folder DIR
#   tool/helper_remote.sh servercheck     prove the helper's storage on the live kind of database
#   tool/helper_remote.sh counts          how the live helper is doing, in counts only
#   tool/helper_remote.sh resort          sort again every sender it holds mail from (counts only)
#   tool/helper_remote.sh trial ARGS       the assistant's test week and its settings (counts only); see helper/tests/server_trial.php
#   tool/helper_remote.sh trialrun N       read the test week with N workers at once, in the background
#   tool/helper_remote.sh trialdone        whether the workers have finished, and remove the runner when they have
#   tool/helper_remote.sh run 'COMMAND'   run one command there
#
# The helper lives in ~/precis-helper, outside any web folder. Its private
# files (config, sealing key, lock) are in ~/precis-helper/data and are never
# copied from here or to here.
set -eu

HOST="${PRECIS_SSH_HOST:-76.13.207.102}"
PORT="${PRECIS_SSH_PORT:-65002}"
USER_AT="${PRECIS_SSH_USER:-u227274523}"
KEY="${PRECIS_SSH_KEY:-$HOME/.ssh/precis_helper}"
KNOWN="${PRECIS_SSH_KNOWN:-$HOME/.ssh/precis_helper_known_hosts}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

remote() {
  ssh -i "$KEY" -p "$PORT" -o IdentitiesOnly=yes -o BatchMode=yes -o PasswordAuthentication=no \
      -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN" -o ConnectTimeout=20 "$USER_AT@$HOST" "$@"
}

case "${1:-}" in
  check)
    remote 'echo "in as $(whoami)"; php -v | head -1; php -m | grep -i -E "^(pdo_mysql|curl|openssl|mbstring|iconv|json)$" | tr "\n" " "; echo; ls -d ~/precis-helper 2>/dev/null || echo "helper not installed yet"; ls -d ~/domains/clayaiken.com/public_html/precis 2>/dev/null || echo "web folder for precis not there yet"'
    ;;
  install)
    # Only the program: src, web.php, cron.php, and the list of outside
    # libraries (the assistant's). Never the private folder. The libraries
    # themselves are fetched on the server, before the new program goes live.
    tar -czf - -C "$HERE/helper" src web.php cron.php composer.json composer.lock | remote 'set -e; mkdir -p ~/precis-helper/data; chmod 700 ~/precis-helper ~/precis-helper/data; rm -rf ~/precis-helper/src.new; mkdir ~/precis-helper/src.new; tar -xzf - -C ~/precis-helper/src.new; cd ~/precis-helper; if ! cmp -s src.new/composer.lock composer.lock || [ ! -f vendor/autoload.php ]; then cp src.new/composer.json src.new/composer.lock .; composer2 install --no-dev --no-interaction --no-progress --optimize-autoloader 2>&1 | tail -3; fi; rm -rf src.old; [ -d src ] && mv src src.old; mv src.new/src src; mv -f src.new/web.php src.new/cron.php .; rm -rf src.new src.old; echo "program files: $(find src web.php cron.php -type f -name "*.php" | wc -l) | library folders: $(ls vendor 2>/dev/null | wc -l)"'
    ;;
  webroot)
    DIR="${2:?the web folder, for example domains/clayaiken.com/public_html/precis}"
    tar -czf - -C "$HERE/helper/public" index.php .htaccess | remote "set -e; cd ~/'$DIR'; tar -xzf -; printf '%s\n' '<?php' '// The only file of the Précis helper inside the web folder.' \"require '/home/$USER_AT/precis-helper/web.php';\" > index.php; ls -la index.php .htaccess | awk '{print \$1, \$5, \$9}'"
    ;;
  servercheck)
    # Proves the helper's storage on the live kind of database, in scratch tables it removes.
    remote 'cat > ~/precis-helper/server_check.php' < "$HERE/helper/tests/server_check.php"
    remote 'php ~/precis-helper/server_check.php; code=$?; rm -f ~/precis-helper/server_check.php; exit $code'
    ;;
  counts)
    # How the live helper is doing, in counts only. Reads; changes nothing.
    remote 'cat > ~/precis-helper/server_counts.php' < "$HERE/helper/tests/server_counts.php"
    remote 'php ~/precis-helper/server_counts.php; code=$?; rm -f ~/precis-helper/server_counts.php; exit $code'
    ;;
  resort)
    # Sorts again every sender the live helper holds mail from; says how much changed, in counts.
    remote 'cat > ~/precis-helper/server_resort.php' < "$HERE/helper/tests/server_resort.php"
    remote 'php ~/precis-helper/server_resort.php; code=$?; rm -f ~/precis-helper/server_resort.php; exit $code'
    ;;
  trial)
    shift
    remote 'cat > ~/precis-helper/server_trial.php' < "$HERE/helper/tests/server_trial.php"
    remote "php ~/precis-helper/server_trial.php $*; code=\$?; pgrep -u \$(id -u) -f 'server_trial.php run' >/dev/null || rm -f ~/precis-helper/server_trial.php; exit \$code"
    ;;
  trialrun)
    N="${2:-3}"
    remote 'cat > ~/precis-helper/server_trial.php' < "$HERE/helper/tests/server_trial.php"
    remote "cd ~/precis-helper; i=0; while [ \$i -lt $N ]; do nohup php server_trial.php run \$i $N > data/trial.\$i.log 2>&1 & i=\$((i+1)); done; sleep 1; echo \"started $N workers\""
    ;;
  trialdone)
    remote 'cd ~/precis-helper; if pgrep -u $(id -u) -f "server_trial.php run" >/dev/null; then echo "still reading: $(pgrep -u $(id -u) -f "server_trial.php run" | wc -l) workers"; else echo "workers finished"; cat data/trial.*.log 2>/dev/null; rm -f data/trial.*.log server_trial.php; fi'
    ;;
  run)
    shift
    remote "$@"
    ;;
  *)
    sed -n '2,15p' "$0"
    exit 2
    ;;
esac
