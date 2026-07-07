# Plan F — Capture precision, person robustness & nav polish

Status: **not started**. Written 2026-07-07 from a round of on-device testing
with real photos (a rider in a cluttered room; a bare wheel for scale). Three
independent findings plus two chrome nits found in the same screens.

**Design authority:** the unpacked prototype in `inspiration/unpacked/`
(`template.html` + `b554d774.js`). **Behaviour authority:**
`plans/get-tucked-code-spec.html`. Same verify loop as Plans A–E
(`xcodebuild test`, iPhone 17 simulator; UI checks via `simctl io screenshot`
since this environment has no tap-simulation tool). One commit per task,
Conventional Commits.

**Suggested order by severity** (not the order they were raised): **F3 first**
— it's a hard blocker (a valid single-rider photo can't be analysed at all),
then **F2** (calibration accuracy — the whole measurement rides on it), then
**F1 / F4** (polish). F1's exact pixel values are a taste call and want
on-device iteration.

---

## F1. Header ergonomics — un-squish the back arrow, bigger nav icons

**Decision already made (2026-07-07):** back arrow stays **beside** the title
(not stacked above it, though the prototype stacks — Kah chose beside), just
**spaced** so it no longer collides, and hugging the screen edge.

**Root cause of the squish.** The back arrow is a 44pt tap frame at 24pt inset
with the `←` glyph *centered* in it → the glyph floats at ~46pt from the edge.
The title starts at `chromeReserve` = 52pt. Glyph right edge (~53pt) and title
left edge (52pt) collide by ~1pt. The arrow reads as anchored to neither the
edge nor clear of the title — it's in no-man's-land.
(`AppNavigation.swift` `BackButton` + `SharedViews.swift` `NavHeader`.)

- File: `ios/GetTucked/Design/AppNavigation.swift` (`BackButton`)
  - **Left-align the glyph** within the 44pt tap target (keep the 44pt target
    for accessibility) so it sits at a clean ~20pt edge margin instead of
    floating at the frame centre. Bump the glyph **18 → 24pt**. Dim
    `fg` → `fg2` (prototype `.back-btn-ico` uses `--fg3`; `fg2` reads better
    on our darker canvas — pick on device).
