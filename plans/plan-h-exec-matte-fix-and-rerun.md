# Execution plan — matte-display fix + clean capture re-run

Status: **done** (Tasks 1-4 executed 2026-07-08, commits `db397b7`,
`776c5f6`, `2104959`). All four coding tasks landed; tests green (36
pass); PHOTO/MASK toggle and bar-width row verified via seeded reveal
screenshots (see task sections below for details). The scale warning
was already positioned above the metric rows near the hero number —
Task 4's reposition concern didn't apply to current code, only the
new bar-width row was added. **Next: Kah runs the experiment protocol
at the bottom of this doc on-device** — that human verdict is still
outstanding.

Written 2026-07-07.
This is a focused execution slice, not new analysis — the full diagnosis lives
in [`plan-h-matte-display-and-storage.md`](plan-h-matte-display-and-storage.md).
Read that plan's "Problem 1 / Problem 2 root cause" sections first; this
document assumes them.

## Purpose

Let Kah re-run the capture experience from scratch with a bike calibrated to
the real bar width (760 mm), and actually *see* the segmented mask this time.
Two independent things are needed:

1. **Make the mask viewable on the reveal** (Plan H tasks H1 + H2). Right now
   the MASK toggle tints the whole frame because a no-alpha grayscale mask is
   fed into `.renderingMode(.template)`, which stencils on alpha. Until this
   is fixed, no capture is visually diagnosable.
2. **A DEBUG "reset all data" control** so Kah can wipe existing bikes +
   positions and go through onboarding → bike setup (at 760 mm) → capture
   fresh. The area is baked at capture time from `bike.handlebarWidthMm`
   (confirmed: `CaptureView.runAnalysis` → `AnalysisEngine.analyse`,
   `PositionMetrics` stores a fixed value), so editing a bike never updates an
   existing position — a fresh capture is the only way to test 760 mm.

Plus a tiny diagnostic addition (Task 4) so the re-run immediately shows
whether the ruler is right.

## Verify loop (every task)

```sh
cd ios && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -project GetTucked.xcodeproj -scheme GetTucked \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

New Swift files need `cd ios && xcodegen generate` before they compile.
UI checks: build + `xcrun simctl io booted screenshot` with the established
static-state `@State`-seed technique (seed, screenshot, **revert before
commit** — grep for `TEMP-SCREENSHOT-SEED` to be sure none survive). There is
no tap-simulation tool. One commit per task, Conventional Commits.

## Task 1 — DEBUG "reset all data" control

Goal: wipe all `Bike` + `Position` records so `ContentView` (shows
`WelcomeView` when `bikes.isEmpty`) drops back to onboarding.

File: `ios/GetTucked/Views/BikeListView.swift`

- In the existing `#if DEBUG` "DEBUG" section (currently just the
  `MATTE CHECK` `HeaderLink`), add a second destructive control:
  `HeaderLink("RESET ALL DATA")` (or a plain red-ish button) that opens a
  `confirmationDialog` (match the app's existing dialog pattern, e.g. in
  `PositionDetailView`).
- On confirm, batch-delete both models and save:
  ```swift
  try? context.delete(model: Position.self)
  try? context.delete(model: Bike.self)
  try? context.save()
  ```
  (`Position.metrics` cascade-deletes via its existing `@Relationship`.)
  `context` is `@Environment(\.modelContext)` — add it to `BikeListView` if
  not already present.
- After deletion the `@Query bikes` in `ContentView` updates reactively →
  `bikes.isEmpty` → `WelcomeView` replaces the whole nav stack. No manual
  path manipulation needed. Verify this actually happens (screenshot: reset →
  lands on WELCOME "GET TUCKED / BEGIN SETUP").
- **DEBUG-only.** Must not appear in release builds.

Commit: `feat(debug): add reset-all-data control to Bikes screen`

## Task 2 — Pure matte-overlay renderer (Plan H · H1)

New file: `ios/GetTucked/Analysis/MatteRenderer.swift` (`#if canImport(UIKit)`).

- `static func tintedOverlay(mask: CGImage, color: UIColor, alpha: CGFloat) -> UIImage?`
  — returns an RGBA image the size of `mask` where foreground pixels
  (luminance ≥ 128) become `color` at `alpha`, background pixels fully
  transparent (alpha 0). **Stride by `mask.bytesPerRow`**, not a linear scan —
  same row-padding discipline as `AnalysisMath.countForegroundPixels` (see
  commit `bd8a273`); a linear scan reads trailing row padding as pixels.
