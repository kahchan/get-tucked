# Plan AN — posture Cd from the side-on bones (teaching, not estimate)

Status: planned 2026-08-13, from Kah's ask ("change our approx CdA based on
body position, guessed from bone angles in the side-on view").

**Decision, made 2026-08-13, before build:** posture Cd goes in the teaching
panel, in **three named bins**, and the estimate stays Cd-invariant. The
comparison keeps cancelling Cd and stays pure area.

Two reasons, one line each. A continuous Cd(θ) read off two Vision joints
claims an angle resolution our pose noise almost certainly doesn't support.
And letting Cd vary per side would let a position read *better* on the
estimate while reading *worse* on area — honest physics, but exactly the
editorialising `plans/torsten-aero-notes.md` §D warns off, on a curve we'd be
borrowing rather than measuring.

What we gain instead is an honesty statement we currently can't make: **our
estimate under-reads a tuck**, because a tuck lowers the drag coefficient as
well as the area, and we only see the area. That's the panel's thesis.

**AN1 is a gate.** If the literature doesn't clear its bar, nothing ships but
the position label — no ratio, no percentage.

## Context for the implementing agent

Read `CLAUDE.md` first, including the standing traps. This plan deliberately
touches nothing load-bearing:

- **No new persisted fields, so no schema bump.** Everything needed is already
  stored: `PositionMetrics.torsoAngleDeg`, `.hipAngleDeg`, `.headDropCm`,
  `.sideOnSkeletonPoints`, `.sideOnArmPoints`. The bin is derived at display
  time. Cite the schema trap as the reason — don't "cache" a class.
- **No change to `EffortModel`, `ComparisonView`, `docs/site.js`, or the watts
  chip at `PositionDetailView.swift:1000`.** `assumedCd = 0.7` stays a
  constant and stays Cd-invariant across a comparison, so
  `ComparisonView.swift:960`'s "equal drag coefficient" stays true.
- **No change to the hero number**, the ±3% area band, or the noise floor.

Verify: `cd ios && xcodegen generate`, full suite on an iPhone simulator.

## The one constraint that shapes the ingest (read before AN1)

**We already measure A. Literature reports CdA. A published CdA-vs-position
curve bundles both effects, and quoting it next to our area number would
double-count.**

Position changes drag two ways: it shrinks the projected area (we measure
this) and it changes the shape's drag coefficient (we don't). The panel is
only allowed to talk about the second. So:

- A source is usable **only if it reports frontal area A and drag area CdA for
  the same position**, or reports Cd with its reference area stated. A paper
  reporting CdA alone is unusable here, however good it is.
- We derive `Cd = CdA / A` per position, per study.
- We pool **within-study ratios** `Cd(bin)/Cd(reference bin)`, never absolute
  Cd across studies. Between-study Cd scatter is clothing, helmet, bike and
  tunnel method — invisible to us, and it cancels in a within-study ratio.

Everything the panel says is a ratio relative to a normal riding position.
No absolute Cd is ever displayed.

## AN1 — Literature ingest (blocking)

Deliverable: `plans/posture-cd-sources.md` — one table, one row per
(study, position), plus a verdict paragraph.

Columns: `study | year | method (tunnel/CFD/field) | position label | torso
angle as published | angle reference (from horizontal / from vertical) |
θ_app | A m² | CdA m² | Cd = CdA/A | rider+bike or rider only | n riders |
notes`.

Rules:

- `θ_app = 90° − θ_from_horizontal`. Our convention is
  `AnalysisMath.torsoAngleDeg` — shoulder→hip from **vertical**, 0° upright,
  90° horizontal. Record the published convention verbatim in its own column
  and show the conversion; a silent sign error here inverts everything.
- Reject rows whose reference area isn't the projected frontal area of the
  same system we measure (rider + bike). Rejected rows stay in the table,
  marked, with the reason — so nobody re-ingests them next time.
- Quote nothing beyond a short attributed line; link out. Same rule the
  methodology page's existing citations already follow.

Starting candidates (verify every number in the paper itself — not from an
LLM, not from a blog, not from this plan):

- Defraeye, Blocken, Koninckx, Hespel & Carmeliet (2010), *J Biomech* —
  upright / dropped / TT, tunnel + CFD, reports frontal areas.
- Fintelman, Sterling, Hemida & Li (2014–15) — torso angle swept in steps;
  the closest thing to a purpose-built Cd-vs-torso-angle dataset.
- Crouch, Burton, LaBry & Blair (2017), *Sports Engineering* review — an index
  into primary sources, not itself a source.
- García-López et al. (2008), *J Sports Sci* — reference values, pro riders.
- Barry, Burton, Sheridan, Thompson & Brown — rider/limb position tunnel work.

**Acceptance bar — all three, or we ship the label with no numbers:**

1. ≥3 independent studies, ≥8 usable (position, A, CdA) rows in total, with
   at least two studies covering each of the three bins.
