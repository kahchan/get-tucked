# Approximately Scientific — audit (2026-10-17)

Source: `Data Components.html` (Claude Design bundle export, unpacked). The export holds
the token sheet, 24 components and two UI kits (`ui_kits/app`, `ui_kits/website`). It does
not hold `readme.md`, `SKILL.md` or `_adherence.oxlintrc.json`.

## The idea (keep)

A lab notebook. Warm paper, cool ink, cyanotype blue for structure, one instrument-orange
accent for measurement. Hairline rules, near-square corners, no blur shadows, plotted
motion with no spring. Figures, equations and tables carry numbers (FIG. 02, TABLE 1, (3)).
`≈` marks an estimate. Viridis for plots. This idea is strong and specific. Keep it.

Type: Archivo (UI sans), Newsreader (display serif, italic subtitles), Ojuju (eyebrows,
units), Geist Mono (data, labels). Font comment says these are Google substitutes; the
intended faces are not in the export.

## Findings

### A. Contrast (WCAG 2.2)

| Pair | Ratio | Use | Verdict |
|---|---|---|---|
| `--text-faint` / `--text-annotation` (ink-400) on page | 3.45 | labels 10–11.5px, FIG./TABLE captions, hints | **fails** 4.5 |
| same on card / sunken | 3.73 / 3.18 | same | **fails** |
| ink-300 on page | 2.38 | — | fails |
| signal-500 on page | 4.03 | measure figures (large: ok) | fails as small text |
| Button `measure`: paper on signal-500 | 4.36 | 11.5px caps label | **fails** |
| Badge `warn`: warn-600 on warn-100 | 4.12 | 10px caps | **fails** |
| warn-600 on page | 4.44 | — | fails |
| Input / Card border: rule-hair on card | 1.36 | input boundary | **fails** 3:1 (1.4.11) |
| Switch off track paper-200 on page | 1.08 (border 1.96) | control boundary | **fails** 3:1 |
| ProgressMeter track on page | 1.08 | — | fails 3:1 |
| plot-5-line / plot-6-line on page | 3.16 / 3.49 | chart strokes | pass 3:1, marginal |
| Blueprint: muted on card | 4.45 | | fails |
| Blueprint: faint on page / card | 3.48 / 3.09 | | fails |
| Blueprint: signal-500 on card | 4.09 | | fails as small text |

Pass: ink-900/700/500, link, signal-600, ok-600, err-600, Button primary (9.59), Readout
digits on well, Tooltip.

### B. The semantic layer is bypassed

- Components reference primitives 114 times (`--blueprint-600`, `--paper-000`, `--ink-900`)
  and semantic tokens 345 times.
- So `.as-blueprint` does not flip them. Measured on the blueprint page:
  ghost Button text ink-700 **1.04:1**, Tag / SegmentedControl / Checkbox border ink-900
  **1.46:1**, primary Button edge 1.30:1. Input's unit cell stays paper-100 (a light slab).
- 39 tokens are defined and never used, among them the whole `--accent*` family,
  `--measure`, `--measure-quiet`, `--surface-inverse`, `--text-inverse`, `--type-ui`,
  `--font-numeral`, `--shadow-overlay`, `--radius-md`, `--sp-1`. The semantic names exist;
  the components do not use them.

### C. Inconsistent meanings

- `tone="measure"` is signal orange in StatBlock, ProgressMeter, Readout, Button and
  Badge, but **plot-3 teal** in Sparkplot.
- Disabled opacity is .38 (Button, IconButton) and .42 (Checkbox, Radio, Switch).
- Button radius is a raw `"1px"`, Readout `1`; tokens say `--radius-xs` / `--radius-sm`.
- Form labels use `--type-eyebrow` (Ojuju) in Input/Select, but `--type-label` (mono)
  everywhere else.

### D. Off-scale values

- Paddings outside the `--sp-*` scale: `7px 14px`, `11px 20px`, `15px 28px`, `6px 13px`,
  `4px 9px`, `3px 8px`, `2px 6px`, `4px 7px`, `8px 30px 8px 11px`.
- Raw letter-spacing: Button `0.055em`, Equation `.01em`, Readout `-.01em`, kits `.04em`.
- Radii: 0 / 1 / 2 / 3 / pill. 1, 2 and 3px look the same at 1× and 2×.

### E. Size and touch

- Button `sm` ≈ 26px tall, `md` ≈ 36px; IconButton sm 28 / md 34. Below the 44pt iOS
  minimum that the system itself defines (`--touch-min: 44px`).
- Smallest text is 10px (`--text-2xs`) in caps with 0.14–0.24em tracking, in Ojuju, a
  display face. This is the brand's most frequent text style and its weakest.

### F. Platform gaps (for a studio-wide system, web + iOS)

- No dark mode. `.as-blueprint` is a hero/panel scope, not a theme, and breaks (see B).
- Tokens are CSS only. No Swift/iOS mapping; no rule for px → pt or Dynamic Type.
- Four type families. Each one has a role, but Ojuju's only jobs are 10px eyebrows and
  units.
