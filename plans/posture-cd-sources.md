# Posture Cd sources (Plan AN1)

**Primary-source pass, 2026-10-18.** Replaces the Crouch (2017) Table 4 read. Three search agents went to the primary papers. The orchestrator checked the key numbers against the PDFs (Defraeye 2010 Table 2, Blocken 2013 Table 1, Blocken 2018 Table 1). Raw extraction sheets: session scratchpad, not kept.

Rule (unchanged): use Cd = CdA/A from within one study only. Torso angle is from vertical (0° = upright). Most papers measure from horizontal, so θ_app = 90° − θ_paper.

## Basis: what A means

The app's matte includes the bike (Plan AD/AG, Z4 coverage row). So the matching Cd is **rider+bike CdA / rider+bike A**. A Cd from body-only CdA over body-only A is a different quantity. Do not mix the two.

## Usable rows

| Study | Method | Basis | Upright | Dropped | TT | Dropped / up | TT / up | Grade |
|---|---|---|---|---|---|---|---|---|
| Defraeye 2010, J Biomech 43:1262 (Crouch [42]) | tunnel, 1 rider, static, 6% blockage uncorrected | body only (see note 1) | A 0.41, CdA 0.193, Cd 0.471 | 0.37, 0.167, 0.451 | 0.34, 0.134, 0.394 | 0.96 | 0.84 | B |
| same, LES CFD | CFD, body only | body only | Cd 0.534 | 0.465 | 0.418 | 0.87 | 0.78 | B |
| Mannion 2018, JWEIA 179:92 | CFD RANS, 1 rider | rider+bike | A 0.497, CdA 0.327, Cd 0.658 | 0.398, 0.233, 0.586 | 0.394, 0.213, 0.541 | 0.89 | 0.82 | B (not checked by orchestrator, internally consistent; TT row also changes helmet) |
| Blocken 2018, JWEIA 181:27 | CFD, validated on 4 poses (0.1–7.2%), 1 rider | rider+bike | "Back up" A 0.423, Cd 0.655 | seated drops/hoods poses: Cd 0.638–0.677 | TT on extensions: TT helmet 0.641, top-tube TT 0.568 | 0.97–1.03 | 0.87–0.98 | A for Cd, C for angles |

Note 1: Defraeye says "frontal area of the cyclist". Two checks say this means body only. (a) Blocken 2013 uses the same A with a body-only CFD model. (b) Blocken 2018 gives a rider+bike A of 0.370 for the same rider in a TT pose. That is larger than Defraeye's TT A of 0.34, so 0.34 cannot include the bike. Pairing the rider+bike CdA (0.270/0.243/0.211) with this A gives a false, flatter 1.00/0.94. Do not use that pairing.

Blocken 2018 "Back up" is already low (torso about 66° from vertical), so its "/ up" column is relative to a tucked baseline, not to a true upright.

## Noise floor

- Inside one TT posture, arm changes alone move Cd 1.3–3.5% (Sports Eng 2025, doi 10.1007/s12283-025-00495-7, CFD).
- Repeat tunnel runs in one position spread 0.1–5% (Crouch 2019, Proc IMechE P, sprint positions, 2 riders). In that study, lower sprint positions moved Cd from −7% to +5%, while A fell 2–21%.
- So a Cd ratio within ±5% of 1.0 cannot be told apart from no change.

## Rejected or not verified

- **Crouch Table 4 rows [8], [51], [53], [55]:** no primary paper reached (paywall, 403, or print only). [8] (Gibertini 2008, dynamic, ≈2% blockage) is seen in two secondaries as Cd hoods 0.76 vs TT 0.79. This is the only source with a flat or rising Cd. It is unverified, so it does not count either way.
- **CdA only, no A:** Grappe 1997, García-López 2008 (abstract), Kyle & Burke 1984, Jeukendrup & Martin 2001, Zdravkovich 1996, Underwood 2011, Barry 2015, Chabroux 2011.
- **A only, no CdA:** Debraux 2009 (rider alone: upright 0.430, aero 0.338, n=9), Heil 2001/2002, Fintelman 2015 PhD (TT A against torso angle, n=19: A = 0.464 − 0.00196·θ_app over 66–90°).
- **Unusable:** Fintelman 2014 tunnel (fixed reference area), Schaffarczyk 2022 (self-contradicting A), Blocken 2019 sprint (out of saddle), Blocken 2018 "Superman" (not a legal pose).
- **Worth a second pass with library access:** Crouch 2021 (Proc IMechE P 235:301, A + CdA for 10 sprint rows), Underwood 2011, García-López 2008, Ghasemi 2022 (abstract: 5 cm lower bars, A −4.1%, Cd −4.6%), Barry 2015, Gibertini 2008.

## Test against the acceptance bar

1. **Count:** fails on independence. There are 3 verified studies, and each uses one rider. Defraeye and Blocken 2013 use the same rider and the same data.
2. **Same direction:**
   - **TT:** passes. Each verified study shows Cd lower than upright (0.78–0.94). The only source that disagrees ([8]) is unverified.
   - **Dropped:** fails. The ratios are 0.87–1.03, and most of them are inside the 5% noise floor.
3. **Spread smaller than the gap:** fails. On the rider+bike basis, the TT ratio is 0.82 (Mannion) or 0.87–0.98 (Blocken). The spread (≈0.16) is as large as the gap from 1.0.

## Verdict: label only stands. The reason changes.

- No Cd ratio ships. Plan AN stays closed.
- The earlier reason was wrong. "Studies disagree on direction" leaned on Crouch Table 4 rows that cannot be traced to a primary paper. The verified primary data say:
  - **Dropped vs upright:** Cd stays about the same, within the noise.
  - **TT on extensions:** Cd is lower in every verified study. The size (6–22%) is not stable enough to quote.
  - **Most of a tuck's gain is frontal area.** In every verified set, A falls more than Cd does.
- **Copy consequence:** the methodology line "studies disagree" (`PostureLimitationSection`, `HowItWorksView.swift`) under-states the evidence for TT positions. A defensible line: *"In aero-bar positions, published studies also find a slightly lower drag coefficient. It is not consistent enough to estimate, so for those positions this estimate is conservative. For drops and hoods, the frontal area is the whole story."* Kah decides whether to change it.
- **Bin boundaries:** 25° / 55° are still placeholders. No verified study gives torso angle, A and CdA from upright to TT for one rider. The CFD angles cover 64–100° from vertical only, and Blocken's figures disagree with each other.
