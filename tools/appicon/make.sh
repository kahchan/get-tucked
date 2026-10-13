#!/bin/sh
# Stand-in icon (Plan AM1). Chrome emits RGBA; the asset compiler rejects alpha, so re-encode via CoreGraphics.
set -e
cd "$(dirname "$0")"
OUT=../../ios/GetTucked/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
TMP=$(mktemp -d)
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
  --default-background-color=00000000 --hide-scrollbars --window-size=1024,1024 \
  --screenshot="$TMP/raw.png" "file://$PWD/appicon.svg" >/dev/null 2>&1
swift - "$TMP/raw.png" "$OUT" <<'S'
import CoreGraphics
import ImageIO
import Foundation
let a = CommandLine.arguments
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dst, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dst)
S
rm -rf "$TMP"
