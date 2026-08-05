# Plan AK — Bike matte completeness, and accessibility (Dynamic Type + VoiceOver)

**Status:** Part 2 ✅ shipped (82df573). AK12 ✅ fixed (dc87556). Part 1 fully closed —
AK1b/AK2 both run, both consistent with "no automated route beats the current mask";
AK7 disclosure is the outcome. Part 3 (AK10, AK11) failed its first on-device pass
2026-07-31; Part 4 re-implemented swipe-back/tab-swipe (AK13/AK14), found and fixed a
real bug along the way (AK17: pop-gesture delegate had no edge-origin check, caused
mid-screen-drag whole-screen panning on every pushed screen). AK15's original
overflow theory closed as a non-cause; AK16's side-on theory also closed as a
non-cause. **All of Part 3/4 is simulator-verified only — awaiting Kah's on-device
pass**, which is the only thing that can confirm the gestures themselves. Uncommitted
throughout; do not commit until that pass confirms.
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
`PositionDetailView`'s photo container, widening the scroll content. Still worth
checking at AX5: the `DiffTable`/`DiffRow` fixed column widths (76/76/70) on Compare
don't scale — AK8 swept heights only — so that's the next overflow source at large
Dynamic Type.

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

## AK13 — Swipe-back doesn't work on the analysis screen — ✅ IMPLEMENTED (approach 2 added), awaiting device pass

Symptom: can't swipe back from a position analysis screen; the floating `BackButton`
is still the only way out — i.e. AK10 did not actually restore the gesture.

Likely cause, in order: (1) `.navigationBarBackButtonHidden(true)` **itself** disables
`interactivePopGestureRecognizer` — UIKit's default delegate declines the gesture when
there's no back item, so AK10's approach 1 is insufficient *by construction* and the
simulator's inability to test it hid that; (2) on `PositionDetailView` specifically,
the photo's pan/zoom gesture or the horizontal overflow in AK15 swallows the edge pan.

Fix: keep approach 1's transparent bar (its layout result was verified good and is
worth retaining), and add the piece it was missing — the plan's original **approach 2**,
walking to the `UINavigationController` and setting
`interactivePopGestureRecognizer.delegate` to a delegate returning `true` (guarded on
`viewControllers.count > 1`). Approach 1 alone was never going to be enough. Keep the
`CaptureView` exclusion (`hideNavBarFully()`) exactly as-is.

Verify: on device, swipe back from position analysis, leaderboard, bike list, how-it-
works. Confirm `CaptureView` still does NOT pop on edge-swipe (discard confirmation
must remain the only exit).

**Implemented** (`SharedViews.swift`): `hideNavBar()` now backs onto
`PopGestureReenabler`, a zero-sized `UIViewControllerRepresentable` that reaches the
hosting `UINavigationController` and swaps `interactivePopGestureRecognizer.delegate`
for a dedicated `AlwaysAllowPopGestureDelegate` (`gestureRecognizerShouldBegin` →
`viewControllers.count > 1`) — a plain `NSObject`, not the view controller itself, so
the pop's slide transition isn't broken. `hideNavBarFully()`/`CaptureView` confirmed
untouched. Build + 331 tests green; the pop gesture itself is unverifiable in
simulator — **needs Kah's device pass.**

## AK14 — Tab swipe doesn't work; direction reads backwards — ✅ IMPLEMENTED, awaiting device pass

Symptom: tab swiping doesn't work; on the positions list it "works backwards."

Cause: AK11 put the gesture on `SegmentedToggleBar` itself — a ~40pt strip nobody
swipes. AB11 attached its two gestures to *content* deliberately; AK11 read that as
duplication to retire and moved the gesture somewhere architecturally tidy but
interactively dead. The component is still the right place to *define* it; the bar is
the wrong place to *receive* it.

Fix: keep the single definition on `SegmentedToggleBar`, but expose it as a modifier
(e.g. `.segmentedSwipe(selection:count:disabled:)`) that screens apply to their
**content** area — restoring AB11's hit region without restoring AB11's duplication.
Remove `.simultaneousGesture` from the bar itself. Apply to `PositionDetailView`
(photo) and `ComparisonView` (overlay) only — see Scope below. Keep the standing
threshold and the `swipeDisabled` zoom guards unchanged.

