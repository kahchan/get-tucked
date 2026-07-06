# Plan E — Navigation & information architecture

Status: **not started**. Written 2026-07-07 after a navigation audit triggered
by a concrete regression: from the app there was no discoverable way to add a
second bike or reach the leaderboard.

**Design authority:** the unpacked prototype in `inspiration/unpacked/`
(`template.html` = screens + CSS, `b554d774.js` = flows/behaviour/copy). Where
this plan is ambiguous, open those two files and match the prototype.
**Behaviour authority:** `plans/get-tucked-code-spec.html`.

Same verify loop as Plans A–D (`xcodebuild test`, iPhone 17 simulator). One
commit per task; commit messages are Conventional Commits.

---

## Root cause — the hamburger index is a misread prototype artifact

The current app navigates via a hamburger (top-right) that opens `IndexOverlay`,
a full-screen menu listing three "peer" destinations:
`POSITIONS · LEADERBOARD · BIKES` (`AppNavigation.swift`, `IndexOverlay`, items
built ~line 169). Tapping an item does `isOpen = false; path = [screen]`.

That menu was modeled on the prototype's **storybook screen-switcher**, not on
any real app chrome. In the prototype, `.idx-btn` / `toggleIndex` opens a list
of **all 15 mockup screens** with a `01 / 15 · WELCOME` counter pinned to the
bottom (`b554d774.js:666`, `.idx-counter` CSS). It exists so a reviewer can flip
between static mockups — it is a demo harness, and it disappears in a shipped
build.

The prototype's **real** in-app IA has no hamburger:

- **Library is home** — the positions list is the app's root. Its header carries
  a single top-right acid link: `LEADERBOARD →` (`template.html:828`,
  `.hdr-link` onclick `go(14)`).
- **Leaderboard** is a pushed screen with a back caret (`template.html:928`,
  `.back-btn` → `goBack()`) and the `ALL/ROAD/GRAVEL/MTB` filter (`.lb-toggle`).
- **Bikes are not a destination.** They are switched *and created* at capture
  time through the tappable bike chip → picker sheet (`openBikePicker`), which
  contains an inline add-bike form (`toggleAddBike` → `pickType` → `saveBike`,
  `b554d774.js:515-579`). The picker's own comment is explicit:
  *"Full bike management lives in Settings; this is the capture-time picker."*
  (`b554d774.js:479`).
- **Methodology** is reference, reached from the ±% / noise-floor blocks on the
  reveal and comparison screens (Plans A2 / D4 / D6).

Both reported symptoms are the same structural error: Leaderboard and Bikes were
buried behind a menu that should not exist, and add-bike has **no** entry point
outside that menu (the prominent `+` on Positions creates a *position*, not a
bike — `PositionListView.swift:32`; the only add-bike control is a bare
`Text("+")` glyph inside `BikeListView`, reachable only via the index).

This plan removes the index and rebuilds navigation on the prototype's actual
model.

---

## Target IA

```
Onboarding (linear, first-run — Plan D8, out of scope here)
  Welcome → How It Works → Bike Setup → Set the Scene → Practice →
  Capture → Processing → Reveal → Name → Noise Floor → Comparison Prompt
        │
        ▼
Main app
  LIBRARY (root)  ──"LEADERBOARD →"──►  LEADERBOARD ──►(back)── LIBRARY
     │  +                                   │
     ▼                                      └─"METHODOLOGY →"─► METHODOLOGY
  CAPTURE FLOW
     │  bike chip (tap)
     ▼
  BIKE PICKER SHEET  ──"+ ADD BIKE" (inline)
                     └─"MANAGE BIKES →"─► BIKE LIST (edit / delete)
  reveal ±% / noise ─────────────────────► METHODOLOGY
```

Principles:
- **One root, no global chrome menu.** The only persistent affordances are the
  per-screen header links (`hdr-link`) and the back caret on pushed screens.
- **Bikes live inside capture**, plus a management list reachable from the
  picker. Bikes are never a top-level peer of Positions/Leaderboard.
