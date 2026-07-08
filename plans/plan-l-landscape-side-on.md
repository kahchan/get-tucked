# Plan L — Landscape side-on capture

Status: **not started.** Written 2026-07-08 after Kah asked for side-on
capture to support landscape, with the HUD actually reflowing when the
phone is rotated — not the lighter "portrait-locked shell, photo tagged
with rotation metadata" approach that was offered as the cheaper default
and turned down.

**Verification note (same caveat as Plan G, more so):** the Simulator has
no camera and no reliable device-rotation signal — `CMMotionManager`
gravity readings in Simulator are synthetic/flat. HUD layout for the
landscape state can be screenshotted using the existing static-state-seed
technique (force the layout branch on), but the actual rotation-triggered
transition, live AVFoundation rotation, and captured-photo orientation can
only be verified by Kah on a physical device.

## Context

Today the whole app is portrait-only: `project.yml`'s
`UISupportedInterfaceOrientations` is `[Portrait]`, `CameraSession.
configureSession()` hardcodes `videoRotationAngle = 90` on both the
preview layer's connection and the photo-output connection, and every
screen's layout (including `LiveCameraView`'s HUD) assumes a tall, narrow
frame. Side-on wants the opposite: a bike + rider profile is wider than
tall, so a landscape frame gives more useful pixels for the same distance
back.

The ask is scoped to **side-on only** — head-on stays portrait, and nothing
else in the app needs to rotate.

## Flagged decisions for Kah

1. **How to scope orientation to just the side-on screen.** SwiftUI's pure
   App lifecycle has no per-screen orientation override — that hook only
   exists on `UIApplicationDelegate` (`application(_:supportedInterface
   OrientationsFor:)`). This app currently has no `AppDelegate` (`@main
   struct GetTuckedApp: App`, no `@UIApplicationDelegateAdaptor`).
   **Recommendation:** add a minimal `AppDelegate` via
   `@UIApplicationDelegateAdaptor`, implementing that one method, driven by
   a small shared flag (e.g. `OrientationLock.allowsLandscape: Bool`, a
   `@Observable` singleton or similar) that `CaptureView` flips true on
   entering `.pickSideOnPhoto` and false on leaving (including on capture,
   skip, and cancel — every exit path). Every other screen keeps returning
   portrait-only from the delegate hook by default, so this can't leak into
   the rest of the app even if the flag is ever left in a bad state.

2. **Which landscape orientations.** **Recommendation: both**
   `.landscapeLeft` and `.landscapeRight`, not just one — riders will
   naturally rotate whichever way is comfortable, and picking one would be
   an arbitrary papercut. Upside-down portrait stays excluded, matching
   today's behaviour; no clean use case for it here.

3. **What the landscape HUD actually looks like.** `LiveCameraView`'s
   current HUD stacks everything vertically (top bar → `LevelLine` → grown
   `Spacer` → pills/shutter/links, bottom-anchored) — a straight port to
   landscape would crush the controls into a thin strip at one edge and
   waste the vertical space landscape frees up on the sides. **Recommendation:**
   a landscape-specific arrangement — top bar (step chip, ✕) stays anchored
   to the physical top edge of the *image* (not the phone) since that's
   what stays meaningful across rotation; pills + capture button + skip/
   library links move to a vertical rail down one side (trailing edge,
   matching where a right-handed shutter naturally falls) instead of a
   bottom stack. `LevelLine` keeps representing physical roll (unrelated to
   interface orientation) but its screen position/axis needs rethinking for
   landscape — worth a sketch before coding, not an upfront call here.

