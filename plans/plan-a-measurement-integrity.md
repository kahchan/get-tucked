# Plan A — Measurement integrity (what the number means)

Status: **in progress**. Written 2026-07-03 from a full code/plan review.
A1's harness is built (commit `18cb848`). **Product definition now decided
(2026-07-07): frontal area = the rider + bike + bags *system*** — see A1.
What's still outstanding is the *feasibility* eyeball (does foreground-instance
segmentation actually capture that system cleanly on real cluttered-background
photos → `plans/matte-verdict.md`); it gates A2/A4. A3/A4/A5 not started.
**A6 added (2026-07-07):** 3D side-on pose trial for posture robustness.
Audience: a smaller model executing tasks one at a time. Do tasks in order.
Each task is self-contained; commit each with a Conventional Commit message.

Verify loop after every task:

```sh
cd ios && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -project GetTucked.xcodeproj -scheme GetTucked \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

Context: the app's whole point is **comparing** frontal areas between setups.
That makes two things load-bearing: (1) the mask must cover the same *kind* of
thing in every capture, and (2) deltas smaller than measurement noise must not
be presented as real. Neither is fully true today.

---

## A1. Decide what "frontal area" includes — experiment first (HIGH priority)

**Harness: done** (commit `18cb848`). **Definition: decided** (2026-07-07).
**Feasibility eyeball: outstanding** — waiting on Kah to shoot real
cluttered-background photos and record the verdict in `plans/matte-verdict.md`.

**Product decision (2026-07-07):** frontal area = the **rider + bike + bags
system** — the whole lit foreground silhouette, not the rider alone. Rationale:
(a) it matches Kah's reference render (rider + full bike, ~5170 cm²) and the
prototype Methodology copy ("you *and the bike*"); (b) for a bikepacking /
ultra audience the **bags** are a large, differentiating part of the drag; and
(c) it's the only definition an on-device request can capture *including bags* —
`VNGeneratePersonSegmentationRequest` is person-only (no bike, no bags), and a
semantic model like DeepLabV3 (person ∪ bicycle classes) still can't see bags,
which have no semantic segmenter. Only saliency-based subject lifting
(`VNGenerateForegroundInstanceMaskRequest`) is class-agnostic enough to grab
them. So the definition dictates the tech: **foreground-instance masking.**

**What the experiment now decides is feasibility, not intent:** can
foreground-instance masking capture the rider+bike+bags cleanly on a real,
cluttered background — and can we reliably drop the clutter (a coat on the wall,
a spare wheel leaning nearby) that saliency will also pick up?

**Task:** extend the DEBUG matte-check harness to answer this empirically.

- File: `ios/GetTucked/Views/MatteCheckView.swift`
- Add a segmentation-mode toggle (reuse the existing `ToggleTab`/`PhotoToggleBar`
  pattern): `PERSON` (current, `VNGeneratePersonSegmentationRequest.accurate`)
  vs `FOREGROUND` (`VNGenerateForegroundInstanceMaskRequest`, iOS 17 — combine
  **all** instances into one mask via
  `generateScaledMaskForImage(forInstances:from:)`). Already built.
- **Add a third mode `SUBJECT` (the real proposed pipeline):** instead of
  unioning *all* foreground instances, select the **rider instance** (the one
  overlapping the `VNDetectHumanRectanglesRequest` box / frame centre) **plus
  instances spatially connected to it** (the bike/bags the rider is on), and
  drop everything else (coat on the wall, leaning spare wheel, background
  clutter). This is what production would actually count — eyeball *this*, not
  raw all-instances. It also subsumes Plan F4's dominant-rider gate: same
  instance-selection logic replaces the brittle `count == 1` reject.
- Show coverage % for each mode, and keep the PHOTO/MATTE display toggle.
- No schema or shipping-UI changes. DEBUG-only.

**Watch for:** **shadows** — saliency may grab a hard shadow behind the rider
(inflating area); semantic wouldn't. Note it in the verdict; mitigation is the
Set-the-Scene diffuse-light coaching, possibly a later low-saturation shadow
reject. **Thin structures** (spokes, cables) may drop out — fine for *area*
(wheels-as-discs and frame tubes dominate), but note where it fails.

**Acceptance:** on the same picked photo you can flip between PERSON, FOREGROUND
(all-instances), and SUBJECT (rider + connected) mattes and read each coverage
figure.

**Then (human step — stop and ask Kah):** run ≥5 real photos (loaded bike with
bags, cluttered background — the fixtures in `fixtures/` do NOT count) through
all three modes and record the verdict in `plans/matte-verdict.md`: does
`SUBJECT` mode capture rider + bike + **bags** cleanly and drop the clutter?
The definition is fixed (rider+bike+bags); the verdict decides **which tech
delivers it**:

- If `SUBJECT` (foreground-instance + rider-connected selection) is clean →
  adopt it as the measurement pipeline; retire person-only.
- If saliency is too noisy (shadows, clutter it won't drop) → fall back, and
  say so loudly in the Methodology copy: e.g. person ∪ bicycle via DeepLabV3
  for the rigid system with **bags excluded and labelled as such**, or
  rider-only + Phase-3 tap-to-add bag areas. These are *fallbacks from the
  intended definition*, flagged honestly — not a silent redefinition.

Whatever ships, the reveal already shows the matte (Plan C1) and must carry a
label stating what's counted ("RIDER + BIKE + BAGS"), so the number is
defensible even when the matte is imperfect and the user can retake.

Note: the prototype Methodology screen (`template.html` screen 14) already
promises "We separate you **and the bike** from everything behind you" — the
design intends the system. The experiment decides feasibility, not intent.

Do **not** change `AnalysisEngine` until the verdict is recorded.

## A2. Methodology screen (spec §11 — ships in v1; design exists)

The design is fully specced: prototype screen **14 · Methodology**
(`inspiration/unpacked/template.html` — `.method-*` CSS + the s14 markup).
Build that screen, not a generic text page:

New file: `ios/GetTucked/Views/HowItWorksView.swift`. Structure per prototype:

1. Header "METHODOLOGY" / subtitle "How the number is made." (D1 pattern).
2. Three numbered rail steps (acc circled numbers joined by a 1px rail —
   circles are correct here, the 0-radius rule exempts dots/radios/circled
   numbers): **Isolate** ("We separate you and the bike from everything
   behind you…" — align this copy with the A1 verdict), **Scale** ("Your
   handlebar width is a known ruler in the frame…"), **Project** ("We sum the
   lit silhouette into one figure: your frontal area, in cm²…").
3. `WHAT THE NUMBER IS — AND ISN'T` two-column block (IT IS: repeatable proxy
   for drag / sensitive to position, not weather / comparable shot to shot;
   IT ISN'T: a wind-tunnel CdA figure / a read on surface or yaw drag / a
   watts-saved promise) — reuse the SetTheScene column pattern.
