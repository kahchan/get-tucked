# Get Tucked

A native iOS app that measures cyclist frontal area from calibrated photos. Built for
bikepackers and ultra-distance racers who iterate their setups across a season — bag
placement, layering, posture in the saddle — and want to quantify the trade-offs without
a wind tunnel.

It is a **measurement tool, not a wind tunnel**: it reports frontal area (cm²) and
posture angles from photos, and expresses differences as percentages against a baseline.
It does not predict CdA or model airflow. See `plans/get-tucked-code-spec.html` for the
full spec.

## Stack

Swift 5.9+ · SwiftUI · Vision · ARKit · AVFoundation · PhotoKit · SwiftData · Core Image.
iOS 17 minimum. No backend, no cloud, on-device only.

## Building (local, macOS)

The Xcode project is generated from `ios/project.yml` via [XcodeGen](https://github.com/yonkit/XcodeGen).

```sh
cd ios
xcodegen generate
open GetTucked.xcodeproj   # build/run in Xcode
```

Requires full Xcode (not just Command Line Tools):
`sudo xcode-select -s /Applications/Xcode.app`. Set a signing team in `project.yml` or
Xcode before building to a device.

## Status

Built and on `main`: onboarding → capture → subject matte → frontal area →
save/list/detail, position comparison and a leaderboard, pose check, bike swap with
rescale, design tokens (`Design/Theme.swift`), Dynamic Type/VoiceOver support, and native
swipe-back/tab-swipe gesture navigation. Remaining phases (bag segmentation,
events/timeline, further polish) are in §14 of the code spec. Several recent changes
still need an on-device verification pass — simulator input can't trigger real gestures
or Vision segmentation, see `plans/`. `HANDOFF-REVIEW.md` is a point-in-time review from
before most of this shipped; treat it as history, not current status.

## Marketing site

`docs/` is the public site, served via GitHub Pages from `main`. Static HTML/CSS, no
build step, self-hosted fonts (no third-party CDN, consistent with the app's on-device/
no-analytics posture).

## Repo notes

- `ios/` — the app.
- `docs/` — the marketing site (see above).
- `plans/get-tucked-code-spec.html` — behaviour source of truth. A design spec is being
  added for visual direction.
- `src/`, `verifier/`, `fixtures/`, `index.html`, `package.json` — a **retired** browser
  segmentation spike. Reference only; not part of the app. See `RUNBOOK.md`.
