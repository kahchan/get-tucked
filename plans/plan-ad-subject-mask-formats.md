# Plan AD — Why the bike never mattes (subject-lift pixel formats)

**Status:** IMPLEMENTED 2026-07-26 (Part 1: Opus investigation agent; Part 2: two
parallel Sonnet coders — AD2+AD3 and AD5a). **272 tests green** on the combined tree.
Committed locally, not pushed. On-device re-capture pass outstanding (old positions have
no stored subject mask — re-run the Paul photos to see the fix).

**AD5a sweep result (empirical, 128 composites across the four fixtures):** rider
threshold **200**, person-mask erosion **none**. Threshold alone cleared every contact
halo (hoods, top tube, cranks) with no thin-part loss; 230 overshot (helmet vents,
fingertips); *any* nonzero erosion (≥0.25% of width ≈ 10 px) ringed the entire rider
amber, because person and subject masks agree at the true body/background edge — the
erosion mechanism is wired and tested but defaults to no-op. Z4 bike-coverage keeps the
plain 128 split deliberately (displayed diagnostic; changing it silently is off-limits).
**Decisions (Kah, 2026-07-26):** harness runs on the AirDropped Paul 1/2 originals
(drop into `~/Documents/get-tucked-fixtures/` on the Mac); the wheel-check "100%
smaller" anomaly is a separate task, not part of AD; if H4 is proven, STOP and
discuss — no fallback gets built inside this plan.
**Trigger:** 2026-07-26 daylight on-device pass (Paul 1 / Paul 2, adult rider, red brick
wall). Bike still not matted, no amber two-tone anywhere, front wheel excluded from the
matte entirely. This kills the Plan Z8 "it's the night lighting" theory: the subject lift
is failing in ideal conditions too.

## Evidence from the screenshots

- Both positions render a **single acid tint** — the exact appearance of
  `PositionDetailView.buildMaskOverlay`'s fallback branch (`subjectMaskData == nil` →
  `tintedOverlay(mask: personMask, acid)`). The two-tone path never runs.
- The matte hugs the rider's silhouette and bleeds slightly onto adjacent bike tube — the
  signature of `VNGeneratePersonSegmentationRequest`, not a subject lift. Front wheel
  (no person nearby) is cleanly excluded.
