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

# Part 5 — AK5 field failures (Kah, on-device 2026-08-10)

First device pass over the shipped correction editor (28c1fd9). Two items: the brush
does nothing, and the editor can't zoom.

## AK20 — The brush never commits a stroke — ⚠️ IMPLEMENTED 2026-08-10, NEEDS DEVICE

Implemented via route 1 below (374 green, uncommitted). **Not closed** — the suite
cannot falsify this and the diagnosis is read off the code, not observed. Keep the
analysis below until a device pass confirms it; if the brush still fails, the cause is
somewhere else and this is the record of what was already ruled out.

Symptom (Kah, on device): TAP works, BRUSH doesn't.

Cause — `hideNavBar()` swallows the stroke before it ends. `HideNavBarKeepingSwipe`
(`ios/GetTucked/Design/SharedViews.swift:103`) applies
`.highPriorityGesture(DragGesture(minimumDistance: 24))` to the **whole screen**, and
its left-edge test (`startLocation.x <= 24`) lives inside `.onEnded` — so the gesture
still *recognises* anywhere on screen, it just declines to act. `MaskCorrectionEditor`
applies `.hideNavBar()` at `MaskCorrectionEditor.swift:113`, over a canvas whose own
`DragGesture(minimumDistance: 0)` is a plain `.gesture`. Once a stroke travels 24pt the
parent's high-priority gesture wins and cancels the child, so the canvas's `.onEnded`
never fires and `commitStroke()` is never called.

That asymmetry is the whole symptom: a tap never travels 24pt, so TAP survives; every
brush stroke longer than 24pt dies. Two consequences follow — `commitStroke`'s
`defer { activePoints = [] }` also never runs, so the killed stroke's points stay in
`activePoints` and bleed into the next stroke as a straight line back to the old
origin.

This is a gesture-layer failure only. The pure half is correct and covered — 422 lines
of `MaskCorrectionTests` pass, including the y-flip convention
(`MaskCorrectionTests.swift:272`) and multi-point stroke rasterisation. Do not go
looking for the bug in `MaskCorrection.swift`.

Fix — as built: `hideNavBar(edgeSwipeBack:)` gates the gesture with
`including: .none`, and `MaskCorrectionEditor` passes `false`. Gated rather than wrapped
in an `if`, because a conditional modifier changes view identity and would reset the
`@State` of everything beneath it. The editor loses nothing — it's a `fullScreenCover`
with its own CANCEL, so the "swipe back" had no back to go to. Same exclusion reasoning
that already sends `CaptureView` to `hideNavBarFully()`.

Every other `hideNavBar()` call site keeps the swipe via the default argument, and none
of them hosts a child drag. **The general rule this establishes:** a screen that hosts a
drag gesture of its own must pass `edgeSwipeBack: false`.

Not done, and deliberately: the edge test was left in `.onEnded`. Moving it into
recognition is the tidier fix but changes behaviour on all seven screens that keep the
swipe, and none of them is broken — device-verified at cafa71a.

Also fixed: a cancelled stroke used to leave its points in `activePoints`, so the next
stroke drew a line back to the dead stroke's origin. `DragGesture` has no cancellation
callback, so a new stroke is identified by a change in `value.startLocation` rather than
by relying on one.

Do not fix this by raising the canvas gesture's `minimumDistance` — that re-breaks the
brush dab, which is exactly what `minimumDistance: 0` is there for.

Verify: **device only** — scripted simulator input triggers neither SwiftUI drags nor
the edge pop (standing trap; this is the same class of bug that cost Part 4). A green
suite proves nothing here. On device: a stroke well clear of the left edge paints and
commits; a stroke starting in the left edge band still leaves the editor; consecutive
strokes don't join up; UNDO drops exactly one.

## AK21 — Zoom while correcting

Symptom (Kah): the correction canvas doesn't zoom, and the edges that need correcting
are exactly the ones too small to hit at fit-to-width. The 0.03-of-long-edge brush is
a fixed size (AK5, deliberately — no size slider), so zoom is the only way to get
precision at an edge.

This reverses AK5's own reasoning at `MaskCorrectionEditor.swift:11-15` ("a freehand
drag can't share a hit region with pinch-zoom and a paging swipe without one of the
three losing"). That held for the *detail screen*, which also carries a paging swipe.
The dedicated editor has no paging swipe, so only two gestures need to coexist, and
the drawing-app convention separates them cleanly: **one finger paints, two fingers
zoom and pan.**

`pinchZoomable` cannot be reused as-is — its pan is a one-finger `DragGesture` applied
via `.highPriorityGesture` (`PinchZoom.swift:119`), which would steal the brush the
moment the canvas is zoomed. Needs a two-finger-only pan: `MagnifyGesture` covers zoom
(inherently two-finger), and pan needs a `UIPanGestureRecognizer` with
`minimumNumberOfTouches = 2` wrapped in a `UIViewRepresentable`. No new dependency.

**The trap worth naming:** painting while zoomed must resolve to the same unit point it
would at 1×. Attach the brush gesture to the *inner, untransformed* content and put
`.scaleEffect`/`.offset` on a parent, so gesture locations arrive already in content
space and `unitPoint(_:)` keeps working unchanged. Mapping screen points back through
the zoom transform by hand is the version of this that ships subtly-offset strokes.

Also: the brush must stay a constant size **on the mask**, not on screen — it already
does, since `MaskCorrection.brushRadiusUnit` is relative to the mask's long edge, but
the `Canvas` preview computes its radius from the on-screen `size`
(`MaskCorrectionEditor.swift:150`) and will need the zoom factor divided out or the
preview disc will disagree with the paint that lands.

