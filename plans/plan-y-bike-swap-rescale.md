# Plan Y — Wrong bike? Swap and rescale from the position detail screen

Status: planned 2026-07-18. Kah's scenario: a position was analysed against
the wrong bike, so its hard points (bar width, wheelbase, wheel diameter)
— and therefore its scale and every derived number — are wrong. Provide an
explicit swap-and-rescale, one tap from the analysis screen.

**Sequencing: lands AFTER Plans W and X** (all three touch
PositionDetailView). Queue: W → X → Y.

## Why this needs no re-analysis (the core insight)

Masks, tap points, and pose landmarks are photo geometry — the bike only
enters as the mm behind the rulers. Swapping the bike is therefore exact,
closed-form arithmetic on stored metrics. With `r = newBarMm / oldBarMm`
(old = `metrics.handlebarWidthMmUsed`):

- `pixelsPerCm` × (1/r) — same tapped pixel span, different physical width
- `frontalAreaCm2` × r², `frontalAreaUncertainty` × r² (absolute cm²)
- `shoulderWidthCm` × r
- wheel check: recompute the disagreement fraction against the NEW bike's
  `wheelDiameterMm` — reuse the existing derivation exactly (it consumes
  the stored wheel taps + scale); nil it out if the new bike has no
  rim/tyre on record.
- Side-on, with `s = newWheelbaseMm / oldWheelbaseMm`: `sideOnPixelsPerCm`
  × (1/s), `headDropCm` × s — ONLY when `sideOnPixelsPerCm` is non-nil
  (a real wheelbase ruler was used, Plan P1.5) AND the new bike has a
  wheelbase. New bike missing a wheelbase → `sideOnPixelsPerCm` and
  `headDropCm` become nil (spec §3: can't defend the number, don't show
  it). headDropCm borrowed from the frontal scale (sideOnPixelsPerCm nil)
  is already hidden from display, and W/old data rules keep applying.
- Angles (torso/hip), all skeleton/tap points, `foregroundPixelCount`,
  masks: unchanged — they're scale-free or pixel-space.
- `handlebarWidthMmUsed` := new bike's bar width; `computedAt` := now
  (provenance row on the compare screen then discloses the re-run).
- Then reassign `position.bike` to the new bike.

## Y1 — Pure rescale math

`AnalysisMath.rescaledMetrics` (or a small struct of pure functions —
match the file's existing style): takes the old values + old/new mm pairs,
returns the new values. No SwiftData types. Unit tests: round-trip (swap
to B then back to A restores every field to within 1e-9), area scales by
r², side-on nils out when the new bike lacks a wheelbase, wheel-check
recompute matches the capture-time derivation for the same inputs
(pin with one worked example).

## Y2 — The swap flow (PositionDetailView)

- Affordance: a `WRONG BIKE?` ghost-link row (same visual weight as
  `HowItWorksLink`) on the position detail screen, shown only when the
  user has more than one bike. Explicit and discoverable — Kah's stated
  preference — not buried in a menu.
- Tapping presents a sheet listing the other bikes; each row shows the
  nickname AND its hard points ("640 mm bars · 1010 mm wheelbase · 622 mm
  wheel") so the choice is made against the numbers that will become the
  new ruler.
- Selecting a bike shows an inline confirm state (same sheet, not a second
  alert): "Rescales this position using BIKE B's 640 mm bars" plus, when
  applicable, "Side-on numbers will be removed — BIKE B has no wheelbase
  on record." amber. CONFIRM applies Y1, reassigns the relationship,
  dismisses; the detail screen's numbers update in place.
- Cross-bike effects fall out automatically (comparison warning keys off
  `position.bike`; leaderboard re-sorts on its own query).
- This is a SWAP, not a bike edit — editing a bike's bar width and
  retro-rescaling its positions is explicitly out of scope (v1 decision,
  2026-07-18).

## Y3 — Tests

Y1's unit tests above, plus: swap flow appears only with ≥2 bikes
(view-model-level guard if the view isn't directly testable — don't force
UI tests). No schema changes anywhere in this plan (relationship
reassignment and field mutation only), so no GetTuckedApp.swift concern.

## Order & commits

1. `feat(analysis): pure bike-swap rescale math` (Y1 + tests)
2. `feat(detail): wrong-bike swap-and-rescale flow` (Y2 + Y3 guards)

Done means: build + suite green; swapping a two-bike test position updates
area/scale/shoulder width in place and moves it to the other bike; swapping
back restores the originals exactly; a new bike without a wheelbase nils
the side-on numbers with the warning shown before confirm.
