# Get Tucked — Segmentation Spike: Build Plan

A handoff brief for a fresh conversation. Goal of that conversation: scaffold a
throwaway repo that proves whether browser-side person segmentation is good
enough for Get Tucked, set up so an AI agent (Claude Code) can run the
verification loop itself.

---

## Background (why this spike exists)

Get Tucked is an iPhone app (stack not finalised). Two humans plus AI agents are
developing it. One Mac available.

A chain of decisions led here:

- **Codespaces / cloud agents can't build native iOS** — Xcode is macOS-only. So
  the stack choice should favour an agent-friendly setup where agents can build
  and verify their own work without leaning on the one Mac.
- The app needs to **separate a cyclist from the background to get a clean
  reference object**. That was initially framed as needing ARKit. It doesn't —
  it's a **person-segmentation (masking)** problem, not spatial AR. ARKit is the
  wrong tool and it's the tool that breaks the agent workflow.
- Segmentation runs on a **captured photo/clip, not a live feed** — so it's an
  offline image op: portable, testable, and a good fit for a cross-platform stack
  (Expo/React Native) with the segmentation as the one native-ish piece.
- "Snappy" = **300–500ms** to process one captured photo. Animation can cover
  some of that latency, so the budget is soft.
- The only live-camera need is a **level indicator** (device tilt via
  DeviceMotion) for framing — trivial, irrelevant to this spike.

**The risk this spike retires:** cross-platform on-device segmentation can be
worse than native Apple Vision on matte quality and speed. Before committing the
whole architecture to Expo, prove the matte is clean and fast enough on the
actual capture conditions. If it is — build on the agent-friendly stack with
confidence. If not — that's the signal to write a native Vision module.

---

## Two spikes, cheapest first

**Spike A — matte QUALITY. 100% in Codespaces. No Mac, no Expo, no phone.**
A plain web page runs MediaPipe segmentation (JS/WASM). Feed in real cyclist
photos, inspect the matte. This validates the thing most likely to kill the plan,
for almost nothing. **This is what we scaffold now.**

**Spike B — device LATENCY. Needs the phone. Later.**
Only if A passes. Expo dev-client build via EAS, measure real on-device ms.
This loop does NOT fully close (a human reads the number off the phone) — that's
expected and fine. Not in scope for the scaffold.

Build A first. It's the high-information, low-cost move and it's fully
Codespaces-native.

---

## The agentic loop (the actual point of the exercise)

An agentic loop is: goal + success criterion → agent writes code → agent runs a
**verification command** → agent reads the machine-readable result → compares to
criterion → fail: diagnose and repeat; pass: stop and hand back.

It only closes if **step 4 is automatic** — the agent must observe the result of
its own action without a human in the middle. So the real design work is turning
"is the matte good and fast enough" into **a command that exits 0 or 1**, not
something judged by eye.

Therefore the spike is NOT "a web page with MediaPipe." It is a **headless
verifier**: a script that loads the page, pushes each test photo through
segmentation, captures the matte + timing, asserts against thresholds, and exits
non-zero with a readable reason on failure. The page is just the thing under
test; the verifier is what makes it a loop.

**The honest split** (this distinction IS the lesson):

- Objective gates the agent loops on unattended:
  - **coverage** (fraction of pixels classed foreground) within a sane range —
    catches empty masks and whole-frame masks. Device-independent.
  - **timing** — but headless CPU timing is a ROUGH PROXY, not the device number.
    So timing only hard-fails on gross regressions (a generous ceiling); the
    300–500ms target is reported for context, with the real verdict deferred to
    Spike B.
- NOT auto-gated, dumped for the human to flip through:
  - **edge quality** ("is the shoulder edge mushy") — partly human judgement. The
    verifier writes every matte PNG to an output folder; a cheap edge-roughness
    proxy can be *reported* but must not gate.

The agent can self-correct on "too slow / mask empty / mask is the whole frame".
It can't self-correct on "edges look ragged". Knowing which half is which is the
skill to take away.

---

## Setup decisions already made (don't re-litigate in the scaffold convo)

- **Run mode:** Kah runs the agent (not Claude driving while narrating). So the
  repo needs a written runbook + agent instructions baked in, not a walkthrough.
- **Agent:** Claude Code.
- **Test images:** assume NONE exist yet. Scaffold with a clearly-marked
  `fixtures/` folder to swap real photos into, and a synthetic-image smoke mode
  so the plumbing can be checked before real photos arrive. (Real eval is
  meaningless without representative photos — real cyclists, cluttered outdoor
  backgrounds, not clean studio shots. Flag this to Kah.)
- **Time budget:** 300–500ms device target; animation buys some slack.

---

