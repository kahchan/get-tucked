import XCTest
import CoreGraphics
@testable import GetTucked

final class AnalysisMathTests: XCTestCase {
    private let acc = 1e-6

    // MARK: - Scale

    func testHandlebarPixelsHorizontalSpan() {
        // 40% of a 1000px-wide image, taps on the same row → 400px.
        let px = AnalysisMath.handlebarPixels(
            tap0: CGPoint(x: 0.2, y: 0.5),
            tap1: CGPoint(x: 0.6, y: 0.5),
            imageSize: CGSize(width: 1000, height: 1000)
        )
        XCTAssertEqual(px, 400, accuracy: acc)
    }

    func testHandlebarPixelsDiagonalRespectsAspect() {
        // dx = 0.5 * 800 = 400, dy = 0.5 * 600 = 300 → hypot = 500.
        let px = AnalysisMath.handlebarPixels(
            tap0: CGPoint(x: 0.0, y: 0.0),
            tap1: CGPoint(x: 0.5, y: 0.5),
            imageSize: CGSize(width: 800, height: 600)
        )
        XCTAssertEqual(px, 500, accuracy: acc)
    }

    func testPixelsPerCm() {
        // 400px handlebar, 400mm (= 40cm) wide → 10 px/cm.
        let ppc = AnalysisMath.pixelsPerCm(handlebarPixels: 400, handlebarWidthMm: 400)
        XCTAssertEqual(ppc, 10, accuracy: acc)
    }

    func testMaskPixelsPerCmDownscale() {
        // Mask is half the source width → scale halves.
        let ppc = AnalysisMath.maskPixelsPerCm(sourcePixelsPerCm: 10, maskWidth: 500, sourceWidth: 1000)
        XCTAssertEqual(ppc, 5, accuracy: acc)
    }

    // MARK: - Area

    func testFrontalAreaCm2() {
        // 10000 foreground px at 5 px/cm → 10000 / 25 = 400 cm².
        let area = AnalysisMath.frontalAreaCm2(foregroundPixelCount: 10_000, maskPixelsPerCm: 5)
        XCTAssertEqual(area, 400, accuracy: acc)
    }

    func testUncertaintyIsThreePercent() {
        XCTAssertEqual(AnalysisMath.uncertaintyCm2(areaCm2: 400), 12, accuracy: acc)
    }

    func testUncertaintyDisplayRoundsAndFormats() {
        XCTAssertEqual(AnalysisMath.uncertaintyDisplay(154.7), "±155 cm²")
        XCTAssertEqual(AnalysisMath.uncertaintyDisplay(12.0), "±12 cm²")
    }

    /// End-to-end scale→area chain, verifying the mask-vs-source rescale (HANDOFF §2.2).
    func testAreaChainWithMaskRescale() {
        let px = AnalysisMath.handlebarPixels(
            tap0: CGPoint(x: 0.3, y: 0.5),
            tap1: CGPoint(x: 0.7, y: 0.5),
            imageSize: CGSize(width: 1000, height: 1000)
        )
        XCTAssertEqual(px, 400, accuracy: acc)
        let sourcePpc = AnalysisMath.pixelsPerCm(handlebarPixels: px, handlebarWidthMm: 400) // 10
        let maskPpc = AnalysisMath.maskPixelsPerCm(sourcePixelsPerCm: sourcePpc, maskWidth: 250, sourceWidth: 1000) // 2.5
        let area = AnalysisMath.frontalAreaCm2(foregroundPixelCount: 2500, maskPixelsPerCm: maskPpc)
        // 2500 / (2.5^2) = 400 cm².
        XCTAssertEqual(area, 400, accuracy: acc)
    }

    // MARK: - Noise floor

    func testCombinedNoiseCm2CombinesInQuadrature() {
        // 3-4-5 triangle: sqrt(3^2 + 4^2) = 5.
        XCTAssertEqual(AnalysisMath.combinedNoiseCm2(uncertaintyA: 3, uncertaintyB: 4), 5, accuracy: acc)
    }

    func testIsDistinguishableWhenDeltaExceedsNoise() {
        XCTAssertTrue(AnalysisMath.isDistinguishable(
            areaA: 400, areaB: 450, uncertaintyA: 12, uncertaintyB: 13.5
        ))
    }

