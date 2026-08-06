# AL8a verdict — tap-to-segment bags via `VNGenerateForegroundInstanceMaskRequest`

**Verdict: no.** Vision does not separate a loaded bike's bags into their own instance.
It returns exactly one foreground instance — rider, bike, and bags all fused — matching
Plan AJ's unloaded-bike finding exactly. There is nothing for a tap to select between;
AL8b as tap-to-segment is not buildable on Vision's instance model.

---

## Fixture check (step 1)

Of the 9 files in `fixtures/`, two show a loaded bike: **IMG_0675** and **IMG_0677**
(same rider/bike/ride, side-on, both AJ fixtures already). Visible cargo: a frame bag on
the top tube (clearest in IMG_0677), a saddle roll, a top-tube/stem accessory bag. The
two frontal shots of the same ride (IMG_0674, IMG_0676) and their app-screenshot
counterparts (IMG_0684.PNG, IMG_0685.PNG) show no visible bags — the frontal angle hides
them behind the rider. `2400-5-1.webp` and `Wahoo-Kickr-Review-Indoor-Trainer-1.jpg` /
`preview2.jpg` are trainer/stock shots (clean backgrounds, indoor, or bags on a
*different* bike in the background) and don't qualify per `fixtures/README.md`'s "hard
case" bar. **Fixture coverage is thin but non-zero** — this spike is not blocked on
fixture data, contrary to what the task brief flagged as a possible outcome.

## Evidence (steps 2–4, matte-lab on this Mac, 2026-08-07)

| fixture | view | allInstances | connectedInstances | bike coverage |
|---|---|---|---|---|
| IMG_0677 | side-on, loaded | **1** | `[1]` | 63.2% |
| IMG_0675 | side-on, loaded | **1** | `[1]` | 59.5% |

Both match AJ's numbers for the same fixtures exactly (AJ measured bike coverage, not
bag-specific — this run re-confirms `allInstances` count with the bag question in mind).

`output/IMG_0677.JPG/1-instance-labels.png` — the harness colours each instance label
with a distinct palette entry; a second instance would show as a second colour region.
The output is a single flat colour across the entire rider+bike+bag silhouette,
including the lower-frame bulge where the frame bag and saddle roll sit. No boundary,
no second label, nothing to distinguish "bag" from "bike" from "rider" in Vision's
instance map. Same result as `2-subject-mask.png` (binary mask, same single blob).

Step 4 (bag-specific instance boundary) is moot — there's only one instance to inspect,
so there's no boundary to correlate with bag geometry. Step 5 (tap-point-to-instance
mode) was skipped per the plan's own condition: the instance count alone settles it.

## What this means for AL8b

**Not buildable as tap-to-segment.** `VNGenerateForegroundInstanceMaskRequest` has no
per-bag granularity on this content class — same root cause as AJ (rider, bike, and now
bags all present too little separation in the frame for Vision's model to split them,
regardless of how a tap lands).

If the "tap a bag, see what it costs" feature (§2, §6) survives at all, it needs a
different mechanism than Vision's instance model:
- **Manual bag-region tapping** — user draws/taps a rough polygon or box over a bag in
  the existing subject mask, area computed by intersecting that region with the mask
  Vision already returns (same pixel-to-cm² scale as the rest of the pipeline). No
  segmentation model involved; the user does the instance separation Vision can't.
  Auditable, consistent with Plan AL13's stance on hand-taps over unreliable detection.
- Not evaluated further here — that's an AL8b-scope design call, not this spike's job.

## Plan feedback

- **AL8 section, plan-al**: "Plan AJ's finding says instance splits on a loaded bike are
  unreliable" undersells it — AJ never tested a loaded bike, only unloaded. This spike
  closes that gap: the same single-instance behaviour holds with bags present. Suggest
  rewording to "AJ's finding (unloaded bike) predicted this; AL8a confirms it holds
  loaded too."
- **AL8b**, if pursued, is not a UI-only follow-on to a working segmentation
  primitive — it needs a manual-region design (see above), which is a bigger scope
  than "model + UI" implies. Recommend re-scoping AL8b as a design decision for Kah
  before any coder task, same gate discipline as D1/D2.
- **Fixture backlog**: only 2 of 9 fixtures show a loaded bike, both from the same ride.
  Worth adding "loaded-bike fixture from a second ride/bag setup" to
  `open-human-steps.md` if AL8b (manual-region variant) proceeds — one ride isn't enough
  to know if frame-bag/saddle-bag placement varies enough to matter for a manual-tap UX.
- **J0 gate**: task brief said it's overridden for this spike; noted, no device work was
  done — this was Mac-only Vision via matte-lab, consistent with the standing trap
  ("Simulator Vision is nil ... device or Apple Silicon Mac only").
