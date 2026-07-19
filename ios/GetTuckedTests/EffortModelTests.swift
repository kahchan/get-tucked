import XCTest
@testable import GetTucked

final class EffortModelTests: XCTestCase {
    private let acc = 1e-6

    // MARK: - Power / speed round-trip

    func testSpeedAtPowerRoundTripsWhenCdAIsUnchanged() {
        // Same CdA on both sides of the solve → the implied speed must be
        // the reference speed itself, since nothing about the drag changed.
        let speedMS = 8.33 // ~30 km/h
        let cda = EffortModel.assumedCd * 4200 / 10_000
        let massKg = 80.0
        let power = EffortModel.impliedPowerW(speedMS: speedMS, cdaM2: cda, massKg: massKg)
        let solved = EffortModel.speedAtPowerMS(powerW: power, cdaM2: cda, massKg: massKg, referenceSpeedMS: speedMS)
        XCTAssertEqual(solved, speedMS, accuracy: 0.001)
    }

    func testImpliedPowerIsStrictlyIncreasingInSpeed() {
        let cda = EffortModel.assumedCd * 4200 / 10_000
        let massKg = 80.0
        let p1 = EffortModel.impliedPowerW(speedMS: 6, cdaM2: cda, massKg: massKg)
        let p2 = EffortModel.impliedPowerW(speedMS: 8, cdaM2: cda, massKg: massKg)
        let p3 = EffortModel.impliedPowerW(speedMS: 10, cdaM2: cda, massKg: massKg)
        XCTAssertLessThan(p1, p2)
        XCTAssertLessThan(p2, p3)
    }

    // MARK: - Bisection convergence

    func testSpeedAtPowerConvergesAtLowExtreme() {
        // A tiny power relative to the reference speed should still solve
        // to something inside the [0.5x, 2x] bracket, not run out the clock.
        let cda = EffortModel.assumedCd * 4200 / 10_000
        let massKg = 80.0
        let referenceSpeedMS = 8.33
        let tinyPower = EffortModel.impliedPowerW(speedMS: 0.5 * referenceSpeedMS, cdaM2: cda, massKg: massKg)
        let solved = EffortModel.speedAtPowerMS(powerW: tinyPower, cdaM2: cda, massKg: massKg, referenceSpeedMS: referenceSpeedMS)
        XCTAssertEqual(solved, 0.5 * referenceSpeedMS, accuracy: 0.01)
    }

    func testSpeedAtPowerConvergesAtHighExtreme() {
        let cda = EffortModel.assumedCd * 4200 / 10_000
        let massKg = 80.0
        let referenceSpeedMS = 8.33
        let bigPower = EffortModel.impliedPowerW(speedMS: 2.0 * referenceSpeedMS, cdaM2: cda, massKg: massKg)
        let solved = EffortModel.speedAtPowerMS(powerW: bigPower, cdaM2: cda, massKg: massKg, referenceSpeedMS: referenceSpeedMS)
        XCTAssertEqual(solved, 2.0 * referenceSpeedMS, accuracy: 0.01)
    }

    // MARK: - Monotonicity: smaller area → faster (positive delta)

    func testSmallerAreaBIsFaster() {
        let delta = EffortModel.timeDeltaMinutes(
            areaACm2: 4500, areaBCm2: 4200, speedMS: 8.33, massKg: 80, distanceM: 200_000
        )
        XCTAssertGreaterThan(delta, 0)
    }

    func testLargerAreaBIsSlower() {
        let delta = EffortModel.timeDeltaMinutes(
            areaACm2: 4200, areaBCm2: 4500, speedMS: 8.33, massKg: 80, distanceM: 200_000
        )
        XCTAssertLessThan(delta, 0)
    }

    func testEqualAreasProduceZeroDelta() {
        let delta = EffortModel.timeDeltaMinutes(
            areaACm2: 4200, areaBCm2: 4200, speedMS: 8.33, massKg: 80, distanceM: 200_000
        )
        XCTAssertEqual(delta, 0, accuracy: 0.01)
    }

    // MARK: - Band ordering

    func testBandLowNeverExceedsBandHigh() {
        let band = EffortModel.timeDeltaBandMinutes(
            areaACm2: 4500, areaBCm2: 4200, speedMS: 8.33, massKg: 80, distanceM: 200_000
        )
        XCTAssertLessThanOrEqual(band.low, band.high)
    }

    func testBandWidensWithLargerNoiseFraction() {
        // A wide area gap (5000 vs 4000 cm², 20%) so neither noise fraction
        // below is large enough to flip which side has the bigger area —
        // isolates "the band widens" from "the delta's sign flips," which
        // `testBandCanSpanZeroForATinyBarelyDistinguishableDelta` covers.
        let tight = EffortModel.timeDeltaBandMinutes(
            areaACm2: 5000, areaBCm2: 4000, speedMS: 8.33, massKg: 80, distanceM: 200_000, noiseFraction: 0.01
        )
        let wide = EffortModel.timeDeltaBandMinutes(
            areaACm2: 5000, areaBCm2: 4000, speedMS: 8.33, massKg: 80, distanceM: 200_000, noiseFraction: 0.06
        )
        // More noise shrinks the low end further below the point estimate
        // and pushes the high end further above it — the tight band nests
        // inside the wide one on both sides.
        XCTAssertGreaterThan(tight.low, wide.low)
        XCTAssertLessThan(tight.high, wide.high)
    }

