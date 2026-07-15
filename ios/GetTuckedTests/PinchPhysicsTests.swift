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
}
