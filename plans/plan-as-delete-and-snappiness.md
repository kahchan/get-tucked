# Plan AS: bike delete, camera start, snappiness

Kah, 2026-10-24, tester report:

1. The first bike delete crashes the app.
2. A deleted bike is still selectable when you add a position.
3. After "+", the camera takes a long time to appear, and nothing shows that work is in progress.
4. The whole app feels laggy.

No crash log exists. Kah approved a schema bump (2026-10-24).

**Status: AS1–AS5 implemented + reviewed, 392 tests green (2026-10-24), uncommitted. Simulator UI checks and AS6 device pass outstanding.**

## The key facts

- `BikeSetupView.deleteBike()` (`BikeSetupView.swift:226`) calls `context.delete(bike)` and
  does not save. The cascade to positions and the `@Query` refresh wait for autosave. If the
  app crashes before autosave, the delete is never persisted, so the bike comes back on relaunch.
  Issue 2 is probably a result of issue 1.
- `Position` stores 7 image blobs inline: `photosData`, `maskData`, `subjectMaskData`,
  `correctedSubjectMaskData`, `sideOnMaskData`, `sideOnSubjectMaskData`, `sideOnPhotoData`.
  None has `@Attribute(.externalStorage)`, so each Position fetch loads every photo of every
  saved position. The app gets slower as more positions are saved.
- Three call sites fetch all positions to find one ID: `PositionDetailWrapper` and
  `ComparisonWrapper` (`AppNavigation.swift:282`, `:320`) and `CaptureView.referencePosition`
  (`CaptureView.swift:20`, `:26`). `CaptureView` also uses the full query only for
  `positions.first?.bike` (`:199`).
- List rows (`PositionListView.PositionRow`) read only `metrics`, `label`, `bike` and
  `capturedAt`, never a blob. Detail views already decode off-main.
- `CameraSession.configureSession()` (`LiveCameraView.swift:863`) runs on `sessionQueue`.
  `applyZoom` runs *after* `startRunning()` (`:913`), so a virtual device can start on one lens
  and switch. Nothing tells the UI when the first frame has arrived.

## Slices

Three coder slices. No two slices touch the same file. Each coder builds and runs only the
tests for its change. The orchestrator runs the full suite once after all three are done.

| Slice | Items | Files |
|---|---|---|
| 1 · Data correctness | AS1, AS2, AS4 | `BikeSetupView.swift`, `CaptureView.swift`, `AppNavigation.swift`, new test file |
| 2 · Schema | AS3 | `Position.swift`, `AppSchema.swift`, `GetTuckedApp.swift`, new test file |
| 3 · Camera | AS5 | `LiveCameraView.swift` only |

## AS1 · Bike delete crash

**Slice 1 built 2026-10-24 (uncommitted).** Crash backtrace: could not reproduce. A save-after-delete unit test passes on SchemaV11 in memory (bike with 2 positions, both fetches empty). No Simulator UI run yet, and the unsaved-delete cause is unconfirmed. Fix (`try? context.save()`) is in. AS2 and AS4 code is in; Simulator checks outstanding.

- First, reproduce the crash in the Simulator. Use a bike with no positions, then a bike with
  positions from a unit test. Record the backtrace in this plan. It is the only raw evidence
  because no crash log exists.
- Fix: in `deleteBike()`, call `try? context.save()` immediately after `context.delete(bike)`,
  before `onSave?()` and `dismiss()`. Do the same in `PositionDetailView`'s delete (`:291`) only
  if the backtrace shows the same cause there.
- If the backtrace points at something other than the unsaved delete (for example the
  `Position.events` relationship during the cascade), stop and report. Do not guess a second fix.

**Verify:** new `BikeDeleteTests` with an in-memory `ModelContainer` built from
`Schema(versionedSchema:)` and the live schema. Insert a bike with 2 positions, delete the bike,
save. Assert that `fetch(FetchDescriptor<Bike>())` and `fetch(FetchDescriptor<Position>())` are
both empty. In the Simulator, delete a bike 5 times in a row (add, delete, add, delete) with no
crash.

## AS2 · Deleted bike in the capture picker

- With AS1 in place, `@Query bikes` drops the bike on save. Do not add `isDeleted` filters.
- `CaptureView.onAppear` (`:199`) default: replace `positions.first?.bike` with a one-row fetch
  (`FetchDescriptor<Position>`, sort `capturedAt` reverse, `fetchLimit = 1`) through
  `@Environment(\.modelContext)`. This is part of AS4: it removes the last use of the full
  `positions` query.

**Verify:** in the Simulator, add bikes A and B, delete A, tap "+". The camera opens on B, and
the bike picker lists only B. Do this once before relaunch and once after.

## AS3 · Blobs to external storage (SchemaV12)

See standing traps in CLAUDE.md (schema bump).

- `Position.swift`: add `@Attribute(.externalStorage)` to the 7 blob properties listed in the
  key facts. SwiftData keeps small values (masks) inline by itself, so mark all 7.