    /// A delta that only barely clears the noise floor can still have a
    /// band spanning zero — the band must show that honestly (S2 §4), never
    /// clamp the low end up to zero.
    func testBandCanSpanZeroForATinyBarelyDistinguishableDelta() {
        let band = EffortModel.timeDeltaBandMinutes(
            areaACm2: 4210, areaBCm2: 4200, speedMS: 8.33, massKg: 80, distanceM: 200_000
        )
        XCTAssertLessThan(band.low, 0)
        XCTAssertGreaterThan(band.high, 0)
    }

    // MARK: - Worked example (hand-checked sanity, not a precise oracle)

    func testWorkedExampleProducesPlausibleWatts() {
        // 30 km/h, 4200 cm² (0.42 m²), 80 kg rider+bike+kit — order-of-
        // magnitude check against published flat-road cycling power figures.
        let speedMS = 30.0 / 3.6
        let cda = EffortModel.assumedCd * 4200 / 10_000
        let power = EffortModel.impliedPowerW(speedMS: speedMS, cdaM2: cda, massKg: 80)
        XCTAssertGreaterThan(power, 80)
        XCTAssertLessThan(power, 300)
    }

    func testWorkedExampleTimeDeltaIsAFewMinutesOver200km() {
        // A ~7% area reduction (4500 → 4200 cm²) at 30 km/h over 200 km —
        // should land in a "worth mentioning, not implausible" range.
        let delta = EffortModel.timeDeltaMinutes(
            areaACm2: 4500, areaBCm2: 4200, speedMS: 30.0 / 3.6, massKg: 80, distanceM: 200_000
        )
        XCTAssertGreaterThan(delta, 1)
        XCTAssertLessThan(delta, 30)
    }

    // MARK: - Speed relationship (Plan U)

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

    // MARK: - AB13: % callout must agree with the minutes band

    /// The comparison's minutes sentence and its "same effort, % faster"
    /// line are two different read-outs of the same power-balance solve —
    /// they must never disagree on which side wins or which way the sign
    /// points, across a spread of plausible area pairs (equal, small gap,
    /// large gap, either side ahead).
    func testSpeedDeltaPercentAgreesInSignWithTimeDeltaMinutes() {
        let pairs: [(areaA: Double, areaB: Double)] = [
            (4500, 4200), (4200, 4500), (4000, 3800), (3800, 4000),
            (5000, 4000), (4200, 4200), (4210, 4200),
        ]
        for pair in pairs {
            for kmh in [15.0, 30.0, 45.0] {
                let speedMS = kmh / 3.6
                let timeDelta = EffortModel.timeDeltaMinutes(
                    areaACm2: pair.areaA, areaBCm2: pair.areaB, speedMS: speedMS,
                    massKg: EffortModel.assumedMassKg, distanceM: 100_000
                )
                let pctDelta = EffortModel.speedDeltaPercent(
                    areaACm2: pair.areaA, areaBCm2: pair.areaB, speedMS: speedMS, massKg: EffortModel.assumedMassKg
                )
                // Same-sign agreement (both derive from B being smaller/larger
                // than A) — a strict `==` on the boolean tests the sign, not
                // the magnitude, so ties (equal areas) round-trip cleanly too.
                XCTAssertEqual(
                    timeDelta >= 0, pctDelta >= 0,
                    "areaA=\(pair.areaA) areaB=\(pair.areaB) at \(kmh) km/h: time delta \(timeDelta) vs pct delta \(pctDelta)"
                )
            }
        }
    }

    func testSpeedDeltaPercentBandLowNeverExceedsHigh() {
        let band = EffortModel.speedDeltaPercentBand(
            areaACm2: 4500, areaBCm2: 4200, speedMS: 8.33, massKg: EffortModel.assumedMassKg
        )
        XCTAssertLessThanOrEqual(band.low, band.high)
    }

    func testSpeedDeltaPercentBandCanSpanZeroForATinyBarelyDistinguishableDelta() {
        let band = EffortModel.speedDeltaPercentBand(
            areaACm2: 4210, areaBCm2: 4200, speedMS: 8.33, massKg: EffortModel.assumedMassKg
        )
        XCTAssertLessThan(band.low, 0)
        XCTAssertGreaterThan(band.high, 0)
    }

    func testEqualAreasProduceZeroSpeedDeltaPercent() {
        // Accuracy loosened past the bisection's own 0.001 m/s tolerance
        // (translated to a % of an ~8 m/s reference speed) so this isn't
        // flaky against `speedAtPowerMS`'s numerical convergence noise.
        let pct = EffortModel.speedDeltaPercent(
            areaACm2: 4200, areaBCm2: 4200, speedMS: 8.33, massKg: EffortModel.assumedMassKg
        )
        XCTAssertEqual(pct, 0, accuracy: 0.05)
    }

    // MARK: - AB12: watts rounding

    func testRoundedWatts5RoundsToNearestFiveWattSteps() {
        XCTAssertEqual(EffortModel.roundedWatts5(187), 185)
        XCTAssertEqual(EffortModel.roundedWatts5(188), 190)
        XCTAssertEqual(EffortModel.roundedWatts5(190), 190)
        XCTAssertEqual(EffortModel.roundedWatts5(0), 0)
    }

    func testWorkedExampleSoloWattsAreInAPlausibleRoundedRange() {
        // Same worked example as the comparison's own sanity check (30 km/h,
        // 4200 cm², 80 kg) — the solo row is the same math, read out alone.
        let speedMS = 30.0 / 3.6
        let cda = EffortModel.assumedCd * 4200 / 10_000
        let power = EffortModel.impliedPowerW(speedMS: speedMS, cdaM2: cda, massKg: EffortModel.assumedMassKg)
        let rounded = EffortModel.roundedWatts5(power)
        XCTAssertEqual(rounded % 5, 0)
        XCTAssertGreaterThan(rounded, 80)
        XCTAssertLessThan(rounded, 300)
    }
}
