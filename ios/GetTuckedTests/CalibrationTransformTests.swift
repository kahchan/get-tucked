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

    // MARK: - clampedPanOffset (Plan W5)

    private let containerSize = CGSize(width: 400, height: 800)
    private var imageRect: CGRect {
        // Same fixture as makeViewport: 1200x1600 image in a 400x800
        // container — fits full width, letterboxed top/bottom.
        CalibrationTransform.aspectFitRect(imageSize: CGSize(width: 1200, height: 1600), in: containerSize)
    }

    func testClampedPanOffsetAt1xPinsToZeroEvenWithNonZeroInput() {
        let clamped = CalibrationTransform.clampedPanOffset(
            CGSize(width: 40, height: -25), zoomScale: 1, imageRect: imageRect, containerSize: containerSize
        )
        XCTAssertEqual(clamped, .zero)
    }

    func testClampedPanOffsetZeroInputStaysZeroAtAnyZoom() {
        let clamped = CalibrationTransform.clampedPanOffset(
            .zero, zoomScale: 4, imageRect: imageRect, containerSize: containerSize
        )
        XCTAssertEqual(clamped, .zero)
    }

    func testClampedPanOffsetWithinBoundsPassesThroughUnchanged() {
        // At 2x zoom the fitted (width) axis's scaled length is 800 vs a
        // 400-wide container, so up to ±200 of pan on that axis keeps the
        // image covering the container.
        let small = CGSize(width: 50, height: 10)
        let clamped = CalibrationTransform.clampedPanOffset(
            small, zoomScale: 2, imageRect: imageRect, containerSize: containerSize
        )
        XCTAssertEqual(clamped.width, small.width, accuracy: acc)
    }

    func testClampedPanOffsetZoomedInImageCannotExposeAGap() {
        // A huge requested pan on a zoomed-in image must be pulled back to
        // the bound where the image edge still lines up with the container
        // edge — never further, which would open a letterbox gap that
        // didn't exist at 1x.
        let huge = CGSize(width: 10_000, height: 10_000)
        let clamped = CalibrationTransform.clampedPanOffset(
            huge, zoomScale: 3, imageRect: imageRect, containerSize: containerSize
        )
        let viewport = CalibrationTransform.Viewport(
            containerSize: containerSize, imageRect: imageRect, zoomScale: 3, panOffset: clamped
        )
        // The image's scaled top-left corner (unit 0,1 in Vision terms is
        // screen-space top-left here) must not sit to the right of/below the
        // container origin, and its bottom-right must not sit inside the
        // container — i.e. the scaled+panned rect still covers [0,container].
        let scaledMinX = viewport.anchor.x + (imageRect.minX - viewport.anchor.x) * 3 + clamped.width
        let scaledMinY = viewport.anchor.y + (imageRect.minY - viewport.anchor.y) * 3 + clamped.height
        XCTAssertLessThanOrEqual(scaledMinX, 0 + acc)
        XCTAssertLessThanOrEqual(scaledMinY, 0 + acc)
        let scaledMaxX = scaledMinX + imageRect.width * 3
        let scaledMaxY = scaledMinY + imageRect.height * 3
        XCTAssertGreaterThanOrEqual(scaledMaxX, containerSize.width - acc)
        XCTAssertGreaterThanOrEqual(scaledMaxY, containerSize.height - acc)
    }

    func testClampedPanOffsetNegativeHugeAlsoBounded() {
        let huge = CGSize(width: -10_000, height: -10_000)
        let clamped = CalibrationTransform.clampedPanOffset(
            huge, zoomScale: 3, imageRect: imageRect, containerSize: containerSize
        )
        XCTAssertGreaterThan(clamped.width, -10_000)
        XCTAssertGreaterThan(clamped.height, -10_000)
    }
}
