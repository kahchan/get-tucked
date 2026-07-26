# Plan AF — Default the live capture to 2× zoom

**Status:** PLAN — awaiting Kah's go-ahead.
**Trigger:** Kah, 2026-07-26: the "Stand back 5–6m, zoom in 2–3×" coaching (Plan W3,
SetTheSceneView) "makes little sense with our camera controls" — correct, and worse
than nonsense: the live capture pipeline (`LiveCameraView` ~563) uses
`.builtInWideAngleCamera` at 1× and exposes **no zoom control at all**. The W3 copy
asks for something the in-app camera cannot do. The perspective rationale stands
(shooting from farther away at longer focal length flattens the front-wheel-forward
inflation); the mechanism was never built.

## AF1 — 2× by default in the capture session

- Device selection: prefer a virtual multi-cam via a fallback chain —
  `.builtInTripleCamera` → `.builtInDualCamera` → `.builtInDualWideCamera` →
  `.builtInWideAngleCamera` (today's device last). On virtual devices, setting
  `videoZoomFactor` engages the real telephoto at its switch-over factor, so 2× is
  optical (or the high-quality 2× sensor crop on 48 MP wides); on plain wide it's a
  digital 2× crop — still the right trade, the calibration geometry benefits more
  than the pixels lose.
- On session configure: `lockForConfiguration`, set `videoZoomFactor = 2.0` clamped
  to the device's `minAvailableVideoZoomFactor…maxAvailableVideoZoomFactor`, unlock.
  Note: on virtual devices the wide lens is 1.0 and factors are relative to it, so
  2.0 means "2× field of view" as the user understands it — but verify against
  `virtualDeviceSwitchOverVideoZoomFactors` on-device (a triple-camera device may
  express the 2× crop at a different factor); the constant must mean *visual 2×*.
- Photo output must inherit the zoom (it does — `videoZoomFactor` applies to the
  connection) — verify the captured photo, not just the preview, is 2×.
- Framing gate interplay: the bbox-height floor (0.35) and clip margins in
  `validatePerson` are unchanged — the rider standing 5–6 m back now *fills* the
  frame at 2× instead of shrinking, which is the whole point.

## AF2 — Explicit zoom control (small, in keeping with house style)

A default the user can't see or undo is hidden magic — and tight spaces (hallway,
garage) may not allow 5–6 m. Add a minimal explicit control on the live capture HUD:
a **1× / 2× toggle chip** (Space Mono, 0 radius, acid highlight on the active state),
defaulting to 2×. No continuous pinch on the live camera — two honest stops keep the
scale story simple and the copy true. Selection is per-capture (no persistence) unless
Kah wants it sticky — flag at review.

## AF3 — Copy truth pass

- SetTheSceneView W3 line becomes true: e.g. "Stand back 5–6m — we're zoomed to 2×
  for you" (final voice at implementation; concise, mono, no fake precision).
- Check for other copy referencing zooming the camera (capture error strings in
  AnalysisEngine mention "zoom in from where you are" — now true via AF2; verify
  each string still reads honestly with the new default).

## Verification

- Unit-testable: the fallback-chain selection order and the clamped-zoom math
  (pure helpers).
- On-device (required, camera has no simulator): preview and captured photo both 2×;
  toggle works; a 5–6 m frontal fills the frame and passes the framing gate; wheel
  vs bar disagreement (Plan K numbers) should shrink vs 1× captures at equal
  distance — that's the measurable win worth eyeballing in MEASUREMENT DETAIL.

## Out of scope

- Continuous zoom / arbitrary factors on the live camera.
- Any change to the calibration-image pinch zoom (Plan AA) — unrelated surface.
