# Plan AK — Bike matte completeness, and accessibility (Dynamic Type + VoiceOver)

**Status:** All four parts closed. Part 1: disclosure (AK7) is the outcome, no automated
route beat the current mask; AK5 (rider-assisted correction) reopened and implemented
2026-08-08, uncommitted, device pass outstanding. Part 2 ✅ shipped (82df573). Part 3/4: swipe-back and tab-swipe shipped and
**device-verified 2026-08-06** (cafa71a) — see AK15–AK19.
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

### AK1b — Landmark coverage check — ✅ RUN (uncommitted, `tools/matte-lab --ak1b`)

PASS on both frontal fixtures (IMG_0674/0676) — mask fully covers tapped wheel/handlebar
spans with wide margin. `subject ⊇ person` violated everywhere but small (0.05–3.15% of
person px) — 1-px edge feathering, not a hole, consistent with AK1a. AJ1 repeatability:
the violation *rate* varies 0.35% vs 3.15% between the one re-shot pair — a real but
small signal, not investigated further. Caveat: real `Position.wheelTapPoints`/
`handlebarTapPoints` aren't reachable from this Mac (device-only SwiftData) — used
eyeballed stand-ins on the 2 fixtures that are frontal; treat as directionally correct,
not exhaustive.

### AK1c — Hand-painted truth — deferred

Only if AK2 produces a candidate worth quantifying. If so: correct
`2-subject-mask.png` (already photo-dimensioned), work at ÷4, and settle the subject
rule first — subject is what the wind sees, so spokes and the open frame triangle are
NOT subject. ⚠️ Put truth files in `fixtures/truth/` (see standing traps in
`CLAUDE.md` — `fixtures/IMG_*` is gitignored).

## AK2 — Background-model segmentation — ✅ RUN, inconclusive (`tools/matte-lab --ak2`)

Not a refutation — blocked on fixtures. Neither IMG_0674 nor IMG_0676 has a plain
background (weathered brick, a structural beam, graffiti); the degradation gate
correctly fired (border std ~83–86, well past `bgConfidenceMin`) and refused to report
a number rather than force one. Union was a near-empty no-op (5–9px) on both. Needs a
fixture shot against a genuinely flat surface (what the BG pill coaches for) before
this check means anything — not worth chasing further without one.

## AK3 — Depth-assisted mask — ❌ CLOSED 2026-07-29 (33152cd)

Kill test: Portrait mode won't engage at the coached 5–6 m standoff — stereo baseline
and LiDAR range physics, not a software gate. Structurally incompatible with the
capture protocol: depth needs the subject close, and the standoff exists to flatten
near-wheel scale error, which corrupts area worse than an incomplete matte. **Do not
reopen** unless the capture protocol changes. (Lesson, reusable: order the kill test
before the build — confirming would have cost depth delivery + a SchemaV9 field.)

## AK4 — Union with person mask / bounded hole fill — moot for now

AK1b/AK2 showed no IoU gain to take (A) and AK2 didn't succeed cleanly enough to drop
(B) outright, but there's nothing to union — both checks came back "no improvement
found," not "found and gated." Revisit only if AK2 gets a proper plain-background
fixture and finds something.

## AK5 — Rider-assisted correction — ✅ IMPLEMENTED 2026-08-08 (uncommitted)

Rider corrects the head-on subject matte with TAP (flood-fill flip of the contiguous
region under the finger) + BRUSH (freehand INCLUDE/EXCLUDE), and the correction changes
the real stored/displayed `frontalAreaCm2`. SchemaV11 adds
`Position.correctedSubjectMaskData` and `PositionMetrics.correctedFrontalAreaCm2`; the
originals are never overwritten. 374 tests green (baseline 351, +23).

