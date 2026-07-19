import Foundation

/// Flat-road power-balance model for the "so what" time-over-distance
/// estimate (Plan S2) — pure, static, no UI types. Measures area, assumes
/// Cd is identical between the two compared positions (stated explicitly in
/// the UI copy, never silent), and solves for the speed a fixed power would
/// produce against the smaller area.
///
/// Ported (Plan S3) to vanilla JS for the marketing site's landing-page
/// hook — `docs/site.js`'s `impliedPowerW`/`speedAtPowerMS`/
/// `timeDeltaMinutes`/`timeDeltaBandMinutes`. No shared code between the two
/// (different languages, different runtimes); if a constant below changes,
/// change it there too or the site and the app will disagree.
///
///     P = v · (½ · ρ · CdA · v² + Crr · m · g)
///
/// Every function here is a closed-form or numerically-stable step in that
/// one equation; nothing here decides *whether* to show an estimate (the
/// noise floor and labelling live in ComparisonView) — this is the math only.
enum EffortModel {
    /// Rolling resistance coefficient — asphalt road tire, fixed (not exposed).
    static let crr = 0.005
    /// Air density at sea level, 15°C, kg/m³ — fixed (not exposed).
    static let airDensityKgM3 = 1.225
    static let gravity = 9.81
    /// Mid-range of published road-cyclist Cd values (~0.6–0.9) — the model
    /// never measures drag, only area, so this is a stated assumption, not
    /// a fitted constant. The *ratio* between the two CdA values is what
    /// drives the result; this scales the aero share of total power.
    static let assumedCd = 0.7
    /// Rider + bike + kit mass (kg), fixed (Plan U — was a user input; mass
    /// only enters the rolling-resistance term, and across 60–120 kg it
    /// moves the time delta ~±4%, inside the ±3% area-noise band already
    /// shown — so it's a stated assumption, not something worth asking for.
    static let assumedMassKg = 80.0

    /// Power (W) to hold `speedMS` against combined aero + rolling drag —
    /// the closed-form half of the model (step 1).
    static func impliedPowerW(speedMS: Double, cdaM2: Double, massKg: Double) -> Double {
        speedMS * (0.5 * airDensityKgM3 * cdaM2 * speedMS * speedMS + crr * massKg * gravity)
    }

    /// Solves `½ρ·CdA·v³ + Crr·m·g·v − P = 0` for v (step 2) — power is
    /// strictly increasing in v for any cdaM2, massKg > 0, so the function
    /// crosses zero exactly once and bisection on a bracket around the
    /// reference speed always converges to that one positive root.
    /// Tolerance 0.001 m/s (≪ display precision — minutes, not seconds),
    /// hard-capped at 100 iterations (converges in ~20 in practice).
    static func speedAtPowerMS(powerW: Double, cdaM2: Double, massKg: Double, referenceSpeedMS: Double) -> Double {
        func residual(_ v: Double) -> Double {
            impliedPowerW(speedMS: v, cdaM2: cdaM2, massKg: massKg) - powerW
        }
        var lo = 0.5 * referenceSpeedMS
        var hi = 2.0 * referenceSpeedMS
        let tolerance = 0.001
        var iterations = 0
        while hi - lo > tolerance, iterations < 100 {
            let mid = (lo + hi) / 2
            if residual(mid) < 0 {
                lo = mid
            } else {
                hi = mid
            }
            iterations += 1
        }
        return (lo + hi) / 2
    }

    /// Point estimate, in minutes: how much faster position B is than A
    /// over `distanceM`, at the effort (power) implied by A's own flat-
    /// cruise speed and CdA. Positive = B faster. `areaACm2`/`areaBCm2` are
    /// the raw measured frontal areas (cm²); CdA is derived here via
    /// `assumedCd`, never passed in pre-multiplied, so callers can't
    /// accidentally apply Cd twice.
    static func timeDeltaMinutes(
        areaACm2: Double, areaBCm2: Double, speedMS: Double, massKg: Double, distanceM: Double
    ) -> Double {
        let cdaA = assumedCd * areaACm2 / 10_000  // cm² → m²
        let cdaB = assumedCd * areaBCm2 / 10_000
        let power = impliedPowerW(speedMS: speedMS, cdaM2: cdaA, massKg: massKg)
        let speedB = speedAtPowerMS(powerW: power, cdaM2: cdaB, massKg: massKg, referenceSpeedMS: speedMS)
        let timeASeconds = distanceM / speedMS
        let timeBSeconds = distanceM / speedB
        return (timeASeconds - timeBSeconds) / 60
    }

