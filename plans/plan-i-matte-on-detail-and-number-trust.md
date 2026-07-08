# Plan I — Matte on the recorded position + number trust carried through

Status: **done** (I1–I6 executed 2026-07-08, commits `cfee250`,
`9ce285b`, `51f25f3`, `4ed519b`, `8df962b`, `b8df82d`). All six tasks
landed; tests green (43 pass, up from 36). I2's PHOTO/MASK toggle
verified via the seeded-position screenshot technique (temporary
`AppNavigationView` seed inserting a synthetic photo + mask, jumped
straight to the detail screen, reverted before commit — see I2's
commit message). I5's "bonus check" (confirm `.accurate` mask
dimensions on a real device capture) is the only human-gated item
left, and it's advisory, not blocking — the aspect guard itself
shipped and is unit-tested against a realistic rounding case.

Written 2026-07-08 after a review session. Two
strands, deliberately in one plan because they touch the same files:

1. **Finish the matte track** — Plan H's H3/H4 (persist the mask, show it on
   the detail screen) were scoped out of the execution slice and never built.
   The reveal now shows a correct mask overlay; the saved position shows
   nothing.
2. **Carry the number-trust story onto the saved position.** The reveal shows
   the scale warning and the bar width used; the detail screen shows neither.
   FUNNY BOI (shoulder 21.8 cm, below the 30 cm plausibility floor) displays
   2,537 cm² on its detail screen with no flag at all. And the bar width that
   *produced* a position's area is not persisted anywhere — editing a bike's
   bar width later silently orphans every old position's number.

## Verify loop (every task)

