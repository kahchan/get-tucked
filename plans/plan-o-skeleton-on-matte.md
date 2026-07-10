# Plan O — Skeleton on the Matte (frontal + side-on)

Status: O1–O6 code complete (2026-07-10). Build green, all 80 tests pass
(17 new — SkeletonGeometry/SkeletonTimeline math, frontal/sideOn convenience
constructors). O6's on-device checklist (migration from a pre-O1 store,
skeleton lands on the body in both orientations, draw-on feel, Reduce
Motion) is human-gated — still needs Kah on physical hardware.
Scope: render the pose skeleton over the matte on both the frontal and side-on
photos, in RevealStep and PositionDetailView. Adds a side-on segmentation pass
and persists pose landmarks — **this is a SwiftData schema change (V1 → V2)**,
approved by Kah 2026-07-10. **No change to any displayed number** — the
skeleton visualises landmarks the pipeline already computes; angles and areas
are untouched.

This doc is written for an implementing agent who has not seen the planning
conversation. Read `CLAUDE.md` (design language section) and
`plans/plan-n-motion-and-experience-polish.md` (motion philosophy) first —
every animation in this plan must obey Plan N's rules.

## Decisions already made (do not re-litigate)

Kah decided, 2026-07-10:

1. **Render sites: both** — RevealStep (quiet secondary beat in the ceremony)
   and PositionDetailView (no ceremony, behind an explicit control).
2. **Side-on gets a matte too** — run person segmentation on the side-on
   photo, store the mask (`sideOnMaskData`), skeleton renders on the tinted
   matte so frontal and side-on read consistently.
3. **Landmarks are persisted at capture** — the exact points the angle math
   consumed are stored in `PositionMetrics`, so the skeleton is a replay of
   what produced the numbers, never a re-estimate that could disagree.
4. **Measurement joints, plus frontal arms** (arms added 2026-07-10) —
   frontal: the shoulder pair (feeds shoulder width) **and both arm chains**
   (shoulder→elbow→wrist per side) — arms are what riders change between
   positions, so they're what makes the skeleton *explain* an area delta.
   Side-on: shoulder–hip–knee chain plus ear (feeds torso angle, hip angle,
   head drop). No other joints. **Visual honesty rule:** joints/bones that
   feed a displayed number draw in `acc`; the frontal arm chains are context,
   not measurement, and draw in a dimmer stroke (`fg2`) so the two tiers
   never read as equally "measured" (spec §3 spirit).
5. **Staggered draw-on** (Kah, 2026-07-10) — the skeleton never draws as one
   simultaneous flash; bones arrive in a stagger (see motion rules).

## Current state (what you'll find in the code)

- `AnalysisEngine.estimateHeadOnPose` (AnalysisEngine.swift ~L270) already
  detects left/right shoulder at confidence > 0.5, returns only
  `shoulderWidthCm` — the points are discarded.
- `AnalysisEngine.estimateSideOnPose` (~L303) detects left shoulder / hip /
  knee / ear at confidence > 0.5, returns only the three derived metrics —
  points discarded. **No segmentation runs on the side-on photo today.**
- Vision landmarks are normalised (0–1, **origin bottom-left**).
- `Position.maskData` stores the head-on mask as untinted grayscale PNG
  (downscaled via `MatteRenderer.downscaledMaskPNGData`); tint is applied at
  display time by `MatteRenderer.tintedOverlay`. Side-on has photo storage
  (`sideOnPhotoData` / `sideOnPhotoIdentifier`) but no mask.
- `AppSchema.swift`: `SchemaV1` only, empty `stages`.
- Display sites: `RevealStep` (private, CaptureView.swift ~L457) shows the
  head-on photo + matte with the N2 scan-wipe ceremony and a PHOTO/MASK
  `SegmentedToggleBar`. `PositionDetailView` shows FRONTAL/SIDE-ON toggle,
  and a PHOTO/MASK toggle on frontal only; side-on shows the bare photo.
- Motion components available (Design/MotionViews.swift): `RollingNumberText`,
  `.scanReveal(progress:)`, `.cascadeIn(index:trigger:)`, `Haptics`.
  Motion tokens in `Theme.Motion` (fast 0.15, base 0.25, gentle 0.45,
  sweep 0.90, roll 0.80, stagger 0.05; `entrance()` = easeOut,
  `travel()` = easeInOut).

## Open questions — STOP and ask Kah before implementing these two

