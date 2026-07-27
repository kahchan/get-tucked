import XCTest
@testable import GetTucked

/// Plan AI3: `AnalysisMath.mergedAdvisories` collapses identical A/B advisory
/// text into one "A and B: …" line instead of printing the same sentence
/// twice.
final class AdvisoryMergeTests: XCTestCase {
    func testIdenticalPairMerges() {
        let merged = AnalysisMath.mergedAdvisories([
            (side: "A", text: "Front wheel reads 18% larger than its spec size."),
            (side: "B", text: "Front wheel reads 18% larger than its spec size."),
        ])
        XCTAssertEqual(merged, ["A and B: Front wheel reads 18% larger than its spec size."])
    }

    func testDifferingPairDoesNotMerge() {
        let merged = AnalysisMath.mergedAdvisories([
            (side: "A", text: "Shoulder width reads 68 cm."),
            (side: "B", text: "Shoulder width reads 22 cm."),
        ])
        XCTAssertEqual(merged, [
            "A: Shoulder width reads 68 cm.",
            "B: Shoulder width reads 22 cm.",
        ])
    }

    func testSingleSideUnchanged() {
        let merged = AnalysisMath.mergedAdvisories([
            (side: "A", text: "Shoulder width reads 68 cm."),
        ])
        XCTAssertEqual(merged, ["A: Shoulder width reads 68 cm."])
    }

    func testEmptyInput() {
        XCTAssertEqual(AnalysisMath.mergedAdvisories([]), [])
    }

    func testOrderPreservedAcrossMixedSet() {
        // Shoulder width differs (no merge), wheel check agrees (merges) —
        // the merged line takes the position of its *first* occurrence, not
        // the end of the list.
        let merged = AnalysisMath.mergedAdvisories([
            (side: "A", text: "Shoulder width reads 68 cm."),
            (side: "B", text: "Shoulder width reads 22 cm."),
            (side: "A", text: "Front wheel reads 18% larger than its spec size."),
            (side: "B", text: "Front wheel reads 18% larger than its spec size."),
        ])
        XCTAssertEqual(merged, [
            "A: Shoulder width reads 68 cm.",
            "B: Shoulder width reads 22 cm.",
            "A and B: Front wheel reads 18% larger than its spec size.",
        ])
    }
}
