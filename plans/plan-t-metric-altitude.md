# Plan T — metric altitude: reorder analysis & comparison content

*Status: direction agreed 2026-07-17, specifics pending build. Pairs with Plan S —
S2's "so what" section lands at the top of the hierarchy defined here, so build T's
tiering either just before or together with S2's ComparisonView work.*

## The problem

`PositionDetailView`'s `MetricsSection` and `ComparisonView`'s metric table each render
one flat list that interleaves three different species of information at the same
visual altitude:

1. **The outcome** — frontal area (hero), the comparison verdict.
2. **Consistency signals** — shoulder width, torso angle, hip angle. Their real job is
   feeding warnings (`poseDeltaWarning`, `shoulderWidthWarning`), not being read as
   standing numbers.
3. **Provenance / diagnostics** — scale px/cm, bar width used, wheel check, foreground
   pixels, computed-at. Audit trail, not content. "Foreground pixels" is pure debug.

A reader can't tell which numbers are the answer, which are guardrails, and which are
the receipt.

## Decisions already made (from the 2026-07-17 discussion)

- **Torso and hip angle: demote, don't delete.** They power the pose-delta advisory —
  the P1 consistency guardrail — so they stay computed and stored unchanged. But hip
  angle is a bike-fit number, not an aero one, and torso angle is largely redundant
  with the area it produces. As standing rows they're noise.
- **Exception-based display for consistency signals.** In the comparison table, show
  torso/hip *only when the pose-delta advisory fires* — at that moment they're the
  evidence ("torso 12° vs 18° — some of this delta is you"). Same pattern shoulder
  width already follows on the detail view (warning-only); extend it.
- **Head drop keeps secondary visibility.** It's the one posture number riders actually
  talk about (bar drop / head position). Stays a visible row where present.
- **Provenance goes behind a visible, collapsed disclosure** — labelled along the lines
  of "MEASUREMENT DETAIL". Per Kah's standing preference: discoverable, not hidden —
  the audit trail is part of the honesty story, it just doesn't share altitude with
  the answer. Contents: scale px/cm, bar width, wheel check, foreground pixels,
  computed-at. **Exception:** a *failing* wheel check (amber) must escape the
  disclosure and surface at tier 2 — a warning nobody sees isn't a warning.

## Target hierarchy

### Position detail (`PositionDetailView`)
1. Frontal area hero + uncertainty (unchanged).
2. Warnings, exception-based (shoulder-width warning — as now; amber wheel check moves
   up to here).
3. Head drop (when present, with its existing ruler gate).
4. `MEASUREMENT DETAIL` disclosure (collapsed): shoulder width, torso, hip, scale,
   bar width, wheel check row, foreground pixels, computed-at.
5. Photo/matte and bike sections as currently ordered.

### Comparison (`ComparisonView`)
1. **"So what" block** (Plan S2): time band lockup — or the indistinguishable / wake
   verdict when gated.
2. Area A / B / delta (the current verdict block, now serving the time figure above it).
3. Advisories, exception-based: pose-delta warning **with the torso/hip rows rendered
   directly beneath it as evidence, only when it fires**; different-bikes note; amber
   wheel check.
4. Metric table, reduced to standing rows: area, head drop (when present on both).
5. `MEASUREMENT DETAIL` disclosure: everything else the table shows today (torso, hip,
   shoulder width when un-warned, scale, bar widths, etc.).

## Non-goals

- No changes to what's computed, stored, or how (`PositionMetrics` untouched).
- No new metrics.
- No redesign of the matte/photo presentation.

## Notes for build

- The disclosure component should be one shared view (both screens), styled on the
  design tokens — 0px radius, mono label, no chevron-pill styling from system defaults.
- Reduce Motion: disclosure expand/collapse falls back to a fade, matching the Plan R
  motion rules.
- Tests: the display-gating logic (what shows when the advisory fires / wheel check
  ambers) should live in a pure helper so it's testable without view inspection —
  same pattern as `wheelCheckDisplay`.
- `ComparisonView.swift` has uncommitted working-tree changes (pre-existing) — land or
  stash before starting.

*Last updated: 2026-07-17.*
