import XCTest
@testable import GetTucked

final class OrientationBucketTests: XCTestCase {
    // MARK: - Mapping tables

    func testReferenceRollDeg() {
        XCTAssertEqual(OrientationBucket.portrait.referenceRollDeg, 0)
        XCTAssertEqual(OrientationBucket.landscapeLeft.referenceRollDeg, -90)
        XCTAssertEqual(OrientationBucket.landscapeRight.referenceRollDeg, 90)
    }

    func testVideoRotationAngle() {
        XCTAssertEqual(OrientationBucket.portrait.videoRotationAngle, 90)
        XCTAssertEqual(OrientationBucket.landscapeLeft.videoRotationAngle, 0)
        XCTAssertEqual(OrientationBucket.landscapeRight.videoRotationAngle, 180)
    }

    // MARK: - Clear readings (no hysteresis ambiguity)

    func testPicksPortraitWhenGravityStraightDown() {
        let bucket = OrientationBucket.pick(gravityX: 0, gravityY: -1, current: .landscapeLeft)
        XCTAssertEqual(bucket, .portrait)
    }

    func testPicksLandscapeLeftWhenGravityPointsNegativeX() {
        // Rotated CCW, top of phone to the left.
        let bucket = OrientationBucket.pick(gravityX: -1, gravityY: 0, current: .portrait)
        XCTAssertEqual(bucket, .landscapeLeft)
    }

    func testPicksLandscapeRightWhenGravityPointsPositiveX() {
        // Rotated CW, top of phone to the right.
        let bucket = OrientationBucket.pick(gravityX: 1, gravityY: 0, current: .portrait)
        XCTAssertEqual(bucket, .landscapeRight)
    }

    // MARK: - Hysteresis at the 45° diagonal

    func testStaysPortraitAtDiagonalWhenCurrentlyPortrait() {
        // |x| == |y| — without hysteresis this is a coin flip; with it,
        // staying in the current bucket wins.
        let bucket = OrientationBucket.pick(gravityX: 0.7, gravityY: -0.7, current: .portrait)
        XCTAssertEqual(bucket, .portrait)
    }

    func testStaysLandscapeAtDiagonalWhenCurrentlyLandscape() {
        let bucket = OrientationBucket.pick(gravityX: 0.7, gravityY: -0.7, current: .landscapeRight)
        XCTAssertEqual(bucket, .landscapeRight)
    }

    func testSwitchesAwayFromPortraitOnlyPastHysteresisRatio() {
        // Just past the diagonal but under the 1.2 ratio — stays portrait.
        let stillPortrait = OrientationBucket.pick(gravityX: 0.75, gravityY: -0.66, current: .portrait)
        XCTAssertEqual(stillPortrait, .portrait)

        // Clearly past the ratio — switches.
        let switched = OrientationBucket.pick(gravityX: 0.95, gravityY: -0.3, current: .portrait)
        XCTAssertEqual(switched, .landscapeRight)
    }

    func testSwitchesToPortraitOnlyPastHysteresisRatio() {
        let stillLandscape = OrientationBucket.pick(gravityX: 0.66, gravityY: -0.75, current: .landscapeRight)
        XCTAssertEqual(stillLandscape, .landscapeRight)

        let switched = OrientationBucket.pick(gravityX: 0.3, gravityY: -0.95, current: .landscapeRight)
        XCTAssertEqual(switched, .portrait)
    }
}
