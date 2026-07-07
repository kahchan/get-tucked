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
}
