# Plan H — Matte display AND measurement trustworthiness

Status: **not started**. Written 2026-07-07 after Kah confirmed the Reveal
screen's MASK toggle paints the *entire* frame acid-yellow (wall, carpet,
sofa, rider — everything), then pushed back that the **area itself** also
looks wrong — correctly. There are **two independent problems** here; the
first analysis only caught one.

| # | Problem | Evidence | Fixed by |
|---|---------|----------|----------|
| 1 | **Wrong ruler (scale)** — the cm² number is untrustworthy | reveal shows "SHOULDER WIDTH 20.8 cm" (a child's is ~30–34 cm) | H5 (verify/repair calibration) |
| 2 | **Unviewable mask (display)** — can't visually check the segmented region at all | MASK toggle tints the whole frame | H2 (compositing fix) |

These are unrelated: fixing the display does **not** fix the number, and vice
versa. The display bug is what has *hidden* problem #1 — with the overlay
painting everything, there was no way to see whether the mask hugged the
rider. Do H2 first so the region becomes visible, then H5 so the ruler is
trustworthy.

## Problem 2 root cause — the display (analysis, not a guess)

The Reveal MASK overlay is broken **independently of segmentation quality** —
it would paint the whole frame yellow even with a perfect mask.

1. **The mask is a grayscale luminance image with no alpha channel.**
   `AnalysisEngine.cgImageFromPixelBuffer` (~line 212) builds it with
   `CGColorSpaceCreateDeviceGray()` + `CGImageAlphaInfo.none` — white (255) =
   person, black (0) = background, and *every pixel fully opaque*.

2. **Reveal renders it with `.renderingMode(.template)`**
   (`CaptureView.swift` `RevealStep`, ~line 350) tinted `acc.opacity(0.5)`.
   Template rendering stencils on the **alpha channel**, not luminance: it
   fills every *opaque* pixel with the tint. The mask is opaque everywhere
   (alpha none) → the whole rectangle is tinted. The black/white silhouette
   data is never consulted.

3. **MatteCheck works** because it displays the raw grayscale directly
   (`Image(uiImage:)`, no `.template`) — white silhouette on black, which is
   visually correct as a standalone image. That's the proof the Vision
   segmentation is fine; only Reveal's compositing is wrong.

**Fix direction:** stop abusing a luminance mask as an alpha stencil. Produce
a proper composited overlay — foreground pixels tinted, background pixels
*actually transparent* — and draw it plainly over the photo. The same overlay
(and the stored raw mask behind it) also delivers the matte-on-detail feature
Kah asked for, without re-running segmentation.

## Problem 1 root cause — the scale (the number is built on a bad ruler)

The reveal readout **"SHOULDER WIDTH 20.8 cm"** is a physical impossibility —
a child's biacromial width is ~30–34 cm. Shoulder width and frontal area are
computed from the **same** `pixelsPerCm`, so this is a direct readout that the
ruler is wrong. `AnalysisMath.shoulderWidthCm` reduces to:

```
shoulderWidth_cm = (shoulderSpanPx / handlebarSpanPx) × handlebarWidth_cm
```

20.8 vs ~30 → the ruler is off by ~1.4–1.6×. And because
**area ∝ handlebarWidth²** (area = count / pixelsPerCm², pixelsPerCm =
handlebarPixels / handlebarWidthCm), that scale error hits the area
*squared*: a 1.5× ruler error is a ~2.3× area error.

**Leading cause: handlebar-width mismatch.** In the test shots the rider holds
a bare ~760 mm MTB flat bar, but calibration uses the bike record's
`handlebarWidthMm` — almost certainly a default road-ish ~440 mm. Feed the
wrong bar length in and every pixel→cm conversion (and the area) is wrong by
the square of the mismatch. The bar width is the single most sensitive input
in the pipeline and the one thing the app can't measure — it trusts the bike
record. (Secondary suspects, ruled less likely but worth eyeballing once the
mask is visible: tap points not exactly on the bar ends; pose mis-detecting
the shoulders; an aspect-ratio assumption in `maskPixelsPerCm`, see H5.)

**A3 already flags this.** `scaleWarning` fires when shoulder width is outside
30–60 cm; 20.8 is below the floor, so the reveal should already be showing
"Shoulder width reads 21 cm — check your taps and the bike's bar width." It's
likely just below the scroll fold. The app is *already* telling us the ruler
is wrong — H5 is about acting on that, not detecting it.

Same verify loop as Plans A–G (`xcodebuild test`, iPhone 17 simulator,
Conventional Commits, one commit per task; UI checks via static-state-seeded
screenshots since there's no tap simulation).

## Flagged decision for Kah

**What to persist for the matte: raw grayscale mask, or a baked tinted
overlay?** Recommendation: **store the raw grayscale mask** (PNG, downscaled
to match the stored photo like `compressedForStorage` does). Rebuild the
tinted overlay at display time from it. Rationale: the raw mask is smaller,
lossless, and — critically — recolorable, so a future theme/opacity change
doesn't leave old positions with a baked-in wrong tint. The alternative
(store the finished RGBA overlay) is marginally simpler to display but bakes
in today's accent color permanently.

## Tasks

Do **H2 first** (makes the mask visible → unblocks judging the region), then
**H5** (makes the number trustworthy). H1 is H2's prerequisite. H3/H4 are the
storage/detail extension and can follow.

### H1. Pure matte-overlay renderer (fixes the core display bug)

New file `ios/GetTucked/Analysis/MatteRenderer.swift` (`#if canImport(UIKit)`).

- `tintedOverlay(mask: CGImage, color: UIColor, alpha: CGFloat) -> UIImage?`
  — returns an RGBA image the same size as the mask where foreground pixels
  (luminance ≥ 128) are `color` at `alpha` and background pixels are fully
  transparent. Read the mask bytes striding by `bytesPerRow` (same
  row-padding discipline as the pixel-count fix in `bd8a273`).
- Extract the per-pixel mask→RGBA mapping into a small helper that takes a
  raw byte buffer + dimensions (like `AnalysisMath.countForegroundPixels`) so
  it's unit-testable without a real CGImage. Test in `GetTuckedTests`: a
  synthetic mask where one pixel is foreground and one is background →
  assert the foreground pixel is tinted+opaque and the background pixel is
  transparent (alpha 0).

### H2. Reveal uses the overlay, not template rendering (the actual rectification)

File: `ios/GetTucked/Capture/CaptureView.swift` (`RevealStep`, ~line 350).

- Replace the `Image(uiImage: result.maskImage).renderingMode(.template)...`
  overlay with `Image(uiImage: <overlay>).resizable().scaledToFit()`, where
  `<overlay>` is `MatteRenderer.tintedOverlay(...)` built from the mask.
- Build the overlay once (e.g. `@State` computed on appear, or a `let` from
  the result) rather than every layout pass.
- **This task alone fixes the reported bug.** H3/H4 extend it to storage; they
  can land separately.

**Acceptance:** on the Reveal MASK view, only the rider is tinted acid-yellow;
the wall/carpet/sofa show through untinted. PHOTO/MASK toggle still works.

### H3. Persist the mask on the position

Files: `ios/GetTucked/Models/Position.swift`, `CaptureView.swift` (`savePosition`).

- Add `var maskData: Data?` to `Position`. **Additive optional field → no
  SwiftData migration stage needed** (lightweight automatic migration; this
  is the non-migration kind the project's "stop and ask" rule is about — flag
  noted, no stage required). Store the raw grayscale mask as PNG, downscaled
  to match `photosData` (mirror `UIImage.compressedForStorage`, but keep it
  lossless PNG for the mask rather than JPEG so the silhouette edge isn't
  compression-fuzzed).
- Populate in `savePosition` from `pendingResult`'s mask.

### H4. Show the stored matte on the detail screen (Kah's earlier request)

File: `ios/GetTucked/Views/PositionDetailView.swift`.

- When `position.maskData` exists, add a PHOTO/MASK toggle over the head-on
  photo (reuse the existing `PhotoToggle`/`ToggleTab` pattern already in this
  file for FRONTAL/SIDE-ON), compositing the stored mask via
  `MatteRenderer.tintedOverlay` over the stored photo — no re-running Vision.
- Older positions saved before H3 have no `maskData`; just hide the toggle
  for them (don't back-fill by re-segmenting — that would show a *different*
  mask than the one that produced the stored number).

**Acceptance:** opening a position captured after H3 lets you toggle to a
MASK view showing the real silhouette that produced its cm² figure; positions
saved earlier simply show no MASK toggle.

### H5. Make the number trustworthy — scale verification & handlebar-width guardrails

This is the *measurement* half — the H1–H4 display work does not touch it.
The 20.8 cm shoulder reading proves the ruler is wrong; this task is about
catching and preventing that, not silently "correcting" a number we can't
independently verify.

- **Confirm the mechanism first (needs the device, after H2):** on a real
  capture, read the reveal's shoulder-width + `scaleWarning` line, and check
  the selected bike's `handlebarWidthMm` against the *physical* bar in frame.
  Expectation: they mismatch (bare MTB bar vs a road-width bike record). This
  is the confirmation step before any code — don't skip it.
- **Make the scale warning impossible to miss.** Today `scaleWarning` is one
  amber line that scrolls off (Kah didn't see it). Options to decide on:
  move it directly under the hero cm² number (not below the metric rows);
  and/or make an implausible shoulder width a *soft block* — the number still
  computes, but the reveal leads with "SCALE LOOKS OFF" and the primary
  action becomes RE-CHECK CALIBRATION rather than NAME POSITION. Recommend
  the reposition at minimum; the soft-block is a product call for Kah.
- **Surface the ruler on the reveal.** Add a metric row showing the bike's
  handlebar width actually used ("BAR WIDTH · 440 mm") so a mismatch is
  self-evident at capture time, next to the shoulder-width sanity number.
- **Add the missing aspect-ratio guard (code, testable now).**
  `AnalysisMath.maskPixelsPerCm` rescales by width ratio only — correct only
  if the Vision mask preserves the source aspect ratio. Add a pure check
  `maskMatchesSourceAspect(maskW:maskH:sourceW:sourceH:tolerance:)` and, in
  `analyse`, fold a mismatch into an honest wider uncertainty or a warning
  rather than silently distorting area. Unit-test the predicate.
- **Do NOT auto-scale or fudge the number to "look right."** Per spec §3
  every displayed number must be defensible; the fix is a correct ruler +
  honest warnings, not a correction factor.

**Acceptance:** a capture whose shoulder width is implausible surfaces that
prominently (not below the fold); the handlebar width in use is visible on the
reveal; the aspect-ratio predicate is unit-tested; no silent number massaging.

## Relationship to other work

- **Two tracks, do H2 then H5:** H1→H2 (+H3/H4) is the *display/storage*
  track; H5 is the *measurement-trust* track. They're independent — shipping
  one without the other still leaves the other problem — but H2 is the
  prerequisite for *judging* H5 (you can't tell if the mask is right until you
  can see it).
- Independent of Plan G (side-on live capture) — no file overlap beyond both
  touching `CaptureView`, in different regions.
- **Correction to the earlier `bd8a273` framing:** the row-padding fix removed
  one *inflation* source in the pixel count, but it did NOT make the number
  trustworthy — the dominant error is the scale (handlebar width), which is
  squared into the area. H5, not `bd8a273`, is what addresses the number.
- H5 overlaps Plan A's measurement-integrity intent (A3 built the shoulder
  sanity check; H5 acts on it). Keep A5 (burst uncertainty) still deferred.
