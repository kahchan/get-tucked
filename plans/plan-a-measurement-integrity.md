# Plan A — Measurement integrity (what the number means)

Status: **in progress**. Written 2026-07-03 from a full code/plan review.
A1's harness is built (commit `18cb848`); the human matte verdict (real
outdoor photos → `plans/matte-verdict.md`) is still outstanding and gates
A2/A4. A3/A4/A5 not started.
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

**Harness: done** (commit `18cb848`). **Human verdict: outstanding** — waiting
on Kah to shoot ≥5 outdoor photos and record the verdict in
`plans/matte-verdict.md`.

**The open product question:** `VNGeneratePersonSegmentationRequest` is trained
on *people*. It may or may not include the bike, and will not reliably include
bags. But a bikepacking setup's drag is the **rider + bike + bags system** —
the reference render Kah produced (rider + full bike masked, ~5170 cm²) implies
the system is the intended quantity. The code spec instead treats frontal area
as person-only, with bags added separately via tap-to-segment (Phase 3).
If the person mask includes *some* bike inconsistently between captures, the
comparison — the hero feature — is corrupted either way.

**Task:** extend the DEBUG matte-check harness to answer this empirically.

- File: `ios/GetTucked/Views/MatteCheckView.swift`
- Add a segmentation-mode toggle (reuse the existing `ToggleTab`/`PhotoToggleBar`
  pattern): `PERSON` (current, `VNGeneratePersonSegmentationRequest.accurate`)
  vs `FOREGROUND` (`VNGenerateForegroundInstanceMaskRequest`, iOS 17 — combine
  **all** instances into one mask via
  `generateScaledMaskForImage(forInstances:from:)`).
- Show coverage % for each mode, and keep the PHOTO/MATTE display toggle.
- No schema or shipping-UI changes. DEBUG-only.

**Acceptance:** on the same picked photo you can flip between PERSON matte and
FOREGROUND matte and read both coverage figures.

**Then (human step — stop and ask Kah):** run ≥5 real outdoor cyclist photos
(loaded bike, cluttered background — the fixtures in `fixtures/` do NOT count)
through both modes and record the verdict in `plans/matte-verdict.md`:
does PERSON mode bleed onto the bike? does FOREGROUND mode capture rider+bike
cleanly? The verdict decides the product definition:

- If FOREGROUND is stable → frontal area = rider+bike system (matches intent).
- If not → frontal area = rider-only, documented loudly, bags/bike via Phase 3
  tap-to-segment as additive areas.

Note: the design prototype's Methodology screen
(`inspiration/unpacked/template.html`, screen 14) explicitly promises
"We separate you **and the bike** from everything behind you" — the design
intends the rider+bike system. The experiment decides feasibility, not intent.

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
