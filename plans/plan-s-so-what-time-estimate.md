# Plan S — the "so what" moment: time-over-distance estimate + drop-bar tap specificity

*Status: direction confirmed 2026-07-17 — the honesty-tension resolution below (equal-Cd
+ noise gate + P3 rear-located gate + banded output) was discussed and endorsed. Ready
to build in the S1 → S2 → S3 order. The related metric-reordering work is **Plan T**
(`plan-t-metric-altitude.md`) — S2's "so what" section is designed to land at the top
of the hierarchy Plan T defines.*

Replaces the earlier freeform draft spec. Two corrections to that draft, up front:

1. **The "blocking scale/calibration gap" doesn't exist.** The app already derives
   pixels/cm from the handlebar tap-calibration (`AnalysisMath.pixelsPerCm`, taps placed
   in `CaptureView`, width from `Bike.handlebarWidthMm`), cross-checked by the optional
   wheel ruler (Plan K). Bar width is the *ruler*, not a measurement output. The real
   drop-bar issue is narrower and different — see S1.
2. **"CdA derived from width capture" was wrong.** Frontal area comes from the
   segmentation matte, not from bar width. And we never measure Cd at all — the model
   below is explicit about what is measured (area) vs assumed (everything else).

---

## S1 — Drop-bar tap specificity (scale integrity)

### The actual problem
Scale = tapped bar-end pixel distance ÷ entered bar width. These must refer to the
**same physical feature**. Drop bars break this silently:

- Manufacturers quote width center-to-center **at the hoods/levers**; flared drops are
  20–60mm wider at the ends (a 42cm bar with 12° flare ends ~46–48cm outside-to-outside).
- In a front-on photo the **drop ends are the easiest points to identify and tap** — the
  hoods are visually ambiguous.
- So the likely user behaviour is: enter the quoted width (hoods, c-c), tap the drop
  ends (wider, outside-to-outside). That inflates pixels/cm and **understates every
  area on that bike** — a systematic, invisible scale error, potentially 5–15%.

Note this is a *consistency* requirement, not a "capture the widest point" requirement.
Either convention works if entered width and tap points match. We standardise on the
**outermost point of the drops, outside-to-outside**, because (a) it's the tappable
feature, (b) it's also the honest frontal width of the bike.

### Changes
- **Bike model**: add `barType` (`drop` / `flat`) to `Bike` — lightweight SwiftData
  additive field, no migration stage needed (verify: additive optional/defaulted
  property). Default existing bikes by `bikeType` (road/gravel → drop, mtb → flat).
