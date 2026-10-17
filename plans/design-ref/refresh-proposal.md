# Approximately Scientific v2: refresh proposal

Studio system for Imprecisely Accurate. Web (React) and iOS (SwiftUI). This is an
evolution: the name and logo do not change. Each change comes from a finding in
[`audit.md`](audit.md). Status: **proposal, not yet approved.** I measured every ratio
with WCAG 2 relative luminance, and a second script checked them again.

## Keep (unchanged)

- The paper, ink and blueprint ramps. Blueprint is the action colour.
- Signal is the only accent, and it marks only measurement.
- Hairlines are notebook blue, not grey. There are no blur shadows.
- The 2px pressed-plate key shadow. The readout well.
- FIG. / TABLE / (n) numbering. `≈` marks an estimate. Viridis stays for data.
- Newsreader italic subtitles. Mono data. The millimetric spacing scale.
- `--ease-plot`. Plotted motion with no bounce.

## Change

| # | Fixes | New value | Result |
|---|---|---|---|
| 1 | B | Components use only semantic and component tokens. Themes override only the semantic layer. | Fixes `.as-blueprint` (ghost button was 1.04:1). Makes dark mode possible. |
| 2 | A | `--text-annotation: #5C6B7E`. `--text-faint` merges into it. | 4.95 page · 5.35 card · 4.57 sunken |
| 3 | A | New `--border-control: #6884A8` for Input, Select, Switch, Checkbox, Radio and the Meter outline. `--rule-hair` is decoration only. | 3.50 · 3.79 · 3.23 |
| 4 | A | `--signal-500: #B04812` (was `#C85416`) | Paper on it: 5.46. As text: 5.05 / 5.46 / 4.66 |
| 5 | A | `--warn-600: #7E580B` | 5.39 on warn-100 |
| 6 | C | Sparkplot `measure` = `var(--measure)` (it was teal) | One meaning for each word |
| 7 | — | Viridis is sequential only. A categorical palette has 3 slots at most. Plot-1/2 lifts move to `-line` tokens. | 6 stops fail as categories (ΔE 2.0 deutan) |
| 8 | F | Drop Ojuju. Eyebrow = `500 11px/1.2` Geist Mono, caps. | 3 families. The Input and Select labels then match the other labels. |
| 9 | E | `--text-2xs: 11px` (the minimum), `--text-xs: 12px`. Label tracking `.08em`, eyebrow `.12em`, figure `-.01em`. | Matches iOS caption2/caption1 |
| 10 | D | Radii: `0` · `--radius: 2px` · `--radius-pill` (Radio only) | 3 steps you can see |
| 11 | D | Controls are sized by height: `--control-h-sm/md/lg` = sp-7/8/9 (27/36/48). `--pad-field-x` = sp-4. `--pad-mark` = sp-1 sp-3. IconButton 27/36. | All off-scale paddings go |
| 12 | E | `--hit-min: 44px`. Web: `::before` under `(pointer: coarse)`. iOS: `.contentShape` with `minHeight: 44`. | The visual density stays |
| 13 | C | `--opacity-disabled: .4`. Disabled controls have no key shadow. | One value |

Blueprint scope: muted `#A9BED8` (5.92 card) · annotation `#8FA7C6` (4.57 card) ·
signal `#F58A3E` (4.61 card) · border-control `#6A93C8` (3.55 card).

## Add: the Ink dark theme

`.as-blueprint` stays a scope (a feature panel) in both themes.

| Semantic | Ink | Check |
|---|---|---|
| surface page / card / sunken / well | `#12171C` / `#1A2027` / `#0E1216` / `#06090C` | |
| text strong / body / muted / annotation | `#F7F4EC` / `#D9D5CA` / `#A9AFB5` / `#8E9AAA` | 16.40 · 11.19 · 7.41 · 5.75 (card) |
| text-link | `#9CC0EB` | 8.71 |
| border hair / control / strong | `#2B3540` / `#5F7898` / `#C7CBCF` | — · 3.62 · 10.06 |
| accent / hover / quiet | `#3A68A6` / `#4574B4` / `#1F3350` | paper on it 5.57 / 4.68 |
| measure / on / quiet | `#F07C2B` / `#101418` / `#4A2D1B` | 6.54 page |
| ok / warn / err (fg on bg) | `#6CC49A`/`#17302A` · `#E3AE45`/`#33280F` · `#F08A7A`/`#3A1C18` | 6.70 · 7.17 · 6.34 |
| key-shadow, scrim | `rgba(0,0,0,.6)` | |

## iOS mapping

| Concern | Rule |
|---|---|
| Units | 1px = 1pt |
| Fonts | Bundle Archivo, Newsreader and Geist Mono (all OFL). Use `Font.custom(_, size:, relativeTo:)`. |
| Type | 11→caption2 · 12→caption1 · 13→footnote · 15→subheadline · 17→body · 21→title3 · 27→title · 34→largeTitle |
| Colour | Make one asset colour set for each semantic token (Any = paper, Dark = Ink). Do not ship primitives. |
| Motion | Use `.timingCurve(0.2, 0.6, 0.2, 1, duration: 0.2)` for state changes. Use a critically damped spring for gestures. |

## Token architecture

- **Primitive:** the colour ramps, `--sp-*` and `--text-*`. Components never use these.
- **Semantic:** surface, text, border, accent, measure, status, focus, plot-line, shadow and
  scrim tokens. Themes and scopes override only this layer.
- **Component:** `control-h-*`, `pad-*`, `radius`, `opacity-disabled` and `hit-min`.
- **Connect 15 unused tokens:** accent ×3, measure ×2, surface-sunken/inverse, text-inverse,
  shadow-overlay, sp-1, radius-none, plot-scale, ink-200, blueprint-400 and blueprint-500.
  The last two are reused for the Ink accent.
- **Delete 24 unused tokens:** container-sm/xl, grid-*, dur-slow, ease-step, font-body,
  font-numeral, font-technical, inset-hair, measure-text, measure-narrow, paper-300,
  radius-md, rule-blue, rule-ink, shadow-none, shadow-soft, surface-blueprint,
  tracking-body, tracking-lockup, type-ui and weight-bold.

## Also

1. Make `tokens.json` the single source. A script of about 50 lines, with no new
   dependency, generates the CSS variables and the `.xcassets` colour sets.
2. Add an adherence lint that fails when a primitive name appears under `components/`.
3. With reduced motion, the 900ms chart draw becomes a cross-fade.

## Decisions (Kah, 2026-10-17)

1. Ojuju stays, but only for hero numerals at 27px and larger (`--font-numeral`). It is
   not used for eyebrows or units. This replaces change #8's "drop".
2. Signal is `#B04812`.
3. Get Tucked keeps its own look. It shares only the token architecture, so the system
   does not need a per-product accent slot.
4. Deliver the system as a design artifact, not as a Claude Design project.