## What to scaffold (Spike A)

A small repo, "dumb v1", no over-engineering. Suggested shape:

```
.devcontainer/devcontainer.json   # Codespaces: node, postCreate installs deps + playwright chromium
.gitignore                        # node, dist, output/, .env*
LICENSE                           # MIT, Kah Chan
README.md                         # what it is, how to run
CLAUDE.md                         # agent instructions: the goal, the loop, the verify command,
                                  #   which knobs it may turn, when to STOP and ask the human
RUNBOOK.md                        # human-facing: what the loop is, how to read results,
                                  #   the quality-vs-speed honesty split
package.json                      # scripts: verify, verify:smoke, typecheck, lint, format
tsconfig.json                     # strict
eslint + prettier configs
index.html                        # minimal page that loads the segmentation module
src/segment.js                    # browser ESM, plain JS (browser can't run .ts, no build step).
                                  #   MediaPipe tasks-vision from CDN. Exposes window globals the
                                  #   verifier calls. Knobs (model URL, delegate, threshold) at top.
verifier/verify.ts                # tsx-run. Tiny static server + Playwright headless Chromium.
verifier/thresholds.ts            # coverage range, timing target/ceiling, env-overridable
verifier/globals.d.ts             # window globals for typecheck
fixtures/README.md                # "drop real cyclist photos here"
output/                           # gitignored, mattes land here for review
```

### Conventions (fresh best-practice)

- TypeScript strict for the verifier. The browser module stays plain JS (no build
  step for a throwaway — the browser can't import `.ts` and a bundler isn't worth
  it here).
- ESLint + Prettier, run manually (`npm run lint`), no pre-commit hooks.
- Conventional Commits.
- Functional, minimal.
- **Ask before adding any library** beyond Playwright, tsx, typescript, eslint,
  prettier. MediaPipe loads from CDN in the browser — not an npm dep.

### Technical notes / likely gotchas (save the scaffold convo some trial-and-error)

- MediaPipe `@mediapipe/tasks-vision` ImageSegmenter, **selfie segmenter** model.
  Note honestly: it's tuned for selfies/upper body; a full-body cyclist on a
  cluttered background is the hard case. If mattes are bad, **swapping the model
  is a legit agent iteration**, not a failure of the harness. Call this out in
  CLAUDE.md as an allowed knob.
- Use **CPU delegate** in headless Chromium — deterministic, no GPU flakiness.
  Note that on-device GPU will be faster, so headless timing runs high (reinforces
  why timing is proxy-only here).
- Model `.tflite` and WASM load from CDN at runtime (storage.googleapis.com /
  jsdelivr). Fine in Codespaces (open internet); just don't expect it to work in
  a locked-down sandbox.
- Verifier serves the repo over a tiny `node:http` server and points Playwright at
  `http://127.0.0.1` (not `file://`, to avoid WASM/CORS issues).
- The page exposes globals the verifier calls via `page.evaluate`:
  `window.__segmentReady` (Promise), `window.__segment(dataUrl)`,
  `window.__smokeImage()`.
- `npm run verify` = real eval against `fixtures/`. If the folder is empty it
  should exit with a clear HUMAN-actionable message (add photos) — NOT loop on it,
  and NOT silently pass. `npm run verify:smoke` = synthetic image, plumbing only.
- The agent's loop command is `npm run verify`. Success = exit 0 across all
  fixtures. Wire `typecheck` + `lint` in as pre-PR self-checks too.

---

## Kick-off message for the scaffold conversation

> Scaffold the "Get Tucked segmentation spike" repo described in the attached
> plan (`segmentation-spike-plan.md`). I'll be running Claude Code against it
> myself, in a GitHub Codespace. I have no test photos yet — set up the
> `fixtures/` folder and a synthetic smoke mode. Show me CLAUDE.md, RUNBOOK.md,
> and the four scaffolding files (README, .gitignore, LICENSE, package.json)
> before creating anything. Then the verifier and the browser module. Ask before
> adding any library beyond Playwright + the TS/lint tooling.

---

## After the spike

- A passes (matte clean + plausibly fast) → commit to **Expo / React Native**,
  segmentation as the one native-ish module, EAS Build for iOS so the Mac is a
  convenience not a dependency, both humans + Claude Code on a shared repo with
  agents self-checking via `verify`/`typecheck`/`lint`.
- A fails on quality → write a **native Apple Vision** segmentation module (still
  RN, just one heavier native piece; Mac re-enters as a dependency for that part).
- Then **Spike B** for the on-device latency number (human-in-the-loop step).

Open question still owed to Kah: representative test photos. The whole spike is a
toy until real cyclist-on-cluttered-background images are in `fixtures/`.
