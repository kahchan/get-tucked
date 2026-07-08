# Open steps that need Kah, not code

Living checklist — update this doc as items resolve or new ones turn up.
Each entry links to the plan that gates on it. Nothing here blocks on writing
more code; all of it needs Kah's eyes, hands, or tape measure.

## On-device verdicts

- [ ] **J0 — subject-matte feasibility eyeball.** Run MATTE CHECK → SUBJECT
  on real photos: rider on a bike, head-on, cluttered background, with and
  without bags, plus the hard cases (wheels/frame tubes segmenting as
  separate instances, furniture touching the rider's box). Record the
  verdict in `plans/matte-verdict.md`. **Gates:** Plan J (J1–J4, rider+bike+
  bags matte adoption) and Plan A5 (burst uncertainty, explicitly deferred
  pending this). See [`plan-j-subject-matte-adoption.md`](plan-j-subject-matte-adoption.md) §J0.

- [ ] **A6 — 3D vs 2D side-on pose verdict.** Using the `PoseCheckView` DEBUG
  harness (already built), shoot two deliberate stress photos and compare:
  (a) off-perpendicular framing (2D angles are known to foreshorten here),
  (b) bike occlusion of the hips/knees. Record whether 3D beats 2D on
  either, in `plans/matte-verdict.md` or a sibling `pose-3d-verdict.md`. See
  [`plan-a-measurement-integrity.md`](plan-a-measurement-integrity.md) §A6.

- [ ] **Shot A — bar-at-chest ground truth.** Companion to the Shot B result
  already recorded (31cm true vs 21.8cm app-read, joint-to-joint, confirmed
  2026-07-08). Hold the bar against your chest (coplanar with the torso) for
  the same tester, same camera spot. Reading ≈ true ⇒ the ruler (bar width +
  taps) is right and the Shot B gap is pure scale-plane perspective bias.
  A mismatch here would mean something in the tap/entry chain is also off.
  See [`plan-i-matte-on-detail-and-number-trust.md`](plan-i-matte-on-detail-and-number-trust.md),
  "Experiment protocol" section.

- [ ] **Plan G live-capture feel.** Side-on now opens the live camera
  (LEVEL/PERP gating, skip, library fallback) — verified via simulator
  screenshot for HUD layout only, since the simulator has no camera. Needs
  a real capture on-device: does the shutter gate feel right, does LEVEL/
  PERP behave sensibly in practice. See [`plan-g-side-on-live-capture.md`](plan-g-side-on-live-capture.md).

- [ ] **Plan L landscape rotation — L1–L4 landed 2026-07-08, needs the
  device checklist from the plan's Acceptance section:**
  1. Rotate mid-side-on → HUD reflows, preview stays upright (not sideways).
  2. Landscape-level phone → LEVEL green, shutter enabled; captured photo is
     landscape-shaped and right-way-up (if upside-down, swap the
     landscapeLeft/Right `videoRotationAngle` values in `OrientationBucket`).
  3. Skip/capture/✕ while held landscape → app returns to portrait.
  4. Head-on step → still refuses to rotate.
  See [`plan-l-landscape-side-on.md`](plan-l-landscape-side-on.md).

## Decisions waiting on an answer

- [ ] **Matte-bleed threshold.** TEST 1's mask showed some bleed (soft
  edges, a bit of extra coverage around a held object) — expected
  `VNGeneratePersonSegmentationRequest` behaviour on a harder pose, not
  obviously a bug. Options: leave the 128 foreground threshold as-is (the
  ±3% uncertainty band already covers some of this), or tighten it (trades
  bleed for risk of clipping thin real regions like fingers) — Claude can
  show a before/after if wanted. No plan doc yet; raised 2026-07-08.
