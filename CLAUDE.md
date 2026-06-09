# Get Tucked — Segmentation Spike A

## What this is

Browser-side person segmentation quality verifier. The goal: confirm MediaPipe (JS/WASM)
produces mattes clean and fast enough for the Get Tucked app before committing to Expo.

## The loop

**Loop command:** `npm run verify`
Exit 0 = pass all fixtures. Exit non-zero = fail (read the output).

Run `npm run verify:smoke` first to confirm plumbing before touching logic.

## Knobs you may turn

**`src/segment.js` — top of file:**
- `MODEL_URL` — swap the segmentation model. If mattes are consistently bad, this is the
  right lever. Alternatives to try (in order):
  - Selfie landscape: `https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter_landscape/float16/latest/selfie_segmenter_landscape.tflite`
  - DeepLab v3: `https://storage.googleapis.com/mediapipe-models/image_segmenter/deeplab_v3/float32/1/deeplab_v3.tflite`
- `CONFIDENCE_THRESHOLD` — lower raises sensitivity (more foreground), raise tightens it.
- `DELEGATE` — keep `'CPU'` for headless determinism; GPU will be faster on-device.

**`verifier/thresholds.ts`:**
- `COVERAGE_MIN` / `COVERAGE_MAX` — widen if fixtures are legitimately outside the default range.
- `TIMING_CEILING_MS` — only raise after a human confirms the hardware is just slow.

## What you must NOT change

- Files in `fixtures/` — only a human adds test photos.
- The browser↔verifier contract: `window.__segmentReady`, `window.__segment`, `window.__smokeImage`.
  The verifier depends on these signatures exactly.

## When to STOP and ask the human

- Mattes are consistently bad across 3+ model variants.
- CDN (storage.googleapis.com / cdn.jsdelivr.net) is unreachable and tests can't run.
- Coverage thresholds keep failing but mattes look correct when viewed in `output/` — may
  need threshold calibration with human sign-off.

## Quality vs speed split (critical)

| What | Auto-gated | Notes |
|------|-----------|-------|
| Coverage (foreground fraction) | Yes | Catches empty/full-frame masks |
| Timing | Ceiling only | Headless CPU ≠ on-device GPU. Reports vs 300–500ms target; hard-fails only on gross regression ceiling. Real verdict is Spike B. |
| Edge quality | No | Mattes written to `output/` for human review. |

## Stack

- `src/segment.js` — browser ESM, plain JS, no build step. MediaPipe from CDN.
- `verifier/verify.ts` — Node 22, tsx, Playwright Chromium, Node http server.
- No bundler. Throwaway spike.

## Conventions

- Conventional Commits (`feat:`, `fix:`, `chore:`, `refactor:`).
- Ask before adding any npm package beyond what's already installed.
- `npm run typecheck && npm run lint` before committing.
