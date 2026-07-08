# Plan L — Landscape side-on capture

Status: **done** (L1–L4 executed 2026-07-08, commits `9b98fee`,
`27e735b`, `051e61f`, `2f17dfc`). All four tasks landed, including the
three correctness traps and the gravity→bucket→rotation mapping added
to this doc before implementation. Tests green (63 pass, up from 54 —
9 new `OrientationBucketTests` covering the mapping tables and the
hysteresis behaviour at the 45° diagonal). L3's HUD layout was
verified via a forced-branch screenshot (real device rotation isn't
producible here — `simctl` has no rotate command and there's no GUI-
automation tool for Simulator.app); L4's rotation/LEVEL fix has no
UI to screenshot and was verified by build + unit tests only. The
full on-device checklist from this doc's Acceptance section is the
next step — added to `plans/open-human-steps.md`.

Written 2026-07-08 after Kah asked for side-on
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
   a small shared flag (`OrientationLock.allowsLandscape: Bool` — a plain
   main-actor static, no `@Observable` needed since only the delegate
   reads it; see L1 for the required `didSet`) that `CaptureView` derives
   from `step` — true only in `.pickSideOnPhoto`; see L2 for the
   `onChange`/`onDisappear` mechanism that covers every exit path,
   including capture, skip, and cancel. Every other screen keeps returning
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

## Correctness traps (read before coding)

These are the three places a straight-line implementation of the tasks
below silently fails. Each is folded into its task, but they matter enough
to state up front:

1. **`levelOK` hard-fails in landscape as written.** `CameraSession.
   startMotion()` computes `roll = atan2(g.x, -g.y)` — that is *deviation
   from portrait-upright*. Hold the phone landscape and perfectly level
   and it reads ±90°, so `levelOK = abs(roll) < 2°` is permanently false
   and the shutter never enables. LEVEL must become *deviation from the
   nearest 90° bucket* (see L4). PERP is fine untouched: `pitch =
   atan2(-g.z, …)` measures rotation about the screen normal's
   perpendicular axis via `g.z`, which doesn't change when the phone spins
   within the screen plane.

2. **Flipping the delegate flag does nothing by itself on iOS 16+.** After
   `OrientationLock.allowsLandscape` changes, UIKit must be told to
   re-query: call `setNeedsUpdateOfSupportedInterfaceOrientations()` on the
   root view controller. And when the flag goes *false while the phone is
   physically held landscape* (user skips/captures mid-landscape), the UI
   does not rotate back on its own — the scene must be forced with
   `windowScene.requestGeometryUpdate(.iOS(interfaceOrientations:
   .portrait))`. Both belong in `OrientationLock`'s setter so every call
   site gets them (see L1).

3. **`CameraPreviewLayer.updateUIView` is currently a no-op**, so there is
   no path for a changed rotation angle to reach the preview connection.
   The angle must be plumbed in as a property and applied in
   `updateUIView` (see L4) — otherwise the preview shows sideways in
   landscape even though the HUD reflowed.

## Reference: gravity → orientation bucket → `videoRotationAngle`

One shared mapping drives L3 (HUD branch cross-check), L4 (connection
angles), and the LEVEL fix. Gravity is in device coordinates (+x out the
right edge in portrait, +y out the top):

