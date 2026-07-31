# Plan AK — Bike matte completeness, and accessibility (Dynamic Type + VoiceOver)

**Status:** Part 2 ✅ shipped (82df573). AK12 ✅ fixed (dc87556). Part 1 investigation
largely closed — AK7 disclosure recommended; AK1b/AK2 remain as the falsification
checks. AK10/AK11 not started.
**Origin:** Kah, 2026-07-29: fix the matte's missing bike, plus Dynamic Type and
accessibility labels. Part 3 added 2026-07-29.

Three independent workstreams; they share no files.

---

# Part 1 — Matte completeness

Plan AJ recommended disclosure over chasing the matte; Kah asked to chase it. That
changes the standard of proof, not the ambition: **AK1 validation gates everything —
any candidate that can't beat the current mask against measured truth doesn't ship**,
because an added pixel silently inflates every future measurement. Carried from AJ,
still binding: Vision returns exactly one foreground instance on every fixture
(`riderInstance`/`connectedInstances`/`margin` are inert — do not tune, do not re-test
candidate E), and the migration trap is live (AK6).

## AK1 — Validation without hand-painting

### AK1a — macOS Remove Background as a second opinion — ✅ DONE (fb3d16f), closes the model-swap line

Measured at quarter resolution, threshold 128, alpha vs `2-subject-mask.png`:

| | IMG_0674 | IMG_0676 |
|---|---|---|
| agreement (IoU) | **0.965** | **0.956** |
| our subject mask | 35,153 px | 37,684 px |
| Remove Background | 34,099 px | 36,647 px |
| px the reference has that we lack | **92 (0.3%)** | **320 (0.9%)** |
| area change if adopted | **−3.0%** | **−2.8%** |

Same silhouette, same absent rear wheel; the difference is a 1-px edge-feathering rim.
**Swapping Apple segmentation models will not fix this — closed.** Caveat: both models
likely share lineage, so agreement could be a shared blind spot rather than truth.
That caveat is the entire remaining case for AK2.

### AK1b — Landmark coverage check (open, do first)

Every capture already stores human-confirmed landmarks
(`Position.handlebarTapPoints`, `Position.wheelTapPoints`). Test: does the subject
mask contain foreground along the tapped wheel span and handlebar line? If not, it
provably misses the wheel — no labelling, and it runs on every saved position. Two
more free invariants: subject mask ⊇ person mask (any violation is a bug), and
repeatability across re-shots (AJ1). Note `wheelCheckDisagreementFraction` validates
*scale*, not completeness.

### AK1c — Hand-painted truth — deferred

Only if AK2 produces a candidate worth quantifying. If so: correct
`2-subject-mask.png` (already photo-dimensioned), work at ÷4, and settle the subject
rule first — subject is what the wind sees, so spokes and the open frame triangle are
NOT subject. ⚠️ Put truth files in `fixtures/truth/` (see standing traps in
`CLAUDE.md` — `fixtures/IMG_*` is gitignored).

## AK2 — Background-model segmentation (open — one run, as falsification)

The only remaining approach that is methodologically independent (not semantic, can't
share the AK1a blind spot). Expect it to agree; run it once to establish "we are at
the ceiling" with two independent methods. **Run AK1b first — it's cheaper.**

Approach: the app already coaches and measures a plain background (BG pill). Estimate
the background model from the frame border, classify by distance from it, take the
rider's connected component, union with the existing subject mask. Deterministic and
two-sentence explainable (spec §3), no dependencies, fails legibly on clutter.
**Degradation rule:** below `bgConfidenceMin`, don't apply it — never let a
low-contrast scene silently change the number. **Known risk:** ground shadows read as
subject and inflate area; check that first if scores disappoint.

## AK3 — Depth-assisted mask — ❌ CLOSED 2026-07-29 (33152cd)

Kill test: Portrait mode won't engage at the coached 5–6 m standoff — stereo baseline
and LiDAR range physics, not a software gate. Structurally incompatible with the
capture protocol: depth needs the subject close, and the standoff exists to flatten
near-wheel scale error, which corrupts area worse than an incomplete matte. **Do not
reopen** unless the capture protocol changes. (Lesson, reusable: order the kill test
before the build — confirming would have cost depth delivery + a SchemaV9 field.)

## AK4 — Union with person mask / bounded hole fill (fallback, gated on AK1)

- A (union with person mask): safe, small, rider-edge only. Take if AK1 shows an IoU gain.
- B (hole fill): riskiest idea in either plan — frame triangle and spokes pass air.
  Only with a strict hole-area bound and an unmoved false-positive score. Drop if AK2 succeeds.

## AK5 — Rider-assisted correction (design option, Kah's call)

