# App suggestions from Torsten Frank's bikepacking-bag aero test

**Source:** [torstenfrank.wordpress.com — "Aerodynamik von Bikepacking-Taschen"](https://torstenfrank.wordpress.com/2021/12/07/aerodynamik-von-bikepacking-taschen-diese-taschen-machen-dich-schneller/)
(28 tests, 107 runs, 214 km, CdA via aerotune + Golden Cheetah, error bands reported).

**Status:** suggestions only — nothing here is a decision. Several touch measurement integrity
(spec §3) or the data model, so they're STOP-and-discuss items, flagged below.

**The one-line lesson for us:** his single biggest methodological point is that *position and kit
consistency between runs dominate the error* — he used one rider, identical clothing/helmet, the
same body tension, and repeated every config ~4×. A photo tool that compares two shots lives or
dies on the same thing: **the noise between our two captures is mostly the rider, not the app.**
That reframes several features.

---

## A. Capture-consistency (highest-value cluster)

Torsten controlled clothing, helmet, position access (always via the drops), and body tension,
because "even small variations in shoulder tension, hip angle or head position alter the results."
Our comparisons have the exact same failure mode, and right now nothing helps the user reproduce a
position between two shots.

1. **Ghost-overlay the previous capture.** When shooting setup B, show setup A's silhouette (or the
   pose skeleton) as a faint on-screen ghost to line up against. This is the single most direct
   attack on the dominant error source, and we already render both the matte and a `SkeletonOverlay`
   — so the pieces exist. *Effort: medium. Honesty-positive (shrinks real noise, doesn't fake
   precision).*
2. **Pose-delta warning on compare.** We already compute torso/hip/head-drop angles. If two compared
   captures differ beyond a threshold on those angles, surface a quiet "these positions differ —
   some of this delta is you, not your setup" note. Turns our existing posture metrics into a
   consistency guardrail. *Effort: low–medium. Ties to `AnalysisMath` pose fns + `ComparisonView`.*
3. **Same-kit checklist / reminder.** A one-line pre-capture nudge: same clothing, same helmet, same
   bars-position as the shot you're comparing to. Clothing changes silhouette as much as a small bag.
   *Effort: trivial. Copy-only.*
4. **Camera-distance / framing consistency.** Torsten fixed his whole rig; we can't fix the phone,
   but ARKit capture pose could record camera distance/angle and warn when two compared shots were
   taken very differently (parallax and framing inject scale noise). *Effort: higher; depends how
   much AR metadata we already retain. Verify before committing.*

---

## B. Noise floor & uncertainty (reconnects to the known gap)

Torsten reports an **error band on every result** (1.1–1.5%) and *deliberately refuses to quote
sub-1%* because "power meters aren't rated below 1% either." That is exactly our "don't invent a
decimal" ethos — external validation of the posture.

5. **Consider making the noise floor empirical (the twice-capture self-test).** This is the feature
   the marketing narrative originally promised and the code doesn't yet do (we ship a *fixed* ±3%;
   see `AnalysisMath.uncertaintyFraction`). Torsten's method is the template: capture the same
   position 2–3× and derive the spread as the user's *personal* floor, instead of a constant.
   **STOP/discuss — measurement-integrity + likely data-model change.** But his data is the strongest
   argument yet that per-setup repeatability is real and measurable. *Effort: high.*
6. **Sanity-check our ±3% against his ~1.5%.** His is *CdA* precision under controlled rolling tests;
   ours is *frontal area* from a phone photo, which should be *noisier*, so a conservative ±3% looks
   defensible — but worth a deliberate calibration pass rather than a guessed constant. *Effort: low
   (analysis), but conclusions may feed #5.*
7. **Keep refusing sub-integer precision.** We already round cm² to whole numbers; Torsten's
   "don't claim what your instrument can't" discipline says keep it. *No change — just don't regress.*

---

## C. Frontal area ≠ drag — own it in-app (honesty-critical)

His headline result: a bag in the **wake behind the rider can be neutral or faster** (Tailfin
Aeropack −0.5 aP, aero bar bag −1.0 aP), while a **handlebar roll is the worst** (+2.1 aP). Crucially,
the wake effects are **invisible to frontal area** — the silhouette barely moves while drag changes.

