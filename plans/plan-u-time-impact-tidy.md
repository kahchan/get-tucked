# Plan U — Time-impact tidy (drop weight, speed in the sentence, 100 km default)

Status: planned 2026-07-18. Implements Kah's feedback on the compare screen's
TIME IMPACT section (Plan S2's "so what" moment).

## Context for the implementing agent

All work is in two files:

- `ios/GetTucked/Views/ComparisonView.swift` — `TimeImpactSection` (~line 700)
- `ios/GetTucked/Analysis/EffortModel.swift` — gains one constant, API otherwise unchanged
- `ios/GetTuckedTests/EffortModelTests.swift` — gains one test, existing tests untouched

Read `CLAUDE.md` first. Key project rules that apply here:

- Every displayed number must be defensible in two sentences (spec §3). The
  assumptions line on the output card is the mechanism — when we hard-code the
  mass, it must be *stated* there, never silent.
- Numeric fields commit on blur, not keystroke (already the pattern here).
- Conventional Commits; comments only for non-obvious why.
- Do NOT touch `docs/site.js`. It mirrors EffortModel's physics *constants*
  (crr, ρ, Cd) — none of those change in this plan. Its own 200 km / 80 kg
  demo baseline is a separate marketing choice and stays as-is.

Build/verify: `cd ios && xcodegen generate`, then
`xcodebuild -project GetTucked.xcodeproj -scheme GetTucked -destination 'platform=iOS Simulator,name=iPhone 16' test`
(any available iPhone simulator is fine). All 150+ existing tests must stay green.

## Why the math is NOT changing (checked 2026-07-18)

Kah asked whether "faster average speed → bigger time difference" should hold.
It shouldn't, and the model is correct as written. Over a **fixed distance**,
time saved from an area cut *shrinks* as reference speed rises: the fractional
speed gain from an aero improvement is roughly speed-independent (v ∝ P^⅓ in
the aero-dominated regime, so Δv/v ≈ −⅓ · ΔCdA/CdA), while time-on-course
t = d/v falls with speed — and Δt ≈ (d/v)·(Δv/v). Numerically (5% area cut,
100 km, 80 kg): 20 km/h → 4.1 min, 30 → 3.0, 40 → 2.4, 45 → 2.2. Slower
riders are out there longer, so the same fractional gain buys them more
minutes. This is the well-known "aero helps slow riders more (per km)" result.
No code change; U4 pins it with a regression test so it never regresses
silently and the next person who "fixes" it gets a failing test explaining why.

Mass sensitivity (same scenario, 30 km/h): 60 kg → 3.13 min, 120 kg →
2.91 min. A ±40 kg swing moves the answer ~±4%, comfortably inside the ±3%
area-noise band already displayed — which is why U1 can drop the weight field
without losing honesty, as long as the assumed mass is stated.

## U1 — Drop the weight input

`EffortModel.swift`:
- Add `static let assumedMassKg = 80.0` with a brief why-comment: mass only
  enters the rolling term; across 60–120 kg it moves the time delta ~±4%,
  inside the displayed ±3% area-noise band, so it's a stated assumption rather
  than an input. Function signatures keep their `massKg` parameter (pure math
  stays parameterised and testable; existing tests pass 80 explicitly).

`TimeImpactSection` in `ComparisonView.swift`:
- Delete: `massText`, `persistedMassKg` (@AppStorage `"effortMassKg"`),
  `commitMass()`, `Field.mass`, the `.mass` case in the `onChange(of:
  focusedField)` switch, the WEIGHT `VStack` in `inputs` (the speed field no
  longer needs the enclosing `HStack` — keep layout tidy), and the `massKg`
  guard clause in `outputBand`.
- `OutputBand` tuple: drop the `massKg` member.
- All `EffortModel` call sites pass `massKg: EffortModel.assumedMassKg`.
- Helper text under the speed field: keep, but it now describes one field —
  reword label context if needed (it currently says "speed and weight").
- Leaving the orphaned `"effortMassKg"` UserDefaults key behind is fine; no
  migration needed.

## U2 — Speed in the sentence, always

Replace `sentence(_:)` so both branches state the speed and neither mentions
kg. The confirmed/unconfirmed split (and the `inputsConfirmed` flag) stays —
it still marks whether the speed is the rider's own number or our guess:

- confirmed:   `At 32 km/h, position B is ~4–6 min faster over 100 km.`
- unconfirmed: `At an assumed 30 km/h, position B would be ~4–6 min faster over 100 km.`

(Exact phrasing above is the spec — conditional "would be" only in the
unconfirmed branch, per Plan S2 §5's conditional-voice rule.)

- `inputsConfirmed` is now set only by `commitSpeed()`.
- The amber call-out becomes speed-only:
  `Using a default speed — edit below for yours.`
- The assumptions line gains the mass assumption (U1's honesty debt):
  `Estimate — assumes equal effort, equal drag coefficient, an 80 kg
  rider+bike+kit, flat course, no wind. A rear-mounted bag can change drag
  through wake effects this model doesn't capture.`
  Reference the constant (`Int(EffortModel.assumedMassKg)`) rather than a
  second hard-coded 80, so the sentence can't drift from the model.

## U3 — Default distance 100 km

`@State private var selectedPreset: DistancePreset? = .c200` → `.c100`.
One-token change; the 100 KM preset chip already exists.

## U4 — Regression test for the speed relationship

Add to `EffortModelTests.swift`:

```swift
/// Counterintuitive but correct (checked by hand, Plan U): over a FIXED
/// distance, a faster reference speed yields a SMALLER time saving — the
/// fractional speed gain from an area cut is ~speed-independent while
/// time-on-course falls with speed. Over fixed *time* the fast rider gains
/// more distance; that's not what this model displays.
func testTimeDeltaShrinksAsReferenceSpeedRises() {
    func delta(atKmh kmh: Double) -> Double {
        EffortModel.timeDeltaMinutes(
            areaACm2: 4000, areaBCm2: 3800, speedMS: kmh / 3.6,
            massKg: EffortModel.assumedMassKg, distanceM: 100_000
        )
    }
    XCTAssertGreaterThan(delta(atKmh: 20), delta(atKmh: 30))
    XCTAssertGreaterThan(delta(atKmh: 30), delta(atKmh: 40))
    // Hand-checked point: ~3.0 min at 30 km/h for a 5% cut over 100 km.
    XCTAssertEqual(delta(atKmh: 30), 3.05, accuracy: 0.15)
}
```

## U5 — Show the time-estimate math on the methodology screen

`ios/GetTucked/Views/HowItWorksView.swift` currently explains the *area*
pipeline (Isolate/Scale/Project, is/isn't, noise floor) but says nothing about
the time estimate — the one number in the app that layers assumptions on top
of the measurement. Add a section for it, after `NoiseFloorNote` and before
the "Be informed, don't guess." sign-off.

Structure: a new `TimeEstimateNote` private view, same boxed shape as
`NoiseFloorNote` (bg1 fill, 1px line stroke, `Theme.Space.md` padding, acc
tag at mono 9 bold / kerning 1.2, body at mono 10 fg2). Give it
`.padding(.horizontal, Theme.Space.screenMargin)` and `.padding(.top,
Theme.Space.lg)` like its sibling. Content, top to bottom:

1. Tag: `THE TIME ESTIMATE`
2. The model, one line in Space Mono so it reads as an equation, fg color
   (not fg2) to let it stand out:
   `P = v · (½ · ρ · CdA · v² + Crr · m · g)`
3. Plain-language body:
   `We take your flat-road speed, work out the power it implies for the
   larger position, then ask how fast that same power pushes the smaller
   one. The time gap over your distance is the estimate.`
4. Fixed-assumptions line (mono 10, fg2) — build the numbers from the
   constants, never literals, so the screen can't drift from the model:
   `Fixed assumptions: drag coefficient \(EffortModel.assumedCd), rider +
   bike + kit \(Int(EffortModel.assumedMassKg)) kg, rolling resistance
   \(EffortModel.crr), sea-level air. Flat course, no wind, equal effort.`
   (Format `crr` as `0.005` — `String(format: "%.3f", ...)` — not raw Double
   interpolation.)
5. The counterintuition, called out explicitly (this is the reason the
   section exists — riders will think it's backwards):
   `Slower riders gain more minutes, not fewer: an area cut buys roughly the
   same percentage of speed at any pace, and a slower rider spends longer on
   course for it to add up. Over a fixed distance, aero minutes favour the
   patient.`

Spec §3 check (two-sentence defensibility): every number in this section is a
named constant from `EffortModel` with its own why-comment; the equation is
the standard cycling power balance. Nothing new to defend.

## Order & commits

U1 → U2 → U3 in one commit (they all touch `TimeImpactSection` and the copy
interlocks): `feat(compare): tidy time-impact — fixed 80 kg mass, speed-first
sentence, 100 km default`. U4 as a second commit:
`test(analysis): pin time-delta vs speed monotonicity`. U5 third (it depends
on U1's `assumedMassKg` constant):
`feat(methodology): explain the time-estimate model and its assumptions`.

Done means: project regenerates and builds, full test suite green, and the
output card renders correctly in all three states (confirmed / unconfirmed /
band-spans-zero) — the band-spans-zero branch (`outputBand`'s last return)
also loses its `massKg` member, don't miss it.
