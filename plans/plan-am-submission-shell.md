# Plan AM — submission shell: the things that stop the upload

Status: planned 2026-08-10, from the App Store readiness audit. Everything here is
mechanical and device-independent — it can land in full before the on-device pass
(`plans/open-human-steps.md`) and does not depend on it.

Scope is the shell around the app, not the app. Six items:

- AM1 — no app icon exists; archive validation fails outright.
- AM2 — no privacy manifest; upload rejected with ITMS-91053.
- AM3 — `UILaunchStoryboardName` is an empty string.
- AM4 — no privacy policy or support page; both are required App Store Connect fields.
- AM5 — App Review notes for the no-bicycle problem.
- AM6 — photo-library purpose string doesn't cover the access taken; missing
  encryption-exemption key.
- AM7 — the correction experience has never had an end-to-end review; gates screenshots
  and carries a §3 exposure. Review-and-report, not a fix.

AM1–AM6 are mechanical and device-independent. **AM7 is not** — it waits on the
AK20/AK21/AK22 device pass, so it doesn't hold up the rest.

**Explicitly out of scope:** screenshots (need real captures from the device pass),
and everything in `plans/open-human-steps.md`.

## Context for the implementing agent

Read `CLAUDE.md` first, including the standing traps.

**Info.plist is generated.** `ios/project.yml` declares `info.path` +
`info.properties`, so `xcodegen generate` **overwrites**
`ios/GetTucked/Resources/Info.plist` from `project.yml`. Every plist change in this
plan goes in `project.yml`. Hand-edits to the plist are lost on the next generate.

Baseline: 374 tests green, 0 warnings, clean build (verified 2026-08-10, main @ 28c1fd9).

Verify: `cd ios && xcodegen generate`, then the suite on an available iPhone simulator.

---

## AM1 — App icon (stand-in)

`ios/GetTucked/Resources/Assets.xcassets/AppIcon.appiconset/` holds a `Contents.json`
declaring a 1024×1024 universal slot and **no image file**. Archive validation fails
on the missing icon, so nothing can be uploaded or sent to TestFlight.

Fix — an SVG source plus a rasterise step, both under `tools/appicon/` (NOT under
`ios/GetTucked/`, which XcodeGen sweeps wholesale into the bundle):

- `tools/appicon/appicon.svg` — 1024×1024, full-bleed `#080808`, single acid-yellow
  `#D9F020` mark: a caliper measuring a solid block — two vertical jaws with inward
  serifs, a filled rectangle between them. Font-free, all paths and rects, so
  rendering has no font dependency. Must read at 60px.
- `tools/appicon/make.sh` — rasterises to
  `ios/GetTucked/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png` via
  headless Google Chrome (present at `/Applications/Google Chrome.app`; no other
  rasteriser is installed and this plan adds no dependency), then flattens the alpha
  channel with a short CoreGraphics re-encode in `swift` — Chrome emits RGBA and the
  asset compiler errors on an icon with alpha.
- Update `Contents.json` to reference `icon-1024.png`.

Constraints, all three are validation failures if missed: exactly 1024×1024, **no
alpha channel**, **no corner radius** in the artwork (iOS masks the squircle itself).

This is a stand-in and is labelled as such — it unblocks TestFlight, it is not the
launch icon. iOS 18 dark and tinted variants are deliberately skipped until the real
icon lands.

Verify: `sips -g pixelWidth -g pixelHeight -g hasAlpha icon-1024.png` reports
1024 / 1024 / no; `xcodebuild archive` completes with no icon warning; the icon
renders on the simulator home screen.

## AM2 — Privacy manifest

No `PrivacyInfo.xcprivacy` exists anywhere in `ios/`. `@AppStorage` is used in six
files (`AppNavigation.swift`, `Components.swift`, `PositionDetailView.swift`,
`ComparisonView.swift`, `PositionListView.swift`), and `UserDefaults` is a
required-reason API — App Store Connect rejects the upload with ITMS-91053.

Fix — `ios/GetTucked/Resources/PrivacyInfo.xcprivacy`, added to the target's
`resources:` list in `project.yml` alongside the asset catalog:

- `NSPrivacyTracking` → `false`, `NSPrivacyTrackingDomains` → empty.
- `NSPrivacyCollectedDataTypes` → **empty array**. The app makes no network calls at
  all (grep for `URLSession` across `ios/GetTucked` returns nothing) — this is
  literally true, not a convenient reading.
- `NSPrivacyAccessedAPITypes` → one entry:
  `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` (access limited to the
  app itself).

No other required-reason category applies: no file-timestamp, disk-space, boot-time
or active-keyboard APIs are used (verified by grep). Do not pad the manifest with
categories the app doesn't touch.

Verify: file is present in the built `.app` (`find` the archive product); `plutil
-lint` passes.

## AM3 — Launch screen

`project.yml` sets `UILaunchStoryboardName: ""`. An empty value is not a launch
screen — the app can render letterboxed at a legacy resolution on modern iPhones.

Fix, in `project.yml`:

