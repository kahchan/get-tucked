# Plan C — UX flow fixes

Status: **done** (C1-C6; C7 superseded by Plan D7, not separately needed).
C1 `00c8c61`, C2 `2566861`, C3 `9d517ad`, C4 `bd09c6f` (pulled in
phase2-live-capture-plan item 2 as a prerequisite), C5 `5571819`,
C6 `3fed904`. Written 2026-07-03; updated same day after unpacking the
design prototype (`inspiration/unpacked/` — see Plan D). Where C and D touch
the same screen, C fixes the flow and D restyles it: read both before starting
a task on CaptureView, ComparisonView, or LeaderboardView.
Do tasks in order; one commit per task.
Same verify loop as Plans A/B (xcodebuild test, iPhone 17 simulator).

Flow today: `+` → Set the Scene → pick bike → live camera → calibrate →
analysing → side-on pick → reveal → name → done. The review found six concrete
holes in it, plus two decisions flagged for Kah.

## C1. Show the matte at the reveal moment (trust + error catching)

`AnalysisEngine` already returns `AnalysisResult.maskImage` — and the UI never
shows it. The user currently has no way to see *what was measured*, so a bad
matte (missing legs, half the bike) saves silently. This is the single highest
value flow fix.

- File: `ios/GetTucked/Capture/CaptureView.swift`.
- Pass the captured photo into `RevealStep` (it already receives `result`).
- Above the hero number, show the photo with the matte composited: matte as an
  acc-tinted overlay at ~50% opacity over the photo (Core-Image-free approach:
  `ZStack { Image(photo); Image(mask).renderingMode(.template)
  .foregroundStyle(Theme.Palette.acc.opacity(0.5)) }`, both `.scaledToFit()`).
  Add a `MASK ON/OFF` toggle using the `ToggleTab` pattern from
  `PositionDetailView`.
- Add `GhostButton(label: "RETAKE")` under the `AccentButton` → sets
  `step = .pickPhoto`, clears `tapPoints` and `pendingResult`.

**Acceptance:** after a capture, the reveal shows the silhouette over the
photo; RETAKE returns to the camera; NAME POSITION continues as before.

## C2. Side-on step must be skippable

`PhotoPickStep` for side-on has no way out except picking a photo (or Cancel,
which abandons the *whole* capture including the valid head-on result).

- File: `ios/GetTucked/Capture/CaptureView.swift`.
- Give `PhotoPickStep` an optional `onSkip: (() -> Void)?` (default nil);
  when non-nil render `GhostButton(label: "SKIP SIDE-ON")` below the picker.
- Wire it in the `.pickSideOnPhoto` case: `onSkip = { step = .reveal }`
  (the existing `runSideOnAnalysis` guard already tolerates a nil side-on).

**Acceptance:** a head-on-only capture can be completed and saved.

## C3. Hide the global hamburger during capture

`AppNavigationView` overlays the hamburger on **every** screen, including the
camera, where it collides with `BikeChip` in the HUD's top-left, and the
capture wizard, where a mid-flow jump via the index would silently discard a
capture in progress.

- File: `ios/GetTucked/Design/AppNavigation.swift`.
- Condition: `if !indexOpen && path.last != .capture && path.last != .setTheScene`
  — hide on `.capture`; `.setTheScene` keep visible (its NavHeader title is
  centred, no collision) unless it looks cramped in practice.

**Acceptance:** camera HUD top-left shows only the bike chip; hamburger is
back after the flow completes or cancels.

## C4. Kill the bike-picker step; pick the bike in the camera HUD

> **Superseded by Plan E2** (`plan-e-nav-ia.md`): the tappable bike chip →
> picker now also carries inline add-bike, since the index that used to host
> add-bike is being removed. Implement via E2, not here.

With one bike (the common case) the current flow still demands a NEXT tap on a
full-screen picker. The design intends the bike chip in the camera HUD to be
the switcher. Depends on: `plans/phase2-live-capture-plan.md` item 2 (tappable
`BikeChip` → picker sheet) — do that item first if not landed.

