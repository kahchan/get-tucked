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

    // AL14 candidate 2
    func testMotionUnavailableBlocksEvenWhenLevelAndTiltReadOK() {
        XCTAssertEqual(
            CaptureGate.blockedReason(levelOK: true, tiltOK: true, motionAvailable: false),
            "Can't verify level — motion sensing unavailable"
        )
    }

    func testMotionAvailableFallsThroughToLevelTiltLogic() {
        XCTAssertNil(CaptureGate.blockedReason(levelOK: true, tiltOK: true, motionAvailable: true))
    }

    // AL14 candidate 3
    func testStorageFullBlocksEvenWhenLevelAndTiltReadOK() {
        XCTAssertEqual(
            CaptureGate.blockedReason(levelOK: true, tiltOK: true, storageOK: false),
            "Not enough storage to save this capture"
        )
    }

    func testMotionUnavailableTakesPriorityOverStorage() {
        XCTAssertEqual(
            CaptureGate.blockedReason(levelOK: true, tiltOK: true, motionAvailable: false, storageOK: false),
            "Can't verify level — motion sensing unavailable"
        )
    }
}

final class StorageGateTests: XCTestCase {
    func testBelowMinimumIsInsufficient() {
        XCTAssertFalse(StorageGate.hasSufficientStorage(availableBytes: 10 * 1024 * 1024, minimum: 50 * 1024 * 1024))
    }

    func testAtOrAboveMinimumIsSufficient() {
        XCTAssertTrue(StorageGate.hasSufficientStorage(availableBytes: 50 * 1024 * 1024, minimum: 50 * 1024 * 1024))
        XCTAssertTrue(StorageGate.hasSufficientStorage(availableBytes: 100 * 1024 * 1024, minimum: 50 * 1024 * 1024))
    }

    func testUnknownAvailabilityDoesNotBlock() {
        XCTAssertTrue(StorageGate.hasSufficientStorage(availableBytes: nil))
    }
}
