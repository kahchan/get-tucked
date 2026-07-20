# Plan AC — Teaching legibility & discoverable controls

Status: planned 2026-07-19, from Kah's review of the landing so-what slider, the
iOS methodology formula legend, and the single-analysis solo-watts row (all shipped
under [Plan AB](plan-ab-methodology-density.md)). Design direction from two
design-lead passes; all forks resolved with Kah 2026-07-19. **No product files
change until Kah approves this plan.**

Three items, one governing rule.

## Governing rule — contrast first, never a near-invisible grey for words

Every item here traces to the same disease AB left behind: **running copy set in the
dimmest grey token, which fails legibility on a near-black panel regardless of size.**

- **Web `--fg4` (`#5E5A54`)** ≈ **2.6:1** on the slider panel `--bg1 #16191D`.
- **iOS `fg4` (`#555555`)** ≈ **2.4:1** on the formula panel `bg2 #161616`.

Both are below the WCAG-AA floor and below the 3:1 large-text floor. The fix across
all three items is the same principle: **move words off `fg4`, lift the size floor,
and never lean on brightness-dimming to carry hierarchy** — use the acid accent or a
weight step for that instead. (Verified hex: iOS `Theme.swift` palette; web
`styles.css:29–31`.)

---

## AC1 — Landing slider copy legibility (web)

**Decision: design-lead Option 1** — contrast first; the two-tone "dim rolling" term
becomes plain legible grey while the acid aero term carries the split.

The small copy fails mostly on **contrast**, not size: `--fg4` (2.6:1) is applied to
the most information-dense text on the panel — the assumptions disclosure, the anchor
descriptors, and the rolling-resistance term (which propagates into the methodology
formula too, shared `.f-roll` class). Space Mono's small x-height compounds it, and
the fine print runs 70+ chars with no measure cap.

Exact edits in [`docs/styles.css`](../docs/styles.css) (lines ~234–267; no markup or
copy changes):

| Selector | Change | Why |
|---|---|---|
| `.f-roll` | `--fg4` → `--fg3` | Biggest single win: rescues the rolling term in **both** slider and methodology formula (2.6:1 → contrast-legible). Two-tone survives on the acid aero term, not on dimming. |
| `.sowhat-fine` | `12px → 14px`; `--fg4 → --fg3`; `line-height 1.6 → 1.65`; add `max-width:52ch` | The whole assumptions disclosure; lift floor + contrast + pull the measure in. |
| `.sowhat-fine strong` | `--fg3 → --fg` | "The app measures your actual number" is the payoff line — brightest in the block. |
| `.sowhat-anchors` | `11px → 12px` | Block bump; color `--fg3` stays (fine). |
| `.sowhat-anchors i` | `--fg4 → --fg3`; `margin-top 2px → 3px` | Descriptors are real words, must clear AA. |
| `.sowhat-sub` | `13px → 14px`; `--fg3 → --fg2` | Captions the 26px headline number; earns the brighter tier. |
| `.sowhat-formula` | `clamp(15,1.8vw,18) → clamp(16,1.9vw,19)` | *Optional.* Lifts the panel "title" clear of the body cliff. |

**Leave alone:** `.sowhat-range` (26px readout) and `.tag-est` chip keep their type;
the slider track keeps its visual style (its width/placement follows the layout below).
Net: small-copy floor moves 11px/2.6:1 → 12–14px/≥4.9:1; ramp reads 18 → 16 → 14.

### AC1 width — use the column, keep the measure (Kah, 2026-07-19)

The panel is under-using the page. `.sowhat` is `max-width:640px` inside the `1080px`
`.wrap`, while its sibling panels already run wider (`.sowhat-formula`/`.formula`
860px, `.qa` 900px) — so the slider is the narrow one, leaving ~440px of column empty
on wide screens.

**This does not conflict with the 52ch fine-print cap** — that caps the *text
line-length* for readability; this widens the *component footprint*. The panel grows;
`.sowhat-fine` keeps its own `max-width:52ch` inside it.

Don't just stretch the track to 1080px — a very long track makes the thumb travel
absurdly far for a 1–15% range, which is worse UX, not better.

- **Recommended — two-column on wide, stacked on mobile.** At `≥720px`, lay the panel
  out as slider + anchors on the left and the big readout (`~3–17 min` + sub) promoted
  larger on the right; below `720px` it collapses to today's stack. This *spends* the
  width on a bigger payoff number and a sane track length, rather than a stretched
  track. `.sowhat max-width:640 → ~940–1000px` (toward the `.wrap`, minus breathing
  room).
- **Simpler fallback — just widen single-column.** `.sowhat max-width:640 → 860px`, to
  match the sibling `.formula`/`.qa` panels. One value, instantly more coherent, but it
  lengthens the track and doesn't grow the readout.

*Recommend the two-column version* — it's the one that makes the width earn its place.
The exact breakpoint and readout scale are a small composition detail worth an eyeball.

> **Cross-surface note:** the `.f-roll` change intentionally also brightens the
> rolling term on the methodology formula panel (shared class, by design).

---

## AC2 — Formula legend: static glossary + tap-to-light (iOS)

Two decisions, both resolved with Kah:

