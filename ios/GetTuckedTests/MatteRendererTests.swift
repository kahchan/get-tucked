import XCTest
@testable import GetTucked

final class MatteRendererTests: XCTestCase {
    /// 2x1 mask with one padding byte per row: [foreground, background, padding].
    /// bytesPerRow=3 so the pure pass must stride past the padding byte, not read it as a pixel.
    func testForegroundMapsToColorBackgroundAndPaddingAreTransparent() {
        let bytes: [UInt8] = [255, 0, 99]
        let fg = (r: UInt8(200), g: UInt8(180), b: UInt8(20), a: UInt8(127))

        let rgba = bytes.withUnsafeBufferPointer { buf in
            MatteRenderer.overlayPixels(
                bytes: buf.baseAddress!, width: 2, height: 1, bytesPerRow: 3,
                premultipliedForeground: fg
            )
        }

        XCTAssertEqual(rgba.count, 2 * 1 * 4)
        // Pixel 0 (foreground, byte 255 >= threshold) -> tinted.
        XCTAssertEqual(Array(rgba[0 ..< 4]), [fg.r, fg.g, fg.b, fg.a])
        // Pixel 1 (background, byte 0) -> fully transparent.
        XCTAssertEqual(Array(rgba[4 ..< 8]), [0, 0, 0, 0])
        // The row-padding byte (99) must never be read as a third pixel.
    }

    func testThresholdBoundary() {
        let bytes: [UInt8] = [128, 127]
        let fg = (r: UInt8(1), g: UInt8(2), b: UInt8(3), a: UInt8(4))

        let rgba = bytes.withUnsafeBufferPointer { buf in
            MatteRenderer.overlayPixels(
                bytes: buf.baseAddress!, width: 2, height: 1, bytesPerRow: 2,
                premultipliedForeground: fg, threshold: 128
            )
        }

        XCTAssertEqual(Array(rgba[0 ..< 4]), [1, 2, 3, 4])
        XCTAssertEqual(Array(rgba[4 ..< 8]), [0, 0, 0, 0])
    }

    // MARK: - outlineMask (Plan P2.2)

    /// 12x12 DeviceGray mask, foreground a 4x4 filled square at rows/cols
    /// 4...7 — small enough to keep the test cheap, large enough that a
    /// strokeWidthPx=3 ring has clean interior/exterior margin either side.
    private func makeSquareMask(canvasSize: Int = 12, squareRange: ClosedRange<Int> = 4 ... 7) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: canvasSize * canvasSize)
        for y in squareRange {
            for x in squareRange {
                bytes[y * canvasSize + x] = 255
            }
        }
        let context = CGContext(
            data: nil, width: canvasSize, height: canvasSize, bitsPerComponent: 8,
            bytesPerRow: canvasSize, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        bytes.withUnsafeBytes { ptr in
            context.data?.copyMemory(from: ptr.baseAddress!, byteCount: bytes.count)
        }
        return context.makeImage()!
    }

    private func pixelValue(_ image: CGImage, x: Int, y: Int) -> UInt8 {
        let data = image.dataProvider!.data!
        let bytes = CFDataGetBytePtr(data)!
        return bytes[y * image.bytesPerRow + x]
    }

    func testOutlineMaskInteriorStaysHollow() {
        let mask = makeSquareMask()
        let ring = MatteRenderer.outlineMask(mask: mask, strokeWidthPx: 3)!
        // Deep inside the square — foreground in both the original and the
        // dilated version, so excluded from the ring by definition
        // regardless of the morphology filter's exact edge behaviour.
        XCTAssertEqual(pixelValue(ring, x: 5, y: 5), 0)
    }

    func testOutlineMaskFarExteriorStaysZero() {
        let mask = makeSquareMask()
        let ring = MatteRenderer.outlineMask(mask: mask, strokeWidthPx: 3)!
        // Corner, far outside the square and outside the dilation radius —
        // background in both versions.
        XCTAssertEqual(pixelValue(ring, x: 0, y: 0), 0)
    }

    func testOutlineMaskRingAppearsJustOutsideTheBoundary() {
        let mask = makeSquareMask()
        let ring = MatteRenderer.outlineMask(mask: mask, strokeWidthPx: 3)!
        // Two pixels left of the square's left edge (col 4) — comfortably
        // inside the radius-3 dilation, background in the original.
        XCTAssertEqual(pixelValue(ring, x: 2, y: 5), 255)
    }

    func testOutlineMaskZeroStrokeWidthReturnsNil() {
        let mask = makeSquareMask()
        XCTAssertNil(MatteRenderer.outlineMask(mask: mask, strokeWidthPx: 0))
    }
}
