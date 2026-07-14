# Plan P — Capture Consistency (align, warn, don't complicate)

Status: **planned** (2026-07-14). No code yet. Derived from
[`plans/torsten-aero-notes.md`](torsten-aero-notes.md) §A — the finding that *position and
kit drift between two shots is the dominant error source* in any photo-based comparison, bigger
than anything in our own pipeline. This plan attacks that, and does it without adding UI weight.

**Scope:** help a rider reproduce a position between two captures, and warn them when they
haven't — so a comparison reflects the *setup* change, not a shoulder that slumped. Three
increments (P1 cheap + certain, P2 the ghost overlay, P4 later/bigger). **P1 and P2 need no
schema change** (they reuse landmarks and mattes Plan O already persists) — a deliberate contrast
with Plan O, and the reason they're safe to ship in a slice.

**Read first:** `CLAUDE.md` (design language + "STOP and ask" rules),
`plans/plan-n-motion-and-experience-polish.md` (motion philosophy — every animation here obeys
it), `plans/plan-o-skeleton-on-matte.md` (the skeleton/matte this builds on). This doc is written
for an implementing agent who has not seen the planning conversation.

---

## The UX principle that governs everything here

**One control changes one thing. Adding a capability must not add a chooser.** The app is a
single linear flow with no tab bar; overlay choices already live in *one* segmented bar. If this
plan ends with the user facing a grid of overlay checkboxes, it has failed regardless of accuracy.

### The overlay taxonomy (decided — do not turn into toggles)

There are exactly **two overlay contexts**, and they must never merge into one control:

| Context | When | Control | Axis |
|---|---|---|---|
| **Inspect** | Reviewing a finished result (RevealStep, PositionDetailView) | the existing `SegmentedToggleBar` | a *detail ladder*: `PHOTO → SILHOUETTE (matte) → SILHOUETTE + POSE (matte+bones)` |
| **Align** | Capturing a *comparison* shot against a reference position | at most one **on/off** affordance | show the reference ghost, or don't |

**The ghost never enters the Inspect control.** It is not a fourth segment next to PHOTO/MASK/
BONES. It is a capture-time aid that exists only while you're shooting the second photo and is
gone the moment you've shot it. This is the single most important decision in the plan: it's what
stops "add an overlay" from becoming "add three overlays and a legend."

### On "combine the matte and bones" (Kah's question)

They're **already combined into one axis** — RevealStep's bar is `PHOTO | MASK | BONES`
(CaptureView.swift ~L529, `revealSegmentLabels`), a single control where each step adds detail,
not three independent switches. So no consolidation work is needed there. The thing to protect is
that ladder staying *one* control. If we ever feel pressure to add a fourth state, that's the
signal we're overloading Inspect with an Align concern — push it to the ghost instead.

**The ghost is itself "combined," by the same logic:** it is *one* reference layer (silhouette
outline + a faint pose, composited together at a single opacity), toggled as a unit. The rider is
never asked "ghost silhouette or ghost bones?" — that's exactly the proliferation we're avoiding.

---

## Current state (what you'll find in the code)

- **Landmarks are already persisted** per position in `PositionMetrics`
  (PositionMetrics.swift:43–52): `headOnSkeletonPoints` (shoulders), `headOnArmPoints`
  (elbows/wrists), `sideOnSkeletonPoints` (shoulder/hip/knee/ear). Vision-normalised, origin
  bottom-left. **P1's pose-delta reads these — no new capture, no new storage.**
- **Angles already computed & stored:** `torsoAngleDeg`, `hipAngleDeg`, `headDropCm`,
  `shoulderWidthCm` (PositionMetrics.swift:28–34).
- **Matte** is stored as untinted grayscale PNG (`Position.maskData`), tinted at display by
  `MatteRenderer.tintedOverlay` (MatteRenderer.swift:30). Side-on matte also exists post-Plan O.
  **P2's ghost reuses this — outline it, don't re-segment.**
- **Skeleton** renders via `SkeletonOverlay` with `.measured` (acc) vs `.context` (fg2) tiers and
  a staggered draw-on (SkeletonOverlay.swift). A `.skeletonReveal(visible:)` helper gives simple
  fade in/out (L233).
- **Inspect controls today:** RevealStep uses a `SegmentedToggleBar` of PHOTO/MASK/BONES
  (CaptureView.swift:580, segments absent when the underlying overlay is missing).
  PositionDetailView has FRONTAL/SIDE-ON plus its own PHOTO/MASK/BONES bar
  (PositionDetailView.swift:68, 130–134).