Keep AK11's `LeaderboardView.FilterBar` rebuild onto `SegmentedToggleBar` — that
removed a hand-rolled lookalike and is worth having regardless; it just won't carry a
swipe. Watch its ~4pt height change (36→40) on the same device pass.

**Implemented**: gesture logic moved out of `SegmentedToggleBar` entirely (it now
carries zero gesture code, tap-only) into a new `View.segmentedSwipe(selection:count:
disabled:)` modifier, same unchanged threshold. Applied to exactly two content sites —
`PositionDetailView`'s photo (the PHOTO/MASK/BONES cycle specifically, matching AB11's
precedent — not the FRONTAL/SIDE-ON toggle, which AB11 never swiped either) and
`ComparisonView`'s `GhostCompareOverlay` (PHOTO/OUTLINE) — each preserving its
pre-existing zoom guard (`isPhotoZoomed`/`isOverlayZoomed`). `PositionListView`,
`LeaderboardView.FilterBar`, `CaptureView`'s reveal bar, and TIME IMPACT presets are
tap-only, as scoped. Build + 331 tests green; direction/feel unverifiable in
simulator — **needs Kah's device pass** (confirm the swipe registers, reads
correct-direction, and that the narrowed scope feels right in practice).

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

## AK15 — Horizontal overflow: DiffTable ruled out, symptom unreproduced (open)

`DiffTable`'s fixed 76/76/70 columns are **not** the overflow source — dc87556 (AK12)
already tested and closed this; reconfirmed 2026-07-31 with fresh `GeometryReader`
width probes at default and AX5. Mechanism is layout-safe by construction: the
flexible `METRIC` label + `Spacer` absorb any squeeze, fixed columns just wrap their
own text (3 lines at AX5) rather than push the row wider. Shipped anyway: `.lineLimit`
+ `.minimumScaleFactor` on `DiffTable`/`DiffRow` so AX5 values render on one line
(`ComparisonView.swift`) — a real legibility fix, unrelated to the overflow theory.

**The actual pan/rubber-band symptom Kah saw is still unreproduced and still open.**
Couldn't be triggered in the simulator with synthetic/seeded data — needs a real
on-device capture (actual photo, actual computed metrics); Simulator Vision is nil
(standing trap) so this is a hard wall, same one dc87556 hit. Next places to look,
not yet tried: an actual photo's `aspectRatio`-driven frame, or `pinchZoomable`'s pan-
offset clamping under a real zoomed state — not the metrics table.

Verify: needs Kah to locate which screen it is on-device (a debug width-probe overlay,
temporary, is the fastest way — see the removed instrumentation in this session's
diff for the pattern) before a fix can be scoped.

## AK16 — Side-on-only whole-screen horizontal pan — ❌ HYPOTHESIS DISPROVEN, see AK17

New symptom, found after Part 4 landed: on positions with a side-on photo (not
frontal-only), the whole screen — photo AND metrics text together — pans horizontally
and rubber-bands back. Not zoomed on load; only happens on drag. "Everything moves
together" rules out `pinchZoomable` (photo-only) and `DimensionOverlay`'s `.position()`
escape (layout-neutral to siblings, per dc87556) — this is the signature of
`ScrollView`'s real content genuinely exceeding screen width, not a gesture or
rendering artifact.

Suspected mechanism: `PositionDetailView.swift:145-146`, the photo container is sized
`.aspectRatio(showingSideOn ? sideOnAspectRatio : headOnAspectRatio, contentMode: .fit)`
**then** `.frame(maxWidth: .infinity)`. That ordering doesn't reliably clamp the
container's ideal width to the screen when the aspect ratio pushes wide — it can leak
upward into the whole `ScrollView` content's measured width. Side-on shots are often
captured landscape (wide ratio) where frontal is always portrait, so this is
plausibly side-on-exclusive by the ratio itself, not by any side-on-specific view.

**Explains a blind spot in AK15's investigation**: that session's synthetic seed data
had no real photo bytes in `sideOnPhotoData`, so `sideOnAspectRatio` fell back to the
same `4.0/3.0` as frontal — never exercising a genuinely wide ratio, hence no overflow
found.

**Disproven 2026-07-31**: measured directly, not just reviewed. A real 16:9 JPEG
seeded into `sideOnPhotoData` (genuine EXIF dimensions, not the `4/3` fallback),
built and run live in-simulator, `ScrollView` content width stayed exactly 402pt
(screen width) in every state — frontal, side-on, before/after toggle. The
`.aspectRatio`→`.frame(maxWidth: .infinity)` ordering does not leak width upward in
practice. Strike the mechanism; the symptom is real but this wasn't it — see AK17.

