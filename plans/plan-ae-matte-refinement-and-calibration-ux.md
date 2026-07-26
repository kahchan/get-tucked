# Plan AE — Matte refinement (bike wins overlaps) & calibration UX

**Status:** IN PROGRESS 2026-07-26 (sequential Sonnet coders).
**AE1 outcome: NO production change — refuted by harness evidence.** Edge-preserving
upsample (CIEdgePreserveUpsampleFilter, photo-guided) changes bike-share by ≤0.1%; only
an anti-aliasing fringe differs from bilinear. Root cause is upstream of any resample:
the half-res person model reads the fork/head-tube gap at **confidence 255, identical to
true torso** — the detail was never in the source. "Bike wins the overlap" therefore
needs AD5b (person seg on a tight subject crop) or acceptance — STOP-AND-DISCUSS with
Kah before any further attempt. Evidence: tools/matte-lab/output/*/ae1/.
**AE2 outcome: APPLIED — subject threshold 0.5 → 0.4 (byte 102).** Lowest threshold
passing the <2%-everywhere gate (area +1.09–1.29% across fixtures), recovers tire tread,
zero visible background bleed (edge-crop verified). Constant + sweep table live in
AnalysisMath.subjectMaskThreshold; count and render paths share it; Z4 coverage row
untouched. 277 tests green after AE1/AE2.
AE3/AE4/AE5 in flight with a second coder.
**Trigger:** first on-device pass with the working two-tone matte (2026-07-26, Paul
Tall 7240 / Paul Tucked 6178 cm²). Four observations, all Kah-confirmed:
bike should win the rider-overlap pixels ("amber on top") and the subject threshold
needs work (missed fork lowers); Compare's OUTLINE tab should optionally underlay both
photos; the calibration loupe ignores the current pinch zoom; slow placements get lost.

## AE1 — Bike wins the overlap (fork/head tube between legs, bars over torso)

The split is per-pixel exclusive, so "amber on top" means *classification*, not draw
order: pixels where the bike is visibly in front of the rider must stop reading as
person. They currently read acid because the person mask is low-res and soft — bilinear
upsampling smears body confidence across the fork/head-tube gap between the legs, and
AD5a's threshold-200 only helps near edges, not deep inside the bridged blob.

Two levers, both harness-gated on the real fixtures before any production change:

- **AE1a (primary): edge-preserving upsample of the person mask.**
  Replace `MatteRenderer.resizedMask`'s plain bilinear resample (for the two-tone path)
  with `CIEdgePreserveUpsampleFilter` — upsample the low-res person mask *guided by the
  full-res photo*, so the mask snaps to true body boundaries and confidence stops
  bleeding across the white fork. Core Image built-in, no new deps. Validate in
  matte-lab: fork/head-tube pixels should drop below the rider threshold while wrists/
  ankles stay above it.
- **AE1b (fallback/adjunct): person-confidence tiering.** Dump raw person-mask values
  over the fork region in matte-lab. If the bridged gap reads mid-confidence
  (~200–240) while true body reads ~250+, a higher rider threshold *after* AE1a's
  better resample may finish the job. (AD5a already showed 230 overshoots with plain
  bilinear — re-evaluate only on top of AE1a, not alone.)
- Presentation-only: area comes from the subject mask and is untouched by AE1.

## AE2 — Subject-mask threshold (the missed fork lowers)

Parts of the white fork got no tint at all: those pixels sit below the subject-mask
decode threshold (float 0.5 ≈ byte 128). This is a **measurement parameter** — it feeds
`countForegroundPixels`, i.e. the displayed cm² — so it changes only with evidence:
- Sweep the subject threshold {0.2, 0.3, 0.4, 0.5} in matte-lab across all fixtures.
  For each: fork/tyre coverage gained vs background bleed admitted, and the cm² delta.
- Pick the threshold with a comment documenting the sweep; if the choice moves area by
  more than ~1–2%, say so honestly in the plan verdict and keep the uncertainty model
  consistent (spec §3 — no silent measurement drift).
- Keep decode (mask → 8-bit) and count using the same threshold so the matte you see
  is the area you get.

## AE3 — Compare OUTLINE tab: photo underlay

`GhostCompareLayer` already carries `photoImage` with the outline's own alignment
transform — this is view plumbing, not new geometry:
- Add a **PHOTO chip** next to the A/B chips on the OUTLINE tab.
- When on, each layer renders its photo dimmed (~35% opacity, under the outlines),
  and each photo's visibility follows its outline chip: A toggled off → A's photo off
  too (Kah-specified). Both photos may blend when A and B are both on — that's the
  point (aligned in-context comparison).
- PHOTO chip off (default) = today's outlines-only view. R1 draw-in ceremony unchanged.

## AE4 — Loupe magnification compounds with pinch zoom

`CaptureView.loupeCrop` crops a fixed window (`min(w,h) × 0.08`) of the source image
regardless of `zoomScale`, so when the user is pinch-zoomed the loupe can show *less*
magnification than the screen behind it — Kah's screenshot. Fix: divide the crop
window by the current zoom (`windowPx = min(w,h) × 0.08 / zoomScale`) so the loupe is
always a constant magnification *boost over what's on screen*. One function + the
call sites that pass zoom in; unit-test the window math.

## AE5 — Slow placements must not get lost

`placementGesture` cancels the pending point the moment cumulative translation
exceeds `panThreshold` (30 pt) — a careful, slow aim naturally drifts past that and
the point (and loupe) silently vanish; the gesture retroactively becomes a pan.
Redesign placement to be explicit (Kah's stated preference for discoverable controls):
- While placing (`canPlaceMore`), a **single-finger drag aims**: the loupe tracks the
  finger for as long as it's down, any distance, and the point commits on release.
  No translation-based cancel.
- **Panning while placing is two-finger** (it already coexists with the pinch via
  `simultaneously`); once both points are placed, one-finger pan returns as today.
- Update the header hint copy to teach the split ("drag to aim, lift to place —
  two fingers to move around"), and keep the existing point-handle drag for
  fine-tuning committed points.
- Keep `handleTap`'s in-image guard; a release outside the image still cancels.

## Sequencing & verification

- AE1/AE2 first in matte-lab (they share sweep infrastructure), then production +
  tests. AE3/AE4/AE5 are independent view/gesture work, parallelisable.
- Fixtures: the four existing originals cover AE1/AE2; the two new captures (Paul
  Tall / Paul Tucked, taken 16:01) show the exact missed-fork case — AirDrop them into
  `fixtures/` for the sweep if handy (photos stay untracked).
- Full suite green; on-device pass: fork reads amber head-on, no acid bridge between
  the legs, loupe magnifies what's on screen, slow placement commits, compare
  underlay toggles with A/B.

## Out of scope

- AD5b (person seg on subject bbox crop) stays in reserve if AE1a underdelivers.
- Wheel-check fix lives in its own worktree/session (unit-mixing bug, Plan Y memory).
