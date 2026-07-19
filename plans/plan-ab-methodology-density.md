# Plan AB — Methodology density: spacing hierarchy, one content column, acid as structure, a legible formula

Status: planned 2026-07-19, from Kah's design review of the METHODOLOGY screen
([`Views/HowItWorksView.swift`](../ios/GetTucked/Views/HowItWorksView.swift)) and
the mirrored web methodology ([`docs/methodology.html`](../docs/methodology.html),
[`docs/index.html`](../docs/index.html), [`docs/styles.css`](../docs/styles.css)).

Both surfaces read as too **dense**. Kah wants: more generous spacing, more
generous (but disciplined) acid-yellow, more light greys, **consistent padding**
on the iOS screen, the formula made **bigger / more legible / graphically
interesting / possibly interactive**, and the web headings to stop stacking
raggedly on wide screens. He also wants to try moving **THE NOISE FLOOR last**.

This is a design plan — no product files change until Kah approves a direction.
Where a task has a fork, the fork is called out with a recommendation.

## Diagnosis — one disease, both surfaces

Density here is not too much content; it's **too little contrast between levels**.
One grey and one gap are each doing three jobs:

- **One spacing value** carries paragraph gaps, section gaps, and major beats.
  iOS uses `lg = 24` for nearly all of it (the scale has a hole between `lg 24`
  and `xl 40`); web uses `44px`. When a section break and a paragraph break are
  the same size, the eye can't chunk the page.
- **One grey** carries almost all text — iOS `fg3 #777` / `fg2 #999`, web
  `fg2 #A6A29B`. No tonal banding, so each section is a flat slab.
- **Acid is a sprinkle, not structure** — only 8–14px marks (numerals, 8px
  bullet squares, summary labels). The strongest brand asset is barely on screen.
- **The dividers don't divide** — web `line2 #20242A` sits ~8 RGB off the
  `#121417` canvas (invisible); iOS hairline rails visually *tie* steps together
  rather than separating them.

## Root causes (verified in code)

**iOS — competing left edges** (the "padding looks off"). Confirmed values from
[`Theme.swift`](../ios/GetTucked/Design/Theme.swift):
`screenMargin 16`, `headerTitleInset 52`, `iconTapTarget 44`, `xs 4 / sm 8 /
md 16 / lg 24 / xl 40`. Down the page the reading edge is:

| Element | Left edge | Why |
|---|---|---|
| Header title/subtitle | **52** | `headerTitleInset`, clears the floating BackButton |
| Step *circles* | 16 | `MethodStep` `.padding(.horizontal, screenMargin)` |
| Step *titles + body* | **62** | 16 + circle 30 + `md 16` gap |
| Section header, IT IS/ISN'T, both cards, hero | **16** | `screenMargin` |
| `SectionDivider` | **0** | full-bleed |

No single content column. The jump from step text (62) back to the section
header (16) is the most jarring, and the header (52) agrees with neither.

**iOS — flat rhythm.** The page body is `VStack(spacing: 0)` where every gap is a
hand-placed `.padding(.top, lg)` (24). Section gaps are all 24; only the closing
hero gets 40. Inside both callout cards every element — tag, formula, each
paragraph — is separated by the *same* `sm 8`.

**iOS — monotone + duplicate cards.** Section header `WHAT THE NUMBER IS` is
`fg3 #777` — the *dimmest* thing on screen when it should be the loudest label.
[`NoiseFloorNote`](../ios/GetTucked/Views/HowItWorksView.swift) and
[`TimeEstimateNote`](../ios/GetTucked/Views/HowItWorksView.swift) are near-identical
`bg1` boxes (same fill, same `line` border, same `md 16` padding), stacking
back-to-back so they blur into one region.

**Web — headings wrap raggedly (two mechanisms).**
- Landing `h2`s in [`index.html`](../docs/index.html) carry hard-coded `<br>`s
  (`Point, tap,<br>compare.` etc.). On wide screens the font pins at its 60px cap
  and the `<br>`s force a fixed ragged 3-line staircase at `line-height:.95` that
  never relaxes.
- `.doc h2` in [`styles.css`](../docs/styles.css) wraps **greedily** (no
  `text-wrap:balance`), the column is locked at 760px, and the inline
  `<span class="num-label">` eats the first line → lopsided two-line splits.

