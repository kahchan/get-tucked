#!/bin/sh
# Re-render docs/og-hero.png (1200x630, no alpha) from og-hero.html. Chrome emits RGBA; flatpng re-encodes without alpha.
set -e
cd "$(dirname "$0")"
TMP=$(mktemp -d)
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars --virtual-time-budget=3000 --allow-file-access-from-files \
  --force-device-scale-factor=1 --window-size=1200,630 --screenshot="$TMP/raw.png" "file://$PWD/og-hero.html" >/dev/null 2>&1
swift ../../marketing/store-shots/flatpng.swift "$TMP/raw.png" ../og-hero.png
rm -rf "$TMP"
