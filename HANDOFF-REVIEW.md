# Handoff review — progress vs plan

Review date: 2026-06-10. Reviewer: Claude (read-only pass over the repo).
Audience: the next agent picking this up.

This is a review, not a change. Nothing in the codebase was modified. Treat the
ordered actions at the bottom as the to-do list.

---

## TL;DR

The project has **pivoted from the spike plan to a native iOS build**, and the
pivot is mostly undocumented. There are now two projects in one repo:

1. **Spike A** (committed) — the browser MediaPipe verifier from
   `plans/segmentation-spike-plan.md`. Complete, clean, loop closes via
   `npm run verify`.
2. **The real product** (`ios/`, *untracked*) + a new engineering spec
   (`plans/get-tucked-code-spec.html`, *untracked*) committing to **Swift /
   Vision / ARKit** — i.e. the "native Apple Vision" branch, not Expo.

Phase 1 of the new spec is essentially built. But the pivot broke the property
the original plan existed to protect (an agent-runnable verification loop), the
hero metric has correctness bugs, and the repo's own docs still describe only the
spike. Fix the docs and the loop before adding features.

---

## 1. Strategic blindspots (read these first)

### 1.1 The agentic loop is gone, and nobody wrote that down
The original plan's central driver (segmentation-spike-plan.md, "Background"):
**cloud agents can't build native iOS — Xcode is macOS-only**, so favour an
agent-friendly stack. Spike A was the cheap way to decide Expo vs native.

The new spec goes **native iOS** with no mention of this tension. That's a
legitimate choice, but it has a consequence nobody recorded: the one Mac is now a
hard dependency, and **there is no automated verification for the Swift code at
all** — no `xcodebuild`, no test target, no CI. The browser spike had a beautiful
`npm run verify` that exits 0/1. The iOS app has nothing equivalent. An agent
cannot currently tell if `ios/` even compiles.

This is the single biggest regression from the plan's philosophy. See action #2.

### 1.2 The risk the spike existed to retire is still open
Spike A was supposed to answer "is on-device segmentation matte quality good
enough on the *hard* case (cyclist on cluttered outdoor background)?" before
committing the architecture.

- The committed fixtures are `Wahoo-Kickr-Review-Indoor-Trainer-1.jpg`,
  `preview2.jpg`, `2400-5-1.webp` — stock / indoor-trainer images, **not**
  representative outdoor cyclists (the fixtures/README itself says studio/clean
  shots are useless).
- No pass/fail verdict on matte quality was ever recorded. The memory file still
  reads "waiting for real cyclist photos."

So the move to native didn't retire the risk — it relocated it. **Apple Vision's
`VNGeneratePersonSegmentationRequest` matte quality on the hard case is now
equally untested.** Before sinking Phase 2–5 effort in, run a handful of real
cyclist photos through the iOS analysis path (or at least Vision) and eyeball the
masks. This is the cheapest risk-retirement still available.

### 1.3 The repo's own docs contradict reality
- `CLAUDE.md` describes *only* the browser spike loop. An agent opening this repo
  is told the job is `npm run verify` and will have no idea the iOS app, the new
  spec, or the architecture pivot exist.
- The auto-memory (`MEMORY.md` → `project_spike_a.md`) still says current focus is
  "waiting for real cyclist photos to drop into fixtures/."

This is a serious onboarding trap. See action #1.

