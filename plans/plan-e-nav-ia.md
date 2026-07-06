# Plan E — Navigation & information architecture

Status: **in progress**. E1 done (`911afbe`), E2 done (`a27777b`), E3 done
(`db89f0b`, but per Kah's call, **not** the plan's own recommendation — see
E3 below). E4 has nothing to build yet: Methodology doesn't exist in the
codebase (owned by Plans A2/D4), so the hdr-link half of its acceptance
criteria is deferred to whichever of those lands the screen; the "no path
depends on the removed index" half is confirmed clean (repo-wide grep for
`IndexOverlay`/`HamburgerButton` finds nothing outside this plan's own
commits). Written 2026-07-07 after a navigation audit triggered by a
concrete regression: from the app there was no discoverable way to add a
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

**Done** (`911afbe`). Landed as specced, plus one call not covered by the plan:
the DEBUG-only `matteCheck` screen had no other entry point once the index was
gone. Added a tiny `#if DEBUG` "DBG" header button as a first pass, but on-device
verification showed it overcrowded the trailing row (`LEADERBOARD →` wrapped to
five lines) — pulled it back out. `matteCheck` is reachable now only by
temporarily seeding `path` in code (see the comment on the enum case);
no persistent UI cost. The `chromeReserve` trailing padding was dropped from
Positions' header per the plan's own suggestion, verified on-device.

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

**Done** (`a27777b`). C4 had already made the chip tappable and built a
switcher sheet, so this task's real scope was: open the picker unconditionally
(was gated to `bikes.count > 1`, which blocked the add-bike path for anyone
with exactly one bike), build the inline add-bike disclosure in a new
`Capture/BikePickerSheet.swift`, restyle the chip to the two-line
key/name/caret, and extract `Bike.isValidInput` so the picker's form and
`BikeSetupView` share one validation rule instead of two. Verified on-device
(sheet list, disabled Save state, expanded form) via temporary state-default
flips, reverted before commit — no tap-simulation tool is available in this
environment.

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

**Done** (`db89f0b`) — **overridden by Kah**, not built per this plan's own
recommendation. Asked both flagged questions; Kah chose the option this plan
had listed as the *rejected* alternative (gear icon in the Library header,
pushing `BikeListView`) and chose to keep both add-bike paths (`BikeListView`
keeps its own `+`, on top of E2's inline form). Shipped as: a `gearshape`
icon on the Positions header → `path.append(.bikeList)`; `BikeListView`
unchanged.

Fitting a 4th control (gear) into the existing trailing row alongside
`LEADERBOARD →` / `SELECT` / `+` overflowed badly on-device (`LEADERBOARD →`
wrapped to five lines, `SELECT` to two) — there simply isn't enough width for
four controls on one line at this screen width once real position data makes
`SELECT` visible. Fixed by splitting the header into two rows: `SELECT` /
gear / `+` on the title row, `LEADERBOARD →` on the subtitle row — same
overall header height, no shared-`NavHeader` API change (Positions builds its
own header block; every other screen's simpler trailing slot is untouched).

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
(superseded — actual commit is `feat(bikes): reach bike management from a
Library header gear icon (Plan E3)`, `db89f0b`)

## E4. Cross-links: Leaderboard → Methodology, header parity

**Blocked / deferred.** No Methodology screen exists anywhere in the codebase
yet (`grep`-confirmed) — it's owned by Plans A2/D4, neither of which has
started. The hdr-link half of this task has nothing to attach to; land it
alongside whichever of A2/D4 builds the screen. The audit half is done now:
repo-wide search confirms no file references `IndexOverlay`, `HamburgerButton`,
or `indexOpen` outside this plan's own (already-landed) commits — the reveal
and comparison screens never depended on the removed index in the first
place. `LeaderboardView`'s back caret needs no changes; it's supplied by
`AppNavigationView`'s overlay, unconditional on `path` being non-empty.

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
— not yet made; nothing to commit until A2/D4 lands Methodology.

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

## Flagged decisions for Kah — resolved

1. **E3 bike-management home** — **decided against the recommendation.**
   Kah chose the Library-header gear icon over the `MANAGE BIKES →` picker
   link. Reintroduces one small persistent control the prototype's real IA
   doesn't have, scoped to the Library screen only (not a global overlay like
   the old hamburger).
2. **Keep `BikeListView`'s own `+`?** — **decided: keep both.** Add-bike now
   has two entry points (E2's inline picker form, and `BikeListView`'s
   existing `+` → `BikeSetupView` sheet), by Kah's choice rather than the
   plan's drop-one recommendation.
3. **`chromeReserve` after E1** — resolved during E1: dropped the extra
   trailing reserve on Positions specifically (verified on-device), left the
   token itself untouched since the back caret's leading reserve still needs
   it. E3 then hit a related-but-separate width problem (see E3 above) fixed
   with a two-row header, not a token change.