- **Comparison:** `ComparisonView` compares two positions, computes `isDistinguishable` and
  `noisePct` (ComparisonView.swift:30–37) and renders the verdict.
- **Capture flow:** `CaptureView` step machine includes `.calibrate`, head-on pick, and a side-on
  path (`.pickSideOnPhoto`, `.analysingSideOn`); `LiveCameraView` exists and the side-on path is
  live (Plan L). **Whether head-on is live or photo-pick determines where the ghost can appear —
  see P2 dependency.**

---

## P1 — Same-kit reminder + pose-delta warning (cheap, certain, schema-free)

The highest value-per-effort. Uses only data we already have, blocks nothing, and mirrors the
existing advisory pattern (`AnalysisMath.shoulderWidthWarning` / `wheelCheckDisplay`): compute a
plain fact, surface it quietly, never gate capture. Honesty posture per spec §3 — advisory, not a
fake precision.

### P1.1 — Same-kit / same-position reminder (copy only)

- One line shown when the rider begins a capture that will be compared, or at the moment they pick
  the second position to compare. Content: *"Same kit, same helmet, same bars-position as the shot
  you're comparing — clothing changes your silhouette as much as a small bag does."*
- Placement: the compare entry point (see P1.3) and/or the capture intro. Mono, `fg2`, no icon
  drama. It is a nudge, not a modal.
- No logic. This alone removes a real, common error (a jacket on one shot, off the other) for zero
  engineering risk.

### P1.2 — Pose-delta computation (new pure math, tested)

Add to `AnalysisMath` (keep it pure/testable, no SwiftUI/Vision), consuming two positions'
stored landmarks/angles:

- **Frontal delta:** from `headOnSkeletonPoints` (+ `headOnArmPoints` when both present) — compare
  shoulder-line tilt and, if arms exist, elbow/wrist positions. Report the largest per-joint
  normalised displacement, and/or a shoulder-tilt angle delta.
- **Side-on delta:** compare `torsoAngleDeg`, `hipAngleDeg`, `headDropCm` between the two
  positions directly (these are already the fit-defining angles Torsten calls out — shoulder
  tension, hip angle, head position).
- **Thresholds (advisory, tune on device):** propose a two-tier response —
  - torso/hip angle delta > ~4–5°, or head-drop delta beyond the noise, → "positions differ";
  - a larger delta (say > ~8–10°) → stronger wording.
  These are starting points, **human-gated for on-device tuning** (like every threshold in
  `AnalysisMath`). Do not ship a guessed number as if it were validated.
- **Function shape:** mirror `shoulderWidthWarning` — return an optional struct
  `(text: String, severity: .note | .warn)?`, `nil` when the two positions are close enough that
  the delta is within measurement noise. **Never returns a "positions are good" affirmation** —
  silence is the pass state, consistent with the app's voice.
- **Honesty note in copy:** the warning says *some of this delta is you, not your setup* — it does
  not claim to separate the two, because it can't. It flags a confound; it doesn't correct it.

### P1.3 — Surface in ComparisonView

- When two compared positions exceed the pose-delta threshold, render a quiet advisory line in
  `ComparisonView` (near the verdict), styled like the existing `shoulderWidthWarning` surfacing —
  `amb` for the stronger tier, `fg2` for the note tier, mono, 0px, no banner theatre.
- **Interaction with the noise floor:** this is complementary, not duplicative. The ±3% floor
  answers "is the *area* delta bigger than measurement noise?"; the pose-delta answers "is the
  *position* even the same?" A comparison can clear the area floor yet be untrustworthy because the
  rider moved — that's exactly the case this catches. Word them so they don't contradict.

**P1 deliverable:** a rider comparing two shots gets a plain-language nudge to keep kit/position
constant, and a quiet flag when their two positions visibly differ — with zero new capture tech,
zero schema change, and one new tested pure function.

---

## P2 — Ghost alignment overlay (live reproduction of a reference position)

The direct attack on the dominant error: let the rider *line up* against their previous shot
before pressing the shutter, instead of catching the drift afterward.

### P2.0 — Dependency to resolve first (STOP/confirm)

