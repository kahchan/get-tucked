# Plan AK — Bike matte completeness, and accessibility (Dynamic Type + VoiceOver)

**Status:** DRAFT — awaiting Kah's go-ahead.
**Origin:** Kah, 2026-07-29, after confirming Plan AI's tab and camera-jump fixes on
device: "our matte is still missing some of the bike, so let's create an AK plan to sort
that. and the dynamic type and accessibility labels."

Two unrelated workstreams, deliberately kept in one document because they're the whole
of what's outstanding. **Part 1** can run without **Part 2** and vice versa; they share
no files.

---

## A note on Part 1's mandate

Plan AJ recommended *not* chasing the matte — it refuted crop-and-reseg (candidate E)
with measurements, deprecated hole-filling (B) as risky, and concluded with option D:
quantify the shortfall and disclose it. Kah has asked to sort it instead. That's his
call and this plan proceeds on it in full.

What that changes is the **standard of proof**, not the ambition. AJ's recommendation
rested on one thing: frontal area is the number the entire product exists to produce, so
any change that *adds* pixels can silently inflate every future measurement. So Part 1
leads with ground truth (AK1) and treats it as a gate, not a nicety. Anything that can't
beat the current mask against hand-labelled truth doesn't ship.

Two AJ items are carried forward unchanged and still bind:
- **The single-instance finding.** Vision returns exactly one foreground instance on
  every fixture, side-on included. `riderInstance` / `connectedInstances` / `margin`
  have never influenced a result. Do not tune them. Do not re-test E.
- **The migration trap (AJ3), now live.** See AK6.

---

# Part 1 — Matte completeness

## AK1 — Ground truth first (gate for everything below)

Nothing in Part 1 may ship without this, because "the matte looks better" is an opinion
and the output is a measurement.

- Hand-label the true rider+bike+bags silhouette on the frontal fixtures
  (`IMG_0674`, `IMG_0676`) and both side-on controls (`IMG_0675`, `IMG_0677`). A
  painted PNG alpha per fixture, committed next to the fixture, is enough — no tooling
  to build.
- Add a matte-lab mode that scores any candidate mask against its ground truth:
  **IoU**, plus separate **false-negative** (missed subject) and **false-positive**
  (invented background) pixel counts. Report the false-positive number prominently:
  that's the one that inflates frontal area, and it is the number that decides whether a
  candidate is allowed near the app.
- Record the current production mask's scores as the baseline every candidate must beat.

**Also finish AJ1 while here** (it was never done): two shots of the same position
without moving anything, to establish whether the current shortfall is *consistent*. If
it is, that number becomes AK7's honest disclosure even if a candidate wins — it
describes what shipped before it.

## AK2 — Background-model segmentation (recommended first candidate)

The app already coaches "plain, high-contrast background", already measures background
confidence every frame, and already shows a **BG** pill for it. That is an enforced
capture constraint no other candidate exploits.

Where the background is plain, everything that *isn't* background is subject — bike
included, regardless of whether a semantic model recognises a seatpost. Approach:
estimate the background model from the frame border (the coached shot has wall/road at
the edges), classify pixels by distance from that model, take the connected component
containing the rider, and union it with the existing subject mask.

**Why this is the strongest candidate:** it is deterministic and explainable in two
sentences, which spec §3 explicitly requires of anything feeding a displayed number. It
adds no dependency and no model. And it fails *legibly* — on a cluttered background it
produces obvious garbage rather than a plausible-but-wrong silhouette, so it can be
gated on the BG confidence the app already computes.

**Degradation rule:** when BG confidence is below the existing `bgConfidenceMin`, do not
apply it at all; fall back to today's mask. Never let a low-contrast scene silently
change the number.

**Risk:** shadows on the ground read as "not background" and would be counted as subject
— a false positive, directly inflating area. AK1's scoring is what catches this.
Ground-shadow handling is the specific thing to look at first if scores disappoint.

## AK3 — Depth-assisted mask (second candidate, feasibility-gated)

The capture path currently requests **no depth at all** — `AVCapturePhotoSettings()` is
bare (`LiveCameraView.swift:686`). On a dual/triple-camera iPhone,
`isDepthDataDeliveryEnabled` can attach a disparity map to the still. Head-on, the
rider+bike sit well in front of the wall, so a depth cut would capture the whole bike
irrespective of semantics.

⚠️ **Feasibility risk, to test before building anything:** the app coaches standing back
**5–6 m**, and stereo-disparity depth degrades with distance while LiDAR is roughly a
5 m instrument. Depth may be too coarse or absent at exactly the range the capture
protocol mandates. This is the make-or-break question, so answer it first: capture one
depth-enabled frame at the coached distance and look at whether rider/wall separate at
all. If they don't, close AK3 and don't spend further.

Note it also only helps devices with the hardware, so it can never be the sole path —
AK2 or today's mask has to remain the fallback.

## AK4 — Union with person mask, and bounded hole fill (fallback only)

AJ's candidates A and B, carried forward with AK1 now gating them.

