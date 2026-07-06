# Plan B — Legibility tune + finish the token pass

Status: **done**. Written 2026-07-03. B1-B5 all landed:
B1 `45db5c5`, B2 `223a5c0`, B3 `0b8cced`, B4 `f9839e4`, B5 `667f306`.
Design authority: the unpacked prototype (`inspiration/unpacked/template.html`
+ `b554d774.js`) and the token system (near-black `bg0`, acid yellow,
**0px radius on surfaces/buttons/cards**, Space Mono numbers/labels,
Barlow Condensed headings). Never introduce a rounded corner on a
surface/button/card or a system-blue control. Exemption (per the prototype
CSS): small **circles** are correct for status dots, radio/check indicators,
the `?` help button, and circled step numbers.

Note on sizes: the prototype uses 7–9px labels at its 393px stage scale.
Do not copy those; this plan's 11pt floor is a deliberate on-device deviation —
preserve the prototype's *hierarchy* (which sizes are biggest/smallest),
not its absolute pixel values.

Verify loop after every task:

```sh
cd ios && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -project GetTucked.xcodeproj -scheme GetTucked \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

The problem: the current type scale bottoms out at 9–11pt Space Mono in
`fg3 #777` / `fg4 #555` on `#080808`. On a phone outdoors (this app is used in
driveways and car parks) that is too small and too dim. Custom fonts also
currently ignore Dynamic Type entirely.

## Legibility rules (apply throughout, memorise before editing)

