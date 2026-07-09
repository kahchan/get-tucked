# Plan M — Header layout polish

Status: **done** (M1–M5 implemented 2026-07-08, plus a same-day follow-up
fix, not yet committed). Build green, all 63 existing tests pass (no new
tests — pure layout). Verified on the iPhone 17 simulator: Positions now
has a clear gap below "Tap two to compare.", the back arrow renders as a
full, centred SF Symbol on Bikes and Leaderboard (no left-edge clipping)
aligned with the root screen's 16pt margin, and gear/plus/back icons are
visibly bigger and consistent. Screenshots taken via a temporarily seeded
`path` in `AppNavigationView` (reverted after) since no on-device tap
automation was available in this session — Kah should still eyeball it
on a real device per the acceptance section below.

**Follow-up (same day):** Kah reported the title and icons looked
mismatched from on-device screenshots after the first pass. Root cause:
`NavHeader`'s title sat at a position that depended on both whether a
subtitle was present *and* whether `trailing()` was a 44pt icon or an
empty view — so the floating `BackButton` (one fixed position, drawn
once in `AppNavigationView` for every pushed screen) could only ever
match one configuration. Fixed by reserving the same minimum height
(`Theme.Control.iconTapTarget`, top-anchored) on both the title side and
the trailing side of `NavHeader`'s row, so the title now sits at an
identical offset regardless of subtitle or trailing content — confirmed
via pixel-level measurement of simulator screenshots (a Python PNG
scanline decoder, since no PIL/ImageMagick was available) that title
position is now invariant between Bikes (icon, no subtitle) and
Leaderboard (subtitle, no icon), then re-tuned `BackButton`'s fixed
`.padding(.top, ...)` once against that invariant position (was
`Theme.Space.sm + 6`, now a literal `-2`, tuned on-device rather than
token-derived since it centres against a floating overlay `NavHeader`
has no way to report its own position to). `PositionListView`'s own
title row (`.center`, mixing "POSITIONS" with SELECT/gear/plus) was left
alone — same underlying tension (44pt icon vs ~23pt text) but no
cross-screen arrow to keep in sync there, so plain centring already
looks reasonable.

Written 2026-07-08 from Kah's on-device screenshots of the Positions,
Bikes, and Leaderboard screens. Four complaints, in priority order:

1. **Worst: no space below "Tap two to compare."** — the subtitle row
   sits directly on the section divider.
2. **Back arrow is clipped** on its left edge (visible on Bikes /
   Leaderboard).
3. **Layout is slightly narrow** — Kah wants it more edge-to-edge, and
   confirmed 16pt margins are right *given* the bigger icons and a
   proper header gap (the three changes are a package deal; don't land
   the margin change without the other two).
4. **Icons should be bigger** (second time this has come up — they were
   already bumped once to the current 22pt).

## Diagnosis (verified in code 2026-07-08)

- **Missing header gap:** the bespoke two-row header in
  `ios/GetTucked/Views/PositionListView.swift` (~line 76) has
  `.padding(.top, Theme.Space.sm)` but **no bottom padding** before the
  `SectionDivider()`. The shared `NavHeader` in
  `ios/GetTucked/Design/SharedViews.swift` (~line 43) has the identical
  gap, which is why Leaderboard's subtitle also crowds its tab bar.
- **Clipped arrow:** `BackButton` in
  `ios/GetTucked/Design/AppNavigation.swift` (~line 91) renders a
  **text glyph** `"←"` in Space Mono Bold, left-aligned in its 44pt tap
  frame. That glyph bleeds past its advance width in this font, so the
  left edge clips. The gear and plus icons are SF Symbols and don't
  have the problem.
- **Narrow layout:** every screen hardcodes `Theme.Space.lg` (24pt) as
  its horizontal margin; there is no dedicated screen-margin token.
- **Icon size:** one shared token, `Theme.Control.iconSize = 22`
  (`ios/GetTucked/Design/Theme.swift` ~line 77).

## Decisions already made by Kah — do not re-litigate

- **Back arrow becomes an SF Symbol** (`arrow.left`), not a fixed text
  glyph. Rationale: kills the clipping for free, joins the gear/plus
  icon family under the one `iconSize` token, scales cleanly at 26pt.
  The Space Mono arrows stay where they belong — inline text arrows
  (`→`) in `HeaderLink` and buttons, which are text-scale and don't
  clip.
