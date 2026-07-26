import XCTest
@testable import GetTucked

/// Plan AE3: the OUTLINE tab's dimmed photo underlay is a pure chip-state →
/// opacity mapping, kept out of the view for direct testing.
final class GhostCompareUnderlayTests: XCTestCase {
    func testHiddenByDefaultWhenUnderlayChipIsOff() {
        XCTAssertEqual(GhostCompareUnderlay.photoOpacity(showOutline: true, showPhotoUnderlay: false), 0)
    }

    func testDimmedWhenBothOutlineAndUnderlayChipAreOn() {
        XCTAssertEqual(GhostCompareUnderlay.photoOpacity(showOutline: true, showPhotoUnderlay: true), 0.35)
    }

    func testHiddenOnThePhotoTabEvenIfUnderlayChipWasLeftOn() {
        // PHOTO tab already shows the photo as primary content — the
        // underlay never doubles up on it.
        XCTAssertEqual(GhostCompareUnderlay.photoOpacity(showOutline: false, showPhotoUnderlay: true), 0)
    }

    func testHiddenWhenNeitherIsOn() {
        XCTAssertEqual(GhostCompareUnderlay.photoOpacity(showOutline: false, showPhotoUnderlay: false), 0)
    }
}