    /// Point estimate: % faster position B is at the same power A implies at
    /// `speedMS` (Plan AB13) — the speed-domain sibling of
    /// `timeDeltaMinutes`, same two-step power-balance solve, just read out
    /// as a speed ratio instead of a time-over-distance. Positive = B faster
    /// (agrees with `timeDeltaMinutes`'s own sign convention by construction:
    /// both are monotonic in the same direction in `areaBCm2 - areaACm2`).
    static func speedDeltaPercent(areaACm2: Double, areaBCm2: Double, speedMS: Double, massKg: Double) -> Double {
        let cdaA = assumedCd * areaACm2 / 10_000
        let cdaB = assumedCd * areaBCm2 / 10_000
        let power = impliedPowerW(speedMS: speedMS, cdaM2: cdaA, massKg: massKg)
        let speedB = speedAtPowerMS(powerW: power, cdaM2: cdaB, massKg: massKg, referenceSpeedMS: speedMS)
        return (speedB - speedMS) / speedMS * 100
    }

    /// Speed-domain sibling of `timeDeltaBandMinutes` — same area-noise
    /// perturbation, same narrower/wider-gap shape, so a comparison view can
    /// show a `%` range with the same honesty as the minutes band beside it.
    static func speedDeltaPercentBand(
        areaACm2: Double, areaBCm2: Double, speedMS: Double, massKg: Double,
        noiseFraction: Double = AnalysisMath.uncertaintyFraction
    ) -> (low: Double, high: Double) {
        let narrowerGap = speedDeltaPercent(
            areaACm2: areaACm2 * (1 - noiseFraction), areaBCm2: areaBCm2 * (1 + noiseFraction),
            speedMS: speedMS, massKg: massKg
        )
        let widerGap = speedDeltaPercent(
            areaACm2: areaACm2 * (1 + noiseFraction), areaBCm2: areaBCm2 * (1 - noiseFraction),
            speedMS: speedMS, massKg: massKg
        )
        return (min(narrowerGap, widerGap), max(narrowerGap, widerGap))
    }

    /// Rounds to 5 W steps (Plan AB12) — the ±3% area noise floor already
    /// shown elsewhere puts fake precision in single-watt figures.
    static func roundedWatts5(_ watts: Double) -> Int {
        Int((watts / 5).rounded() * 5)
    }

    /// Propagates the ±`noiseFraction` area uncertainty (default 3%,
    /// matching `AnalysisMath.uncertaintyFraction`) through to a band on the
    /// time delta — the widest-gap and narrowest-gap area pairings, in
    /// whichever order they land (never assumed), so a delta that barely
    /// clears the noise floor can still show "0–X min" honestly instead of
    /// being clamped away from zero. This is measurement-noise propagation
    /// only, not a Cd sensitivity sweep (S2 §4) — Cd itself stays fixed.
    static func timeDeltaBandMinutes(
        areaACm2: Double, areaBCm2: Double, speedMS: Double, massKg: Double, distanceM: Double,
        noiseFraction: Double = AnalysisMath.uncertaintyFraction
    ) -> (low: Double, high: Double) {
        let narrowerGap = timeDeltaMinutes(
            areaACm2: areaACm2 * (1 - noiseFraction), areaBCm2: areaBCm2 * (1 + noiseFraction),
            speedMS: speedMS, massKg: massKg, distanceM: distanceM
        )
        let widerGap = timeDeltaMinutes(
            areaACm2: areaACm2 * (1 + noiseFraction), areaBCm2: areaBCm2 * (1 - noiseFraction),
            speedMS: speedMS, massKg: massKg, distanceM: distanceM
        )
        return (min(narrowerGap, widerGap), max(narrowerGap, widerGap))
    }
}