The ghost is a **live-preview** aid — you align to it in real time, then shoot. It therefore
requires a live camera step for the orientation being captured.
- **Side-on is already live** (Plan L) → ghost works there now.
- **Head-on:** confirm whether it's live or photo-pick today. If photo-pick, the ghost either
  waits until head-on capture is live, or degrades to a *post-shot* alignment check (show the
  reference ghost over the just-picked photo, offer "re-pick" — weaker, but schema-free and still
  useful). **Decide before building P2.** Do not silently assume live head-on.

### P2.1 — Entry: "compare to an existing position"

- From a position (or the compare screen), a **"Match this position"** action starts a capture
  whose reference is that position. This is the *only* new entry point; it reuses the normal
  capture flow, just carrying a reference id.
- The reference supplies: its stored `maskData` (for the silhouette outline) and its landmarks
  (for the faint pose) — both already persisted, both in the reference's own image space.

### P2.2 — Render the ghost (one layer, one opacity, on/off)

- **Compose one reference layer:** the silhouette as an **outline/edge stroke** (not a filled
  matte — a fill would occlude the live subject), low-opacity `acc`, plus the reference pose
  skeleton in a dim stroke. Composite them together; expose a single **show/hide** control
  (default **on**), no sub-choices. This is the "combined ghost" the overlay-taxonomy section
  requires.
- **Why outline, not fill:** during alignment you need to see *yourself through the guide*. The
  Inspect matte is a solid tint; the Align ghost is a hollow outline. Different jobs, different
  render — implement a stroke/edge pass on the mask (trace the foreground boundary) rather than
  reusing `tintedOverlay`'s fill.
- **Coordinate alignment:** the ghost is drawn in the live preview's fitted image rect using the
  same `SkeletonGeometry`/aspect-fit the skeleton already uses. The reference and the live frame
  must share a framing assumption — document that the ghost assumes similar camera distance/angle
  (which P4 would later measure), and that gross framing differences make the ghost approximate.
- **Motion (Plan N):** the ghost fades in at `Motion.fast`, hard-edged, no pulse/glow/spring. It's
  a static guide, not an animation. Honour `prefers-reduced-motion` (it's already static, so
  nothing to collapse).

### P2.3 — Keep it out of the Inspect control

- Reiterated because it's the failure mode: the ghost's on/off lives **only** in the live-capture
  step, never in RevealStep's or PositionDetailView's PHOTO/MASK/BONES bar. After the shot, the
  ghost is gone and the normal Inspect ladder takes over.

**P2 deliverable:** shooting a comparison, the rider sees a faint outline+pose of the position
they're matching and can line up to it live — attacking drift at the source rather than reporting
it after.

---

## P3 — Front/rear determination in side-on (prerequisite for the wake caveat)

