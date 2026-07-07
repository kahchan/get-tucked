import XCTest
import CoreGraphics
@testable import GetTucked

final class CalibrationTransformTests: XCTestCase {
    private let acc = 1e-6

    private func makeViewport(zoom: CGFloat, pan: CGSize) -> CalibrationTransform.Viewport {
        let containerSize = CGSize(width: 400, height: 800)
        let imageRect = CalibrationTransform.aspectFitRect(
            imageSize: CGSize(width: 1200, height: 1600), in: containerSize
        )
        return CalibrationTransform.Viewport(
            containerSize: containerSize, imageRect: imageRect, zoomScale: zoom, panOffset: pan
        )
    }

    // MARK: - Aspect-fit rect

    func testAspectFitRectLetterboxesRelativelyWiderImage() {
        // Image aspect 0.75 (1200x1600) vs container aspect 0.5 (400x800): the
        // image is relatively wider than the container, so it fits full width
        // and is letterboxed top/bottom.
        let rect = CalibrationTransform.aspectFitRect(
            imageSize: CGSize(width: 1200, height: 1600), in: CGSize(width: 400, height: 800)
        )
        XCTAssertEqual(rect.width, 400, accuracy: acc)
        XCTAssertEqual(rect.height, 400.0 / 0.75, accuracy: acc)
        XCTAssertEqual(rect.minX, 0, accuracy: acc)
    }

    // MARK: - Round trip: unit → screen → unit

    func testRoundTripNoZoomNoPan() {
        let viewport = makeViewport(zoom: 1, pan: .zero)
        let unit = CGPoint(x: 0.3, y: 0.7)
        let screen = CalibrationTransform.screenPoint(forUnit: unit, in: viewport)
        let back = CalibrationTransform.unitPoint(forScreen: screen, in: viewport)
        XCTAssertEqual(back.x, unit.x, accuracy: acc)
        XCTAssertEqual(back.y, unit.y, accuracy: acc)
    }

    func testRoundTripZoomedIn() {
        let viewport = makeViewport(zoom: 3.5, pan: .zero)
        let unit = CGPoint(x: 0.15, y: 0.85)
        let screen = CalibrationTransform.screenPoint(forUnit: unit, in: viewport)
        let back = CalibrationTransform.unitPoint(forScreen: screen, in: viewport)
        XCTAssertEqual(back.x, unit.x, accuracy: acc)
        XCTAssertEqual(back.y, unit.y, accuracy: acc)
    }

    func testRoundTripZoomedAndPanned() {
        let viewport = makeViewport(zoom: 2.2, pan: CGSize(width: 45, height: -30))
        let unit = CGPoint(x: 0.6, y: 0.25)
        let screen = CalibrationTransform.screenPoint(forUnit: unit, in: viewport)
        let back = CalibrationTransform.unitPoint(forScreen: screen, in: viewport)
        XCTAssertEqual(back.x, unit.x, accuracy: acc)
        XCTAssertEqual(back.y, unit.y, accuracy: acc)
    }

    // MARK: - A point stays glued to its screen pixel across zoom changes only
    // when re-anchored from unit space (documents *why* points are stored in
    // unit space, not screen space, across zoom/pan).

    func testUnzoomedScreenPointMapsToImageCentreAtCentreUnit() {
        let viewport = makeViewport(zoom: 1, pan: .zero)
        let centreUnit = CGPoint(x: 0.5, y: 0.5)
        let screen = CalibrationTransform.screenPoint(forUnit: centreUnit, in: viewport)
        XCTAssertEqual(screen.x, viewport.containerSize.width / 2, accuracy: acc)
        XCTAssertEqual(screen.y, viewport.containerSize.height / 2, accuracy: acc)
    }
}
