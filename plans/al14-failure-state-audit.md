# AL14 — Failure-state audit (§12)

Read-and-report against `ios/GetTucked/` source, 2026-08-08. No code changed.

## Capture failures (§12 table 1)

| Condition | Status | Evidence |
|---|---|---|
| No person detected | **Implemented** | `Analysis/AnalysisEngine.swift:60` `.noPersonDetected` |
| Multiple people detected | **Implemented** | `Analysis/AnalysisEngine.swift:61` `.multiplePersonsDetected` |
| Person clipped at edge | **Implemented** | `Analysis/AnalysisEngine.swift:62` `.personClipsFrame` (single generic message, not per-limb `[head/feet/elbows]` as spec's copy shows — deviation, not a gap) |
| Phone not level | **Implemented** | `Capture/LiveCameraView.swift:646-653` `CaptureGate.blockedReason`, gates the shutter (`allPassed` = `levelOK && tiltOK`, line 682) |
| Phone not perpendicular | **Partially implemented** | Same gate, but measures phone *pitch* not perpendicularity to the wheel plane — labeled TILT not PERP, a recorded deviation (AL1, CLAUDE.md Deviations) |
| Low segmentation confidence | **Partially implemented** | `bgConfidence`/`bgOK` computed and shown as a BG status pill (`LiveCameraView.swift:666-670, 952`), but advisory only — doesn't gate the shutter and has no refusal copy ("Background is making you hard to separate...") anywhere in source |
| Strong backlight | **Missing** | No backlight/luma detection in source — AL3b (per-region luma metric) isn't built yet per plan-al |
| Handlebar endpoints not detected | **N/A by design** | App is tap-only, no Vision endpoint auto-detection to fail (AL13 deviation) — this row's premise doesn't apply |
| Multi-capture spread too high | **Implemented** | `Analysis/AnalysisEngine.swift:67` `.burstSpreadTooHigh`, wired in AL10 (Wave 4) |

## System failures (§12 list 2)

| Condition | Status | Evidence |
|---|---|---|
| Camera permission denied → Settings deep-link | **Implemented** | `Capture/LiveCameraView.swift:532` explanation text + `:538` `UIApplication.openSettingsURLString` |
| Photo Library permission denied → Settings deep-link | **Missing** | No Settings deep-link anywhere. `Capture/CaptureView.swift:551-557` (`saveToCameraRoll`) silently `return`s on non-authorized status; `Views/PositionDetailView.swift:537-541` (`loadAsset`) silently returns `nil` on denial. Plan AL14's "known-implemented" note is wrong for this row — it does not carry over from camera denial. |
| Motion permission denied | **Missing** | `Capture/LiveCameraView.swift:855-859`: if `isDeviceMotionAvailable` is false, `levelOK`/`tiltOK` are silently forced to `true` — the gate passes with no measurement and no user-facing explanation, rather than refusing and explaining |
| Storage full, surfaced before capture | **Missing** | No disk-space check found anywhere in `Capture/` or `Views/` |
| Backgrounded mid-capture discards cleanly | **Missing** | No `scenePhase`/`willResignActive`/`didEnterBackground` handling found in `Capture/CaptureView.swift` or `LiveCameraView.swift` |
| ARKit unsupported device, graceful fallback | **N/A — moot** | App never adopted ARKit; capture pose comes from `CMMotionManager` (see AL1 deviation). "ARKit" appears only in a stale doc comment (`LiveCameraView.swift:9`) and in `HowItWorksView.swift`'s new inputs line. No ARKit import, so no unsupported-device case exists to fall back from. |

## Logical edge cases (§12 list 3) — bonus pass, not in original AL14 scope

| Condition | Status | Evidence |
|---|---|---|
| Handlebar width sanity check vs. frame | **Missing** | No such check found in `Capture/` or `Analysis/` |
| Bag tap selects nothing useful | **N/A** | Bags (AL8) unbuilt; AL8a closed "not buildable as tap-to-segment" (`plans/matte-verdict.md`) |
| Delta below noise floor | **Implemented** | `Views/ComparisonView.swift:900,1199`, `Analysis/AnalysisMath.swift:363` (`isDistinguishable`) |
| Cross-bike comparison warning banner | **Implemented** | `Views/ComparisonView.swift:88-90` `isCrossBike`, MARK "Cross-bike warning" at line 495 |

## Candidates worth a future fix (flagged, not built here)

1. **Fixed.** `saveToCameraRoll` now surfaces denial via a dedicated `.alert` (Settings
   deep-link, matching camera-denial copy shape); `PositionDetailView.loadAsset` sets
   `photoLibraryDenied`, shown as an in-placeholder `PhotoLibraryDeniedNotice` instead of
   a permanently blank photo box. `ios/GetTucked/Capture/CaptureView.swift`,
   `ios/GetTucked/Views/PositionDetailView.swift`.
2. **Fixed.** `CameraSession.startMotion`'s no-motion fallback now sets
   `motionAvailable = false` (and `levelOK`/`tiltOK` false) instead of faking a pass;
   `CaptureGate.blockedReason` and `allPassed` both gate on it. `CaptureGateTests`
   covers the new branch. `ios/GetTucked/Capture/LiveCameraView.swift`.
3. **Fixed.** New `StorageGate` (50MB floor, sized for a 3-shot burst) checked at
   session start and on a 3s timer; gates `allPassed`/`blockedReason` alongside
   LEVEL/TILT/motion. `StorageGateTests` covers the pure threshold.
   `ios/GetTucked/Capture/LiveCameraView.swift`.
4. **Fixed.** `CaptureView` now reads `\.scenePhase`; backgrounding during `.analysing`/
   `.analysingSideOn` cancels the in-flight `Task` and calls `resetForNewCapture()`, with
   a `Task.isCancelled` guard in both analysis functions so a resolving-late continuation
   can't stomp the reset. Pure predicate `shouldDiscardOnBackground` covered by
   `CaptureBackgroundDiscardTests`. `ios/GetTucked/Capture/CaptureView.swift`.