1. **Old positions (no stored landmarks / no side-on mask).** Recommendation:
   **no backfill in v1** — the BONES control simply doesn't appear for
   positions captured before this plan. Rationale: recomputing pose on an old
   photo can yield landmarks that disagree slightly with the stored angles,
   and a skeleton that contradicts its own numbers violates spec §3. A
   backfill that recomputes landmarks *and* angles together from the stored
   photo is a possible follow-up, but it silently rewrites saved numbers, so
   it needs its own sign-off.
2. **Toggle UI.** The request is "skeleton on the matte", and Kah prefers
   explicit, discoverable controls. Recommendation: generalise
   `SegmentedToggleBar` (Design/Components.swift) to three segments —
   **PHOTO / MASK / BONES** — where BONES = matte + skeleton. Applied to both
   RevealStep and PositionDetailView (frontal *and* side-on, once side-on has
   a mask). Alternative if three segments feel cramped: keep PHOTO/MASK and
   add a separate BONES on/off chip. Show Kah a build of the 3-segment bar
   before committing to it.

## Motion rules for the skeleton (Plan N applied)

- **Form:** hard-edged. Bones are 2px straight strokes — `Theme.Palette.acc`
  for measurement bones (frontal shoulder bar; side-on chain), `fg2` for the
  frontal arm chains (context tier). Joints are small **squares** (~8pt, 0px
  radius — never circles), filled in their tier's color with a 1px `bg0`
  inset border so they read on top of the tinted matte. No glow, no blur, no
  springs, no scale.
- **Draw-on = staggered travel:** bones never appear simultaneously — each
  bone draws via path `trim` with `Theme.Motion.travel()` easing, starting
  `Theme.Motion.stagger` (0.05s) after the previous bone *starts* (an
  overlapping cascade, like `.cascadeIn`, not a strict relay where each bone
  waits for the last to finish). Draw order follows the body outward:
  frontal — shoulder bar first, then both arms in parallel, upper arms then
  forearms; side-on — shoulder–hip, hip–knee, shoulder–ear. Joints pop to
  full opacity (duration `Motion.fast`) the moment their bone's trim reaches
  them — a hard arrival, eased approach.
- **Fresh numbers get ceremony; saved numbers don't.** RevealStep: bones draw
  on. PositionDetailView: no draw-on — skeleton appears as a plain
  `Motion.fast` opacity fade when the BONES segment is selected.
- **One wow moment.** The scan wipe + number roll stay the hero. The frontal
  skeleton is a single shoulder segment drawing quietly (duration
  `Motion.base`) *after* the sweep completes, while the number is still
  rolling — it must never delay or upstage the roll.
- **Interruptible:** the draw-on joins RevealStep's existing ceremony state —
  a mid-sequence interaction that snaps the ceremony forward also snaps the
  skeleton to fully drawn (`ceremonyCancelled` pattern).
- **Reduce Motion:** skeleton appears at final state via opacity fade,
  centralised in the component so call sites get it free.
- **Never animate uncertainty:** the skeleton celebrates landmarks that passed
  the confidence floor. If landmarks are absent, nothing draws — no partial
  or apologetic skeleton.

## Work items

Ordering: O1 → O2 → O3, then O4/O5 in either order, O6 last.
One conventional commit each; the app builds and behaves coherently after
every commit. Run `cd ios && xcodegen generate` after adding files.

---

### O1 — Persist landmarks + side-on mask field (schema V2)

**Models/PositionMetrics.swift** — two optional fields, flattened `[Double]`
in Vision-normalised coordinates (0–1, origin bottom-left), matching the
`handlebarTapPoints` storage convention. Comment the layout at the
declaration — it's non-obvious *why*-adjacent (coordinate origin):

- `headOnSkeletonPoints: [Double]?` — `[leftShoulderX, leftShoulderY,
  rightShoulderX, rightShoulderY]`.
- `headOnArmPoints: [Double]?` — `[leftElbowX, leftElbowY, leftWristX,
  leftWristY, rightElbowX, rightElbowY, rightWristX, rightWristY]`.
  Separate field (not appended to the shoulder array) because arms are
  optional: **all four arm joints must pass the 0.5 confidence floor or the
  field stays nil** — a one-armed skeleton reads as broken, so arms are
  symmetric-or-nothing while shoulders remain independently required.