**(a) Static glossary — no tap-to-reveal (Kah, 2026-07-19: "just show the text, an
extra tap isn't great").** The "tap to decode" prompt was `mono(10)` at `fg4`
(~2.4:1), repeated 6×, hiding the actual payload (the meanings) behind six taps —
the opposite of the discoverability preference, for zero space saving. Retire it.

In [`HowItWorksView.swift`](../ios/GetTucked/Views/HowItWorksView.swift) `FormulaHero`
(~lines 255–340):
- Show all six meanings permanently; delete the `"tap to decode"` string and the
  `revealed`-set text gating.
- **Meaning text:** `mono(10) → mono(13)`, `fg4 → fg2` (`#999999`, ~6.5:1). NB iOS
  `fg3 #777` is only ~4.0:1 on `bg2` — unlike web, iOS must land the glossary on
  **`fg2`, not `fg3`**.
- Glyph column unchanged: `mono(12, .bold)`, `acc`, 40pt-wide leading column.
- Row min height stays `Control.iconTapTarget` (44).

**(b) Tap a legend row → light that symbol in the equation (Kah chose the interactive
option over fully-static, 2026-07-19).** This is *not* the reveal Kah cut — nothing
is hidden; it's the high-value half the web already ships and iOS omitted (the reader
never learns the 26pt equation's glyphs ARE these six rows).

- **Legend-first, persistent selection.** Touch has no hover, so tapping a row enters
  a selected state: the row's glyph and its matching glyph(s) in the 26pt equation
  brighten to **`fg` (`#EEEEEE`)** — the exact analog of the web's `is-lit → var(--fg)`.
  One selection at a time; re-tap or tap another row moves/clears it.
- **`v` lights in both places** (`v ×` and `v²`), matching the web's `data-term="v"`.
- **Equation glyphs are a secondary tap target, not primary** — they're 12–26pt inline,
  under 44pt, and finger-occluded at the panel top. The readable 44pt row is the
  reliable affordance; accept an equation-glyph tap too but don't rely on it.
- **Affordance:** because the glossary is fully visible, the tap is enhancement, not a
  gate. Signal interactivity with a 2px `acc` leading rule on the selected row (or an
  inverted glyph chip) — a faint always-on cue, not a bare row.
- **Motion:** color-only cross-fade via `Theme.Motion.interactive()` (existing 0.35
  spring) — no position/scale, so it can't fight the once-per-visit draw-on. **Add a
  reduce-motion guard:** `FormulaHero` has no `@Environment(\.accessibilityReduceMotion)`
  today — add one and drop to an instant color swap when it's on (state change stays,
  tween drops).

**Rejected:** recoloring `"tap to decode"` `fg4 → fg3` and stopping — leaves the
glossary hidden, keeps the 6× prompt noise, and `fg3` is itself ~4.0:1 on `bg2`.

---

## AC3 — Single-analysis speed: a clearly-tappable inline control (iOS)

**Decision: inline-tappable, and unmistakably so (Kah, 2026-07-19: "if we make it
tappable, we need to make it CLEARLY tappable").**

The solo-watts row ([`PositionDetailView.swift:868`](../ios/GetTucked/Views/PositionDetailView.swift)
`SoloEffortRow`) shows "Holding an assumed 30 km/h in this position takes ~190 W" as
plain text. The speed (`effortSpeedKmh`) is shared via `@AppStorage` but its **only**
control lives on the Compare screen's slider — so from the detail screen the number is
speed-dependent with no local affordance and no signpost. It reads as a baked-in
assumption when it's actually settable-elsewhere.

- Make the `30 km/h` in the sentence a **tappable inline control** that reveals a
  compact stepper (or mini-slider) in place, writing to the same shared
  `effortSpeedKmh` (10–60, step 1) so Compare stays in sync. Committing here also sets
  `effortInputsConfirmed`, dropping "assumed" on both screens.
- **Bordered chip (Kah, 2026-07-19).** Render the speed as a **bordered chip** — 0px
  radius per the design language, a visible `line`/`acc` border, `acc` value text, with
  a small edit/chevron glyph. It must read as tappable at a glance, not on discovery.
  (Exact border weight/fill is a small eyeball; the affordance is decided.)
- Tap target ≥44pt.

---

## Sequencing

1. **AC1** (web) — pure CSS, independent, lowest risk; ship first.
2. **AC2** (iOS formula legend) — static glossary is trivial; the tap-to-light reuses
   the web's proven model. One view (`FormulaHero`).
3. **AC3** (iOS speed control) — new inline control + shared-state write; test the
   Compare↔Detail sync.

All three are cleanly separable and touch non-overlapping files (`docs/styles.css`;
`HowItWorksView.swift`; `PositionDetailView.swift`), so they parallelize the same way
AB did.

## Resolved decisions (2026-07-19)
- **AC1** → design-lead Option 1 (contrast first; `.f-roll → --fg3`, two-tone via acid)
  **+ widen the panel** off 640px to use the column: two-column-on-wide recommended,
  fine-print stays 52ch-capped.
- **AC2a** → static glossary, no tap-to-reveal; meanings at `mono(13)`/`fg2`.
- **AC2b** → ship the tap-to-light interaction (legend-first, `fg` lit state, reduce-
  motion guard) — the web-parity teaching, chosen over fully-static.
- **AC3** → inline-tappable speed as a **bordered chip** (0px radius, visible border,
  acid + edit glyph).
