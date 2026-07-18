# Plan V — Richer skeletons (tertiary bone tier, front + side)

Status: planned 2026-07-18. Kah's call: the skeletons are visually thin —
frontal is a T-shape, side-on is a floating torso. Add more bones for visual
interest without letting decoration read as measurement.

## Context for the implementing agent

Read `CLAUDE.md` first. Files in scope:

- `ios/GetTucked/Design/SkeletonOverlay.swift` — new tier + constructor params
- `ios/GetTucked/Analysis/AnalysisEngine.swift` — capture more Vision joints
- `ios/GetTucked/Models/PositionMetrics.swift` — three new optional fields
- `ios/GetTucked/Models/AppSchema.swift` — SchemaV6 snapshot + lightweight stage
- `ios/GetTucked/Capture/CaptureView.swift` — persist new points; RevealStep overlay
- `ios/GetTucked/Views/PositionDetailView.swift` — pass new points to constructors
- `ios/GetTuckedTests/SkeletonOverlayTests.swift` — constructor/tier tests

Verify: `cd ios && xcodegen generate`, then full suite via xcodebuild against
any available iPhone simulator (iPhone 17 worked for Plan U; iPhone 16 is not
installed). All 151 existing tests must stay green.

Honesty rule (spec §3, Plan O): tiers exist so decoration can never read as
measurement. `.measured` feeds a displayed number, `.context` explains, and
the new third tier is pure body-shape richness. Each step down must be
visibly quieter than the last.

## V1 — The `detail` tier in SkeletonOverlay

Add a third case to `SkeletonOverlay.Tier`:

```swift
case measured   // feeds a displayed number — acc, 2px bones, 8px joints
case context    // explanatory — fg2, 2px bones, 8px joints
case detail     // body-shape richness only — fg4, 1px bones, 6px joints
```