Show the matte, let the rider include/exclude regions by tap. Invents nothing, matches
Kah's explicit-controls preference — but measurement becomes partly manual. A product
decision, not an engineering one.

## AK6 — Migration decision (blocking, before any mask change ships)

A mask change alters every future number while saved Positions keep old ones, and the
leaderboard compares them regardless. STOP-and-ask. Options: (1) recompute saved
positions from stored photos on migration, with a one-time UI note — **recommended**;
(2) version the measurement (`SchemaV9`) and badge cross-version comparisons;
(3) ship nothing, take AJ's disclosure.

## AK7 — Disclosure — the recommended outcome (fb3d16f)

Every automated route closed by evidence: E refuted, AK3 on physics, model-swap by
AK1a. The visual gap is geometric — head-on, the rear wheel and frame sit occluded
behind the front wheel and legs, and occluded structure adds no frontal area. Ship the
disclosure; replace the methodology's "reads a touch low" with AK1's measured figure.
If the *appearance* needs fixing, that's AK5, chosen deliberately.

---

# Part 2 — Dynamic Type and VoiceOver — ✅ SHIPPED (82df573)

AK8: `Theme.Control` tokens converted to `@ScaledMetric`-backed values; the 24 fixed
`.frame(height:)` sites swept (text → scaled `minHeight`; picture boxes and hairlines
stay fixed); verified at AX5 with screenshots. AK9: all icon/glyph controls labelled,
spoken form for the hero number, overlay layers `accessibilityHidden`,
`SegmentedToggleBar` exposes `.isSelected`, status pills announce state, `.isButton`
restored on plain-style buttons. Fixed *widths* were explicitly out of scope — see AK12.

---

# Part 3 — Navigation gestures and horizontal overflow

## AK10 — Swipe back (open)

Cause known: every pushed screen's `hideNavBar()` (`SharedViews.swift`) hides the
navigation bar wholesale, which disables `interactivePopGestureRecognizer` — the
floating `BackButton` is the only way out. Approaches, cheapest first:

1. **Keep the bar, hide its contents** — `.navigationBarBackButtonHidden(true)` + a
   transparent bar appearance, so the system gesture survives. Risk: top-of-screen
   layout shift; check against `NavHeader` spacing (`headerTitleInset`, the
   `BackButton`'s −2 top padding).
2. **Re-enable the recogniser via introspection** — walk to the
   `UINavigationController`, set `isEnabled = true` with a delegate. Exact current
   look, but fragile across iOS releases.
3. **Custom `DragGesture` popping `path`** — must be reconciled with AK11's tab
   swipes (same gesture, different origin) — likely a narrow leading-edge zone.
   **Do AK10 with or before AK11.**

Decide: exclude `CaptureView` (recommended) — it owns its ✕ + discard confirmation
(Q1/Q2); a silent-discard edge swipe would be a regression.

## AK11 — Swipe between tabs, consistently (open)

AB11 added swipe in exactly two places, both attached to *content* not the bar
(`PositionDetailView.photoSwipeGesture`, `ComparisonView.swipeGesture`). Missing:
`LeaderboardView.FilterBar`, the FRONTAL/SIDE-ON segment on detail, and
`SegmentedToggleBar` generally. **Right shape: put the gesture on `SegmentedToggleBar`
itself** so every tab strip gains it at once and the two bespoke swipes retire —
otherwise this recurs. TIME IMPACT distance presets stay tap-only (a swipe changing an
input that feeds a number is a different thing).

Constraints: reuse the standing horizontal-dominance rule (see `CLAUDE.md` traps);
respect the `isZoomed`/`isPhotoZoomed` guards so a zoomed pan never reads as a tab
swipe; reconcile with AK10 if it's gesture-based. Tabs stay tappable — swipe is an
accelerator, never the only route (VoiceOver can't see it).

## AK12 — Horizontal overflow on analyse screen — ✅ FIXED (dc87556)

Dimension callout boxes could land outside the image with no `.clipped()` on
`PositionDetailView`'s photo container, widening the scroll content. Still worth
checking at AX5: the `DiffTable`/`DiffRow` fixed column widths (76/76/70) on Compare
don't scale — AK8 swept heights only — so that's the next overflow source at large
Dynamic Type.

---

## Verification

- Full suite green (329 baseline).
- Part 1: every candidate scored against AK1, false-positive count reported.
- matte-lab on Apple Silicon or device only (see `CLAUDE.md` traps).

## Non-goals

- No re-test of AJ candidate E; no tuning `connectedInstances`/`riderInstance`/`margin`.
- No reintroducing the two-tone matte (Plan AG).
- No new dependencies without asking.