```sh
cd ios && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -project GetTucked.xcodeproj -scheme GetTucked \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

New Swift files need `cd ios && xcodegen generate` first. UI checks: the
established static-state `@State`-seed + `xcrun simctl io booted screenshot`
technique (seed, screenshot, revert before commit — grep for
`TEMP-SCREENSHOT-SEED`). No tap simulation available. One commit per task,
Conventional Commits.

## Tasks

### I1. Persist the mask on the position (Plan H · H3)

Files: `ios/GetTucked/Models/Position.swift`,
`ios/GetTucked/Capture/CaptureView.swift` (`savePosition`).

- Add `var maskData: Data?` to `Position`. Additive optional field →
  lightweight automatic migration, no migration stage (the "stop and ask"
  rule covers staged migrations; this isn't one).
- In `savePosition`, store `pendingResult.maskImage` as **PNG** (lossless —
  JPEG would fuzz the silhouette edge), downscaled so its long edge matches
  the stored photo's (≤1400px, mirroring `compressedForStorage`). The Vision
  mask may already be smaller than that; only downscale, never upscale.
- Store the mask exactly as produced — raw grayscale, not a baked tinted
  overlay. Rationale (from Plan H's flagged decision, recommendation adopted):
  smaller, lossless, recolorable — a future accent/opacity change must not
  leave old positions with a stale baked-in tint.

Commit: `feat(capture): persist the segmentation mask on saved positions (Plan H3)`

### I2. MASK toggle on the detail screen (Plan H · H4) + shared toggle component

Files: `ios/GetTucked/Views/PositionDetailView.swift`,
`ios/GetTucked/Design/SharedViews.swift`,
`ios/GetTucked/Capture/CaptureView.swift`.

- `RevealStep`'s `MaskToggleBar` and `PositionDetailView`'s
  `PhotoToggle`/`ToggleTab` are near-identical private copies. Extract one
  shared segmented-tab component into `SharedViews.swift` first, then use it
  in both places. (Three toggle states now meet on the detail screen —
  FRONTAL / SIDE-ON and PHOTO / MASK — so the shared component should
  compose: keep them as two stacked bars, MASK bar only in FRONTAL view.)
- When `position.maskData` exists and the frontal photo is showing, offer
  PHOTO / MASK; composite via `MatteRenderer.tintedOverlay` over the stored
  photo. Build the overlay once (`@State` on appear), not per layout pass.
- **Do not back-fill old positions by re-running Vision** — that would show a
  different mask than the one that produced the stored number. No `maskData`
  → no MASK toggle. FUNNY BOI stays toggle-less; that's correct.
- Mind the mask/photo geometry: the stored photo and stored mask have
  different pixel sizes. Both are `.resizable().scaledToFit()` in the same
  ZStack — they only align if aspect ratios match. Assert/check this once at
  overlay-build time; if they differ, skip the overlay rather than show a
  misregistered one (this is the same aspect question as I5).

Commit: `feat(detail): PHOTO/MASK toggle on saved positions (Plan H4)`

### I3. Persist the ruler: `handlebarWidthMmUsed`

Files: `ios/GetTucked/Models/PositionMetrics.swift`,
`ios/GetTucked/Capture/CaptureView.swift` (`savePosition`),
`ios/GetTucked/Views/PositionDetailView.swift` (`MetricsSection`).

- Add `var handlebarWidthMmUsed: Double?` to `PositionMetrics` (additive
  optional, same migration reasoning as I1). Populate at save time from the
  value the analysis actually used.
- Detail screen: add `MetricRow(key: "Bar width", value: "… mm")` when
  present, matching the reveal's row.
- This makes every saved number auditable: area + pixelsPerCm + bar width +
  tap points are then all on the record (spec §3).

Commit: `feat(model): persist the handlebar width used for each capture`

### I4. Detail screen shows the scale warning

File: `ios/GetTucked/Views/PositionDetailView.swift` (`MetricsSection`).

- `shoulderWidthCm` is already persisted. When
  `!AnalysisMath.isShoulderWidthPlausible(shoulderWidthCm)`, render the same
  amber warning line the reveal shows (same copy, same `Theme.mono(11)` /
  `amb` styling), directly under the ± uncertainty line — above the fold.
- Recompute from stored data at display time (don't persist the warning
  string — the plausibility rule may be tuned later, e.g. for junior riders,
  and stored positions should pick that up).

Commit: `feat(detail): surface the scale warning on saved positions`

### I5. Aspect-ratio guard (the unbuilt H5 leftover)

Files: `ios/GetTucked/Analysis/AnalysisMath.swift`,
`ios/GetTucked/Analysis/AnalysisEngine.swift`, `ios/GetTuckedTests/`.

- `maskPixelsPerCm` rescales by **width ratio only** — correct only if the
  Vision mask preserves the source aspect ratio. Unverified assumption, and
  it silently distorts area if false.
- Add pure `AnalysisMath.maskMatchesSourceAspect(maskW:maskH:sourceW:sourceH:tolerance:)`
  (suggest tolerance ~2%); unit-test the predicate (match, mismatch,
  rounding-edge cases like 4032×3024 → 512×384).
- In `analyse`, on mismatch: widen the uncertainty honestly or attach a
  warning — **never silently proceed, never fudge the count** (spec §3).
- Bonus check while in there: log/compare the `.accurate` mask dimensions on
  a real device capture once (MatteCheck harness already shows the mask) so
  the assumption is confirmed empirically, not just guarded.

Commit: `feat(analysis): guard the mask/source aspect-ratio assumption (Plan H5)`

### I6. One voice for the area number

Files: `ios/GetTucked/Analysis/AnalysisMath.swift`,
`ios/GetTucked/Capture/CaptureView.swift`,
`ios/GetTucked/Views/PositionDetailView.swift` (+ Leaderboard/Comparison if
they format independently — check).

- Detail truncates (`Int(metrics.frontalAreaCm2)`), reveal rounds
  (`Int(...rounded())`) — the same position can read 1 cm² differently on two
  screens. Add `AnalysisMath.areaDisplay(_:) -> String` (rounded, matching
  `uncertaintyDisplay`'s pattern) and use it everywhere an area is shown.

Commit: `refactor(ui): single shared formatter for displayed frontal area`

## Explicitly out of scope

- Plan G (side-on live capture) — but its side-on photo-persistence gap is
  now recorded in plan G itself (G0), added the same day as this plan.
- The A1 person-vs-person+bike mask question and A5 burst uncertainty —
  still gated on Kah's on-device verdicts.
- Any change to how the area is *computed*. See the review note on the
  scale-plane perspective bias (bar is nearer the camera than the torso →
  pixelsPerCm reads large → area reads small). That is a documentation /
  methodology-screen candidate, and mostly cancels in comparisons on the
  same bike — do NOT "correct" for it numerically (spec §3).

## Experiment protocol — ruler ground truth (any human, tape measure required)

Added 2026-07-08. The tester does **not** need adult shoulders — the check is
app-reading vs *measured* ground truth, not vs the 30–60 cm plausibility
range (which is adult-calibrated and will keep flagging a child; ignore the
amber line for this test, it's advisory).

1. Tape-measure the tester's shoulder span, joint-to-joint across the front
   (Vision's shoulder landmarks sit roughly at the joint centres, slightly
   inside the outer shoulder edge). Write it down: `S_true`.
2. **Shot A — bar held against the chest** (same depth plane as the body).
   Capture, read the app's shoulder width. With the bar and body coplanar the
   perspective bias vanishes: reading ≈ `S_true` ⇒ the ruler (bar width +
   taps) is right. A mismatch here is a genuine calibration bug — investigate
   taps / bar entry before anything else.
3. **Shot B — bar held at arms' length** (riding-position geometry, same
   camera spot). Reading will come in *below* `S_true`; the ratio
   `reading / S_true` is the linear perspective bias, and its square is the
   area bias. Record both numbers in this doc.
4. Expected shape of the result: Shot A ≈ `S_true`, Shot B ≈ 0.8–0.9 ×
   `S_true` at typical indoor distances. Bias shrinks as the camera moves
   back — worth one extra shot from farther away if room allows.

**Results (2026-07-08, Kah, tape measure confirmed).** FUNNY BOI's
normal-riding-position capture (bar at arms' length — Shot B geometry):
`S_true = 31 cm` (tape), app read `21.8 cm` → ratio `0.70`, i.e. a ~30%
linear undershoot — bigger than the "typical indoor distances" 0.8–0.9×
estimate above. Confirms the scale-plane perspective bias is real and
non-trivial, not just a theoretical concern. **Shot A (bar at chest) not
yet done** — without it we can't yet separate "pure perspective bias"
(expected, geometry-only) from "the ruler itself is also off" (a real
bug, e.g. mis-tapped bar ends or wrong bar width on record) for this
specific capture. Worth doing before deciding whether this stays a
documentation matter or escalates to the depth-capture idea below.

This needs no new code and settles, separately: (a) is the ruler right, and
(b) how big is the scale-plane bias in practice. If (b) turns out large and
Kah wants the app to *measure* it per-capture rather than document it, that
is a depth-capture feature (LiDAR `AVDepthData` at the tap points at shutter
time) — a new plan, flagged as a product decision, not something to fold in
here.

## Idea stage (2026-07-08, Kah) — cross-scale verification via the front wheel

**Promoted same day to [`plan-k-wheel-size-and-scale-verifier.md`](plan-k-wheel-size-and-scale-verifier.md)**
after Kah adopted it (verifier taps to be optional; wheel size captured as
bike-setup metadata). Analysis kept below for the reasoning record.

Question: given optionally
entered figures (bar width, wheelbase), can the app *derive or verify* one
dimension from the images?

**Directly, no** — each ruler is only visible in one view. The bar spans the
frontal photo but points at the camera side-on; the wheelbase spans the
side-on photo but foreshortens to nothing head-on. Neither photo can measure
the other's ruler.

**Via a bridge, yes: the front wheel is visible in both photos**, and it
sits at (nearly) the bar's depth plane — which makes the chain
perspective-consistent:

- *Side-on:* wheelbase taps → side-on px/cm → measure the front wheel's
  diameter in cm (full circle, trivial to tap top+bottom of tire).
- *Frontal:* the same wheel edge-on — a vertical circle parallel to the
  camera axis, so its projected **height** equals its true diameter
  (foreshortening squashes its width, not its height). Tap ground contact +
  tire top → frontal px/cm at the front-wheel≈bar plane.
- Compare against the bar-tap ruler. Disagreement beyond a few % ⇒ one of
  the entered figures (or a tap) is wrong — surfaced as a warning.

**Shorter chain, frontal photo alone:** tire overall diameter is known-ish
without side-on at all (spec'd per tire, e.g. 700×28 ≈ 684 mm; 29er ≈ 740 mm;
or tape-measured once) → a second independent ruler in the same photo as the
bar taps. Two rulers, one photo, no new capture step.

**Use as verification, never silent replacement** (spec §3): the entered bar
width stays the ruler; the derived figure exists to *catch* the single most
dangerous silent error in the pipeline — a wrong bar width, which enters the
area squared. Copy shape: "Bar taps and wheel size disagree by 18% — check
the bar width on this bike." Chained tap error is maybe ±3–5%, which is
plenty for a mis-entry check (440 vs 760 is a 73% disagreement) but not good
enough to *be* the ruler.

Also decided: `reach` may be recorded as optional setup metadata if wanted,
but it is a poor ruler — its endpoints (BB centre, head-tube top) are far
less tappable than hub centres or a tire's ground contact. Don't build a
scale on it.

## Acceptance

A position captured after I1 shows a PHOTO/MASK toggle on its detail screen
with the tint hugging the rider only; pre-I1 positions show no toggle. The
detail screen shows bar width used and (when shoulder width is implausible)
the same amber warning as the reveal. The aspect predicate is unit-tested and
`analyse` responds honestly to a mismatch. Area reads identically on every
screen. All existing tests stay green.
