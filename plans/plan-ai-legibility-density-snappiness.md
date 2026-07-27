# Plan AI — Legibility, density and snappiness pass

**Status:** DRAFT — awaiting Kah's go-ahead.
**Origin:** Kah's UI review request, 2026-07-27, with on-device screenshots (positions
list, bikes, leaderboard, compare ×2, methodology ×2, live camera, detail ×2).
**Decisions already made by Kah (2026-07-27):**
1. Retune the colour tokens *and* raise the type floor (not colours alone).
2. Cut the copy roughly in half, keeping every defensible claim behind a disclosure.
3. Keep the motion beat, halve the wait.
4. Include camera HUD legibility, position-list usability, and the compare restructure.

**Non-goals for this pass** (queue separately): Dynamic Type / `ScaledMetric`
conversion, a full accessibility-label sweep, any change to the area maths, the matte,
`AnalysisEngine`, or the SwiftData schema. No new dependencies. No new screens.

**Scope note:** AI1–AI7 are the iOS app. AI9–AI11 cover the marketing site (`docs/`)
and are deliberately a *different, much smaller* shape of work — see the web diagnosis
below for why the app's prescriptions must not be copied over wholesale.

---

## Diagnosis (measured, not impressionistic)

**Contrast against `bg0` (#080808), WCAG 2.1:**

| token | hex | ratio | verdict |
|---|---|---|---|
| `fg` | #EEEEEE | 17.2:1 | fine |
| `fg2` | #999999 | 7.0:1 | fine |
| `acc` | #D9F020 | 15.7:1 | fine |
| `amb` | #E8A020 | 9.0:1 | fine |
| `fg3` | #777777 | **4.47:1** | fails AA for normal text |
| `fg4` | #555555 | **2.68:1** | fails everything |

`fg3` appears 72 times, `fg4` 19 times. `fg4` carries real prose today: the speed
helper on Compare, the `raw: … noise: …` line under a within-noise verdict, and the
entire `EmptyStateView` message.

**Type scale, counted across `ios/GetTucked`:** 85 instances at ≤11pt (63 × 11pt,
17 × 10pt, 4 × 9pt, 1 × 8pt). Space Mono at 10pt has roughly the optical size of
system text at 8.5pt, so the dimmest text is also the smallest.

**Camera HUD:** over live video, palette contrast is meaningless. Unprotected today:
`TIPS`, `OR CHOOSE FROM LIBRARY`, `SKIP`, the ✕, the `LevelLine` rail (`Palette.line`
#262626 — invisible on any bright scene), and the three `StatusPill`s (transparent
fill). The bike chip and 1×/2× chip already carry `bg0.opacity(0.72)`, which is why
they're the only readable elements in Kah's screenshot.

**Copy volume:** methodology is ~260 words of body copy at 10–11pt. Compare stacks a
34-word assumptions sentence, a % sentence, a default-speed warning, a 21-word speed
helper and up to four advisory lines — and the screenshot shows the worst case, where
the *same* ~40-word wheel advisory prints twice (once for A, once for B).

**Snappiness:** the work is already off-main (photo/mask decode, coverage arithmetic);
the lag is pure choreography. `RevealStep`'s primary CTA sits at `opacity(0)` for
**1.9s** and, being opacity-only, is invisible-but-tappable that whole time.
`ComparisonView`'s draw-in runs ~1.25s with the A/B chips rendering "off" until armed.

---

## AI1 — Colour token retune

`ios/GetTucked/Design/Theme.swift`, `Theme.Palette`:

```
fg   #EEEEEE  (unchanged, 17.2:1)
fg2  #999999 → #B0B0B0   9.2:1   secondary prose
fg3  #777777 → #8A8A8A   5.8:1   tertiary prose, labels — the floor for text
fg4  #555555 → #6A6A6A   3.7:1   NON-TEXT ONLY
```

Leave `bg0/bg1/bg2/line/line2/line3/acc/amb` alone.

Add a doc comment above the ramp stating the contract verbatim:

> Measured against `bg0`. Every token used for text clears 4.5:1. `fg4` is below that
> floor on purpose and must never carry text — it is for placeholder glyphs, disabled
> graphics and inactive strokes only.

**Then sweep every `Palette.fg4` call site** and apply that rule:

- Prose or a control label → `fg3` (or `fg2` if it is the only content on screen).
- Placeholder glyph / disabled graphic / inactive stroke → `fg4` stays.

Known sites and their verdicts:

| file | what | change |
|---|---|---|
| `ComparisonView.swift:1048` | speed helper sentence | → `fg3` |
| `ComparisonView.swift:1124` | `raw: … noise: …` | → `fg3` |
| `ComparisonView.swift:767` | `LayerToggleChip` off-state label | → `fg3` |
| `SharedViews.swift:202` | `EmptyStateView` message | → `fg2` |
| `PositionDetailView.swift:204` | `PACKING` label | → `fg3` |
| `AppNavigation.swift:235` | `IndexRow` ordinal | → `fg3` |
| `LiveCameraView.swift:244` | `SHOOTING ON` eyebrow | → `fg2` (see AI4) |
| `PositionListView.swift:229` | `···` placeholder | keep `fg4` |
| `PositionDetailView.swift:272` | `···` placeholder | keep `fg4` |
| `ComparisonView.swift:219` | `···` placeholder | keep `fg4` |
| `PositionListView.swift:269` | disabled checkbox stroke | keep (`line2`) |

DEBUG-only views (`MatteCheckView`, `PoseCheckView`) are out of scope — leave them.

## AI2 — Type floor

One rule, applied everywhere:

- **Prose (full sentences): 13pt minimum.**
- **Secondary prose / captions / assumption lines: 12pt minimum.**
- **Uppercase kerned micro-labels (eyebrows, chips, pill text): 11pt minimum.**
- Numbers, headings and hero type are unchanged.

Explicit bumps (this is the list; anything else found by grep follows the same rule):

`HowItWorksView.swift` — `MethodStep.lead` 11→13, `.detail` 11→13, `FactColumn`
items 11→13 and `tag` 9→11, `NoiseFloorNote` body 10→12 and tag 9→11,
`TimeEstimateSection` paragraphs 10→12, `FormulaHero` "Power = …" 11→12, the
"CdA: your frontal area…" line 10→12, the handoff link 11→12.

`ComparisonView.swift` — assumptions line 10→12, default-speed warning 11→12, speed
helper 10→12, `CrossBikeWarning` / `PoseDeltaAdvisory` / `AdvisoryLine` 11→12,
`raw:/noise:` 10→12.

`PositionDetailView.swift` — same-kit reminder 11→12, shoulder/wheel warnings 11→12.

`LiveCameraView.swift` — `TIPS` 11→12, library link 11→12, skip 11→12, chips 11→12.

`Components.swift` — `StatusPill` label 11→12.

`PositionListView.swift` — subtitle hint 11→12, row date 11→12.

`SetTheSceneView.swift` — apply the rule to its tip rows.

**Layout risk.** Bigger text needs room. Convert fixed `.frame(height:)` on
text-bearing containers to `.frame(minHeight:)`:
`Theme.Control.metricRowHeight` (50) and `listRowHeight` (60) call sites,
`DetailDisclosure`'s 40pt row, `SegmentedToggleBar`'s 40pt bar, `PositionPanel`'s
130pt. Do **not** touch the 300pt ghost-overlay container or any image frame — those
are picture boxes, not text boxes.

## AI3 — Cut the copy (methodology + compare)

Target: methodology body copy ~260 → ~130 words. Nothing defensible is deleted;
what leaves the surface goes behind a `DetailDisclosure`.

**`HowItWorksView.swift`**

- Step 01: drop `detail` entirely (it restates the lead). Lead unchanged.
- Step 02: keep lead; `detail` → `"Pixels become centimetres. No depth sensor needed."`
- Step 03: unchanged, parenthetical and all — it is the payoff line.
- `TimeEstimateSection`: keep paragraph 1 (how the estimate is derived) visible. Move
  paragraph 2 (fixed assumptions) and paragraph 3 (slower riders gain more minutes)
  into a `DetailDisclosure(label: "Assumptions")` directly beneath it, verbatim.
- `NoiseFloorNote`: keep the ±3% paragraph visible (it is actionable). Move the
  handlebar-ruler-forward-of-torso paragraph into that same Assumptions disclosure,
  verbatim.
- `FormulaHero` legend: six rows × 44pt = 264pt of vertical. Re-lay as a two-column
  grid (three rows of two glyph/meaning pairs). Each cell keeps a ≥44pt tap target via
  `contentShape` — do not shrink the tap target, only the stack height.

**`ComparisonView.swift`**

- Speed helper → `"Flat, calm road speed. Not your ridden average."`
- `outputCard` assumptions line: shorten the always-attached inline sentence to
  `"Estimate. Equal effort, equal drag coefficient, 80 kg rider+bike+kit, flat, no wind."`
  and move the rear-bag/wake sentence into the existing
  `DetailDisclosure("Measurement detail")` at the bottom of the screen, verbatim.
  ⚠️ **Flagged for Kah's explicit approval:** Plan S2 §5 called the assumptions line
  "always attached, never optional". This keeps a shortened assumptions line attached
  and relocates only the wake caveat. Approving this plan approves that relocation.
- **De-duplicate the A/B advisories.** Add a pure, testable helper —
  `AnalysisMath.mergedAdvisories(_ sided: [(side: String, text: String)]) -> [String]` —
  that emits `"A and B: <text>"` for an identical string on both sides and
  `"A: <text>"` / `"B: <text>"` otherwise, preserving input order. Rewrite
  `advisoryLines` to build `(side, text)` pairs and pass them through it. Tests:
  identical pair merges, differing pair does not, single side unchanged, empty input.

## AI4 — Camera HUD legibility (no solid backgrounds)

`ios/GetTucked/Capture/LiveCameraView.swift`, plus `Components.swift` for `StatusPill`.

1. **Scrims, not solid fills.** Add a private `CameraScrim` view and place two
   instances in the `ZStack` between `CameraPreviewLayer` and the HUD, both
   `.allowsHitTesting(false)` and `.ignoresSafeArea()`:
   - top: `LinearGradient(bg0.opacity(0.75) → bg0.opacity(0))`, height 150
   - bottom: the mirror, height 240
   These are gradients; the feed stays visible through them. This is the answer to
   "readable without a solid background."
2. **Shadow on every bare glyph over the feed.** Add a view modifier next to the other
   shared helpers:
   `func hudText() -> some View { shadow(color: .black.opacity(0.6), radius: 2, y: 1) }`
   Apply to `TIPS`, the library link, the skip link, the ✕, `LevelLine`, `StatusPill`,
   `BikeChip`, `StepLabelChip`, `GhostToggleButton`, `ZoomToggleChip`.
3. **Colour floor over the feed:** bare text over live video uses `fg` or `fg2`, never
   `fg3`. `TIPS` fg3→fg2, library link fg3→fg2, skip fg3→fg2, `SHOOTING ON` fg4→fg2.
4. **`LevelLine` rail:** `Palette.line` → `Color.white.opacity(0.35)` plus `hudText()`.
   The indicator tick keeps `acc`/`amb`.
5. **`StatusPill`:** add `.background(Theme.Palette.bg0.opacity(0.72))` behind the pill
   content, matching the chip treatment already in use. All three call sites are in
   `LiveCameraView` (verified), so this needs no opt-in flag.
6. **Say why the shutter is blocked.** Today the button just greys out. Add a new pure
   helper — `CaptureGate.blockedReason(levelOK: Bool, perpOK: Bool) -> String?`
   returning `nil` when both pass, `"Hold the phone level"`, `"Tilt the phone upright"`,
   or `"Hold the phone level and upright"` — and render it in `amb`, 12pt, `hudText()`,
   directly under `CaptureButton` in `controlStack`. Tests cover all four cases.

## AI5 — Snappiness

**`CaptureView.swift` / `RevealStep`:**

- **Never gate a live control on opacity alone.** Delete `buttonsVisible` and render
  `RETAKE` / `NAME POSITION` visible and tappable from t=0. (Today they are invisible
  but still hit-testable for 1.9s — a tap in that window fires unseen.)
- Retime: `labelVisible` delay 0.5 → 0.15; `uncertaintyVisible` 1.5 → 0.55;
  `revealRowsAfterHold` sleep 1.6s → 0.6s; `RollingNumberText` delay 0.7 → 0.35 and
  duration 0.8 → 0.6.
- **Tap anywhere to skip.** `cancelCeremony()` exists but is reachable only through the
  PHOTO/MASK/BONES binding. Add a `.contentShape(Rectangle()).onTapGesture { cancelCeremony() }`
  on the photo container so a tap on the image snaps the whole sequence to its end
  state. Do not attach it to the scroll content at large (it would swallow row taps).

**`Theme.swift`:** `Motion.sweep` 0.90 → 0.55. This is shared with the compare draw-in,
which wants the same thing.

**`ComparisonView.swift`:**

- B's draw-in delay 0.35 → 0.2 (total ≈ 0.75s with the shorter sweep).
- A/B chips: change `isOn: showLayerA && layerAArmed` → `isOn: showLayerA` (same for B)
  so the chips read their true state from the first frame. Keep `layerAArmed`/
  `layerBArmed` for whatever else genuinely depends on the draw having finished.

Leave `AnalysingView`'s scan loop alone — it covers real Vision work.

## AI6 — Position list usability

`ios/GetTucked/Views/PositionListView.swift`.

1. **Show the bike on each row.** `PositionRow`'s secondary line becomes
   `"<date> · <bike.nickname>"` at 12pt `fg3`, `lineLimit(1)`, falling back to the bare
   date when `position.bike` is nil. `LeaderboardView.RankRow` already shows the bike;
   this brings the list in line.
2. **Sort control.** Add a `SegmentedToggleBar(labels: ["NEWEST", "SMALLEST"])` beneath
   the hint row (above the first `SectionDivider`). Persist the choice in
   `@AppStorage("positionListSort")`.
   - `newest` = `capturedAt` descending (today's behaviour, the default).
   - `smallest` = `frontalAreaCm2` ascending, with metric-less positions last, ties
     broken by `capturedAt` descending so the order is stable.
   - Implement as a pure `PositionSort` helper taking `[(id, capturedAt, areaCm2?)]`-
     shaped input so it is testable without SwiftData, and apply it in a computed
     property. Do **not** try to vary the `@Query` sort.
   - Tests: both orders, metric-less positions land last, tie-break is stable.

## AI7 — Compare restructure

The delta hero (`-14.6%`) currently sits *below* the TIME IMPACT inputs, so the user
scrolls past a distance selector, a speed field and a slider to reach the verdict.

Fix the scroll problem without inverting Plan S2's deliberate tiering (TIME IMPACT
stays tier 1, above the delta hero):

- In `TimeImpactSection`, move `inputs` (the distance selector, `SpeedControl` and the
  helper line) inside a `DetailDisclosure(label: "Change speed & distance")` placed
  directly under `outputCard`. Default state: **collapsed when `effortInputsConfirmed`
  is true, expanded when it is false**, so a first-timer still meets the form and a
  returning user goes straight from the answer to the delta hero.
- Drop the `NavHeader` subtitle `"Same kit, same position as the reference shot?"`. It
  asks a question the screen already answers below (`PoseDeltaAdvisory`), and it costs
  two lines at the top of every comparison.
- Apply AI3's advisory de-duplication here.

---

# The marketing site (`docs/`)

## Web diagnosis — it does not share the app's problems

Audited `docs/styles.css` (641 lines), `docs/site.js` (159), `index.html` (311),
`methodology.html` (366).

**Contrast against the site's `--bg0` #121417** (lighter than the app's #080808):

| token | hex | ratio | verdict |
|---|---|---|---|
| `--fg` | #E8E6E1 | 14.6:1 | fine |
| `--fg2` | #A6A29B | 7.2:1 | fine |
| `--fg3` | #8A867F | 5.0:1 | fine |
| `--acc` | #D9F020 | 14.3:1 | fine |
| `--amb` | #E8A020 | 8.2:1 | fine |
| `--fg4` | #5E5A54 | **2.66:1** | fails |

So the site has **one** contrast bug, not six, and `--fg3` — the app's worst offender —
already passes here because the site's canvas is lighter.

**The site has no type-floor problem either.** Body copy is system sans at 18px/1.62
with a 66ch measure (`--body`, not `--mono`). Mono is correctly reserved for numerals,
labels and code. The only type ≤11px is `.tag-est` (10px, black on acid — a badge, very
high contrast) and `.readout .tag` / `.shot-frame span` (11px uppercase kerned labels).
**No web type-size changes are needed. Do not apply AI2 to the site.**

**The site has no over-explaining problem.** `methodology.html` is 2,014 words and
`index.html` 606 — but that is the correct answer for this surface. The app's
methodology is 260 words of 10pt mono on a 6" screen, read mid-task by someone who
already bought in; the web methodology is long-form editorial read pre-purchase by
someone deciding whether to trust the number at all, and it already uses seven
`<details>` disclosures for progressive disclosure. **Do not apply AI3 to the site.**

## AI9 — Retire `--fg4` for text on the site

`docs/styles.css`. `--fg4` #5E5A54 is 2.66:1 and appears three times, two of them on
real content:

| line | selector | what | change |
|---|---|---|---|
| 459 | `details .figure-note` | 12px note inside a disclosure | → `var(--fg3)` |
| 494 | `.cites .lang` | 12px language tag on a citation | → `var(--fg3)` |
| 301 | `.shot-frame span` | "screenshot" placeholder | keep `--fg4` |

Do **not** invent a new `--fg4` hex: a value clearing 4.5:1 on this canvas lands at
~#857F76, which is visually indistinguishable from `--fg3` #8A867F and would collapse
the ramp. Instead keep `--fg4` as the placeholder-only token and note that in the CSS.

Also update the stylesheet header comment (line 3): it currently says the tokens
"mirror the app's Theme.swift". After AI1 the two ramps hold *equal contrast on
different canvases* rather than equal hexes. Reword so nobody later "fixes" the site
hexes to match the app's and silently drops the site to failing ratios.

## AI10 — Claim-consistency audit (not a rewrite)

AI3 shortens app copy. Anything it touches that is also asserted on the web must stay
in agreement. Verify, and reconcile in the site's favour where the app dropped detail:

- The ±3% noise floor, stated in both `HowItWorksView.NoiseFloorNote` and
  `methodology.html`.
- The fixed assumptions the app's shortened `outputCard` line now carries (Cd 0.7,
  80 kg rider+bike+kit, Crr 0.005, sea-level air, flat, no wind) against
  `methodology.html` and `marketing/website-copy.md`.
