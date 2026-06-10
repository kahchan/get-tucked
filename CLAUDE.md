# Get Tucked

## What this is

A native iOS app that measures cyclist frontal area from calibrated photos, to help
bikepackers and ultra-distance racers iterate their setups. The user photographs a
position, the app segments the rider, computes frontal area in cm², and compares
positions. See the full behaviour spec below.

**Source of truth for behaviour:** [`plans/get-tucked-code-spec.html`](plans/get-tucked-code-spec.html)
(the engineering spec). A companion **design spec** governs visual direction, tone, and
hero flows — design assets are being added to the repo.

## Where we are

- **Stack decided: native iOS.** Swift 5.9+, SwiftUI, Vision (segmentation + pose),
  ARKit (capture pose), AVFoundation, PhotoKit, SwiftData, Core Image. iOS 17 minimum.
  No backend, no cloud, no third-party services.
- **Development is local, on the Mac.** We are *not* using Codespaces / cloud agents /
  Expo / React Native. That earlier direction (and the agent-buildability concerns behind
  it) is retired — see "History" below.
- **Phase 1 is built** (`ios/`): Bike model, single-bike onboarding, photo-pick →
  segment → frontal area, save/list/detail. It has known correctness issues in the
  frontal-area math — read [`HANDOFF-REVIEW.md`](HANDOFF-REVIEW.md) before extending it.

Build phases (skeleton → pose/comparison/AR → bags → events/timeline/self-test → polish)
are defined in §14 of the code spec. Each phase ships a coherent working slice.

## Building and running (local, Mac)

The Xcode project is generated from `ios/project.yml` by [XcodeGen](https://github.com/yonkit/XcodeGen)
— `project.yml` is the source of truth, not the `.xcodeproj`.

```sh
cd ios
xcodegen generate          # regenerate GetTucked.xcodeproj from project.yml
open GetTucked.xcodeproj    # then build/run in Xcode (⌘R)
```

Gotchas:
- **Full Xcode must be selected**, not Command Line Tools:
  `sudo xcode-select -s /Applications/Xcode.app` (else `xcodebuild` errors out).
- Regenerate the project after editing `project.yml` or adding/removing source files.
- `DEVELOPMENT_TEAM` in `project.yml` is empty — set it (or set signing in Xcode) before
  building to a device.

## When to STOP and ask the human

- Before showing any number in the UI that you can't explain in two sentences. The spec
  (§3) is strict: every displayed number must be defensible. No fake precision.
- Before adding any Swift package or third-party dependency — propose it first.
- Before changing the data model in a way that needs a SwiftData migration stage.
- When a design decision isn't covered by the code spec or the design spec.

## Design language (overrides the global default)

This project has **its own visual system** — do **not** apply the global mire·studio
default (rounded 25px, pale pills). The design file (reviewed 2026-06-10) is the opposite:

- Dark canvas (near-black `#080808`), **acid-yellow** accent `#D9F020`, amber `#E8A020`.
- **0px border radius everywhere** — no rounded corners.
- `Space Mono` for numbers/labels, `Barlow Condensed` (bold) for headings.
- No tab bar — a single linear flow with a hamburger index menu.

Phase 1's current UI is plain system SwiftUI and predates this — Phase 2 reworks it.
**Implement design tokens (`Theme.swift`) FIRST in Phase 2**, before building new screens,
so every view is built against the tokens, not system styling. Design assets being added
to the repo are the authority for specifics.

## Conventions

- Conventional Commits (`feat:`, `fix:`, `chore:`, `refactor:`).
- Functional SwiftUI; no force-unwraps in analysis code; keep the area/scale math in
  `AnalysisEngine` testable and pure where possible.
- Comments only for non-obvious *why* (the scale/intrinsics/uncertainty math qualifies).
- Match the existing file layout under `ios/GetTucked/` (App / Models / Views / Capture /
  Analysis).
- The user cares deeply about visual polish — once the design spec lands, styling is not
  optional.

## History — the segmentation spike (retired)

Before committing to native, a throwaway browser spike (`src/`, `verifier/`, `fixtures/`,
`index.html`, `package.json`) tested whether cross-platform MediaPipe segmentation was
good enough to justify an Expo/React Native stack. That question is closed: we went
native with Apple Vision. **Do not develop the browser spike further.** It remains in the
repo as reference only. Note: it tested MediaPipe, not Vision — so Apple Vision's matte
quality on the hard case (full-body cyclist, cluttered background) is still worth a quick
eyeball check (see `HANDOFF-REVIEW.md`).
