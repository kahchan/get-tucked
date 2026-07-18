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

    // MARK: - lowestForegroundUnitY (ghost-compare ground fallback)

    private let overlayAcc = 1e-6

    func testLowestForegroundUnitYFindsBottomMostRow() {
        // 3x4 mask, foreground only at row 2 (one row above the bottom).
        let bytes: [UInt8] = [
            0, 0, 0,   // row 0 (top)
            0, 0, 0,   // row 1
            255, 0, 0, // row 2
            0, 0, 0,   // row 3 (bottom)
        ]
        let unitY = bytes.withUnsafeBufferPointer { buf in
            MatteRenderer.lowestForegroundUnitY(bytes: buf.baseAddress!, width: 3, height: 4, bytesPerRow: 3)
        }
        XCTAssertEqual(unitY ?? -1, 1.0 / 3.0, accuracy: overlayAcc)
    }

    func testLowestForegroundUnitYOnBottomRowIsZero() {
        let bytes: [UInt8] = [
            0, 0, 0,
            0, 0, 0,
            0, 0, 0,
            0, 255, 0, // row 3 (bottom)
        ]
        let unitY = bytes.withUnsafeBufferPointer { buf in
            MatteRenderer.lowestForegroundUnitY(bytes: buf.baseAddress!, width: 3, height: 4, bytesPerRow: 3)
        }
        XCTAssertEqual(unitY ?? -1, 0, accuracy: overlayAcc)
    }

    func testLowestForegroundUnitYOnTopRowIsOne() {
        let bytes: [UInt8] = [
            0, 255, 0, // row 0 (top)
            0, 0, 0,
            0, 0, 0,
            0, 0, 0,
        ]
        let unitY = bytes.withUnsafeBufferPointer { buf in
            MatteRenderer.lowestForegroundUnitY(bytes: buf.baseAddress!, width: 3, height: 4, bytesPerRow: 3)
        }
        XCTAssertEqual(unitY ?? -1, 1, accuracy: overlayAcc)
    }

    func testLowestForegroundUnitYNoForegroundReturnsNil() {
        let bytes: [UInt8] = Array(repeating: 0, count: 12)
        let unitY = bytes.withUnsafeBufferPointer { buf in
            MatteRenderer.lowestForegroundUnitY(bytes: buf.baseAddress!, width: 3, height: 4, bytesPerRow: 3)
        }
        XCTAssertNil(unitY)
    }

    func testLowestForegroundUnitYIgnoresRowPadding() {
        // 2x2 mask, bytesPerRow=3 (one padding byte per row). The bottom
        // row's padding byte is 255 but must never be read as pixel data.
        let bytes: [UInt8] = [
            0, 0, 9,      // row 0, padding
            0, 0, 255,    // row 1 (bottom), padding only — real pixels are background
        ]
        let unitY = bytes.withUnsafeBufferPointer { buf in
            MatteRenderer.lowestForegroundUnitY(bytes: buf.baseAddress!, width: 2, height: 2, bytesPerRow: 3)
        }
        XCTAssertNil(unitY)
    }

    // MARK: - twoToneOverlayPixels (Plan W2)

    func testTwoToneRiderPixelWhereSubjectAndPersonAgree() {
        // Single pixel: both subject and person read foreground → rider tint.
        let subject: [UInt8] = [255]
        let person: [UInt8] = [255]
        let rider = (r: UInt8(10), g: UInt8(20), b: UInt8(30), a: UInt8(128))
        let bike = (r: UInt8(200), g: UInt8(150), b: UInt8(20), a: UInt8(128))

        let rgba = subject.withUnsafeBufferPointer { subjectBuf in
            person.withUnsafeBufferPointer { personBuf in
                MatteRenderer.twoToneOverlayPixels(
                    subjectBytes: subjectBuf.baseAddress!, subjectBytesPerRow: 1,
                    personBytes: personBuf.baseAddress!, personBytesPerRow: 1,
                    width: 1, height: 1, riderColor: rider, bikeColor: bike
                )
            }
        }
        XCTAssertEqual(rgba, [rider.r, rider.g, rider.b, rider.a])
    }

    func testTwoToneBikePixelWhereSubjectForegroundButPersonBackground() {
        // Subject foreground, person background → bike/bags tint (subject − person).
        let subject: [UInt8] = [255]
        let person: [UInt8] = [0]
        let rider = (r: UInt8(10), g: UInt8(20), b: UInt8(30), a: UInt8(128))
        let bike = (r: UInt8(200), g: UInt8(150), b: UInt8(20), a: UInt8(128))

        let rgba = subject.withUnsafeBufferPointer { subjectBuf in
            person.withUnsafeBufferPointer { personBuf in
                MatteRenderer.twoToneOverlayPixels(
                    subjectBytes: subjectBuf.baseAddress!, subjectBytesPerRow: 1,
                    personBytes: personBuf.baseAddress!, personBytesPerRow: 1,
                    width: 1, height: 1, riderColor: rider, bikeColor: bike
                )
            }
        }
        XCTAssertEqual(rgba, [bike.r, bike.g, bike.b, bike.a])
    }

    func testTwoToneBackgroundPixelStaysTransparentRegardlessOfPerson() {
        // Subject background → fully transparent no matter what person says.
        let subject: [UInt8] = [0]
        let person: [UInt8] = [255]
        let rider = (r: UInt8(10), g: UInt8(20), b: UInt8(30), a: UInt8(128))
        let bike = (r: UInt8(200), g: UInt8(150), b: UInt8(20), a: UInt8(128))

        let rgba = subject.withUnsafeBufferPointer { subjectBuf in
            person.withUnsafeBufferPointer { personBuf in
                MatteRenderer.twoToneOverlayPixels(
                    subjectBytes: subjectBuf.baseAddress!, subjectBytesPerRow: 1,
                    personBytes: personBuf.baseAddress!, personBytesPerRow: 1,
                    width: 1, height: 1, riderColor: rider, bikeColor: bike
                )
            }
        }
        XCTAssertEqual(rgba, [0, 0, 0, 0])
    }

    func testTwoToneStridesEachBufferByItsOwnBytesPerRow() {
        // 2x1, subject has a padding byte (bytesPerRow=3), person doesn't
        // (bytesPerRow=2) — each buffer must stride independently.
        let subject: [UInt8] = [255, 0, 77]   // pixel0 fg, pixel1 bg, padding
        let person: [UInt8] = [255, 255]       // pixel0 fg, pixel1 fg
        let rider = (r: UInt8(1), g: UInt8(2), b: UInt8(3), a: UInt8(4))
        let bike = (r: UInt8(9), g: UInt8(9), b: UInt8(9), a: UInt8(9))

        let rgba = subject.withUnsafeBufferPointer { subjectBuf in
            person.withUnsafeBufferPointer { personBuf in
                MatteRenderer.twoToneOverlayPixels(
                    subjectBytes: subjectBuf.baseAddress!, subjectBytesPerRow: 3,
                    personBytes: personBuf.baseAddress!, personBytesPerRow: 2,
                    width: 2, height: 1, riderColor: rider, bikeColor: bike
                )
            }
        }
        // Pixel 0: subject fg, person fg -> rider.
        XCTAssertEqual(Array(rgba[0 ..< 4]), [rider.r, rider.g, rider.b, rider.a])
        // Pixel 1: subject bg -> transparent, regardless of person/padding.
        XCTAssertEqual(Array(rgba[4 ..< 8]), [0, 0, 0, 0])
    }

    // MARK: - resizedMask (Plan W2)

    func testResizedMaskReturnsSameInstanceWhenAlreadyTargetSize() {
        let mask = makeSquareMask()
        let resized = MatteRenderer.resizedMask(mask, toWidth: mask.width, height: mask.height)
        XCTAssertEqual(resized?.width, mask.width)
        XCTAssertEqual(resized?.height, mask.height)
    }

    func testResizedMaskProducesRequestedDimensions() {
        let mask = makeSquareMask()
        let resized = MatteRenderer.resizedMask(mask, toWidth: 6, height: 6)
        XCTAssertEqual(resized?.width, 6)
        XCTAssertEqual(resized?.height, 6)
    }
}