4. `THE NOISE FLOOR` bordered note box: every reading carries ±N%; re-shoot
   the same position to confirm a change is real. Until the self-test exists,
   N = 3 (the model floor). Add one line the prototype lacks (HANDOFF §2.4):
   the bar-width ruler sits forward of the torso, so absolute area is slightly
   underestimated — this mostly cancels in comparisons.
5. Closing line: "Be informed, don't guess." (Barlow 30, "don't guess." in acc).

Wire-up: add `case howItWorks` to `AppScreen`
(`ios/GetTucked/Design/AppNavigation.swift`), an IndexOverlay entry
("METHODOLOGY"), and links from the three metric screens — on the reveal it's
the tappable NOISE FLOOR block (Plan D4); on `PositionDetailView` and
`ComparisonView` a `Theme.mono(11)` "HOW THE NUMBER IS MADE →" link.

**Acceptance:** screen matches prototype 14; reachable from index + the three
metric screens; every displayed number has its explanation one tap away.

## A3. Calibration sanity check (spec §12 logical edge case)

`AnalysisEngine.analyse` already computes `shoulderWidthCm` from pose. After
analysis, if `shoulderWidthCm` is outside 30–60 cm, the scale is probably
mis-tapped (or the handlebar width is wrong). Surface it, don't block:

- Add `scaleWarning: String?` to `AnalysisResult` (AnalysisEngine.swift).
  Populate with e.g. `"Shoulder width reads 78 cm — check your taps and the
  bike's bar width."` Pure threshold check → put the predicate in
  `AnalysisMath.isShoulderWidthPlausible(_:)` and unit-test it in
  `ios/GetTuckedTests/AnalysisMathTests.swift` (run existing tests first).
- Show it on `RevealStep` as an amber `Theme.mono(11)` line under the
  uncertainty line.

**Acceptance:** unit tests for the predicate pass; warning renders when
shoulder width is implausible; nothing blocks the save.

## A4. Noise-floor honesty in comparisons (interim, before Phase-4 self-test)

