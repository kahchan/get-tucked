# Plan X — Dimension annotations (the measured hard points, drawn)

Status: planned 2026-07-18. Kah's direction: highlight the "hard" points on
the bike the rider actually measured — bar width, wheelbase, wheel diameter —
as engineering-drawing dimension lines, since they form the ruler basis of
every number in the app. Decisions (Kah, 2026-07-18): callouts show the
**entered spec values** (the ruler itself, honest and consistent); surfaces
are **position detail + the reveal ceremony**; rendered as **part of BONES
mode**, no new toggle.

**Sequencing: lands AFTER Plan W** — W2 touches PositionDetailView's mask
rendering and RevealStep. Do not start until Plan W's commits are on main.

## Context for the implementing agent

Read `CLAUDE.md` first. No schema changes — every input is already persisted:

| Dimension       | Points (unit coords, origin bottom-left)   | mm value                                  |
|-----------------|--------------------------------------------|-------------------------------------------|
| Bar width       | `Position.handlebarTapPoints` (frontal)    | `PositionMetrics.handlebarWidthMmUsed`    |
| Wheel diameter  | `Position.wheelTapPoints` (frontal)        | spec diameter from bike rim+tyre (reuse the same derivation the wheel check uses — find it in AnalysisMath/Bike, do not re-derive) |
| Wheelbase       | `Position.sideOnTapPoints` (side-on)       | `Bike.wheelbaseMm`                        |

Each dimension renders only when both its points AND its mm value exist —
independent graceful degrade per dimension, no partial annotation (a line
with no number, or a number with no line, never appears).

## X1 — DimensionOverlay component

New `ios/GetTucked/Design/DimensionOverlay.swift`, same architecture as
`SkeletonOverlay`: pure geometry enum (testable, no SwiftUI types) + view.

Visual spec (all amber `Theme.Palette.amb`, hard-edged, Space Mono):

- **Dimension line:** dotted (not the calibration screen's 6-4 dash — use a
  tighter dot, e.g. `dash: [2, 3]`), 1pt, drawn between the two tapped
  points, with short perpendicular end ticks (6pt) at each terminal —
  engineering-drawing convention, hard-edged.
- **Callout box:** the mm value as entered/derived, formatted `780 MM`
  (`Theme.mono(9, weight: .bold)`), amber text on `bg0.opacity(0.72)` fill
  (same recipe as `LayerToggleChip`), 1px amber stroke, 0 radius, tight
  padding (4pt).
- **Leader line:** solid (not dotted) 1pt amber, exactly 45°, from the
  dimension line's midpoint to the callout box's nearest corner. Fixed run
  (~36pt at 45°). Direction auto-picks the diagonal (up-left / up-right /
  down-left / down-right) that keeps the box inside the image bounds —
  pure function, unit-tested with corner-case points near each edge.
- Collision with the skeleton is acceptable (both are sparse); collision of
  the box with the image edge is not — the direction picker handles it.

Geometry enum responsibilities (each a pure function): tick endpoints for a
segment, midpoint, leader direction choice given box size + bounds, box
anchor from leader end.

## X2 — BONES mode integration (PositionDetailView)

- Frontal BONES: bar-width + wheel-diameter dimensions over the matte,
  alongside the skeleton. Side-on BONES: wheelbase dimension.
- Same fitted-image coordinate space as `SkeletonOverlay` (unit → view via
  `SkeletonGeometry.point(forUnit:in:)` — tap points share the bottom-left
  origin convention; verify against a stored position, not assumed).
- Appears/disappears with the existing `.skeletonReveal` fade — one
  "technical drawing" layer, no separate ceremony on the detail screen
  (Plan O5's no-draw-on rule for detail views applies).

## X3 — Reveal ceremony integration (CaptureView RevealStep)

- After the skeleton's draw-in completes, the dimensions draw as one quiet
  tertiary beat: dotted line trims on (`Theme.Motion.travel(base)`), end
  ticks with it, then leader + box pop together on completion
  (`jointOpacity`-style smoothstep, causality beat per §13 — the box is
  *caused* by the line finishing).
- Frontal reveal shows bar width (+ wheel diameter when the check was done);
  the side-on reveal path (if RevealStep renders side-on — check; if not,
  detail-only for wheelbase is correct, don't force it).
- Reduce Motion: everything appears with the skeleton's plain fade, no draw.
- Ceremony cancellation (existing `cancelCeremony`) must snap dimensions to
  fully drawn, same as bones.

## X4 — Tests

`DimensionGeometryTests` (new, mirrors SkeletonOverlayTests' style): tick
perpendicularity, midpoint, leader-direction choice pinned for a point near
each image corner (box never exits bounds), 45° slope exactness
(|dx| == |dy|), per-dimension degrade (missing points or missing mm → no
annotation entry).

## Order & commits

1. `feat(design): DimensionOverlay — dotted hard-point dimensions with mm callouts` (X1 + X4)
2. `feat(detail): bar/wheel/wheelbase dimensions in BONES mode` (X2)
3. `feat(capture): dimension draw-on beat in the reveal ceremony` (X3)

Done means: build + full suite green; BONES mode on a position with bar
taps, wheel taps, and a wheelbase shows all three annotations with legible
callouts at typical zoom; a position missing any input just omits that
dimension; reveal plays line-then-box after the skeleton and cancels
cleanly.
