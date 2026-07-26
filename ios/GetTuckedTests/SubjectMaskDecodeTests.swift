import XCTest
import CoreVideo
import CoreGraphics
@testable import GetTucked

/// Plan AD2/AD3 — pure buffer-plumbing tests for the two pixel formats Part
/// 1's Mac harness confirmed empirically: `VNInstanceMaskObservation.instanceMask`
/// is `OneComponent8` (512×512 UInt8 labels), `generateScaledMaskForImage`'s
/// output is `OneComponent32Float` at full source resolution. No Neural
/// Engine involved — these build synthetic `CVPixelBuffer`s by hand, so they
/// run the same in CI/simulator as on device.
final class SubjectMaskDecodeTests: XCTestCase {
    // MARK: - instanceBoundingBoxes (OneComponent8 label buffer)

    /// Two labelled rectangles in a buffer whose `bytesPerRow` is forced
    /// wider than `width` (via row-alignment) — proves the read strides by
    /// `CVPixelBufferGetBytesPerRow`, not `width`, which is exactly the bug
    /// class H1 was (reading the wrong format entirely, but a width-only
    /// stride would have been silently wrong here too).
    func testInstanceBoundingBoxesStridesPaddedRows() throws {
        let width = 20, height = 16
        let buffer = makeLabelBuffer(width: width, height: height, rowAlignment: 64)
        XCTAssertGreaterThan(CVPixelBufferGetBytesPerRow(buffer), width, "test buffer must actually have row padding")

        // Instance 1: columns 2...7, rows 1...4 (top-down pixel coords).
        // Instance 2: columns 10...15, rows 8...12.
        setLabel(1, inBuffer: buffer, x0: 2, x1: 7, y0: 1, y1: 4)
        setLabel(2, inBuffer: buffer, x0: 10, x1: 15, y0: 8, y1: 12)

        guard case .success(let boxes) = AnalysisEngine.instanceBoundingBoxes(mask: buffer) else {
            return XCTFail("expected success decoding a well-formed OneComponent8 label buffer")
        }
        XCTAssertEqual(boxes.count, 2)

        // Bottom-left-origin conversion: xFrac = col / width, yFrac counts
        // up from the bottom, so a box low in top-down pixel rows (large y)
        // sits low in the normalised frame (small yFrac).
        let box1 = try XCTUnwrap(boxes[1])
        XCTAssertEqual(box1.minX, 2.0 / 20.0, accuracy: 1e-9)
        XCTAssertEqual(box1.width, 6.0 / 20.0, accuracy: 1e-9)
        XCTAssertEqual(box1.minY, 1 - Double(4 + 1) / 16.0, accuracy: 1e-9)
        XCTAssertEqual(box1.height, 4.0 / 16.0, accuracy: 1e-9)

        let box2 = try XCTUnwrap(boxes[2])
        XCTAssertEqual(box2.minX, 10.0 / 20.0, accuracy: 1e-9)
        XCTAssertEqual(box2.width, 6.0 / 20.0, accuracy: 1e-9)
        XCTAssertEqual(box2.minY, 1 - Double(12 + 1) / 16.0, accuracy: 1e-9)
        XCTAssertEqual(box2.height, 5.0 / 16.0, accuracy: 1e-9)
    }

    /// The exact pre-AD2 failure mode: reading a real (all-zero-until-set)
    /// label buffer used to happen through a Float32 lens — that path is
    /// gone now, this just confirms an all-background buffer correctly
    /// yields "no instances", not a crash.
    func testInstanceBoundingBoxesAllBackgroundYieldsEmptySuccess() {
        let buffer = makeLabelBuffer(width: 8, height: 8, rowAlignment: 1)
        guard case .success(let boxes) = AnalysisEngine.instanceBoundingBoxes(mask: buffer) else {
            return XCTFail("expected success with an empty box set for an all-background buffer")
        }
        XCTAssertTrue(boxes.isEmpty)
    }

    /// H1: a wrong-format instanceMask must fail loudly with the reason enum
    /// (Plan AD3), not silently return nil the way the pre-fix Float32 read did.
    func testInstanceBoundingBoxesWrongFormatReturnsUnexpectedMaskFormat() {
        let wrongFormatBuffer = makeBGRABuffer(width: 8, height: 8)
        let result = AnalysisEngine.instanceBoundingBoxes(mask: wrongFormatBuffer)
        XCTAssertEqual(result, .failure(.unexpectedMaskFormat(kCVPixelFormatType_32BGRA)))
    }

    // MARK: - cgImageFromPixelBuffer (OneComponent32Float soft mask)

