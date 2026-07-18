# Plan W — Subject matte (two-tone), capture forgiveness, and two field bugs

Status: planned 2026-07-18, from Kah's first on-device pass of Plans U/V
(night shots, kid on an MTB — the hard case). Four workstreams:

- W1/W2: the mask misses big chunks of the bike (person-only model) → adopt
  the subject-lifting mask, and render rider vs bike/bags in different colours.
- W3: "stand back and zoom" capture guidance + a more forgiving rider-size gate.
- W4: frontal skeleton grew no new Plan V bones (all-or-nothing confidence
  gate too brittle) — bug fix.
- W5: calibration zoom drifts the background image over time — bug fix.

W4 and W5 are independent bug fixes and land first. W2 depends on W1's
verdict; W3 is independent but pairs naturally with W2's landing.

## Context for the implementing agent

Read `CLAUDE.md` first. **Schema warning:** any new persisted field means a
new schema version — and the version bump MUST also update
`Schema(versionedSchema:)` in `ios/GetTucked/App/GetTuckedApp.swift` to the
new latest, or the app fatals at launch with "Failed to cast model" (this
exact mistake shipped in Plan V; see commit 7d7f311).

Verify: `cd ios && xcodegen generate`, full suite via xcodebuild on an
available iPhone simulator. 158 tests currently green.

## W4 — Frontal detail bones never appear (bug)

`AnalysisEngine.bodyPoints(from:)` requires **all four** of
leftHip/rightHip/leftKnee/leftKnee' at confidence > 0.5, or returns nil. On a
frontal bike shot the knees and hips sit behind the bars/frame — one weak
knee kills the torso too, so Plan V's frontal richness effectively never
fires (Kah's device pass: side-on grew bones, frontal didn't).

Fix — split the pairs, knees dependent on hips:

- `HeadOnPoseMetrics`: replace `bodyPoints: [CGPoint]?` with
  `hipPoints: [CGPoint]?` ([leftHip, rightHip], all-or-nothing) and
  `kneePoints: [CGPoint]?` ([leftKnee, rightKnee], all-or-nothing, only
  meaningful when hips are present).
