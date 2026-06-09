# Runbook — Segmentation Spike A

## What this is

A headless verifier that feeds cyclist photos through MediaPipe person segmentation
and checks whether the mattes are clean and fast enough for the Get Tucked app.

## Getting started

1. Open in a GitHub Codespace (devcontainer handles deps + Playwright Chromium).
2. Run `npm run verify:smoke` to confirm plumbing works.
3. Drop real cyclist photos (JPG/PNG) into `fixtures/`.
   **What "real" means:** full-body cyclists, cluttered outdoor backgrounds, varying
   light. Studio shots are useless — the hard case is what needs testing.
4. Run `npm run verify`.
5. Check `output/` for the matte PNGs.

## Commands

| Command | What it does |
|---------|-------------|
| `npm run verify:smoke` | Tests plumbing only. No fixture photos needed. |
| `npm run verify` | Real eval against `fixtures/`. Exits 0 (pass) or 1 (fail). |
| `npm run typecheck` | TypeScript check (verifier only). |
| `npm run lint` | ESLint. |
| `npm run format` | Prettier. |

## Reading the output

The verifier prints one line per image:

```
✓ rider_front.jpg  coverage=23.4%  time=812ms
✗ rider_side.jpg   coverage=2.1%   time=390ms
  → coverage too low (2.1% < 5%) — mask may be empty
```

Then a summary and a reminder to review mattes visually.

**Coverage** is the fraction of pixels classified as foreground. Valid range: 5%–80%
(configurable in `verifier/thresholds.ts`). Outside this range means the mask is
essentially empty or covers the whole frame.

**Timing** — the number reported is headless Chromium on CPU. It will be higher than
on-device GPU. The verifier only hard-fails on a gross regression ceiling (default 5s).
The 300–500ms target is the *device* target, confirmed in Spike B. Don't read too much
into the headless number.

## What "passing" means

Automated:
- Coverage in range for every fixture.
- Timing below the ceiling (regression guard, not quality bar).

Human (you):
- Open `output/` and flip through the mattes.
- Look for: clean shoulder/head edges, cycle frame not cut away, background not bleeding
  through jersey, no random holes in the torso.

Both must be true for the spike to pass.

## If mattes are bad

The current model (`selfie_segmenter`) is tuned for upper-body selfies. Full-body cyclists
on cluttered backgrounds is the hard case — bad results here are expected and the agent
can try swapping the model (see `CLAUDE.md` → Knobs).

If model-swapping doesn't help after a few iterations, that's the signal to write a native
Apple Vision segmentation module instead of using MediaPipe cross-platform.

## Spike A → Spike B

If mattes are clean (good edges, no bleed) **and** the automated checks pass → Spike A passes.

Next: Spike B — on-device latency. Run an Expo dev-client build via EAS on the actual iPhone
and measure real processing time. A human reads the number off the phone — the agent loop
doesn't close on that step. Mac is needed for the Xcode/EAS step.

## Output files

All mattes land in `output/` (gitignored). File names match fixture names with `_matte`
appended: `rider_front.jpg` → `output/rider_front_matte.png`.
