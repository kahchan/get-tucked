import XCTest
import SwiftUI
@testable import GetTucked

/// AL14 candidate 4: `CaptureView.shouldDiscardOnBackground` is the pure
/// predicate behind the scenePhase handler that discards an in-flight
/// analysis rather than leaving it to resolve into an unseen step.
final class CaptureBackgroundDiscardTests: XCTestCase {
    func testDiscardsWhenBackgroundedMidHeadOnAnalysis() {
        XCTAssertTrue(
            CaptureView.shouldDiscardOnBackground(newPhase: .background, step: .analysing)
        )
    }

    func testDiscardsWhenInactiveMidSideOnAnalysis() {
        XCTAssertTrue(
            CaptureView.shouldDiscardOnBackground(newPhase: .inactive, step: .analysingSideOn)
        )
    }

    func testDoesNotDiscardWhileStillActive() {
        XCTAssertFalse(
            CaptureView.shouldDiscardOnBackground(newPhase: .active, step: .analysing)
        )
    }

    func testDoesNotDiscardNonAnalysingSteps() {
        XCTAssertFalse(
            CaptureView.shouldDiscardOnBackground(newPhase: .background, step: .calibrate)
        )
        XCTAssertFalse(
            CaptureView.shouldDiscardOnBackground(newPhase: .background, step: .reveal)
        )
    }
}