- `AppScreen` keeps its cases (`.leaderboard`, `.bikeList`, etc.) — the change
  is *how they're reached*, not the stack model. `NavigationStack(path:)` stays.

---

## E1. Remove the hamburger index; Library becomes root with a Leaderboard link

The highest-value, lowest-risk task. It deletes the broken menu and restores
Leaderboard discoverability in one move.

- File: `ios/GetTucked/Design/AppNavigation.swift`
  - Delete `HamburgerButton` and the `IndexOverlay` struct, the `indexOpen`
    state, the `if indexOpen { … }` overlay, and the hamburger overlay block.
  - Keep the `BackButton` overlay and its condition (`!path.isEmpty &&
    path.last != .capture`) — pushed screens still need a back caret.
  - Keep the `.animation` only if still referenced; otherwise remove.
- File: `ios/GetTucked/Design/SharedViews.swift` / `PositionListView.swift`
  - Add a `LEADERBOARD →` link to the Positions `NavHeader` trailing slot,
    styled per prototype `.hdr-link` (`Theme.mono(10)`, `Theme.Palette.acc`,
    kerning ~0.08em, uppercase). On tap: `path.append(.leaderboard)`.
  - It sits alongside the existing `SELECT` / `+` controls. Confirm the trailing
    HStack + `chromeReserve` still lays out without crowding; the hamburger is
    gone, so the 52pt reserve can likely drop back to `Theme.Space.lg` on
    Positions — verify on device before changing the token (other screens may
    still rely on `chromeReserve` for the back caret; leave the token, adjust
    per-screen padding).
- File: `ios/GetTucked/Views/LeaderboardView.swift`, `BikeListView.swift`
  - Remove the now-dead assumption that these are entered from the index. No
    functional change; they're still pushed via `path`.

Notes:
- This also eliminates the fragile `isOpen = false; path = [...]` write that
  mutated the navigation path from inside the very overlay the same tap tore
  down — a known SwiftUI footgun and the prime suspect for menu taps that closed
  without navigating.
- `BikeListView` is temporarily orphaned after this task (its only entry point
  was the index). E3 gives it a new home. If E3 slips, gate the risk by landing
  E1 + E3 together.

**Acceptance:** no hamburger anywhere; Positions is root; a `LEADERBOARD →`
header link pushes the leaderboard; back caret returns; no dead index code
remains.

**Commit:** `refactor(nav): remove hamburger index, Library-root + Leaderboard header link (Plan E1)`

## E2. Capture-time bike picker with inline add-bike

Restores add-bike *in context* and makes the bike chip the switcher, per the
prototype. Absorbs Plan C4 and `phase2-live-capture-plan` item 2.

- File: `ios/GetTucked/Capture/LiveCameraView.swift`
  - `BikeChip` (currently display-only, `LiveCameraView.swift:38` / struct at
    `:148`) becomes a button → presents a bike picker sheet. Restyle to the
    prototype two-line chip (`SHOOTING ON` key over the bike name, acc `▾`
    caret) if D2 hasn't already; otherwise keep D2's chip and just add the tap.
- File: `ios/GetTucked/Capture/CaptureView.swift` (or a new
  `Capture/BikePickerSheet.swift` if the sheet grows past ~120 lines)
  - Build `BikePickerSheet`:
    - Lists bikes (`@Query`), current one marked (acc tick / `on` state per
      prototype `.bike-row.on`). Tapping a row sets the capture's
      `selectedBike` and dismisses (~180ms delay, matching `selectBike`).
    - Inline **`+ ADD BIKE`** disclosure (prototype `toggleAddBike`): expands a
      compact form — nickname, `ROAD/GRAVEL/MTB` segmented (`pickType`),
      handlebar width (mm). `SAVE BIKE` (`saveBike`) inserts the `Bike`, selects
      it as active, collapses the form. Reuse the field components from
      `BikeSetupView` / `Design/Components.swift`; do **not** duplicate the
      validation (`isValid`) — extract if needed.
  - `selectedBike` default remains most-recently-used → first (Plan C4). Switch
    is safe pre-calibration: `handlebarWidthMm` is re-read at calibrate time.