## AK17 — Pop-gesture delegate has no edge-origin check — ❌ DEAD END, see AK18

Edge-check fix (below) did not resolve it on a fresh device build. Kah confirmed:
root screen (Positions list) unaffected, only pushed screens still pan/rubber-band
from a mid-screen drag — same signature as before, still narrows to the pop gesture,
not a new mechanism.

Original fix (insufficient alone): `AlwaysAllowPopGestureDelegate
.gestureRecognizerShouldBegin` approved any touch whenever `viewControllers.count > 1`
with no origin check. Added a leading-edge check (`location(in: view).x <= 20`pt).
Root-cause-fine in isolation, but didn't fix the symptom.

**New hypothesis — delegate assignment lost to a race, not a logic bug.**
`PopGestureReenablerController` only assigns the delegate once, in
`viewWillAppear` (`SharedViews.swift`). This is a documented SwiftUI
`NavigationStack` gotcha: `NavigationStack` manages
`interactivePopGestureRecognizer` with its own internal coordinator and can reset
the delegate back to its own on a later render pass, silently clobbering a one-shot
`viewWillAppear` assignment. AK14/AK17's edge-check logic may be entirely correct
and simply never running because something else's delegate is answering instead.

Fix: re-assert the delegate repeatedly (cheap operation) rather than once —
`viewDidLayoutSubviews` fires on every layout pass, which should win any race with
SwiftUI's own reset. Verify: on device, mid-screen drag on a pushed screen no longer
pans; left-edge swipe still pops; root screen still unaffected (already confirmed
fine). If this still doesn't hold, the next escalation is abandoning
`interactivePopGestureRecognizer` entirely for approach 3 (a SwiftUI-native
edge-gated `DragGesture` calling `@Environment(\.dismiss)`), which doesn't depend on
this private recognizer at all — noted here so it isn't rediscovered from scratch.

**Reassertion fix also failed 2026-08-05.** Kah ran from Xcode with a device
attached, watched the console with the `[AK17]` debug logging in place, dragged
mid-screen: **zero log lines**, ever. Decisive, not ambiguous — our delegate is
never consulted at all, from any of the three reassertion points. This isn't a
race we're losing sometimes; something else entirely owns this gesture on this
iOS/SwiftUI version. Fighting `interactivePopGestureRecognizer`'s delegate is a
dead end — **abandon approach 2 entirely, do not attempt a fourth delegate-timing
variant.**

## AK18 — Swipe-back as a SwiftUI-native gesture (approach 3) — ✅ IMPLEMENTED, awaiting device pass

Replace the whole `PopGestureReenabler`/`AlwaysAllowPopGestureDelegate` mechanism
(delete it, including the AK17 debug logging — proven non-functional, don't leave
it as dead code) with a plain SwiftUI `DragGesture` that manually pops via
`@Environment(\.dismiss)`. Doesn't touch any private UIKit recognizer, so there's
nothing to race or lose.