- The rear-bag/wake caveat, which AI3 moves behind a disclosure in-app — confirm the
  site still states it somewhere visible, since the web is the place with room for it.
- **`docs/site.js` constants vs `ios/GetTucked/Analysis/EffortModel.swift`.** site.js
  says "keep every constant below literally identical to that file". Verified correct
  today (`CRR 0.005`, `RHO 1.225`, `G 9.81`, `CD 0.7`, `MASS_KG 80` all match). Re-check
  after this plan lands and leave a comment in both files pointing at each other.

## AI11 — The entrance animation is a single point of failure

`docs/index.html:18` sets `documentElement.classList.add('js')` inline in `<head>`.
`docs/styles.css:379` then hides *every direct child* of `section.block`, `.doc >
section`, `.floor`, `.get-list`, `.shots`, `.faq`, `ul.plain` and `.cites` at
`opacity:0`, and the **only** rule that brings them back requires the `.in` class,
which is added by `site.js`'s IntersectionObserver at line 153 — the very last thing in
the file.

So if `site.js` 404s, fails to parse, or throws anywhere in the hero (lines 10–46),
so-what calculator (55–108) or formula-hover (115–128) blocks, execution never reaches
the observer and:

- `index.html` renders **only** the hero and top bar. All six `section.block`s —
  including the FAQ, the proof strip and the download CTA — stay invisible.
