# Plan D — Design parity with the prototype

Status: **in progress**. D1 done (`438f70d`) — also added a discovered
fix: reserved trailing space (`Theme.Control.hamburgerReserve`) so
Positions'/Bikes' header actions don't collide with the relocated
hamburger. D2-D7 not started; D8 remains decision-gated per below.
Written 2026-07-03, after unpacking the Claude Design
prototype into `inspiration/unpacked/` (`template.html` = screens + CSS,
`b554d774.js` = flows/behaviours/copy). **Those two files are the design
authority** — when this plan is ambiguous, open them and match the prototype.
Same verify loop as Plans A–C. One commit per task.

Read first: prototype screen flow (SCREENS array, `b554d774.js:6`):
Welcome → How It Works → Bike Setup → Set the Scene → **Practice Capture** →
Capture Front+Side → Processing → Reveal → Name → **Noise Floor prompt** →
**Comparison prompt** → Library (empty/full) → 2-Up → Leaderboard → Methodology.

Deliberate deviations from the prototype (do NOT "fix" these):
- **Display precision:** prototype shows `124.7` (one decimal, placeholder
  data). Real frontal areas are ~3500–5500 cm²; one-decimal display there is
  fake precision. Keep integer cm².
- **BG pill is advisory** in the app (prototype gates the shutter on it).
  A dead shutter in a real environment is worse than a noisy matte.
- **Type floor:** prototype uses 7–9px labels at stage scale; on device we
  keep Plan B's 11pt floor. Preserve the *hierarchy*, not the absolute sizes.

## D1. Header pattern + hamburger position

