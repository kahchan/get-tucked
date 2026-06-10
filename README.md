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

Phase 1 (skeleton: onboarding → capture → frontal area → save/list) is implemented in
`ios/`, with known issues documented in `HANDOFF-REVIEW.md`. Remaining phases (pose,
comparison, AR capture enforcement, bag segmentation, events/timeline, polish) are in §14
of the code spec.

## Repo notes

- `ios/` — the app.
- `plans/get-tucked-code-spec.html` — behaviour source of truth. A design spec is being
  added for visual direction.
- `src/`, `verifier/`, `fixtures/`, `index.html`, `package.json` — a **retired** browser
  segmentation spike. Reference only; not part of the app. See `RUNBOOK.md`.