- `methodology.html` renders **only** its title block. All seven sections stay invisible.

Users with `prefers-reduced-motion` are immune (styles.css:631 and site.js:148 both
short-circuit), so this would also be easy to miss in testing.

Fix, smallest first:

1. Wrap the hero, so-what and formula blocks each in their own `try { } catch { }` so a
   failure in any one cannot prevent the entrance observer from being wired.
2. Add an unconditional failsafe after the observer is attached:
   `setTimeout(function(){ targets.forEach(function(e){ e.classList.add('in'); }); }, 2000);`
   Content that already faded in is unaffected (the class is idempotent); content that
   never got observed becomes visible instead of staying blank.
3. Verify in a browser with `site.js` blocked, at default motion settings, that both
   pages render complete.

## AI12 — Sequencing note: screenshots come last

`docs/index.html:158` still carries `<!-- PLACEHOLDER: replace each .shot-frame with
<img …> before launch -->` and three `<span>screenshot</span>` stand-ins. Real captures
are still outstanding (noted in the launch-marketing memory).

**Do not shoot them before AI1–AI7 land.** This plan changes the colour ramp, the type
sizes, the camera HUD and the compare layout — screenshots taken now would be obsolete
within the same plan. Capture them from the finished build as the closing step.

## Web verification

- Browser check at 1440px, 768px and 375px on both pages: no horizontal scroll, FAQ and
  proof strip reflow correctly.