- File: `ios/GetTucked/Design/SharedViews.swift` (`NavHeader`) + `Theme.swift`
  - Widen the title's leading reserve so there's a real gap after the arrow
    (arrow occupies ~16–44pt; title should start ~56–60pt). Rename/repoint
    `chromeReserve` accordingly, or add a `headerTitleInset` token.
  - **Sub-decision (flag, decide on device):** root screens with no back arrow
    (only POSITIONS) currently inherit the same indent, so their title is
    pushed in for an arrow that isn't there and no longer lines up with the
    body content at 24pt. Recommendation: **root titles at 24pt, pushed-screen
    titles at the ~56pt reserve** — titles align with the content below them;
    accept that the title's left edge differs between root and pushed screens
    (it tracks whether there's an arrow, which is honest). The alternative
    (uniform indent everywhere) keeps one title baseline but wastes space on
    root. This needs `NavHeader` to know whether a back arrow is present —
    pass a `hasBack` flag from the two call sites that are pushed, or drive it
    off the same `path` condition the overlay uses.
- File: `ios/GetTucked/Views/PositionListView.swift` (bespoke two-row header)
  - Apply the same left margin rule (root → 24pt). Bump the gear **18 → 22**
    and `+` **20 → 22**, keep 44pt targets. Re-check the title-row fit after
    the bump (E3 already showed this row is width-tight).
- File: `ios/GetTucked/Views/BikeListView.swift`
  - Drop the stale `.padding(.trailing, chromeReserve)` on its `+` (left over
    from the removed hamburger).
- Add ~a token of top breathing room above headers (prototype has ~30px below
  the status bar; ours is tight) — verify it doesn't clip on notch/Dynamic
  Island devices.

**Acceptance:** on a pushed screen the arrow hugs the edge with a clear gap
before the title (no overlap); nav icons are visibly larger; POSITIONS' title
lines up with its body content; nothing crowds or wraps. Screenshot both a
pushed screen and POSITIONS.

**Commit:** `fix(nav): space the back arrow off the title, enlarge nav icons (Plan F1)`

## F2. Capture-screen chrome — kill the system nav bar, fix title casing

Found while testing F3. Two nits on every `CaptureView` step:

- **A stray system back button.** `CaptureView` never calls `.hideNavBar()`,
  so the system navigation bar shows through — on iOS 26 that's the translucent
  circular chevron top-left in the calibrate screenshot. The capture flow owns
  its own `✕` dismiss and must show no system chrome (mid-flow back would also
  silently discard the capture). Add `.hideNavBar()` to `CaptureView`'s root.
- **Mixed-case step titles.** `stepTitle` returns `"Calibrate scale"`,
  `"Analysing"`, `"Result"`, `"Name position"`, `"Done"` — the rest of the app
  is UPPERCASE (`"FRONTAL · 1 OF 2"`, `"POSITIONS"`). Uppercase them (or
  uppercase in `NavHeader`, but that risks fighting intentional casing
  elsewhere — safer to fix the strings here).

- File: `ios/GetTucked/Capture/CaptureView.swift` — `.hideNavBar()` on the
  root `ZStack`; uppercase the `stepTitle` cases.

**Acceptance:** no system back button anywhere in the capture flow; every step
title is uppercase and consistent with the app.

**Commit:** `fix(capture): hide system nav bar, uppercase step titles (Plan F2)`

## F3. Calibration precision — pinch-to-zoom + draggable points with a loupe

The scale calibration is the ruler for **every** measurement — sub-pixel error
on the two handlebar-end points propagates into every cm² number. The current
interaction makes precise placement hard.

**Current** (`HandlebarCalibrationStep`, `CaptureView.swift:483`): tap places
the first two points; a third tap moves whichever existing point is nearest.
A static 2.5× crop preview appears *below* the image after a tap (`zoomPreview`,
`:599`). No drag, no pinch. You can't see under your fingertip while placing,
and you can't zoom into a thin bar end.

- File: `ios/GetTucked/Capture/CaptureView.swift` (`HandlebarCalibrationStep`)
  - **Draggable handles.** Attach a `DragGesture` to each point handle so you
    drag it directly instead of tap-to-snap-nearest. While dragging, show a
    **loupe** (magnifier bubble) offset *above* the finger (so the fingertip
    doesn't occlude it) — a zoomed crop centred on the live point with a
    crosshair. Reuse the existing `zoomPreview`/`crosshair` render; move it
    from a static bottom strip to a floating overlay that tracks the drag.
    Commit the point on drag end.
  - **Pinch-to-zoom + pan** on the image. Wrap the image + overlay in a
    zoomable container (`MagnificationGesture` + a pan `DragGesture`, or a
    zoomable `ScrollView`). Points are already stored in **unit image-space
    (0–1)**, which is zoom-invariant — so they track the zoom for free; the
    work is mapping gesture locations back through the current
    scale/offset transform into unit space.
  - **Watch the transform composition.** The existing `aspectFitRect` math
    (letterbox-aware tap mapping) now has to compose with the pinch scale and
    pan offset. This is the fiddly part — get the unit-space round-trip right
    (screen → container → asp-fit rect → unit, and back) and verify a point
    stays glued to the same pixel across zoom in/out. Expect on-device
    iteration; add a small pure helper for the coordinate transform so it can
    be unit-tested rather than eyeballed.
  - Keep the initial tap-to-place-two-points flow; dragging is for refinement.
  - Consider a "reset points" affordance once zoomed/panned around.

- Optional test: extract the screen↔unit transform into a pure function in
  `AnalysisMath` (or a sibling) and add round-trip tests (place at unit (u,v),
  apply an arbitrary zoom+pan, map the resulting screen point back → (u,v)).

**Acceptance:** you can pinch to zoom into a handlebar end and drag either
point with a loupe showing exactly where it lands; a placed point stays glued
to its pixel through zoom/pan; the resulting scale is unchanged by zoom level.

**Commit:** `feat(capture): pinch-zoom + draggable calibration points with loupe (Plan F3)`

## F4. Multi-person false positive — select the dominant rider, don't reject

**The blocker.** `validatePerson` (`AnalysisEngine.swift:111`) runs
`VNDetectHumanRectanglesRequest` and **hard-rejects when `observations.count
!= 1`** → `multiplePersonsDetected` ("More than one person detected. Ask
helpers to step aside."). Real rooms defeat this: a coat on the wall reads as
a person, and a **person printed on the rider's shirt** (the Klimt "Kiss" tee;
the W.O.R.D logo figure) gets detected too. A perfectly good solo shot is
refused.

- File: `ios/GetTucked/Analysis/AnalysisEngine.swift` (`validatePerson`)
  - **Select the dominant rectangle** instead of rejecting. Per spec §3 the
    rider fills the frame, so the rider's box dwarfs a coat/poster/shirt-print.
    Sort observations by area (or bbox height), take the largest as the rider,
    run the existing clip/height checks on *that* box.
  - **Only flag genuine multi-person.** Reject with `multiplePersonsDetected`
    *just* when a second box is also large — e.g. ≥ ~60% of the largest box's
    area **and** ≥ 50% frame height — i.e. an actual second human in shot, not
    decor. Tune thresholds against the real test photos.
  - **Filter by confidence** first: drop `observations` below a confidence
    floor before counting (`VNDetectedObjectObservation.confidence`).
  - Regression-guard with the two real test photos (rider + coat + person-print
    shirt) — they must pass; a staged two-real-people photo must still fail.

- **Deeper, optional (ties into Plan A's mask-definition question).** The
  segmentation itself (`VNGeneratePersonSegmentationRequest`, `:141`) merges
  *all* detected people into one mask — so a coat-as-person or a background
  person would also inflate the **frontal area**, not just trip the gate.
  Moving to `VNGeneratePersonInstanceMaskRequest` (iOS 17) and keeping only the
  dominant instance's mask would make the area robust too. `MatteCheckView`
  already uses the sibling `VNGenerateForegroundInstanceMaskRequest` +
  `allInstances` (`MatteCheckView.swift:148`), so the instance-mask pattern is
  in-repo. Flag as a follow-up — larger change, and it overlaps Plan A1's open
  "what does the mask include" verdict; don't fold it in here without that
  decision.

**Acceptance:** the two real single-rider test photos analyse without a
"multiple people" error; a genuine two-person photo still errors; the chosen
rider box is the dominant one; no regression in the clip/height checks.

**Commit:** `fix(analysis): pick the dominant rider instead of rejecting multi-detections (Plan F4)`

---

## Relationship to other plans

- **F1/F2** extend the Plan D/E header + capture-chrome work (they refine
  screens those plans built; no conflict).
- **F4** overlaps **Plan A** (measurement integrity): the shallow gate fix is
  self-contained here, but the deeper instance-mask change is gated on Plan A1's
  mask-definition verdict — keep it as a flagged follow-up, not part of F4.
- **F3** is new capture-UX surface; no dependency, but it touches the same
  `CaptureView` region as F2 — land F2 first (tiny) to avoid churn.

## Flagged decisions for Kah

1. **F1 root-title indent** — root screens (POSITIONS) at 24pt to match body
   content vs. uniformly indented to share a title baseline with pushed
   screens. Recommendation: 24pt on root. Decide on device.
2. **F4 deeper fix** — do we also move segmentation to dominant-instance masks
   (robust area, not just a robust gate)? Recommend deferring until Plan A1's
   "does the mask include the bike?" verdict lands, to avoid reworking it twice.
3. **F3 scope** — is pinch-zoom + drag-with-loupe the right ceiling, or do you
   also want a nudge control (arrow keys / fine-adjust buttons) for the last
   pixel? Recommendation: ship pinch + loupe first, add nudge only if it's
   still fiddly on device.