- **Margin goes to 16pt** (not the 20pt first proposed). Kah: "more
  edge to edge would work if the icons were bigger and we have a good
  gap."
- Icons go to **26pt**.

## Tasks

### M1 — Theme tokens (`ios/GetTucked/Design/Theme.swift`)

Everything else keys off these:

- `Control.iconSize`: `22` → `26` (bumps gear, plus, and — after M2 —
  the back arrow together).
- New `Space.screenMargin: CGFloat = 16` — the horizontal screen
  margin. All *horizontal* screen padding uses this from now on;
  vertical uses of `Space.lg` are untouched.
- New `Control.headerBottomPad: CGFloat = 16` — the header→divider gap
  that's currently missing.
- `Control.headerTitleInset`: `58` → `52` — pushed-screen titles
  re-align with the tighter margin (16pt margin + a centred 26pt glyph
  in a 44pt target needs less clearance than the old left-aligned text
  glyph did). Update the token's doc comment, which currently describes
  the left-aligned-glyph layout that M2 removes.

### M2 — BackButton → SF Symbol (`ios/GetTucked/Design/AppNavigation.swift`)

- Replace `Text("←")` with `Image(systemName: "arrow.left")`, styled
  like the gear/plus in `PositionListView`:
  `.font(.system(size: Theme.Control.iconSize, weight: .medium))`,
  keep `Theme.Palette.fg2`.
- **Centre** the glyph in its 44×44 tap target (alignment `.leading` →
  `.center`); the centring is part of the clipping fix.
- Adjust the floating overlay's `.padding(.leading, …)` in
  `AppNavigationView` so the *glyph* (not the invisible tap box)
  optically sits at the 16pt margin: with a centred ~26pt glyph in a
  44pt frame that's `screenMargin − (44 − 26)/2` = **7pt** on the
  frame. Eyeball it in the canvas/simulator; ±1–2pt is fine, glyph
  alignment with the title's left edge on the *root* screen's margin is
  the target.

### M3 — Shared header (`ios/GetTucked/Design/SharedViews.swift`)

- `NavHeader`: add `.padding(.bottom, Theme.Control.headerBottomPad)`;
  trailing padding `Theme.Space.lg` → `Theme.Space.screenMargin`.
  (Leading stays `headerTitleInset` from M1.)
- `HeaderLink`: `Theme.mono(10)` → `Theme.mono(11)` so it matches the
  subtitle weight it sits next to.

### M4 — Positions header (`ios/GetTucked/Views/PositionListView.swift`)

The bespoke two-row header (it intentionally does not use `NavHeader` —
keep it bespoke):

- Add `.padding(.bottom, Theme.Control.headerBottomPad)` — this is the
  fix for the worst issue.
- Horizontal padding `Theme.Space.lg` → `Theme.Space.screenMargin`.

### M5 — Margin sweep (mechanical)

Replace **horizontal** `Theme.Space.lg` padding with
`Theme.Space.screenMargin` across screens and row components so margins
stay consistent: `BikeListView`, `LeaderboardView`,
`PositionDetailView`, `ComparisonView`, `HowItWorksView`,
`SetTheSceneView`, `BikeSetupView`, plus row components
(`PositionRow`, `SelectablePositionRow`, `CompareBar`, bike rows) and
`EmptySlate`/`EmptyStateView` if they use `Space.lg`/`Space.xl`
horizontally as a *margin* (leave genuinely internal padding alone —
judgement call: if it's the distance from the screen edge, it's a
margin).

Do **not** touch: vertical paddings, the capture flow HUD
(`Capture/…` — it has its own landscape-aware layout from Plan L), or
the retired browser spike (`src/`).

## Acceptance (on device — Kah)

Against the three screenshot screens:

- Positions: clear gap between "Tap two to compare." and the divider.
- Bikes / any pushed screen: back arrow fully visible, left edge not
  clipped, optically aligned with the root screen's 16pt margin.
- Icons (gear, plus, back) visibly bigger and consistent with each
  other.
- 16pt margins + 26pt icons + the new header gap read balanced, not
  cramped. If 16 feels too tight, the fallback is a one-token edit
  (`Space.screenMargin`).

## Build/verify notes

- `cd ios && xcodegen generate` is only needed if files are
  added/removed — this plan only edits existing files.
- Build and run existing tests; no new tests needed (pure layout).
- Conventional Commits; suggest one commit per task or a single
  `feat(design): header gap, SF-symbol back arrow, 16pt margins, 26pt
  icons (Plan M)`.
