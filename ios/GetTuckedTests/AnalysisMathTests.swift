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

    func testSideOnPixelsPerCmMatchesFrontalRulerMath() {
        // Same shape as testHandlebarPixelsHorizontalSpan + testPixelsPerCm:
        // 40% of a 1000px-wide image → 400px, over a 1050mm wheelbase.
        let ppc = AnalysisMath.sideOnPixelsPerCm(
            tap0: CGPoint(x: 0.2, y: 0.5), tap1: CGPoint(x: 0.6, y: 0.5),
            imageSize: CGSize(width: 1000, height: 1000), wheelbaseMm: 1050
        )
        let expected = AnalysisMath.pixelsPerCm(handlebarPixels: 400, handlebarWidthMm: 1050)
        XCTAssertEqual(ppc, expected, accuracy: acc)
    }

    func testMaskPixelsPerCmDownscale() {
        // Mask is half the source width → scale halves.
        let ppc = AnalysisMath.maskPixelsPerCm(sourcePixelsPerCm: 10, maskWidth: 500, sourceWidth: 1000)
        XCTAssertEqual(ppc, 5, accuracy: acc)
    }

    func testMaskMatchesSourceAspectExactMatch() {
        // Both exactly 4:3.
        XCTAssertTrue(AnalysisMath.maskMatchesSourceAspect(
            maskWidth: 512, maskHeight: 384, sourceWidth: 4032, sourceHeight: 3024
        ))
    }

    func testMaskMatchesSourceAspectWithinRoundingTolerance() {
        // Mask width off by one from an exact 4:3 scale — real Vision output
        // sizes don't land on an exact integer scale of the source.
        XCTAssertTrue(AnalysisMath.maskMatchesSourceAspect(
            maskWidth: 513, maskHeight: 384, sourceWidth: 4032, sourceHeight: 3024
        ))
    }

    func testMaskMatchesSourceAspectDetectsMismatch() {
        // Square mask against a 4:3 source — a real distortion, not rounding noise.
        XCTAssertFalse(AnalysisMath.maskMatchesSourceAspect(
            maskWidth: 512, maskHeight: 512, sourceWidth: 4032, sourceHeight: 3024
        ))
    }

    func testMaskMatchesSourceAspectZeroHeightIsFalseNotCrash() {
        XCTAssertFalse(AnalysisMath.maskMatchesSourceAspect(
            maskWidth: 512, maskHeight: 0, sourceWidth: 4032, sourceHeight: 3024
        ))
    }

    // MARK: - Area

    func testFrontalAreaCm2() {
        // 10000 foreground px at 5 px/cm → 10000 / 25 = 400 cm².
        let area = AnalysisMath.frontalAreaCm2(foregroundPixelCount: 10_000, maskPixelsPerCm: 5)
        XCTAssertEqual(area, 400, accuracy: acc)
    }

    func testCountForegroundPixelsIgnoresRowPadding() {
        // 3 rows of logical width 4, but bytesPerRow 6 (2 padding bytes per
        // row, deliberately set to 255 — worst case, as if uninitialised
        // memory happened to read as foreground). Only 2 of the 4 real
        // pixels per row are >= threshold; padding must not be counted.
        let bytesPerRow = 6
        let height = 3
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0 ..< height {
            let row = y * bytesPerRow
            buffer[row + 0] = 255
            buffer[row + 1] = 255
            buffer[row + 2] = 0
            buffer[row + 3] = 0
            buffer[row + 4] = 255 // padding — must be ignored
            buffer[row + 5] = 255 // padding — must be ignored
        }
        let count = buffer.withUnsafeBufferPointer { ptr in
            AnalysisMath.countForegroundPixels(
                bytes: ptr.baseAddress!, width: 4, height: height, bytesPerRow: bytesPerRow
            )
        }
        XCTAssertEqual(count, 2 * height)
    }

    func testUncertaintyIsThreePercent() {
        XCTAssertEqual(AnalysisMath.uncertaintyCm2(areaCm2: 400), 12, accuracy: acc)
    }

    func testUncertaintyDisplayRoundsAndFormats() {
        XCTAssertEqual(AnalysisMath.uncertaintyDisplay(154.7), "±155 cm²")
        XCTAssertEqual(AnalysisMath.uncertaintyDisplay(12.0), "±12 cm²")
    }

    func testAreaDisplayRoundsRatherThanTruncates() {
        // 2537.6 must read "2538", not "2537" (Plan I6 — the detail-screen bug).
        XCTAssertEqual(AnalysisMath.areaDisplay(2537.6), "2538")
        XCTAssertEqual(AnalysisMath.areaDisplay(400.0), "400")
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

    // MARK: - Wheel-ruler verification (Plan K)

    func testOverallWheelDiameterMm() {
        // 700C bead seat (622mm) + 2 * 45mm tire → 712mm.
        let d = AnalysisMath.overallWheelDiameterMm(beadSeatMm: 622, tireWidthMm: 45)
        XCTAssertEqual(d, 712, accuracy: acc)
    }

    func testWheelPixelsPerCm() {
        // 356px vertical tap span, 712mm (=71.2cm) wheel → 5 px/cm.
        let ppc = AnalysisMath.wheelPixelsPerCm(
            groundTap: CGPoint(x: 0.5, y: 0.9),
            topTap: CGPoint(x: 0.5, y: 0.544),
            imageSize: CGSize(width: 1000, height: 1000),
            wheelDiameterMm: 712
        )
        XCTAssertEqual(ppc, 5, accuracy: 0.01)
    }

    func testRulerDisagreementFractionZeroWhenEqual() {
        XCTAssertEqual(AnalysisMath.rulerDisagreementFraction(barPixelsPerCm: 10, wheelPixelsPerCm: 10), 0, accuracy: acc)
    }

    func testRulerDisagreementFractionDetectsMismatch() {
        // Wheel reads 18% higher than the bar-derived scale.
        let fraction = AnalysisMath.rulerDisagreementFraction(barPixelsPerCm: 10, wheelPixelsPerCm: 11.8)
        XCTAssertEqual(fraction, 0.18, accuracy: 1e-9)
    }

    func testWheelCheckDisplayAgreesWithinThreshold() {
        let result = AnalysisMath.wheelCheckDisplay(0.03)
        XCTAssertEqual(result.text, "agrees ±3%")
        XCTAssertFalse(result.isWarning)
    }

    func testWheelCheckDisplayAtThresholdBoundaryAgrees() {
        // Exactly at the threshold — inclusive, still "agrees".
        let result = AnalysisMath.wheelCheckDisplay(AnalysisMath.wheelCheckDisagreementThreshold)
        XCTAssertFalse(result.isWarning)
    }

    func testWheelCheckDisplayWarnsAboveThreshold() {
        let result = AnalysisMath.wheelCheckDisplay(0.18)
        XCTAssertEqual(result.text, "disagrees 18%")
        XCTAssertTrue(result.isWarning)
    }

    func testTireWidthMmPassesThroughForMmUnit() {
        XCTAssertEqual(AnalysisMath.tireWidthMm(fromEntry: 40, unit: .mm), 40, accuracy: acc)
    }

    func testTireWidthMmConvertsInchesToMm() {
        // 2.1" tire → 53.34mm.
        XCTAssertEqual(AnalysisMath.tireWidthMm(fromEntry: 2.1, unit: .inches), 53.34, accuracy: acc)
    }

    func testTireWidthDisplayValueRoundTripsInches() {
        let mm = AnalysisMath.tireWidthMm(fromEntry: 2.35, unit: .inches)
        let backToInches = AnalysisMath.tireWidthDisplayValue(fromMm: mm, unit: .inches)
        XCTAssertEqual(backToInches, 2.35, accuracy: acc)
    }

    func testTireWidthDisplayValuePassesThroughForMmUnit() {
        XCTAssertEqual(AnalysisMath.tireWidthDisplayValue(fromMm: 45, unit: .mm), 45, accuracy: acc)
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

    func testShoulderWidthWarningNilWhenPlausible() {
        XCTAssertNil(AnalysisMath.shoulderWidthWarning(45))
    }

    func testShoulderWidthWarningPresentWhenImplausible() {
        XCTAssertEqual(
            AnalysisMath.shoulderWidthWarning(21.8),
            "Shoulder width reads 22 cm — check your taps and the bike's bar width."
        )
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

    // MARK: - 3D pose geometry (Plan A6)

    func testTorsoAngle3DUprightIsZero() {
        let deg = AnalysisMath.torsoAngleDeg3D(shoulder: (x: 0, y: 0.5, z: 0), hip: (x: 0, y: 0, z: 0))
        XCTAssertEqual(deg, 0, accuracy: 1e-9)
    }

    func testTorsoAngle3DHorizontalIsNinety() {
        let deg = AnalysisMath.torsoAngleDeg3D(shoulder: (x: 0.5, y: 0, z: 0), hip: (x: 0, y: 0, z: 0))
        XCTAssertEqual(deg, 90, accuracy: 1e-9)
    }

    func testTorsoAngle3DIsInvariantToYaw() {
        // The whole point of 3D: the same physical lean, rotated about the
        // vertical axis, must read the same angle from vertical.
        let degFacingX = AnalysisMath.torsoAngleDeg3D(shoulder: (x: 0.3, y: 0.4, z: 0), hip: (x: 0, y: 0, z: 0))
        let degFacingZ = AnalysisMath.torsoAngleDeg3D(shoulder: (x: 0, y: 0.4, z: 0.3), hip: (x: 0, y: 0, z: 0))
        XCTAssertEqual(degFacingX, degFacingZ, accuracy: 1e-9)
    }

    func testHipAngle3DStraight() {
        let deg = AnalysisMath.hipAngleDeg3D(
            shoulder: (x: 0, y: 0.4, z: 0), hip: (x: 0, y: 0, z: 0), knee: (x: 0, y: -0.4, z: 0)
        )
        XCTAssertEqual(deg, 180, accuracy: 1e-6)
    }

    func testHipAngle3DRight() {
        let deg = AnalysisMath.hipAngleDeg3D(
            shoulder: (x: 0, y: 0.4, z: 0), hip: (x: 0, y: 0, z: 0), knee: (x: 0.4, y: 0, z: 0)
        )
        XCTAssertEqual(deg, 90, accuracy: 1e-6)
    }

    func testHipAngle3DDegenerateReturnsZero() {
        let deg = AnalysisMath.hipAngleDeg3D(
            shoulder: (x: 0, y: 0, z: 0), hip: (x: 0, y: 0, z: 0), knee: (x: 0, y: 0, z: 0)
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

    // MARK: - Pose delta (Plan P1)

    func testShoulderTiltLevelIsZero() {
        let deg = AnalysisMath.shoulderTiltDeg(
            leftShoulder: CGPoint(x: 0.3, y: 0.6), rightShoulder: CGPoint(x: 0.7, y: 0.6)
        )
        XCTAssertEqual(deg, 0, accuracy: 1e-9)
    }

    func testShoulderTilt45() {
        let deg = AnalysisMath.shoulderTiltDeg(
            leftShoulder: CGPoint(x: 0.3, y: 0.5), rightShoulder: CGPoint(x: 0.7, y: 0.9)
        )
        XCTAssertEqual(deg, 45, accuracy: 1e-9)
    }

    func testPoseAngleDeltaNilWhenNoChannelPresentOnBothSides() {
        let delta = AnalysisMath.poseAngleDelta(
            shoulderTiltDegA: nil, shoulderTiltDegB: nil,
            torsoAngleDegA: 20, torsoAngleDegB: nil,
            hipAngleDegA: nil, hipAngleDegB: 100
        )
        XCTAssertNil(delta)
    }

    func testPoseAngleDeltaSymmetricInputsIsZero() {
        let delta = AnalysisMath.poseAngleDelta(
            shoulderTiltDegA: 5, shoulderTiltDegB: 5,
            torsoAngleDegA: 20, torsoAngleDegB: 20,
            hipAngleDegA: 100, hipAngleDegB: 100
        )
        XCTAssertEqual(delta ?? -1, 0, accuracy: acc)
    }

    func testPoseAngleDeltaTakesLargestAvailableChannel() {
        let delta = AnalysisMath.poseAngleDelta(
            shoulderTiltDegA: 5, shoulderTiltDegB: 8,     // delta 3
            torsoAngleDegA: 20, torsoAngleDegB: 31,       // delta 11
            hipAngleDegA: 100, hipAngleDegB: 104          // delta 4
        )
        XCTAssertEqual(delta ?? -1, 11, accuracy: acc)
    }

    func testPoseDeltaWarningNilBelowNoteThreshold() {
        XCTAssertNil(AnalysisMath.poseDeltaWarning(angleDeltaDeg: 2))
    }

    func testPoseDeltaWarningNoteTierBetweenThresholds() {
        let warning = AnalysisMath.poseDeltaWarning(angleDeltaDeg: 5)
        XCTAssertEqual(warning?.severity, .note)
    }

    func testPoseDeltaWarningWarnTierAboveUpperThreshold() {
        let warning = AnalysisMath.poseDeltaWarning(angleDeltaDeg: 12)
        XCTAssertEqual(warning?.severity, .warn)
    }

    // MARK: - Side-on facing (Plan P3)

    func testSideOnFacingClearRightLeaningIsHighConfidence() {
        // Shoulder/ear/knee all forward (+x) of hip/shoulder — a pronounced,
        // unambiguous lean toward the bars.
        let result = AnalysisMath.sideOnFacing(
            shoulder: CGPoint(x: 0.65, y: 0.65), hip: CGPoint(x: 0.5, y: 0.35),
            knee: CGPoint(x: 0.58, y: 0.15), ear: CGPoint(x: 0.72, y: 0.68)
        )
        XCTAssertEqual(result.facing, .right)
        XCTAssertGreaterThanOrEqual(result.confidence, AnalysisMath.sideOnFacingConfidenceThreshold)
    }

    func testSideOnFacingClearLeftLeaningIsHighConfidence() {
        // Mirror of the right-facing case above.
        let result = AnalysisMath.sideOnFacing(
            shoulder: CGPoint(x: 0.35, y: 0.65), hip: CGPoint(x: 0.5, y: 0.35),
            knee: CGPoint(x: 0.42, y: 0.15), ear: CGPoint(x: 0.28, y: 0.68)
        )
        XCTAssertEqual(result.facing, .left)
        XCTAssertGreaterThanOrEqual(result.confidence, AnalysisMath.sideOnFacingConfidenceThreshold)
    }

    func testSideOnFacingNearUprightIsLowConfidence() {
        // Torso nearly vertical, tiny/noisy horizontal displacements — the
        // ambiguous case the UI should ask about rather than guess.
        let result = AnalysisMath.sideOnFacing(
            shoulder: CGPoint(x: 0.50, y: 0.7), hip: CGPoint(x: 0.50, y: 0.4),
            knee: CGPoint(x: 0.49, y: 0.15), ear: CGPoint(x: 0.51, y: 0.75)
        )
        XCTAssertLessThan(result.confidence, AnalysisMath.sideOnFacingConfidenceThreshold)
    }
}