- `sideOnSkeletonPoints: [Double]?` — `[shoulderX, shoulderY, hipX, hipY,
  kneeX, kneeY, earX, earY]` (left-side landmarks, same points the angle
  math consumed).

**Models/Position.swift** — `sideOnMaskData: Data?`, untinted grayscale PNG,
mirroring `maskData`'s comment and rationale.

**Models/AppSchema.swift** — add `SchemaV2` (version 2,0,0) and a
`.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)` stage.
All new properties are optional, so existing stores migrate in place.
Freeze `SchemaV1`'s model list by snapshotting if needed — V1 must keep
describing the pre-O1 shape; don't let both versions point at the same
mutated classes without checking the migration actually runs on an existing
store (test: install pre-O1 build, save a position, upgrade, relaunch).

Commit: `feat(models): persist pose landmarks and side-on mask (schema V2)`

### O2 — Pipeline: return landmarks, segment the side-on photo

**Analysis/AnalysisEngine.swift** — no math changes:

- `HeadOnPoseMetrics` gains `leftShoulder: CGPoint` / `rightShoulder:
  CGPoint` (normalised). `estimateHeadOnPose` populates them from the points
  it already guards.
- `HeadOnPoseMetrics` also gains `armPoints: [CGPoint]?` (elbow/wrist ×
  both sides, order as in O1): request `.leftElbow`, `.leftWrist`,
  `.rightElbow`, `.rightWrist` from the same observation; if any is missing
  or below the 0.5 floor, `armPoints` is nil — **never throw for arms**,
  they're presentational and must not affect the shoulder-width path.
- `SideOnPoseMetrics` gains `shoulder/hip/knee/ear: CGPoint`. Same deal.
- `analyseSideOn` returns a small struct (`SideOnAnalysis`) bundling
  `SideOnPoseMetrics` + `maskImage: UIImage?`: after the pose estimate
  succeeds, run the existing `segmentPerson` on the side-on image.
  **Segmentation failure must not fail the pose metrics** — the side-on
  matte is presentational; catch and return `nil` mask, the UI degrades to
  photo + skeleton-over-photo. (Note: `VNGeneratePersonSegmentationRequest`
  is person-only — the bike won't be in the side-on matte, consistent with
  the frontal matte today. The A1 mask-definition question is unchanged.)

**Capture/CaptureView.swift** — `savePosition` writes
`metrics.headOnSkeletonPoints` / `metrics.headOnArmPoints` /
`metrics.sideOnSkeletonPoints` from the
pose structs, and `position.sideOnMaskData` via
`MatteRenderer.downscaledMaskPNGData`. The side-on `AnalysingView` scan
(N3 minimum-sweep) already covers the added segmentation latency — verify
the 1.2s floor still masks it on-device.

Commit: `feat(analysis): surface pose landmarks and side-on matte from the pipeline`

### O3 — `SkeletonOverlay` component

**New file `ios/GetTucked/Design/SkeletonOverlay.swift`:**

```swift
struct SkeletonOverlay: View {
    struct Bone {
        let from: Int          // indices into `joints`
        let to: Int
        let tier: Tier         // .measured (acc) or .context (fg2)
    }
    /// Joints in Vision-normalised coords (0–1, origin bottom-left).
    let joints: [CGPoint]
    /// Bones in draw order; stagger derives from position in this array.
    let bones: [Bone]
    /// 0→1 draw progress; 1 = fully drawn. Callers own the animation.
    var progress: Double = 1
}
```

- Renders in a `Canvas` (or a `Shape` per bone with `trim`): flip Y
  (Vision origin is bottom-left, SwiftUI top-left), scale into the view's
  bounds. Callers overlay it in the same `ZStack` as the photo/matte with a
  matching `aspectRatio`, exactly as the matte `Image` already aligns — the
  overlay must inherit the photo's fitted rect, so give it the photo's
  aspect ratio and `scaledToFit` geometry (same container).
- Bone drawing: **staggered cascade** — bone *i*'s trim window starts at
  `i × Motion.stagger` within the total timeline and runs for a fixed
  per-bone duration, so bones overlap like `.cascadeIn` rather than relay.
  Map the caller's single 0→1 `progress` across that timeline (total = last
  bone's start + per-bone duration, normalised back to 0→1) — pure math,
  unit-testable. Joints appear as their bone's trim reaches them. Styling
  per the motion-rules section (2px strokes, tier colors, 8pt square
  joints, 1px bg0 inset). Bones drawn in parallel (the two frontal arms)
  share the same window index.