The spec calls below-noise-floor handling "the single most important honesty
feature". Don't wait for the Phase-4 self-test — use the existing ±3% model now.

- New pure function in `ios/GetTucked/Analysis/AnalysisMath.swift`:
  `combinedNoiseCm2(uncertaintyA:uncertaintyB:)` = `sqrt(uA² + uB²)`, plus
  `isDistinguishable(areaA:areaB:uncertaintyA:uncertaintyB:)`. Unit-test both.
- `ios/GetTucked/Views/ComparisonView.swift`: when NOT distinguishable, the
  `DeltaHero` shows `WITHIN MEASUREMENT NOISE` (fg2, `Theme.mono(13)` caption
  under a `≈` hero glyph in fg3) instead of a % — with the raw delta shown
  small underneath (`"raw: +0.8% · noise: ±4.2%"`, fg4).
- `ios/GetTucked/Views/LeaderboardView.swift`: `RankRow.deltaText` returns nil
  (renders nothing) when the row is indistinguishable from best.

**Acceptance:** two captures of the same position no longer claim one is
"0.3% smaller"; genuinely different positions still show the % delta.

## A5. Burst capture → empirical uncertainty

Already fully specced as item 1 of `plans/phase2-live-capture-plan.md`
(half-range across 3 frames, floored at 3%). Execute from there **after**
A1's verdict lands, since re-validating numbers twice is wasted work.

## A6. 3D side-on pose trial — experiment first (posture, not area)

**Frame this correctly before touching it:** 3D pose does **nothing** for the
hero number. Frontal area already captures upright-vs-tucked (a tuck *is* a
smaller area, straight off the head-on matte). 3D body pose is a **posture**
tool — it explains *how* a rider achieved an area (hip hinge vs rounded back vs
arm width) and could make the posture angles better. Its job is to be evaluated
against the **2D** side-on pose the app already computes
(`VNDetectHumanBodyPoseRequest` → `AnalysisMath` torso/hip/head-drop), not to
add a new headline metric.

**Why it might help** (`VNDetectHumanBodyPose3DRequest`, iOS 17 — lifts a 3D
skeleton from a *single* RGB image, no LiDAR needed; joints in metres relative
to a root, single most-prominent person; monocular depth is approximate):
- **Alignment robustness.** The 2D angles assume a near-perfect perpendicular
  side-on; any camera yaw foreshortens them. 3D recovers the true sagittal
  torso/hip angles regardless of squareness. A clean side-on is hard to shoot,
  so this is a real gain.
- **Cross-session comparability.** A 3D-normalised tuck/torso angle is
  comparable between sessions even when framing differs — which is the whole
  point of iterating a position over time.

**Why it might not** (the honest risks — this is a *measurement-integrity*
plan):
- **Monocular depth is approximate.** A "torso 42°" off noisy 3D depth risks
  fake precision (spec §3). If adopted, the angle needs an honest, wider ± than
  the in-plane 2D version — not a tighter one.
- **Bike occlusion is the specific threat.** Side-on, the wheel and frame
  occlude the **hips and knees** — the exact aero-relevant joints. Both 2D and
  3D degrade under occlusion; 3D's depth inference may degrade unpredictably.
  This is the crux and can only be settled empirically.
- Newest of the Vision pose requests; least-proven on this hard case.

**Task (experiment, do not wire into the pipeline yet):**
- Extend the side-on analysis to run `VNDetectHumanBodyPose3DRequest`
  *alongside* the existing 2D request (DEBUG comparison surface — reuse the
  `MatteCheckView` harness pattern or add a sibling), and put the 3D-joint →
  angle math in pure functions in `ios/GetTucked/Analysis/AnalysisMath.swift`
  (testable next to the 2D ones).
- On the same side-on photo, compare 3D vs 2D torso/hip angles under two
  deliberate stresses: **(a) off-perpendicular framing** (where 2D is known to
  break) and **(b) bike occlusion of the lower body.**

**Then (human step — stop and ask Kah):** record in `plans/matte-verdict.md`
(or a sibling `pose-3d-verdict.md`) whether 3D beats 2D on both stresses
*without* inflating uncertainty. **Adopt only if it does.** If occlusion wrecks
the hip/knee joints, keep 2D and lean on the PERP pill to keep side-ons square.

**Acceptance:** a DEBUG surface shows 3D and 2D angles side by side on the same
photo; the comparison verdict is recorded; `AnalysisEngine`'s shipping pipeline
is unchanged until the verdict says adopt.
