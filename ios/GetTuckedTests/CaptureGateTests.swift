import XCTest
@testable import GetTucked

final class CaptureGateTests: XCTestCase {
    func testBothPassedReturnsNil() {
        XCTAssertNil(CaptureGate.blockedReason(levelOK: true, perpOK: true))
    }

    func testLevelFailingOnlyAsksToLevel() {
        XCTAssertEqual(CaptureGate.blockedReason(levelOK: false, perpOK: true), "Hold the phone level")
    }

    func testPerpFailingOnlyAsksToTiltUpright() {
        XCTAssertEqual(CaptureGate.blockedReason(levelOK: true, perpOK: false), "Tilt the phone upright")
    }

    func testBothFailingAsksForBoth() {
        XCTAssertEqual(
            CaptureGate.blockedReason(levelOK: false, perpOK: false),
            "Hold the phone level and upright"
        )
    }
}