- **BikeSetupView**: bar-type picker; width field help text switches with it:
  - drop: "Measure outside-to-outside at the very ends of the drops — NOT the quoted
    size (that's measured at the hoods and flared bars are wider at the ends)."
  - flat: "Outside-to-outside at the bar ends, including bar-end accessories."
- **CaptureView tap copy** (currently "Tap the left end of your handlebars"): for drop
  bars, "Tap the outermost point of the LEFT drop" / "…RIGHT drop". Flat bars keep
  current copy.
- **Existing-data caveat**: bikes created before this change may carry a hood-width
  number. One-time gentle prompt when a drop-bar bike is next used: "confirm this width
  was measured at the drop ends." No forced re-entry.

Parked (unchanged from draft): live AR guide line during tap placement.

### Not in scope
No change to the area math — this is copy, one model field, and setup UI. The wheel
ruler (Plan K) already catches gross width mis-entry; this shrinks the systematic case
it can't see (10% threshold vs a ~5–15% error that can hide under it).

---

## S2 — Position comparison: time-over-distance at equal effort

### The honesty tension — decide deliberately
`torsten-aero-notes.md` §D says: *don't chase watts, don't add a faster/slower verdict —
"indistinguishable" and a raw cm² delta are the honest ceiling.* This feature crosses
that line on purpose, because a cm² delta has no felt meaning and the "so what" moment
is the product. The resolution is not to abandon the honesty stance but to price it in:

1. **Equal-Cd assumption, stated.** We measure area A, not drag. The model assumes Cd is
   identical between the two positions, so CdA_B = CdA_A × (A_B / A_A). This is exactly
   the regime where frontal area is most trustworthy (silhouette changes up front), and
   exactly wrong for wake effects (rear bags) — the front/rear caveat (Torsten #8)
   applies here too.
2. **Noise-floor gate.** If the area delta fails `isDistinguishable` (combined ±3%
   floors), show **no time figure at all** — keep the existing "indistinguishable"
   verdict. A time estimate on a delta we can't distinguish from zero is fake precision.
3. **Rear-located gate (the P3 dividend).** Torsten's objection is about wake effects —
   which are a *bag* problem, not a *position* problem. Plan P3 already localises the
   silhouette diff and knows which way the bike faces. Use it: when the area change is
   predominantly rear-located, **suppress the time estimate** and fall back to cm² +
   the existing wake caveat. When it's front/body-located — the regime where area
   tracks drag — the estimate runs. This turns the "no verdict" rule into an enforced
   gate rather than a rule we quietly break. (Head-on captures have no localisation;
   they're body-position comparisons by construction, estimate runs.)
4. **Range, not point.** Propagate the ±3% area uncertainty through the model and show
   a band: "roughly 4–9 min faster over 200 km", never "6.3 min". The two-sentence
   defence: "Your measured area difference, at your usual effort, implies this speed
   difference if nothing else changes; the range is our measurement noise."
   The band covers *measurement noise only*, not model bias (Cd equality, speed input
   error) — the assumptions line carries those claims; don't widen the band with a Cd
   sensitivity sweep, it reshuffles the power split without adding honesty.
5. **Labelled estimate, uncroppable.** Copy always carries "estimate — assumes equal
   effort, equal drag coefficient, flat course, no wind." The minutes figure, the band,
   and an "EST" label are **one typographic lockup** — there must never be a
   screenshot-croppable bare "9 min".

### Physics model
Flat-road power balance, no wind, no slope, drivetrain losses cancel (equal both sides):

```
P = v · (½ · ρ · CdA · v² + Crr · m · g)
```

- **Step 1 (closed form):** from baseline speed v_A, CdA_A, m, Crr → implied power P.
- **Step 2:** with the same P and CdA_B, solve `½ρ·CdA_B·v³ + Crr·m·g·v − P = 0` for
  v_B. One real positive root. Use **bisection** on [0.5·v_A, 2·v_A], tolerance
  0.001 m/s (≪ display precision), hard cap 100 iterations. (Cardano exists but
  bisection is trivially testable and unconditionally stable.)
- **Step 3:** t = d/v for both; output Δt.

Absolute CdA_A: `Cd_assumed × A_A`, with **Cd_assumed = 0.7** (mid-range of published
road-cyclist values ~0.6–0.9; constant, not exposed). Sensitivity note: the *ratio*
drives the result; Cd choice shifts the aero share of total power and therefore scales
Δt modestly — acceptable inside an already-banded estimate. Revisit only if the band
looks dishonest in testing.

### Constants and inputs

| Input | Source | Value / default |
|---|---|---|
| A_A, A_B (cm² → m²) | Measured (existing) | from the two compared positions |
| Flat-road speed | User-entered, persisted | see wording note below |
| Rider + bike + kit mass | Default, editable, persisted | 80 kg, whole kg, bounds 40–150 |
| Distance | User-entered per calc + presets | presets 100 / 200 / 400 / 1000 km (ultra framing), custom field |
| Crr | Fixed constant | 0.005 |
| ρ (air density) | Fixed constant | 1.225 kg/m³ (sea level, 15 °C) |
| g | Fixed constant | 9.81 |
| Cd | Fixed constant | 0.7 |

**Speed wording — ask for what the model uses.** Not "your usual average speed": a
ridden average bundles hills, stops, wind and drafting, and feeding it into a flat
no-wind model misprices the implied power. Ask for **"the speed you'd hold on a flat,
calm road"** so input and model describe the same ride. (Error direction if users
enter a bundled average anyway: it's *lower* than flat cruising speed, which
understates the aero share and therefore understates the time saved — we err toward
under-promising. Acceptable.)

**Mass — one field, demoted.** Mass only enters via `Crr·m·g·v` on the flat: at
30 km/h / 80 kg that's ~33 W of ~180 W, and ±10 kg moves the final Δt by ~3% *of the
delta* — inside the measurement band. So: a single combined "rider + bike + kit"
field, kg only, no rider/bike split, **not** stored per-bike (that's collecting
precision the model can't use). Layout altitude follows the physics: **distance and
speed are the two real inputs; mass is an editable row in the assumptions line**
("80 kg — edit"), not a peer input.

Persist speed + mass (UserDefaults is enough — user-level, not per-bike) so the section
works with zero typing on repeat visits. Values commit on blur per convention.

### Output framing
- "At your usual effort, POSITION B is **~4–9 min faster** over 200 km."
- Minutes; switch to `Xh Ym` past 90 min. Whole minutes only — no decimals, ever.
- Copy stays in the conditional voice — the claim is "smaller silhouette → less aero
  drag *at equal Cd*", never an unconditional "B is faster".
- Below the noise gate: keep the existing indistinguishable copy, add "too close to
  call a time difference."
- Rear-located change (gate 3): no time figure; cm² delta + wake caveat only.
- Always followed by the assumptions line (estimate, equal effort/Cd, flat, no wind).

### Implementation shape
- **`EffortModel.swift`** (new, in `Analysis/`): pure static functions —
  `impliedPowerW(...)`, `speedAtPowerMS(...)` (bisection), `timeDeltaBand(...)`
  (runs the pipeline at A_B±3% vs A_A∓3% for the band ends). No UI types.
- **P3 gate wiring**: reuse the existing facing + silhouette-diff localisation output
  to classify the change front/body vs rear before offering the estimate. Verify what
  P3 actually exposes before building — the gate needs a "predominantly rear" boolean,
  not the raw diff.
- **`ComparisonView`**: new "SO WHAT" section under the existing verdict — distance
  presets + custom field, speed + mass fields, output line. Uses the design tokens.
  *Note: `ComparisonView.swift` has uncommitted changes in the working tree — land or
  stash those first.*
- **Tests** (`EffortModelTests`): power round-trip (solve v_B with CdA_B = CdA_A → v_B
  == v_A), monotonicity (smaller area → faster), bisection convergence at extremes,
  band ordering, noise-gate behaviour, a hand-checked worked example (e.g. 30 km/h,
  0.42 m² → sensible watts ~150–200).

### Edge cases
- Distance ≤ 0 or speed outside 10–60 km/h: field validation, no output.
- Band spanning zero (delta barely clears the gate): show "0–X min" honestly — do not
  clamp away the zero end.
- Comparing across different bikes: allowed (it already is), assumptions line covers it.

---

## S3 — Marketing-site hook (simple standalone version)

A small calculator on the landing page: **"area saved" as a percentage** (not cm² — a
raw cm² figure is meaningless to a visitor, which is the exact problem this feature
exists to solve) plus a distance preset — output "~X–Y minutes over 200 km".

The % maps straight into the model: A_B = A_A × (1 − p), so the fixed baseline area
only sets the aero share and the visitor never needs to know their own number.

**Anchor the percentage — a bare % has the cm² problem one level up.** Nobody knows
whether 5% is huge or trivial. Slider range ~1–15% with 2–3 labelled anchor points at
recognisable scenarios (e.g. "tucking your elbows", "hoods → drops", "removing a bar
roll"), each marked **illustrative** — no sourced claim per anchor, no per-scenario
precision. The close of the pitch is the app itself: *"this slider is a guess — the
app measures your actual number."* That keeps the hook honest and makes the CTA do
the work.

Same formula duplicated in vanilla JS (no shared code with Swift; keep constants
literally identical and note the pairing in a comment on both sides). Fixed assumed
baseline: 30 km/h, 0.45 m², 80 kg. Same banded output and assumptions line — per the
launch-marketing stance, the hook is "felt time from a measured area change, honestly
banded", not a watts claim.

Build after S2 lands so the numbers on site and in app can never disagree.

---

## Order of work
1. **S1** — small, standalone, fixes a live scale-integrity hole. Ship first.
2. **S2** — `EffortModel` + tests, then the ComparisonView section. STOP point: confirm
   the honesty-tension resolution above before building.
3. **S3** — after S2, reusing its constants and copy.

## Open items
- ~~Confirm the S2 departure from the "no faster/slower verdict" position~~ — resolved
  2026-07-17: endorsed with the equal-Cd framing, P3 rear-located gate, and banded
  lockup output as the conditions.
- Additive SwiftData field for `barType` — verify no migration stage needed before S1.
- Cd = 0.7 constant — sanity-check the band width against a couple of published CdA
  figures during S2 testing.
- P3's localisation output shape — confirm it can answer "predominantly rear?" directly.

*Last updated: 2026-07-17.*
