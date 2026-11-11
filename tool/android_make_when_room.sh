#!/bin/bash
# Waits until the Ubuntu environment has enough free memory for the Android
# make (other work there may be using it), then runs tool/android_make.sh.
# Gives up after three hours.
#
#   wsl.exe -d Ubuntu -- bash -lc 'bash /mnt/c/Users/clay/Projects/convomail/tool/android_make_when_room.sh [debug|release]'
MODE="${1:-release}"
NEED_MB="${2:-4300}"
tries=0
while [ "$tries" -lt 360 ]; do
  free_mb=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  if [ "$free_mb" -ge "$NEED_MB" ]; then
    echo "room: ${free_mb} MB free at $(date)"
    bash /mnt/c/Users/clay/Projects/convomail/tool/android_make.sh "$MODE"
    tail -25 "$HOME/projects/convomail-make.log"
    exit 0
  fi
  tries=$((tries + 1))
  sleep 30
done
echo "NO-ROOM: still only ${free_mb} MB free after three hours"
exit 3