**Web — density + no light surface.** `.doc section` padding `44px`; `.doc p`
margin `16px`; nearly all copy is one grey `fg2 #A6A29B`; `:root` has **no light
surface token** — the only fills (`bg1 #16191D`, `bg2 #1C2025`) are ~4 RGB off
the canvas, so "cards" don't register as panels. Acid appears only at 8–14px; the
one acid section-rule only animates in on scroll (absent on load / JS-off).

---

## AB1 — Spacing hierarchy: a 3-tier scale (both surfaces)

Make the section gap **~2.5–3× the paragraph gap** so the page chunks.

- **iOS:** fill the scale hole by **reusing `xl 40`** for *between-section* breaks
  (already defined, used only once today) — **no new token**; keep `24` for
  within-section grouping, `md 16` for paragraphs (ratio 40:16 ≈ 2.5:1, the target).
  Refactor the page body off `VStack(spacing: 0)` + per-section `.padding(.top)`
  onto a parent stack that owns one rhythm, so gaps can't drift section-to-section.
- **Web:** `.doc section` `44px → 64px` (not 80 — 64 also **matches the landing's
  `section.block` 64px**, unifying the two web pages); `.doc p` margin `16 → 22`;
  card padding `16 → 24`. Ratio 64:22 ≈ 2.9:1.

## AB2 — One content column on iOS (the padding fix)

Establish a **single left edge** for all reading content and stop the step
numbers pushing text rightward. Recommended approach — and it doubles as AB4's
"bigger acid": **the step number becomes a large acid eyebrow above its title**,
so title + body sit flush in the `screenMargin` (16) column with everything else.

- All body content — steps, section header, lists, cards, hero — reads at one
  edge (16).
- `MethodStep` restructures: `01` as a large acid mono eyebrow, `ISOLATE` heading
  beneath it, body beneath that — all left-aligned at 16. This retires the 62pt
  indent.
- **Rail: dropped (Kah, 2026-07-19 — "eyebrows only").** No connecting rail and no
  left-tick; the acid `01 / 02 / 03` eyebrows carry the sequence alone. Most
  spacious option, and it removes the hairline that was tying the three steps into
  one cramped column.
- **Header decision (flag for Kah):** the header's 52pt inset is structurally
  justified — the floating BackButton occupies the top-left. Options: (a) leave it
  as the one deliberate exception (a button sits to its left, which reads as
  intentional); or (b) move BackButton to its own row so the title drops to 16 and
  agrees with the body — cleaner but touches every screen using `NavHeader`, so
  out of scope unless we want a nav pass. **Recommend (a)** for this plan.

> **Coherence bonus:** "number as an eyebrow above the heading" is *also* the web
> heading-wrap fix (AB7). Adopting it on both surfaces fixes iOS padding, fixes web
> wrapping, delivers bigger acid numbers, and makes the two surfaces siblings — one
> move, four wins.

## AB3 — A light-grey / lifted tier (the "more light greys")

Not white cards — a tonal lift so callouts sit *on* the page, plus brighter lead
lines so each section opens legibly then settles to grey.

- **New lifted surface:** iOS callout cards `bg1 #101010 → bg2 #161616`
  (**not `#1A1A1A` — that collides with the `line2` divider token**), border
  `line #262626 → #333`. Web: add `--panel:#1E222A` and use it for `details` /
  callouts; brighten dividers `--line2 #20242A → #2E333B` so sections actually
  separate.
- **Bright lead lines:** promote the iOS section header and the first sentence of
  each step to `fg`. On web, promote each section's lead sentence to `--fg`.

## AB4 — Acid as structure, not scatter (the "more acid pops")

Fewer, bigger, deliberate — scatter is what reads as under-designed. Concentrate
into ~2–3 pops per screen:

1. **The numbered spine** (via AB2) — big acid `01/02/03` eyebrows (no rail/tick).
2. **The formula as hero** (AB6) — the single most technically-reassuring element;
   the aero term goes acid, rolling stays grey (the color-split teaches the thesis).
3. **Persistent acid section-rule on web** — make the existing top-rule a 2–3px
   persistent tick on section tops (today it only animates in on scroll).
4. Keep the closing `don't guess.` acid.

## AB5 — Reorder + differentiate the two cards

