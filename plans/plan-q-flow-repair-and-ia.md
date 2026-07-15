# Plan Q — Flow Repair & IA (get in fast, get out clean)

Status: **planned** (2026-07-15). No code yet. Derived from a full-flow review of every screen
(2026-07-15 session): the individual screens are in good shape post Plans E–P; the problems are
in the **seams** — the back-stack after a save, exits from capture, a coaching screen that never
stops appearing, and bikes hidden behind a settings cog.

**Scope:** navigation and flow only. No changes to analysis math, capture mechanics, overlays,
or any displayed number. **No SwiftData schema changes anywhere in this plan** (Q3's flag uses
`@AppStorage`, deliberately — see the CLAUDE.md stop-rule about migrations).

**Read first:** `CLAUDE.md` (design language, stop-rules), `plans/plan-e-nav-ia.md` (why there
is one `NavigationStack` and no tab bar — this plan works *within* that decision, it does not
reopen it), `plans/plan-n-motion-and-experience-polish.md` (motion rules for anything that
animates). This doc is written for an implementing agent who has not seen the review
conversation.

---

## The principle that governs everything here

**A returning rider mid-session gets from the list to a live viewfinder in one tap, and back in
one tap.** The app's premise is iteration — many captures per garage session. Every mandatory
interstitial, every stranded back-stack entry, is a tax paid on *every* iteration. Onboarding
can be generous; the loop must be lean.

Corollary for exits: **cancel means "back to where I started," never "back to a screen I only
passed through."**

---

## Current flow map (for orientation)

```
First run:  Welcome → [sheet] BikeSetup → (save) → PositionList (empty) → CTA → SetTheScene → Capture → Done
Return:     PositionList → + → SetTheScene → Capture(8-step machine) → Done → View Analysis / Capture Another
Match:      PositionDetail → MATCH THIS POSITION → SetTheScene(ref) → Capture(ghost) → …
Compare:    PositionList → 2 checkboxes → COMPARE bar → Comparison
Bikes:      PositionList → gearshape icon → BikeList → [sheet] BikeSetup
```

Key files:

- `ios/GetTucked/Design/AppNavigation.swift` — `AppScreen` enum, the single `NavigationStack`,
  the floating back caret.
- `ios/GetTucked/Capture/CaptureView.swift` — the `CaptureStep` state machine, the success step
  (`CaptureSuccessStep`), every `dismiss()` call this plan touches.
- `ios/GetTucked/Views/PositionListView.swift` — root header (gear + plus + LEADERBOARD link).
- `ios/GetTucked/Views/SetTheSceneView.swift` — the coaching interstitial.
- `ios/GetTucked/Views/WelcomeView.swift` + `ios/GetTucked/App/ContentView.swift` — first-run
  branch.
- `ios/GetTucked/Capture/LiveCameraView.swift` — camera HUD (top bar, ✕, control stack).

---

## Q1 — Back-stack repair (bug fix; do this first)

### Q1.1 "VIEW ANALYSIS" must not leave `.setTheScene` under the detail

`CaptureSuccessStep`'s `onViewAnalysis` (CaptureView.swift, `.done` case wiring around line
236) currently does:

```swift
if !path.isEmpty { path.removeLast() }
path.append(.positionDetail(savedPositionID))
```

At that moment the path is `[.setTheScene, .capture]` (ordinary) or
`[.positionDetail(old), .setTheScene, .capture]` (match flow). Popping one element leaves
`.setTheScene` in the stack, so **back from the freshly saved position lands on the coaching
screen**, whose only affordance starts a new capture. In the match flow the stack ends up
`[.positionDetail(old), .setTheScene, .positionDetail(new)]`.

**Fix:** replace, don't pop:

```swift
path = [.positionDetail(savedPositionID)]
```

Root (`PositionListView`) stays under it; back from the detail goes to the list. This is
correct for both the ordinary and the match flow — after saving a *new* position, the old
reference detail has served its purpose and does not need to remain in the stack. (Note: once
Q3 lands, `.setTheScene` may not be in the path at all — `path = [...]` is right in every
variant, which is why it beats any removeLast arithmetic.)