| Physical hold | Dominant gravity | `UIDeviceOrientation` | `videoRotationAngle` |
| --- | --- | --- | --- |
| Portrait upright | `g.y ≈ -1` | `.portrait` | `90` (today's hardcode) |
| Rotated CCW, top of phone to the left | `g.x ≈ -1` | `.landscapeLeft` | `0` |
| Rotated CW, top of phone to the right | `g.x ≈ +1` | `.landscapeRight` | `180` |

Implementation notes:
- Pick the bucket by dominant axis (`abs(g.x)` vs `abs(g.y)`), with
  **hysteresis**: only switch buckets when the new axis clearly dominates
  (e.g. by a ratio ≥ 1.2, ≈ deviation past ~50°), otherwise the bucket —
  and with it `videoRotationAngle`, the LEVEL zero-point, and the HUD
  branch — flaps right at the 45° diagonal.
- Keep the bucket as published state on `CameraSession` (e.g.
  `@Published var orientationBucket`), computed inside the existing
  `startMotion()` closure — one source of truth for L3 and L4.
- Always guard with `conn.isVideoRotationAngleSupported(angle)` (the
  existing code already models this). The 0/180 assignments above are the
  standard back-camera mapping but are exactly the kind of thing the
  device pass must confirm — if a captured landscape photo comes out
  upside-down, swap the 0 and 180 rows, nothing else.
- When `allowsLandscape` is false (head-on, and side-on before L2 flips
  it), force the bucket to portrait regardless of gravity, so head-on
  behaviour is bit-identical to today.

## Tasks

### L1. `AppDelegate` + orientation-lock flag

Files: new `ios/GetTucked/App/AppDelegate.swift`, `GetTuckedApp.swift`.

- Minimal `NSObject, UIApplicationDelegate` implementing
  `func application(_ application: UIApplication,
  supportedInterfaceOrientationsFor window: UIWindow?) ->
  UIInterfaceOrientationMask`, reading a shared `OrientationLock` flag
  (new small file, e.g. `ios/GetTucked/App/OrientationLock.swift`) —
  `.portrait` when false, `[.portrait, .landscapeLeft, .landscapeRight]`
  when true.
- `OrientationLock` needs no `@Observable` — nothing observes it in
  SwiftUI; the delegate reads it on demand. A main-actor `enum` with a
  `static var allowsLandscape = false` is enough, **but the `didSet` must
  do the iOS 16+ invalidation dance** (Correctness trap 2):
  ```swift
  static var allowsLandscape = false {
      didSet {
          guard allowsLandscape != oldValue else { return }
          guard let scene = UIApplication.shared.connectedScenes
              .first(where: { $0.activationState == .foregroundActive })
              as? UIWindowScene else { return }
          if !allowsLandscape {
              scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
          }
          scene.keyWindow?.rootViewController?
              .setNeedsUpdateOfSupportedInterfaceOrientations()
      }
  }
  ```
  Without `requestGeometryUpdate`, leaving side-on while physically
  holding the phone landscape strands the whole app in landscape; without
  `setNeedsUpdateOfSupportedInterfaceOrientations`, entering side-on never
  starts permitting landscape at all.
- Wire via `@UIApplicationDelegateAdaptor(AppDelegate.self) var delegate`
  in `GetTuckedApp` (currently a bare `@main struct GetTuckedApp: App` in
  `ios/GetTucked/App/GetTuckedApp.swift` — no delegate exists yet).
- `project.yml`: extend the existing
  `UISupportedInterfaceOrientations` list (currently only
  `UIInterfaceOrientationPortrait`, under
  `targets.GetTucked.info.properties`) with
  `UIInterfaceOrientationLandscapeLeft` and
  `UIInterfaceOrientationLandscapeRight` — the delegate hook can only
  *restrict* within what Info.plist declares as possible. Leave
  upside-down portrait out (decision 2). Run `xcodegen generate` after.

### L2. `CaptureView` toggles the lock around the side-on step

File: `ios/GetTucked/Capture/CaptureView.swift`.

- Don't hand-audit every exit closure — derive the flag from `step`
  structurally, so no path can be missed:
  ```swift
  .onChange(of: step) { _, newStep in
      OrientationLock.allowsLandscape = (newStep == .pickSideOnPhoto)
  }
  .onDisappear { OrientationLock.allowsLandscape = false }
  ```
  on `CaptureView`'s root `ZStack` (next to the existing `.onAppear`).
  `onChange` covers capture (`→ .analysingSideOn`), library-pick
  (`→ .analysingSideOn`), skip (`→ .reveal`), the error alert's "Try
  again" (`→ .pickPhoto`), and retake via `resetForNewCapture()`;
  `onDisappear` covers `dismiss()` (the ✕ / cancel paths) and any
  navigation pop. Nothing needs to change inside the step closures
  themselves.
- The flag also gates `CameraSession`'s orientation bucket (see the
  mapping reference above), so head-on capture — which shares
  `LiveCameraView` — keeps today's fixed-portrait behaviour exactly.

### L3. Landscape HUD layout for `LiveCameraView`

File: `ios/GetTucked/Capture/LiveCameraView.swift`.

- Branch on **layout geometry, not `UIDevice.current.orientation`**: wrap
  the HUD in a `GeometryReader` and use `geo.size.width >
  geo.size.height`. Geometry is synchronised with the actual rotation
  animation; `UIDevice` orientation is not (it can report `.faceUp`, and
  it fires before layout settles). The gravity bucket from L4 is for the
  *camera connections*, not the HUD — the HUD must follow what the
  *interface* did, which in landscape-locked-out states (head-on) is
  always portrait even when gravity says otherwise.