    /// Four quadrants at 0.0 / 0.4 / 0.6 / 1.0 — the 128 foreground threshold
    /// (`AnalysisMath.countForegroundPixels`, `MatteRenderer`) must fall
    /// exactly between the 0.4 and 0.6 quadrants: 0.4×255=102 (<128, reads
    /// background), 0.6×255=153 (≥128, reads foreground).
    func testCgImageFromPixelBufferConvertsFloatMaskToEightBitGray() throws {
        let width = 10, height = 10
        let buffer = makeFloatMaskBuffer(width: width, height: height, rowAlignment: 64) { x, y in
            if y < height / 2 {
                return x < width / 2 ? 0.0 : 0.4
            } else {
                return x < width / 2 ? 0.6 : 1.0
            }
        }
        XCTAssertGreaterThan(CVPixelBufferGetBytesPerRow(buffer), width * 4, "test buffer must actually have row padding")

        let image = try AnalysisEngine.cgImageFromPixelBuffer(buffer, sourceSize: CGSize(width: width, height: height))
        XCTAssertEqual(image.width, width)
        XCTAssertEqual(image.height, height)

        let bytes = try grayBytes(of: image)
        XCTAssertEqual(bytes.bytesPerRow >= width, true)

        XCTAssertEqual(bytes.value(x: 1, y: 1), 0)
        XCTAssertEqual(bytes.value(x: width - 2, y: 1), 102)
        XCTAssertEqual(bytes.value(x: 1, y: height - 2), 153)
        XCTAssertEqual(bytes.value(x: width - 2, y: height - 2), 255)
    }

    /// A value outside 0...1 (Vision's contract, but defend anyway) must
    /// clamp rather than wrap/overflow the UInt8 conversion.
    func testCgImageFromPixelBufferClampsOutOfRangeFloats() throws {
        let width = 4, height = 4
        let buffer = makeFloatMaskBuffer(width: width, height: height, rowAlignment: 1) { _, _ in 1.7 }
        let image = try AnalysisEngine.cgImageFromPixelBuffer(buffer, sourceSize: CGSize(width: width, height: height))
        let bytes = try grayBytes(of: image)
        XCTAssertEqual(bytes.value(x: 0, y: 0), 255)
    }

    // MARK: - Buffer builders

    /// OneComponent8, zero-initialised, with `bytesPerRow` forced wider than
    /// `width` via row alignment (when > 1) to prove the production read
    /// strides by the real `bytesPerRow`, not `width`.
    private func makeLabelBuffer(width: Int, height: Int, rowAlignment: Int) -> CVPixelBuffer {
        let attrs: [CFString: Any] = [
            kCVPixelBufferBytesPerRowAlignmentKey: rowAlignment,
            kCVPixelBufferCGImageCompatibilityKey: false,
            kCVPixelBufferCGBitmapContextCompatibilityKey: false,
        ]
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8, attrs as CFDictionary, &buffer
        )
        precondition(status == kCVReturnSuccess, "CVPixelBufferCreate failed: \(status)")
        let pixelBuffer = buffer!
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(base, 0, bytesPerRow * height)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }

    private func setLabel(_ value: UInt8, inBuffer buffer: CVPixelBuffer, x0: Int, x1: Int, y0: Int, y1: Int) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        for y in y0...y1 {
            for x in x0...x1 {
                bytes[y * bytesPerRow + x] = value
            }
        }
    }

    /// OneComponent32Float, filled per-pixel by `value(x:y:)` (0.0–1.0),
    /// with `bytesPerRow` forced wider than `width * 4` via row alignment
    /// (when > 1) to prove the float-stride math holds under padding too.
    private func makeFloatMaskBuffer(
        width: Int, height: Int, rowAlignment: Int, value: (Int, Int) -> Float32
    ) -> CVPixelBuffer {
        let attrs: [CFString: Any] = [
            kCVPixelBufferBytesPerRowAlignmentKey: rowAlignment,
        ]
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent32Float, attrs as CFDictionary, &buffer
        )
        precondition(status == kCVReturnSuccess, "CVPixelBufferCreate failed: \(status)")
        let pixelBuffer = buffer!
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.size
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let floats = base.assumingMemoryBound(to: Float32.self)
            for y in 0 ..< height {
                for x in 0 ..< width {
                    floats[y * floatsPerRow + x] = value(x, y)
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }

    /// Any format that is unambiguously not `OneComponent8`/`OneComponent32Float`
    /// — stands in for "Vision handed back something this engine doesn't expect".
    private func makeBGRABuffer(width: Int, height: Int) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer
        )
        precondition(status == kCVReturnSuccess, "CVPixelBufferCreate failed: \(status)")
        return buffer!
    }

    // MARK: - CGImage byte reader

    private struct GrayBytes {
        let data: Data
        let bytesPerRow: Int
        func value(x: Int, y: Int) -> UInt8 {
            data[y * bytesPerRow + x]
        }
    }

    private func grayBytes(of image: CGImage) throws -> GrayBytes {
        guard let provider = image.dataProvider, let data = provider.data else {
            throw XCTSkip("no data provider on decoded image")
        }
        return GrayBytes(data: data as Data, bytesPerRow: image.bytesPerRow)
    }
}
