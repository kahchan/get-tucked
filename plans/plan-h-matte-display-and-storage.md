# Plan H — Matte display & storage (show the real mask)

Status: **not started**. Written 2026-07-07 after Kah confirmed the Reveal
screen's MASK toggle paints the *entire* frame acid-yellow (wall, carpet,
sofa, rider — everything), while the DEBUG MatteCheck screen shows a correct
silhouette on the same kind of photo.

## Root cause (analysis, not a guess)

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

### H1. Pure matte-overlay renderer (fixes the core bug)

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

## Relationship to other work

- H1's renderer is the shared primitive; H2 is the minimal fix; H3+H4 are the
  storage/detail extension (Kah's earlier "store the matte, don't re-run"
  ask). They can ship as separate commits in that order.
- Independent of Plan G (side-on live capture) — no file overlap beyond both
  touching `CaptureView`, and in different regions.
- Does **not** change the frontal-area number or the segmentation pipeline —
  the row-padding count fix (`bd8a273`) already addressed the number; this is
  purely how the mask is shown and stored.