- `AppSchema.swift`: freeze the current shape as a nested `SchemaV11` snapshot, the same pattern
  as `SchemaV10` (`:1025`, `:1035`). Copy every stored property and relationship of the 5 live
  models exactly, without the new attribute. Add `SchemaV12` (version 12.0.0,
  `models = AppSchema.models`), add it to `schemas`, and add a lightweight `migrateV11toV12` with
  a one-line comment in the style of the stages above.
- `GetTuckedApp.swift`: change `Schema(versionedSchema: SchemaV11.self)` to `SchemaV12`, and add
  "V11→V12 (Plan AS3)" to the comment list.
- Risk: if SwiftData sees the same checksum for V11 and V12 ("duplicate version checksums"), the
  container does not open. If that happens, stop and report. The fallback is no version bump and
  only the attribute on the live model, but Kah must approve it.
- Done (slice 2): the checksum risk did not happen. `BikeDeleteTests` and `MaskCorrectionTests`
  build from the live schema, and they must move on every bump.

**Verify:** new `SchemaV12MigrationTests`. Create an on-disk store in a temp directory with
`Schema(versionedSchema: SchemaV11.self)` (the frozen snapshot). Insert a bike and a position
with a 1 MB `photosData` and a small `maskData`, then close it. Reopen with `SchemaV12` and
`AppMigrationPlan`. Assert that both blobs come back byte-equal and that the bike relationship
is intact. Also launch the app in the Simulator over an existing store with no crash at launch.

## AS4 · Fetch one position, not all

- `PositionDetailWrapper` and `ComparisonWrapper`: replace the bare `@Query` with a filtered
  query that is built in `init`, for example
  `_positions = Query(filter: #Predicate<Position> { $0.persistentModelID == id })`
  (Comparison: `id == idA || id == idB`). Keep it a `@Query`, not `context.model(for:)`: the
  "Position not found" fallback must still react to deletes (see fix cc5ec1b).
- `CaptureView`: remove the full `@Query positions`. Read `referencePosition` with the same
  filtered query on `referenceID` (or nothing when `referenceID` is nil). The `onAppear` default
  bike comes from AS2.
- `BikeEditWrapper` queries bikes. Bikes are small rows, so do not change it.
- If `#Predicate` on `persistentModelID` does not compile or does not match on iOS 17, stop and
  report. Do not add a UUID route.
- Done (slice 1): `CaptureView` got an explicit `init(path:referenceID:onSaved:)`, and a nil
  `referenceID` uses `#Predicate { _ in false }` (an optional ID does not compile in a predicate).

**Verify:** `AppNavigationTests` green. In the Simulator: open a position, compare two positions,
"Match this position", then delete a position from its detail screen. Each one opens the right
record, and the delete lands on the list with no "Position not found" flash.

## AS5 · Camera start: measure, speed up, loader

**Done (slice 3, 2026-10-24, uncommitted).** Built; signpost start interval is lock-guarded and opened after the DEBUG early return. Loader is unverified until the device pass.

- Measure: add an `OSSignposter` interval (subsystem bundle ID, category "camera") from
  `CameraSession.start` to the first frame in `captureOutput`. Put the first-frame check *before*
  the segmentation throttle guard (`:1018`). Keep the signposter: it is the before/after number
  for Kah's device pass.
- Speed up: move `applyZoom(visualMultiplier: 2.0, to: device)` to before
  `captureSession.startRunning()`, so the session starts on the correct lens. Make no other
  change to session setup until there are device numbers.
- Loader: add `@Published var isRunning = false` to `CameraSession`. Set it to true on main on
  the first frame, and set it to false in `stop()`. The DEBUG staged-frame path sets it to true
  in `start`. In `LiveCameraView`, while `!isRunning && !permissionDenied`, show a centred
  `STARTING CAMERA` label in `Theme.mono(11, weight: .bold)` with `Theme.Palette.fg2`, and a
  thin indeterminate acid-yellow bar below it. Use 0 radius. Show it only after 150 ms so that
  a fast start does not flash. Fade it out at `Theme.Motion.fast`. Reduce Motion: no bar
  animation, label only. VoiceOver: "Starting camera".

**Verify:** builds. The Simulator has no camera, so the loader must stay visible there and stay
hidden with the staged frame. Device numbers come from the device pass below.

## AS6 · Device pass (Kah, after merge)

Record about 20 saved positions on the phone first. Back up the phone before the build that
contains SchemaV12.

- Instruments → os_signpost, "camera" category: "+" tap to first frame. Target: under 400 ms
  warm. Record before (main) and after (this plan) in a table here.
- Instruments → Time Profiler + SwiftUI: scroll the position list, open a detail, go back.
  Any frame over 16 ms on the main thread becomes a candidate for a follow-up plan.
- Known candidate, not built: `captureOutput` runs person segmentation on full-size `.photo`
  buffers at 3 Hz (`:1018`). Build a fix only if the trace shows it.

**Must not regress:** existing data opens after the update. Every saved photo and matte still
renders in detail and compare. Bike delete never crashes.
