#!/bin/sh
# Renders App Store creative assets from creative.html into website images/appstore-v2/creative/:
# header 21:9 (3840x1646) and search results 3:2 (3840x2560), PNG with no alpha
# (the header upload rejects JPEG despite Apple's spec table).
cd "$(dirname "$0")"
out="../../website images/appstore-v2/creative"; mkdir -p "$out"
render() { # name width height
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=$2,$3 --allow-file-access-from-files \
    --virtual-time-budget=3000 --screenshot="/tmp/creative-$1.png" "file://$PWD/creative.html?a=$1" 2>/dev/null
  swift flatpng.swift "/tmp/creative-$1.png" "$out/$1-$2x$3.png" && echo "$1-$2x$3.png" || echo "FAILED $1"
}
render header 3840 1646
render search 3840 2560