### 1.4 Untracked = unprotected
`ios/` and `plans/get-tucked-code-spec.html` are **untracked**. A `git clean` or
fresh clone loses the entire product. Commit them (action #1).

---

## 2. Correctness bugs in the hero metric (frontal area cm²)

The spec is emphatic (§3, §8, §13): every number must be defensible, and the
frontal-area math is "the most important math in the app." Three independent bugs
currently corrupt it. All three are in the capture → analysis path.

### 2.1 Letterbox-offset tap calibration — `CaptureView.swift`
`HandlebarCalibrationStep` shows the photo with `.scaledToFit()` inside a
`GeometryReader`, then converts a tap to unit coords by dividing by `proxy.size`
(the *container*). With `scaledToFit` the image is letterboxed — there's padding
on two sides — so the tap is measured against the container, not the image. Unit
coords are wrong by the letterbox offset/scale unless the image aspect ratio
exactly matches the container. That feeds straight into `pixelsPerCm`.

**Fix:** compute the actual displayed image rect (aspect-fit math from
`image.size` and `proxy.size`), and map taps relative to that rect, not the
container. `imageSize` is currently captured but effectively unused.

### 2.2 Mask-space vs source-space pixel mismatch — `AnalysisEngine.swift`
`pixelsPerCm` is derived from tap points × **source image** dimensions
(`cgImage.width/height`). But `countForegroundPixels` counts pixels in the
**Vision mask buffer**, whose resolution is not guaranteed to equal the source
image. `areaCm2 = maskPixels / pixelsPerCm²` then mixes two pixel spaces and is
wrong by `(maskRes / sourceRes)²` whenever they differ.

**Fix:** log `CVPixelBufferGetWidth/Height(maskBuffer)` vs source dims to confirm.
If they differ, either scale the mask to source resolution before counting, or
compute `pixelsPerCm` in mask space. Don't assume they match.

### 2.3 EXIF orientation dropped — `CaptureView.swift` + `AnalysisEngine.swift`
The picked image is loaded as `UIImage(data:)` (which carries `imageOrientation`)
and displayed via `Image(uiImage:)` (which *applies* orientation). But analysis
uses `image.cgImage` + `VNImageRequestHandler(cgImage:)` with no orientation — the
raw, unrotated buffer. For any photo not already `.up` (most phone photos), the
calibration taps (on the oriented display) and the Vision analysis (on the
unrotated buffer) live in different coordinate spaces, and the person detection
runs sideways.

**Fix:** normalise the `UIImage` to `.up` once (redraw into a context) and use that
single bitmap for *both* the calibration display and the cgImage handed to Vision.

### 2.4 Known limitation not recorded: no camera intrinsics
Phase 1 cut camera intrinsics (reasonable — library photos have none) and scales
by handlebar width alone. That bakes in a systematic bias: the bars sit forward of
the torso, so they're closer to the camera and project larger → `pixelsPerCm` too
high → **frontal area underestimated**. This is fine as a Phase-1 simplification
but must be written into the "How this works" / limitations notes (spec §11), and
flagged as a thing Phase 2 (AR capture with intrinsics) fixes. Right now the cut
is silent.

---

## 3. Phase-1 gaps and smaller risks

- **False "clipped frame" rejections.** `validatePerson` rejects if the person
  bbox touches any edge (5px margin). The spec *wants* the rider to fill the frame
  (bbox height > 50%); real full-body cycling shots routinely have feet at the
  bottom edge. Expect valid photos to be rejected. Reconcile with the spec
  heuristic (height threshold, not strict edge-contact).
- **Photo Library read auth never requested.** `PositionDetailView.loadPhoto`
  uses `PHAsset.fetchAssets(withLocalIdentifiers:)`, which needs library
  authorization. The app never calls `PHPhotoLibrary.requestAuthorization`.
  `PhotosPicker` itself is permissionless, so the saved photo will silently fail
  to reload in the detail view. Either request auth, or persist the image bytes
  rather than relying on re-fetching the asset.
- **Capture is library-pick, not camera.** Spec Phase 1 says "single capture";
  the impl punts to `PhotosPicker`. Defensible (no AR enforcement yet) but it
  sidesteps ARKit/intrinsics entirely — note it as a deliberate cut so it isn't
  mistaken for done.
- **Signing not configured.** `ios/project.yml` has empty `DEVELOPMENT_TEAM`. Fine
  for spec stage; a blocker the moment device testing (Spike B) starts.
- **SchemaV1 is frozen with no migration stages.** Adding Events/bags/PhotoRefs
  (spec Phase 3/4) will need migration stages — `AppMigrationPlan.stages` is
  currently empty. Expected, just be ready for it.
- **No design language for iOS.** Kah cares deeply about visual polish (global
  CLAUDE.md: mire·studio system, 25px radius, specific fonts). The app is default
  SwiftUI. The spec references a "companion design spec" that isn't in the repo.
  Fine for a skeleton, but the visual direction is undefined and Kah will notice.

---

## 4. What's genuinely good (don't regress these)

- Spike A's verifier is exactly right: real static server + Playwright, coverage
  as the only hard gate, timing as report-only ceiling, mattes dumped for human
  review, smoke mode for plumbing. The quality-vs-speed honesty split is intact.
- The iOS Phase-1 vertical slice is coherent and matches the spec's "each phase
  ships a working product" intent. Models, onboarding gate, capture flow, and
  detail view all hang together.
- `AnalysisError` copy already mirrors the spec's failure-state table. Good.
- Uncertainty is surfaced (±cm²) from the start — aligns with the spec's
  noise-floor honesty posture.

---

## 5. Recommended actions, in order

1. **Reconcile the docs with reality, then commit.** Update `CLAUDE.md` to
   describe both projects (or split the spike into its own subdir / archive it),
   point at `get-tucked-code-spec.html` as the source of truth for the iOS app,
   and update the memory file's "current focus." Then `git add ios/ plans/` and
   commit — these are untracked and unprotected.
2. **Restore an automated loop for the iOS code.** Add a test target and unit
   tests for `AnalysisEngine` (the area math especially), runnable via
   `xcodebuild test` on the Mac. This is the native equivalent of `npm run
   verify`. Without it the agent is flying blind. If cloud-buildability matters,
   that decision (native vs Expo) needs to be made explicitly — it was never
   actually resolved by the spike.
3. **Fix the three hero-metric bugs (§2.1–2.3)** before building any comparison
   feature — comparisons of wrong numbers are worse than no comparisons.
4. **Retire the segmentation-quality risk for real:** run 3–10 representative
   outdoor cyclist photos through Vision and eyeball the masks. Record the
   verdict. (The current fixtures don't count.)
5. Write the camera-intrinsics limitation (§2.4) into the methodology notes.
6. Then proceed to Phase 2 per the spec.
