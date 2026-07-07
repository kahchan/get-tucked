# Plan G — Side-on live capture

Status: **not started**. Written 2026-07-07 after Kah noticed side-on capture
only offers a library picker (`PhotoPickStep`), never got the live-camera
treatment head-on has (`LiveCameraView` — HUD, LEVEL/PERP enforcement).

**Verification note (important, more so than any prior plan):** the iOS
Simulator has no camera hardware — `AVCaptureDevice.default(...)` returns
`nil` there, so `CameraSession.configureSession()`'s guard fails silently and
the session never starts. The HUD still *renders* (so layout/copy/skip-button
placement can be screenshotted via the existing static-state-seeding
technique), but the live feed, LEVEL/PERP gating feel, and shutter behaviour
can only be verified by Kah on a physical device. Same verify loop as Plans
A–F otherwise (`xcodebuild test`, Conventional Commits, one commit per task).

---

## Context

Head-on capture (`CaptureView`'s `.pickPhoto` step) uses `LiveCameraView`:
full-screen AVFoundation preview, CoreMotion-based LEVEL/PERP tilt detection
(gates the shutter), a throttled Vision BG-confidence pill (advisory only),
and a "SHOOTING ON [bike] ▾" chip that opens `BikePickerSheet`. Side-on
(`.pickSideOnPhoto` step) uses `PhotoPickStep` instead — just a
`PhotosPicker` button and a "SKIP SIDE-ON" ghost button. This plan brings
side-on to the same live-capture standard, reusing `LiveCameraView` rather
than duplicating it.

## Flagged decisions for Kah

These need a call before/while implementing — recommendations given, but
they're real product choices, not obvious defaults.

1. **Drop the BG pill for side-on.** BG confidence is a segmentation-quality
   proxy for computing *frontal area* from a matte — side-on doesn't compute
   an area or a matte at all, only pose landmarks (`VNDetectHumanBodyPoseRequest`
   → torso/hip angle). Showing a pill that measures something irrelevant to
   what side-on actually needs would be confusing. **Recommendation: show
   LEVEL + PERP only for side-on**, matching the existing `allPassed = levelOK
   && perpOK` gate (BG has always been advisory-only, never part of the gate,
   so dropping its *display* changes nothing about when the shutter unlocks).

2. **Hide the bike-chip/switcher for side-on.** The bike was already locked
   in during head-on capture for this same position — letting someone switch
   bikes mid-pair would silently desync the scale reference between the two
   photos. **Recommendation: replace the tappable bike chip with a plain,
   non-interactive step-label chip** ("SIDE-ON · 2 OF 2") in the same HUD
   position, styled like the existing `BikeChip` but without the `▾` picker
   affordance.

3. **"Skip" needs to be a distinct action from "cancel."** `LiveCameraView`'s
   `✕` currently means "abandon the whole capture" (`onCancel` → `dismiss()`).
   Side-on is optional — skipping it should fall through to `.reveal` with
   the head-on result intact, not discard everything. These are semantically
   different and both need a control. **Recommendation: add a new
   `onSkip: (() -> Void)?` param to `LiveCameraView`** (`nil` for head-on),
   rendered as a small "SKIP SIDE-ON" ghost-style text link — keeping `✕` as
   "abandon everything" and skip as its own explicit, discoverable action
   (matches your stated preference for explicit controls over hidden gestures
   — see `feedback_design_preferences.md`).

4. **Keep a "choose from library" fallback, or go live-only?**
   **Recommendation: keep both** — a small "OR CHOOSE FROM LIBRARY" ghost
   link below the shutter button, reusing the existing `PhotosPicker` code
   path from `PhotoPickStep`, so a device/lighting problem with live capture
   doesn't leave side-on with no path forward at all.

## Tasks

### G1. Generalise `LiveCameraView` for both capture steps

File: `ios/GetTucked/Capture/LiveCameraView.swift`

- Add params: `showsBikeChip: Bool = true`, `stepLabel: String? = nil`
  (shown instead of the bike chip when `showsBikeChip` is `false`),
  `onSkip: (() -> Void)? = nil` (renders the skip link when non-nil),
  `showsBackgroundPill: Bool = true`.
- `StatusPillRow` drops the BG pill when `showsBackgroundPill` is `false`
  (`CameraSession` keeps computing `bgOK` internally either way — reusing the
  session unchanged is simpler than forking its throttled segmentation logic
  for a value that's advisory/unused in this mode anyway).
- No change to `CameraSession`, `CameraPreviewLayer`, or the AVFoundation/
  CoreMotion plumbing — this task is HUD composition only.

### G2. Wire side-on to `LiveCameraView`

File: `ios/GetTucked/Capture/CaptureView.swift`

- Replace the `.pickSideOnPhoto` case's `PhotoPickStep` with
  `LiveCameraView(bike: selectedBike, showsBikeChip: false, stepLabel:
  "SIDE-ON · 2 OF 2", onCapture:, onCancel:, onSkip:)`.
- `onCapture`: set `sideOnImage`, set `sideOnAssetIdentifier = nil` (live
  capture has no PHAsset identifier — mirrors how head-on already handles
  this), advance to `.analysingSideOn`, run `runSideOnAnalysis()`.
- `onSkip`: advance straight to `.reveal` (matches `PhotoPickStep`'s existing
  `onSkip` behaviour, being removed from that view).
- `onCancel`: same as head-on — `dismiss()` abandons the whole capture.
- Keep the "choose from library" fallback per decision 4 — either as a small
  link inside the generalised `LiveCameraView` HUD, or by keeping a
  lightweight `PhotoPickStep`-style sheet reachable from that link. Exact
  placement is a detail to settle while implementing, not upfront.

### G3. Stop double-chroming the side-on step

File: `ios/GetTucked/Capture/CaptureView.swift`

- The `if step != .pickPhoto { NavHeader(...) }` wrapper must also exclude
  `.pickSideOnPhoto` once it's a full-screen live camera view (it owns its
  own HUD chrome, same reasoning as why `.pickPhoto` is already excluded) —
  otherwise there'd be a redundant NavHeader bar on top of the camera HUD.

## Acceptance

Side-on capture opens the live camera with LEVEL + PERP pills (no BG pill),
a non-interactive "SIDE-ON · 2 OF 2" label instead of a bike chip, a working
shutter gated on LEVEL+PERP, an explicit "SKIP SIDE-ON" control that reaches
Reveal without a photo, a working "✕" that abandons the whole capture, and
(if decision 4 lands as recommended) a library fallback. Verified via
simulator screenshot for HUD layout/copy; actual capture behaviour needs
Kah on a physical device.