- File: `ios/GetTucked/Capture/CaptureView.swift`.
- Initial step becomes `.pickPhoto`. Initialise
  `selectedBike = bikes.first` in `.onAppear` (positions can't be created with
  zero bikes — `PositionListView` already disables `+` when `bikes.isEmpty`).
  Better default if cheap: most recently used bike
  (`positions.sorted(by: capturedAt).last?.bike`) — otherwise first.
- Delete `BikePickerStep` and the `.selectBike` case.
- The tappable `BikeChip` (phase2 item 2) is then the only bike switcher;
  switching bikes before calibration re-reads `handlebarWidthMm` at
  calibrate time, which already happens post-capture — no analysis change.

**Acceptance:** `+` → Set the Scene → camera in two taps; bike switchable from
the chip; saved position carries the chip-selected bike.

## C5. Fix comparison semantics (A/B, sign, honesty)

Today `PositionListView` sorts the selected pair by area so A is always the
smaller — which means `deltaPct` is always positive and `DeltaHero` can *only
ever* say "+X% LARGER" in amber. The improvement state (acc, "SMALLER") is
unreachable, and the user's selection order is discarded.

- File: `ios/GetTucked/Views/PositionListView.swift` — change
  `@State private var selected: Set<UUID>` to an ordered `[UUID]` (append on
  select, removeAll(where:) on deselect, cap at 2). Pass the pair in
  **selection order**: first selected = A (the reference), second = B.
  Delete the area-sort in the compare button action.
- File: `ios/GetTucked/Views/ComparisonView.swift` — `DeltaHero` copy per the
  prototype (screen 12): signed % hero, caption `"<A|B> IS SMALLER · N cm²"`
  (winner + absolute delta), keeping acc = smaller / amb = larger. Layout
  details in Plan D6.
- Integrate Plan A4 here if it has landed (indistinguishable state).
- **Cross-bike warning (spec §9):** when `positionA.bike?.id !=
  positionB.bike?.id`, show a full-width amber banner between the panels and
  the hero: `"DIFFERENT BIKES — differences may reflect the bikes, not the
  rider."` (`Theme.mono(11)`, amb border 1px, bg1 fill.)

**Acceptance:** selecting "loaded" then "unloaded" shows a negative delta in
acc; selecting across bikes shows the banner; same-position pairs (Plan A4)
show WITHIN MEASUREMENT NOISE.

## C6. Delete a position

There is currently **no way to delete a saved position** anywhere in the app.

- File: `ios/GetTucked/Views/PositionDetailView.swift` — add
  `GhostButton(label: "DELETE POSITION")` at the bottom of the scroll content,
  with a `confirmationDialog` (mirror `BikeSetupView.deleteBike`'s pattern).
  On confirm: `context.delete(position)` then pop — the view is pushed via
  `path`, so pass `@Environment(\.dismiss)` or have the wrapper handle the
  now-missing model (the existing `PositionDetailWrapper` "Position not found"
  fallback makes this safe; prefer an explicit `dismiss()`).
- `PositionMetrics` is `.cascade` from `Position`, so metrics go with it.

**Acceptance:** delete → confirmation → back on the list, row gone, no crash
on the wrapper.

## C7. Leaderboard semantics — superseded by Plan D7

The prototype resolves this: deltas are `−X% vs upright` against your
most-upright position (largest area, auto-derived, labelled
`YOUR UPRIGHT BASELINE`), with proportional bars and a `LATEST` tag.
Implement per Plan D7; no separate caption task needed.

---

## Flagged decisions for Kah (do NOT implement without a call)

1. ~~Baseline~~ — **resolved by the prototype** (Plan D7): baseline is the
   derived most-upright (max-area) position per filter; `isBaseline` stays
   unused; no manual toggle in this phase.
2. **Set-the-Scene fatigue.** The coaching screen shows on every capture.
   The prototype only shows it during onboarding (before the practice
   capture). Options: (a) keep always, (b) show once then offer a "SCENE
   TIPS" ghost button in the camera HUD, (c) add DON'T SHOW AGAIN.
   Recommendation: (b), which matches the prototype's flow.
3. **What frontal area includes** — Plan A1's verdict gates any pipeline
   change; the prototype's methodology copy says rider **and bike**, so the
   experiment decides feasibility, not intent.
4. **Onboarding additions** (Plan D8: How-It-Works intro, practice capture,
   noise-floor prompt, comparison prompt) — real scope; confirm sequencing.
