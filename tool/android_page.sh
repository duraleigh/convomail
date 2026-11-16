#!/bin/sh
# precis.clayaiken.com/android: the download page for the Android app.
#
#   tool/android_page.sh make    put the page and the app file together in build/android-page
#   tool/android_page.sh put     make it, put it on the site, and check it from outside
#
# The app file is build/android/Precis.apk, the same one that goes on the
# phone (tool/android_make_when_room.sh release). Run "put" after every new
# phone version. Nothing of the helper is touched: the page is a folder of its
# own inside the web folder.
set -eu

HOST="${PRECIS_SSH_HOST:-76.13.207.102}"
PORT="${PRECIS_SSH_PORT:-65002}"
USER_AT="${PRECIS_SSH_USER:-u227274523}"
KEY="${PRECIS_SSH_KEY:-$HOME/.ssh/precis_helper}"
KNOWN="${PRECIS_SSH_KNOWN:-$HOME/.ssh/precis_helper_known_hosts}"
WEB="${PRECIS_WEB_DIR:-domains/clayaiken.com/public_html/precis}"
SITE="${PRECIS_SITE:-https://precis.clayaiken.com}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
APK="$HERE/build/android/Precis.apk"
OUT="$HERE/build/android-page"

remote() {
  ssh -i "$KEY" -p "$PORT" -o IdentitiesOnly=yes -o BatchMode=yes -o PasswordAuthentication=no \
      -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN" -o ConnectTimeout=20 "$USER_AT@$HOST" "$@"
}

make() {
  [ -f "$APK" ] || { echo "make the phone version first: there is no build/android/Precis.apk" >&2; exit 1; }
  rm -rf "$OUT"; mkdir -p "$OUT"
  cp "$HERE/android-page/index.html" "$HERE/android-page/android.css" "$HERE/android-page/.htaccess" "$OUT/"
  cp "$HERE/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" "$OUT/icon.png"
  cp "$APK" "$OUT/Precis.apk"
  BYTES="$(wc -c < "$APK" | tr -d ' ')"
  SIZE="$(( (BYTES + 524288) / 1048576 ))"
  DATE="$(date -r "$APK" '+%B %-d, %Y')"
  sed -i "s/__SIZE__/$SIZE/g; s/__DATE__/$DATE/g" "$OUT/index.html"
  if grep -q "__" "$OUT/index.html"; then echo "a blank on the page was not filled in" >&2; exit 1; fi
  echo "made the page: $SIZE MB, $DATE"
}

case "${1:-}" in
  make)
    make
    ;;
  put)
    make
    WANT="$(sha256sum "$OUT/Precis.apk" | cut -c1-64)"
    # Goes up beside the live folder and is checked there; then the two swap, so the address never serves half a page.
    tar -cf - -C "$OUT" . | remote "set -e; cd ~/'$WEB'; rm -rf android.new; mkdir android.new; tar -xf - -C android.new; test \"\$(sha256sum android.new/Precis.apk | cut -c1-64)\" = '$WANT'; rm -rf android.old; if [ -d android ]; then mv android android.old; fi; mv android.new android; rm -rf android.old; ls -la android | awk '{print \$5, \$9}'"
    echo "--- from outside"
    curl -s -o /dev/null -w "the address without the slash: %{http_code} -> %{redirect_url}\n" "$SITE/android"
    curl -s -o /dev/null -w "the page: %{http_code} %{content_type}\n" "$SITE/android/"
    curl -sI "$SITE/android/Precis.apk" | grep -i "^HTTP\|^content-type\|^content-length\|^content-disposition\|^cache-control\|^x-robots-tag" | tr -d '\r'
    GOT="$(curl -s "$SITE/android/Precis.apk" | sha256sum | cut -c1-64)"
    [ "$GOT" = "$WANT" ] || { echo "the file that comes down is NOT the one that went up" >&2; exit 1; }
    echo "the file that comes down is the one that went up, byte for byte"
    ;;
  *)
    sed -n '2,10p' "$0"
    exit 2
    ;;
esac