    func testIsNotDistinguishableWhenDeltaWithinNoise() {
        // |401 - 400| = 1, combined noise = sqrt(12^2+12^2) ≈ 17 → within noise.
        XCTAssertFalse(AnalysisMath.isDistinguishable(
            areaA: 400, areaB: 401, uncertaintyA: 12, uncertaintyB: 12
        ))
    }

    // MARK: - Pose geometry

    func testShoulderWidthCm() {
        // |0.6 - 0.4| * 1000 = 200px at 10 px/cm → 20cm.
        let cm = AnalysisMath.shoulderWidthCm(
            leftShoulderX: 0.4, rightShoulderX: 0.6, imageWidthPx: 1000, pixelsPerCm: 10
        )
        XCTAssertEqual(cm, 20, accuracy: acc)
    }

    func testShoulderWidthPlausibleWithinRange() {
        XCTAssertTrue(AnalysisMath.isShoulderWidthPlausible(30))
        XCTAssertTrue(AnalysisMath.isShoulderWidthPlausible(45))
        XCTAssertTrue(AnalysisMath.isShoulderWidthPlausible(60))
    }

    func testShoulderWidthImplausibleOutsideRange() {
        XCTAssertFalse(AnalysisMath.isShoulderWidthPlausible(29.9))
        XCTAssertFalse(AnalysisMath.isShoulderWidthPlausible(78))
        XCTAssertFalse(AnalysisMath.isShoulderWidthPlausible(0))
    }

    func testTorsoAngleUpright() {
        // Shoulder directly above hip → 0°.
        let deg = AnalysisMath.torsoAngleDeg(
            shoulder: CGPoint(x: 0.5, y: 0.8), hip: CGPoint(x: 0.5, y: 0.4)
        )
        XCTAssertEqual(deg, 0, accuracy: 1e-9)
    }

    func testTorsoAngleHorizontal() {
        // Shoulder level with hip, forward → 90°.
        let deg = AnalysisMath.torsoAngleDeg(
            shoulder: CGPoint(x: 0.9, y: 0.5), hip: CGPoint(x: 0.5, y: 0.5)
        )
        XCTAssertEqual(deg, 90, accuracy: 1e-9)
    }

    func testTorsoAngle45() {
        let deg = AnalysisMath.torsoAngleDeg(
            shoulder: CGPoint(x: 0.9, y: 0.9), hip: CGPoint(x: 0.5, y: 0.5)
        )
        XCTAssertEqual(deg, 45, accuracy: 1e-9)
    }

    func testHipAngleStraight() {
        // Shoulder up, knee down from hip → 180°.
        let deg = AnalysisMath.hipAngleDeg(
            shoulder: CGPoint(x: 0.5, y: 0.9),
            hip: CGPoint(x: 0.5, y: 0.5),
            knee: CGPoint(x: 0.5, y: 0.1)
        )
        XCTAssertEqual(deg, 180, accuracy: 1e-6)
    }

    func testHipAngleRight() {
        // Shoulder up, knee forward → 90°.
        let deg = AnalysisMath.hipAngleDeg(
            shoulder: CGPoint(x: 0.5, y: 0.9),
            hip: CGPoint(x: 0.5, y: 0.5),
            knee: CGPoint(x: 0.9, y: 0.5)
        )
        XCTAssertEqual(deg, 90, accuracy: 1e-6)
    }

    func testHipAngleDegenerateReturnsZero() {
        // Coincident points must not divide by zero.
        let deg = AnalysisMath.hipAngleDeg(
            shoulder: CGPoint(x: 0.5, y: 0.5),
            hip: CGPoint(x: 0.5, y: 0.5),
            knee: CGPoint(x: 0.5, y: 0.5)
        )
        XCTAssertEqual(deg, 0, accuracy: acc)
    }

    func testHeadDropBelowShoulderIsPositive() {
        // Ear 0.2 (normalised) below shoulder over 1000px at 10 px/cm → 20cm.
        let cm = AnalysisMath.headDropCm(
            shoulderY: 0.8, earY: 0.6, imageHeightPx: 1000, pixelsPerCm: 10
        )
        XCTAssertEqual(cm, 20, accuracy: acc)
    }

    func testHeadAboveShoulderIsNegative() {
        let cm = AnalysisMath.headDropCm(
            shoulderY: 0.6, earY: 0.8, imageHeightPx: 1000, pixelsPerCm: 10
        )
        XCTAssertEqual(cm, -20, accuracy: acc)
    }
}
