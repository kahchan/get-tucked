# Plan N — Motion & Experience Polish

Status: N1–N9 code complete. N9's on-device checklist (camera/haptics/feel,
Reduce Motion, Dynamic Type) is human-gated — still needs Kah on physical
hardware; the code-level Reduce Motion audit is done.
Scope: animation, transitions, pre-population, haptics. **No measurement logic
changes** — nothing in `Analysis/` changes behaviour, no model/schema changes.

This doc is written for an implementing agent who has not seen the review
conversation. Read `CLAUDE.md` first (design language section), then this.

## Review — where we are

The visual system (`Theme.swift`, hard edges, acid/amber on near-black, Space
Mono) is consistent, but the app is almost entirely static:

- Capture steps (`CaptureView.stepContent`) hard-cut between states — no transition.
- `AnalysingView` (private, in `CaptureView.swift`) is a bare static label
  filling the screen for ~1s of real segmentation work.
- `RevealStep` shows the 60pt hero number instantly; the matte overlay pops in
  fully formed once `MatteRenderer.tintedOverlay` finishes in `onAppear`.
- `PositionDetailView` flashes the `···` placeholder, then the photo pops in
  with a layout jump; the mask overlay is built on the main actor after photo load.
- `SegmentedToggleBar` / `FilterBar` underlines jump between tabs (they're
  conditional views, not a moving element).
- The only animations in the app: the compare bar slide-up (`PositionListView`,
  which animates on `selected.count` only — `selectMode` toggling is NOT
  animated, so checkboxes pop in) and the RESET VIEW zoom in
  `HandlebarCalibrationStep`.
- No haptics anywhere.

## Motion philosophy

- **Hard-edged in form, eased in timing.** The *shapes* of motion match the
  design system — wipes, scan lines, clipped reveals, monospace digit rolls,
  no springs, no bounce, no blur, no overshoot, no scale above 1.0. But the
  *timing* is always eased: every animation in the app uses an easing curve
  (`easeOut` for entrances, `easeInOut` for sweeps and travel). Nothing runs
  on a `linear` curve — linear reads as mechanical/cheap, and the brutalism
  lives in the geometry, not in robotic timing. A scan line still sweeps a
  hard 1px edge; it just accelerates into the pass and settles out of it.
- **One wow moment per flow.** The frontal-area reveal is *the* moment of the
  app; everything else stays quick and quiet so it keeps its weight.
  - Primary: RevealStep (scan wipe + number roll).
  - Secondary: ComparisonView delta hero (only when distinguishable — never
    celebrate noise, Plan A4 spirit).
  - Everything else: fades and small slides, 150–300ms, done before the user
    notices they waited.
- **Fresh numbers get ceremony; saved numbers don't.** RevealStep counts up.
  PositionDetailView (revisiting stored data) settles fast — a revisit must
  never feel slower than today.
- **Never animate uncertainty or warnings.** ± lines, amber warnings, and the
  within-noise state appear as plain fades. Motion celebrates the measurement,
  not the error bar (spec §3: no fake precision, no fake drama).
- **Never trap the user in an animation.** Every ceremonial sequence must be
  interruptible — controls stay live, and interacting with a control that an
  animation is "about to reveal" snaps the whole sequence to its end state.
- **Reduce Motion honored everywhere** — every effect degrades to opacity
  fade, numbers appear at final value. Centralized in the N1 components so
  call sites get it for free.

## Work items

Ordering: N1 → N2 → N3 → N4, then N5–N8 in any order, N9 last.
Each item is one self-contained conventional commit (`feat(motion): …`); the
app must build and behave coherently after every commit.

---

### N1 — Motion tokens + shared components (foundation, do first)

**`Theme.swift`** — add a `Motion` enum alongside the existing token enums:

```swift
enum Motion {
    static let fast: Double = 0.15      // press states, handle pops, banner text
    static let base: Double = 0.25      // step fades, toggles, list changes
    static let gentle: Double = 0.45    // photo fade-in, section entrances
    static let sweep: Double = 0.90     // scan wipe across the matte
    static let roll: Double = 0.80      // hero number count-up
    static let stagger: Double = 0.05   // per-row cascade offset

    /// Entrances: content arriving — decelerate in.
    static func entrance(_ d: Double = base) -> Animation { .easeOut(duration: d) }
    /// Travel: sweeps, slides, reorders — accelerate in, settle out.
    static func travel(_ d: Double = base) -> Animation { .easeInOut(duration: d) }
}
```