4. **Mid-rotation transitions.** If the phone rotates *during* the side-on
   step (say, mid-composition), the interface should follow live via the
   normal system rotation animation — no custom handling needed there,
   `UIKit`/`SwiftUI` do this automatically once the delegate permits both
   orientations. The one thing worth deciding: should `CameraPreviewLayer`'s
   and the photo-output's `videoRotationAngle` connections update
   reactively as `UIDevice.current.orientation` (or the existing
   `CMMotionManager` gravity read, which is already immune to the "Portrait
   Orientation Lock" Control Center toggle unlike `UIDevice` notifications)
   changes, so a photo captured mid-rotation still comes out correctly
   oriented? **Recommendation: yes**, derive orientation from the existing
   gravity read (already sampled for LEVEL/PERP) rather than adding
   `UIDevice` orientation notifications — one source of truth, immune to
   the orientation-lock toggle, and no new CoreMotion plumbing.

## Tasks

### L1. `AppDelegate` + orientation-lock flag

Files: new `ios/GetTucked/App/AppDelegate.swift`, `GetTuckedApp.swift`.

- Minimal `NSObject, UIApplicationDelegate` implementing
  `application(_:supportedInterfaceOrientationsFor:)`, reading a shared
  `OrientationLock` flag (new small file, e.g.
  `ios/GetTucked/App/OrientationLock.swift`) — `.portrait` when false,
  `[.portrait, .landscapeLeft, .landscapeRight]` when true.
- Wire via `@UIApplicationDelegateAdaptor(AppDelegate.self)` in
  `GetTuckedApp`.
- `project.yml`: `UISupportedInterfaceOrientations` needs all four values
  listed (the delegate hook can only *restrict* within what Info.plist
  already declares as possible) — regenerate the Xcode project after.

### L2. `CaptureView` toggles the lock around the side-on step

File: `ios/GetTucked/Capture/CaptureView.swift`.

- Set `OrientationLock.allowsLandscape = true` on entering
  `.pickSideOnPhoto`; set it back `false` on every exit path — capture
  (`onCapture` → `.analysingSideOn`), skip (`onSkip` → `.reveal`), and
  cancel (`onCancel` → `dismiss()`). Audit `resetForNewCapture()` too, in
  case a retake re-enters side-on from a landscape-dirty state.

### L3. Landscape HUD layout for `LiveCameraView`

File: `ios/GetTucked/Capture/LiveCameraView.swift`.

- Read current interface orientation (e.g. via a `GeometryReader`'s aspect
  ratio, or `UIDevice.current.orientation` gated behind the same gravity-
  based detection as L4) and branch the HUD `VStack` into the vertical-rail
  arrangement from decision 3 when landscape.
- `StepLabelChip`/`BikeChip`, the ✕, `StatusPillRow`, `CaptureButton`,
  `LibraryFallbackLink`, and the skip button all need landscape-safe
  positions — reuse the existing sub-views, just relaid-out, not rebuilt.
- Only exercised when `showsBikeChip == false` (i.e. the side-on
  configuration) needs to look right in landscape — head-on's `.pickPhoto`
  call site never sets `allowsLandscape`, so it never rotates and its
  layout is unaffected.

### L4. Dynamic capture-rotation to match physical orientation

File: `ios/GetTucked/Capture/LiveCameraView.swift` (`CameraSession`).

- Derive a current `videoRotationAngle` from the existing gravity read
  (extend the roll/pitch math already computing `levelOK`/`perpOK`) instead
  of the hardcoded `90`.
- Apply it to both `CameraPreviewLayer`'s connection (live preview stays
  upright) and `photoOutput`'s connection at capture time (the saved JPEG
  comes out correctly oriented for whichever way the phone was actually
  held).
- `UIImage.normalisedOrientation()` (already run on every captured photo)
  should continue to make this a non-issue downstream — confirm rather
  than assume once real landscape captures exist.

## Acceptance

Side-on capture starts portrait like today; rotating the phone to
landscape mid-step reflows the HUD into the vertical-rail layout from L3,
capture stays gated on LEVEL+PERP throughout, and a photo captured while
the phone is held in landscape saves as a genuinely landscape-shaped
image. Every other screen in the app — including head-on capture — is
unaffected and stays portrait-only. Verified via seeded screenshots for
the landscape HUD layout; live rotation behaviour and captured-photo
orientation need Kah on a physical device (added to
`plans/open-human-steps.md`).