**New order:** Steps → IT IS / IT ISN'T (scope) → **THE TIME ESTIMATE** (the
payoff/method, with the formula hero) → **THE NOISE FLOOR** (the honest caveat) →
*Be informed, don't guess.*

- Rationale: method → payoff → humility → CTA. Ending on the ±3% "re-shoot to
  confirm a real change" note lands the trustworthy tone and hands off naturally
  to the CTA. Color rhythm becomes acid payoff → amber caution → acid CTA.
- **Differentiate by role, reusing the existing acid/amber split** (IT IS = acid,
  IT ISN'T = amber):
  - **THE TIME ESTIMATE = acid.** Promote from a bordered card to a full section
    with the formula hero (AB6) — expansive, teaching.
  - **THE NOISE FLOOR = amber.** Keep it a compact amber-cued caveat note (tag or
    left rule), tight by design. The contrast of "big teaching section" vs "tight
    caveat" is itself the differentiation.
- Web: **don't force the same section order** — `methodology.html` is a long-form
  doc (measure / scale / don't-do / floor / limitations / citations) with no formula
  or time section, and the payoff/time story lives on the **landing**. Align the
  **semantics and the formula treatment**, not the section order.

## AB6 — The formula: legible, graphic, interactive

`P = v · (½ · ρ · CdA · v² + Crr · m · g)` is currently 11pt bold mono, one line,
buried in an 8pt stack. Three tiers:

**1. Legibility (both).** Give it a dedicated panel with real air above/below,
large display size (iOS ~24–28pt; web `clamp(...)`), monospace, generous leading.

**2. Graphic structure (both).** Teach the one insight the app is built on — *you
only change the aero half.*
- A plain-language bridge line above the symbols:
  **`Power = speed × (air drag + rolling drag)`**.
- Color-split the two physical terms: aero `½·ρ·CdA·v²` in **acid** (the part the
  app changes), rolling `Crr·m·g` in **dim grey** (fixed).
- Annotate `CdA` with an acid bracket/underline: *"your frontal area — the one
  thing you change."* Of all these symbols, one is what the app measures; pointing
  to it is both the hook and the pedagogy.
- A compact **decoder legend** below mapping each glyph to plain words
  (`v` your speed, `ρ` air density, `CdA` frontal area × drag, `Crr` rolling
  resistance, `m` you + bike + kit, `g` gravity).

**3. Interactivity — surface-specific. NB: the web slider already exists.**
The landing already ships a live area→time slider — `.sowhat`
([`index.html:186`](../docs/index.html), logic in [`site.js:55`](../docs/site.js)):
`<input type=range>` → `~3–17 min faster over 200 km`, labelled *Illustrative*, on
the same `EffortModel` constants. So there is nothing to *build* on web — and a
second slider with different assumptions would break spec §3.
- **Web landing — upgrade the existing `.sowhat` slider** into the teaching moment:
  expose the formula + the fixed assumptions (`Cd 0.7`, `80 kg`, `Crr 0.005`,
  sea-level) on it, so the physics is explained where the payoff is felt.
- **Web methodology page — static** color-split teaching graphic (tier 2) that
  **links** to the landing slider. One interactive per site.
- **iOS:** the *real* interactive already lives in the Comparison flow (real
  photos → real time impact). Keep the formula a teaching graphic with
  **tap-to-decode** symbols (tap `ρ` → its plain meaning; **≥44pt tap targets** per
  HIG) and a link *"see it on your own positions →"* into Comparison.

**Decided (Kah, 2026-07-19, after design-lead review):** upgrade the existing
landing slider (do **not** build a second one); the methodology formula is static
and links to it; iOS keeps tap-to-decode + the Comparison link.

## AB7 — Web heading wrap fix

- **One CSS edit covers both heading systems.** `.doc h2` declares no
  `line-height`/`text-wrap`, so it inherits from the base `h2` rule via cascade — add
  `text-wrap: balance` and lift `line-height .95 → ~1.02` on the **base `h2` rule**
  ([`styles.css:191`](../docs/styles.css)) and both landing and doc headings get it.
  No second rule needed. (Eyeball the leading on the 60px landing headlines — the
  bump loosens single-line ones slightly; 1.0–1.05 is the band.)
- **`text-wrap: balance` does nothing to a hard `<br>`.** The landing `h2`s
  ([`index.html:156/179/209`](../docs/index.html)) carry hard `<br>`s that force the
  ragged staircase — those must be **removed** for balance to take effect. This HTML
  change is what actually fixes the landing; the CSS alone only helps the
  greedy-wrapping doc headings. Only reintroduce a controlled `<br>` (behind a
  `max-width` query) for the one or two headings that still look wrong after
  balancing — don't gate them back by default.
- **`.doc h2`:** also pull `.num-label` **out of the heading flow** into an eyebrow
  line above (matches AB2's eyebrow treatment), so it stops eating the first line and
  skewing the split. `aria-hidden` the ordinal number once it's separated.

## AB8 — Coherence decision

The two surfaces diverge on the **ground itself** — iOS `#080808` (pure black) vs
web `#121417` (lifted blue-grey) — and on their grey ramps. Fine if intentional
(web reads a touch more editorial). Note **acid `#D9F020` and amber `#E8A020` are
already byte-identical on both surfaces** — the brand signal is already unified; only
the greys/ground differ. Decision for Kah: align the ramps for true sibling feel, or
keep the web lift but align the **acid/amber semantic roles and the space ratios**
(these drive "one system" more than exact hex). Recommend the latter — cheaper, and
it's what the eye reads as coherent. **Cheaper still, and missed first time round:
unify the two _web_ pages** — take `methodology.html`'s `.doc section` from 44px to
the landing's 64px (AB1).

## AB9 — Copy pass (from stop-slop)

The product copy is strong, not slop, with one systemic tic: the **"X, not Y"
negation** recurs 4+ times across both surfaces ("measured, not guessed" / "Felt,
not just measured" / "don't guess" / "indistinguishable, not '1.8%'"). Any one is
on-brand; the repetition reads as a formula — **vary one or two**. Also drop the
em-dash in the iOS `WHAT THE NUMBER IS — AND ISN'T` header (keep the is/isn't frame —
it's load-bearing positioning). Keep `Power = speed × (air drag + rolling drag)` —
it's the strongest single addition in the plan.

---

# Part 2 — Analysis & comparison features (added 2026-07-19)

Four feature additions from Kah, distinct from the Part 1 design pass — these touch
[`ComparisonView.swift`](../ios/GetTucked/Views/ComparisonView.swift),
[`PositionDetailView.swift`](../ios/GetTucked/Views/PositionDetailView.swift) and
[`EffortModel.swift`](../ios/GetTucked/Analysis/EffortModel.swift). All forks below
were resolved with Kah 2026-07-19.

## AB10 — Speed control: slider + text input, much wider hit zone

The comparison so-what speed is today a type-in `MonoField` only
([`ComparisonView.swift:922`](../ios/GetTucked/Views/ComparisonView.swift)).

- Add a slider **alongside** the text field, both bound to the same value: range
  10–60 km/h (matching the existing validation), step 1.
- The field keeps commit-on-blur (house convention for typed numerics); the slider
  updates the displayed band **live during drag** and persists to
  `effortSpeedKmh` on release. Either control counts as a commit (clears the
  "Using a default speed" note / `hasCommittedSpeed`).
- **Hit zone:** ≥44pt-tall drag target on a full-width track — the ask is a LOT
  wider than a stock thumb, so pad the gesture area, not just the visuals.

## AB11 — Swipe between the photo-mode tabs (detail + comparison)

One gesture, one meaning on both screens: **horizontal swipe on the photo area
cycles the photo-mode toggle** — never the A/B sides.

- **Detail:** cycles the PHOTO/MASK/BONES `SegmentedToggleBar`
  ([`PositionDetailView.swift:142`](../ios/GetTucked/Views/PositionDetailView.swift)),
  for whichever photo (frontal or side-on) is showing. Cycle only the segments
  actually **available** — BONES is absent pre-Plan-O, MASK absent when the
  matte failed — exactly the set the toggle bar shows.
- **Comparison (added 2026-07-19):** the same swipe cycles PHOTO/OUTLINE
  ([`ComparisonView.swift:165`](../ios/GetTucked/Views/ComparisonView.swift)).
  A/B switching keeps its existing control — swipe must not touch it, so the
  gesture means "change lens" everywhere.
- **Swipe registers only at 1× zoom.** Both screens' photos are pinch-zoomable
  (detail via Plan AA; comparison via `.pinchZoomable`,
  [`ComparisonView.swift:587`](../ios/GetTucked/Views/ComparisonView.swift)) —
  once zoomed, horizontal drag must keep panning. No wraparound — swiping past
  the last tab does nothing, like iOS paging.
- The toggle bars **stay visible** — swipe is an accelerant, not a replacement
  (explicit, discoverable controls stay).
- Switching tabs by swipe must not retrigger either screen's once-per-visit
  draw-on/ceremony animation any differently than tapping does (R1.4 already
  snaps the comparison ceremony to done on gesture — keep that behavior).

## AB12 — Solo "so what" on the detail screen: standalone watts

**Decision: no baseline, no fake delta** — a lone position shows the *cost* of
its frontal area, not an "impact" (spec §3: a solo time-over-distance delta would
need an invented reference).

- New row in the detail metrics area (near
  [`MetricsSection`](../ios/GetTucked/Views/PositionDetailView.swift) /
  `DetailDisclosure`): the implied power to hold the rider's flat-road speed in
  this position — `EffortModel.impliedPowerW` with CdA from this position's area,
  `assumedMassKg` (80), and the same persisted `effortSpeedKmh` the comparison
  uses (default 30).
- Copy must carry the assumptions, same register as the comparison band:
  "Holding an assumed 30 km/h in this position takes **~190 W**" — "assumed"
  drops once the rider has committed a speed anywhere.
- Round honestly (~5 W steps, `~` prefix) — the ±3% area noise floor puts fake
  precision in single-watt figures.

## AB13 — Comparison % callout: same effort, % faster

**Decision: % speed at the same power, at the rider's chosen speed** (not %
power, not a fixed showcase 50 km/h — the number must agree with the time band
beside it).

- Derivation, all existing math: `power = impliedPowerW(speed, cdaA)` →
  `speedB = speedAtPowerMS(power, cdaB)` → `pct = (speedB − speedA) / speedA`.
- Copy: "Same effort at 30 km/h: position B is **~1.9% faster**." Winner and
  sign must always agree with the existing minutes band (same inputs guarantee
  it; a test should pin it).
- Run the % through the same low/high area bounds as the time band and show a
  range (or `~`) when the spread warrants — never a false three-significant-digit
  percentage.
- Placement: a second line inside the existing so-what block, under the minutes
  sentence.

---

## Sequencing

1. **AB7** (web headings) — fastest, most visible; `text-wrap: balance` +
   de-inline the num-label.
2. **AB1 + AB3** — the 3-tier scale + lifted surface/bright leads on both; unlocks
   everything else.
3. **AB2** — iOS one-column + acid eyebrows (lands the padding fix and AB4's
   spine together).
4. **AB6** — formula hero (biggest single content win).
5. **AB5** — reorder + differentiate the two cards.
6. **AB8** — coherence pass.

Part 2 (independent of Part 1, can land in any order relative to it):
AB13 → AB12 (both are small `EffortModel`-reuse features, % first since it
completes the comparison story) → AB10 → AB11 (gesture work last; it must be
tested against Plan AA zoom on device).

## Open decisions for Kah

- **AB2:** header inset — leave at 52 (recommend) or do a nav pass to drop it to 16?
- **AB8:** unify the grounds, or keep web's lift and align only roles + ratios (recommend the latter).

### Resolved
- **AB2 rail** → eyebrows only, no rail/tick (2026-07-19).
- **AB6 interactivity** → upgrade the existing landing slider (don't build a second); methodology formula static + linked; iOS tap-to-decode + Comparison link (2026-07-19, after design-lead review).

### Corrections from the design-lead review (2026-07-19, verified against code)
- Web slider already ships (`.sowhat`) → AB6 reframed to "upgrade," not "build."
- Web `.doc section` 44→**64** (not 80), matching the landing → also unifies the two web pages (AB1/AB8).
- iOS section gap **reuses `xl 40`**, no new `xxl` token (AB1).
- iOS lifted surface `bg2 #161616`, **not `#1A1A1A`** (collides with `line2`) (AB3).
- AB7: one base-`h2` edit covers both via cascade; `text-wrap: balance` needs the hard `<br>`s removed to help the landing.
- Copy: vary the repeated "X, not Y" negations; drop the em-dash in the IS/ISN'T header (AB9).
