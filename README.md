# get-tucked — Segmentation Spike A

Browser-side person segmentation quality verifier. Runs headless in GitHub Codespaces.

Proves whether MediaPipe (JS/WASM) produces mattes clean and fast enough for the
Get Tucked app before committing to an Expo/React Native architecture.

## Quick start (Codespaces)

Open in a Codespace — the devcontainer installs Node 22, deps, and Playwright Chromium automatically.

```sh
# Test plumbing (no photos needed)
npm run verify:smoke

# Real eval (add photos to fixtures/ first)
npm run verify
```

## Adding test photos

Drop real cyclist photos (JPG/PNG) into `fixtures/`. Use real conditions: full-body cyclists,
cluttered outdoor backgrounds. Studio shots are useless for this test.

See `fixtures/README.md` for details.

## Results

Mattes are written to `output/` after each run. Review them visually — automated checks
cover coverage range and timing, but edge quality is a human call.

See `RUNBOOK.md` for how to read results and what "passing" means.

## Commands

| Command | What it does |
|---------|-------------|
| `npm run verify:smoke` | Smoke test — plumbing only, no fixtures needed |
| `npm run verify` | Real eval against `fixtures/` |
| `npm run typecheck` | TypeScript check (verifier only) |
| `npm run lint` | ESLint |
| `npm run format` | Prettier |