The reason this matters: the honest wake caveat (torsten-aero-notes §C #8 — "frontal area may
under-read a change that sits behind you") is **meaningless until we know which end of the bike is
the front** in a side-on shot. A side-on photo can face left or right; without facing, "front bag"
vs "rear bag" is a coin toss, and we don't ship coin tosses (spec §3).

Note: a recent change already makes side-on pose detection **try both sides** (commit *"try both
sides for side-on pose, not just left"*), so the pose lands regardless of facing — but it **doesn't
record which way the rider faces**. P3 is about capturing and trusting that fact.

### P3.1 — Determine facing (derive first, don't guess)

Facing is derivable from the **already-stored** `sideOnSkeletonPoints` (shoulder/hip/knee/ear,
PositionMetrics.swift:51) — a new pure function in `AnalysisMath`, no new capture:

- **Forward = the direction the rider leans/looks.** In a riding position the head and shoulders
  reach *toward the front of the bike*, so three independent x-axis cues point forward:
  - `sign(shoulderX − hipX)` — torso lean toward the bars,
  - `sign(earX − shoulderX)` — head reaching forward,
  - `sign(kneeX − hipX)` — knee ahead of hip.
- **Combine as a vote with a confidence.** Agreement across the three + their magnitude = a facing
  confidence. Strong agreement → trust it. **Disagreement or tiny magnitudes (an upright rider,
  torso near-vertical) → low confidence → do not guess.**
- Return `(facing: .left | .right, confidence: Double)` — pure, testable, nil/low-confidence
  handled explicitly.

### P3.2 — Confirm with the rider when unsure (explicit, correctable)

Per Kah's standing preference for **explicit, discoverable controls over hidden inference**
(and the "don't display what you can't defend" rule):

- **High confidence:** label facing automatically, but keep it **visibly correctable** — a small
  "front ▸" indicator on the side-on view the user can tap to flip. Never silently locked.
- **Low confidence:** ask, once — a single "Which way is the front?" tap at capture. One tap, not a
  flow. This is the honest path when geometry is ambiguous, and it's cheap.

### P3.3 — Storage (mostly schema-free; override is the only new field)

- The **derived** facing needs no storage — recompute from `sideOnSkeletonPoints` at display time
  (same "derive, don't persist" pattern as `shoulderWidthWarning`).
- Only a **user override** needs persisting (a rider who flipped a correct-looking-but-wrong auto
  guess). That's one optional field (`sideOnFacingOverride`) → a **small schema addition → STOP/
  confirm with Kah**, though far lighter than Plan O. If we accept "derive + confirm-at-capture
  without persisting an override," P3 stays fully schema-free — a viable simpler option to put to
  Kah.

### P3.4 — What facing unlocks (the wake caveat, downstream)

Once facing is known, a **silhouette diff between two side-on captures** can localise *where* area
was added — front half vs rear half, split at the hip/bottom-bracket line. If the growth is behind
the rider, surface the honest note: *"this change sits in your wake — frontal area may under-read
its true aero effect"* (torsten §C #8). This localisation is the more advanced analysis step; P3
delivers the **facing** it depends on, and the diff can follow as its own increment. Don't build
the diff before facing is solid.

### P3 testing

- Pure-function unit tests for P3.1: clear left-facing and right-facing landmark sets → correct
  facing at high confidence; a near-upright/ambiguous set → low confidence (so the UI asks);
  malformed/absent points → nil. Tune the confidence threshold on device (human-gated).

---

## P4 — Camera-distance / framing consistency (later; bigger; needs a decision)

Torsten fixed his entire rig; we can't fix the phone, but we can *notice* when two compared shots
were taken very differently.

- **Idea:** record capture distance/angle (ARKit capture pose) and warn when two compared shots
  differ enough to inject scale/parallax noise — a sibling of the pose-delta warning, for the
  camera instead of the body.
- **Blocker:** this needs capture-pose metadata persisted per position → **SwiftData schema change
  → STOP and discuss** (same gate Plan O went through). Also verify how much AR metadata the
  capture path already retains before scoping.
- **Sequencing:** do not fold into P1/P2. This is a separate, later slice precisely because it
  breaks the "schema-free" property that makes P1/P2 safe.

---

## Data-model impact

- **P1:** none. Reads existing `PositionMetrics` landmarks/angles.
- **P2:** none. Reads the reference's existing `maskData` + landmarks. (Carrying a reference id
  through the capture flow is transient state, not persisted.)
- **P3:** none *if* facing is derive-and-confirm-at-capture; **one small optional field**
  (`sideOnFacingOverride`) only if we persist a user's flip → gated (P3.3).
- **P4:** **schema change** (capture-pose metadata) — gated.

Keeping P1+P2 (and P3, if we skip the persisted override) schema-free is deliberate: they ship as
a coherent slice without a migration stage, unlike Plan O.

## Testing

- **P1.2 pose-delta:** pure-function unit tests in the `AnalysisMath` suite — symmetric inputs →
  `nil`; a known angle delta → the expected tier; malformed/absent landmarks → `nil` (no partial
  warnings, mirroring the skeleton constructors' nil-on-malformed rule). Tune thresholds on device.
- **P1.3 / P2:** on-device checklist (human-gated, like Plan O6): the reminder reads right; the
  warning fires when you deliberately slump between two shots and stays silent when you don't; the
  ghost lands on the body and is genuinely alignable; the ghost never appears in an Inspect
  control; Reduce Motion behaves.

## Open questions / human-gated

1. **Head-on live vs photo-pick** — gates P2's reach (P2.0). Confirm before building.
2. **Pose-delta thresholds** — starting points only; tune on hardware. Never ship a guessed
   threshold as validated (spec §3).
3. **Reminder placement** — capture intro, compare entry, or both. A copy/UX call for Kah.
4. **Ghost edge rendering** — need a foreground-outline pass on the mask (P2.2); confirm approach
   (trace boundary vs cheap dilate-and-subtract) before implementing.
5. **P3 facing storage** — derive-and-confirm-only (schema-free) vs persist a `sideOnFacingOverride`
   (one small gated field). Kah's call; the schema-free option is simpler and probably enough.
6. **P3 confidence threshold** — where "ask the rider" kicks in; tune on device, don't ship a guess.
