# Plan AJ — Bike matte completeness

**Status:** DRAFT — awaiting Kah's go-ahead. Diagnosis is done and is the point of
this document; the remedy is deliberately gated behind a measurement phase.
**Origin:** Kah, on-device 2026-07-27, looking at Paul Tall 3 in BONES view: "we're
still missing a bit of the bike matte?" Yes. But not for the reason the existing code
is shaped around.

---

## The finding that reframes this

I read the matte-lab instance-label dumps for `IMG_0684.PNG` and `IMG_0674.JPG`. The
harness colours **each Vision instance label with a distinct palette entry**
(`labelPalette[(label - 1) % count]`, `tools/matte-lab/Sources/matte-lab/main.swift`
~line 676). Both images come back a **single uniform colour**.

**Vision returns exactly ONE foreground instance for these cyclist photos.** That
instance is the rider plus whatever bike happens to fuse into the same blob — you can
see bar stubs and a front-wheel column in it — and it omits the rest.

This means the entire instance-selection layer is a no-op on this class of photo:

- `AnalysisMath.riderInstance(instanceBoxes:riderBox:)` — picks the max-overlap
  instance from a set of one.
- `AnalysisMath.connectedInstances(riderInstance:instanceBoxes:margin:)` — unions the
  rider box with instances that intersect it, expanded by `margin: 0.06`. There are no
  other instances to union.

So **tuning `margin`, or the connectivity rule, or the rider anchor, cannot recover a
single missing bike pixel.** Any plan that starts there is dead on arrival. That
machinery isn't wrong — it correctly excludes a leaning spare wheel or a car when
Vision *does* emit multiple instances — it simply isn't the thing failing here.

The gap is upstream, in what `VNGenerateForegroundInstanceMaskRequest` itself produces.
We do not control that model.

---

## Measured evidence (matte-lab, run on this Mac 2026-07-27)

The harness runs on Apple Silicon, so this was measured, not inferred. Four fixtures,
two matched frontal/side-on pairs of the same rider and bike (orientation confirmed via
`sips`: portrait = frontal, landscape = side-on, matching `OrientationLock`):

| fixture | view | instances | bike coverage `(subject−person)/subject` |
|---|---|---|---|
| IMG_0674 | frontal | **1** | **17.6%** |
| IMG_0676 | frontal | **1** | **16.3%** |
| IMG_0675 | side-on | **1** | **59.5%** |
| IMG_0677 | side-on | **1** | **63.2%** |

In all four, the harness reports `connectedInstances (unioned) = [1]` and
`dropped instances = []`.

**Three findings, in order of importance:**

1. **The instance-selection layer is inert on every photo we have, not just frontal.**
   One instance every time, nothing ever unioned, nothing ever dropped — side-on
   included. `riderInstance` / `connectedInstances` / `margin` have never once
   influenced a result on this content.

2. **The side-on path includes ~3.7× more bike than frontal, through identical code.**
   `analyseSideOn` calls the *same* `segmentSubject(cgImage:)` as the frontal path
   (`AnalysisEngine.swift:286`). Same model, same selection, same everything. So the
   difference is **viewing geometry, not implementation**: side-on the bike presents two
   full wheels and a frame triangle, hundreds of connected pixels of unambiguous
   evidence; head-on it is a thin, edge-on column largely occluded by the rider's own
   legs and torso. Vision's model can segment a bike — it needs to be shown one.

3. **The two frontal shots agree to within 1.3 points (17.6 vs 16.3).** That is early
   evidence for the *consistent* under-inclusion case, which is the benign one. Treat it
   as indicative only: those are two different positions (tall vs tucked), so some of
   that spread is legitimate signal rather than noise. AJ1 still needs same-position
   repeats to settle it.

**What this means for expectations:** head-on, most of the bike is genuinely behind the
rider. The ~17% that *is* included is essentially fork, front wheel and bars — which is
most of what the bike actually presents to the wind that the rider's silhouette doesn't
already cover. The visible gap looks worse than its area cost.

---

## The question that actually decides what to do

This app's job is **comparing positions**, not certifying absolute area. That makes
consistency, not completeness, the thing that matters:

