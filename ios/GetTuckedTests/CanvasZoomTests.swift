import XCTest
@testable import GetTucked

/// Plan AK21. The correction canvas paints where `CanvasZoom.contentPoint`
/// says the finger is, so an error here is a stroke that lands somewhere the
/// rider didn't touch — and at 1× (where every previous manual test happened)
/// the transform is the identity, so the bug only appears once zoomed. These
/// are the tests that can catch it; the gesture routing above them can't be
/// tested without a device.
final class CanvasZoomTests: XCTestCase {
    private let container = CGSize(width: 300, height: 400)

    /// The forward transform the *view* applies:
    /// `.scaleEffect(zoom, anchor: .center)` then `.offset(pan)`.
    /// `contentPoint` must be exactly this inverted — if the view's modifier
    /// order ever changes, this helper changes with it and the round-trip
    /// tests below fail, which is the point.
    private func containerPoint(
        content: CGPoint, zoom: CGFloat, pan: CGSize
    ) -> CGPoint {
        let centreX = container.width / 2
        let centreY = container.height / 2
        return CGPoint(
            x: centreX + (content.x - centreX) * zoom + pan.width,
            y: centreY + (content.y - centreY) * zoom + pan.height
        )
    }

    func testUnzoomedMappingIsTheIdentity() {
        let point = CGPoint(x: 42, y: 314)
        let mapped = CanvasZoom.contentPoint(
            container: point, containerSize: container, zoom: 1, pan: .zero
        )
        XCTAssertEqual(mapped.x, point.x, accuracy: 1e-9)
        XCTAssertEqual(mapped.y, point.y, accuracy: 1e-9)
    }

    /// The centre is the scale anchor, so it's the one point that doesn't
    /// move when zoom changes with no pan.
    func testCentreIsFixedUnderZoom() {
        let centre = CGPoint(x: container.width / 2, y: container.height / 2)
        for zoom in [1.0, 2.5, 8.0] as [CGFloat] {
            let mapped = CanvasZoom.contentPoint(
                container: centre, containerSize: container, zoom: zoom, pan: .zero
            )
            XCTAssertEqual(mapped.x, centre.x, accuracy: 1e-9, "zoom \(zoom)")
            XCTAssertEqual(mapped.y, centre.y, accuracy: 1e-9, "zoom \(zoom)")
        }
    }

    /// The real guarantee: whatever the view draws at a content point, a
    /// touch on that spot resolves back to the same content point. Covers
    /// zoom and pan together, which is where sign errors hide.
    func testRoundTripsThroughTheViewTransform() {
        let cases: [(CGPoint, CGFloat, CGSize)] = [
            (CGPoint(x: 10, y: 10), 2, CGSize(width: 30, height: -45)),
            (CGPoint(x: 299, y: 399), 8, CGSize(width: -120, height: 200)),
            (CGPoint(x: 150, y: 200), 3.5, CGSize(width: 0, height: 0)),
            (CGPoint(x: 0, y: 0), 1.2, CGSize(width: -7, height: 3)),
        ]
        for (content, zoom, pan) in cases {
            let onScreen = containerPoint(content: content, zoom: zoom, pan: pan)
            let back = CanvasZoom.contentPoint(
                container: onScreen, containerSize: container, zoom: zoom, pan: pan
            )
            XCTAssertEqual(back.x, content.x, accuracy: 1e-6, "zoom \(zoom) pan \(pan)")
            XCTAssertEqual(back.y, content.y, accuracy: 1e-6, "zoom \(zoom) pan \(pan)")
        }
    }

    /// A zoomed-in touch resolves to a *smaller* content displacement than
    /// the finger travelled — this is the whole reason zoom buys precision
    /// with a fixed-size brush.
    func testZoomShrinksContentDisplacement() {
        let offCentre = CGPoint(x: container.width / 2 + 80, y: container.height / 2)
        let atOne = CanvasZoom.contentPoint(
            container: offCentre, containerSize: container, zoom: 1, pan: .zero
        )
        let atFour = CanvasZoom.contentPoint(
            container: offCentre, containerSize: container, zoom: 4, pan: .zero
        )
        XCTAssertEqual(atOne.x - container.width / 2, 80, accuracy: 1e-9)
        XCTAssertEqual(atFour.x - container.width / 2, 20, accuracy: 1e-9)
    }

    func testUnzoomedPanIsPinnedToZero() {
        let clamped = CanvasZoom.clampedPan(
            CGSize(width: 120, height: -90), zoom: 1, containerSize: container
        )
        XCTAssertEqual(clamped.width, 0, accuracy: 1e-9)
        XCTAssertEqual(clamped.height, 0, accuracy: 1e-9)
    }

    /// The legal pan is exactly the overhang either side of centre, so the
    /// scaled content always covers the container — no gutter, and the photo
    /// can't be pushed off screen.
    func testPanClampsToTheOverhang() {
        let zoom: CGFloat = 3
        let limitX = container.width * (zoom - 1) / 2
        let limitY = container.height * (zoom - 1) / 2

        let overshot = CanvasZoom.clampedPan(
            CGSize(width: 9_999, height: -9_999), zoom: zoom, containerSize: container
        )
        XCTAssertEqual(overshot.width, limitX, accuracy: 1e-9)
        XCTAssertEqual(overshot.height, -limitY, accuracy: 1e-9)

        let inBounds = CGSize(width: limitX / 2, height: -limitY / 2)
        let untouched = CanvasZoom.clampedPan(inBounds, zoom: zoom, containerSize: container)
        XCTAssertEqual(untouched.width, inBounds.width, accuracy: 1e-9)
        XCTAssertEqual(untouched.height, inBounds.height, accuracy: 1e-9)
    }

    /// A degenerate container (first layout pass, before geometry resolves)
    /// must not produce NaN — the editor reads `canvasSize` from
    /// `.onGeometryChange`, which is `.zero` on the first frame.
    func testDegenerateContainerStaysFinite() {
        let mapped = CanvasZoom.contentPoint(
            container: CGPoint(x: 5, y: 5), containerSize: .zero, zoom: 2, pan: .zero
        )
        XCTAssertTrue(mapped.x.isFinite)
        XCTAssertTrue(mapped.y.isFinite)

        let clamped = CanvasZoom.clampedPan(
            CGSize(width: 10, height: 10), zoom: 4, containerSize: .zero
        )
        XCTAssertEqual(clamped.width, 0, accuracy: 1e-9)
        XCTAssertEqual(clamped.height, 0, accuracy: 1e-9)
    }
}