Prototype headers (`.scr-head`) are **left-aligned**: Barlow Condensed 19px
uppercase title with a mono 11 subtitle line under it (e.g. "Set the Scene /
Good light in, good numbers out."), hairline below. The index button sits
**top-right** (three 16px lines), not top-left.

- `ios/GetTucked/Design/SharedViews.swift` — rework `NavHeader`: left-aligned
  `Theme.heading(19)` title + optional `subtitle` param rendered
  `Theme.mono(11)` fg3 below, trailing slot kept. Callers pass subtitles:
  POSITIONS → "Tap two to compare.", LEADERBOARD → "Your positions, ranked by
  frontal area.", SET THE SCENE → "Good light in, good numbers out.",
  BIKE SETUP → "Two facts. Then we shoot."
- `ios/GetTucked/Design/AppNavigation.swift` — move `HamburgerButton` overlay
  to `.topTrailing`; back affordance (where pushed screens need one) is a
  mono `←` at top-left (prototype `.back-btn`).

**Acceptance:** every screen shows left-aligned title + subtitle; hamburger
top-right; no centred titles remain.

## D2. Camera HUD to prototype spec

File: `ios/GetTucked/Capture/LiveCameraView.swift`. Current HUD diverges from
the prototype capture screens (`buildTwoStepCapture`, `b554d774.js:116`):

1. **Bike chip top-centre**, two-line ("SHOOTING ON" 8px-equiv key over the
   bike name in Barlow Condensed) with an acc `▾` caret — currently a one-line
   chip top-left. Tappable → picker sheet (phase2 item 2 / Plan C4).
2. **Step label top-left** (`FRONTAL · 1 OF 2`, mono bold acc) + **progress
   dashes top-right** (two 20×2 bars: acc = current, line = pending; after
   frontal: fg3 + acc). On frontal capture success, flash the label to
   `✓ FRONTAL CAPTURED` (acc) for ~0.7s before switching to side-on.
3. **Framing guide**: centred 150×210-proportioned 1px white(0.14) rect with
   guide caption above it — `FRAME RIDER FRONT-ON` / `FRAME RIDER IN PROFILE`
   — plus 16px corner brackets in the four frame corners (white 0.2).
4. **Level line**: full-width 1px acc line at vertical centre with `LEVEL ✓`
   caption when level (replaces the current top `LevelLine` tick-on-rail;
   keep the amber/deviation behaviour, move it to centre).
5. **Capture control is a full-width 56pt bordered bar**, not a round
   shutter: label `ALIGN TO CAPTURE` (fg3, border line) → ready state
   `CAPTURE FRONTAL` / `CAPTURE SIDE-ON` (acc border, acc label, 5% acc fill).
6. Pills row sits directly above the capture bar on a bg0 strip with a top
   hairline (already close; pill dots are round — that's correct, the
   0-radius rule exempts dots/radios/checks, see prototype CSS `.pill-dot`).

This task also delivers the **side-on live capture** as step 2 of the same
screen (phase2-live-capture-plan item 3 — same session, guide text swap, no
re-calibration), since the two-step HUD is one component in the prototype.

**Acceptance:** side-by-side with prototype screen `04 Capture · Front+Side`
(open `inspiration/unpacked/template.html` in a browser, index → screen 04),
the HUD elements match in placement and behaviour.

## D3. Processing screen

Prototype s5: centred `PROCESSING` label, a 1px acc progress bar animating
0→100%, and rotating status messages `SEGMENTING RIDER → ESTIMATING POSE →
COMPUTING AREA → VALIDATING RESULT` (~420ms cadence).

- `ios/GetTucked/Capture/CaptureView.swift` — replace both analysing states
  with one `ProcessingStep` view implementing the above (drive the bar with
  a `withAnimation(.linear(duration:))`; messages on a timer; analysis
  completion navigates as today — the bar is choreography, not real progress,
  so cap the bar at ~90% until the real result lands, then snap to 100%).

**Acceptance:** capture → processing shows bar + rotating messages in tokens;
no system `ProgressView` remains in the flow.

## D4. Reveal to prototype spec (extends Plan C1)

Prototype s6 layout, top to bottom: step label `RESULT · HEAD-ON`; 360pt-ish
stand-in area (in the app: **the captured photo with matte overlay** — C1);
a bg1 headline band with hairlines: tiny key `FRONTAL AREA · <NAME>`, the
big number (60pt mono bold) with `cm²` unit and — right-aligned in the same
band — a small `NOISE FLOOR / ±N%` block, tappable → methodology screen;
then metric rows (50pt, 16pt bold values); then the acc CTA `NAME THIS
POSITION`.

- `ios/GetTucked/Capture/CaptureView.swift` (`RevealStep`):
  - restructure to the band layout above; move the ± out of the hero into the
    right-aligned NOISE FLOOR block, shown as a **percentage** (from
    `AnalysisMath.uncertaintyFraction`, i.e. `±3%` until the burst/self-test
    lands), tappable → HowItWorks (Plan A2).
  - **Count-up animation** on the area number (~0.9s ease-out cubic, prototype
    `countUp`) — this is the reveal moment the spec (§17) budgets 3–6s for;
    pair it with the C1 matte fade-in (photo → matte trace → number counts).
- Keep integer cm² (deliberate deviation, above).

**Acceptance:** reveal reads top-to-bottom like prototype screen 06 with real
photo+matte in place of the stand-in; number animates; noise-floor block
links to methodology.

## D5. Positions list = prototype Library rows

Prototype `.lib-row`: 46×58 **thumbnail**, name in **Barlow Condensed 16
uppercase**, chip row under it (bike type chip, acc-bordered when ROAD +
bike-name chip), right-aligned area (16 bold) with tiny date under it.
App rows are all-mono, no thumbnail, no chips.

- `ios/GetTucked/Views/PositionListView.swift`:
  - `PositionRow`/`SelectablePositionRow`: thumbnail from `position.photosData`
    (46×58, `.scaledToFit` into a bg `standin` rect — add
    `standin = Color(hex: 0x1C1C1C)` to `Theme.Palette`), name
    `Theme.heading(16)`, chips (new small `Chip` view in
    `Design/Components.swift`: mono 9–11 per Plan B floor, 1px border,
    uppercase; acc variant), value column right-aligned.
  - Selection circle: prototype uses a **round** check that fills acc with a
    dark tick — replace the current square indicator (rounds are correct for
    radio/check controls).
  - Header subtitle per D1; keep SELECT mode + compare bar (prototype selects
    by tapping rows directly and evicts the oldest selection when a third is
    tapped — adopt that and drop the explicit SELECT/DONE toggle only if it
    survives a feel-check on device; otherwise keep SELECT mode).
- Empty library: prototype `10 Library Empty` shows the position list plus a
  **dashed-border card**: eyebrow `NEXT STEP`, Barlow copy "Add a second
  position to start comparing.", acc CTA. Use this pattern for the app's
  empty/one-position states instead of the centred `EmptyStateView` text.

**Acceptance:** list matches prototype screens 10/11 (minus event chips —
events are Phase 4).

## D6. Comparison screen to prototype spec (merges into Plan C5)

Prototype s12 layout details my Plan C5 didn't have:

- Panels 240pt with **matte/skeleton render per side** (photo thumbnails from
  `photosData` for now), A tag fg3 / B tag acc, names in Barlow Condensed.
- Delta hero: signed % (56pt) in acc, caption **`A IS SMALLER · 6.5 cm²`**
  (winner + absolute cm² delta — clearer than the current "SMALLER FRONTAL
  AREA" line).
- Noise line under the hero: `Your noise floor: ±N% — this delta is real.`
  when distinguishable; the **flat state** (Plan A4) renders the delta in
  fg2 at ~34pt instead of acc 56pt with caption `WITHIN MEASUREMENT NOISE`.
- Diff rows: single combined `A / B` value cell + signed delta cell
  (down=acc, up=amb) — simpler than the current 3-column table; adopt it.
- Bottom toggle row `SILHOUETTE / SKELETON / BAGS` — build the row with
  SILHOUETTE functional (matte overlay on panels), SKELETON and BAGS as
  disabled placeholders (Phase 3).

Files: `ios/GetTucked/Views/ComparisonView.swift` (+ `AnalysisMath` helpers
from Plan A4).

**Acceptance:** matches prototype screen 12; flat state reachable by comparing
two captures of the same position.

## D7. Leaderboard to prototype spec (supersedes Plan C7)

Prototype s13 resolves the baseline question (Plan C flagged decision #1):
**baseline = your most upright position (largest area)**, auto-selected, and
each row shows `−X% vs upright`; the baseline row's sub reads
`YOUR UPRIGHT BASELINE`. Rows also carry a **proportional bar** (2pt track,
fill scaled so smaller area = longer bar; acc fill on the highlighted row)
and a `LATEST` acc tag on the most recent capture. Ranks 1–3 in fg, rest fg4.

- `ios/GetTucked/Views/LeaderboardView.swift`: implement rows per above
  (`Position.isBaseline` stays unused — baseline is *derived* as max-area
  row within the current filter; no schema change). Keep ALL/ROAD/GRAVEL/MTB
  filter; subtitle updates per filter ("Your ROAD positions, ranked…").
  Apply Plan A4's noise gate to the `−X%` subs.

**Acceptance:** matches prototype screen 13 with real data; baseline row
labelled; bars proportional.

## D8. Onboarding flow additions (decision-gated — confirm with Kah first)

The prototype onboarding has four screens the app lacks entirely:

1. **How It Works intro** (s_intro: Snap / Measure / Compare, 3 numbered
   steps) between Welcome and Bike Setup.
2. **Practice capture** (s3: PRACTICE badge, `CAPTURE (NOT SAVED)`) after
   Set the Scene, first run only.
3. **Noise Floor prompt** (s8: "How precise is this number?" DO IT NOW /
   SKIP FOR NOW) after first save — the spec §8 self-test's front door.
4. **Comparison prompt** (s9: "One position is a measurement. Two is a
   comparison.") closing the first-run loop.

These are real scope (first-run state machine + the self-test itself), not a
styling pass — sequence them **after** Plans A–C land. Also from the
prototype: Welcome copy is "Be informed, don't guess." with CTA
`GET STARTED`; update `WelcomeView` copy when touching it (cheap, can ride
along with any onboarding task). The prompt-screen pattern (eyebrow / big
Barlow copy / mono sub) should land in `Design/Components.swift` as
`PromptScreen` when the first of these is built. NamePositionStep also uses
this pattern (34pt Barlow prompt over a dimmed 16%-opacity matte background —
fold into Plan B4.6's restyle).
