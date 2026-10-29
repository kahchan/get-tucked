# App Review notes — paste into App Store Connect

Sample photo (committed, also downloadable): `docs/review/sample-head-on.jpg`
Live at https://impreciselyaccurate.com/get-tucked/review/sample-head-on.jpg (HTTP 200, checked 2026-10-23).
Attach the same file to the submission.

Paste the block below twice: as the reply to the 2.1 message, and into App Review Information → Notes.
Fill in the two `[...]` values in section 1 first.

## Text to paste

```
1. SCREEN RECORDING
Attached. Recorded on [DEVICE] running iOS [VERSION]. It starts at app launch and follows the steps in section 3.
Not applicable, with reason:
- Account registration, login, account deletion: the app has no accounts. Nothing to register, log in to or delete.
- User-generated content: none is shared. Photos and measurements stay on the device and no other user can see them.
- Paid content: none in the app. Get Tucked is a paid-upfront app with no in-app purchases or subscriptions. Every feature is available after download.

2. PURPOSE AND AUDIENCE
Get Tucked measures the frontal area of a cyclist and their bike, in cm2, from a head-on photo. Frontal area is the largest part of aerodynamic drag that a rider controls with position and luggage.
Audience: bikepackers, ultra-distance racers, and touring and gravel riders who want to compare positions and bag setups.
Problem: a wind tunnel or lab session costs hundreds to thousands of dollars. Get Tucked gives a repeatable measurement at home against a plain wall.
How: the user enters their handlebar width once. The app uses it as a ruler to turn pixels into centimetres. Each reading shows its error bar, and when two setups differ by less than their combined error, the app says so instead of claiming one is better.

3. SETUP AND MAIN FEATURES
No login and no credentials. The app measures a photo of a person on a bicycle, so it cannot do anything useful with the camera pointed at a desk or a wall. To review the full flow without a bicycle, use the sample photo: https://impreciselyaccurate.com/get-tucked/review/sample-head-on.jpg (also attached). It shows a rider head-on on a flat-bar bike.
1. Save the sample photo to Photos on the device.
2. Launch Get Tucked. Tap BEGIN SETUP.
3. Enter any BIKE NAME. Under TYPE pick MTB. Enter 740 in HANDLEBAR WIDTH (MM), the real bar width in the sample photo. Tap SAVE BIKE.
4. On SET THE SCENE tap GOT IT. Allow camera access. On BEFORE YOU CAPTURE tap GOT IT. Tap OR CHOOSE FROM LIBRARY and pick the sample photo.
5. Tap the left end of the handlebars, then the right end. Tap CONFIRM SCALE. Ignore the optional wheel check.
6. On SIDE-ON · 2 OF 2 tap SKIP SIDE-ON (optional step). The frontal area in cm2 appears. Tap NAME POSITION, enter a name, tap SAVE POSITION, then VIEW ANALYSIS.
7. Compare: go back to POSITIONS, tap + and repeat steps 4 to 6 (tap the bar ends slightly differently). On POSITIONS tap both positions, then COMPARE (2).
Other screens: the menu button opens BIKES, LEADERBOARD (positions ranked by area) and HOW IT WORKS.

4. EXTERNAL SERVICES
None. The app makes no network calls and contains no third-party SDKs: no analytics, advertising, authentication, payment processor, AI or data service. All processing runs on the device with Apple frameworks: Vision (person segmentation and body pose), Core Image, AVFoundation (camera), Core Motion (keeps the camera level), PhotoKit and SwiftData (local storage).

5. REGIONAL DIFFERENCES
None. The app works the same in all regions. It has no region-specific features or content. The interface is in English and uses metric units.

6. REGULATION AND THIRD-PARTY MATERIAL
Not applicable. Get Tucked is a tool for bicycle position and equipment setup. It is not a medical device and makes no health, diagnostic or safety claims. It contains no protected third-party material. All text and images, including the sample photo, are our own.

PERMISSIONS
- Camera: to photograph the rider's position.
- Photo library: to read a photo the user picks, read back captures the app saved, and save source photos.
- Motion: to keep the camera level during capture.

Privacy policy: https://impreciselyaccurate.com/get-tucked/privacy.html
Support: https://impreciselyaccurate.com/get-tucked/support.html
```

## Screen recording shot list

Record on a physical iPhone on the latest iOS. Delete the app first, so onboarding shows. Turn on airplane mode before you start: it shows that the app needs no network.

1. Home screen → tap the Get Tucked icon (launch must be in the recording).
2. Steps 2–6 of section 3, with the sample photo or a real head-on photo of you. Allow each permission prompt on camera.
3. Detail screen after VIEW ANALYSIS: scroll once so the area and error bar show.
4. Step 7: second position, then COMPARE (2). Hold on WITHIN MEASUREMENT NOISE or the difference row.
5. Menu → LEADERBOARD → HOW IT WORKS. Stop.

## Status

- Labels in section 3 were checked against source on 2026-10-23 (`WelcomeView`, `BikeSetupView`, `SetTheSceneView`, `CaptureView`, `LiveCameraView`, `PositionListView`). Not yet walked on a device; the recording is that walk.
- Section 4 checked against source: no `URLSession`/`StoreKit`/web views, no Swift packages in `project.yml`, imports are Apple frameworks only.
- Not done: the AM5 walk of the flow with no valid subject (camera at a wall, photo with no person). The failure states are unaudited.
