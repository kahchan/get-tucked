#!/bin/sh
# Renders App Store screenshots (1320x2868, 6.9") from shots.html into website images/appstore-v2/.
# Sources live in the gitignored "website images/" folder.
cd "$(dirname "$0")"
out="../../website images/appstore-v2"; mkdir -p "$out"
for n in ${@:-1 2 3 4 5 6}; do
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=1320,2868 --allow-file-access-from-files \
    --virtual-time-budget=3000 --screenshot="/tmp/shot-$n.png" "file://$PWD/shots.html?n=$n" 2>/dev/null
  # App Store rejects alpha: flatten to JPEG
  sips -s format jpeg -s formatOptions 92 "/tmp/shot-$n.png" --out "$out/0$n.jpg" >/dev/null && echo "0$n.jpg"
done
