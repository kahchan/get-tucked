# matte-lab

Diagnostic harness for the Plan AD subject-lift / two-tone matte work
(`plans/plan-ad-subject-mask-formats.md`). A SwiftPM macOS command-line tool —
not part of the iOS target — that runs the real Vision requests
(`VNGenerateForegroundInstanceMaskRequest`, `VNDetectHumanRectanglesRequest`,
`VNGeneratePersonSegmentationRequest`) against a photo and dumps pixel-format
ground truth, instance selection, and two-tone matte composites as PNGs.

**Vision needs a real Neural Engine.** Run this on the Mac (Apple Silicon,
arm64) or on-device — **never the iOS Simulator**, where both Vision requests
used here return nil unconditionally (verified repeatedly across this
project's plans). This is exactly why the harness exists: it's the only way
to iterate on subject-lift/segmentation behaviour without a device in hand.

## Build

```sh
cd tools/matte-lab
swift build -c release
```

## Run

```sh
./.build/release/matte-lab <path-to-photo.jpg>
```

Writes to `output/<photo-name>/`:

- `1-instance-labels.png` — colour-coded Vision instance mask
- `2-subject-mask.png` — the selected-union subject mask (correctly decoded)
- `3-person-mask.png` — the person segmentation mask
- `4-twotone-composite.png` — subject∩person (green) / subject−person (orange)
  two-tone composite at a plain 128/128 split, kept as the untuned baseline

Console output also prints pixel formats, `allInstances`, bounding boxes
decoded both the correct way (UInt8 label buffer) and the way production used
to read them incorrectly (Float32 — see Plan AD Part 1, H1), and pixel-count
ratios.

### Sweep mode (AD5a)

```sh
./.build/release/matte-lab <path-to-photo.jpg> --sweep
```

Additionally renders the two-tone composite across a grid of rider threshold
{128, 160, 200, 230} × person-mask erosion radius {0, 0.25%, 0.5%, 1.0% of
subject-mask width}, writing `output/<photo-name>/sweep/sweep-e<pct>pct-t<threshold>.png`
plus a per-combo bike-share printout — used to tune the contact-point split
in `MatteRenderer.twoToneOverlay` (grips/hoods, saddle/top tube, cranks
flipping bike-colour without thin rider parts like wrists/helmet edge
overshooting).

## Fixtures

Real cyclist photos in `../../fixtures/` (repo root) — see that directory's
own README for what makes a fixture useful. `output/` is gitignored; nothing
in it should be committed.
