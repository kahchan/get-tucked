# App Review notes — paste into App Store Connect

Sample photo (committed, also downloadable): `docs/review/sample-head-on.jpg`
Live at https://impreciselyaccurate.com/get-tucked/review/sample-head-on.jpg
Attach the same file to the submission.

## Text to paste

```
Get Tucked has no account, no login and no server. There are no credentials to provide. The app makes no network calls.

IMPORTANT: the app measures a photo of a person on a bicycle. It cannot do anything useful if the camera points at a desk or a wall. To review the full flow without a bicycle, use the sample photo below.

Sample photo: https://impreciselyaccurate.com/get-tucked/review/sample-head-on.jpg (also attached to this submission). It shows a rider head-on, upright, on a flat-bar bike.

Steps to complete one measurement:
1. Save the sample photo to the Photos app on the device.
2. Launch Get Tucked. Tap BEGIN SETUP.
3. Bike setup: enter any BIKE NAME. Under TYPE pick MTB (this sets BAR TYPE to FLAT). Enter 740 in HANDLEBAR WIDTH (MM). This is the real bar width of the bike in the sample photo. Tap SAVE BIKE.
4. SET THE SCENE (shooting tips) appears next: tap GOT IT. The camera opens; allow camera access. A one-time BEFORE YOU CAPTURE sheet appears: tap GOT IT. If the camera shows no bicycle, tap OR CHOOSE FROM LIBRARY and pick the sample photo.
5. Calibrate scale: tap the left end of the handlebars, then the right end, in the photo. The scale step is deliberate. The app has no other way to know real size, so it uses the handlebar width you typed as the ruler. Tap CONFIRM SCALE. Ignore the optional wheel check.
6. A second camera screen appears (SIDE-ON · 2 OF 2). This step is optional: tap SKIP SIDE-ON. The app then shows the rider and bike outline and the frontal area in cm2. Tap NAME POSITION, enter any name, tap SAVE POSITION, then VIEW ANALYSIS. If asked for photo library access, allow it.

Why each permission is requested:
- Camera: to photograph the rider's position.
- Photo library: to read a photo the user picks as the source for a measurement, to read back captures the app saved, and to save source photos to the library.
- Motion: to keep the camera level during capture.

All photos and measurements stay on the device. Privacy policy: https://impreciselyaccurate.com/get-tucked/privacy.html
Support: https://impreciselyaccurate.com/get-tucked/support.html
```

## Status

- Sample photo: `IMG_0966.jpg` from `website images/`, resized to 1500 px tall, committed to `docs/review/`. It needs a push to GitHub Pages before the URL resolves.
- Not done: the AM5 walk of the flow with no valid subject (camera at a wall, photo with no person). The failure states are unaudited.
- Button labels above were read from source (`BikeSetupView`, `CaptureView`, `LiveCameraView`). They were not run on a device.