- Cross-check: the `+` on Positions stays disabled when `bikes.isEmpty`
  (`PositionListView.swift:42`) — first bike still comes from onboarding /
  Welcome, so the picker's add path is for the *second+* bike.

**Acceptance:** in capture, tapping the bike chip opens a sheet; you can switch
bikes and add a new bike inline without leaving the flow; the saved position
carries the chip-selected bike.

**Commit:** `feat(capture): tappable bike chip → picker sheet with inline add-bike (Plan E2)`

## E3. Bike management surface (flagged — confirm before building)

`BikeListView` (edit / delete, `BikeListView.swift`) needs a home now the index
is gone. The prototype defers this to a "Settings" screen that does not yet
exist in the 15 mockups.

**Recommendation (pending Kah's confirmation):** a `MANAGE BIKES →` link at the
bottom of the E2 picker sheet → pushes `BikeListView`. Keeps bike management
adjacent to where bikes are used, and adds no top-level chrome the prototype
avoids.

Rejected alternative: a gear icon in the Library header — reintroduces a
persistent global control the prototype deliberately omits.

- File: E2's picker sheet + `BikeListView.swift`
  - Add the `MANAGE BIKES →` link (`hdr-link` style) below the bike list.
  - `BikeListView` keeps its edit sheet + delete; its own `+` can be dropped in
    favour of the picker's inline add (avoid two add paths), or kept — decide on
    device. Its entry is now the picker link, not the index.

**Acceptance:** from the capture bike picker, `MANAGE BIKES →` opens the bike
list; edit and delete work; no orphaned `BikeListView`.

**Commit:** `feat(bikes): reach bike management from the capture picker (Plan E3)`

## E4. Cross-links: Leaderboard → Methodology, header parity

Finish the header cross-link web so every reference screen is reachable without
the index.

- File: `ios/GetTucked/Views/LeaderboardView.swift`
  - Confirm the back caret behaves (E1 supplies the overlay); subtitle updates
    per active filter (Plan D7 handles full styling — here just the link).
  - Optional `METHODOLOGY →` `hdr-link` if Methodology exists by now
    (Plan A2 / D4 own the screen); otherwise leave a TODO and land with D4.
- File: reveal / comparison ±% blocks — ensure they link to Methodology
  (owned by Plans A2 / D4 / D6; this task only audits that no path depends on
  the removed index).

**Acceptance:** Methodology is reachable from the leaderboard and from the ±% /
noise-floor blocks; no navigation path anywhere routes through the old index.

**Commit:** `feat(nav): leaderboard + reveal cross-links to methodology (Plan E4)`

---

## Relationship to other plans

- **Supersedes Plan D1** (`438f70d`, "hamburger top-right"). D1's header
  left-alignment + subtitle work stays; only the hamburger relocation is undone.
  Mark D1 superseded in `plan-d-design-parity.md`.
- **Absorbs Plan C4** (kill bike-picker step; pick bike in the HUD) and
  `phase2-live-capture-plan` item 2 (tappable `BikeChip` → picker) into E2.
- **Unaffected and still standing:** D5 (Library rows), D6 (comparison), D7
  (leaderboard styling), D8 (onboarding). E rebuilds *routing*; D5–D8 restyle
  the screens E routes to — do E first so D-work targets the final structure.

## Flagged decisions for Kah

1. **E3 bike-management home** — recommendation is the `MANAGE BIKES →` link in
   the capture picker (vs. a Library-header gear). Confirm before E3.
2. **Keep `BikeListView`'s own `+`?** — once E2's inline add lands there are two
   add paths. Recommendation: drop `BikeListView`'s `+`, keep add only in the
   picker. Decide on device during E3.
3. **`chromeReserve` after E1** — the 52pt trailing reserve existed for the
   hamburger. Re-tune per screen once it's gone; don't remove the token (the
   back caret's leading reserve still uses the same 52pt convention).
