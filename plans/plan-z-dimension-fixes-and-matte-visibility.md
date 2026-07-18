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

## Z5 — Side-on wheel-height dimensions (both wheels)

Kah's second pass: show the wheel diameter on the side-on view too (frontal
already has it), as a second visible hard point. Decision (2026-07-18):
**both wheels**, snazzy visual.

- Data: `sideOnTapPoints` are the wheelbase ruler = the two axle centres
  (confirm: wheelbase is axle-to-axle). Wheel diameter = `bike.wheelDiameterMm`.
  Side-on scale = `sideOnPixelsPerCm`. Both wheels use the same spec diameter.
- For EACH of the two axle taps: draw a vertical span of length
  `wheelDiameterMm` (converted via `sideOnPixelsPerCm`) centred on the axle
  (axle ± radius) — this is the wheel's height in the image.
- **Visual (Kah's "snazzy" spec):** horizontal extension ticks pointing
  outward from the span's top and bottom, a 45° dimension/leader line off the
  span, mm callout box at the leader end. Front wheel's leader points forward
  (its outward side), rear wheel's points rearward — so the two boxes sit on
  opposite ends and never collide with the bike or each other. New
  `DimensionOverlay` variant (a "spanned/diameter" dimension, distinct from
  the point-to-point tap dimension in X1) — pure geometry, unit-tested.
- Degrade: renders only when `sideOnPixelsPerCm != nil` (a real wheelbase
  ruler was used — spec §3, same gate as head drop) AND `wheelDiameterMm`
  AND `sideOnTapPoints` all exist. Depends on Z1's top-left origin fix
  (`sideOnTapPoints` are top-left too).
- Tests: span endpoints from axle + radius; outward-side leader picks the
  correct diagonal per wheel; boxes stay in bounds.

## Z6 — Z-index: dimensions render BELOW bones

Kah: the wheelbase/bar/wheel dimensions should sit *under* the skeleton, not
over it. Today `PositionDetailView` layers matte (line 96) → skeleton (103)
→ DimensionOverlay (109), so dimensions are on top. Reorder to matte →
DimensionOverlay → skeleton (skeleton last = topmost). Same reorder in the
RevealStep overlay stack in CaptureView. Trivial, but do it in both places.

## Z7 — Animated BONES draw-on (every tap, fast, interruptible)

Kah wants tapping BONES on the detail screen to animate in, not fade.
Decision (2026-07-18): **plays every time BONES is tapped.** This
deliberately reverses Plan O5's "no draw-on on the detail screen" rule —
that rule stands for the reveal-vs-inspection distinction, but Kah has
chosen motion here.

Replace the `skeletonReveal` opacity fade (detail-screen BONES only) with a
scripted draw-on, driven by a per-entry progress that resets each time the
segment becomes `.bones`:

- **Matte:** `scanReveal` wipe-in (the existing modifier), ~`Motion.base`
  (0.25s). Kah: "a wipe in for the matte."
- **Skeleton:** draw in **from the top** — reuse `SkeletonOverlay`'s
  `progress` 0→1 draw-on; ensure window ordering runs topmost-first
  (shoulders/head before legs; adjust window indices if the current order
  doesn't read top-down). ~`stagger`×windows + `base` ≈ 0.3s.
- **Dimensions:** the line trims from one tap point to the other (grow
  A→B), box pops on completion — the same causality beat X3 built for the
  reveal. ~`Motion.base`.

CRITICAL (from the find-animation-opportunities pass, frequency gate): this
is an *every-tap* toggle, so the whole thing must stay **under ~0.5s and
be interruptible** — switching to PHOTO/MASK mid-draw snaps it done (a
`cancelCeremony`-style flag), so rapid compare-toggling never stacks or
drags. Do NOT reuse the reveal's full 0.9s `sweep` here — that slow ceremony
stays reserved for the actual first-analysis reveal in CaptureView.
Reduce Motion collapses everything to today's instant fade.

## Z8 — Matte investigation (separate track, gated on the harness)

Kah's device re-run shows the two-tone matte is a **no-op at night**: the
MASK view is all acid (rider), zero amber (bike), and area moved only ~3%
vs pre-W — the rider-anchored subject lift isn't including the dark bike.
Z4 still ships (it's the diagnostic + a daylight win, and the bike-coverage
row will correctly read ~0% here), but the *fix* is its own investigation,
NOT an agent task yet:

- Fixtures folder created at `~/Documents/get-tucked-fixtures/`. Kah drops
  2–3 raw night JPEGs (+ a daylight one if possible); then run
  `SubjectMaskSpikeHarness` to see person mask vs foreground-instance mask
  side by side.
- If subject ≈ person on night shots: try unioning ALL foreground instances
  whose bbox overlaps the rider bbox (not just the rider-connected one) —
  might catch the bike as a separate instance without grabbing the car
  (car is behind/beside; may not overlap the rider bbox). Validate on these
  exact photos that it does NOT pull in the car.
- If Vision genuinely can't segment a dark bike at night: document it, keep
  the person-anchored matte, treat two-tone as a daylight/contrast feature,
  and lean on capture-lighting guidance. Never fabricate bike pixels.
- Pick the branch from the harness output before committing an agent.

## Order & commits

1. `fix(design): dimension lines anchor to tap points (top-left origin) + honest coordinate comments` (Z1)
2. `feat(design): bar/wheelbase callouts sit beside their lines` (Z2)
3. `fix(analysis): wheel-check warning names perspective, not taps, when oversized` (Z3)
4. `feat(detail): two-tone matte in BONES mode + bike-coverage row` (Z4)
5. `feat(design): side-on wheel-height dimensions on both wheels` (Z5)
6. `feat(detail): dimensions render below bones; animated BONES draw-on` (Z6 + Z7)

Z8 is investigation, not a commit — it runs after Kah drops fixtures and the
harness output picks the branch.

This is a large plan (Z1–Z7 implementable + Z8 investigation); it can be
split across more than one agent/session if needed — Z1→Z3 are the bug
fixes and copy, Z4→Z7 the visual/animation build.

Done means: build + full suite green; on Kah's same photos the bar line
sits on the bars with the mm box beside it, wheelbase on the hub line,
wheel line on the wheel; both side-on wheels show a 45° height dimension;
dimensions sit under the skeleton; tapping BONES wipes the matte, draws the
skeleton from the top, and grows the dimensions, all under ~0.5s and
cancellable; the oversized wheel-check message explains perspective; BONES
shows amber bike pixels when the subject mask has any, and the bike-coverage
row makes their absence explicit.