### Q1.2 Cancel pops past `.setTheScene`, back to the entry point

Every ✕ in the capture flow (LiveCameraView HUD `onCancel`, the NavHeader ✕ on non-camera
steps, the error alert's Cancel) calls `dismiss()`, which pops exactly one screen — stranding
the user on the coaching screen they only passed through.

**Fix:** replace `dismiss()` with a single exit routine on `CaptureView` that trims the path
back to the entry point:

```swift
private func exitCaptureFlow() {
    while case .capture = path.last { path.removeLast() }
    while case .setTheScene = path.last { path.removeLast() }
}
```

(Pattern-match, don't `==` — both cases carry associated values.) `while` rather than
`removeLast(2)` so it stays correct when Q3 removes `.setTheScene` from some variants. Extract
this trimming rule into a small pure function over `[AppScreen]` (it can live next to
`AppScreen`) and unit-test it — path arithmetic is exactly the kind of logic that silently rots.

Route **every** capture-flow exit through it: the HUD ✕ on both camera steps, the NavHeader ✕,
and the error alert's Cancel button.

### Q1.3 Success-screen exits

On the `.done` step, ✕ (and any future "DONE" affordance) should pop to root — the save is
complete, the natural landing is the list, where the N7 highlight tick pays off. `exitCaptureFlow()`
already produces this for the ordinary flow; for the match flow it lands on the old reference
detail, which is acceptable (the user chose not to view the new analysis). No special-casing.

### Acceptance (Q1)

- Save → VIEW ANALYSIS → back ⇒ position list. Never SetTheScene.
- Match flow: save → VIEW ANALYSIS → back ⇒ position list (old detail no longer stacked).
- ✕ from any capture step ⇒ the screen the flow was entered from (list, or the reference
  detail in match flow), one tap, no intermediate coaching screen.
- Pure path-trim function has tests covering: ordinary, match, tips-skipped (post-Q3), and
  already-empty paths.

---

## Q2 — Discard confirmation once analysis exists (bug-adjacent)

One tap on ✕ during `.pickSideOnPhoto`, `.calibrateSideOn`, `.reveal`, or `.namePosition`
silently throws away a completed head-on analysis (two photos, calibration taps, a wait). The
app confirms deleting a *saved* position but not abandoning an unsaved one — same loss, no
guard.

**Fix:** in `CaptureView`, gate `exitCaptureFlow()` behind a confirmation dialog **iff
`pendingResult != nil` and `step != .done`**. Copy, matching existing dialog style
(`confirmationDialog`, destructive role):

> **Discard this capture?**
> Discard — Cancel

Before analysis exists (`.pickPhoto`, `.calibrate`, `.analysing`) ✕ exits immediately, as
today — nothing meaningful is lost. On `.done` the position is saved; ✕ exits immediately.

RETAKE on the reveal step is **not** an exit and gets no dialog — it's an explicit, labelled
choice to redo (and stays inside the flow).

### Acceptance (Q2)

- ✕ on reveal/name/side-on steps ⇒ dialog; Discard ⇒ entry point per Q1.2; Cancel ⇒ stays put.
- ✕ before analysis, and on `.done` ⇒ immediate exit, no dialog.

---

## Q3 — SetTheScene: coach once, then get out of the way

Today the coaching interstitial appears on **every** capture, forever, with no skip — including
"MATCH THIS POSITION", where the user has by definition captured before and the ghost overlay
*is* the framing guidance.

### Q3.1 First-time-only for ordinary captures

- Add `@AppStorage("hasSeenSetTheScene") var hasSeenSetTheScene = false` (no schema change; the
  spec's `UserSettings` model doesn't exist yet and this must not force it into existence).
- Entry points (`+` in the list header, the empty-state CTA) push `.setTheScene(referenceID:
  nil)` when the flag is false, `.capture(referenceID: nil)` directly when true.
- `SetTheSceneView`'s GOT IT sets the flag before continuing.

### Q3.2 Match flow skips coaching unconditionally

`PositionDetailView`'s MATCH THIS POSITION button pushes `.capture(referenceID:
position.persistentModelID)` directly — never `.setTheScene`, regardless of the flag.

The same-kit reminder currently living at the bottom of SetTheSceneView ("Comparing to an
earlier shot? Same kit, same helmet…") is the one piece of that screen the match flow genuinely
needs. **Move a copy to PositionDetailView**: a `Theme.mono(11)` / `fg3` caption directly under
the MATCH THIS POSITION button, condensed:

> Same kit, same helmet, same bar position — clothing changes your silhouette as much as a
> small bag does.

It stays on SetTheSceneView too (first-time users still see it there).

### Q3.3 Tips stay discoverable — a TIPS affordance in the camera HUD

Per Kah's standing preference (explicit, discoverable controls over hidden functionality), the
coaching content must remain one tap away after it stops being mandatory:

- In `LiveCameraView`'s top bar, add a small "TIPS" text button (mono 11, bold, `fg3`, kerning
  0.5 — same recipe as the SKIP link in `controlStack`), between the leading chip and the
  ghost/✕ cluster. Head-on step only is fine (`showsBikeChip == true` configuration); side-on's
  HUD is already busier and the rider has just seen the head-on one.
- It presents `SetTheSceneView` **as a sheet** (not a nav push — pushing would re-enter the
  `.setTheScene` route and tangle the Q1 path rules). In sheet mode the button reads "GOT IT"
  and just dismisses. Give `SetTheSceneView` no new mode flag if avoidable — its `onContinue`
  closure already abstracts what the button does; the sheet wrapper passes `dismiss`.

### Acceptance (Q3)

- Fresh install: first `+` shows SetTheScene; every later `+` opens the camera directly.
- MATCH THIS POSITION always opens the camera directly, ghost armed; the kit reminder is
  visible on the detail screen before entering.
- TIPS in the HUD re-opens the coaching content as a sheet; dismissing returns to the live
  camera with all capture state intact.
- Q1's path trimming still exits correctly when `.setTheScene` was never pushed.

---

## Q4 — Onboarding momentum: bike saved → straight to shooting

Today: Welcome → BEGIN SETUP → bike sheet → save → **dropped on an empty positions list** →
must tap the CTA to proceed. The BikeSetup subtitle literally promises "Two facts. Then we
shoot." — deliver it.

**Fix:** after the *first* bike is saved from the Welcome path, land in `AppNavigationView`
with the capture flow already pushed.

Suggested mechanics (implementer may find better within the existing structure): `ContentView`
owns the `bikes.isEmpty` branch. Give `AppNavigationView` an optional `initialPath: [AppScreen]`.
`WelcomeView`'s sheet `onSave` sets a `@State` flag on `ContentView` (e.g.
`launchIntoCapture = true`); when the branch flips to `AppNavigationView`, pass
`initialPath: [.setTheScene(referenceID: nil)]`. SetTheScene is *always* shown here regardless
of Q3's flag — this is the moment coaching earns its place — and GOT IT sets
`hasSeenSetTheScene` as usual.

Backing out of that pushed flow (✕ or back) lands on the empty positions list — which remains
the fallback state, with its existing CTA.

Do **not** touch the `bikes.isEmpty → WelcomeView` branch itself (deleting the last bike
intentionally returns the app to first-run).

### Acceptance (Q4)

- Fresh install: Welcome → save bike → SetTheScene appears without any extra tap; ✕ from there
  ⇒ empty positions list.
- Second run (bike exists): app opens on the positions list as today.

---

## Q5 — Root IA: the index menu returns (revised 2026-07-15; supersedes the cog→link fix)

> An earlier draft of this section replaced the gear with a `BIKES` header link. Kah flagged
> the deeper problem in review: the root screen is accumulating hallway doors with
> inconsistent affordances. This revision consolidates them instead.

### The problem

`PositionListView` is doing two jobs. It is the **workspace** (list, selection checkboxes,
compare bar) and the only **hallway** to everything that isn't the capture loop — and every
hallway door looks different: a `gearshape` icon whose semantics are wrong (a cog says "app
settings"; bikes are *domain data* — each bike's bar width is the ruler behind every number),
a `LEADERBOARD` text link on the subtitle row, a How-It-Works link that exists only
contextually on number screens, and no home at all for Phase 4's Settings (noise floor,
consent) and Events. Fixing one door leaves the inconsistency.

### The rule

**The surface is the loop; the index is everything else.**

- **Surface (root header):** `☰ … POSITIONS … +`. Capture is the only action that earns
  header placement. Rows, checkboxes, compare bar: unchanged.
- **Index (☰, root screen only):** `BIKES · LEADERBOARD · HOW IT WORKS` — and, when Phase 4
  arrives, `SETTINGS` and `EVENTS` land here without another IA renegotiation.

### Relationship to Plan E1 (read this before assuming it's a revert)

Plan E1 (2026-07-07) removed a hamburger index — deliberately, and its reasons were sound
*for that menu*: it was modeled on the prototype's **storybook screen-switcher** (dev chrome,
not app chrome), it treated `POSITIONS / LEADERBOARD / BIKES` as peer screens, and it did
`path = [screen]` (replace) on tap. None of that returns:

1. **POSITIONS is not in the menu.** The positions list is the root; the index is a menu of
   *secondary* destinations only. There are no "peer screens."
2. **Items push** (`path.append(screen)`) — never replace the path. The back caret returns to
   root as from any pushed screen.
3. E1 was decided when there were **two** secondary destinations; a header link beat a menu.
   At four-going-on-six, the calculus inverts — the cog was the symptom of a header running
   out of room.

The design file's own language ("a single linear flow with a hamburger index menu",
CLAUDE.md design section) called for exactly this; E1 removed a bad *implementation* of it,
not the idea. Do not resurrect the deleted `IndexOverlay` wholesale from git history
(`911afbe` removed it) — its path semantics were the bug — but its visual treatment is fair
reference.

### Specifics

- **Hamburger button:** top-left on the root header, `iconTapTarget` frame. Glyph: SF Symbol
  `line.3.horizontal` at `iconSize`/medium — per the Q8.4 decision (2026-07-15), all chrome
  icons are SF Symbols.
- **The index itself:** full-screen overlay in the design language — near-black field,
  destinations as a large typographic list (`Theme.heading`, Barlow Condensed bold, generous
  size), mono ordinals (`01 / 02 / 03`) in `fg4`, acid accent on press, `SectionDivider`s
  between rows, ✕ top-right to close. Present it as a ZStack overlay in `AppNavigationView`
  (like the old one) or `fullScreenCover` — implementer's choice; it must never appear in
  `path`. Entrance/exit obey `Theme.Motion` and Reduce Motion.
- **Contents now:** `BIKES` → `.bikeList`, `LEADERBOARD` → `.leaderboard`,
  `HOW IT WORKS` → `.howItWorks`. Tap ⇒ close menu, push screen.
- **Remove:** the `gearshape` button and the subtitle-row `LEADERBOARD` HeaderLink. The
  subtitle row keeps only the hint text (see Q7 — the row may be empty in some states; that's
  fine).
- **Deliberate dual entry:** `HowItWorksLink` on reveal/detail/comparison screens stays —
  contextual "why is this number trustworthy" beats making the index the only route.
- **Unchanged:** `BikeListView` (DEBUG tools stay there), `LeaderboardView`, all pushed-screen
  back behaviour.

### Decided against (so the implementer doesn't relitigate)

- **Leaderboard as a root sort-toggle** (RECENT/RANKED on the list itself): same data, but the
  bike-type filter bar, rank chrome, and podium moment earn a screen — and merging ranked mode
  with the selection checkboxes complicates the root's one job.
- **Keeping a surfaced LEADERBOARD link alongside the index:** a half-in-half-out IA (some
  secondary destinations in the menu, some as links) recreates today's inconsistency.
- **A settings screen now:** there are no app-level settings yet. When Phase 4's
  `UserSettings` exists, `SETTINGS` joins the index — that's the point of it.
- **N-way comparison** (raised in the same review): the comparison screen stays strictly
  pairwise — two photos and one noise-gated delta against a stated reference is the only
  defensible read (spec §3). The n-way answer already exists as the leaderboard (ranked,
  deltas vs best, noise-gated); what it lacks — scoping to a session's shots, choosing a
  baseline — is precisely Phase 4's Events/timeline. Selection stays capped at 2; Q7.2 makes
  the pairwise contract legible.

### Acceptance (Q5)

- Root header is `☰ … POSITIONS … +` — no gearshape, no LEADERBOARD link.
- Index opens ⇒ BIKES / LEADERBOARD / HOW IT WORKS; each pushes with a working back caret;
  the menu never appears in the navigation path; ✕ closes with capture/selection state intact.
- `HowItWorksLink` on number screens unchanged.
- Everything fits at SE width; Reduce Motion collapses the menu transition.

---

## Q6 — Head-on library fallback (DECIDED 2026-07-15: library picker, no self-timer)

Head-on capture had no solo path at all: no self-timer, no library fallback (side-on gets
`onPickFromLibrary`; the head-on `LiveCameraView` call site does not). The target user is a
solo bikepacker — someone must press the shutter while the rider is on the bike, in position.

**Kah's decision: add the library fallback; do not build a timer.** Rationale, recorded so it
isn't relitigated: a timer means propping the phone at hub height, rushing back to the bike,
clipping in, and settling into an *honest* position inside a countdown — then walking back to
review framing, repeatedly. The realistic solo workflow is a tripod + burst/remote (or a
helper) in the system Camera app, then importing the good frame. The library pick serves
that; a timer serves a workflow nobody would actually tolerate. (A timer could still be a
v1.x extension if field feedback demands it — it is *decided against for this plan*, not
banned forever.)

### Implementation

Mirror the side-on call site exactly — the plumbing already exists end to end:

- `LiveCameraView` already renders `LibraryFallbackLink` whenever `onPickFromLibrary` is
  non-nil (see the side-on configuration in `CaptureView`'s `.pickSideOnPhoto` case).
- At the head-on call site (`CaptureView`, `.pickPhoto` case), pass:

  ```swift
  onPickFromLibrary: { image, identifier in
      selectedImage = image
      assetIdentifier = identifier
      tapPoints = []
      step = .calibrate
  }
  ```

  No `saveToCameraRoll` (the photo is already in the library — that's the point), which is
  exactly how the side-on path behaves. `savePosition` already persists
  `position.headOnPhotoIdentifier = assetIdentifier` and the image bytes unconditionally, so
  detail-view reload works with zero further changes.

### What this deliberately does not add

A library-picked head-on photo bypasses the live gates (level / perpendicular / background
pills) — tilt and camera height are unknown. **Do not add new warning UI for this in Q6.**
The existing advisories (scale warning, wheel check, shoulder-width sanity) still apply to
the imported photo and are the honest signals we can actually compute; inventing an
"unverified tilt" badge would be asserting knowledge we don't have (spec §3 cuts both ways).
If imported-photo captures turn out noticeably noisier in practice, that's a future plan with
data behind it. The Set-the-Scene coaching (camera at hub height, fill the frame) is the
guidance that covers the solo/tripod workflow — unchanged.

### Acceptance (Q6)

- Head-on camera step shows the same library link side-on has; picking an image lands on
  CALIBRATE SCALE with the image, and the saved position's detail view shows the photo.
- Live-capture path unchanged (still saves to camera roll, still no PHAsset identifier).
- No new warnings, gates, or copy beyond the link itself.

---

## Q7 — Small polish (bundle with any of the above)

1. **"Tap two to compare."** shows even with 0–1 positions. Show it only when
   `positions.count >= 2`. With Q5's links moved into the index, the subtitle row holds only
   this hint — let the row collapse entirely when there's nothing to say.
2. **Comparison order is invisible.** First checkbox tapped = A (reference), second = B —
   deliberate, but nothing tells the user. When exactly one position is selected, swap the hint
   text to `Reference set. Tap one more to compare.` (mono 11, `fg3`, same slot). No new UI.

---

## Q8 — Consistency sweep (UI drift audit, 2026-07-15)

Findings from a full-screen audit. The system is mostly disciplined — `NavHeader` everywhere
except two *documented* exceptions (PositionListView's bespoke two-row root header per Plan F1,
and the camera steps which own their HUD per G2), shared `SegmentedToggleBar`/`MetricRow`/
`SectionDivider`, tokenized motion. The drifts below are real; fix them as one pass. The
DEBUG-only screens (`MatteCheckView`, `PoseCheckView`) are exempt — not product surface.

### Q8.1 One screen margin (the visible one)

`Theme.Space.screenMargin` (16) is the standard everywhere in `Views/` — but these use
`Theme.Space.lg` (24) for screen-edge padding:

- **Every CaptureView step view:** `RevealStep` (buttons + metrics block),
  `NamePositionStep` (headline, hint, button), `CaptureSuccessStep` (both buttons),
  `WheelbaseEntryPrompt` (its *buttons* — its text already uses screenMargin, so this view
  disagrees with itself), and `TapCalibrationStep`'s instruction banner.
- **`BikePickerSheet`** (sheet content + SAVE & SELECT button).
- **`WelcomeView`** — see the exception below.

**Rule: screen-edge horizontal padding is `screenMargin`, always.** `lg` remains a vertical-
rhythm/internal token. The user walks GOT IT (16) → capture steps (24) in one flow today; this
is the most visible drift in the app.

**Exception requiring Kah's eyeball:** `WelcomeView`'s hero wordmark at 24 is a composition
choice, not a bug. Change it to `screenMargin` in the same pass **but Kah verifies the hero on
device before it commits** — if it reads worse, Welcome keeps `lg` with a comment saying it's
deliberate.

### Q8.2 Field indent: strip the padding baked into `FieldLabel` / `MonoField`

Both components carry `.padding(.horizontal, Theme.Space.lg)` internally
(`Components.swift:142` and `:161`), so their real indent depends on what the caller adds on
top: **40** in `BikeSetupView` (wrapped in screenMargin) and `WheelbaseEntryPrompt`, **24** in
`NamePositionStep` and `BikePickerSheet`. Same field style, three indents.

**Fix:** remove the internal horizontal padding from both components (components should not
own screen-level margins); every call site then gets exactly `screenMargin` from its
container. Call-site inventory to audit after the change: `BikeSetupView` (+ its
`TypeToggle`/`RimStandardToggle`/`OptionalSectionToggle`, which also self-pad with `lg`),
`NamePositionStep`, `WheelbaseEntryPrompt`, `BikePickerSheet`'s inline add form,
`WheelSizeFields`. `MonoField`'s underline hugs its padded frame, so after the change the
underline spans margin-to-margin — verify it matches `SectionDivider` optics on device.

### Q8.3 Button stack order

Currently a 2–2 split: Ghost-above-Accent on `RevealStep` (RETAKE / NAME POSITION) and
`WheelbaseEntryPrompt` (SKIP RULER / USE THIS); Accent-above-Ghost on `CaptureSuccessStep`
(VIEW ANALYSIS / CAPTURE ANOTHER) and `BikeSetupView` (SAVE / DELETE).

**Rule: `AccentButton` is always the bottom-most control; `GhostButton`s stack above it.**
Primary action at the thumb; side benefit: DELETE BIKE moves off the easiest-reach position.
Flip `CaptureSuccessStep` and `BikeSetupView`.

### Q8.4 One icon family per job

- Add: SF `plus` on PositionListView vs `Text("+")` (Space Mono) on BikeListView's NavHeader.
- Close: `Text("✕")` in `fg3` (CaptureView NavHeader) vs `fg` (LiveCameraView HUD).
- Back: SF `arrow.left` in `fg2`.

**Fix (DECIDED 2026-07-15, Kah): SF Symbols for all chrome icons.** One source, one weight,
one size — every bare-icon control uses an SF Symbol at
`.font(.system(size: Theme.Control.iconSize, weight: .medium))` inside an `iconTapTarget`
frame, matching the existing back arrow and PositionListView buttons:

- Add: `plus` everywhere — convert BikeListView's `Text("+")`.
- Close: `xmark` everywhere — convert both `Text("✕")` sites (CaptureView NavHeader,
  LiveCameraView HUD).
- Back: `arrow.left` (already SF, unchanged).
- Q5's hamburger: `line.3.horizontal` (supersedes Q5's drawn-rules suggestion — chrome icons
  are one family now).

Chrome color rule: `fg3` on the dark canvas, `fg` only over live camera video (where `fg3`
would vanish). Content/text marks are *not* chrome and stay typographic: FacingChip's ◂/▸,
BikeSetupView's boxed "?", the SetTheScene tip glyphs, and button arrows (→).

### Q8.5 Row-height token

`PositionRow` and `BikeRow` are 60; `RankRow` (LeaderboardView) is 64. Add
`Theme.Control.listRowHeight = 60` and use it in all three — unless the rank row's
two-line-plus-delta content genuinely needs 64 on device, in which case comment why.

### Q8.6 Merge the two empty-state components

`EmptySlate` (BikeListView, LeaderboardView) and `EmptyStateView` (PositionListView) are the
same component with and without a CTA. Fold `EmptySlate` into `EmptyStateView` (CTA already
optional) and delete it.

### Q8.7 `HowItWorksLink` reuses `HeaderLink`

`HowItWorksLink` re-implements `HeaderLink`'s look minus the `kerning(0.8)`. Rebuild it on
`HeaderLink` (same label, same arrow) so the two acid text-links can't drift again.

### Acceptance (Q8)

- `grep 'padding(.horizontal, Theme.Space.lg)'` over `Views/` + `Capture/` returns only
  internal-layout uses (e.g. column cells), no screen-edge margins; DEBUG screens exempt.
- Fields sit at exactly `screenMargin` on every form; no double-padding anywhere.
- Every two-button stack ends with the `AccentButton`.
- One add glyph, one close glyph, consistent chrome colors; row heights tokenized;
  `EmptySlate` deleted; `HowItWorksLink` built on `HeaderLink`.
- Welcome hero margin change explicitly approved (or reverted with a comment) by Kah.

---

## Sequencing

Q1 → Q2 → Q3 → Q4 → Q5 → Q6 → Q7 → Q8. Q1 first because Q2 and Q3 both route through its
`exitCaptureFlow()`. Q6 is independent of everything and can land anywhere after Q1. Q8 last
so the sweep covers surfaces the earlier increments touched (Q5's index, Q3's TIPS link)
rather than being re-broken by them. Each increment is independently shippable; run the full
`GetTuckedTests` suite (101 green as of Plan P) after each, plus the new path-trim tests from
Q1. Manual pass per increment: the acceptance list above, on device, both the ordinary and the
match flow.

## What this plan deliberately does not do

- No settings screen (premature until Phase 4's UserSettings exists — `SETTINGS` joins the
  Q5 index then).
- No n-way comparison view (see Q5 "Decided against" — the leaderboard plus Phase 4 Events is
  the designed answer).
- No changes to the capture step machine's internal order, the reveal ceremony, or any
  analysis/display gating.
- No SwiftData schema changes.
