# Plan AP: field feedback (fold, scroll, slider, capture HUD) + icon

Feedback from testers, 2026-10-17. Kah's answers 2026-10-17: AP1 = saved position screen; AP3 = "sometimes you can't scroll, depending on where the scroll starts"; haptics yes; two pill states only (ready ✓ / not ready ✗); small plate for HUD text.

**Status: AP1–AP5 implemented 2026-10-17, uncommitted, 389 tests green, reviewer pass done. All of it needs the device pass below** (see `gesture_verification_needs_device` memory).

## AP1 · Saved-position photo pushes content below the fold

Done. `PositionDetailView` photo capped at 40% of screen height (same as the `CaptureView` reveal), `bg1` letterbox, height read with `onGeometryChange`.
**Device:** tall portrait + landscape photo: hero number shows with no scroll; zoom, swipe and bones stay aligned; no uncapped flash on first frame. Check `ComparisonView`'s overlay photo for the same overflow; cap it only if it overflows.

## AP2 · Speed slider drag · AP3 · Methodology scroll

Done. Cause: `hideNavBar()` put a screen-wide `.highPriorityGesture` on every screen. It cancelled every child drag at 24 pt (the slider, the AK20 brush) and fought ScrollView pans. Now `.simultaneousGesture` with the same edge test and threshold. Edge band narrowed from 24 pt to `screenMargin − 1` (15 pt), so a slider drag at its minimum cannot also go back. `MaskCorrectionEditor` keeps `edgeSwipeBack: false`: with a simultaneous gesture, an edge brush stroke would dismiss the cover and lose the edits.
**Device:** slider drags 10–60 in one stroke on detail and compare. Methodology scrolls from any start point. Left-edge swipe still goes back on HowItWorks, detail and compare. Mid-screen horizontal drag does not go back.
**Fallback if the edge swipe dies on scrolling screens:** a 15 pt clear strip `.overlay(alignment: .topLeading)`, padded below the `NavHeader` so it does not cover the back button.

## AP4 · Capture readiness is colour only

Done. `StatusPill` dot → `checkmark` (ready) / `xmark` (not ready), same colours. `.success` haptic on the shutter when every check is ready and stays ready for 300 ms (level and tilt flicker while framing; without the hold the phone buzzes on each flicker).
**Device:** the pills read with no colour; one buzz each time the shot becomes ready, no buzzing while you line it up.

## AP5 · HUD text hard to read on bright backgrounds

Done. New `hudPlate()` (`bg0 @ 0.72` chip, same as `StatusPill`/`BikeChip`) on the four free labels: TIPS, blocked reason, skip, library link. Not on `hudText()` itself: the level gauge and the chips that already have a plate must not get a second one. Blend mode rejected: `difference` gives grey on grey over mid tones and changes the acid/amber state colours.
**Device:** white wall, mid-grey wall, bright sky: every label is readable.

## AP6 · App icon

Open. Plan AO Part 1 owns this. All four lanes (a–d) have `final-{1,2,3}.svg`. **Needs Kah:** pick a finalist on the canvas, or name what to change. Then do AO's finalist-proof list 1–9.