Shape: attach at the `HideNavBarKeepingSwipe` wrapping level (where `hideNavBar()`
already applies to every pushed screen except `CaptureView`, which uses
`hideNavBarFully()` and is unaffected by construction). Gate strictly on touch
origin — reject anything starting more than ~24pt from the left edge — and on
direction: only a rightward drag (translation.width positive, standard "swipe
right = back" convention) past the standing dominance threshold
(`abs(h) > 50 && abs(h) > abs(v) * 1.5`, reused not reinvented) calls `dismiss()`
on release. Use `.highPriorityGesture` at this outer level so an edge-originated
drag always resolves to back-navigation ahead of any content-level gesture
(reconcile explicitly with AK14's `.segmentedSwipe` on `PositionDetailView`'s
photo / `ComparisonView`'s overlay — non-edge drags on those still resolve to tab
swipe as before; only the narrow edge band is claimed for back-navigation, same
as the system's own edge-pop zone would claim it).

No live drag-follow visual required — a discrete pop-on-release trade-off is
acceptable given how much has already been burned trying to get the native
slide-with-finger feel working reliably. Correctness over polish this round.

Verify: on device, left-edge rightward swipe pops back on every screen except
`CaptureView` (confirm it still doesn't); mid-screen and non-edge drags do
nothing; `PositionDetailView`/`ComparisonView` tab-swipe still works on non-edge
touches. This is still a gesture-behavior change unverifiable by scripted
simulator input — Kah's device pass required.

**Implemented 2026-08-05 (uncommitted)**: `PopGestureReenabler`/
`AlwaysAllowPopGestureDelegate` fully deleted, no dangling references. Replaced
with `.highPriorityGesture(DragGesture(minimumDistance: 24))` on
`HideNavBarKeepingSwipe`, gated on `startLocation.x <= 24`, `horizontal > 0`, and
the standing dominance threshold, calling `@Environment(\.dismiss)` only when all
three hold. `CaptureView` confirmed structurally untouched (routes through
`hideNavBarFully()`, never this gesture). 331 tests green, build clean.

**One real residual risk, unverifiable except on-device**: `.highPriorityGesture`
wins arbitration against *any* qualifying drag in the same view chain, then
internally no-ops for non-edge/wrong-direction ones — it does not pre-filter by
edge before claiming priority. Whether this creates any double-response or
visible fight against AK14's `.segmentedSwipe` (a sibling gesture on nested
content, not a child, so SwiftUI's cross-boundary arbitration here is genuinely
undocumented) is the one thing code review couldn't settle. Specifically test: a
swipe starting *inside* the left 24pt band on `PositionDetailView`/
`ComparisonView` — does it cleanly pop back, or does the tab also cycle?

## AK19 — Stale pinchZoomable state leaks across positions — ✅ IMPLEMENTED, awaiting device pass

**Revised diagnosis 2026-08-05, from an on-device screenshot** — not the
whole-screen `ScrollView` overflow AK15/16 chased. In the screenshot, `NavHeader`
(title, back arrow) and the PHOTO/MASK tab bar are all in their normal position;
only the photo itself is shifted hard right with a black gap on the left. That's
`pinchZoomable`'s own `panOffset`, active on a photo that isn't visibly zoomed.
Confirmed general, not side-on-specific: Kah reproduces it "even on positions
without the sideon" — so AK16's aspect-ratio theory and AK15's `DiffTable`
theory are both correctly closed; this was always a different bug.

Root cause: `PositionDetailView.swift:150`, `.id(showingSideOn)` resets
`pinchZoomable`'s internal zoom/pan `@State` on the FRONTAL/SIDE-ON toggle only —
**it does not key on which Position is being viewed.** If SwiftUI ever reuses
that state across a navigation to a different saved position, a leftover
`zoomScale` just above `1.01` (imperceptible as "zoom" but enough to pass the
`isZoomed` gate in `PinchZoom.swift`) silently unlocks the pan gesture; rubber-band
resistance during an active drag then swings the image far to one side even
though the "legal" clamp for a barely-zoomed state is nearly zero — matching the
screenshot exactly.

**Correction, found while implementing**: `ComparisonView`'s `GhostCompareOverlay`
does NOT use the same `.id()` pattern — it had no `.id()` at all, by explicit
design (PHOTO/OUTLINE and A/B toggles must never reset zoom, since physical-cm
placement keeps content at the same screen position across those toggles). More
exposed than `PositionDetailView`, not equally exposed.

**Implemented 2026-08-05**: `PositionDetailView.swift:150` now
`.id("\(position.persistentModelID)-\(showingSideOn)")`. `ComparisonView`'s
`GhostCompareOverlay(...)` call site now carries
`.id("\(positionA.persistentModelID)-\(positionB.persistentModelID)")`, added
fresh (there was nothing there before) — preserves the intentional
no-reset-on-toggle behavior while giving a genuinely different position pairing
fresh state. 331 tests green, build clean.

**Root path not confirmed.** Both `PositionDetailWrapper`/`ComparisonWrapper`
are keyed by position identity inside a `Hashable` `AppScreen` path element,
which should normally give `navigationDestination(for:)` fresh view identity per
distinct position — no concrete SwiftUI state-reuse mechanism was found or
reproduced by code review alone. The fix closes the gap regardless (defensive,
not dependent on nailing the exact trigger) but if the symptom recurs after this
lands, the mechanism is still an open question, not confirmed-and-fixed.

Verify: on device — zoom slightly on one position's photo, back out, open a
different position, confirm its photo isn't offset. Same for comparison: zoom on
one pairing, back out, open a different pairing.

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