**New file `ios/GetTucked/Design/MotionViews.swift`** (add to the Xcode
project via `cd ios && xcodegen generate` — project.yml globs the source
tree, so just regenerate):

1. **`RollingNumberText`** — animatable count-up for hero numbers.
   ```swift
   struct RollingNumberText: View {
       let value: Double                     // final value
       let format: (Double) -> String        // e.g. AnalysisMath.areaDisplay
       let font: Font
       let color: Color
       var duration: Double = Theme.Motion.roll
       var delay: Double = 0
   }
   ```
   Implementation: an `Animatable` `ViewModifier` (or `AnimatableModifier`
   pattern) whose `animatableData` is the displayed `Double`; on appear,
   `withAnimation(Theme.Motion.travel(duration).delay(delay))` drive it from
   `value * 0.88` → `value`. Rendering goes through `format` — the *same*
   formatter the static display uses — so the rolled value can never disagree
   with the final displayed value. Starting at ~88% (not 0) because a
   from-zero roll reads as a slot machine and implies precision theater.
   Space Mono is monospaced, so no layout jitter; still set
   `.monospacedDigit()` defensively for the fallback system font.
   Reduce Motion: render `format(value)` immediately, no animation.

2. **`ScanReveal`** — view modifier revealing content top-to-bottom behind a
   scan line.
   ```swift
   extension View {
       /// progress 0→1 reveals top-to-bottom; a 1px acc scan line rides the
       /// reveal edge and fades out when progress reaches 1.
       func scanReveal(progress: Double) -> some View
   }
   ```
   Implementation: `.mask(alignment: .top) { GeometryReader → Rectangle
   .frame(height: h * progress) }` plus an `.overlay` positioning a
   1px-high `Theme.Palette.acc` rectangle at `y = h * progress` (hidden when
   progress ≥ 1, opacity fade over `fast`). The *caller* animates progress
   with `Theme.Motion.travel(Theme.Motion.sweep)`. Reduce Motion: caller
   checks the environment and sets progress straight to 1 inside a plain
   `entrance()` fade of the whole content instead.

3. **`Cascade`** — indexed entrance for stacked rows.
   ```swift
   extension View {
       /// Opacity 0→1 + 8pt upward settle, entrance(gentle), delayed
       /// index * Theme.Motion.stagger after `trigger` becomes true.
       func cascadeIn(index: Int, trigger: Bool) -> some View
   }
   ```
   Reduce Motion: single opacity fade, no offset, no per-index delay.

4. **`Haptics`** — thin wrapper so call sites are one-liners:
   ```swift
   enum Haptics {
       static func tap()      // UIImpactFeedbackGenerator(style: .light)
       static func confirm()  // UINotificationFeedbackGenerator .success
       static func select()   // UISelectionFeedbackGenerator
   }
   ```
   All no-op behind `#if canImport(UIKit)`.

5. **`MotionSettings`** — one place to read Reduce Motion:
   ```swift
   // @Environment(\.accessibilityReduceMotion) is per-view; components 1–3
   // read it themselves. Expose a helper for imperative call sites:
   // UIAccessibility.isReduceMotionEnabled behind canImport(UIKit).
   ```

**Acceptance (N1):** components compile with `#Preview` blocks demonstrating
each (previews are the verification here — simulator screenshots of the
previews are optional). Zero existing call sites changed. Tests still green
(`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test
-project ios/GetTucked.xcodeproj -scheme GetTucked -destination 'platform=iOS
Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO`).

---

### N2 — The reveal ceremony (`RevealStep` in `CaptureView.swift`)

Sequence on entry to `.reveal` (total ~1.8s, phases overlapping):

| t (s) | what | how |
|---|---|---|
| 0.0 | photo already on screen (carried from analysing, N3) | no animation |
| 0.0–0.9 | matte overlay wipes in top→bottom | `scanReveal`, `travel(sweep)` |
| ~0.9 | sweep completes | `Haptics.tap()` |
| 0.5 | "FRONTAL AREA" label fades in | `entrance()` |
| 0.7–1.5 | hero number rolls | `RollingNumberText(delay: 0.7)` |
| ~1.5 | number lands | `Haptics.confirm()` |
| 1.5 | uncertainty line, scale warning (if any), HOW-IT'S-MADE link | plain fade `entrance()`, **no motion** (philosophy: never animate uncertainty) |
| 1.6+ | metric rows cascade | `cascadeIn(index:)`, buttons fade last |

