import XCTest
import CoreGraphics
@testable import GetTucked

final class DimensionGeometryTests: XCTestCase {
    private let acc = 1e-6

    // MARK: - midpoint

    func testMidpoint() {
        let m = DimensionGeometry.midpoint(CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 60))
        XCTAssertEqual(m.x, 20, accuracy: acc)
        XCTAssertEqual(m.y, 40, accuracy: acc)
    }

    // MARK: - point(forTopLeftUnit:in:): Z1 regression — no Vision-style flip

    func testPointForTopLeftUnitDoesNotFlipY() {
        // y=0.9 in top-left-origin unit space is near the image's BOTTOM
        // edge — must land in the view's bottom 20%. Plan X's shipped bug
        // borrowed SkeletonGeometry's Vision-bottom-left flip here, which
        // would have put this point near the TOP instead.
        let size = CGSize(width: 400, height: 1000)
        let point = DimensionGeometry.point(forTopLeftUnit: CGPoint(x: 0.5, y: 0.9), in: size)
        XCTAssertEqual(point.x, 200, accuracy: acc)
        XCTAssertEqual(point.y, 900, accuracy: acc)
        XCTAssertGreaterThan(point.y, size.height * 0.8, "a y=0.9 top-left tap must land in the bottom 20% of the view")
    }

    func testHorizontalTapPairNearBottomStaysNearBottom() {
        // Bar-style dimension: two taps sharing a similar y near 0.9.
        let size = CGSize(width: 400, height: 1000)
        let from = DimensionGeometry.point(forTopLeftUnit: CGPoint(x: 0.2, y: 0.9), in: size)
        let to = DimensionGeometry.point(forTopLeftUnit: CGPoint(x: 0.8, y: 0.9), in: size)
        XCTAssertGreaterThan(from.y, size.height * 0.8)
        XCTAssertGreaterThan(to.y, size.height * 0.8)
    }

    func testVerticalTapPairNearBottomStaysNearBottomAndOrdered() {
        // Wheel-style dimension: a vertical pair (ground tap, top tap),
        // both nearer the image's bottom than its top, with the larger
        // unit-y (ground) rendering strictly lower on screen than the
        // smaller unit-y (top) — never flipped.
        let size = CGSize(width: 400, height: 1000)
        let ground = DimensionGeometry.point(forTopLeftUnit: CGPoint(x: 0.5, y: 0.9), in: size)
        let top = DimensionGeometry.point(forTopLeftUnit: CGPoint(x: 0.5, y: 0.7), in: size)
        XCTAssertGreaterThan(ground.y, size.height * 0.8)
        XCTAssertGreaterThan(top.y, size.height * 0.6)
        XCTAssertGreaterThan(ground.y, top.y, "ground tap (larger unit y) must render lower on screen than the top tap")
    }

    // MARK: - tickEndpoints: perpendicularity

    func testTickIsPerpendicularToHorizontalSegment() {
        let tick = DimensionGeometry.tickEndpoints(
            at: CGPoint(x: 50, y: 100), lineFrom: CGPoint(x: 0, y: 100), lineTo: CGPoint(x: 100, y: 100), length: 6
        )
        // Horizontal segment → tick must be purely vertical.
        XCTAssertEqual(tick.a.x, tick.b.x, accuracy: acc)
        XCTAssertEqual(abs(tick.a.y - tick.b.y), 6, accuracy: acc)
    }

    func testTickIsPerpendicularToVerticalSegment() {
        let tick = DimensionGeometry.tickEndpoints(
            at: CGPoint(x: 50, y: 50), lineFrom: CGPoint(x: 50, y: 0), lineTo: CGPoint(x: 50, y: 100), length: 6
        )
        // Vertical segment → tick must be purely horizontal.
        XCTAssertEqual(tick.a.y, tick.b.y, accuracy: acc)
        XCTAssertEqual(abs(tick.a.x - tick.b.x), 6, accuracy: acc)
    }

    func testTickIsPerpendicularToDiagonalSegment() {
        let from = CGPoint(x: 0, y: 0)
        let to = CGPoint(x: 100, y: 100)
        let tick = DimensionGeometry.tickEndpoints(at: CGPoint(x: 50, y: 50), lineFrom: from, lineTo: to, length: 6)
        let segDx = to.x - from.x, segDy = to.y - from.y
        let tickDx = tick.b.x - tick.a.x, tickDy = tick.b.y - tick.a.y
        let dot = segDx * tickDx + segDy * tickDy
        XCTAssertEqual(dot, 0, accuracy: 1e-4, "tick vector must be perpendicular (zero dot product) to the segment")
    }

    func testTickIsCentredOnItsPointAndHasRequestedLength() {
        let point = CGPoint(x: 50, y: 100)
        let tick = DimensionGeometry.tickEndpoints(
            at: point, lineFrom: CGPoint(x: 0, y: 100), lineTo: CGPoint(x: 100, y: 100), length: 6
        )
        let mid = DimensionGeometry.midpoint(tick.a, tick.b)
        XCTAssertEqual(mid.x, point.x, accuracy: acc)
        XCTAssertEqual(mid.y, point.y, accuracy: acc)
        let dx = tick.a.x - tick.b.x, dy = tick.a.y - tick.b.y
        XCTAssertEqual((dx * dx + dy * dy).squareRoot(), 6, accuracy: acc)
    }

    func testTickDegeneratesToAPointOnAZeroLengthSegment() {
        let point = CGPoint(x: 10, y: 10)
        let tick = DimensionGeometry.tickEndpoints(at: point, lineFrom: point, lineTo: point, length: 6)
        XCTAssertEqual(tick.a, point)
        XCTAssertEqual(tick.b, point)
    }

    // MARK: - leaderEnd: exact 45°

    func testLeaderEndIsExactly45DegreesForEveryDirection() {
        let point = CGPoint(x: 50, y: 50)
        for direction in DimensionGeometry.LeaderDirection.allCases {
            let end = DimensionGeometry.leaderEnd(from: point, direction: direction, runLength: 36)
            let dx = abs(end.x - point.x)
            let dy = abs(end.y - point.y)
            XCTAssertEqual(dx, dy, accuracy: acc, "\(direction) must run at exactly 45°")
        }
    }

    func testLeaderEndRunLengthIsExact() {
        let point = CGPoint(x: 0, y: 0)
        let end = DimensionGeometry.leaderEnd(from: point, direction: .downRight, runLength: 36)
        let dx = end.x - point.x, dy = end.y - point.y
        XCTAssertEqual((dx * dx + dy * dy).squareRoot(), 36, accuracy: 1e-4)
    }

    // MARK: - chooseLeaderDirection: corner cases (box must never exit bounds)

    func testDirectionNearTopLeftCornerPicksDownRight() {
        let bounds = CGSize(width: 400, height: 600)
        let point = CGPoint(x: 5, y: 5)
        let direction = DimensionGeometry.chooseLeaderDirection(
            from: point, boxSize: CGSize(width: 40, height: 20), bounds: bounds, runLength: 36
        )
        XCTAssertEqual(direction, .downRight)
        assertBoxWithinBounds(point: point, direction: direction, boxSize: CGSize(width: 40, height: 20), bounds: bounds, runLength: 36)
    }

    func testDirectionNearTopRightCornerPicksDownLeft() {
        let bounds = CGSize(width: 400, height: 600)
        let point = CGPoint(x: 395, y: 5)
        let direction = DimensionGeometry.chooseLeaderDirection(
            from: point, boxSize: CGSize(width: 40, height: 20), bounds: bounds, runLength: 36
        )
        XCTAssertEqual(direction, .downLeft)
        assertBoxWithinBounds(point: point, direction: direction, boxSize: CGSize(width: 40, height: 20), bounds: bounds, runLength: 36)
    }

    func testDirectionNearBottomLeftCornerPicksUpRight() {
        let bounds = CGSize(width: 400, height: 600)
        let point = CGPoint(x: 5, y: 595)
        let direction = DimensionGeometry.chooseLeaderDirection(
            from: point, boxSize: CGSize(width: 40, height: 20), bounds: bounds, runLength: 36
        )
        XCTAssertEqual(direction, .upRight)
        assertBoxWithinBounds(point: point, direction: direction, boxSize: CGSize(width: 40, height: 20), bounds: bounds, runLength: 36)
    }

    func testDirectionNearBottomRightCornerPicksUpLeft() {
        let bounds = CGSize(width: 400, height: 600)
        let point = CGPoint(x: 395, y: 595)
        let direction = DimensionGeometry.chooseLeaderDirection(
            from: point, boxSize: CGSize(width: 40, height: 20), bounds: bounds, runLength: 36
        )
        XCTAssertEqual(direction, .upLeft)
        assertBoxWithinBounds(point: point, direction: direction, boxSize: CGSize(width: 40, height: 20), bounds: bounds, runLength: 36)
    }

    func testDirectionNearCentrePrefersDownRightTieBreak() {
        // Away from every edge, all four directions fit — the stable
        // tie-break (declared LeaderDirection.allCases order) wins.
        let bounds = CGSize(width: 400, height: 600)
        let point = CGPoint(x: 200, y: 300)
        let direction = DimensionGeometry.chooseLeaderDirection(
            from: point, boxSize: CGSize(width: 40, height: 20), bounds: bounds, runLength: 36
        )
        XCTAssertEqual(direction, .downRight)
    }

    private func assertBoxWithinBounds(point: CGPoint, direction: DimensionGeometry.LeaderDirection, boxSize: CGSize, bounds: CGSize, runLength: CGFloat) {
        let end = DimensionGeometry.leaderEnd(from: point, direction: direction, runLength: runLength)
        let rect = DimensionGeometry.boxRect(leaderEnd: end, direction: direction, boxSize: boxSize)
        XCTAssertGreaterThanOrEqual(rect.minX, -acc)
        XCTAssertGreaterThanOrEqual(rect.minY, -acc)
        XCTAssertLessThanOrEqual(rect.maxX, bounds.width + acc)
        XCTAssertLessThanOrEqual(rect.maxY, bounds.height + acc)
    }

    // MARK: - chooseBesideSide / besideBoxOrigin (Plan Z2)

    func testBesideSideNearLeftEdgePicksRight() {
        let bounds = CGSize(width: 400, height: 600)
        let from = CGPoint(x: 10, y: 300), to = CGPoint(x: 60, y: 300)
        let boxSize = CGSize(width: 60, height: 24)
        let side = DimensionGeometry.chooseBesideSide(from: from, to: to, boxSize: boxSize, bounds: bounds, gap: 8)
        XCTAssertEqual(side, .right)
        assertBesideBoxWithinBounds(from: from, to: to, side: side, boxSize: boxSize, bounds: bounds, gap: 8)
    }

    func testBesideSideNearRightEdgePicksLeft() {
        let bounds = CGSize(width: 400, height: 600)
        let from = CGPoint(x: 340, y: 300), to = CGPoint(x: 390, y: 300)
        let boxSize = CGSize(width: 60, height: 24)
        let side = DimensionGeometry.chooseBesideSide(from: from, to: to, boxSize: boxSize, bounds: bounds, gap: 8)
        XCTAssertEqual(side, .left)
        assertBesideBoxWithinBounds(from: from, to: to, side: side, boxSize: boxSize, bounds: bounds, gap: 8)
    }

    func testBesideSideAwayFromEdgesPrefersRightTieBreak() {
        let bounds = CGSize(width: 400, height: 600)
        let from = CGPoint(x: 150, y: 300), to = CGPoint(x: 250, y: 300)
        let side = DimensionGeometry.chooseBesideSide(
            from: from, to: to, boxSize: CGSize(width: 60, height: 24), bounds: bounds, gap: 8
        )
        XCTAssertEqual(side, .right)
    }

    func testBesideBoxOriginIsVerticallyCentredOnTheLine() {
        let from = CGPoint(x: 100, y: 190), to = CGPoint(x: 200, y: 210)
        let boxSize = CGSize(width: 60, height: 24)
        let origin = DimensionGeometry.besideBoxOrigin(from: from, to: to, side: .right, boxSize: boxSize, gap: 8)
        XCTAssertEqual(origin.y, 200 - boxSize.height / 2, accuracy: acc) // centreY = (190+210)/2 = 200
        XCTAssertEqual(origin.x, 200 + 8, accuracy: acc) // right of the line's rightmost x
    }

    func testBesideBoxOriginLeftSitsLeftOfTheLine() {
        let from = CGPoint(x: 100, y: 200), to = CGPoint(x: 200, y: 200)
        let boxSize = CGSize(width: 60, height: 24)
        let origin = DimensionGeometry.besideBoxOrigin(from: from, to: to, side: .left, boxSize: boxSize, gap: 8)
        XCTAssertEqual(origin.x, 100 - 8 - boxSize.width, accuracy: acc)
    }

    private func assertBesideBoxWithinBounds(
        from: CGPoint, to: CGPoint, side: DimensionGeometry.HorizontalSide, boxSize: CGSize, bounds: CGSize, gap: CGFloat
    ) {
        let rect = DimensionGeometry.besideBoxRect(from: from, to: to, side: side, boxSize: boxSize, gap: gap)
        XCTAssertGreaterThanOrEqual(rect.minX, -acc)
        XCTAssertGreaterThanOrEqual(rect.minY, -acc)
        XCTAssertLessThanOrEqual(rect.maxX, bounds.width + acc)
        XCTAssertLessThanOrEqual(rect.maxY, bounds.height + acc)
    }

    // MARK: - calloutLabel / calloutBoxSize

    func testCalloutLabelFormatsRoundedMillimetres() {
        XCTAssertEqual(DimensionGeometry.calloutLabel(mm: 780), "780 MM")
        XCTAssertEqual(DimensionGeometry.calloutLabel(mm: 779.6), "780 MM")
        XCTAssertEqual(DimensionGeometry.calloutLabel(mm: 622.4), "622 MM")
    }

    func testCalloutBoxSizeGrowsWithLabelLength() {
        let short = DimensionGeometry.calloutBoxSize(label: "1 MM", fontSize: 9, padding: 4)
        let long = DimensionGeometry.calloutBoxSize(label: "1200 MM", fontSize: 9, padding: 4)
        XCTAssertGreaterThan(long.width, short.width)
        XCTAssertEqual(long.height, short.height, accuracy: acc, "height is font-driven, not label-length-driven")
    }

    // MARK: - DimensionOverlay.dimension: independent per-dimension degrade

    func testDimensionFromFlatPointsRequiresBothPointsAndMm() {
        XCTAssertNotNil(DimensionOverlay.dimension(unitPoints: [0.1, 0.2, 0.3, 0.4], mm: 780))
        XCTAssertNil(DimensionOverlay.dimension(unitPoints: nil, mm: 780), "missing points → no annotation")
        XCTAssertNil(DimensionOverlay.dimension(unitPoints: [0.1, 0.2, 0.3, 0.4], mm: nil), "missing mm → no annotation")
        XCTAssertNil(DimensionOverlay.dimension(unitPoints: [0.1, 0.2, 0.3], mm: 780), "malformed point count → no annotation")
    }

    func testDimensionFromFlatPointsPreservesCoordinates() {
        guard let dim = DimensionOverlay.dimension(unitPoints: [0.1, 0.2, 0.3, 0.4], mm: 780) else {
            return XCTFail("expected a non-nil dimension")
        }
        XCTAssertEqual(dim.unitFrom, CGPoint(x: 0.1, y: 0.2))
        XCTAssertEqual(dim.unitTo, CGPoint(x: 0.3, y: 0.4))
        XCTAssertEqual(dim.valueMm, 780, accuracy: acc)
    }

    func testDimensionDefaultsToLeaderStyleAndAcceptsBeside() {
        let leader = DimensionOverlay.dimension(unitPoints: [0.1, 0.2, 0.3, 0.4], mm: 780)
        XCTAssertEqual(leader?.style, .leader)
        let beside = DimensionOverlay.dimension(unitPoints: [0.1, 0.2, 0.3, 0.4], mm: 780, style: .beside)
        XCTAssertEqual(beside?.style, .beside)
        let besideFromPoints = DimensionOverlay.dimension(
            points: [CGPoint(x: 0.1, y: 0.2), CGPoint(x: 0.3, y: 0.4)], mm: 780, style: .beside
        )
        XCTAssertEqual(besideFromPoints?.style, .beside)
    }

    func testDimensionFromCGPointsRequiresBothPointsAndMm() {
        let points = [CGPoint(x: 0.1, y: 0.2), CGPoint(x: 0.3, y: 0.4)]
        XCTAssertNotNil(DimensionOverlay.dimension(points: points, mm: 622))
        XCTAssertNil(DimensionOverlay.dimension(points: [], mm: 622), "missing points → no annotation")
        XCTAssertNil(DimensionOverlay.dimension(points: points, mm: nil), "missing mm → no annotation")
        XCTAssertNil(DimensionOverlay.dimension(points: [CGPoint(x: 0.1, y: 0.2)], mm: 622), "malformed point count → no annotation")
    }
}