- Convenience constructors:
  `SkeletonOverlay.frontal(shoulders: [Double], arms: [Double]?)` —
  shoulder bar (`.measured`) always; when `arms` is non-nil, both arm
  chains (`.context`): upper arms share window 1, forearms window 2.
  `SkeletonOverlay.sideOn(points: [Double])` (4 joints, all `.measured`;
  bones shoulder–hip, hip–knee, shoulder–ear in that order). Both return
  `nil` on malformed counts — no partial skeletons; a nil `arms` simply
  omits the context tier.
- Reduce Motion is the *caller's* animation concern (they pass progress),
  but add a `.skeletonReveal(visible:)` helper mirroring `.scanReveal`'s
  pattern: animates trim with `Theme.Motion.travel()`, collapses to an
  opacity fade under `accessibilityReduceMotion`.
- Add a `#Preview` demo next to the existing MotionViews demos.

Commit: `feat(design): SkeletonOverlay — hard-edged pose skeleton with trim draw-on`

### O4 — RevealStep: quiet draw-on after the sweep

**Capture/CaptureView.swift (`RevealStep`):**

- Extend the toggle to PHOTO / MASK / BONES per the open-question resolution
  (generalise `SegmentedToggleBar` to N segments in Components.swift; the
  N4 underline slide must keep working — it becomes an offset move across
  three slots).
- Default selection after the ceremony: **BONES** if `headOnSkeletonPoints`
  exists (the matte stays visible underneath), else MASK — the reveal should
  land on the richest defensible view.
- Sequence: when the scan sweep completes (existing completion that starts
  the number roll), start the frontal skeleton draw — shoulder bar, then
  arms, in the staggered cascade O3 defines (per-bone `Motion.base`,
  `travel()`, `Motion.stagger` offsets — total ≲0.4s). It runs concurrently
  with the 0.8s roll and finishes first, staying the quiet secondary beat.
  Wire into the existing ceremony snap: `ceremonyCancelled` forces
  `progress = 1`.
- Reduce Motion: skeleton fades in with everything else, no trim animation
  (comes free from `.skeletonReveal`).
- No new haptics — the roll-complete `Haptics.confirm()` stays the only one.

Commit: `feat(motion): frontal skeleton draw-on in the reveal ceremony`

### O5 — PositionDetailView: skeleton on frontal and side-on, no ceremony

**Views/PositionDetailView.swift:**

- Frontal: PHOTO / MASK / BONES bar (hidden BONES segment when
  `headOnSkeletonPoints == nil` — old positions, per open question 1).
  Selecting BONES fades the skeleton in over the matte, `Motion.fast`,
  no draw-on.
- Side-on: build the side-on matte overlay off-main exactly like the
  existing `buildMaskOverlay` (N5 pattern — pixel work off the main actor),
  from `sideOnMaskData`. Add the same PHOTO / MASK / BONES bar under the
  side-on photo when a mask or skeleton exists; degrade gracefully:
  mask-only → PHOTO/MASK, skeleton-only (segmentation failed at capture) →
  PHOTO/BONES with the skeleton over the photo.
- A revisit must never feel slower than today (Plan N): photo appears
  exactly as it does now; overlays fade in when ready.
- Remember the selected segment per photo side within the session
  (`@State`), don't persist it.

Commit: `feat(views): skeleton + side-on matte on position detail`

### O6 — Verification & on-device checklist (human-gated)

- Unit-test the coordinate transform (Vision bottom-left → view top-left,
  aspect-fit scaling) and the stagger timeline mapping (global progress →
  per-bone trim) — pure functions, put the math in a testable helper.
- Migration test: install the pre-O1 build, save positions, upgrade, confirm
  positions load and the BONES segment is absent for them.
- On-device (Kah): skeleton lands on the body in both orientations
  (including Plan L landscape side-on); draw-on feels quiet next to the
  roll; Reduce Motion collapses everything to fades; segmentation latency
  on the side-on analysing step still feels covered by the scan.

Commit: `test(analysis): skeleton coordinate transform + migration check`

## Non-goals

- No backfill of old positions (open question 1 — follow-up if approved).
- No full-body skeleton, no confidence visualisation, no angle-arc overlays.
- No change to any computed or displayed number, no new Vision requests
  beyond reusing `segmentPerson` on the side-on photo.
- No skeleton in ComparisonView (possible follow-up once this lands).
