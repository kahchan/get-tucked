import XCTest
@testable import GetTucked

final class CaptureGateTests: XCTestCase {
    func testBothPassedReturnsNil() {
        XCTAssertNil(CaptureGate.blockedReason(levelOK: true, tiltOK: true))
    }

    func testLevelFailingOnlyAsksToLevel() {
        XCTAssertEqual(CaptureGate.blockedReason(levelOK: false, tiltOK: true), "Hold the phone level")
    }

    func testTiltFailingOnlyAsksToTiltUpright() {
        XCTAssertEqual(CaptureGate.blockedReason(levelOK: true, tiltOK: false), "Tilt the phone upright")
    }

    func testBothFailingAsksForBoth() {
        XCTAssertEqual(
            CaptureGate.blockedReason(levelOK: false, tiltOK: false),
            "Hold the phone level and upright"
        )
    }
}
