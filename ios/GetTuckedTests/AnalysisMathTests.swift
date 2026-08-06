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

    // MARK: - wheelSpanUnitY (Plan Z5)

    func testWheelSpanUnitYWorkedExample() {
        // Axles purely horizontal (dy=0), unit dx=0.5, square image (aspect
        // 1) → wheelbase unit length 0.5. wheelDiameter/wheelbase = 700/1000
        // = 0.7 → span = 0.35.
        let span = AnalysisMath.wheelSpanUnitY(
            axleFront: CGPoint(x: 0.7, y: 0.8), axleRear: CGPoint(x: 0.2, y: 0.8),
            imageAspect: 1, wheelbaseMm: 1000, wheelDiameterMm: 700
        )
        XCTAssertEqual(span, 0.35, accuracy: 1e-9)
    }

    func testWheelSpanUnitYScalesWithAspectOnTheXAxisOnly() {
        // Same unit dx but a 2:1 aspect image → dx contributes twice as much
        // physical (pixel) distance, so the resulting span (also expressed
        // against height) doubles.
        let square = AnalysisMath.wheelSpanUnitY(
            axleFront: CGPoint(x: 0.7, y: 0.5), axleRear: CGPoint(x: 0.2, y: 0.5),
            imageAspect: 1, wheelbaseMm: 1000, wheelDiameterMm: 700
        )
        let wide = AnalysisMath.wheelSpanUnitY(
            axleFront: CGPoint(x: 0.7, y: 0.5), axleRear: CGPoint(x: 0.2, y: 0.5),
            imageAspect: 2, wheelbaseMm: 1000, wheelDiameterMm: 700
        )
        XCTAssertEqual(wide, square * 2, accuracy: 1e-9)
    }

    func testWheelSpanUnitYZeroWheelbaseReturnsZero() {
        XCTAssertEqual(
            AnalysisMath.wheelSpanUnitY(axleFront: .zero, axleRear: .zero, imageAspect: 1, wheelbaseMm: 0, wheelDiameterMm: 700),
            0, accuracy: acc
        )
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
        // Wheel reads 18% higher than the bar-derived scale — positive
        // (oversized, Plan Z3's signed convention).
        let fraction = AnalysisMath.rulerDisagreementFraction(barPixelsPerCm: 10, wheelPixelsPerCm: 11.8)
        XCTAssertEqual(fraction, 0.18, accuracy: 1e-9)
    }

    func testRulerDisagreementFractionNegativeWhenWheelMeasuresSmaller() {
        // Wheel reads 12% lower than the bar-derived scale — negative
        // (undersized, Plan Z3's signed convention).
        let fraction = AnalysisMath.rulerDisagreementFraction(barPixelsPerCm: 10, wheelPixelsPerCm: 8.8)
        XCTAssertEqual(fraction, -0.12, accuracy: 1e-9)
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

    func testWheelCheckDisplayHandlesNegativeDisagreement() {
        // Signed (Plan Z3) — the displayed percentage is always unsigned.
        let result = AnalysisMath.wheelCheckDisplay(-0.18)
        XCTAssertEqual(result.text, "disagrees 18%")
        XCTAssertTrue(result.isWarning)
    }

    // MARK: - wheelCheckWarning (Plan Z3)

    func testWheelCheckWarningNilWhenAgrees() {
        XCTAssertNil(AnalysisMath.wheelCheckWarning(0.03))
        XCTAssertNil(AnalysisMath.wheelCheckWarning(-0.03))
    }

    func testWheelCheckWarningNilAtThresholdBoundary() {
        XCTAssertNil(AnalysisMath.wheelCheckWarning(AnalysisMath.wheelCheckDisagreementThreshold))
    }

    func testWheelCheckWarningNamesPerspectiveWhenOversized() {
        let warning = AnalysisMath.wheelCheckWarning(0.26)
        XCTAssertEqual(
            warning,
            "Front wheel reads 26% larger than its spec size — usually the camera was too close (the wheel sits forward of the bars). Area may read high; try standing back and zooming."
        )
    }

    func testWheelCheckWarningKeepsTapsFramingWhenUndersized() {
        let warning = AnalysisMath.wheelCheckWarning(-0.18)
        XCTAssertEqual(
            warning,
            "Front wheel reads 18% smaller than its spec size — check your taps and the bike's bar width."
        )
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

    // MARK: - Bike coverage display (Plan Z4)

    func testBikeCoverageDisplayFormatsFractionAsWholePercent() {
        XCTAssertEqual(AnalysisMath.bikeCoverageDisplay(0.18), "18%")
    }

    func testBikeCoverageDisplayRoundsToNearestPercent() {
        XCTAssertEqual(AnalysisMath.bikeCoverageDisplay(0.184), "18%")
        XCTAssertEqual(AnalysisMath.bikeCoverageDisplay(0.186), "19%")
    }

    func testBikeCoverageDisplayZeroReadsAsZeroPercent() {
        // The night-shot case (Plan Z8): the subject lift found no bike —
        // this must read as an honest 0%, not "—" (that's reserved for "no
        // subject mask at all").
        XCTAssertEqual(AnalysisMath.bikeCoverageDisplay(0), "0%")
    }

    func testBikeCoverageDisplayNilReadsAsDash() {
        XCTAssertEqual(AnalysisMath.bikeCoverageDisplay(nil), "—")
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

    // MARK: - Physical overlay (ghost-compare)

    func testMaskPixelsPerCmFromAreaKnownRatio() {
        // 400 foreground pixels over 100cm² → sqrt(4) = 2 px/cm.
        let scale = AnalysisMath.maskPixelsPerCm(foregroundPixelCount: 400, areaCm2: 100)
        XCTAssertEqual(scale, 2, accuracy: acc)
    }

    func testMaskPixelsPerCmFromAreaZeroAreaReturnsZero() {
        XCTAssertEqual(AnalysisMath.maskPixelsPerCm(foregroundPixelCount: 400, areaCm2: 0), 0, accuracy: acc)
    }

    func testAnchorCmCentredBarsAndLowGround() {
        // 100x200px mask at 2px/cm → 50x100cm. Bars dead-centre (unit 0.5),
        // ground near the bottom (unit 0.1) → anchor (25, 10).
        let anchor = AnalysisMath.anchorCm(
            handlebarMidUnitX: 0.5, groundUnitY: 0.1,
            maskSize: CGSize(width: 100, height: 200), maskPixelsPerCm: 2
        )
        XCTAssertEqual(anchor.x, 25, accuracy: acc)
        XCTAssertEqual(anchor.y, 10, accuracy: acc)
    }

    func testAnchorCmZeroScaleReturnsZero() {
        let anchor = AnalysisMath.anchorCm(
            handlebarMidUnitX: 0.5, groundUnitY: 0.1,
            maskSize: CGSize(width: 100, height: 200), maskPixelsPerCm: 0
        )
        XCTAssertEqual(anchor, .zero)
    }

    func testOverlayPlacementCentredAnchorNeedsNoHorizontalShift() {
        // Same mask as above (50x100cm), anchor at its own horizontal centre
        // (25) but 40cm below its vertical centre (10 vs the 50cm midline) —
        // so the image's centre should land directly above the shared point,
        // with no horizontal shift.
        let placement = AnalysisMath.overlayPlacement(
            maskSize: CGSize(width: 100, height: 200), maskPixelsPerCm: 2,
            anchorCm: CGPoint(x: 25, y: 10),
            sharedAnchorScreenPoint: CGPoint(x: 300, y: 400), screenPointsPerCm: 3
        )
        XCTAssertEqual(placement.frameSize.width, 150, accuracy: acc)
        XCTAssertEqual(placement.frameSize.height, 300, accuracy: acc)
        XCTAssertEqual(placement.center.x, 300, accuracy: acc)
        XCTAssertEqual(placement.center.y, 280, accuracy: acc)  // 400 - 40*3
    }

    func testOverlayPlacementOffCentreAnchorShiftsHorizontally() {
        // Same mask/scale, but the handlebar anchor sits left of the mask's
        // own centre (20 vs 25) — the image's centre should shift right of
        // the shared point to compensate, so the anchor still lands there.
        let placement = AnalysisMath.overlayPlacement(
            maskSize: CGSize(width: 100, height: 200), maskPixelsPerCm: 2,
            anchorCm: CGPoint(x: 20, y: 10),
            sharedAnchorScreenPoint: CGPoint(x: 300, y: 400), screenPointsPerCm: 3
        )
        XCTAssertEqual(placement.center.x, 315, accuracy: acc)  // 300 + 5*3
        XCTAssertEqual(placement.center.y, 280, accuracy: acc)
    }

    func testOverlayPlacementZeroScaleReturnsSharedPoint() {
        let placement = AnalysisMath.overlayPlacement(
            maskSize: CGSize(width: 100, height: 200), maskPixelsPerCm: 0,
            anchorCm: CGPoint(x: 20, y: 10),
            sharedAnchorScreenPoint: CGPoint(x: 300, y: 400), screenPointsPerCm: 3
        )
        XCTAssertEqual(placement.frameSize, .zero)
        XCTAssertEqual(placement.center, CGPoint(x: 300, y: 400))
    }

    func testOverlayExtentCmRelativeToAnchor() {
        // 50x100cm mask (100x200px @ 2px/cm), anchor at (25, 10) —
        // extent should span 25cm either side of the anchor horizontally,
        // 10cm below and 90cm above it vertically.
        let extent = AnalysisMath.overlayExtentCm(
            maskSize: CGSize(width: 100, height: 200), maskPixelsPerCm: 2,
            anchorCm: CGPoint(x: 25, y: 10)
        )
        XCTAssertEqual(extent.minX, -25, accuracy: acc)
        XCTAssertEqual(extent.maxX, 25, accuracy: acc)
        XCTAssertEqual(extent.minY, -10, accuracy: acc)
        XCTAssertEqual(extent.maxY, 90, accuracy: acc)
    }

    func testOverlayFitIdenticalExtentsScalesToFitContainer() {
        let extent = (minX: -25.0, maxX: 25.0, minY: -10.0, maxY: 90.0)
        let fit = AnalysisMath.overlayFit(
            extentA: extent, extentB: extent, containerSize: CGSize(width: 500, height: 1000)
        )
        // unionWidth 50cm into 500pt, unionHeight 100cm into 1000pt — both
        // give scale 10, so the binding constraint is the same either axis;
        // padding 0.9 default → scale 9.
        XCTAssertEqual(fit.screenPointsPerCm, 9, accuracy: acc)
        XCTAssertEqual(fit.anchorScreenPoint.x, 250, accuracy: acc)
        XCTAssertEqual(fit.anchorScreenPoint.y, 860, accuracy: acc)  // 500 + 40*9
    }

    func testOverlayFitUnionsWiderOfTwoExtents() {
        // B is wider on the left than A — the shared scale/anchor must
        // account for B's extent too, not just A's.
        let extentA = (minX: -25.0, maxX: 25.0, minY: -10.0, maxY: 90.0)
        let extentB = (minX: -40.0, maxX: 10.0, minY: -10.0, maxY: 90.0)
        let fit = AnalysisMath.overlayFit(
            extentA: extentA, extentB: extentB, containerSize: CGSize(width: 650, height: 1000)
        )
        // unionWidth 65cm into 650pt, unionHeight 100cm into 1000pt — both
        // scale-to-10 again, padding 0.9 → scale 9.
        XCTAssertEqual(fit.screenPointsPerCm, 9, accuracy: acc)
        XCTAssertEqual(fit.anchorScreenPoint.x, 392.5, accuracy: acc)  // 325 - (-7.5*9)
        XCTAssertEqual(fit.anchorScreenPoint.y, 860, accuracy: acc)
    }

    func testOverlayFitDegenerateExtentFallsBackToContainerCentre() {
        let zeroExtent = (minX: 0.0, maxX: 0.0, minY: 0.0, maxY: 0.0)
        let fit = AnalysisMath.overlayFit(
            extentA: zeroExtent, extentB: zeroExtent, containerSize: CGSize(width: 400, height: 800)
        )
        XCTAssertEqual(fit.anchorScreenPoint, CGPoint(x: 200, y: 400))
    }

    // MARK: - Subject-mask instance selection (Plan W2)

    func testOverlapAreaOfIntersectingBoxes() {
        let a = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        let b = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        XCTAssertEqual(AnalysisMath.overlapArea(a, b), 0.0625, accuracy: acc) // 0.25 x 0.25
    }

    func testOverlapAreaOfNonIntersectingBoxesIsZero() {
        let a = CGRect(x: 0, y: 0, width: 0.2, height: 0.2)
        let b = CGRect(x: 0.8, y: 0.8, width: 0.2, height: 0.2)
        XCTAssertEqual(AnalysisMath.overlapArea(a, b), 0)
    }

    func testRiderInstancePicksBoxWithMostOverlap() {
        let riderBox = CGRect(x: 0.3, y: 0.3, width: 0.3, height: 0.4)
        let boxes: [Int: CGRect] = [
            1: CGRect(x: 0.3, y: 0.3, width: 0.3, height: 0.4), // exact match — most overlap
            2: CGRect(x: 0.0, y: 0.0, width: 0.1, height: 0.1), // far away, no overlap
        ]
        XCTAssertEqual(AnalysisMath.riderInstance(instanceBoxes: boxes, riderBox: riderBox), 1)
    }

    func testRiderInstanceEmptyBoxesReturnsNil() {
        XCTAssertNil(AnalysisMath.riderInstance(instanceBoxes: [:], riderBox: .zero))
    }

    func testConnectedInstancesIncludesRiderAndTouchingBoxesOnly() {
        let boxes: [Int: CGRect] = [
            1: CGRect(x: 0.3, y: 0.3, width: 0.2, height: 0.4), // rider
            2: CGRect(x: 0.49, y: 0.3, width: 0.1, height: 0.1), // just touches rider's expanded box
            3: CGRect(x: 0.9, y: 0.9, width: 0.05, height: 0.05), // far away — disconnected clutter
        ]
        let selected = AnalysisMath.connectedInstances(riderInstance: 1, instanceBoxes: boxes, margin: 0.06)
        XCTAssertTrue(selected.contains(1))
        XCTAssertTrue(selected.contains(2))
        XCTAssertFalse(selected.contains(3))
    }

    func testConnectedInstancesUnknownRiderInstanceReturnsEmpty() {
        let boxes: [Int: CGRect] = [1: CGRect(x: 0, y: 0, width: 0.2, height: 0.2)]
        XCTAssertTrue(AnalysisMath.connectedInstances(riderInstance: 99, instanceBoxes: boxes).isEmpty)
    }

    // MARK: - Bike swap rescale (Plan Y1)

    func testBarRescaleRatio() {
        XCTAssertEqual(AnalysisMath.barRescaleRatio(oldBarMm: 400, newBarMm: 500), 1.25, accuracy: acc)
    }

    func testWheelbaseRescaleRatio() {
        XCTAssertEqual(AnalysisMath.wheelbaseRescaleRatio(oldWheelbaseMm: 1000, newWheelbaseMm: 1100), 1.1, accuracy: acc)
    }

    /// A full swap, no wheel check, no side-on ruler — just the bar-driven
    /// numbers. r = 500/400 = 1.25: pixelsPerCm divides by r, area/uncertainty
    /// scale by r², shoulder width scales by r.
    func testRescaledMetricsScalesFrontalNumbersByBarRatio() {
        let input = AnalysisMath.BikeSwapInput(
            pixelsPerCm: 10,
            frontalAreaCm2: 400,
            frontalAreaUncertainty: 12,
            shoulderWidthCm: 42,
            armWidthCm: nil,
            sideOnPixelsPerCm: nil,
            headDropCm: nil,
            wheelTapPoints: nil,
            imageAspect: CGSize(width: 1, height: 1),
            oldHandlebarWidthMm: 400,
            newHandlebarWidthMm: 500,
            oldWheelbaseMm: nil,
            newWheelbaseMm: nil,
            newWheelDiameterMm: nil
        )
        let result = AnalysisMath.rescaledMetrics(input)
        XCTAssertEqual(result.pixelsPerCm, 8, accuracy: acc) // 10 / 1.25
        XCTAssertEqual(result.frontalAreaCm2, 625, accuracy: acc) // 400 * 1.25^2
        XCTAssertEqual(result.frontalAreaUncertainty, 18.75, accuracy: acc) // 12 * 1.25^2
        XCTAssertEqual(result.shoulderWidthCm ?? -1, 52.5, accuracy: acc) // 42 * 1.25
        XCTAssertEqual(result.handlebarWidthMmUsed, 500, accuracy: acc)
        XCTAssertNil(result.wheelCheckDisagreementFraction)
        XCTAssertNil(result.sideOnPixelsPerCm)
    }

    /// Pins the wheel-check recompute against the exact same functions
    /// AnalysisEngine's capture-time derivation uses (wheelPixelsPerCm +
    /// rulerDisagreementFraction), worked by hand: a 356px vertical tap span
    /// on a square 1000x1000-equivalent image, bar re-derived to 8 px/cm
    /// (400mm bar, r=1.25 → 10/1.25), new wheel diameter 800mm.
    func testRescaledMetricsWheelCheckRecomputeMatchesCaptureTimeDerivation() {
        let input = AnalysisMath.BikeSwapInput(
            pixelsPerCm: 10,
            frontalAreaCm2: 400,
            frontalAreaUncertainty: 12,
            shoulderWidthCm: nil,
            armWidthCm: nil,
            sideOnPixelsPerCm: nil,
            headDropCm: nil,
            wheelTapPoints: [0.5, 0.9, 0.5, 0.544],
            imageAspect: CGSize(width: 1000, height: 1000),
            oldHandlebarWidthMm: 400,
            newHandlebarWidthMm: 500,
            oldWheelbaseMm: nil,
            newWheelbaseMm: nil,
            newWheelDiameterMm: 800
        )
        let result = AnalysisMath.rescaledMetrics(input)
        // wheelPixels = hypot(0, 0.356*1000) = 356; wheelPixelsPerCm = 356/80 = 4.45
        // barPixelsPerCm (new) = 8; disagreement = (4.45 - 8) / 8 = -0.44375
        // (signed, Plan Z3 — the wheel measures SMALLER than the bar scale here).
        XCTAssertEqual(result.wheelCheckDisagreementFraction ?? 1, -0.44375, accuracy: 1e-6)

        // Same value derived independently via the plain functions, as a
        // belt-and-braces check that the recompute really does reuse them.
        let expectedWheelPpc = AnalysisMath.wheelPixelsPerCm(
            groundTap: CGPoint(x: 0.5, y: 0.9), topTap: CGPoint(x: 0.5, y: 0.544),
            imageSize: CGSize(width: 1000, height: 1000), wheelDiameterMm: 800
        )
        let expected = AnalysisMath.rulerDisagreementFraction(barPixelsPerCm: 8, wheelPixelsPerCm: expectedWheelPpc)
        XCTAssertEqual(result.wheelCheckDisagreementFraction ?? 1, expected, accuracy: 1e-9)
    }

    func testRescaledMetricsWheelCheckNilWhenNewBikeHasNoWheelData() {
        let input = AnalysisMath.BikeSwapInput(
            pixelsPerCm: 10, frontalAreaCm2: 400, frontalAreaUncertainty: 12,
            shoulderWidthCm: nil, armWidthCm: nil, sideOnPixelsPerCm: nil, headDropCm: nil,
            wheelTapPoints: [0.5, 0.9, 0.5, 0.544], imageAspect: CGSize(width: 1000, height: 1000),
            oldHandlebarWidthMm: 400, newHandlebarWidthMm: 500,
            oldWheelbaseMm: nil, newWheelbaseMm: nil, newWheelDiameterMm: nil
        )
        XCTAssertNil(AnalysisMath.rescaledMetrics(input).wheelCheckDisagreementFraction)
    }

    /// Side-on numbers scale by the wheelbase ratio when both bikes have a
    /// wheelbase on record.
    func testRescaledMetricsSideOnScalesByWheelbaseRatio() {
        let input = AnalysisMath.BikeSwapInput(
            pixelsPerCm: 10, frontalAreaCm2: 400, frontalAreaUncertainty: 12,
            shoulderWidthCm: nil, armWidthCm: nil, sideOnPixelsPerCm: 12, headDropCm: 5,
            wheelTapPoints: nil, imageAspect: CGSize(width: 1, height: 1),
            oldHandlebarWidthMm: 400, newHandlebarWidthMm: 400,
            oldWheelbaseMm: 1000, newWheelbaseMm: 1100, newWheelDiameterMm: nil
        )
        let result = AnalysisMath.rescaledMetrics(input)
        XCTAssertEqual(result.sideOnPixelsPerCm ?? -1, 12 / 1.1, accuracy: acc)
        XCTAssertEqual(result.headDropCm ?? -1, 5.5, accuracy: acc) // 5 * 1.1
    }

    /// Plan Y2's edge case: the new bike has no wheelbase on record — both
    /// side-on numbers nil out rather than showing an indefensible figure.
    func testRescaledMetricsSideOnNilsOutWhenNewBikeLacksWheelbase() {
        let input = AnalysisMath.BikeSwapInput(
            pixelsPerCm: 10, frontalAreaCm2: 400, frontalAreaUncertainty: 12,
            shoulderWidthCm: nil, armWidthCm: nil, sideOnPixelsPerCm: 12, headDropCm: 5,
            wheelTapPoints: nil, imageAspect: CGSize(width: 1, height: 1),
            oldHandlebarWidthMm: 400, newHandlebarWidthMm: 400,
            oldWheelbaseMm: 1000, newWheelbaseMm: nil, newWheelDiameterMm: nil
        )
        let result = AnalysisMath.rescaledMetrics(input)
        XCTAssertNil(result.sideOnPixelsPerCm)
        XCTAssertNil(result.headDropCm)
    }

    /// A side-on capture with no wheelbase ruler (sideOnPixelsPerCm already
    /// nil pre-swap) leaves headDropCm untouched — it borrowed the frontal
    /// scale and stays hidden from display regardless (Plan Y1).
    func testRescaledMetricsLeavesBorrowedHeadDropUntouchedWhenSideOnScaleAlreadyNil() {
        let input = AnalysisMath.BikeSwapInput(
            pixelsPerCm: 10, frontalAreaCm2: 400, frontalAreaUncertainty: 12,
            shoulderWidthCm: nil, armWidthCm: nil, sideOnPixelsPerCm: nil, headDropCm: 3.5,
            wheelTapPoints: nil, imageAspect: CGSize(width: 1, height: 1),
            oldHandlebarWidthMm: 400, newHandlebarWidthMm: 500,
            oldWheelbaseMm: nil, newWheelbaseMm: 1100, newWheelDiameterMm: nil
        )
        let result = AnalysisMath.rescaledMetrics(input)
        XCTAssertNil(result.sideOnPixelsPerCm)
        XCTAssertEqual(result.headDropCm ?? -1, 3.5, accuracy: acc)
    }

    /// Swap A→B then back to A restores every field to within 1e-9 — the
    /// closed-form round trip Plan Y1 requires. Each leg is recomputed fresh
    /// (not chained multiplicatively), so this also exercises that the
    /// wheel-check recompute genuinely returns to its original value rather
    /// than drifting.
    func testRescaledMetricsRoundTripRestoresOriginalValues() {
        let original = AnalysisMath.BikeSwapInput(
            pixelsPerCm: 10,
            frontalAreaCm2: 437.5,
            frontalAreaUncertainty: 13.125,
            shoulderWidthCm: 41.3,
            armWidthCm: nil,
            sideOnPixelsPerCm: 9.6,
            headDropCm: 4.2,
            wheelTapPoints: [0.5, 0.9, 0.5, 0.544],
            imageAspect: CGSize(width: 1000, height: 1000),
            oldHandlebarWidthMm: 400,
            newHandlebarWidthMm: 500, // -> bike B
            oldWheelbaseMm: 1000,
            newWheelbaseMm: 1080,
            newWheelDiameterMm: 700
        )
        let toB = AnalysisMath.rescaledMetrics(original)

        let backToA = AnalysisMath.BikeSwapInput(
            pixelsPerCm: toB.pixelsPerCm,
            frontalAreaCm2: toB.frontalAreaCm2,
            frontalAreaUncertainty: toB.frontalAreaUncertainty,
            shoulderWidthCm: toB.shoulderWidthCm,
            armWidthCm: toB.armWidthCm,
            sideOnPixelsPerCm: toB.sideOnPixelsPerCm,
            headDropCm: toB.headDropCm,
            wheelTapPoints: original.wheelTapPoints,
            imageAspect: original.imageAspect,
            oldHandlebarWidthMm: toB.handlebarWidthMmUsed, // 500 (bike B)
            newHandlebarWidthMm: original.oldHandlebarWidthMm, // back to 400 (bike A)
            oldWheelbaseMm: original.newWheelbaseMm, // bike B's wheelbase
            newWheelbaseMm: original.oldWheelbaseMm, // back to bike A's
            newWheelDiameterMm: 712 // bike A's original wheel diameter
        )
        let backResult = AnalysisMath.rescaledMetrics(backToA)

        XCTAssertEqual(backResult.pixelsPerCm, original.pixelsPerCm, accuracy: 1e-9)
        XCTAssertEqual(backResult.frontalAreaCm2, original.frontalAreaCm2, accuracy: 1e-9)
        XCTAssertEqual(backResult.frontalAreaUncertainty, original.frontalAreaUncertainty, accuracy: 1e-9)
        XCTAssertEqual(backResult.shoulderWidthCm ?? -1, original.shoulderWidthCm ?? -2, accuracy: 1e-9)
        XCTAssertEqual(backResult.sideOnPixelsPerCm ?? -1, original.sideOnPixelsPerCm ?? -2, accuracy: 1e-9)
        XCTAssertEqual(backResult.headDropCm ?? -1, original.headDropCm ?? -2, accuracy: 1e-9)
        XCTAssertEqual(backResult.handlebarWidthMmUsed, original.oldHandlebarWidthMm, accuracy: 1e-9)

        // Wheel check recomputed against bike A's original wheel diameter
        // (712mm, same worked example as testWheelPixelsPerCm) must match
        // what capture time would have produced for the same taps/scale.
        let expectedWheelPpc = AnalysisMath.wheelPixelsPerCm(
            groundTap: CGPoint(x: 0.5, y: 0.9), topTap: CGPoint(x: 0.5, y: 0.544),
            imageSize: CGSize(width: 1000, height: 1000), wheelDiameterMm: 712
        )
        let expectedDisagreement = AnalysisMath.rulerDisagreementFraction(
            barPixelsPerCm: original.pixelsPerCm, wheelPixelsPerCm: expectedWheelPpc
        )
        XCTAssertEqual(backResult.wheelCheckDisagreementFraction ?? -1, expectedDisagreement, accuracy: 1e-9)
    }
}
