# Go live

Status 2026-10-13: site live (dark) at https://kahchan.github.io/get-tucked/ from
`main:/docs`, commit 8885039. All App Store CTAs are still `href="#"`. App not
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

1. Upload when Kah says (`ios/ExportOptions.plist`, `xcodebuild -exportArchive
   -allowProvisioningUpdates`). Internal TestFlight first; external group + public
   link + Beta App Review after Kah's own pass.
2. AM5 no-subject walk is still open (camera at a wall, photo with no person).
3. Store metadata: subtitle, description, keywords, privacy answers ("Data Not
   Collected"), age rating, price.
   - Price: the site says $20. Apple's nearest tier is US$19.99. Make the site and
     the store say the same thing.

## After 1.0 is approved

- Custom product pages (App Store Connect): variants of the listing with their own
  screenshots and promotional text, each with its own URL, for each outreach audience.

## Launch day — site

1. Put the real App Store URL in the three CTAs: top bar, hero, and buy section.
2. Make `og-hero.png`. Without it, shared links show a blank card.
3. Make the press kit, or remove the dead "Press kit →" link.
4. Optional: custom domain. Add `docs/CNAME`, then set DNS.

## After launch

Outreach in the order in `marketing/outreach-drafts.md`: TestFlight racer seeding,
then Reddit, then press. Fill-ins: App Store URL, methodology URL (live now:
`/get-tucked/methodology.html`), TestFlight link, press kit.
