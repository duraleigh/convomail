#!/bin/bash
# Makes the Android app. Runs inside Ubuntu (WSL), where the Android tools live.
#
#   From Windows:  wsl.exe -d Ubuntu -- bash -lc 'bash /mnt/c/Users/clay/Projects/convomail/tool/android_make.sh [debug|release] [icons]'
#
# The Windows working copy is the one true copy. This script copies it into
# ~/projects/convomail-make (Flutter's own notes differ between Windows and
# Ubuntu, so the two cannot share a folder), makes the app there, and puts
# the finished file back in the Windows copy under build/android/.
set -u
MODE="${1:-release}"
WIN=/mnt/c/Users/clay/Projects/convomail
WORK="$HOME/projects/convomail-make"
LOG="$HOME/projects/convomail-make.log"
source "$HOME/opt/android-env.sh"
export PATH="$HOME/opt/flutter/bin:$PATH"
exec > "$LOG" 2>&1
echo "started $(date) mode=$MODE"
mkdir -p "$WORK"
rsync -a --delete \
  --exclude .git --exclude build --exclude .dart_tool --exclude .idea \
  --exclude 'windows/flutter/ephemeral' --exclude 'helper/vendor' --exclude 'helper/data' \
  --exclude 'android/local.properties' --exclude 'android/.gradle' --exclude 'android/.kotlin' \
  --exclude '.flutter-plugins-dependencies' --exclude 'android/app/src/main/java/io/flutter/plugins' \
  "$WIN/" "$WORK/" || { echo "COPY FAILED"; echo MAKE-DONE; exit 1; }
cd "$WORK" || exit 1
flutter pub get --enforce-lockfile 2>&1 | tail -4
if [ "${2:-}" = "icons" ]; then
  dart run flutter_launcher_icons 2>&1 | tail -6
  rsync -a android/app/src/main/res/ "$WIN/android/app/src/main/res/"
fi
echo "=== make starts $(date)"
# One file for the chips nearly every phone has (arm64). Always made the
# same way, so each new version installs over the last.
OUT="build/app/outputs/flutter-apk/app-arm64-v8a-$MODE.apk"
# What an earlier make left behind is removed first, so a make that fails
# can never hand back an old app as if it were new.
rm -f "$OUT" "$WIN/build/android/Precis.apk"
flutter build apk "--$MODE" --split-per-abi --target-platform android-arm64 2>&1 | grep -v '^\s*$' | tail -80
CODE="${PIPESTATUS[0]}"
echo "=== make exit: $CODE at $(date)"
if [ "$CODE" = "0" ] && [ -f "$OUT" ]; then
  mkdir -p "$WIN/build/android"
  cp "$OUT" "$WIN/build/android/Precis.apk"
  ls -la "$WIN/build/android/"
  echo "MADE"
else
  echo "NOT-MADE"
fi
echo MAKE-DONE