Implementation notes:
- Drive the sequence off a single `@State private var revealPhase` (or a set
  of booleans flipped in `onAppear` via `withAnimation(...delay:)`) — do NOT
  use `DispatchQueue.asyncAfter` chains; delays live in the animations so
  Reduce Motion collapses cleanly.
- The PHOTO/MASK `SegmentedToggleBar` stays interactive the whole time.
  Toggling mid-sweep **cancels the ceremony**: set sweep progress to 1 and
  all phase flags true without animation, then crossfade to the chosen state.
- After the ceremony, PHOTO↔MASK toggling is a `travel(base)` crossfade
  (0.25s) between the two image states — the sweep is a once-per-result
  event, never re-run on toggle.
- Move the `tintedOverlay` build out of `onAppear` on the main actor into a
  detached task started when analysis completes (N3 hands the overlay over),
  so the sweep never waits on pixel work. If the overlay genuinely isn't
  ready at t=0, delay the sweep start until it is — never sweep-reveal
  nothing.
- Skipped side-on / failed pose changes nothing here; the sequence only
  depends on `result`.

**Acceptance (N2):** seeded-state screenshots (established repo technique —
seed `AppNavigationView.path = [.capture]`, `step = .reveal`, synthetic
photo + DeviceGray mask; grep for the seed marker before commit) showing
mid-sweep (partial matte + scan line visible) and end state. Real feel check
is N9's on-device pass.

---

### N3 — Analysing as a scanner, not a blank wall

Replace `AnalysingView`'s bare label with the captured photo being scanned:

- Show the image being analysed (`selectedImage` for `.analysing`,
  `sideOnImage` for `.analysingSideOn` — pass it in) dimmed to ~40% opacity,
  with a 1px `acc` scan line sweeping top→bottom on a loop —
  `travel(1.2)` per pass with `.repeatForever(autoreverses: false)`, a
  brief hold at the top between passes so each pass reads as a discrete
  eased sweep, not a sawtooth.
- Step label beneath with a blinking block cursor: `ANALYSING ▮` — cursor
  blinks via opacity toggle every 0.5s (the most Space-Mono loading state
  there is). No fake stage names — `AnalysisEngine.analyse` is one opaque
  call, and invented stages would violate the "every displayed state is
  defensible" rule (spec §3).
- **Minimum display of one full sweep** (1.2s): in `runAnalysis()` /
  `runSideOnAnalysis()`, record the step-entry time; if the engine returns
  early, delay the step advance until the current pass completes
  (`try? await Task.sleep`). The matte wipe (N2) then reads as the scan
  line's *final* pass finding the rider — analysing → reveal is one
  continuous visual gesture.
- Error path unchanged (alert fires immediately), no minimum hold on failure.
- Reduce Motion: static dimmed photo + label, no scan line, no minimum hold.

**Acceptance (N3):** seeded screenshot of the analysing state showing dimmed
photo + label; a timing check that a fast (<1.2s) analysis still shows the
analysing step (can be asserted by log timestamps in a debug run, or just
verified on-device in N9).

---

### N4 — Capture step transitions + haptics

**Step transitions** (`CaptureView.stepContent`):
- Add `.animation(Theme.Motion.entrance(), value: step)` on the `Group` and
  `.transition(.opacity)` on the step views — EXCEPT the two live-camera
  steps (`.pickPhoto`, `.pickSideOnPhoto`): the viewfinder must cut in
  immediately with no fade delaying it (use `.transition(.identity)` for
  those cases).

**Calibration (`HandlebarCalibrationStep`):**
- Tap placement: handle appears with a 0.15s settle — scale 1.3→1.0,
  `entrance(fast)` (arriving and settling, no bounce) + `Haptics.tap()`.
- Second point placed: the dashed connecting line *draws* from point A to B —
  `trim(from: 0, to: progress)` on the existing `Path`, `travel(base)` +
  `Haptics.tap()`. (Applies to both the bar pair and the optional wheel pair.)
- Banner text changes ("Now tap the right end" …): 0.15s crossfade — give the
  banner `Text` an `.id(bannerText)` + `.transition(.opacity)` +
  `.animation(entrance(fast), value: bannerText)`.
