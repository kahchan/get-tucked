import XCTest
@testable import GetTucked

final class ContourTracerTests: XCTestCase {
    func testAllEmptyMaskReturnsNoContours() {
        let contours = ContourTracer.trace(isForeground: { _, _ in false }, width: 50, height: 50)
        XCTAssertEqual(contours, [])
    }

    func testSquareMaskSimplifiesToRoughlyFourPoints() {
        // 60x60 square inset into a 100x100 grid — an axis-aligned boundary
        // traces as a staircase (many collinear points) before Douglas–
        // Peucker collapses each straight edge back to its two corners.
        let contours = ContourTracer.trace(
            isForeground: { x, y in (20 ..< 80).contains(x) && (20 ..< 80).contains(y) },
            width: 100, height: 100
        )
        XCTAssertEqual(contours.count, 1)
        let square = contours[0]
        XCTAssertGreaterThanOrEqual(square.count, 4)
        XCTAssertLessThanOrEqual(square.count, 6)
    }

    func testSquareContourPointsStayWithinUnitBounds() {
        let contours = ContourTracer.trace(
            isForeground: { x, y in (20 ..< 80).contains(x) && (20 ..< 80).contains(y) },
            width: 100, height: 100
        )
        guard let square = contours.first else { return XCTFail("expected a contour") }
        for point in square {
            XCTAssertGreaterThanOrEqual(point.x, 0)
            XCTAssertLessThanOrEqual(point.x, 1)
            XCTAssertGreaterThanOrEqual(point.y, 0)
            XCTAssertLessThanOrEqual(point.y, 1)
        }
    }

    func testDonutProducesTwoContours() {
        // Outer boundary + inner hole boundary — two disjoint closed loops
        // sharing no segments.
        let center = (x: 50.0, y: 50.0)
        let outerRadius = 35.0
        let innerRadius = 15.0
        let contours = ContourTracer.trace(
            isForeground: { x, y in
                let dx = Double(x) - center.x, dy = Double(y) - center.y
                let dist = (dx * dx + dy * dy).squareRoot()
                return dist <= outerRadius && dist >= innerRadius
            },
            width: 100, height: 100
        )
        XCTAssertEqual(contours.count, 2)
    }

    func testTwoDisjointBlobsProduceTwoContours() {
        let contours = ContourTracer.trace(
            isForeground: { x, y in
                let inLeftBlob = (10 ..< 30).contains(x) && (10 ..< 30).contains(y)
                let inRightBlob = (70 ..< 90).contains(x) && (70 ..< 90).contains(y)
                return inLeftBlob || inRightBlob
            },
            width: 100, height: 100
        )
        XCTAssertEqual(contours.count, 2)
    }

    func testSpeckBelowAreaThresholdIsDiscarded() {
        // A 2x2 speck alongside a large blob — the speck is far under 0.5%
        // of the large blob's foreground area and should be filtered.
        let contours = ContourTracer.trace(
            isForeground: { x, y in
                let inBigBlob = (10 ..< 90).contains(x) && (10 ..< 90).contains(y)
                let inSpeck = x == 2 && y == 2
                return inBigBlob || inSpeck
            },
            width: 100, height: 100
        )
        XCTAssertEqual(contours.count, 1)
    }

    func testContourPointOrderStartsAtTopmostPoint() {
        let contours = ContourTracer.trace(
            isForeground: { x, y in (20 ..< 80).contains(x) && (20 ..< 80).contains(y) },
            width: 100, height: 100
        )
        guard let square = contours.first else { return XCTFail("expected a contour") }
        let minY = square.map(\.y).min()
        XCTAssertEqual(square[0].y, minY)
    }
}