- **A (union with person mask):** safe, small, helps the rider edge, does nothing for
  the bike. Worth taking if AK1 shows it improves IoU.
- **B (bounded interior hole fill):** still the riskiest idea in either plan. A bicycle
  genuinely passes air through the frame triangle and between spokes; filling those
  inflates area. Only viable with a strict hole-area bound *and* an AK1 false-positive
  score that doesn't move. If AK2 succeeds, drop B entirely.

## AK5 — Rider-assisted correction (design option, needs Kah's call)

Show the computed matte and let the rider include or exclude regions by tapping. This
invents nothing — a human confirms what the wind sees — and it matches Kah's standing
preference for explicit, discoverable controls over hidden automation.

Cost is real UI work, and it changes the app's character: measurement becomes partly
manual. Flagged as a genuine option rather than a recommendation, because that's a
product decision, not an engineering one.

## AK6 — The migration decision (blocking, must precede any ship)

**Any change to the mask changes every future frontal-area number while saved Positions
keep their old ones.** Positions captured before and after become quietly incomparable,
and the leaderboard will happily rank them against each other regardless. Comparison is
the product.

This is a STOP-and-ask under `CLAUDE.md`. Decide before implementing:

1. **Recompute** saved positions from their stored photos on migration — feasible, since
   photos and masks are persisted. Saved numbers change under the user, which needs
   saying in the UI.
2. **Version the measurement** on `Position` (a `SchemaV9` field) and refuse or badge
   cross-version comparisons.
3. **Ship nothing** and take AJ's option D after all.

Option 1 plus a one-time explanatory note is my recommendation if a candidate wins.

## AK7 — Disclosure, regardless of outcome

Whatever happens, replace the methodology's qualitative "reads a touch low" with AK1's
measured figure. If a candidate ships, this describes the improvement honestly; if none
does, it's the whole deliverable.

---

# Part 2 — Dynamic Type and VoiceOver

Explicit non-goals of Plan AI, now in scope. Measured state:

| | count |
|---|---|
| fixed `.frame(height:)` sites | **24** |
| `ScaledMetric` uses | **0** |
| `accessibilityLabel` | **3** |
| SF Symbol buttons | 9 |
| bare-glyph text controls (`→ ← ▾ ◂ ▸ − + ✕`) | 8 |

Plan AI *raised* the type floor, which means the app is now closer to overflowing at
large text sizes than before, not further. This is real debt with a known cause.

## AK8 — Dynamic Type

- Convert `Theme.Control`'s fixed tokens (`accentButtonHeight` 52, `ghostButtonHeight`
  48, `metricRowHeight` 50, `listRowHeight` 60, `iconTapTarget` 44, `iconSize` 26,
  `headerTitleInset` 52) to `@ScaledMetric`-backed values, or add scaled variants.
  `iconTapTarget` is the HIG 44pt *minimum* — it may grow, never shrink.
- Sweep the 24 fixed `.frame(height:)` sites: text-bearing → `minHeight` with scaled
  values; genuine picture boxes and hairlines stay fixed.
- **The known trap, from Plan AI:** `SegmentedToggleBar` broke precisely because its tab
  content asked for `maxHeight: .infinity` while the bar relaxed to `minHeight`, so it
  ate all available space. When relaxing any fixed height, check what the *children*
  ask for. That bug shipped to device once already.
- Verify at **AX5 (largest accessibility size)** on: positions list, position detail,
  compare, methodology, camera HUD. Screenshot each.

## AK9 — VoiceOver and labels

- Label all 17 icon/glyph controls. `Image(systemName:)` announces its symbol name and a
  bare `Text("→")` announces the character — both useless.
- The hero number needs a spoken form: "Frontal area, 7,488 square centimetres", not
  "7488 cm²" read as glyphs.
- Photo/matte/skeleton overlays: give the photo a description and mark the decorative
  overlay layers `accessibilityHidden`, so VoiceOver doesn't walk three stacked images.
- `SegmentedToggleBar` should expose `.isSelected` traits, not just colour — selection is
  currently conveyed by acid colour and a 2pt underline alone.
- Status pills (LEVEL/PERP/BG) should announce state, not just the label; the camera's
  blocked-shutter reason should be an accessibility announcement when it changes.
- Add the `.isButton` trait wherever `.buttonStyle(.plain)` on custom content has lost it.

## Verification

- Full suite green (329 baseline).
- Part 1: every candidate scored against AK1 ground truth, false-positive count reported.
- Part 2: on-device VoiceOver pass and AX5 screenshots — neither is checkable in tests.
- matte-lab runs on **Apple Silicon or device, never the Simulator** (Vision returns nil
  there).

## Non-goals

- Do not re-test AJ candidate E (crop-and-reseg). Refuted with measurements.
- Do not tune `connectedInstances` / `riderInstance` / `margin`. Inert on all fixtures.
- Do not reintroduce the two-tone matte (retired by Plan AG for structural reasons).
- No new dependencies, in either part, without asking.