**Files:** `Analysis/MaskCorrection.swift` (new — actions replay, flood fill, recompute),
`Analysis/MatteRenderer.swift` (`editableMaskContext` / `maskPNGData(from:)` — the
decode/encode inverse of `downscaledMaskPNGData`), `Views/MaskCorrectionEditor.swift`
(new), `Models/{Position,PositionMetrics,AppSchema}.swift`, `App/GetTuckedApp.swift`,
`Views/{PositionDetailView,ComparisonView,LeaderboardView,PositionListView,BikeSwap}.swift`,
`Design/Components.swift` (`CorrectedAreaNote`), `GetTuckedTests/MaskCorrectionTests.swift`.

**Decisions taken during implementation** (the plan left these open):
- **Editor is a `fullScreenCover`, not an inline MASK-tab mode.** The detail photo already
  carries `.pinchZoomable` + `.segmentedSwipe`; a freehand drag can't share that hit
  region without one of the three losing. MASK tab gains a `CORRECT THE MATTE` link.
- **Preview is the pipeline's own output**, re-rendered off-main after each committed
  action — a flood fill has no cheap vector equivalent, and a preview that can disagree
  with the measurement is exactly the number §3 forbids. Only the in-flight brush stroke
  is drawn as vectors.
- **Read seam:** `PositionMetrics.effectiveFrontalAreaCm2` + `.isManuallyCorrected` +
  `.effectiveFrontalAreaUncertainty`. The last one is an addition the plan missed — the ±
  band is stored as an absolute cm² but is a fixed *fraction* of area, so an uncorrected
  band next to a corrected number silently claims the wrong precision. Rescaled by the
  same ratio; no new stored field.
- **`BikeSwap.apply` rescales `correctedFrontalAreaCm2` by the same r²** — the plan didn't
  mention it, and without it a swap strands the displayed area on the pre-swap ruler.
- **Ghost-compare (`ComparisonView.buildGhostCompareLayer`) takes the corrected
  mask+area as a PAIR.** It reconstructs its own scale from the two, so a corrected area
  against an uncorrected mask mis-sizes the ghost. Not a non-goal violation — the AK5
  non-goals name `bikeCoverageFraction` and the two-tone composite, both of which stay on
  the automated `subjectMaskData` as written.
- **MASK tab shows the corrected matte** once one exists (it's the matte that produced the
  displayed number); `bikeCoverageFraction` beside it deliberately does not.
- **Disclosure:** `CorrectedAreaNote` — amber, same exception-based slot as the
  shoulder-width/wheel-check advisories. Sentence form under the hero number, `CORRECTED`
  compact form on list/leaderboard/comparison rows. Detail's tier-4 disclosure gains an
  `Automated area` row, so the automated number stays visible, not just stored.