- `SkeletonOverlay.frontal(shoulders:arms:body:)` → change `body:` to
  `hips: [Double]?` (4 values) and `knees: [Double]?` (4 values, ignored
  when `hips` is nil — upper legs can't attach to nothing). Hips alone
  yield torso sides + pelvis bar (window 1); knees add the upper legs
  (window 2). Same `.detail` tier, same shared windows, `windowCount`
  stays 3.
- `PositionMetrics`: replace `headOnBodyPoints` with `headOnHipPoints` /
  `headOnKneePoints`. `headOnBodyPoints` shipped in SchemaV6 but Plan V
  landed **today** and effectively never produced data (that's this bug) —
  still, don't mutate a shipped schema version: SchemaV7 freezes V6 and
  makes the live classes current, dropping the dead field and adding the
  two new ones. Lightweight stage V6→V7 (removals + optional additions
  qualify). **Update GetTuckedApp.swift to SchemaV7** (see warning above).
- Update CaptureView persistence + both frontal call sites + PositionDetail,
  and the SkeletonOverlayTests that exercise `body:` (split into hips-only /
  hips+knees / knees-without-hips-ignored cases).

## W5 — Calibration zoom drifts the background image (bug)

`CaptureView`'s calibration step (~line 1683, `backgroundGesture`): pinch
and pan run `.simultaneously`. A physical two-finger pinch always includes
some centroid translation, and `DragGesture` tracks it — so every pinch
deposits a small phantom pan into `panOffset`. Nothing ever clamps
`panOffset`, so repeated zoom/adjust cycles accumulate visible drift ("after
some time it moves the background image" — Kah, on-device).

Fix, two parts:

1. **Clamp the committed viewport.** After each gesture ends (and in the
   live composition), clamp `panOffset` so the zoomed image always covers
   the container (no letterbox gap can open on a zoomed image; at 1x the
   only valid offset is .zero). Put the pure math in `CalibrationTransform`
   (e.g. `clampedPanOffset(_:zoomScale:imageRect:containerSize:)`) so it's
   unit-testable next to the existing transform tests.
2. **Suppress single-finger pan bleed during a pinch.** Track whether a
   magnification is in flight (the `$pinchDelta` GestureState ≠ 1) and
   ignore the drag's contribution to `panOffset.onEnded` when the gesture
   was predominantly a pinch — or simpler and usually sufficient: raise the
   pan `minimumDistance` contribution check so a pinch's incidental
   translation stays under it. Prefer whichever keeps deliberate
   two-finger pan working; the clamp in (1) is the hard guarantee either way.

Add `CalibrationTransformTests` cases for the clamp (zoomed-in image can't
expose a gap; 1x pins to zero; pan within bounds passes through unchanged).

## W1 — Subject-mask spike (gate for W2)

Question: does `VNGenerateForegroundInstanceMaskRequest` (iOS 17 subject
lifting) matte rider+bike+bags as one clean subject on the hard case —
night shot, white car directly behind, black wall beside?

- Build a tiny throwaway harness — a debug-only screen or a unit test that
  writes PNGs to the simulator's tmp — that runs BOTH requests
  (`VNGeneratePersonSegmentationRequest` as today, and
  `VNGenerateForegroundInstanceMaskRequest` with `allInstances`) on the
  same input photo and saves both masks side by side.
- Run it on Kah's real fixtures (Kah supplies 3–4 photos from the device
  pass: both frontal night shots plus a daylight one if available).
- **HUMAN CHECKPOINT (add to plans/open-human-steps.md): Kah eyeballs the
  pairs.** Pass = the subject mask covers rider AND bike (fork, wheels,
  bars) without grabbing the car/background. Fail = stop; W2 doesn't
  happen and we keep person-only.
- Keep the harness out of the shipping target (test target or #if DEBUG).

## W2 — Adopt the subject mask + two-tone matte (gated on W1)

Area becomes the **subject mask's** foreground count (rider+bike+bags —
what the wind actually sees, and what spec §2 always wanted); the person
mask stays and becomes the *colour splitter*:

- rider pixels = subject ∩ person → keep the current acid-yellow tint
- bike/bags/wheels = subject − person → amber (`Theme.Palette.amb`), the
  established "B side / secondary" colour
- Render two-tone wherever the matte shows (RevealStep MASK segment,
  PositionDetailView MASK mode, MatteCheckView). MatteRenderer grows a
  two-mask tint compositor; pure mask set-ops (intersection/subtraction on
  the byte buffers) live in AnalysisMath or MatteRenderer as testable
  functions.
- Persist the subject mask alongside the person mask on Position
  (`subjectMaskData`, downscaled PNG like `maskData`) — **SchemaV8** if W4
  already made V7, otherwise V7; same freeze-and-bump pattern, same
  GetTuckedApp.swift warning. Old positions have nil → render single-tone
  as today, numbers unchanged (their area was person-mask-derived; the
  Computed date row already discloses vintage).
- The uncertainty/noise-floor math doesn't change; the wheel-check and
  ghost-compare consume whichever mask drove the area — audit call sites
  so mask consumers are consistent (ghost outline should trace the subject
  mask once adopted).
- Honesty note for the reveal copy: bike coverage improving means area
  numbers step up vs old measurements of the same position. The comparison
  screen's "Computed" provenance row covers this; no extra UI, but the
  commit message must call it out.

## W3 — Stand-back-and-zoom guidance + forgiving size gate

Perspective context (from Kah's device pass): the front wheel sits well
forward of the handlebar scale plane and reads oversized — shooting from
farther away with optical zoom flattens the single-plane error. Encourage
that, then stop punishing the resulting smaller rider:

- `AnalysisEngine.validate` (~line 238) rejects when the person bbox height
  < 50% of frame. Lower the floor to **0.35**, and soften the failure copy
  to mention the zoom option ("step closer — or zoom in from where you
  are"). Keep the clip checks unchanged.
- SetTheSceneView / capture coaching copy: add the guidance line — shoot
  from 5–6 m and zoom to 2–3× rather than standing close; closer shots
  inflate whatever's nearest the camera (that front wheel).
- No EXIF focal-length logic in this pass — copy + threshold only.
- Update any AnalysisEngine validation tests pinned to 0.5.

## Order & commits

1. `fix(analysis): frontal hip/knee bones gate independently (SchemaV7)` — W4
2. `fix(capture): clamp calibration pan and stop pinch drift` — W5
3. `chore(analysis): subject-mask spike harness` — W1 (harness only; the
   verdict is Kah's, async)
4. — pause for the W1 human checkpoint —
5. `feat(analysis): subject mask drives area; two-tone rider/bike matte` — W2
6. `feat(capture): stand-back-and-zoom guidance, relaxed size gate` — W3

Done means: build + full suite green after each commit; W4 verified by
re-analysing a frontal photo and seeing torso bones even when knees are
occluded; W5 verified on-device by repeated pinch cycles with no drift
(Kah); W2 only after the W1 eyeball passes.
