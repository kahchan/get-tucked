# Plan AL — spec completion: what v1 still owes

Audit of `plans/get-tucked-code-spec.html` against main @ 9000c02 (331 tests). Every
item below is absent from the code or verified-open in a prior plan. Built things are
not restated. Honesty gaps (§3) first, then missing surface, then carry-forward.

**Two decisions for Kah gate parts of this — see "Decisions" at the foot. AL4 and
AL6/AL10 must not be handed to a coder until they're answered.**

---

## Part 1 — Honesty gaps (§3 ship-blockers)

### AL1 — PERP measures phone pitch, not perpendicular-to-bike → relabel TILT

Start: `Capture/LiveCameraView.swift:851`, `:462-476`, `:629-640`.

`perpOK = abs(pitch) < 5°` from `CMMotionManager` gravity. Gravity cannot see the wheel
plane, so the pill asserts a tolerance spec §7 defines ("perpendicular to the bike's
wheel plane within ±5°") and the app never measures — a rider squared up 20° off-axis
gets a green PERP.

**Decided (Kah, 2026-08-06): relabel, don't measure.** Pill → `TILT`; rename the
properties too (`perpOK` → `tiltOK`, `perpThresholdDeg` → `tiltThresholdDeg`) or the
confusion re-seeds itself. `CaptureGate.blockedReason` copy drops perpendicular
phrasing. Framing squareness becomes coached copy in `SetTheSceneView`, not a claimed
measurement.

Non-goal: the post-capture off-axis estimate (bar-span vs shoulder-span, wheel-ellipse
eccentricity). Off-axis bias stays absorbed by the ±3% band and the wheel-check (Plan K).

Verify: pill copy matches what `CameraSession` computes, one-to-one. Record the §7
deviation alongside AL13.

### AL3 — BG confidence doesn't measure background clutter

Start: `Capture/LiveCameraView.swift:882-908`, `:685`.

Spec §7 wants a background-quality score with directional guidance and a hard refusal
floor. What exists is the fraction of mask pixels that are decisively foreground (>200)
or background (<50) — ambiguous edge pixels are the only thing that lowers it. That is
a **matte-edge-softness gauge, not a clutter detector**:

1. **It rewards confident wrongness.** A cluttered background that fools the segmenter
   yields a confidently-wrong mask (bike and bags at 0, crisply "background"). Every one
   of those pixels counts as decisive. The worse the miss, the better the score.
2. **It should be near-always-green.** Ambiguous pixels live only in a thin perimeter
   band; the rest of the frame is decisive background, so the ratio should sit far above
   `bgConfidenceMin = 0.6`. Unconfirmed — the code publishes a bool and discards the
   value, and Simulator Vision is nil (standing trap).
3. **It watches a different pipeline than the number.** It runs
   `VNGeneratePersonSegmentationRequest`; analysis moved to the subject/instance mask in
   Plans AD/AG.

**Do not hard-gate the shutter on this metric.** In order:

- **AL3a — instrument.** Publish the raw confidence; DEBUG-log per frame. One device
  session (plain wall / cluttered garage / backlit doorway) says whether it separates
  anything. Cheap, and it decides whether AL3b is needed at all.
- **AL3b — replace the metric**, only if AL3a shows it blind. Source luma just inside vs
  just outside the matte perimeter (low delta = rider blends into the background, the
  actual failure mode), plus fg/bg mean-luma ratio for backlight. Both cheap per frame,
  both *per-region* — spec §12's "low contrast on your left side" falls out of the same
  pass.
- **AL3c — refusal floor**, only once AL3b's numbers visibly separate good frames from
  bad. Two-tier: advisory line plus a lower hard floor.

Non-goal: Sobel/edge-density clutter scoring. Most expensive candidate, least
actionable — "your background is busy" doesn't tell a rider what to do.

Verify: AL3a is a device session with logged numbers, not a test.

### AL4 — Methodology screen has no citations or limitations list

Start: `Views/HowItWorksView.swift` (append below `FormulaHero`).

Spec §11 requires citations (Defraeye et al, Crouch et al, García-López et al, plus two
accessible overviews) and an explicit limitations list (planar-projection assumption,
scale-reference dependence on accurate bar width, segmentation accuracy under poor
lighting). The screen has method steps, IS/ISN'T, noise-floor note, formula hero, time
estimate — neither of the above.

**Blocked on decision D1: a coder agent handed "cite Defraeye et al" will invent a
title, journal, and year.** Reference strings must come from Kah or be web-verified
first; the two "accessible overviews" are unnamed in the spec and cannot be guessed.
The LIMITATIONS block is unblocked and can ship ahead of REFERENCES.

Fix: `LIMITATIONS` and `REFERENCES` sections at the foot. Text only, no outbound links
(offline app; a dead link is worse than a plain citation line).

Verify: every entry in §11's contents list has a visible home on that screen.

---

## Part 2 — Missing product surface

### AL5 — `UserSettings` does not exist

Start: `Models/AppSchema.swift`, `App/GetTuckedApp.swift`.

No model, no store. Spec §6 wants `noiseFloorPct`, `noiseFloorLastCalibrated`,
`preferredUnits`, `hasCompletedOnboarding`, `consentToCaptureOthers`. Prerequisite for
AL2, AL6, AL7. Single-row `@Model`, fetched-or-created at launch. `preferredUnits` ships
metric-only — include the field, build no picker.

**SchemaV9 — see standing traps in CLAUDE.md.** One bump carries AL5, AL7 and AL11.

### AL7 — Consent reminder (§10)

Start: `Capture/CaptureView.swift` (first-capture entry), gated on AL5.

One-time acknowledgement before first capture: photos stay on device, only capture
people who agreed. Stores `consentToCaptureOthers`. Small, and an App Store review
liability if absent.

### AL11 — `armWidthCm` missing from posture metrics

Start: `Analysis/AnalysisMath.swift:326` (alongside `shoulderWidthCm`),
`Models/PositionMetrics.swift`.

Spec §8 lists five posture metrics; three are computed. `headOnArmPoints` (elbows) are
already persisted and frontal `pixelsPerCm` is already the right ruler — this is a
near-free addition following the existing `shoulderWidthCm` shape.

Non-goal: `shoulderRollDeg`. It needs a bar line to roll against, and a 2° roll read off
two hand-placed taps sits inside tap noise — fails §3. Record with AL13.

### AL2 — Uncertainty is a constant, not the user's noise floor

Start: `Analysis/AnalysisMath.swift:8-10`, `:164`.

`uncertaintyFraction = 0.03` is hardcoded. §8/§9 want a *measured* floor. The comparison
machinery (`combinedNoiseCm2`, `differenceIsMeaningful`) is already correct and is being
fed an invented input.

Fix: `uncertaintyCm2(areaCm2:)` gains an optional measured fraction, falling back to
0.03. One injection point, so whichever of AL6/AL10 wins D2 feeds the same seam.

Non-goal: re-guessing 0.03. It is a placeholder to be replaced by measurement, not
re-tuned.

Verify: with no measurement present, every displayed band is byte-identical to today's.

### AL6 / AL10 — noise floor: self-test, burst, or both — blocked on D2

- **AL6 (§8, Phase 4):** after the first capture, prompt for a repeat; percent difference
  over a few captures becomes `noiseFloorPct`. Recallable behind the methodology
  screen's existing noise-floor note. Re-prompt at 90 days.
- **AL10 (§7, = Plan A5, deferred pending J0):** 3 shots per position, metrics from each,
  report the median, spread → per-position uncertainty, retry prompt on high spread.

**These measure the same physical quantity twice.** Spec asks for both; that is worth
questioning before building either — see D2. Whichever lands feeds AL2's seam.

### AL8 — Bags: the whole of Phase 3

Largest remaining slice and the second headline in §2 ("tap any bag… see what that piece
of luggage costs"). Entirely unbuilt: no `BagSegment`, no tap-to-segment, no per-bag
area/colour, no comparison toggle.

**Split — AL8a is a research spike, not a coder task.**
- **AL8a:** feasibility in `tools/matte-lab` on real loaded-bike photos. Does a
  tap-selected `VNGenerateForegroundInstanceMaskRequest` instance isolate a bag from the
  frame? Plan AJ's finding says instance splits on a loaded bike are unreliable. Returns
  a verdict to `plans/matte-verdict.md`, no UI.
- **AL8b:** model + UI, only if AL8a survives.

Gated on J0 (subject-matte eyeball) — same discipline as Plan J.

### AL9 — Events + timeline: Phase 4's tagging half

Start: `Models/AppSchema.swift`, `Views/LeaderboardView.swift`.

No `Event` model, no many-to-many with `Position`, no timeline. §6/§9 frame events as
*tags with dates*, not folders — the timeline ("setup evolution into Tour Divide") is
what they unlock. `LeaderboardView` already filters by bike and is the natural host for
an event filter.

### AL13 — Deliberate deviations: write them down, don't build them

Start: a `## Deviations from the code spec` section in `CLAUDE.md`.

Three so far: §7 perpendicular-to-wheel-plane (AL1), §8 `shoulderRollDeg` (AL11), and §7
handlebar auto-detection — Vision endpoint detection is spec-primary and the app is
tap-only. Bar-end detection against clutter is a research problem with a silent-failure
mode; hand taps are auditable and already carry Plan AE's correction UX. **Record, don't
build.**

### AL14 — Failure-state audit (§12, Phase 5)

Read-and-report, produces a checklist, not code. Camera and Photo Library denial have
Settings deep-links. Unverified: storage full surfaced *before* capture, backgrounded
mid-capture discarding cleanly, motion-permission denial, ARKit-unsupported fallback.
One pass over §12's two tables, each row ticked against real code.

**Cut from this plan: re-analysis offer (§10).** `pipelineVersion` is stored but nothing
compares it. Poor value for v1 — it depends on `PHAsset` identifiers the user can delete,
and old positions predate the current `subjectMaskData` format (Plan AD). Revisit when
the pipeline stops moving.

---

## Part 3 — Carry-forward

**Closed: AK15–AK19** (device-verified 2026-08-06, cafa71a). AK15's overflow symptom was
AK19's stale pan offset — no separate mechanism. Compressed in plan AK.

**Needs Kah on a device:**
- **AL3a** — the one new device task this plan adds.
- **`open-human-steps.md` backlog**, unchanged and still gating: J0 subject-matte eyeball
  (gates AL8, AL10), A6 3D-vs-2D pose verdict, Shot A bar-at-chest ground truth, Plan G
  live-capture feel, Plan L landscape checklist, matte-bleed threshold.
- **Visual passes never run:** Plans AC, AI (waves 1+2), AF, AE, AK10/AK11 a11y — esp.
  `PositionDetailView`'s leftmost FRONTAL/SIDE-ON tab.

**Phase 5 remainder:** AL14, plus App Store screenshots and launch-day checklist (see the
launch-marketing memory).

---

## Decisions for Kah

- **D1 — AL4 reference strings.** Supply the citations, or approve web-verifying them.
  Do not let an agent generate them.
- **D2 — one noise measurement or two?** AL6 (repeat-capture self-test) and AL10 (3-shot
  burst) measure the same thing. The burst yields per-position spread with no user
  education, where the self-test's pedagogy is called out in §13 as harder than its
  math — and a floor could be derived from accumulated burst spreads across positions,
  collapsing three items into one. Recommend **burst only**; the spec asks for both.

---

## Waves

Grouped so no two parallel agents touch the same file.

| Wave | Items | Files owned | Notes |
|---|---|---|---|
| 1a | AL1 + AL3a | `LiveCameraView.swift` | **Closed** — TILT relabel + bgConfidence instrumentation, 331 green. `SetTheSceneView.swift` had nothing to change (already coached copy). |
| 1b | AL4 LIMITATIONS | `HowItWorksView.swift` | **Closed** — LIMITATIONS card added after `NoiseFloorNote`. REFERENCES still waits on D1. |
| 2 | AL5 + AL7 + AL11 | `AppSchema.swift`, `GetTuckedApp.swift`, `CaptureView.swift`, `AnalysisMath.swift`, `AnalysisEngine.swift`, `PositionMetrics.swift`, `BikeSwap.swift`, `UserSettings.swift` (new) | **Closed** — SchemaV9, 331 green. AL11's mirror of `shoulderWidthCm` also had to reach `AnalysisEngine.swift` (Vision→metric computation) and the bike-swap rescale path — "same shape as shoulderWidthCm" pulls in more files than PositionMetrics alone. No singleton-model precedent existed for `UserSettings`; fetch-or-insert via a static helper is now that precedent. `armWidthCm` has no UI surface yet by design. |
| 3 | AL2 seam | `AnalysisMath.swift` | **Closed** — `uncertaintyCm2(areaCm2:measuredFraction:)`, optional param defaults to 0.03. 332 green. Injection point for D2's winner: `AnalysisEngine.swift:237`, pass `userSettings.noiseFloorPct`. |
| — | AL3a device session, J0 | — | Kah; interleaves, doesn't queue |
| 4 | D2 winner (AL6 and/or AL10) | — | Blocked on D2 + J0 |
| 5 | AL8a spike → AL8b | `tools/matte-lab`, then new | Verdict before UI |
| 6 | AL9 events | `AppSchema.swift`, `LeaderboardView.swift` | SchemaV10 |
| 7 | AL13, AL14 | `CLAUDE.md`, checklist | Docs |

## Verification

- Full suite green (331 baseline) after each wave — **one run by the orchestrator, not
  per worker** (see delegation contract in CLAUDE.md).
- Any new persisted field: schema bump per standing traps.
- Gesture and matte changes: device only.
- No new number on screen that fails §3's two-sentence test.

## Non-goals

- No CdA, CFD, or yaw — §15, permanently.
- No cloud, accounts, or sharing.
- No new dependencies without asking.
- No revisiting the two-tone matte (Plan AG) or AJ candidate E.
