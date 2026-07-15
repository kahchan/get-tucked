import XCTest
import CoreGraphics
@testable import GetTucked

final class LiveGhostGeometryTests: XCTestCase {
    private let acc = 1e-6

    func testMatchingAspectReducesToSimpleFitMapping() {
        // Container and reference share the same 0.5 aspect ratio — fill
        // degenerates to fit, so corners land exactly on the container edges
        // (same convention SkeletonGeometry uses: Vision-normalised y=0 is
        // the bottom of the image, y increases downward on screen).
        let container = CGSize(width: 400, height: 800)
        let bottomLeft = LiveGhostGeometry.point(forUnit: CGPoint(x: 0, y: 0), in: container, referenceAspect: 0.5)
        XCTAssertEqual(bottomLeft.x, 0, accuracy: acc)
        XCTAssertEqual(bottomLeft.y, 800, accuracy: acc)

        let topRight = LiveGhostGeometry.point(forUnit: CGPoint(x: 1, y: 1), in: container, referenceAspect: 0.5)
        XCTAssertEqual(topRight.x, 400, accuracy: acc)
        XCTAssertEqual(topRight.y, 0, accuracy: acc)
    }

    func testCentrePointMapsToContainerCentreRegardlessOfAspectMismatch() {
        // A square reference (aspect 1.0) inside a narrow portrait container
        // gets cropped left/right — but the centre point must still land on
        // the container's centre, the way aspect-fill's symmetric crop works.
        let container = CGSize(width: 400, height: 800)
        let centre = LiveGhostGeometry.point(forUnit: CGPoint(x: 0.5, y: 0.5), in: container, referenceAspect: 1.0)
        XCTAssertEqual(centre.x, 200, accuracy: acc)
        XCTAssertEqual(centre.y, 400, accuracy: acc)
    }

    func testMismatchedAspectCropsOffscreenContent() {
        // Same square-in-portrait setup — a landmark near the reference's
        // left edge falls in the cropped-away region and maps off-screen
        // (negative x), matching what .resizeAspectFill actually shows.
        let container = CGSize(width: 400, height: 800)
        let point = LiveGhostGeometry.point(forUnit: CGPoint(x: 0, y: 0.5), in: container, referenceAspect: 1.0)
        XCTAssertEqual(point.x, -200, accuracy: acc)
        XCTAssertEqual(point.y, 400, accuracy: acc)
    }

    func testLandscapeContainerCropsTopAndBottom() {
        // Wide container, portrait-shaped reference — this time the crop is
        // vertical, so a landmark near the reference's top edge should fall
        // above the visible container (negative y after the fill transform).
        let container = CGSize(width: 800, height: 400)
        let point = LiveGhostGeometry.point(forUnit: CGPoint(x: 0.5, y: 1), in: container, referenceAspect: 0.5)
        XCTAssertEqual(point.x, 400, accuracy: acc)
        XCTAssertLessThan(point.y, 0)
    }

    func testDegenerateReferenceAspectFallsBackToPlainScale() {
        // Guard clause: a zero/negative aspect (shouldn't happen with a real
        // photo, but must not crash) falls back to the same plain
        // unit-to-container scale SkeletonGeometry uses.
        let container = CGSize(width: 400, height: 800)
        let point = LiveGhostGeometry.point(forUnit: CGPoint(x: 0.25, y: 0.25), in: container, referenceAspect: 0)
        XCTAssertEqual(point.x, 100, accuracy: acc)
        XCTAssertEqual(point.y, 600, accuracy: acc)
    }
}
