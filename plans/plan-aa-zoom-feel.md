# Plan AA — Zoom feel: focal-point pinch, double-tap-to-zoom, clean release

Status: planned 2026-07-18, from Kah's on-device pass. The analysis-view zoom
([`Design/PinchZoom.swift`](../ios/GetTucked/Design/PinchZoom.swift)) feels
jarring. Three symptoms confirmed by Kah:

1. Zoom balloons from the frame centre, not from the fingers.
2. Double-tap only ever resets to fit — never zooms in.
3. The settle on release snaps/springs oddly.

**Sequencing: run AFTER Plan Z4 lands.** PinchZoom.swift itself doesn't
collide with Z4's files, but both need the one simulator to test — don't run
concurrently.

## Root causes (verified in code)

- **(1) + (3) are one bug.** The gesture keeps a separate `pinchDelta`
  `@GestureState` multiplier (displayed = `zoomScale * pinchDelta`). At
  gesture end `pinchDelta` resets to 1 *instantly* while `withAnimation`
  animates `zoomScale` from its OLD committed value up to the new one — so at
  release the displayed scale jumps down to the old `zoomScale` then springs
  back up (the "odd snap"). And `scaleEffect` (line 80) uses the default
  `.center` anchor with no focal-point handling, so the pinch never tracks
  the fingers. Both fall out of the multiplier model.
- **(2)** `onTapGesture(count: 2)` (line 151) unconditionally resets to 1×;
  double-tapping while already at fit is a no-op.

## AA1 + AA3 — Continuous-commit, focal-point zoom, no release snap

Refactor `PinchZoomModifier` to write scale/offset **continuously** into
`@State` in `.onChanged` (drop the `pinchDelta`/`panDelta` GestureState
multiplier), capturing per-gesture baselines (`scale0`, `offset0`, focal
point) on the first change of each gesture.

- **Focal point:** `MagnifyGesture.Value.startAnchor` is a `UnitPoint` in the
  view's bounds. Focal offset relative to container centre:
  `f = ((startAnchor.x - 0.5) * containerW, (startAnchor.y - 0.5) * containerH)`,
  captured once at gesture start.
- **Keep-the-point-fixed math (pure, add to `PinchPhysics`, unit-tested):**
  for a scale change `scale0 → s1` about focal `f` with pan baseline
  `offset0`:
  `offset1 = f - (s1 / scale0) * (f - offset0)`
  This holds the content point under the fingers stationary as scale changes.
  Then `clampedOffset(offset1, zoom: s1, …)`.
- **Live rubber-band on scale** past `[1, maxZoom]` stays (existing
  `resistedZoomDelta` shape), applied to `s1` before the offset solve.
- **Release (`onEnded`):**
  - Within legal bounds → **commit instantly, no animation.** The finger
    already placed it there; animating from a baseline is exactly what
    creates the snap. (This is the core AA3 fix.)
  - Overshot a boundary → spring back to the clamped target, seeded with the
    gesture's own velocity (existing `interpolatingSpring`/`normalizedVelocity`
    path), animating from the live overshot value.
- **Curve unchanged:** keep `Theme.Motion.interactive(0.35)` / critically
  damped (bounce 0) for the double-tap and snap-back — on-brand, no bounce.
  AA3 is about *removing* animation from the no-op release path, not
  retuning the spring.

Panning keeps its own continuous-commit + clamp + rubber-band, same as today,
just moved off the GestureState multiplier onto the shared `@State offset`.

## AA2 — Double-tap zooms in at the tap point

Replace the reset-only double tap with `SpatialTapGesture(count: 2)` (gives
the tap location):

- Already zoomed → animate to `scale 1`, `offset .zero` (reset), spring.
- At fit → animate to a target scale (`2.5×`, tunable constant) with offset
  from the AA1 focal formula (`scale0 = 1`, `f` = tap location relative to
  centre), clamped, spring.

## Tests

Add to `PinchZoomTests` (mirrors the existing PinchPhysics tests):
- Focal-offset holds the focal content point fixed across a scale change
  (round-trip: solve offset1, verify the focal point maps to the same screen
  location).
- `scale0 = 1` double-tap case produces an offset that centres the tap point.
- Clamp still bounds the solved offset at the zoom's max travel.

## Order & commits

1. `fix(design): pinch zoom tracks the fingers and commits cleanly on release` (AA1 + AA3 + tests)
2. `feat(design): double-tap zooms in at the tap point` (AA2)

Done means: build + full suite green; pinching on an off-centre spot keeps
that spot under the fingers; releasing doesn't jump; double-tap zooms in to
the tapped point and double-tap again resets. Kah confirms the feel on device.
