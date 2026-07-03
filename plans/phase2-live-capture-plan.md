# Phase 2 — Live-capture gaps: plan

Status: **planned, not started.** Covers the remaining Phase 2 live-capture work
(§2.3 / §2.5) plus the CoreMotion↔ARKit decision. See the code spec
(`get-tucked-code-spec.html`) for behaviour source of truth.

## Confirmed decisions

1. **Burst uncertainty** = half-range `(max − min) / 2` across the 3 frames,
   floored at the existing 3% model — i.e. `max(halfRange, 0.03 × median)`.
   Never claim tighter than 3% off a lucky-identical burst.
2. **Schema**: add `sideOnPhotoData: Data?` to `Position` (additive, auto-migrated).
3. **ARKit**: deferred. Keep CoreMotion for now.

## Build order & scope

Order: **2 → 4 → 3 → 1**. ARKit deferred.

### 2. Tappable bike chip — *low*
- Pass `bikes: [Bike]` + a selection binding/callback into `LiveCameraView`
  (`ios/GetTucked/Capture/LiveCameraView.swift`); `BikeChip` becomes a button
  opening a picker sheet that updates `selectedBike`.
- Only affects which bike the position saves under and the handlebar width used
  at calibrate time (calibration/analysis happen after capture).

### 4. Finish token pass — *low*
- Restyle `NamePositionStep` in `ios/GetTucked/Capture/CaptureView.swift` from
  `Form` / `.borderedProminent` to `MonoField` + `AccentButton` on `bg0`.
- The SF-symbol side-on `PhotoPickStep` is removed by step 3.

### 3. Side-on live capture + schema — *medium*
- Reuse `LiveCameraView` for side-on (parameterized label/guidance; no handlebar
  calibration — reuses `pixelsPerCm` from head-on).
- **Schema**: add `sideOnPhotoData: Data?` to `Position`
  (`ios/GetTucked/Models/Position.swift`); persist the side-on
  burst-representative frame there. `photosData` stays the head-on blob
  (documented asymmetry: `photosData` = head-on frontal, `sideOnPhotoData` = side-on).
- Add a FRONTAL / SIDE-ON toggle to the Reveal screen (mirrors `PositionDetailView`).

### 1. Three-shot burst → empirical uncertainty — *high*
- `CameraSession.capturePhoto` captures 3 stills rapidly → `[UIImage]`.
- Calibrate once; reuse the tap (unit coords) across all three (rider is
  stationary across a ~0.5s burst).
- New `AnalysisEngine.analyseBurst(images:...)`: median area, uncertainty per
  decision #1.
- Same burst mechanism feeds side-on capture.

## Schema-change detail

The app uses `.modelContainer(for: AppSchema.models)` in `GetTuckedApp.swift` —
the convenience initializer that infers the schema and does **automatic
lightweight migration**. Adding an **optional** property (`sideOnPhotoData: Data?`)
is purely additive → auto-migrated, no data loss, **no explicit `MigrationStage`**.

The `SchemaV1` / `AppMigrationPlan` enums in `AppSchema.swift` exist but are not
wired into the container, so they don't apply to this change. Optionally bump
`versionIdentifier` to `1.1.0` for hygiene — cosmetic until we formally adopt
`migrationPlan:`.

## CoreMotion vs ARKit — pros & cons of staying on CoreMotion

### Keeping CoreMotion (current)

**Pros**
- **No camera contention** — runs freely alongside `AVCaptureSession`, so we keep
  the full-res `AVCapturePhotoOutput` still path.
- **Light**: minimal battery/thermal, instant start, no tracking warm-up.
- **Stable & lighting-independent**: roll/pitch are accelerometer-referenced
  (gravity), so they don't drift and work in any light. (Yaw would drift, but we
  don't use it.)
- Already working and shipped.

**Cons**
- **"PERP" is only a proxy.** It confirms the phone isn't pitched up/down — it
  *cannot* verify you're square-on to the rider. Level but 30° off-axis passes,
  and that off-axis error distorts frontal area.
- **No framing help**: can't measure camera height (hub level) or distance /
  "fill the frame."
- **No camera intrinsics** → the area math keeps its orthographic/pinhole
  simplification, which HANDOFF flagged as silently *underestimating* area. This
  is the real limitation, and it's about scale accuracy, not the tilt indicators.

**Nuance:** ARKit's genuine prize is **camera intrinsics + world geometry for
accurate scale**, not better level/perp bubbles. And intrinsics don't strictly
require ARKit — see the middle path below.

## Migration path, if we later need more than CoreMotion

### Cheapest first (recommended if the goal is scale accuracy, not framing)
- Get **camera intrinsics from AVFoundation** — enable
  `cameraIntrinsicMatrixDeliveryEnabled` on the capture connection (or
  `AVCameraCalibrationData` from the photo output). Yields the intrinsic matrix
  **without ARKit and without losing the high-res photo path**, letting
  `AnalysisEngine` replace the orthographic scale assumption. No capture rewrite.

### Full ARKit (only if we need world geometry — true perpendicularity, camera height, distance)
1. **Abstract capture behind a protocol** — `CaptureProvider` yielding
   `(image, intrinsics?, gravity, trackingPose)`. `LiveCameraView` depends on the
   protocol, not AVFoundation directly. Low-risk refactor; do it anytime to keep
   the door open.
2. **Add `ARKitCaptureProvider`** using `ARWorldTrackingConfiguration` (optionally
   `frameSemantics = .personSegmentation` on A12+), reading
   `ARFrame.camera.intrinsics` + `.transform` for level/perp and capturing
   `ARFrame.capturedImage` on the shutter.
3. **Swap behind a feature flag**, keeping AVFoundation as fallback for older
   devices / thermal.
4. Feed intrinsics into `AnalysisEngine`.

**Costs to accept with full ARKit**
- ARSession owns the camera, so the still comes from `ARFrame.capturedImage`
  (~1920×1440 YUV, **lower res** than the full-res photo output).
- Heavier battery/thermal + warm-up; tracking-state handling
  (limited / relocalizing).
- Perpendicularity-*to-rider* still isn't free — needs a detected plane or
  `ARBodyTracking` (A12+, a config that conflicts with world tracking).
- No SwiftData model change — it changes capture + analysis, and the
  area/uncertainty numbers would shift → a §3 re-validation.

**Suggested trigger:** if we want better *numbers*, do the AVFoundation-intrinsics
middle path — not ARKit. Reserve full ARKit for framing guidance
(height/distance/true square-on). Either way, step 1 (the `CaptureProvider`
protocol) is the cheap insurance that makes a later swap easy.