- `color`: `.detail` → `Theme.Palette.fg4` (dim-label grey — one step below
  context's fg2, same hard-edged rendering, no opacity tricks).
- Move `boneWidth`/`jointSize` from overlay-level constants onto `Tier`
  (`lineWidth: CGFloat`, `jointSize: CGFloat`): measured/context keep 2/8,
  detail gets 1/6. `boneView` strokes with `bone.tier.lineWidth`; `jointView`
  sizes from the tier it already resolves (`touching.first?.tier`) — when a
  detail bone shares a joint with a higher tier, the higher tier's joint
  wins: sort `touching` so measured > context > detail before picking.
- Update the `Tier` doc comment to describe all three tiers.

## V2 — Frontal: torso + upper legs

`SkeletonOverlay.frontal` gains a third parameter, default nil so existing
call sites and tests compile unchanged:

```swift
static func frontal(shoulders: [Double], arms: [Double]?, body: [Double]? = nil) -> SkeletonOverlay?
```

`body` is `[leftHipX, leftHipY, rightHipX, rightHipY, leftKneeX, leftKneeY,
rightKneeX, rightKneeY]` (8 values; nil-on-malformed like `arms`). Joints
append after the arm joints: leftHip 6, rightHip 7, leftKnee 8, rightKnee 9
(when `arms` is nil, body indices shift down to 2–5 — compute from
`joints.count` before appending, don't hardcode). Bones, all `.detail`:

- leftShoulder→leftHip and rightShoulder→rightHip — **window 1** (torso sides)
- leftHip→rightHip — **window 1** (pelvis bar, closes the torso shape)
- leftHip→leftKnee and rightHip→rightKnee — **window 2** (upper legs)

Windows 1 and 2 are shared with the arm chains deliberately: the cascade gets
*denser*, not longer — `windowCount` stays 3 and `totalDrawDuration` is
unchanged, so the reveal ceremony's "quiet secondary beat ≲0.4s" budget
(Plan O4) still holds. Do not add new windows on the frontal skeleton.

## V3 — Side-on: arm chain + shank

`SkeletonOverlay.sideOn` gains two parameters, both default nil:

```swift
static func sideOn(points: [Double], arm: [Double]? = nil, ankle: [Double]? = nil) -> SkeletonOverlay?
```

- `arm` is `[elbowX, elbowY, wristX, wristY]` — joints elbow 4, wrist 5.
  Bones: shoulder(0)→elbow **window 1**, elbow→wrist **window 2**, tier
  `.context` — not `.detail`: the arm to the bars is the reach line, it
  *explains* the position the same way the frontal arm chains do.
- `ankle` is `[ankleX, ankleY]` — joint appended after any arm joints
  (compute index from `joints.count`). Bone: knee(2)→ankle, **window 2**,
  tier `.detail` (the shank continues the leg the knee joint ends at, so it
  reads as growth from window 1's hip–knee bone).
- Same shared-window rule as V2: `windowCount` stays 3, duration unchanged.

## V4 — Capture the joints (AnalysisEngine)

- `HeadOnPoseMetrics` gains `bodyPoints: [CGPoint]?`. New private
  `bodyPoints(from:)` mirroring `armPoints(from:)` exactly — joints
  `[.leftHip, .rightHip, .leftKnee, .rightKnee]`, all-or-nothing at
  confidence > 0.5, never throws (presentational context, not measurement).
- Side-on: `sideOnJoints(from:side:)` currently returns the four measured
  joints; the winning `BodySide` is needed afterwards, so also try the same
  side's `.elbow`/`.wrist`/`.ankle` (e.g. extend `BodySide.joints` or add a
  second lookup using the side that succeeded). Arm is all-or-nothing
  (elbow+wrist together); ankle independent — cranks/chainrings occlude
  ankles often, and a missing ankle must not cost the arm chain (and vice
  versa). Same 0.5 confidence floor. `SideOnPoseMetrics` gains
  `armPoints: [CGPoint]?` and `anklePoint: CGPoint?`.
- No measurement math changes anywhere in this plan — these points feed the
  overlay only.

## V5 — Persist (PositionMetrics + SchemaV6)

New optional fields on the live `PositionMetrics`, comment-documented like
their siblings (same Vision-normalised, origin-bottom-left convention):

```swift
// headOnBodyPoints: [leftHipX, leftHipY, rightHipX, rightHipY,
//                    leftKneeX, leftKneeY, rightKneeX, rightKneeY]
var headOnBodyPoints: [Double]?
// sideOnArmPoints: [elbowX, elbowY, wristX, wristY] — same detected side
// as sideOnSkeletonPoints
var sideOnArmPoints: [Double]?
// sideOnAnklePoint: [ankleX, ankleY]
var sideOnAnklePoint: [Double]?
```

`AppSchema.swift`: add a `SchemaV6` snapshot (copy the V5 classes, add the
three fields to its `PositionMetrics`), register it in
`AppMigrationPlan.schemas`, and add `migrateV5toV6` as
`MigrationStage.lightweight` with the same "additions are optional" comment
the previous stages carry. This follows the established pattern exactly;
Kah approved the migration stage by approving this plan.

Existing positions simply have nil in the new fields — the overlay omits
those bones, same graceful degrade as nil `arms` today. Old and new
positions will show different skeleton richness side by side; accepted.

## V6 — Wire the call sites

- `CaptureView` save path (~line 529): persist `headOnBodyPoints` from
  `headOnPose.bodyPoints`, and `sideOnArmPoints`/`sideOnAnklePoint` from
  `pendingSideOnPose`, using the same `flatMap { [$0.x, $0.y] }` shape as
  the existing arm persistence.
- `CaptureView.frontalSkeletonOverlay` (RevealStep, ~line 938): pass
  `body:` from `result.headOnPose?.bodyPoints`.
- `CaptureView` ghost reference (~line 399): pass the new stored fields into
  both constructors.
- `PositionDetailView` (~line 296): same for both constructors.
- Update both `#Preview` blocks in SkeletonOverlay.swift to exercise the new
  parameters (pick plausible cyclist coordinates).

## V7 — Tests

Extend `SkeletonOverlayTests` following its existing style:

- `frontal` with valid `body` → joint count 10, four/five detail bones on
  windows 1–2, `windowCount` still 3 (assert `totalDrawDuration` equals the
  arms-only value — that's the "denser not longer" guarantee).
- `frontal` with malformed `body` (odd/short count) → nil.
- `frontal` with `arms: nil, body: valid` → correct shifted joint indices.
- `sideOn` with `arm` + `ankle` → joint count 7, arm bones `.context`,
  shank `.detail`, `windowCount` still 3.
- `sideOn` with only `ankle` → shank present, no arm bones, correct index.
- Tier rendering constants: `.detail.lineWidth == 1`, `.detail.jointSize == 6`
  (only if lineWidth/jointSize land on `Tier` as V1 specifies).

## Order & commits

One commit for V1–V3 (overlay, self-contained, previews prove it):
`feat(design): tertiary detail tier + richer frontal/side skeletons`.
Second commit for V4–V6 (capture → persist → wire, crosses the schema bump):
`feat(analysis): capture and persist body/arm/ankle joints for the skeleton (SchemaV6)`.
Third: `test(design): cover detail-tier skeleton constructors`.

Done means: project regenerates and builds, full suite green, previews show
the richer skeletons, and — critical — `totalDrawDuration` unchanged on both
constructors. On-device migration check (existing store opens, old positions
render with their thinner skeletons) happens in Kah's next device pass with
Plans P–U.
