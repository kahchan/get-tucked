import XCTest
@testable import GetTucked

final class PinchPhysicsTests: XCTestCase {
    // MARK: - rubberband

    func testRubberbandIsZeroAtZeroOvershoot() {
        XCTAssertEqual(PinchPhysics.rubberband(overshoot: 0, dimension: 300), 0)
    }

    func testRubberbandIsMonotonicIncreasingWithOvershoot() {
        let small = PinchPhysics.rubberband(overshoot: 10, dimension: 300)
        let medium = PinchPhysics.rubberband(overshoot: 50, dimension: 300)
        let large = PinchPhysics.rubberband(overshoot: 200, dimension: 300)
        XCTAssertLessThan(small, medium)
        XCTAssertLessThan(medium, large)
    }

    func testRubberbandIsBoundedByDimension() {
        let dimension: CGFloat = 300
        let extreme = PinchPhysics.rubberband(overshoot: 1_000_000, dimension: dimension)
        XCTAssertLessThan(extreme, dimension)
        XCTAssertGreaterThan(extreme, dimension * 0.9) // approaches but never reaches
    }

    func testRubberbandPreservesSign() {
        let positive = PinchPhysics.rubberband(overshoot: 40, dimension: 300)
        let negative = PinchPhysics.rubberband(overshoot: -40, dimension: 300)
        XCTAssertGreaterThan(positive, 0)
        XCTAssertLessThan(negative, 0)
        XCTAssertEqual(positive, -negative, accuracy: 0.0001) // symmetric
    }

    func testRubberbandResistsLessThanRawOvershoot() {
        // The whole point of rubber-banding: displayed movement is always
        // less than the raw finger movement past the boundary.
        let overshoot: CGFloat = 80
        let resisted = PinchPhysics.rubberband(overshoot: overshoot, dimension: 300)
        XCTAssertLessThan(resisted, overshoot)
    }

    func testRubberbandZeroDimensionReturnsZero() {
        XCTAssertEqual(PinchPhysics.rubberband(overshoot: 50, dimension: 0), 0)
    }

    // MARK: - normalizedVelocity

    func testNormalizedVelocityIsZeroWhenAlreadyAtTarget() {
        let velocity = PinchPhysics.normalizedVelocity(gestureVelocity: 500, current: 2.0, target: 2.0)
        XCTAssertEqual(velocity, 0)
    }

    func testNormalizedVelocityDividesByRemainingDistance() {
        // Moving toward the target (positive gesture velocity, target ahead).
        let velocity = PinchPhysics.normalizedVelocity(gestureVelocity: 100, current: 0, target: 50)
        XCTAssertEqual(velocity, 2.0, accuracy: 0.0001)
    }

    func testNormalizedVelocitySignReflectsDirection() {
        let towardTarget = PinchPhysics.normalizedVelocity(gestureVelocity: 100, current: 0, target: 50)
        let awayFromTarget = PinchPhysics.normalizedVelocity(gestureVelocity: -100, current: 0, target: 50)
        XCTAssertGreaterThan(towardTarget, 0)
        XCTAssertLessThan(awayFromTarget, 0)
    }

    // MARK: - focalOffset (Plan AA)

    /// Screen position of a content point q (relative to centre, at scale 1)
    /// is `offset + scale·q` — the model `scaleEffect(anchor:.center)` +
    /// `offset` implements. The focal point must map to the same screen spot
    /// before and after the scale change.
    private func screenPosition(of contentPoint: CGSize, scale: CGFloat, offset: CGSize) -> CGSize {
        CGSize(width: offset.width + scale * contentPoint.width, height: offset.height + scale * contentPoint.height)
    }

    func testFocalOffsetKeepsFocalPointFixedFromUnzoomed() {
        let scale0: CGFloat = 1, offset0 = CGSize.zero, newScale: CGFloat = 2
        let focal = CGSize(width: 100, height: 50)
        let q = CGSize(width: (focal.width - offset0.width) / scale0, height: (focal.height - offset0.height) / scale0)
        let offset1 = PinchPhysics.focalOffset(scale0: scale0, offset0: offset0, newScale: newScale, focal: focal)
        let after = screenPosition(of: q, scale: newScale, offset: offset1)
        XCTAssertEqual(after.width, focal.width, accuracy: 0.0001)
        XCTAssertEqual(after.height, focal.height, accuracy: 0.0001)
    }

    func testFocalOffsetKeepsFocalPointFixedFromAlreadyZoomedAndPanned() {
        let scale0: CGFloat = 1.5, offset0 = CGSize(width: 20, height: -10), newScale: CGFloat = 3
        let focal = CGSize(width: 60, height: 40)
        let q = CGSize(width: (focal.width - offset0.width) / scale0, height: (focal.height - offset0.height) / scale0)
        let offset1 = PinchPhysics.focalOffset(scale0: scale0, offset0: offset0, newScale: newScale, focal: focal)
        let after = screenPosition(of: q, scale: newScale, offset: offset1)
        XCTAssertEqual(after.width, focal.width, accuracy: 0.0001)
        XCTAssertEqual(after.height, focal.height, accuracy: 0.0001)
    }

    func testFocalOffsetNoOpWhenScaleUnchanged() {
        let offset0 = CGSize(width: 12, height: -7)
        let offset1 = PinchPhysics.focalOffset(scale0: 2, offset0: offset0, newScale: 2, focal: CGSize(width: 33, height: 44))
        XCTAssertEqual(offset1.width, offset0.width, accuracy: 0.0001)
        XCTAssertEqual(offset1.height, offset0.height, accuracy: 0.0001)
    }

    func testFocalOffsetCentredFocalActsLikeCentreAnchor() {
        // A focal point at the container centre (0,0 relative) leaves the
        // offset untouched — zooming about the centre needs no pan.
        let offset1 = PinchPhysics.focalOffset(scale0: 1, offset0: .zero, newScale: 2.5, focal: .zero)
        XCTAssertEqual(offset1.width, 0, accuracy: 0.0001)
        XCTAssertEqual(offset1.height, 0, accuracy: 0.0001)
    }

    func testFocalOffsetGuardsZeroScale() {
        let offset0 = CGSize(width: 5, height: 6)
        let offset1 = PinchPhysics.focalOffset(scale0: 0, offset0: offset0, newScale: 2, focal: CGSize(width: 1, height: 1))
        XCTAssertEqual(offset1.width, offset0.width)
        XCTAssertEqual(offset1.height, offset0.height)
    }
}