- Factor the per-pixel decision into a small pure helper taking a raw byte
  buffer + `width/height/bytesPerRow` (mirrors `AnalysisMath.countForegroundPixels`'s
  shape) so it's unit-testable without a real `CGImage`.
- Unit test in `ios/GetTuckedTests/`: build a tiny synthetic mask buffer with
  one foreground and one background (and one padding) byte; assert the
  foreground maps to opaque-tinted RGBA and background/padding map to alpha 0.

Commit: `feat(analysis): add MatteRenderer for a proper tinted mask overlay (Plan H1)`

## Task 3 — Reveal uses the overlay, not template rendering (Plan H · H2)

File: `ios/GetTucked/Capture/CaptureView.swift` — `RevealStep`, the `ZStack`
around line 345–356.

- Replace:
  ```swift
  Image(uiImage: result.maskImage)
      .renderingMode(.template)
      .scaledToFit()
      .foregroundStyle(Theme.Palette.acc.opacity(0.5))
  ```
  with an `Image(uiImage: overlay).resizable().scaledToFit()` where `overlay`
  = `MatteRenderer.tintedOverlay(mask: result.maskImage.cgImage!, color:
  UIColor(Theme.Palette.acc), alpha: 0.5)`. Guard the `cgImage` unwrap (fall
  back to no overlay rather than force-unwrap).
- Compute the overlay once (a `let` derived from `result`, or `@State` set in
  `.onAppear`) — not every layout pass.
- **Acceptance:** on the reveal MASK view only the rider is tinted; wall /
  carpet / sofa show through untinted. PHOTO/MASK toggle still works.
  Screenshot both PHOTO and MASK states (seed `RevealStep` with a synthetic
  photo + a synthetic mask that is foreground in the centre only, so the
  tinting is obviously localised).

Commit: `fix(capture): composite mask as transparent overlay, not template tint (Plan H2)`

## Task 4 — Surface the ruler on the reveal (diagnostic slice of Plan H · H5)

So the re-run instantly shows whether the scale is sane, next to the existing
shoulder-width sanity number.

File: `ios/GetTucked/Capture/CaptureView.swift` — `RevealStep` metric rows
(near the existing `MetricRow(key: "Scale", ...)` / shoulder-width rows).

- Add a `MetricRow(key: "Bar width", value: "\(Int(barWidthMm)) mm")` showing
  the handlebar width actually used for this capture. `RevealStep` will need
  that value passed in — thread `selectedBike?.handlebarWidthMm` (or the
  `handlebarWidthMm` already on hand in the capture flow) into `RevealStep`.
- Leave the A3 `scaleWarning` amber line where it is functionally, but ensure
  it renders **above the metric rows / near the hero number** so it isn't
  below the scroll fold (Kah missed it last time). Do not change its logic —
  only its position/visibility.
- Do **not** auto-correct or fudge any number (spec §3 — every displayed
  number must be defensible).

Commit: `feat(capture): show handlebar width used + lift scale warning above the fold (Plan H5 slice)`

## Out of scope (leave for later / Plan H proper)

- H3 (persist `maskData` on `Position`) and H4 (MASK toggle on
  `PositionDetailView`) — not needed to diagnose a fresh capture.
- The H5 aspect-ratio guard and the soft-block product decision.
- Plan G (side-on live capture).

## Experiment protocol (for Kah, after the agent finishes)

1. Bikes screen → **RESET ALL DATA** → confirm → should land on onboarding.
2. Onboard, create the bike with handlebar width **760 mm** (the real bar).
3. Capture the same head-on pose. On the reveal, note and report:
   - **Frontal area** (cm²) and its ± line,
   - **Shoulder width** (cm) and whether the amber SCALE warning shows,
   - **Bar width** row (should read 760 mm),
   - and eyeball the **MASK** toggle: does the tint hug the rider, or bleed
     into background / miss limbs? Screenshot it.
4. Those four readings + the mask screenshot discriminate the two hypotheses
   in `plan-h`: linear shoulder-width vs squared-area scaling tells us whether
   the ruler is now right, and the visible mask tells us whether segmentation
   is capturing the correct region.
