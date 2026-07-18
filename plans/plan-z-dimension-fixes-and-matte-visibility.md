# Plan Z — Dimension coordinate fix, callout placement, honest wheel-check copy, matte visibility

Status: planned 2026-07-18, from Kah's second on-device pass (re-run of the
same night photos after Plans W/X landed).

**Sequencing: lands AFTER Plan Y** (shared files: PositionDetailView,
CaptureView). Queue: Y → Z.

## Z1 — Dimension lines are vertically mirrored (bug)

Root cause, verified: `CalibrationTransform.unitPoint(forScreen:in:)`
produces **top-left-origin** unit coords (screen space, y-down, no flip), so
`handlebarTapPoints` / `wheelTapPoints` / `sideOnTapPoints` are all
top-left. But the comment block in `PositionMetrics.swift` (~line 39) says
the tap points share the Vision skeleton's bottom-left convention — it's
WRONG, and Plan X's `DimensionOverlay` trusted it, mapping taps through
`SkeletonGeometry.point(forUnit:)`'s `1 − y` flip. Result on device: bar
dimension drew near the ground, wheel dimension at the frame top, wheelbase
at shoulder height. (Ghost-compare consumes the same taps top-left directly
— that's the in-repo reference for the correct handling.)

Fix:

- `DimensionOverlay` maps tap-point units **without** the y-flip (plain
  `unit.x * width, unit.y * height` — add a tiny
  `DimensionGeometry.point(forTopLeftUnit:in:)` or equivalent rather than
  borrowing SkeletonGeometry).
- **Fix the lying comment** in `PositionMetrics.swift`: the pose-landmark
  fields are Vision bottom-left; the tap-point fields on `Position` are
  top-left from `CalibrationTransform`. State both conventions explicitly
  where each field lives — this comment already caused one shipped bug.
- Regression test: a unit tap at y=0.9 (near the image *bottom*, top-left
  convention) must land in the bottom 20% of the view, pinned for both a
  bar-style horizontal pair and a wheel-style vertical pair.

## Z2 — Callout placement (Kah's direction, second device pass)

- **Bar width** (horizontal line): callout box sits directly beside the
  line — to the right or left of the bar end, whichever side has room
  (reuse/adapt the direction-picker logic; the box is vertically centred
  on the line, no leader, small fixed gap ~8pt).
- **Wheelbase** (horizontal line, side-on): same treatment — box to the
  left or right of the line, vertically centred.
- **Wheel diameter** (vertical line): unchanged — keeps the 45° leader
  (Kah didn't flag it once mirrored correctly; mid-wheel rarely has
  side room anyway).
- Update DimensionGeometryTests: side-picker chooses the roomier side;
  box stays inside image bounds near the left and right edges.

## Z3 — Wheel-check copy tells the truth (perspective advisory)

Kah hit "Wheel check disagrees 26% — check your taps and the bike's bar
width." on a photo where the real cause is perspective: the front wheel
sits forward of the bar scale plane and the shot was close, so the wheel
measures large. The current copy sends the user to re-check taps that are
fine.

- Rework the warning copy (find every display site via
  `AnalysisMath.wheelCheckDisplay` and the advisory strings in
  PositionDetailView/ComparisonView — keep all sites consistent, the
  wording should live in ONE place in AnalysisMath):
  - Oversized (measured > spec, the common close-shot case): "Front wheel
    reads N% larger than its spec size — usually the camera was too
    close (the wheel sits forward of the bars). Area may read high; try
    standing back and zooming."
  - Undersized: keep a taps/bar-width framing (genuinely the likelier
    cause in that direction).
- Threshold/tiering unchanged — this is copy + direction-awareness only
  (the signed disagreement is already stored as a fraction; verify sign
  convention before writing "larger").
- Update any tests pinned to the old copy.

## Z4 — Make the two-tone matte visible and diagnosable

From the device pass it's unclear whether the subject lift is even
contributing (area moved only ~3%, bike still looks person-only in BONES).

- **BONES mode underlay**: render the same two-tone overlay MASK mode uses
  (Plan W2 wired two-tone into MASK only; BONES kept the old single-tone
  path). One "technical drawing" surface, consistent colours.
- **Diagnosability**: add a "Bike coverage" row to the measurement-detail
  disclosure (PositionDetailView + ComparisonMeasurementDetail): the
  subject-minus-person pixel share as a percentage of the subject mask
  (e.g. "BIKE COVERAGE — 18%"), "—" when there's no subject mask. Zero or
  near-zero instantly tells Kah the lift added nothing on that photo —
  no harness run needed to know *whether* it worked (the harness still
  answers *why* it didn't).
- Spec §3 check: the percentage is pixel arithmetic on stored masks —
  defensible in one sentence.

## Order & commits

1. `fix(design): dimension lines anchor to tap points (top-left origin) + honest coordinate comments` (Z1)
2. `feat(design): bar/wheelbase callouts sit beside their lines` (Z2)
3. `fix(analysis): wheel-check warning names perspective, not taps, when oversized` (Z3)
4. `feat(detail): two-tone matte in BONES mode + bike-coverage row` (Z4)

Done means: build + full suite green; on Kah's same photos the bar line
sits on the bars with the mm box beside it, wheelbase on the hub line,
wheel line on the wheel; the oversized wheel-check message explains
perspective; BONES shows amber bike pixels when the subject mask has any,
and the bike-coverage row makes their absence explicit.
