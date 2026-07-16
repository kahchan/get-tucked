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
}