- **Floor: no text below 11pt.** 9–10pt sizes get bumped per the table below.
- **fg4 (#555) is decorative only** (arrows, dots, `···` placeholders). Any
  text that carries information uses fg3 or better.
- **Data values** (cm², %, mm, °) are ≥13pt bold mono.
- Keys/labels may be fg3 only at ≥12pt; at 11pt use fg2.

## B1. Dynamic Type support in Theme

File: `ios/GetTucked/Design/Theme.swift`. Change the two font helpers to scale
with the user's text size:

```swift
static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    let name = weight == .regular ? FontName.mono : FontName.monoBold
    return .custom(name, size: size, relativeTo: .body)
}

static func heading(_ size: CGFloat) -> Font {
    .custom(FontName.heading, size: size, relativeTo: .title)
}
```

**Acceptance:** build succeeds; with iOS Settings text size increased, app text
visibly scales. (Layout overflow at huge sizes is acceptable for now — spec
Phase 5 owns the full accessibility pass.)

## B2. Size/contrast sweep (mechanical — follow the table)

| File | Element | Now | Change to |
|---|---|---|---|
| `Design/Components.swift` | `MetricRow` key | 11 fg3 | 12 **fg2** |
| `Design/Components.swift` | `MetricRow` value | 13 bold | 15 bold |
| `Design/Components.swift` | `StatusPill` label | 10 | 11 |
| `Capture/LiveCameraView.swift` | `BikeChip` both labels | 9 | 11 |
| `Views/ComparisonView.swift` | `DiffRow` key | 10 fg3 | 11 fg2 |
| `Views/ComparisonView.swift` | `DiffRow` A/B values | 12 fg2 | 13 fg |
| `Views/ComparisonView.swift` | `DiffRow` diff | 12 bold | 13 bold |
| `Views/ComparisonView.swift` | `DiffTable` header labels | 10 fg4 | 11 fg3 |
| `Views/ComparisonView.swift` | `PositionPanel` area | 20 bold | 24 bold |
| `Views/ComparisonView.swift` | `PositionPanel` side/bike | 10 fg4 | 11 fg3 |
| `Views/LeaderboardView.swift` | `RankRow` label | 13 bold | 14 bold |
| `Views/LeaderboardView.swift` | `RankRow` bike / delta / rank | 10–11 fg4 | 11 fg3 |
| `Views/LeaderboardView.swift` | `FilterBar` options | 10 | 11 |
| `Views/PositionListView.swift` | row date | 11 fg3/fg4 | keep 11, all fg3 |
| `Views/PositionDetailView.swift` | `MetricsSection` "FRONTAL AREA" + ± line | 10/11 fg4 | 11/12 fg3 |
| `Views/PositionDetailView.swift` | `ToggleTab` labels | 11 | 12 |
| `Views/SetTheSceneView.swift` | `TipCell` text | 11 fg2 | 12 fg2 |
| `Views/BikeListView.swift` | row spec line | 11 fg3 | keep; "EDIT" 10 fg4 → 11 fg3 |

Column widths in `DiffTable`/`DiffRow` (72/72/64) must grow to 76/76/70 so the
larger values don't truncate.

**Acceptance:** build + tests pass; no `Theme.mono(9…)` or `Theme.mono(10…)`
remains anywhere (`grep -rn "Theme.mono(9\|Theme.mono(10" ios/GetTucked` → only
acceptable hits are decorative glyphs, ideally none).

## B3. One uncertainty format everywhere

Now: RevealStep shows `± 155 cm² estimated`, PositionDetail shows `±154.7 cm²`.
Same number, two voices — looks like two different quantities.

- Add to `ios/GetTucked/Analysis/AnalysisMath.swift`:
  `static func uncertaintyDisplay(_ cm2: Double) -> String` returning
  `"±\(Int(cm2.rounded())) cm²"`. Unit-test it (run existing tests first).
- Use it in `RevealStep` (CaptureView.swift), `MetricsSection`
  (PositionDetailView.swift), and anywhere else a ± renders. Drop the word
  "estimated" — the How-This-Works link (Plan A2) explains it instead.

**Acceptance:** grep for `"±"` in `ios/GetTucked/Views` + `Capture` shows only
call sites of the shared formatter.

## B4. Finish the token pass inside CaptureView (the last system-SwiftUI island)

File: `ios/GetTucked/Capture/CaptureView.swift`. This is the biggest single
task in this plan. The capture flow still uses system chrome that clashes with
every other screen. Sub-steps (keep as ONE commit — it's one visual pass):

1. **Remove the inner `NavigationStack`** and system toolbar. Replace with the
   app pattern: `NavHeader(title: stepTitle)` with a trailing ✕ button that
   calls `dismiss()`, over `Theme.Palette.bg0`. The camera step
   (`LiveCameraView`) keeps its own full-screen HUD — show no NavHeader there.
2. **`BikePickerStep`** — restyle rows like `BikeListView.BikeRow` (mono 14
   bold name, mono 11 fg3 spec line, `SectionDivider` between rows, selection
   shown as a square acc indicator like `SelectablePositionRow`, not a
   `checkmark.circle.fill`). NOTE: Plan C4 deletes this step entirely — if
   Plan C4 has already landed, skip this sub-step.
3. **`HandlebarCalibrationStep`** —
   - instruction banner: `Theme.mono(12)` fg on `bg1`, full-width, no system
     `secondarySystemBackground`;
   - tap markers: first point `acc`, second `amb` squares (`Rectangle`,
     18×18, 2px white inner border) instead of blue/orange circles;
   - zoom preview: **square**, `Rectangle` border in `line` — the current
     `RoundedRectangle(cornerRadius: 8)` violates the 0-radius rule;
   - confirm: `AccentButton(label: "CONFIRM SCALE", …)` with disabled state,
     replacing `.borderedProminent`.
4. **Analysing states** — replace both `ProgressView("…")` with a centred
   `Theme.mono(12)` fg3 `ANALYSING…` / `ANALYSING POSTURE…` on bg0 (match
   MatteCheckView's `SEGMENTING…` pattern).
5. **`PhotoPickStep` (side-on)** — dark canvas, step label `Theme.mono(11)`
   fg3, instructions `Theme.mono(13)` fg2, pick button as `GhostButton`
   ("CHOOSE FROM LIBRARY"). (Superseded later by live side-on capture —
   phase2-live-capture-plan item 3 — but cheap to keep consistent now.)
6. **`NamePositionStep`** — replace `Form`/`.borderedProminent` with the
   `BikeSetupView` pattern: `FieldLabel("POSITION NAME")` + `MonoField` +
   bottom hairline, context line `Theme.mono(12)` fg3, save as
   `AccentButton(label: "SAVE POSITION", enabled: isValid)`. `FieldLabel` and
   `MonoField` are currently `private` in `Views/BikeSetupView.swift` — move
   them into `Design/Components.swift` (internal) and delete the privates.
7. **Done state** — replace the green SF checkmark with the design voice:
   `Theme.heading(28)` "SAVED" in acc, centred on bg0, same 0.8s auto-dismiss.

**Acceptance:** capture flow end-to-end shows zero system-styled controls, zero
rounded corners, zero `Color.blue/orange/green`; tests pass.

## B5. Numbers legibility on the reveal (polish, quick)

`RevealStep` hero: keep 60pt but give the ± line 12pt fg3 (per B2 floor), and
add `SectionDivider` spacing so `Scale` / pose rows don't crowd the hero.
Check `PositionDetailView.MetricsSection` hero matches the RevealStep hero
exactly (both `Theme.mono(60, weight: .bold)` acc + 18pt fg3 unit).

**Acceptance:** side-by-side screenshot of Reveal vs Detail shows the same
hero treatment.