Non-goals: no zoom on the TAP tool's behaviour (flood fill is resolution-independent),
no brush-size slider (AK5's call stands), no double-tap-to-zoom unless it falls out
free — a double tap on a painting surface is ambiguous with two dabs.

Verify: **device only**, same reason as AK20. Pinch zooms, two-finger drag pans, one
finger always paints and never pans. A stroke painted at 3× lands where the finger was
— check against a landmark in the photo, not by eye on the overlay alone. Zoom state
survives an UNDO.

## AK22 — TAP's flood fill is unbounded and swallows the frame

Symptom (Kah, on device 2026-08-10, confirming AK20's fix landed): "it swallows
everything."

Cause — `MaskCorrection.flipRegion` flips *every* pixel 4-connected to the tap on the
same side of the threshold, with no bound. On a real matte there are only two outcomes
that matter, and both are catastrophic:

- Tap a gap to **add** something Vision missed (rear wheel, a bag) — all open background
  is one connected region, so the whole frame becomes subject.
- Tap mis-included bleed that **touches** the rider — contiguous with the rider, so the
  whole rider flips out.

TAP therefore only behaves on a genuinely detached blob or a fully enclosed hole. Per
AK1b the common defect is edge bleed, which is connected by definition — so the tool
misfires on its primary use case.

This is not a regression. It is what the code has always done, and the suite asserts it
as correct: `testTapFlipOnBackgroundFillsTheWholeCanvas` pins the whole-canvas result,
and `testTapFlipUsesTopLeftOriginCoordinates` calls the same behaviour "a
catastrophically visible failure" while using it as a y-convention probe. Those tests
change with this fix; the y-convention probe needs a new mechanism.

### Revised after AK21 landed — zoom changes the answer

The pre-zoom proposal was: refuse any fill whose region touches the image border
(structural, no tuned constant). **Superseded.** It stops the catastrophe but leaves TAP
useless on its main job — bleed connected to a rider whose wheels touch the frame edge
gets refused, and the rider is sent to the brush every time.

With zoom in hand there's a better rule, and it fixes the brush too.

**Bound both tools to a radius fixed in *screen* points, not in mask fraction.** Zoom
then becomes the size control for both, and the "swallows everything" failure can't
happen because a fill can never exceed a disc.

Why this is the right shape:

- **It makes zoom a control, not just a viewer.** Zoomed out, a tap flips a chunk;
  zoomed to 8×, the same gesture is surgical — 1/8th the mask distance for the same
  finger travel (`CanvasZoomTests.testZoomShrinksContentDisplacement`).
- **It fixes a brush limitation AK21 did not.** `brushRadiusUnit` is 3% of the mask's
  long edge at every zoom level, so today zoom improves placement but the disc laid down
  is always the same 3%. Screen-space radius is what actually makes an edge paintable.
- **It retires AK5's rejected knob honestly.** "A size slider is a precision knob nothing
  in the app validates" still holds — this replaces the slider with a spatial control the
  rider already has their fingers on.
- **Small blobs still flip whole, for free.** A flood that terminates naturally inside the
  disc has already taken the entire region, so a detached blob smaller than the bound
  behaves exactly as it does today. Only oversized regions degrade, and they degrade to a
  local flip instead of a catastrophe.
- **TAP stays meaningfully different from BRUSH.** The brush lays a hard disc regardless
  of content and spills across an edge; a bounded fill only flips contiguous same-state
  pixels, so it stops dead at the matte boundary. That's precisely the tool edge cleanup
  wants.

Calibrate so nothing changes at 1×: screen radius = `0.03 × content long edge`, which on
a portrait canvas is ~15pt (≈30pt across, a fingertip). Then existing brush behaviour at
1× is bit-identical and only zoomed behaviour is new.

Build:

- `Action.tapFlip` and `Stroke` both carry the radius in unit space, captured at the zoom
  the action was made at, so replay is deterministic. **Not a schema change** — only
  `MaskCorrection.Result` is persisted (the corrected mask, count and area); the action
  list is editor `@State` and dies with the sheet.
- `flipRegion` takes the same radius and stops the flood outside the disc — a bound in
  the existing `connectedRegion` walk, no second pass.
- The `Canvas` preview must derive its radius identically or the acid disc will disagree
  with the paint that lands (`MaskCorrectionEditor.swift:168`).
- Drop the border rule entirely. One bound, not two.

Open question for the device pass: whether a bounded fill leaves visible scalloping when
tapped repeatedly along an edge. The brush has the same round-cap property, so probably
not — but it's an eyeball call, not an argument.

Verify: **this one is testable**, unlike AK20/AK21 — it's pure and the Simulator runs it.
`testTapFlipOnBackgroundFillsTheWholeCanvas` and `testTapFlipUsesTopLeftOriginCoordinates`
both assert the unbounded behaviour and must be rewritten; the latter needs a new
mechanism for probing the y-convention. Add: a tap on open background flips only a disc;
a small detached blob still flips whole; the same tap at two radii flips proportionally.

## Sequencing

AK20 first and separately — done (4e0c081), confirmed on device. AK22 next: it's pure,
testable, and independent of the gesture work. AK21 last, since it's the only one that
needs a device to falsify and it will want the tap behaviour already settled.

Note AK22 and AK21 are not substitutes. Zoom does not fix an unbounded fill, and a
bounded fill doesn't make a 3mm edge reachable at fit-to-width.

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
