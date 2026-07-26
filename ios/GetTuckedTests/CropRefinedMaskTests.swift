import XCTest
import CoreGraphics
@testable import GetTucked

/// Plan AD5b — pure geometry tests for the crop-and-reseg side-on matte
/// helpers. The `VNGeneratePersonSegmentation` pass itself needs the device
/// (it returns nil on the Simulator), but the bbox / paste / resample math
/// that places the crop mask back into a full frame is plain byte arithmetic
/// and runs identically here. These pin the parts that would ship a
/// mis-placed or flipped matte if wrong.
final class CropRefinedMaskTests: XCTestCase {

    /// Builds a packed 8-bit gray `CGImage` with a solid `fg`-valued rectangle
    /// (top-left pixel coords) on a 0 background.
    private func grayImage(
        w: Int, h: Int, rectX: Range<Int>, rectY: Range<Int>, fg: UInt8 = 255
    ) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: w * h)
        for y in rectY where y >= 0 && y < h {
            for x in rectX where x >= 0 && x < w {
                bytes[y * w + x] = fg
            }
        }
        return AnalysisEngine.grayCGImage(bytes, width: w, height: h)!
    }

    // MARK: - grayBytes / grayCGImage round-trip

    func testGrayRoundTripPreservesPixels() throws {
        let img = grayImage(w: 8, h: 5, rectX: 2..<6, rectY: 1..<4, fg: 200)
        let decoded = try XCTUnwrap(AnalysisEngine.grayBytes(from: img))
        XCTAssertEqual(decoded.w, 8)
        XCTAssertEqual(decoded.h, 5)
        // Inside the rect reads fg, outside reads background.
        XCTAssertEqual(decoded.gray[1 * 8 + 2], 200)
        XCTAssertEqual(decoded.gray[3 * 8 + 5], 200)
        XCTAssertEqual(decoded.gray[0 * 8 + 0], 0)
        XCTAssertEqual(decoded.gray[4 * 8 + 7], 0)
    }

    // MARK: - maskForegroundBBox

    func testForegroundBBoxIsTopLeftFractions() throws {
        // Foreground rect: x 2..<6 (cols 2,3,4,5), y 1..<4 (rows 1,2,3) in a 8×5 frame.
        let img = grayImage(w: 8, h: 5, rectX: 2..<6, rectY: 1..<4)
        let bbox = try XCTUnwrap(AnalysisEngine.maskForegroundBBox(img, threshold: 128))
        XCTAssertEqual(bbox.x0, 2.0 / 8.0, accuracy: 1e-9)
        XCTAssertEqual(bbox.y0, 1.0 / 5.0, accuracy: 1e-9, "y0 counts from the TOP (top-left origin)")
        XCTAssertEqual(bbox.x1, 6.0 / 8.0, accuracy: 1e-9, "x1 is one past the last fg column")
        XCTAssertEqual(bbox.y1, 4.0 / 5.0, accuracy: 1e-9)
    }

    func testForegroundBBoxRespectsThreshold() {
        // A rect at value 100 is below a 128 threshold → no foreground.
        let img = grayImage(w: 6, h: 6, rectX: 1..<4, rectY: 1..<4, fg: 100)
        XCTAssertNil(AnalysisEngine.maskForegroundBBox(img, threshold: 128))
        XCTAssertNotNil(AnalysisEngine.maskForegroundBBox(img, threshold: 50))
    }

    func testForegroundBBoxNilOnEmptyMask() {
        let img = grayImage(w: 4, h: 4, rectX: 0..<0, rectY: 0..<0)
        XCTAssertNil(AnalysisEngine.maskForegroundBBox(img, threshold: 128))
    }

    // MARK: - resampleGray

    func testResampleGrayReturnsRequestedSize() {
        let src = [UInt8](repeating: 255, count: 4 * 4)
        let out = AnalysisEngine.resampleGray(src, w: 4, h: 4, toW: 10, toH: 7)
        XCTAssertEqual(out.count, 10 * 7)
        // A fully-solid mask stays solid after resampling.
        XCTAssertTrue(out.allSatisfy { $0 == 255 })
    }

    func testResampleGrayIdentityWhenSameSize() {
        let src: [UInt8] = [0, 1, 2, 3]
        let out = AnalysisEngine.resampleGray(src, w: 2, h: 2, toW: 2, toH: 2)
        XCTAssertEqual(out, src)
    }

    // MARK: - pasteMaskFullFrame

    func testPasteLandsInsideBBoxAndZeroOutside() {
        // Crop is a solid 4×4 block; paste into the top-left quadrant of a
        // 10×10 frame (bbox 0.0–0.4 in both axes → offset 0, size 4).
        let crop = [UInt8](repeating: 255, count: 4 * 4)
        let full = AnalysisEngine.pasteMaskFullFrame(
            cropGray: crop, cropW: 4, cropH: 4,
            bbox: (x0: 0.0, y0: 0.0, x1: 0.4, y1: 0.4),
            fullW: 10, fullH: 10
        )
        XCTAssertEqual(full.count, 100)
        // Inside the pasted box (top-left origin) is solid.
        XCTAssertEqual(full[0 * 10 + 0], 255)
        XCTAssertEqual(full[3 * 10 + 3], 255)
        // Just outside the box is background.
        XCTAssertEqual(full[0 * 10 + 4], 0)
        XCTAssertEqual(full[4 * 10 + 0], 0)
        XCTAssertEqual(full[9 * 10 + 9], 0)
    }

    func testPasteOffsetBBoxPlacesTopLeft() {
        // bbox x 0.5–0.9, y 0.2–0.6 in a 10×10 frame → offset (5,2), size (4,4).
        let crop = [UInt8](repeating: 255, count: 4 * 4)
        let full = AnalysisEngine.pasteMaskFullFrame(
            cropGray: crop, cropW: 4, cropH: 4,
            bbox: (x0: 0.5, y0: 0.2, x1: 0.9, y1: 0.6),
            fullW: 10, fullH: 10
        )
        // Corner of the pasted region (row 2, col 5) is solid; the pixel above
        // it (row 1) and to its left (col 4) are background — confirms the
        // top-left origin placement, not a vertical flip.
        XCTAssertEqual(full[2 * 10 + 5], 255)
        XCTAssertEqual(full[1 * 10 + 5], 0)
        XCTAssertEqual(full[2 * 10 + 4], 0)
        XCTAssertEqual(full[5 * 10 + 8], 255)
    }

    func testPasteEmptyBBoxIsAllBackground() {
        let crop = [UInt8](repeating: 255, count: 1)
        let full = AnalysisEngine.pasteMaskFullFrame(
            cropGray: crop, cropW: 1, cropH: 1,
            bbox: (x0: 0.5, y0: 0.5, x1: 0.5, y1: 0.5),
            fullW: 8, fullH: 8
        )
        XCTAssertTrue(full.allSatisfy { $0 == 0 })
    }
}
