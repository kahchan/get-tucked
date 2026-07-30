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

## AK1 — Validation, without hand-painting anything

The first draft of this section asked Kah to hand-paint reference mattes. He pushed back,
correctly: that front-loaded hours of tedium before establishing there was anything to
find. Two cheaper routes were tried instead, and one of them settled the question.

### AK1a — macOS Remove Background as a second opinion: ✅ DONE, and it closes the model-swap line

Kah ran macOS **Remove Background** on both frontal fixtures — one click each, no
painting — and observed it behaves much like ours. Measured (quarter resolution,
threshold 128, alpha channel vs `2-subject-mask.png`):

| | IMG_0674 | IMG_0676 |
|---|---|---|
| agreement (IoU) | **0.965** | **0.956** |
| our subject mask | 35,153 px | 37,684 px |
| Remove Background | 34,099 px | 36,647 px |
| px the reference has that we lack | **92 (0.3%)** | **320 (0.9%)** |
| area change if we adopted it | **−3.0%** | **−2.8%** |

**Remove Background's mask is *smaller* than ours and has essentially nothing to
recover.** The difference map is a 1-pixel rim around the whole silhouette — pure
edge-threshold feathering, ours very slightly dilated — plus two specks near the fork.
**No structural disagreement.** Both pipelines produce the same silhouette, including the
same absent rear wheel.

**What this proves, and what it doesn't.** It is strong evidence that *swapping Apple
segmentation models will not fix this* — that line is closed. It is **not** proof our mask
is correct: macOS Remove Background almost certainly shares model lineage with
`VNGenerateForegroundInstanceMaskRequest`, so their agreement may reflect a common blind
spot rather than truth. Two related models converging is weaker evidence than two
independent methods converging. That distinction is the entire remaining case for AK2.

*Reproduce:* rasterise both to a common size, threshold the reference's alpha at 128, and
count set intersections. ~100 lines against CoreGraphics; not committed, since the
reference source it compares against is now retired. The numbers above are the artifact.

### AK1b — Label-free validation using landmarks the rider already tapped

Better than any reference matte, and it needs no labelling at all: **every capture already
stores human-confirmed physical landmarks.** `Position.handlebarTapPoints` and
`Position.wheelTapPoints` are unit-coordinate points the rider tapped during calibration.

So the completeness test is: **does the subject mask actually cover the landmarks the
rider tapped?** If the mask has no foreground along the vertical span between the tapped
wheel top and bottom, it is provably missing the wheel — no opinion, no IoU, no painting.
Same for the handlebar line. This runs across *every saved position*, not four fixtures.

Two further invariants, also label-free:
- **Superset:** the subject mask must contain the person mask. Any violation is a bug
  irrespective of what truth would say.
- **Repeatability:** the same position shot twice should give a stable area — AJ1, still
  worth doing, still free.

Note for accuracy: the existing `wheelCheckDisagreementFraction` validates the *scale*
(measured wheel vs spec size), **not** mask completeness. It is a physical reality check,
but not this one.

### AK1c — Pixel-accurate truth: deferred, and only if earned

Hand-painted truth is now the *last* resort, not the first step, and only becomes
necessary if AK2 produces a candidate whose improvement needs quantifying. If that day
comes: correct `2-subject-mask.png` rather than tracing (it is already exactly the
photo's dimensions, so it layers on with no alignment), work at ÷4, and fix the subject
rule first — **subject is what the wind actually sees, so spokes and the open frame
triangle are NOT subject.** That call decides whether AK4's hole fill can ever be
legitimate.

⚠️ `fixtures/IMG_*-truth.png` is silently swallowed by the `fixtures/IMG_*` rule from
`b7fae52`. Use `fixtures/truth/`, which is itself gitignored — those files are
full-colour subject cutouts, so they identify the rider exactly as the source photo does.

## AK2 — Background-model segmentation (one experiment, on narrowed grounds)

> **Downgraded 2026-07-29 by AK1a, but not closed — and the reason it survives is the
> reason to run it.** Every other automated route is dead: AJ's candidate E refuted by
> measurement, AK3 closed on physics, model-swapping closed by AK1a. AK2 is the only
> remaining approach that is **methodologically independent** — it is not semantic, so it
> cannot inherit the shared blind spot that AK1a's 96% agreement might represent. It is
> the only thing that could disagree *informatively*.
>
> **Set expectations honestly:** two related models agree that the subject-vs-background
> boundary is where our mask puts it, and that boundary is what AK2 recomputes. So do not
> expect the number to move much. Run it once, as a falsification test of "we are at the
> ceiling", not as an expected fix. If it agrees too, the ceiling claim is established by
> two genuinely independent methods and Part 1 is finished.
>
> Run **AK1b's landmark check first** — it is cheaper, works on real saved positions, and
> may show there is nothing missing that isn't occluded anyway.


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

## AK3 — Depth-assisted mask — ❌ CLOSED 2026-07-29, before any engineering

> **Kah ran the zero-cost kill test: Portrait mode does not engage at the coached 5–6 m
> standoff.** AK3 is closed. Cost of finding out: one look through the stock Camera app,
> no app changes, no schema migration.
>
> Portrait mode declining is not literally identical to
> `AVCapturePhotoOutput.isDepthDataDeliveryEnabled` returning nothing — that is a lower-
> level API without Portrait's aesthetic distance heuristics. But the same physics drives
> both: stereo disparity from a centimetre-scale lens baseline carries almost no parallax
> at 5–6 m, and LiDAR is roughly a 5 m instrument. Any map delivered at that range would
> be too coarse to separate rider from wall.
>
> **The more important finding: AK3 is structurally incompatible with this app's capture
> protocol, not merely blocked today.** Depth needs the subject close. The 5–6 m standoff
> exists precisely to flatten the near-wheel perspective error (Plan W3, made real in the
> app by Plan AF's 2× default). Moving closer to obtain usable depth would reintroduce
> the exact scale error the standoff was introduced to remove — and scale error corrupts
> the area number directly, which is strictly worse than an incomplete matte.
>
> So this does not become viable on better hardware or on a Pro model. **Do not reopen
> it** unless the capture protocol itself changes, at which point the whole scale
> derivation is back in question anyway.
>
> Note the asymmetry that made this cheap, and reuse it: AK3 was cheap to *kill* and
> expensive to *confirm* — the confirm path needed depth delivery, a capture-delegate
> change, and a `SchemaV9` field to persist the map (a documented stop-and-ask). Ordering
> the kill test first saved all of it.

*Original rationale, retained so the closure is legible:*

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

## AK7 — Disclosure — now the recommended outcome, not the consolation prize

> **Recommendation as of 2026-07-29.** Every automated route has been closed by evidence
> rather than by giving up: E refuted, AK3 closed on physics, model-swap closed by AK1a.
> Two pipelines agree on the silhouette to 96%, and the second has under 1% we lack.
>
> The reason the bike looks absent is geometric, not algorithmic: head-on, standing over
> the bike, the rear wheel sits directly behind the front wheel and the frame sits behind
> the legs. **Occluded structure contributes no additional frontal area.** The fork column
> and bars *are* in the mask. So the visual gap is largely not an area error — which is
> what AJ concluded, now supported by two pipelines instead of one.
>
> Ship the disclosure. If the *appearance* is what needs fixing rather than the number,
> that is **AK5**, and it should be chosen as a design decision with eyes open, not as a
> workaround for a measurement problem we have been unable to demonstrate exists.


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