**Verified by test, no device needed** (`MaskCorrectionTests`, 23 tests): PNG
decode→edit→recompute→encode→decode round trip byte-exact; zero-actions is a true no-op on
the number; flood fill respects padded `bytesPerRow`, is 4-connected, and selects
background when seeded on background; tap-flip removes a detached blob with an exact area
change; both tools confirmed TOP-left origin (the brush flips to CG's y-up, the fill
doesn't — the one place the two conventions meet); action order is load-bearing; replay is
pure so UNDO truly reverts and the original mask is never mutated. Plus a container-build
test guarding the `Schema(versionedSchema:)` standing trap directly.

**Needs Kah on a device** (scripted simulator input proves nothing about touch — see
standing traps): does the drag feel right and track the finger; is the fixed brush
(`MaskCorrection.brushRadiusUnit = 0.03` of the long edge) the right size, or does v2 need
a size control after all; does TAP select regions at a useful granularity on a real matte
(a leaky 1-px bridge between rider and background would make one tap flip everything —
the pure tests can't predict this on real segmentation output); does the preview keep up
between strokes at full mask resolution; does `CorrectedAreaNote` read as disclosure
rather than as an error.

## AK6 — Migration decision — moot, AK7 shipped instead

Would have blocked any change to the *automated* mask (recompute-on-migration vs.
version-badging vs. ship-nothing). AK7 (disclosure) was the actual outcome — no
automated mask change ever shipped, so there was nothing to migrate. Revisit only if
AK5 (rider-assisted correction, reopened below) ships a stored correction — that's a
different kind of change (additive per-position data, not a retroactive mask swap) and
may not need this decision at all, but check before assuming.

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

## AK10 — Swipe back — ⚠️ IMPLEMENTED, REFUTED ON DEVICE (see AK13)

Approach 1 shipped: `hideNavBar()` (`SharedViews.swift`) now keeps the bar alive
(transparent, `.navigationBarBackButtonHidden(true)`, `.inline` display mode) instead
of hiding it wholesale, restoring `interactivePopGestureRecognizer`. `CaptureView`
excluded as recommended (now calls new `hideNavBarFully()`, unchanged old behavior).
Layout-shift risk didn't materialize — `.inline` with no title/buttons reserves zero
extra space on iOS 26.5/iPhone 17, measured by screenshot diff, no compensation code
needed. Interactive pop gesture itself unverifiable by scripted simulator input (tool
limitation, confirmed against an unrelated existing `DragGesture` too) — on-device pass
outstanding, esp. `PositionDetailView`'s leftmost FRONTAL/SIDE-ON tab per AK11.

## AK11 — Swipe between tabs, consistently — ⚠️ IMPLEMENTED, REFUTED ON DEVICE (see AK14)

Gesture moved onto `SegmentedToggleBar` itself (`SharedViews.swift`, new
`swipeDisabled` param, standing threshold reused verbatim). Both AB11 bespoke gestures
retired (`PositionDetailView.photoSwipeGesture`, `ComparisonView.swipeGesture`); their
zoom guards ported to `swipeDisabled: isPhotoZoomed` / `isOverlayZoomed`. TIME IMPACT
presets excluded via `swipeDisabled: true`. **Correction to this plan:**
`LeaderboardView.FilterBar` was never built on `SegmentedToggleBar` — it was rebuilt
onto the shared component (index-mapped over `BikeType?`) rather than left swipe-less;
~4pt height increase (36→40), visually negligible. `CaptureView`'s reveal-step bar and
`PositionListView`'s sort bar gained swipe for free, no prior zoom guard to preserve.
AK10 coexistence is reasoned (edge-pan recognizer zone wins by construction), not
on-device verified — same outstanding pass as AK10.

## AK12 — Horizontal overflow on analyse screen — ✅ FIXED (dc87556)

Dimension callout boxes could land outside the image with no `.clipped()` on
`PositionDetailView`'s photo container, widening the scroll content. `DiffTable`/
`DiffRow`'s fixed column widths (76/76/70) on Compare were flagged as a possible next
overflow source at large Dynamic Type — checked and closed, see AK15.

---

# Part 4 — On-device gesture pass (Kah, 2026-07-31)

Part 3 shipped against a simulator that **cannot exercise either gesture** (scripted
touch injection doesn't trigger SwiftUI drags or the system edge pop — established in
AK10, re-confirmed in AK11). Both features were therefore reasoned, not observed. The
device disagrees on all three counts. **Standing lesson: a gesture change is not done
until a human has swiped it — simulator-green is not evidence here.**

Positive: matte quality reads as improved on device. That's prior committed work
(AG/AE), not this session — Part 1 changed no production mask code. It does not
reopen AK7; disclosure remains the outcome.

## AK13 — Swipe-back doesn't work on the analysis screen — ✅ CLOSED, superseded by AK18 (cafa71a)

Symptom: can't swipe back from a position analysis screen; AK10 did not actually
restore the gesture (`.navigationBarBackButtonHidden(true)` disables
`interactivePopGestureRecognizer` by construction). The `PopGestureReenabler`/
`AlwaysAllowPopGestureDelegate` approach built here was fully deleted — see AK17 (dead
end, delegate never consulted) and AK18 (replaced with a native `DragGesture`, shipped).

## AK14 — Tab swipe doesn't work; direction reads backwards — ✅ CLOSED, device-verified (cafa71a)

Symptom: tab swiping doesn't work; on the positions list it "works backwards." Cause:
AK11 put the gesture on `SegmentedToggleBar` itself — a ~40pt strip nobody swipes.
Fix, shipped: gesture moved to a `View.segmentedSwipe(selection:count:disabled:)`
modifier applied to **content** (`PositionDetailView`'s PHOTO/MASK/BONES photo,
`ComparisonView`'s `GhostCompareOverlay`) — not the bar. `PositionListView`,
`LeaderboardView.FilterBar`, `CaptureView`'s reveal bar, and TIME IMPACT presets stay
tap-only by design (no adjacent content for a swipe to point at). See AK19 for the
zoom-state bug found alongside this.

Direction — **settled 2026-07-31, do not flip the sign.** Kah read the positions-list
swipe as backwards because the gesture was on the *bar*: touching a control invokes
direct manipulation (selection follows the finger, swipe-left → left), while touching
content invokes paging (content follows the finger, swipe-left → next). Moving the
gesture to content per the fix above makes swipe-left → next correct; inverting it
would break the detail/compare photo tabs where AB11's convention already worked.

Scope — **swipe only where tabs page spatially adjacent content.** Applies to
`PositionDetailView` (photo) and `ComparisonView` (overlay). Does NOT apply to
`PositionListView`'s NEWEST/SMALLEST or `LeaderboardView`'s filter bar: those re-sort
and re-filter a list in place, so there is no adjacent item for a direction to point
at, and a 2-option bar dead-ends on half its swipes. Same principle that already
excludes TIME IMPACT — a swipe changing *what data is shown* is not a swipe changing
*which view you're on*. This reverses AK11's "every tab strip gains it at once"
ambition: the gesture's correctness depends on what the bar controls, not on the
component it's built from. Tap remains the only route on sort/filter, which also suits
the standing preference for explicit controls over hidden ones.

## AK15–AK19 — the gesture/overflow trail — ✅ ALL CLOSED (device-verified 2026-08-06)

- **AK15 horizontal overflow / AK16 side-on aspect-ratio leak** — closed: the symptom
  was AK19's stale pan offset, not `ScrollView` content width. `DiffTable`'s fixed
  76/76/70 columns are layout-safe (probed at default and AX5, dc87556); a real 16:9
  JPEG in `sideOnPhotoData` held content width at exactly 402pt in every state.
  Shipped from the investigation regardless: `.lineLimit` + `.minimumScaleFactor` on
  `DiffTable`/`DiffRow` so AX5 values stay on one line.
- **AK17 — dead end, don't repeat.** Three delegate-timing variants on
  `interactivePopGestureRecognizer` (edge-origin check, `viewWillAppear`, repeated
  reassertion) all failed; `[AK17]` device logging showed **zero** lines — our delegate
  is never consulted on this iOS/SwiftUI version. Never fight that recognizer's
  delegate again.
- **AK18 swipe-back / AK19 stale `pinchZoomable` state — resolved, cafa71a.**
  SwiftUI-native `.highPriorityGesture(DragGesture(minimumDistance: 24))` on
  `HideNavBarKeepingSwipe`, gated on `startLocation.x <= 24` + rightward + the standing
  dominance threshold, calling `dismiss()`; `PopGestureReenabler`/
  `AlwaysAllowPopGestureDelegate` deleted. Zoom/pan state now keyed on
  `persistentModelID` in both `PositionDetailView` and `ComparisonView`. The feared
  edge-band fight with AK14's `.segmentedSwipe` did not materialise on device.

Spec-completion follow-on work lives in [`plan-al-spec-completion.md`](plan-al-spec-completion.md).

---

## Verification

- Full suite green (331 baseline as of 2026-07-31).
- Part 1: every candidate scored against AK1, false-positive count reported.
- matte-lab on Apple Silicon or device only (see `CLAUDE.md` traps).
- **Gestures: human on-device swipe only.** Scripted simulator input triggers neither
  SwiftUI drags nor the system edge pop, so it cannot falsify a gesture change — a
  green suite says nothing about whether the swipe works (Part 4 is what that cost).

## Non-goals

- No re-test of AJ candidate E; no tuning `connectedInstances`/`riderInstance`/`margin`.
- No reintroducing the two-tone matte (Plan AG).
- No new dependencies without asking.
