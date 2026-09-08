import XCTest
@testable import GetTucked

final class PostureCdTests: XCTestCase {
    func testUprightBelowBoundary() {
        XCTAssertEqual(PostureCd.bin(torsoDeg: 0), .upright)
        XCTAssertEqual(PostureCd.bin(torsoDeg: 24.9), .upright)
    }

    func testUprightUpperBoundaryIsTucked() {
        // < 25 is upright, so exactly 25 rolls into tucked.
        XCTAssertEqual(PostureCd.bin(torsoDeg: 25), .tucked)
    }

    func testTuckedMidRange() {
        XCTAssertEqual(PostureCd.bin(torsoDeg: 40), .tucked)
        XCTAssertEqual(PostureCd.bin(torsoDeg: 54.9), .tucked)
    }

    func testTuckedUpperBoundaryIsAero() {
        // < 55 is tucked, so exactly 55 rolls into aero.
        XCTAssertEqual(PostureCd.bin(torsoDeg: 55), .aero)
    }

    func testAeroAboveBoundary() {
        XCTAssertEqual(PostureCd.bin(torsoDeg: 60), .aero)
        XCTAssertEqual(PostureCd.bin(torsoDeg: 90), .aero)
    }
}
