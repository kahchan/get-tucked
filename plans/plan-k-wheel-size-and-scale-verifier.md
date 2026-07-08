# Plan K — Wheel size on the bike + optional tap-to-verify scale check

Status: **not started.** Written 2026-07-08 after Kah adopted both halves of
the cross-scale idea recorded in
[`plan-i-matte-on-detail-and-number-trust.md`](plan-i-matte-on-detail-and-number-trust.md)
(idea-stage section), with one directive: **the verification taps are
optional** — never a gate on capture.

## What this buys

The front wheel's overall diameter is a second known dimension, and the
wheel is visible in *both* photos at ~the bar's depth plane:

- **Frontal:** the wheel edge-on is a vertical circle parallel to the camera
  axis — its projected *height* equals its true diameter. Ground contact +
  tire top = a second, independent ruler in the same photo as the bar taps.
  Catches the most dangerous silent error in the pipeline: a mis-entered bar
  width (squared into area). 440-entered-vs-760-actual = 73% ruler
  disagreement; the check needs only ~±5% precision.
- **Side-on:** the wheel is a full circle — an alternative (or complement)
  to Plan G's wheelbase axle-taps for giving side-on its own ruler.
- Setup metadata in its own right — wheel/tire choice is part of a
  bikepacking setup worth recording per bike.

Verification only, never silent replacement (spec §3): the bar width stays
THE ruler; the wheel check exists to catch mis-entry, and it's skippable.

## Flagged decisions for Kah

1. **How wheel size is entered.** Recommendation: two fields on the bike —
   rim standard picker (700C / 650B / 26″ / 27.5″ / 29″ → ISO bead-seat
   diameter: 622 / 584 / 559 / 584 / 622 mm) + tire width in mm; computed
   `overallDiameter ≈ beadSeat + 2 × tireWidth`. Bikepackers know their tire
   size cold ("700×45"); nobody knows their inflated overall diameter.
   Alternative: a single "measured diameter mm" field. The approximation is
   good to ~±1–2% (inflated height ≠ nominal width exactly), fine for a
   ~10% disagreement threshold.
2. **Disagreement threshold + copy.** Recommendation: amber warning above
   ~8–10% ("Bar taps and wheel size disagree by 18% — check this bike's bar
   width"), same advisory posture as the shoulder-width check. Never blocks.
3. **Where the optional taps live.** Recommendation: after the two bar taps
   on the calibration screen, a ghost link "VERIFY WITH WHEEL (OPTIONAL)"
   reveals two more tap targets (tire ground contact, tire top) with its own
   skip; CONFIRM SCALE stays enabled regardless. Zero new screens.

## Tasks

### K1. Wheel size on the Bike model + setup form

Files: `ios/GetTucked/Models/Bike.swift`,
`ios/GetTucked/Views/BikeSetupView.swift`,
`ios/GetTucked/Capture/BikePickerSheet.swift` (inline add-bike form).

- Additive optional fields per decision 1 (no migration stage): e.g.
  `rimStandard: String?`, `tireWidthMm: Double?`, plus a computed
  `wheelDiameterMm: Double?` (nil unless both set). Also fold in the
  already-agreed `wheelbaseMm: Double?` (Plan G decision 4) so the model
  changes land once.
- Both bike forms get the optional fields, visually secondary to
  nickname/type/bar width (they're optional — don't let the form read as
  longer/scarier). `Bike.isValidInput` unchanged — optional means optional.

Commit: `feat(model): optional wheel size + wheelbase on Bike`

### K2. Pure verifier math + tests

Files: `ios/GetTucked/Analysis/AnalysisMath.swift`, `ios/GetTuckedTests/`.

- `wheelPixelsPerCm(groundTap:topTap:imageSize:wheelDiameterMm:)` (reuses the
  bar-tap geometry, vertical distance) and
  `rulerDisagreementFraction(barPixelsPerCm:wheelPixelsPerCm:)`.
- `overallWheelDiameterMm(beadSeatMm:tireWidthMm:)`.
- Unit-test all three (agreement, big disagreement, threshold edges).

Commit: `feat(analysis): pure wheel-ruler verification math`

### K3. Optional wheel taps on the calibration step

File: `ios/GetTucked/Capture/CaptureView.swift`
(`HandlebarCalibrationStep`).

- Per decision 3: after two bar taps, if the selected bike has a
  `wheelDiameterMm`, show the optional verify affordance; two extra taps
  reuse the existing zoom/loupe/drag machinery (points 3 and 4, different
  accent). Skippable at any time; CONFIRM SCALE never waits on it.
- Thread the wheel taps into `runAnalysis` → disagreement beyond threshold
  becomes a `scaleWarning`-style amber line on the reveal (and rides along
  to the detail screen via Plan I4's display logic — same recompute-at-
  display pattern, so persist the wheel taps / disagreement input, not the
  string).

Commit: `feat(capture): optional wheel-tap scale verification`

### K4. Surface it

Files: `CaptureView.swift` (`RevealStep`), `PositionDetailView.swift`.

- Reveal + detail: when the verifier ran, a metric row ("Wheel check ·
  agrees ±3%" / amber "disagrees 18%"). When skipped: no row, no nagging.

Commit: `feat(ui): show wheel-check verdict on reveal and detail`

## Interactions

- **After Plan I** (shares the detail-screen warning surface and the
  metrics-persistence pattern). Independent of Plan J. Plan G's side-on can
  later use `wheelDiameterMm` as an alternative axle-tap ruler — noted
  there; no dependency either way (K1 lands `wheelbaseMm` for it).
- The frontal wheel plane ≈ bar plane also matters for the perspective-bias
  work (Plan I protocol note): a wheel-derived ruler inherits the same
  scale-plane bias as the bar ruler, which is exactly why they're comparable
  at all. Don't "correct" either; compare like with like.

## Acceptance

A bike can optionally record tire/rim (and wheelbase); calibration offers —
never demands — two wheel taps when wheel size is known; a mis-entered bar
width produces a loud, specific, advisory disagreement warning on reveal and
detail; skipping the verifier changes nothing else; math is unit-tested;
tests green.
