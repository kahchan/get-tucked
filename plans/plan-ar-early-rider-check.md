# Plan AR: check for a rider before calibration

Kah, 2026-10-23, from the AM5 walk: a kitchen photo got through two bar taps and failed only
on CONFIRM SCALE with "No rider found. Step back…". Check first, and word the failure for
library photos.

**Status: AR1 + AR2 implemented, reviewed, uncommitted. Device pass outstanding.**

Built in `AnalysisEngine.checkRider` / `AnalysisError.message(fromLibrary:)` and
`CaptureView.riderCheckPassed`. `RiderCheckTests` green (blank-image test skips in the
Simulator). Review changes: `riderCheckPassed` blocks only on an `AnalysisError` and fails
open on any other error; `LiveCameraView`'s picker clears `pickerItem` after `onPicked`, so
the same photo can be re-picked after a rejection (the camera stays mounted).

## The key fact

`AnalysisEngine.validatePerson` (`AnalysisEngine.swift:369`) is one
`VNDetectHumanRectanglesRequest`: fast, and it needs no taps. It runs only inside
`analyse` (`:229`), after the scale math. Both photo entry points in `CaptureView.swift`
(`onPickFromLibrary` `:261`, `onBurstCapture` `:274`) go straight to `step = .calibrate`.

## AR1 · Rider check on photo arrival

- `AnalysisEngine`: add `static func checkRider(image: UIImage) async throws`. It
  wraps `validatePerson` with the same `cgImage` guard as `analyse`. `analyse` keeps its
  own call: it is the public entry, and the second request is cheap.
- `CaptureView`: both entry points call `checkRider` before `step = .calibrate`. If it
  throws, use the existing alert, and stay on `.pickPhoto`. The burst path checks the
  first frame only, the same frame that is shown for calibration.
- No spinner. The request takes well under the analysing beat, and a spinner would only flash.
- Side-on is out of scope: its flow does not call `validatePerson`.

**Verify:** a unit test that `checkRider` throws `noPersonDetected` on a blank image. On
device, test a kitchen photo from the library, then the camera pointed at a wall. The alert
must come before Calibrate Scale opens, and Try again must return to the camera. The review
sample photo must still reach Calibrate Scale.
**Simulator:** Vision human-rectangles throws `Code=9` "Could not create inference context".
The early check fails open on non-`AnalysisError` errors, so Simulator captures pass through
with no `#if`. `analyse` re-runs `validatePerson`, so a full analysis still cannot finish in
the Simulator.

## AR2 · Copy for library photos

The current text is for someone with a camera ("Step back…"). Someone with a library photo
cannot act on it.

- `AnalysisError`: add `func message(fromLibrary: Bool) -> String`. `errorDescription`
  keeps the camera text for every other caller.
- `CaptureView` passes `fromLibrary: burstImages.isEmpty` to the alert. A picked photo
  has no burst.

| Case | Library text |
|---|---|
| noPersonDetected | No rider found in this photo. Pick a photo of a person on a bike. |
| multiplePersonsDetected | More than one person in this photo. Pick one with only the rider. |
| personTooSmallInFrame | The rider is too small in this photo. Pick one where they fill more of the frame. |
| personClipsFrame | Part of the rider is cut off in this photo. Pick one that shows them head to wheel. |

Other cases keep their current text. The title and text key off `burstImages.isEmpty`, so the `runAnalysis` failure alert follows the same rule. The alert title stays "Capture failed" for the camera
path and becomes "Can't use this photo" for library photos.

**Verify:** a unit test for each library string; check both alert variants on device.

## Non-goals

- Live rider detection in the camera viewfinder.
- Changing the person-check thresholds (35% height, 5 px edge margin).
- Updating the review notes. Step 4 of `plans/app-review-notes.md` does not change.