- **Delete** the `UILaunchStoryboardName` key entirely. Do not leave it empty.
- Add a `UILaunchScreen` dictionary with `UIColorName` pointing at a new
  `LaunchBackground` colorset in the asset catalog, set to `#080808` (`Theme.Palette.bg0`).
- No image, no text — a black field that hands over to `WelcomeView`.

**No logo on the launch screen (asked and decided 2026-08-10).** Apple's HIG treats the
launch screen as a loading state, not a branding moment: it should resemble the app's
first screen so the handover is invisible, and should avoid text. Two app-specific
reasons on top of that:

1. **There is no single first screen to match.** First run is `WelcomeView` (black field,
   "GET TUCKED" wordmark); every launch after that is `PositionListView`. A wordmark
   launch screen would match first run and mis-match every subsequent launch — the case
   the user sees hundreds of times.
2. **`UILaunchScreen` can't render the wordmark, only a picture of it.** No custom fonts,
   so a logo means a rasterised asset hand-aligned to `WelcomeView`'s live text. Any
   drift in size or position reads as a visible jump at handover.

A plain `bg0` field is the common denominator of both screens and disappears correctly
into either. Branding goes on the app icon (AM1) and `WelcomeView`, which is what the
user actually looks at. Revisit only if the wordmark becomes a genuine animated launch
beat — a different piece of work, not a plist key.

Verify: launch on the simulator and confirm the app fills the screen with no black
bars; `plutil -p` on the built plist shows `UILaunchScreen` and no
`UILaunchStoryboardName`.

## AM4 — Privacy policy and support pages

App Store Connect requires a reachable privacy policy URL and a support URL. `docs/`
has neither, and all three App Store badge links in `index.html` are `href="#"`.

Fix — two new pages in `docs/`, both mirroring `methodology.html`'s shell exactly
(same `<head>`, self-hosted fonts, `styles.css`, `site.js`, footer):

- `docs/privacy.html` — everything stays on device; no accounts, no analytics, no
  network calls, no third-party SDKs; what camera, photo-library and motion access
  are each used for and that none of it leaves the phone; deletion is deleting the
  position or the app; contact is the footer address. Keep it short and specific —
  it has to match the Nutrition Label ("Data Not Collected" across the board) and the
  AM2 manifest, or the mismatch is itself a 5.1 rejection.
- `docs/support.html` — what the app does, the three or four questions a buyer will
  actually ask, and the contact address.

Then link them: add `Privacy` and `Support` to the footer of `index.html` and
`methodology.html` (the footer already carries `hello@gettucked.app`). Leave the
three App Store badge `href="#"` links alone — they get the real product URL at
submission, and a dead link on a live page is worse than an obviously pending one.

Verify: both pages render, pass the same responsive check as `methodology.html`, and
carry no external requests (the no-CDN posture in `styles.css:7` is deliberate).

## AM5 — App Review notes

App Review runs in an office with no bicycle. A reviewer will install this, open the
camera, point it at a desk, and get nothing — and if any path dead-ends there it is a
Guideline 2.1 rejection. This is the highest-probability rejection vector in the
submission and the only defence is notes plus a working fallback.

Fix — `plans/app-review-notes.md`, holding the exact text to paste into the App Store
Connect review-notes field. It must cover:

- No account, no login, no server. Nothing to provide credentials for.
- **The app needs a photo of a person on a bicycle.** State it plainly, first.
- The library-picker fallback path, step by step, so a reviewer can complete a full
  measurement from a supplied photo without ever pointing the camera at a bike.
- A sample photo committed for the purpose and attached to the submission
  (App Store Connect review notes accept attachments). Kah supplies the photo —
  note it as a dependency, do not invent one. `fixtures/IMG_*` is gitignored
  (standing trap), so it goes somewhere tracked.
- Onboarding asks for a handlebar width before anything else — give them a value to
  type (420mm) so they don't stall on the first screen.
- Why each permission is requested: camera (capture), photo library (pick a source
  photo, save the result), motion (level/tilt gating during capture).
- That the tap-calibration step is deliberate and how to complete it.

Alongside the notes, walk the whole flow with no valid subject — camera at a wall,
then a photo with no person in it — and confirm every failure state offers a route
forward rather than a dead end. `plans/al14-failure-state-audit.md` covers the system
failures; this is the "reviewer has nothing to photograph" case specifically, which
that audit did not cover. Report what you find; fix only dead ends, and raise
anything larger rather than building it here.

## AM6 — Purpose string and encryption key

Two one-line fixes in `project.yml`.

`PositionDetailView.swift:605` requests `.readWrite` photo-library authorization, but
`NSPhotoLibraryUsageDescription` says only *"Get Tucked saves source photos to your
library."* A purpose string that doesn't describe the access actually taken is a
routine 5.1.1 rejection.

- `NSPhotoLibraryUsageDescription` → describe both directions: picking a source photo
  and reading back a saved capture. `NSPhotoLibraryAddUsageDescription` (add-only,
  used by `CaptureView.swift:608`) is already accurate — leave it.
- Add `ITSAppUsesNonExemptEncryption` → `false`. Not a rejection, but without it every
  single submission stops for a manual answer.