- Area numbers (5210 / 6182 cm²) are plausible person-only values, not garbage — so the
  subject mask isn't corrupt, it's **absent**: `segmentSubject` returns nil and every
  consumer silently degrades, by design (Plan W2's "best-effort, never blocks" posture).

So the question is only: **why does `segmentSubject` return nil on every capture?**

## Hypotheses, ranked

### H1 (prime): `instanceBoundingBoxes` reads the instance mask with the wrong pixel type

`AnalysisEngine.instanceBoundingBoxes` (AnalysisEngine.swift ~381) does
`base.assumingMemoryBound(to: Float32.self)` on `result.instanceMask`.

Per WWDC 2023 ("Lift subjects from images") `VNInstanceMaskObservation.instanceMask` is a
**UInt8 label buffer** (0 = background, N = instance index). The iOS SDK header
(VNObservation.h) documents `OneComponent32Float` only for `generateMaskForInstances`,
*not* for `instanceMask`.

If the buffer is UInt8, reading it as Float32 packs four label bytes into one float —
values like 0x00000001 → 1.4e-45, a denormal that `.rounded()` sends to **0** — so every
"pixel" reads as background, `minX` stays empty, the guard fails, and `segmentSubject`
returns **nil, deterministically, on every image**. This single bug explains:
- night no-op (Plan W first pass),
- daylight no-op (this pass),
- bike-coverage row presumably reading "—",
- no amber ever, in both CaptureView reveal and PositionDetailView.

Note W2 shipped with the on-device checkpoint waived, and both Vision requests return nil
in the simulator — so this code path has **never once been observed producing a non-nil
subject mask**. There is no counter-evidence to H1.

### H2 (latent, fix together): `cgImageFromPixelBuffer` assumes 8-bit for the scaled mask

`generateScaledMaskForImage` returns a **OneComponent32Float** soft mask (0.0–1.0).
`cgImageFromPixelBuffer` builds a `CGContext` with `bitsPerComponent: 8` over that
buffer. Once H1 is fixed, the decoded subject mask would be byte-salad (float bytes
thresholded at ≥128 → sparse stripes in the left quarter of the frame), corrupting both
the matte *and the displayed cm²*. Must ship with H1 or we trade an invisible bug for a
visible wrong number — spec §3 forbids that.

### H3: instance selection drops the bike

If Vision returns rider and bike as separate instances, `connectedInstances`' box-overlap
margin (0.06) should catch a bike under a rider — their boxes overlap heavily. Low risk,
but the harness (below) verifies with real photos: log every instance box, which one is
picked as rider, which get unioned.

### H4: Apple's subject lift genuinely won't include the bike

Possible — saliency-based lifting has no obligation to grab a dark bike. If the harness
shows clean instance data but the mask still excludes the bike, this is a product
problem, not a code bug (options: accept person-only + honest copy, or trial
`VNGeneratePersonInstanceMaskRequest` + wheel-tap-informed heuristics — separate plan).

## Part 1 — FINDINGS (2026-07-26, harness run on the four Paul originals)

Harness: `tools/matte-lab/` (SwiftPM macOS CLI, committed-ready, no deps). Ran all four
fixtures (`fixtures/IMG_0674–0677.JPG`); both Vision requests produce real results on
this arm64 Mac. Output PNGs: `tools/matte-lab/output/<image>/1-instance-labels,
2-subject-mask, 3-person-mask, 4-twotone-composite.png` — the 0675 composite was
independently eyeballed: rider green, entire bike (both wheels, frame, fork, rear-rack
bag) orange. The two-tone matte works perfectly once the buffers are decoded correctly.

| Photo | instanceMask fmt | Float32 read (prod) | UInt8 read | scaledMask fmt | area ratio subj/person | bike share |
|---|---|---|---|---|---|---|
| 0674 frontal | OneComponent8, 512² | **0 boxes** | 1 box | OneComponent32Float, 12 MP | 1.20× | 17.6% |
| 0675 side-on | OneComponent8, 512² | **0 boxes** | 1 box | OneComponent32Float, 12 MP | 2.46× | 59.5% |
| 0676 frontal | OneComponent8, 512² | **0 boxes** | 1 box | OneComponent32Float, 12 MP | 1.15× | 16.3% |
| 0677 side-on | OneComponent8, 512² | **0 boxes** | 1 box | OneComponent32Float, 12 MP | 2.70× | 63.1% |

- **H1 CONFIRMED.** `instanceMask` is a UInt8 label buffer (`L008`, 512×512, bpr 512).
  The production Float32 replica returns **zero boxes on every image** (label bytes →
  denormals → `.rounded()` → 0), so `segmentSubject` has returned nil on every capture
  ever taken. This alone explains the night no-op, the daylight no-op, and the
  never-seen amber.
- **H2 CONFIRMED.** `generateScaledMaskForImage` returns `OneComponent32Float` at full
  source resolution (bpr = width×4). `cgImageFromPixelBuffer`'s 8-bit CGContext over
  that buffer reads 1 byte in 4, left quarter only — byte-salad. Must fix with H1.
- **H3 REFUTED.** Apple returns a **single fused instance** (rider+bike together,
  `allInstances = [1]`) on all four photos — the selection machinery has nothing to
  drop. Keep it as defence against stray instances, but it's not the cause.
- **H4 REFUTED.** Correctly decoded, the subject mask includes the full bike in every
  shot. No product fallback needed.

**Expected on-device effect of the fix:** frontal cm² rises ~15–20% over the person-only
5210/6182 baselines (head-on, the rider occludes most of the bike — the 2.5× side-on
ratios are not what area is measured from). Bike-coverage row reads ~16–18% frontal;
amber tint appears everywhere.

**Notes for Part 2 (AD2):**
- `instanceBoundingBoxes`: read labels as UInt8 (stride by `bytesPerRow`); the Float32
  path is dead — branch on `CVPixelBufferGetPixelFormatType`, keep only the real format.
- `cgImageFromPixelBuffer`: add a `OneComponent32Float` branch — per-pixel
  `UInt8(clamp(v,0,1) × 255)` into an 8-bit gray image (stride `bytesPerRow/4`); keep
  the 8-bit path for `segmentPerson`.
- Subject mask is 12 MP vs the person mask's half-res — `maskPixelsPerCm` already keys
  off `areaMask.width` so the math holds, but the per-capture area count now walks a
  12 MP buffer (fine; watch analysis latency on device).

## Part 1 — Investigation method (as planned; retained for reference)

The simulator is useless (both requests nil there — CRITICAL ENV FACT, 2026-07-18), but
**macOS on Apple Silicon runs the same Vision requests natively**. This Mac is arm64.

**AD1 — Mac harness.** A small SwiftPM command-line tool, `tools/matte-lab/` (not in the
iOS target), that takes a photo path and:
1. Runs `VNGenerateForegroundInstanceMaskRequest` + `VNDetectHumanRectanglesRequest`.
2. Prints the **FourCC pixel format** of `instanceMask` and of
   `generateScaledMaskForImage`'s output — the ground truth that settles H1/H2.
3. Prints `allInstances`, per-instance bounding boxes decoded BOTH ways (UInt8 and
   Float32 reads) so the wrong read is demonstrated, not argued.
4. Replicates the production selection (`riderInstance` → `connectedInstances`) and
   writes PNGs: instance-label visualisation, selected-union mask, person mask, and the
   two-tone composite — eyeball artifacts for H3/H4.

Input photos: the Paul 1 / Paul 2 originals (AirDropped to the Mac), any daylight
person-on-bike photo works as a stand-in.

**Exit gate:** the harness output pins the failure to H1/H2/H3/H4 before any production
code changes. If H1 confirmed → Part 2. If H4 → stop, report, decide direction with Kah.

## Part 2 — Fixes (coder sub-agents, parallelisable after the gate)

**AD2 — Format-correct buffer reads** (`AnalysisEngine.swift`):
- `instanceBoundingBoxes`: branch on `CVPixelBufferGetPixelFormatType` — UInt8 path for
  `OneComponent8`, keep a Float32 path only if the harness shows it's ever real.
- `cgImageFromPixelBuffer`: handle `OneComponent32Float` by converting 0.0–1.0 floats to
  an 8-bit gray CGImage (manual pass, same style as the existing byte loops); keep the
  existing 8-bit path for `segmentPerson`'s output.
- Unit tests with synthetic CVPixelBuffers in both formats (label buffer → expected
  boxes; float mask → expected 8-bit threshold behaviour). These run fine in CI/sim —
  they don't need the Neural Engine, only buffer plumbing.

**AD3 — Kill the silent degrade.** A week of "best-effort nil" hid a total feature
failure. Keep the never-blocks posture but make failure *visible*: `segmentSubject`
returns a reason on nil (enum: requestFailed / noInstances / decodeFailed / …), logged,
and surfaced in the DEBUG measurement-detail area next to the Z4 bike-coverage row
("SUBJECT LIFT: —  (noInstances)"). Explicit and discoverable over hidden — house style.

**AD5 — Split quality: make the bike read amber at the contact points** (after AD2 —
two-tone can't render until the buffers decode). Kah's review of the Part 1 composites:
bike pixels adjacent to the body (bars at the hands, saddle/top tube between the thighs,
crank at the foot) classify as rider, because the person mask's soft upsampled halo
clears the ≥128 threshold there. Presentation-only fix — area is the subject mask alone
and is untouched:
- **AD5a (do first):** in the two-tone set op only, raise the person threshold
  (128 → ~200 candidate) and erode the person mask 1–2 px at mask res
  (`CIMorphologyMinimum`, the inverse of the outline dilate). Tune offline in
  matte-lab against all four fixtures; watch for thin rider parts (wrists, ankles)
  flipping amber — that's the overshoot signal.
- **AD5b (reserve):** if halo persists, run person seg on the subject bbox crop so the
  model's fixed resolution covers less area → crisper body/bike boundary. More
  plumbing; only if 5a is insufficient.
- Residual smear at true contact lines (grips, saddle) is genuinely ambiguous at mask
  resolution — past 5a/5b, accept it.
Note: the harness composite's green/orange are placeholder colours; the app already
tints acid/amber via Theme at the MatteRenderer call sites.

**AD4 — Keep the harness.** Commit `tools/matte-lab/` with a README line in CLAUDE.md:
matte diagnosis runs on the Mac, never the simulator. Future matte plans get a real
feedback loop that agents can drive end-to-end.

## Part 3 — Verification

- 262 existing tests + new AD2 tests green.
- Harness re-run on the Paul photos with the fixed code paths: two-tone PNG shows acid
  rider + amber bike, area = subject-mask area.
- Kah re-runs the same two photos on device: amber bike tint visible, bike coverage row
  reads > 0%, area increases vs the person-only 5210/6182 baselines.

## Out of scope (flagged, separate decision)

- **Paul 1's "Front wheel reads 100% smaller than its spec size"** — that message means
  `wheelPixelsPerCm ≈ 0`, i.e. the stored wheel taps are essentially coincident, yet the
  detail overlay draws a full-height 741 mm wheel span. Smells like a tap-persistence or
  coordinate-space bug (Plan Z's top-left-origin fact), unrelated to segmentation.
- H4 fallback strategy (if the subject lift fundamentally can't see the bike).