- If the lift misses **the same** bike parts on every shot, every comparison stays
  valid. The absolute number reads low, which the methodology screen *already*
  discloses ("the absolute number reads a touch low"). This would be a known,
  disclosed accuracy limit — annoying, not broken.
- If the lift misses **different** parts shot to shot, then two positions differ partly
  because the matte wandered, and the headline delta is contaminated. That is a
  correctness bug and it invalidates the app's core claim.

**Nothing in the repo currently answers this.** That's Phase 1, and no product code
changes until it's answered.

---

## AJ1 — Quantify (diagnostic only, no app change)

Extend `tools/matte-lab` to print, per photo, one machine-readable line:

- instance count (`result.allInstances.count`) — confirm the single-instance finding
  holds across every fixture, and flag any photo where it doesn't
- subject-mask foreground pixel count
- person-mask foreground pixel count
- **bike share** = (subject − person) / subject, the same quantity
  `MatteRenderer.bikeCoverageFraction` already computes and the Z4 "Bike coverage" row
  already shows
- subject-mask bounding box vs person-mask bounding box (does the mask even *reach* the
  ground, or does it stop at the rider's feet?)

Run it across every fixture in `fixtures/` — including the six Kah added
2026-07-26/27 (`IMG_0674-0677`, `IMG_0684-0685`), which are already dumped under
`tools/matte-lab/output/`.

**Report as a table, then answer one question:** across photos of the *same rider and
bike in similar positions*, how much does bike share vary?

**Decision gate:**
- Variance within a few points → consistent under-inclusion. Go to **AJ4** (disclose,
  don't chase). Stop.
- Variance large or erratic → comparison validity is compromised. Proceed to AJ2/AJ3
  with that established as the thing to fix.

There is a cheap real-world cross-check available immediately, before any code: open
Paul Tall 3 and Paul Tucked 3 on device, expand **Measurement detail**, and read the
existing **Bike coverage** row on each. Two shots, same bike, minutes apart. If those
percentages are close, that is early evidence for the consistent case.

## AJ2 — Candidate remedies (only if AJ1 fails the gate)

Listed with their correctness risk, because the risk is the deciding factor here, not
the implementation cost.

**A. Union the subject mask with the person mask.** `subject ∪ person`. Cheap, and
strictly safe in the sense that the person mask is a well-behaved rider segmentation.
Recovers rider edges the instance blob clipped. **Does nothing for the bike** — which is
the actual complaint. Low risk, low reward.

**B. Bounded interior hole fill.** Fill background regions *fully enclosed* by subject
pixels. This is the direct fix for the pale patch visible between the thighs in Paul
Tall 3. **Risk, and it is serious:** a bicycle genuinely passes air. The front triangle,
the gap under the saddle, and the wheels themselves are real holes, and filling them
inflates frontal area — manufacturing exactly the fake precision spec §3 forbids. Any
hole fill must be bounded (by absolute hole area, as a fraction of subject area) and
validated against hand-labelled ground truth, not eyeballed. Head-on the frame triangle
is close to edge-on and small, which is *why* a size bound might work — but "might" has
to become "measured" before this ships.

**E. Crop-and-reseg the instance request (AD5b, applied where it never has been).**
*This is the strongest untried lever, and it comes straight out of the side-on finding.*

`AnalysisEngine.cropRefinedPersonMask(source:coarseMask:)` already does exactly this for
person segmentation: take a coarse mask, compute its foreground bbox, pad 3%, crop the
**original photo** to it, re-run the request on the crop so the subject fills the frame
at far higher effective resolution, then paste back. It is proven (Plan AD5b,
`CropRefinedMaskTests`) and shipped — the side-on path calls it at
`AnalysisEngine.swift:281`.

It has **never been applied to `VNGenerateForegroundInstanceMaskRequest`.** Only to
person segmentation.

Why it should help precisely here: in IMG_0676 the rider+bike occupies roughly a quarter
of the frame width, and Kah is coached to stand back 5–6 m and shoot at 2×, so the frame
is mostly wall and asphalt. Vision runs the instance model at a fixed internal
resolution, so a seatpost or a rear wheel rim is a handful of pixels. Finding 2 says the
model includes the bike when the bike presents enough evidence — and cropping is exactly
how you hand it more evidence, at zero cost in new dependencies or new models.

**Experiment, in matte-lab, before any app change:** add a mode that runs the instance
request on a padded crop of the subject bbox and reports instance count and bike
coverage against the uncropped baseline in the table above. If frontal bike coverage
moves meaningfully off ~17% — and especially if instance count ever exceeds 1, which
would finally give `connectedInstances` something real to do — this becomes the plan. If
it doesn't move, we have cheaply falsified the most promising idea and AJ4 is the answer.

**Risk:** lower than B or C. It adds no invented pixels; it re-asks the same model a
better-framed question. It still changes measured numbers, so **AJ3 applies**.

**C. Saliency-seeded recovery.** `VNGenerateObjectnessBasedSaliencyImageRequest` to
propose bike regions, intersected with a dilation of the instance mask so nothing
disconnected gets pulled in. More machinery, unproven on this content, and saliency is
coarse (it returns a low-resolution heat map, not a matte). Prototype in matte-lab
before it goes anywhere near the app.

**D. Do nothing to the mask; make the disclosure quantitative.** Replace the
methodology's qualitative "reads a touch low" with the number AJ1 measures. This is a
legitimate outcome, not a cop-out: it is the honest response if the miss is consistent,
and it is squarely in line with this project's posture of never showing a number it
can't defend.

**Recommendation up front:** run **E** first — it is cheap, offline, risk-free to try,
and it either produces the fix or kills the best idea in one experiment. If E moves
nothing and AJ1 shows consistency, ship **A + D** and stop.
The bike pixels we're missing sit mostly *behind the rider* from head-on, where the
rider's own silhouette already occupies that frontal area — so the true error is
materially smaller than the visual gap suggests. Chasing B or C to fix an appearance
problem, at the risk of inflating the measurement, would be the wrong trade.

## AJ3 — The migration problem nobody has raised yet

⚠️ **Any change that alters the mask changes every future frontal-area number, while
every already-saved Position keeps its old one.** Positions captured before and after
become quietly incomparable — and comparison is the entire product. The leaderboard
would rank them against each other regardless.

This is a STOP-and-ask item under `CLAUDE.md` ("before showing any number in the UI you
can't explain in two sentences", and any data-model change needing a migration stage).
Before implementing AJ2 B or C, decide:

1. **Recompute** stored positions from their stored photos on migration (the photos and
   masks are persisted, so this is feasible) — and accept that saved numbers change
   under the user.
2. **Version the measurement** on `Position`, and refuse to compare across versions, or
   badge the comparison.
3. **Don't change the mask** (AJ2 option D), which is partly why D is attractive.

Option A (union with person mask) has the same problem in kind, if smaller in degree.
It is not exempt.

## AJ4 — If the miss is consistent (expected outcome)

- Update the methodology copy so the absolute-number caveat carries AJ1's measured
  figure instead of a vague qualifier. Keep it defensible and specific.
- Leave the Z4 Bike coverage row exactly where it is — AJ1 confirms it is the right
  diagnostic, and Plan AG already made it the numeric replacement for the retired
  two-tone colour check.
- Close this plan. Do not chase the appearance.

---

## Non-goals

- **Do not reintroduce the two-tone matte.** Plan AG retired it for sound structural
  reasons: the bike colour is an *absence* (subject − person), so every person-mask flaw
  renders as a confidently wrong colour. Nothing here changes that.
- Do not touch the scale/calibration maths, `EffortModel`, or any Plan AI work.
- Do not add a third-party segmentation dependency, or any dependency, without asking.
- Do not tune `connectedInstances`/`riderInstance`/`margin` — see the finding above.
  Leave that code alone; it is correct for the multi-instance case it exists to handle.

## Verification

- matte-lab must run **on the Mac (Apple Silicon) or a device, never the iOS Simulator**
  — both Vision requests return nil unconditionally there. This is documented in the
  harness README and has bitten this project repeatedly (Plan Z8).
- Any AJ2 change needs before/after bike-share numbers across the full fixture set, not
  a single hero photo.
- Full test suite green (329 baseline as of Plan AI).
- Kah's on-device pass on real captures, since fixtures are a fixed sample.