8. **Front-vs-rear caveat on bag comparisons.** Frontal area *reliably* catches things that grow your
   silhouette — and up-front bags (bar rolls) are exactly that, our strongest, most defensible case.
   It *cannot* see a rear/wake change that leaves the silhouette unchanged. Where we can tell a change
   is behind the rider, say so: "this sits in your wake — frontal area may under-read its true aero
   effect." *The side-on capture (Plan L) is how we'd locate front vs rear — **but only once we know
   which way the bike faces**, which is now specced as **Plan P, phase P3** (facing determination +
   the silhouette-diff that localises the change). Build P3 before attempting this note.* *Effort:
   medium; honesty-critical. Already partly reflected in the new methodology-page limitation bullet.*
9. **Lean the positioning into our strong case.** We're genuinely good at the thing that matters most
   and is easiest to get wrong — *frontal* bulk, especially up front. That's a marketing angle, not a
   code change, and Torsten's +2.1 aP bar-roll result backs it.

---

## D. Things to NOT copy

- **Don't chase aeroPOINTs / watts.** He can, because he measures CdA on the road; we can't and have
  said so. Converting cm² to watts would break the whole honesty pitch.
- **Don't add a "faster/slower" verdict beyond area + the noise floor.** His faster-with-a-bag result
  is precisely why a frontal-area tool must not editorialise direction — "indistinguishable" and a raw
  cm² delta are the honest ceiling.

---

## E. Caveats — what to be careful of when copying his method

His methodology is excellent, but it is a **controlled rolling-road CdA test**, and we are a
**phone photo of a projected silhouette**. Copy the *philosophy* (control variables, repeat,
report error, refuse false precision). Do **not** copy the numbers or the rankings — several
things don't transfer, and a couple are actively dangerous to borrow:

1. **He measures CdA; we measure frontal area. These are different quantities.** His entire
   results table (this bag faster than that one) is driven by *flow* — the thing we can't see.
   Trap: citing his rankings as if our tool would reproduce them. It wouldn't. His data is most
   useful to us as evidence of *where frontal area and drag diverge*, i.e. our honest limit — not
   as validation of our output.
2. **His precision (1.1–1.5%) is not ours, and we must not borrow it.** That's a power meter over
   214 km of repeated runs. A phone photo carries different and probably larger error —
   segmentation edge, scale-tap, lens perspective, camera distance, pose drift. Our ±3% is a
   separate, self-derived, deliberately conservative thing; do not "upgrade" it toward his figure
   because his looks tighter. Different instrument, different error.
3. **His single-rider, single-session control is exactly what our users lack.** He removed rider
   variability by being the only rider, one session, fixed kit, fixed body tension. Our users
   shoot on different days in different clothes. The lesson is *not* "replicate his control" (we
   can't) — it's "we must **compensate** for the control we don't have." That's the whole reason
   P1 (pose-delta warning) and P2 (ghost) exist. Copying him here means building the compensation,
   not assuming the control.
4. **Perspective and parallax are photo-only errors he doesn't have.** A rolling test has no
   camera-distance or foreshortening problem; we do. This is why *comparisons at matched framing*
   are trustworthy and *absolute* single-photo areas are weaker — and why P4 (camera-distance
   consistency) is even on the list. Don't let his clean absolutes tempt us into over-trusting a
   single shot's absolute cm².
5. **"Bags can make you faster" is his most quotable line and our most dangerous to over-tell.**
   It's a wake/flow effect **invisible to frontal area**. If we lean on it in marketing, users
   will expect our tool to *detect* the speed-up — it can't. Keep it strictly as "area isn't the
   whole story" honesty (§C, #8), never as a capability.
6. **Copying his statistical rigor implies building multi-capture.** He got his confidence from
   ~4 runs per config, not one. If we want comparable trust, one photo isn't enough — that's
   precisely the argument for the empirical twice-capture noise floor (#5). "Copy his approach"
   and "ship a single-shot number as gospel" are contradictory.
7. **Attribution / content.** If we cite him on the site, cite properly and link out; don't lift
   his charts or reproduce his data wholesale (it's his work). One short quote, attributed — the
   same rule the methodology page already follows for the academic citations.

**One-line takeaway:** his *method-philosophy* is a gift and we should wear it openly; his
*results* belong to a different measurement than ours, and borrowing them would quietly reintroduce
exactly the overclaiming the whole product is built to avoid.

## Suggested priority

1. **#2 pose-delta warning** and **#3 same-kit reminder** — cheap, honesty-positive, use existing
   metrics. Do first.
2. **#1 ghost overlay** — highest impact on real accuracy; medium effort; assets already exist.
3. **#8 front/rear caveat** — honesty-critical; pairs with the side-on capture we already have.
4. **#5 empirical noise floor** — biggest, most strategic, but a STOP/discuss with data-model
   implications. Torsten is the evidence it's worth doing; decide deliberately.