- Both pages complete with `site.js` blocked (AI11 item 3).
- Both pages complete with `prefers-reduced-motion: reduce`.
- Recompute the contrast of `--fg`, `--fg2`, `--fg3`, `--acc`, `--amb` against `--bg0`
  after any token edit; all must stay ≥ 4.5:1.
- The site is a static dark-launch page in `docs/` — no build step, no tests. Visual
  confirmation in the browser is the whole verification surface, so it must actually be
  done, not assumed.

---

## Verification (app)

- `xcodegen generate` is not needed (no files added to the target… **except** the new
  `CaptureGate` / `PositionSort` helpers — if they land in new files, regenerate;
  prefer adding them to existing files, `AnalysisMath.swift` and a new small section of
  `PositionListView.swift`, to avoid it).
- **Full test suite green.** Baseline is 308 tests; this plan adds roughly 15 (merged
  advisories, blocked reason, position sort, contrast).
- **New `ThemeContrastTests`:** compute the WCAG ratio of `fg`, `fg2`, `fg3`, `acc` and
  `amb` against `bg0` and assert each ≥ 4.5:1; assert `fg4` is documented-and-below and
  is *not* expected to pass. Keep the luminance maths in the test file so no production
  code exists purely for tests. This pins the token contract against silent regression.
- **On-device pass by Kah** (the parts no test can cover): the camera HUD in bright
  daylight and against a pale indoor wall; the reveal timing after a real capture; the
  compare scroll from panels to verdict without passing a form; the methodology screen
  read end to end.

## Suggested execution order for sub-agents

**Wave 1 — one agent, solo (touches every file):** AI1 + AI2. Nothing else can run
alongside it without constant conflicts.

**Wave 2 — four agents in parallel, disjoint files:**

| agent | items | files |
|---|---|---|
| A | AI3 (methodology half) | `HowItWorksView.swift` |
| B | AI3 (compare half) + AI7 + AI5 (compare) | `ComparisonView.swift`, `AnalysisMath.swift` |
| C | AI4 | `LiveCameraView.swift`, `Components.swift` |
| D | AI5 (reveal) + AI6 | `CaptureView.swift`, `PositionListView.swift`, `Theme.swift` (Motion.sweep) |
| E | AI9 + AI11 | `docs/styles.css`, `docs/site.js`, `docs/index.html` |

Agent D owns the one-line `Motion.sweep` change; agent B must not touch `Theme.swift`.
Agent E touches no Swift and can start immediately, in parallel with Wave 1 — the web
work shares no files with the app.

**Wave 3 — after everything lands:** AI10 (claim-consistency audit, needs the final app
copy) then AI12 (screenshots, needs the final app UI). Both are Kah's calls to make, not
a coder's.
