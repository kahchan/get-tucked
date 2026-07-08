# Plan J — Rider + bike + bags in the matte (subject segmentation adoption)

Status: **not started; J0 (human verdict) gates everything else.**
Written 2026-07-08 after Kah confirmed the product direction: the frontal
area must include the bike, bars, and bags — the whole system moving through
the air — not the person alone.

**This is also an honesty bug, not just a feature.** The methodology screen
(`HowItWorksView.swift`, A2) already tells the user *"We separate you, your
bike, and your bags from everything behind you"* (deliberate 2026-07-07
product-decision copy), but the shipping pipeline runs
`VNGeneratePersonSegmentationRequest` — person only. The app currently
explains a number it does not compute. Until J lands, every displayed area
contradicts the app's own explanation (spec §3).

## What already exists

`MatteCheckView.swift` (DEBUG harness, reachable from the Bikes screen) has
three modes; **SUBJECT is the proposed production pipeline, fully
implemented** (commit `9b373e5`):

1. `VNGenerateForegroundInstanceMaskRequest` + `VNDetectHumanRectanglesRequest`
   in one handler pass.
2. Scan the Float32 instance-index buffer once → per-instance bounding boxes
   (`instanceBoundingBoxes`), converted to Vision's bottom-left-origin
   normalised convention.
3. Rider instance = the one maximally overlapping the largest human rect
   (frame-centre fallback).
4. Union in instances whose boxes intersect the rider's box expanded by a
   6% margin — the bike/bags the rider is on — while dropping disconnected
   clutter that plain FOREGROUND would sweep up (a coat on the wall).
5. `generateScaledMaskForImage(forInstances:from:)` → matte.

## J0. Human verdict (Kah, on-device — gates J1–J4)

Run MATTE CHECK → SUBJECT on real photos: rider **on a bike**, head-on,
cluttered background, with and without bags; plus the hard cases (wheels/
frame tubes often segment as separate instances — does the margin-union
catch them? does it over-grab furniture touching the rider's box?). Verdict
to record in this doc: does SUBJECT reliably matte rider+bike+bags and
nothing else? If the margin heuristic needs tuning (6% too tight/loose),
note the failure photos — that tuning is a J1 parameter, not a redesign.

Sanity note for the verdict: Kah's reference render masking rider+whole-bike
came out ~5,170 cm²; person-only captures have been reading ~2,500 cm².
Expect roughly a doubling — that's correct behaviour, not inflation.

## Tasks (after J0 says yes)

### J1. Extract the subject-matte pipeline into the analysis layer

Files: new `ios/GetTucked/Analysis/SubjectSegmentation.swift`,
`ios/GetTucked/Views/MatteCheckView.swift`, `ios/GetTuckedTests/`.

- Move the harness's subject logic into a reusable
  `SubjectSegmentation.subjectMask(cgImage:) throws -> CGImage` that returns
  the **same 8-bit DeviceGray, alpha-none format** `segmentPerson` produces —
  downstream (pixel count, `MatteRenderer`, I1 storage) then needs zero
  changes.
- Extract the pure parts — instance-box scan (Float32 buffer, stride by
  `bytesPerRow`), overlap scoring, margin-union selection — into testable
  pure functions (`AnalysisMath` or a sibling pure enum). Unit-test: synthetic
  instance buffers (rider + touching bike + distant clutter) → correct
  IndexSet selected; row-padding case included (the `bd8a273` lesson).
- MatteCheckView's SUBJECT mode becomes a caller of the shared code — the
  harness and the pipeline must not drift apart.

Commit: `refactor(analysis): extract subject segmentation from the matte-check harness`

### J2. Pipeline swap in `AnalysisEngine.analyse`

File: `ios/GetTucked/Analysis/AnalysisEngine.swift`.

- Replace `segmentPerson` with `SubjectSegmentation.subjectMask` for the
  foreground count and `maskImage`. Keep `validatePerson` exactly as is —
  a person must still anchor the capture.
- **Flagged decision — fallback semantics.** If the instance request returns
  nothing but person segmentation would succeed, falling back silently
  changes what the number *means*. Recommendation: fall back to person-only
  **and record which mode produced the number** (J3), surfacing it as an
  amber line on reveal + detail ("PERSON-ONLY MATTE — bike not included"),
  rather than failing the capture outright.
- Uncertainty: keep the ±3% model for now, but re-eyeball edge quality on
  subject mattes in J0 — if bike-spoke regions are ragged, that's a reason
  to widen, honestly, later.

Commit: `feat(analysis): frontal area from rider+bike+bags subject matte (Plan J)`

### J3. Record the mask mode; guard comparisons across the changeover

Files: `ios/GetTucked/Models/PositionMetrics.swift`,
`CaptureView.swift` (`savePosition`), `ComparisonView.swift`,
`LeaderboardView.swift`, `PositionDetailView.swift`.

- Add `var maskMode: String?` to `PositionMetrics` (additive optional; store
  `"person"` / `"subject"`). Old positions have `nil` = person-era.
- A person-only 2,500 cm² vs a subject 5,000 cm² is not a position change —
  it's a definition change. Comparison and Leaderboard must treat cross-mode
  pairs as **not comparable** (reuse the noise-floor "indistinguishable"
  presentation pattern from A4, with copy like "DIFFERENT MATTE MODES — NOT
  COMPARABLE"). Detail screen shows a matte-mode row.
- Simplest honest alternative (Kah's call): after J lands, prompt to archive/
  reset person-era positions instead of carrying the mixed-mode UI burden.
  Recommendation: the not-comparable guard — it's a few view checks and
  destroys nothing.

Commit: `feat(model): record matte mode; block cross-mode comparisons`

### J4. Copy + coaching audit

Files: `HowItWorksView.swift`, `SetTheSceneView.swift`, error copy in
`AnalysisEngine.swift`.

- Methodology copy becomes true as-written — verify, don't assume; the
  uncertainty/±3% wording may need a subject-matte caveat.
- Set-the-Scene coaching: the bike should now be *in* frame deliberately
  (person-era coaching may imply the rider is the subject). AVOID column:
  other salient objects touching the rider (a second bike leaning on them).
- The live BG pill stays person-based (fast, advisory) — note in code why
  that's fine: it gauges background contrast, not the final matte.

Commit: `docs(copy): align coaching and methodology with the subject matte`

## Interactions

- **Plan I first, then J** (I1's `maskData` and I3's metrics fields touch the
  same save path; J3 adds `maskMode` beside them). Both are additive-optional
  fields — no migration stage.
- The scale-plane perspective bias (Plan I "out of scope" note) gets *bigger*
  with the bike in the matte — the system spans more depth. Still a
  methodology-documentation matter, still not a fudge-factor candidate.
- Plan G (side-on live capture) is independent; no file overlap beyond
  `CaptureView` regions.

## Acceptance

A head-on capture of a rider on a loaded bike produces a matte (visible via
the reveal MASK toggle) hugging rider+bike+bags and excluding background
clutter; the area roughly doubles vs person-era captures of the same pose;
the reveal/detail state which matte mode produced the number; person-era vs
subject-era positions refuse to pretend they're comparable; methodology and
coaching copy match reality. Tests green throughout.