2. Every study's within-study Cd ratio moves in the **same direction** from
   upright → tucked → aero. Sign disagreement between studies = stop.
3. The pooled between-study spread of each bin's ratio is smaller than the
   gap between adjacent bins' ratios. If the bins overlap inside their own
   scatter, they aren't three findings — they're one, and the panel says so
   in words instead of showing three numbers.

Verdict paragraph: pass / label-only, in one paragraph, with the reason.

## AN2 — The bins

`ios/GetTucked/Analysis/PostureCd.swift`, pure, no UI types, no SwiftData.

- `enum PostureBin { case upright, tucked, aero }` with θ_app boundaries taken
  from AN1's own position labels — not invented here, and the chosen
  boundaries recorded in `posture-cd-sources.md` next to the rows that
  justify them.
- `static func bin(torsoDeg: Double) -> PostureBin`
- `static func cdRatio(_ bin: PostureBin) -> Double` — 1.0 at the `tucked`
  reference bin (a normal hoods/drops riding position, where today's
  `assumedCd = 0.7` already lives), and the pooled within-study ratio for the
  other two. Each value carries its source in a comment.
- `static func ratioSpread(_ bin: PostureBin) -> Double` — the pooled
  between-study spread for that bin, as a fraction. Cited, not guessed; it's
  what stops the panel quoting a bare percentage it can't stand behind.

Nothing in this file is read by `EffortModel`. That's deliberate — the
one-way dependency is the guarantee that the estimate can't drift into using
these numbers by accident.

## AN3 — Pose → bin

`AnalysisMath` already computes everything; AN3 adds a read seam and one
measured number.

- **Only `torsoAngleDeg` selects the bin.** Hip angle, head drop and forearm
  angle refine the *wording* of the label, never the bin — no AN1 source will
  support them as Cd inputs.
- **Forearm angle** (label only): derive from `sideOnArmPoints`
  (elbow, wrist) against horizontal. Nil-safe; absent arms just mean a
  coarser label.
- **`positionLabel(torsoDeg:forearmDeg:headDropCm:) -> String?`** — returns
  nil rather than guessing when torso angle is missing.
- **Measure the torso-angle noise on device.** Repeat side-on captures of one
  held position, using the burst machinery already in `AnalysisMath`
  (`spreadFraction`, `burstSpreadRetryThreshold`); record the observed spread
  in degrees in `posture-cd-sources.md`. **If that spread is wider than the
  narrowest bin, the bins are not separable and AN1's gate 3 fails on our own
  instrument, whatever the literature says.** Device only — Vision is nil in
  the Simulator (standing trap), and pose is no better.

## AN4 — What the user sees

Two surfaces, both teaching. No number moves anywhere else in the app.

- **Position detail** (`PositionDetailView.swift:931`, the existing "Torso
  angle" `MetricRow`): append the label — `38° — tucked`. One row, no new
  section, nil-safe as today.
- **Methodology** (`HowItWorksView`, a new section between
  `LimitationsSection` and `ReferencesSection` — it is a limitation, and it
  reads as one): the panel's thesis, in this order.
  1. Position changes drag two ways: how big you are, and how slippery.
  2. We measure the first. The second we can't see from a photo.
  3. What the literature finds, per bin, as a ratio relative to a normal
     riding position — with the spread shown, never a bare figure.
  4. **Therefore our estimate under-reads a tuck**, and by roughly how much.
     This is the sentence the section exists for.
  5. Citations appended to the existing `ReferencesSection` list.
- **Label-only fallback** (AN1 gate fails): points 1, 2 and 4-in-words, no
  ratios, no percentages. "A tuck also makes you more slippery, which we
  can't measure — so this estimate is conservative for tucked positions."

## Verification

- `PostureCdTests`: bin boundaries match the table; ratio is exactly 1.0 at
  the reference bin; ratios are ordered in the documented direction; every
  value matches `posture-cd-sources.md` (the test is the thing that stops the
  file and the code drifting apart).
- `AnalysisMathTests`: `positionLabel(torsoDeg:)` delegates to `PostureCd.bin`
  — boundary behaviour is tested once, at `PostureCd`.
- **Regression lock deferred**: no `EffortModelTests` lock yet — there's no
  numeric `PostureCd` output for `EffortModel` to consume until AN1 lands and
  AN2 gains `cdRatio`. Add the lock then.
- On-device: an upright and a tucked capture of the same rider land in
  different bins, and the detail row reads sensibly for both.

## Non-goals

- **Posture does not enter the estimate.** Not the time delta, not the speed
  delta, not the watts chip. Kah's call, 2026-08-13 — reopen it deliberately
  or not at all.
- No continuous Cd(θ) curve.
- No Cd from hip angle, head drop, arm position, clothing or helmet.
- No yaw / crosswind model.
- No absolute Cd or CdA figure shown anywhere in the UI. We remain an area
  tool (`torsten-aero-notes.md` §D).
- No new persisted field, no schema version, no `docs/site.js` change.