- RESET VIEW / wheel-verify link rows appearing: `entrance()` fade+slide
  (currently they pop the layout).

**`NamePositionStep`:**
- Auto-focus the name field on appear (`@FocusState` + set true in
  `onAppear` with a short delay if needed for the push transition) —
  pre-populating the *keyboard* is the polish here.
- SAVE POSITION → `Haptics.confirm()` in the save action.

**`CaptureSuccessStep`:** small punch only (the reveal already happened):
"SAVED" fades in, number rises 8pt + fades (`entrance(gentle)`, no roll),
buttons follow ~0.15s later. One `Haptics.confirm()` on appear.

Files: `CaptureView.swift`; `Components.swift` only if AccentButton's
enabled-state color change needs an `.animation(_:value:)` added (it does:
animate line→acc with `entrance()` when `enabled` flips — this also covers
CONFIRM SCALE).

**Acceptance (N4):** build green; seeded screenshots for calibrate state;
gesture feel is N9's on-device pass.

---

### N5 — PositionDetail: pre-populate and settle, don't perform

Goal: a revisit feels *instant*, never staged. (`PositionDetailView.swift`)

- **Metrics stay static** — they're synchronous from SwiftData already. No
  count-up here (saved number, no ceremony).
- **Kill the placeholder flash / layout jump**: render the placeholder at the
  real photo aspect ratio (decode just the image size from
  `position.photosData` header via `CGImageSource` without full decode, fall
  back to 4/3), then fade the decoded image in over it —
  `entrance(gentle)` opacity, zero layout shift.
- **Decode off-main**: move `UIImage(data:)` decode and
  `buildMaskOverlay()` (pure pixel pass) into the existing `.task` but off
  the main actor (`Task.detached(priority: .userInitiated)`), assigning
  results back on main. The MASK `SegmentedToggleBar` fades in
  (`entrance()`) when the overlay is ready instead of popping the layout.
- PHOTO↔MASK and FRONTAL↔SIDE-ON toggles: `travel(base)` crossfade between
  image states (currently hard swap).
- One flourish only: on push, the hero area number gets a 0.25s settle
  (opacity + 4pt rise). Everything else renders immediately.

**Acceptance (N5):** seeded-position screenshots; before/after check that
nothing renders later than it does today (the toggles may *appear* slightly
later since overlay build moves off-main — that's the intended trade, note it
in the commit message).

---

### N6 — Comparison: the second (conditional) wow (`ComparisonView.swift`)

- 2-up panels, then the table: quick cascade (`cascadeIn`, tight stagger) —
  total under 0.5s.
- **Distinguishable delta** (`DeltaHero`, `isDistinguishable == true`):
  `RollingNumberText` on the delta % (0.6s, `format` builds the
  `+/-x.x%` string), color arrives *with* the number (acc for improvement,
  amb for regression — the existing `color` logic), then "A IS SMALLER ·
  n cm²" fades in after. `Haptics.confirm()` only when it's an improvement
  (delta < 0).
- **Within noise**: no ceremony at all — the ≈ block and its lines plain-fade
  in together (`entrance()`). The absence of motion *is* the message. No
  haptic.
- `DiffTable` diff-column values: no roll (derived, small, numerous); rows
  just cascade with the table.
