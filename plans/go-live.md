# Go live

Status 2026-10-21: site live (dark) at https://impreciselyaccurate.com/get-tucked/ from
`main:/docs`. The domain belongs to the `kahchan.github.io` repo (root redirects here). All App Store CTAs are still `href="#"`. App not
submitted. Next session: App Store submission.

## Done

- Site: photo hero (matte + bones + dimensions), side-on pair, three device
  screenshots, compare shot swaps outline/photo on click. No cm² on the site
  outside the app screenshots (Kah's call).
- Plan AM wave 1 (813ab4a): icon (stand-in), privacy manifest, launch screen, plist.
- iPhone-only (4656a62).
- `-stagedCameraFrame` DEBUG hook (302e646) for capture screenshots in the Simulator.
- Developer Program enrolled (individual).
- Signing: `DEVELOPMENT_TEAM` was the certificate's personal ID (LVK77WYSK8), not the
  team. Now `EN7N37J6DU` (paid team kept the free team's ID). Release archive OK.
- AM4 privacy + support pages and AM5 review notes (`plans/app-review-notes.md`, sample
  photo at `/review/sample-head-on.jpg`). Contact: gettucked.app@gmail.com.
- Camera-denied screen now offers OR CHOOSE FROM LIBRARY (was a dead end for review).
- App Store screenshot set: `website images/appstore/`, five PNGs at 1320×2868
  (6.9"). Gitignored. The 11 Pro shots are upscaled about 18%.

## Kah — before submission

1. Accept the Paid Apps Agreement. Add banking and the W-8BEN tax form. Not needed
   for TestFlight; needed before the paid release.
2. Create the App Store Connect record for `com.gettucked.app`. The record gives
   the App Store URL. Needed before the upload.
3. On the device, check: the icon on the home screen, no letterbox at launch, the
   acid accent in system sheets and dialogs. Do the AM7 correction-flow review.

## Claude — submission (Plan AM wave 2 and the upload)

1. **Build 1.0 (5) uploaded 2026-10-27** (main b3ff363: Plan AS). **Build 1.0 (3) uploaded 2026-10-22** (main 447d3fb: Set the Scene photos). 1.0 (2)
   went up 2026-10-17 (8bbfc0a: Plans AP, AQ, icon r7). Both via
   `xcodebuild archive` + `-exportArchive` with `ios/ExportOptions.plist`. A duplicate
   1.0 (1) went up first by mistake (build 1 already existed): ignore or expire it. Bump
   `CFBundleVersion` in `project.yml` before every upload. Internal TestFlight first; external
   group + public link + Beta App Review after Kah's own pass.
2. AM5 no-subject walk is still open (camera at a wall, photo with no person).
3. Store metadata: subtitle, description, keywords, privacy answers ("Data Not
   Collected"), age rating, price.
   - Price: US$9.99 (decided 2026-10-22). Site updated; set the same tier in App Store
     Connect. Outreach drafts in `marketing/` still say $20.

## After 1.0 is approved

- Custom product pages (App Store Connect): variants of the listing with their own
  screenshots and promotional text, each with its own URL, for each outreach audience.

## Launch day — site

1. Put the real App Store URL in the three CTAs: top bar, hero, and buy section.
2. Make `og-hero.png`. Without it, shared links show a blank card.
3. ~~Press kit~~: done 2026-10-22. `docs/press.html` + `docs/press/get-tucked-press-kit.zip` (fact sheet source: `marketing/press-fact-sheet.txt`). Rebuild the zip if the store shots change.
4. ~~Custom domain~~ — done 2026-10-21, 4ad56d2; DNS at iwantmyname, domain verified on GitHub.

## After launch

Outreach in the order in `marketing/outreach-drafts.md`: TestFlight racer seeding,
then Reddit, then press. Fill-ins: App Store URL, methodology URL (live now:
`https://impreciselyaccurate.com/get-tucked/methodology.html`), TestFlight link, press kit.