- When landscape, branch the HUD into the vertical-rail arrangement from
  decision 3: top bar (`StepLabelChip` + ✕) stays along the top edge;
  `StatusPillRow` (vertical stack of pills), `CaptureButton`,
  `LibraryFallbackLink`, and the skip button move to a trailing-edge
  `VStack` rail, respecting the safe area (the home indicator sits on a
  long edge in landscape). Reuse the existing sub-views, just relaid-out,
  not rebuilt.
- `LevelLine` default (so this doesn't stall on decision 3's "sketch
  first"): keep it a horizontal rail near the top of the screen in both
  orientations, showing the bucket-relative roll deviation from L4.
  `session.tiltDeg` must feed it the *bucket-relative* value (see L4),
  otherwise the tick pegs at full deflection in landscape.
- Only the `showsBikeChip == false` configuration (side-on) needs to look
  right in landscape — head-on's `.pickPhoto` call site never sets
  `allowsLandscape`, so its geometry can never go landscape and its layout
  is unaffected. `BikePickerSheet` therefore never presents in landscape
  either.
- For seeded screenshots: the landscape branch keys off geometry, so
  forcing it in the Simulator is just rotating the Simulator window (⌘→)
  once Info.plist permits landscape and a DEBUG seed forces
  `allowsLandscape = true` — no layout-branch flag needed beyond that.

### L4. Dynamic capture-rotation + landscape-aware LEVEL

File: `ios/GetTucked/Capture/LiveCameraView.swift` (`CameraSession`,
`CameraPreviewLayer`).

- **Fix LEVEL first** (Correctness trap 1). In `startMotion()`, keep the
  raw `roll = atan2(g.x, -g.y)`, then subtract the current bucket's
  reference angle (portrait 0°, landscapeLeft −90°, landscapeRight +90°,
  normalised to (−180°, 180°]) before thresholding and publishing:
  `tiltDeg` becomes the bucket-relative deviation, `levelOK =
  abs(deviation) < 2°` as today. The bucket comes from the shared
  gravity→bucket mapping (with hysteresis) defined above, and is forced
  to portrait whenever `OrientationLock.allowsLandscape` is false.
  `pitch`/`perpOK` stay exactly as they are.
- Derive `videoRotationAngle` from the bucket per the mapping table
  (portrait 90, landscapeLeft 0, landscapeRight 180) instead of the two
  hardcoded `90`s.
- **Preview path:** `CameraPreviewLayer.updateUIView` is currently empty —
  add a `let rotationAngle: CGFloat` property, pass
  `session.orientationBucket`'s angle from `LiveCameraView`, and apply it
  in **both** `makeUIView` and `updateUIView` (guarded by
  `isVideoRotationAngleSupported`). Without the `updateUIView` half,
  SwiftUI never propagates the change and the preview shows sideways
  after rotation.
- **Photo path:** in `capturePhoto`, set the photo-output connection's
  `videoRotationAngle` from the current bucket *inside the existing
  `sessionQueue.async` block, before `capturePhoto(with:delegate:)`* —
  connection config belongs on the session queue, and setting it at
  capture time (rather than reactively) means a mid-rotation shot uses
  the bucket the gravity read had settled on.
- `UIImage.normalisedOrientation()` (already run on every captured photo)
  should continue to make orientation a non-issue downstream — confirm
  rather than assume once real landscape captures exist: the saved image
  must be genuinely wider-than-tall in pixels, and the side-on pose
  analysis must receive it that way.

## Acceptance

Side-on capture starts portrait like today; rotating the phone to
landscape mid-step reflows the HUD into the vertical-rail layout from L3,
capture stays gated on LEVEL+PERP throughout — **including that a
landscape-level phone shows LEVEL ok and an enabled shutter** (the
bucket-relative roll fix, the easiest thing to get wrong) — and a photo
captured while the phone is held in landscape saves as a genuinely
landscape-shaped image (width > height in pixels). Leaving the side-on
step while physically holding the phone landscape snaps the UI back to
portrait (the `requestGeometryUpdate` path). Every other screen in the
app — including head-on capture — is unaffected and stays portrait-only.

Verified via seeded screenshots for the landscape HUD layout (Simulator
rotation per L3's last bullet); the physical-device checklist for Kah
(add to `plans/open-human-steps.md`):
1. Rotate mid-side-on → HUD reflows, preview stays upright (not sideways).
2. Landscape-level phone → LEVEL green, shutter enabled; captured photo is
   landscape-shaped and right-way-up (if upside-down, swap the 0/180
   mapping rows).
3. Skip/capture/✕ while held landscape → app returns to portrait.
4. Head-on step → still refuses to rotate.