- Cross-bike warning: appears with the panels, no special motion (it's a
  warning — philosophy says warnings don't perform).

**Acceptance (N6):** seeded screenshots of both hero states; confirm the
within-noise path has no `RollingNumberText` in it at all.

---

### N7 — Lists: stagger, reorder, select mode

**`PositionListView.swift`:**
- Animate `selectMode` (currently unanimated — the `.animation` modifier only
  watches `selected.count`): add `.animation(Theme.Motion.entrance(),
  value: selectMode)`; checkboxes get `.transition(.move(edge:
  .leading).combined(with: .opacity))` so they slide in while row content
  shifts right.
- Row select/deselect: `Haptics.select()`; the inner acid square scales in
  `entrance(fast)` (add `.transition(.scale)` inside the existing `if
  isSelected`).
- Returning from a *new* save (`.done` → VIEW ANALYSIS or back to root): the
  newest row (index 0, list is newest-first) fades in with a 2px acid
  left-edge tick that fades out over 0.6s — "here's what you just made".
  Implement by passing a `highlightID: UUID?` down (set when arriving from
  the capture flow, cleared after first render). **No stagger on routine
  visits** — the root list must render instantly.

**`LeaderboardView.swift`:**
- Filter change: `ForEach` identity is already `\.element.id` — add
  `.animation(Theme.Motion.travel(), value: bikeFilter)` so rows slide to
  their new rank order instead of teleporting.
- Rank 1: 2px acc underline sweeps in left→right (`travel(gentle)`) once per
  push — the podium moment, small.

**`SharedViews.swift` (`SegmentedToggleBar`) + `LeaderboardView` (`FilterBar`):**
- Underline slides between tabs via `matchedGeometryEffect` in a shared
  namespace (`travel(0.2)`) instead of the conditional
  appear/disappear rectangles.

**Acceptance (N7):** seeded screenshots (select mode on, leaderboard filtered);
reorder animation verified on-device in N9.

---

### N8 — Micro-interactions (component-level, app-wide for free)

All in `Components.swift` / `SharedViews.swift` / `AppNavigation.swift`:

- `AccentButton` / `GhostButton`: custom `ButtonStyle` (replace
  `.buttonStyle(.plain)`) — while pressed, background darkens ~12% (overlay
  `Color.black.opacity(0.12)`) and the `→` nudges 3pt trailing;
  `entrance(fast)` both ways. Hard-edged: **no scale change**.
- `HeaderLink` / `HowItWorksLink`: pressed opacity 0.6, 0.1s.
- `StatusPill` (capture HUD): border/dot color changes crossfade
  `entrance()`; dot blinks once (opacity dip) on transition into `.ok`.
- `BackButton`: pressed state nudges glyph 2pt leading.

**Acceptance (N8):** build green; every screen inherits without call-site
changes; press feel is N9's device pass.

---

### N9 — Reduce Motion + on-device pass (human-gated finish)

- Code audit: every N1–N8 effect degrades under Reduce Motion (mostly free
  via the N1 components — audit the direct `.animation`/`withAnimation` call
  sites added in N4/N5/N7 and gate the offset/slide parts, plain fades may
  remain).
- On-device checklist for Kah (simulator has no camera; feel needs hardware):
  - [ ] Full capture flow: scanner hold never exceeds ~1 extra second; reveal
        sequence lands; no matte flash-then-wipe double draw; haptic timing
        matches the number landing.
  - [ ] Reveal with side-on skipped, with pose failure, with scale warning —
        warnings appear as plain fades, no ceremony.
  - [ ] Toggle PHOTO/MASK *during* the sweep — ceremony cancels cleanly.
  - [ ] Detail push of an old position: image fade, zero layout jump, MASK
        toggle appears when overlay ready, revisit feels instant.
  - [ ] Comparison both cases: distinguishable (roll + haptic on improvement)
        and within-noise (nothing moves, no haptic).
  - [ ] Leaderboard filter reorder slides; rank-1 underline once per push.
  - [ ] Select mode in/out slides; compare bar; new-save row tick appears
        once; haptics overall feel sparse, not buzzy.
  - [ ] Settings → Accessibility → Reduce Motion ON: nothing sweeps, rolls,
        or slides; app fully usable.
  - [ ] Dynamic Type XL: rolls/cascades don't clip or overlap.

## Verification notes for the implementing agent

- Build/test command and the `DEVELOPER_DIR` override, the seeded-`path`
  screenshot technique (and the "grep for the seed marker before commit"
  discipline), and the no-tap-simulation constraint are all documented in the
  project memory (`ios_phase2_plan.md`) — follow those patterns.
- Animations can't be screenshot-verified end-to-end in the simulator without
  tap simulation; verify *states* (mid-progress values can be seeded the same
  way as any other `@State`) and leave *feel* to the N9 device pass.
- After adding `MotionViews.swift`: `cd ios && xcodegen generate` before
  building.

## Explicit non-goals

- No launch/onboarding animation work (`WelcomeView` untouched this plan).
- No live-capture HUD motion (`LiveCameraView`) beyond the StatusPill color
  crossfade (N8) — capture legibility is Plan L territory; don't add motion
  over a viewfinder.
- No skeleton shimmers, no progress bars pretending to know progress, no
  animated uncertainty, no confetti. Ever.
- No `linear` timing curves anywhere — see philosophy.