Verify: `plutil -p` on the built plist shows both; the photo prompt on device shows
the new string.

## AM7 — Correction experience review (pre-submission)

Not a blocker for the upload, but it gates the screenshots and it carries a §3 exposure,
so it belongs in the submission run rather than after it.

`MaskCorrectionEditor` is the newest surface in the app and the only one where the rider
edits the measurement by hand. It shipped 2026-08-08 (AK5) and **every** subsequent
change to it — AK20's swallowed brush, AK21's zoom, AK22's bounded fill — landed after,
with no end-to-end pass over the whole flow. Nobody has yet sat down and used it as a
rider rather than as a bug reporter.

**Reversing a tap specifically.** There are three ways back and they don't behave alike:

- **UNDO** drops the last action and replays from the original mask. Exact, always.
- **REMOVE CORRECTION** reverts the position to its automated measurement. Exact.
- **Tapping the same spot again** is the one a rider will reach for first, and it is
  *not* an inverse. It was roughly one pre-AK22; it isn't now. The second flood reads the
  state the first one left behind and bounds itself to a disc around the new seed, so
  tap-tap leaves a different mask than it started with. Either make re-tapping a true
  toggle, or make UNDO unmistakably the way back. Deciding that is the review's job, not
  this plan's.

**The §3 exposure.** A corrected area is a rider-authored number. The app must not give
it the same authority as an automated one without saying which it is — check that a
corrected position is distinguishable in the list, in the detail screen, and in a
comparison, and that AK7's disclosure copy still reads true now that the rider can move
the number themselves. This is the part that makes AM7 submission-relevant: it's the
honesty bar, not a polish pass.

Also worth the reviewer's attention: whether TAP vs BRUSH is understandable without the
hint text; whether INCLUDE/EXCLUDE is discoverable at all; whether the area visibly
changes on save; and whether zoom is discoverable now that it exists (there's no
affordance suggesting a pinch).

Read-and-report, one pass, like AL14 — findings land as items in
[`plan-ak-matte-completeness-and-accessibility.md`](plan-ak-matte-completeness-and-accessibility.md),
not as fixes inside this plan. Blocks any App Store screenshot that shows the correction
flow.

Depends on the AK20/AK21/AK22 device pass — there is no point reviewing the experience
until the mechanics are known good. AK23 (zoom feel) is already open from that pass.

---

## Waves

Grouped so no two agents touch the same file. `project.yml` is contended by AM1/AM2/
AM3/AM6, so those are one slice.

| Wave | Items | Files owned |
|---|---|---|
| 1 | AM1 + AM2 + AM3 + AM6 | `ios/project.yml`, `Assets.xcassets`, `PrivacyInfo.xcprivacy` (new), `tools/appicon/` (new) |
| 2 | AM4 + AM5 | `docs/privacy.html`, `docs/support.html` (new), `docs/index.html`, `docs/methodology.html`, `plans/app-review-notes.md` (new) |

Both waves run in parallel. The orchestrator runs the full suite once after the
merge — not per worker (delegation contract, `CLAUDE.md`).

AM7 is not in a wave. It's Kah on a device, after AK20/AK21/AK22 are confirmed, and it
runs alongside the two waves rather than queueing behind them.

## Verification

- Full suite green, 374 baseline, one run after merge.
- `xcodebuild archive` completes clean — this is the gate AM1/AM2/AM3 exist for, and
  a passing test suite says nothing about it.
- `plutil -p` on the archived `Info.plist`: `UILaunchScreen` present,
  `UILaunchStoryboardName` absent, `ITSAppUsesNonExemptEncryption` false, photo string
  updated.
- Icon: 1024×1024, no alpha, renders on the home screen.
- No new dependency added (Chrome and `swift` are both already on the machine).

## Non-goals

- Screenshots and store metadata — blocked on the device pass.
- The real app icon. AM1 is a stand-in and says so.
- Anything in `plans/open-human-steps.md`, and the AL10 / AL3a device items.
- Monetization, IAP, or paywall work. The site advertises $20 one-time; nothing in
  this plan touches purchase.
- Fixing failure states beyond dead ends found in AM5's no-subject walk.
- Fixing what AM7 finds. It reports; the fixes are plan AK items. The one exception is a
  §3 honesty failure — a corrected number presented as an automated one is a ship
  blocker, not a backlog entry.

## Decisions for Kah

- **D1 — is `hello@gettucked.app` a live mailbox?** It's in the site footer and both
  AM4 pages point at it. App Review will use it. Needs to actually receive mail.
- **D2 — where do the policy and support pages get served?** `docs/` has no `CNAME`,
  so today that's the GitHub Pages default URL, not `gettucked.app`. The URLs must
  resolve at submission time. Custom domain or the default — either works, pick one.
- **D3 — does an App Store Connect app record exist yet** (bundle ID
  `com.gettucked.app`, team `LVK77WYSK8`)? Nothing can be uploaded without it, and
  it's a Kah-only step.
- **D4 — the AM5 sample photo.** Which shot, and is it clear enough for a reviewer
  who has never seen a bike fit? Kah supplies it.
