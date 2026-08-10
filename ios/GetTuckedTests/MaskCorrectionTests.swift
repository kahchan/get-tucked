import XCTest
import CoreGraphics
import SwiftData
@testable import GetTucked

/// Plan AK5 — the rider-assisted correction pipeline. Everything here runs
/// on already-persisted-shaped `Data`/`CGImage`, never on Vision, so it is
/// fully exercisable in the Simulator (unlike segmentation itself — see the
/// standing traps in CLAUDE.md). The one part of AK5 these tests can't
/// reach is the drawing *gesture*, which needs a device.
final class MaskCorrectionTests: XCTestCase {
    // MARK: - Fixtures

    /// A synthetic DeviceGray mask written row-by-row into the bitmap
    /// buffer, whose first row is the image's TOP row — so `fill`'s `y` is a
    /// top-left-origin row index, matching how the correction's own
    /// coordinates are specified.
    private func makeMask(width: Int, height: Int, fill: (Int, Int) -> UInt8) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        for y in 0 ..< height {
            for x in 0 ..< width {
                bytes[y * context.bytesPerRow + x] = fill(x, y)
            }
        }
        return try XCTUnwrap(context.makeImage())
    }

    /// 100×100: a 20×20 main blob at rows/cols 40...59 (400 px) plus a
    /// detached 5×5 blob at rows/cols 5...9 (25 px) — the shape of the
    /// exact failure AK5 exists to fix (a mis-included background object
    /// sitting apart from the rider).
    private func makeTwoBlobMask() throws -> CGImage {
        try makeMask(width: 100, height: 100) { x, y in
            if (40 ... 59).contains(x), (40 ... 59).contains(y) { return 255 }
            if (5 ... 9).contains(x), (5 ... 9).contains(y) { return 255 }
            return 0
        }
    }

    private let twoBlobCount = 425
    private let twoBlobArea = 850.0

    private func foregroundCount(of mask: CGImage) throws -> Int {
        let context = try XCTUnwrap(MatteRenderer.editableMaskContext(mask: mask))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return AnalysisMath.countForegroundPixels(
            bytes: bytes, width: context.width, height: context.height, bytesPerRow: context.bytesPerRow
        )
    }

    private func foregroundCount(ofPNG data: Data) throws -> Int {
        let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)
        return try foregroundCount(of: decoded)
    }

    // MARK: - Encode / decode round trip

    /// The seam the whole feature rests on: a stored mask PNG decoded into
    /// an editable buffer and re-encoded must come back byte-for-byte
    /// equivalent, or every correction silently drifts the automated
    /// measurement it was supposed to leave alone.
    func testDecodeEncodeRoundTripPreservesEveryPixel() throws {
        let mask = try makeTwoBlobMask()
        let context = try XCTUnwrap(MatteRenderer.editableMaskContext(mask: mask))
        let encoded = try XCTUnwrap(MatteRenderer.maskPNGData(from: context))
        let decoded = try XCTUnwrap(UIImage(data: encoded)?.cgImage)

        XCTAssertEqual(decoded.width, mask.width)
        XCTAssertEqual(decoded.height, mask.height)

        let roundTripped = try XCTUnwrap(MatteRenderer.editableMaskContext(mask: decoded))
        let original = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let result = try XCTUnwrap(roundTripped.data).assumingMemoryBound(to: UInt8.self)
        for y in 0 ..< mask.height {
            for x in 0 ..< mask.width {
                XCTAssertEqual(
                    original[y * context.bytesPerRow + x], result[y * roundTripped.bytesPerRow + x],
                    "pixel (\(x), \(y)) changed across the PNG round trip"
                )
            }
        }
    }

    /// No actions must be a true no-op on the number too — not just on the
    /// pixels — since the scale is reconstructed from the very pair being
    /// recomputed.
    func testNoActionsReproducesTheStoredArea() throws {
        let mask = try makeTwoBlobMask()
        let result = try XCTUnwrap(
            MaskCorrection.corrected(originalMask: mask, actions: [], originalAreaCm2: twoBlobArea)
        )
        XCTAssertEqual(result.foregroundPixelCount, twoBlobCount)
        XCTAssertEqual(result.frontalAreaCm2, twoBlobArea, accuracy: 1e-9)
        XCTAssertEqual(try foregroundCount(ofPNG: result.maskPNGData), twoBlobCount)
    }

    func testRejectsNonPositiveStoredArea() throws {
        let mask = try makeTwoBlobMask()
        XCTAssertNil(MaskCorrection.corrected(originalMask: mask, actions: [], originalAreaCm2: 0))
    }

    func testRejectsEmptyMask() throws {
        let empty = try makeMask(width: 20, height: 20) { _, _ in 0 }
        XCTAssertNil(MaskCorrection.corrected(originalMask: empty, actions: [], originalAreaCm2: 100))
    }

    // MARK: - connectedRegion (the TAP tool's flood fill)

    /// Two disjoint blobs: seeding one must return exactly that blob and
    /// never leak into the other. `bytesPerRow` is deliberately wider than
    /// `width` — a fill that strides by `width` would wrap off the end of
    /// one row into the start of the next and swallow the whole image.
    func testConnectedRegionStopsAtTheBlobBoundaryWithPaddedRows() {
        let width = 10, height = 8, bytesPerRow = 16
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        // Blob A: cols 1...2, rows 1...2 (4 px). Blob B: cols 7...8, row 6 (2 px).
        for y in 1 ... 2 { for x in 1 ... 2 { bytes[y * bytesPerRow + x] = 255 } }
        for x in 7 ... 8 { bytes[6 * bytesPerRow + x] = 255 }
        // Row padding set to a foreground-looking value: only a width-strided
        // read would ever see it.
        for y in 0 ..< height { for x in width ..< bytesPerRow { bytes[y * bytesPerRow + x] = 255 } }

        let region = bytes.withUnsafeBufferPointer { buffer -> [Int] in
            MaskCorrection.connectedRegion(
                bytes: buffer.baseAddress!, width: width, height: height,
                bytesPerRow: bytesPerRow, seedX: 1, seedY: 1
            )
        }

        let coordinates = Set(region.map { ($0 % bytesPerRow, $0 / bytesPerRow) }.map { "\($0.0),\($0.1)" })
        XCTAssertEqual(coordinates, ["1,1", "2,1", "1,2", "2,2"])
    }

    /// 4-connectivity, not 8: a diagonal touch is a separate region. Stated
    /// as a test because the choice is invisible in the code and changes
    /// what a single tap selects on a thin, stepped edge.
    func testConnectedRegionIsFourConnectedNotEight() {
        let width = 4, height = 4, bytesPerRow = 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        bytes[1 * bytesPerRow + 1] = 255
        bytes[2 * bytesPerRow + 2] = 255

        let region = bytes.withUnsafeBufferPointer { buffer -> [Int] in
            MaskCorrection.connectedRegion(
                bytes: buffer.baseAddress!, width: width, height: height,
                bytesPerRow: bytesPerRow, seedX: 1, seedY: 1
            )
        }
        XCTAssertEqual(region, [1 * bytesPerRow + 1])
    }

    /// Seeding a background pixel selects the background region, which is
    /// what makes one tap able to fill an enclosed hole.
    func testConnectedRegionSelectsBackgroundWhenSeededOnBackground() {
        let width = 5, height = 5, bytesPerRow = 5
        var bytes = [UInt8](repeating: 255, count: bytesPerRow * height)
        bytes[2 * bytesPerRow + 2] = 0

        let region = bytes.withUnsafeBufferPointer { buffer -> [Int] in
            MaskCorrection.connectedRegion(
                bytes: buffer.baseAddress!, width: width, height: height,
                bytesPerRow: bytesPerRow, seedX: 2, seedY: 2
            )
        }
        XCTAssertEqual(region, [2 * bytesPerRow + 2])
    }

    func testConnectedRegionRejectsAnOutOfBoundsSeed() {
        let bytes = [UInt8](repeating: 255, count: 9)
        let region = bytes.withUnsafeBufferPointer { buffer -> [Int] in
            MaskCorrection.connectedRegion(
                bytes: buffer.baseAddress!, width: 3, height: 3, bytesPerRow: 3, seedX: 5, seedY: 0
            )
        }
        XCTAssertTrue(region.isEmpty)
    }

    // MARK: - TAP through the full pipeline

    /// The headline case: tap the mis-included detached blob, and the area
    /// drops by exactly that blob's share. Exact (not approximate) because
    /// the fill writes raw bytes with no antialiasing to round off.
    /// The headline case doubles as AK22's "a small detached blob still
    /// flips whole": at the default radius (3px on this 100×100 canvas) the
    /// 5×5 blob's farthest corner (2.83px from the tap) is still inside the
    /// disc, so the bound doesn't change this result.
    func testTapFlipRemovesADetachedBlobAndRescalesAreaExactly() throws {
        let mask = try makeTwoBlobMask()
        let result = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: mask,
            actions: [.tapFlip(CGPoint(x: 0.075, y: 0.075), radiusUnit: MaskCorrection.brushRadiusUnit)],
            originalAreaCm2: twoBlobArea
        ))

        XCTAssertEqual(result.foregroundPixelCount, 400)
        XCTAssertEqual(result.frontalAreaCm2, twoBlobArea * 400.0 / Double(twoBlobCount), accuracy: 1e-9)
        XCTAssertEqual(try foregroundCount(ofPNG: result.maskPNGData), 400)
    }

    /// AK22's y-convention probe: with the fill now bounded to a disc,
    /// "flips the whole background" is no longer the failure signature to
    /// pin down. Instead: a marker that exists only near the TOP of the
    /// image, tapped at a top-left-origin unit point close to y=0. Correct
    /// top-left mapping seeds on the marker and flips it out (count drops
    /// below the marker's size); a bottom-origin bug would seed on empty
    /// background near the bottom instead, growing the count as background
    /// flips in.
    func testTapFlipUsesTopLeftOriginCoordinates() throws {
        let markerCount = 5 * 3
        let mask = try makeMask(width: 100, height: 100) { x, y in
            (0 ... 2).contains(y) && (48 ... 52).contains(x) ? 255 : 0
        }
        let result = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: mask,
            actions: [.tapFlip(CGPoint(x: 0.5, y: 0.01), radiusUnit: MaskCorrection.brushRadiusUnit)],
            originalAreaCm2: 100
        ))
        XCTAssertLessThan(result.foregroundPixelCount, markerCount)
    }

    /// AK22: a tap on open background flips only a disc, not the whole
    /// frame — the fix for "it swallows everything".
    func testTapFlipOnBackgroundFlipsOnlyADisc() throws {
        let mask = try makeTwoBlobMask()
        let result = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: mask,
            actions: [.tapFlip(CGPoint(x: 0.9, y: 0.9), radiusUnit: MaskCorrection.brushRadiusUnit)],
            originalAreaCm2: twoBlobArea
        ))
        XCTAssertGreaterThan(result.foregroundPixelCount, twoBlobCount)
        XCTAssertLessThan(result.foregroundPixelCount, 100 * 100)
    }

    /// AK22: the same tap at two radii flips proportionally — doubling the
    /// radius roughly quadruples the disc's area (πr²). A lone foreground
    /// pixel far from the tap keeps the mask non-empty (`corrected` rejects
    /// an all-background mask) without ever falling inside either disc.
    func testTapFlipRadiusScalesTheFlippedRegion() throws {
        let mask = try makeMask(width: 100, height: 100) { x, y in x == 0 && y == 0 ? 255 : 0 }
        let small = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: mask, actions: [.tapFlip(CGPoint(x: 0.5, y: 0.5), radiusUnit: 0.03)],
            originalAreaCm2: 100
        ))
        let large = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: mask, actions: [.tapFlip(CGPoint(x: 0.5, y: 0.5), radiusUnit: 0.06)],
            originalAreaCm2: 100
        ))
        let ratio = Double(large.foregroundPixelCount) / Double(small.foregroundPixelCount)
        XCTAssertEqual(ratio, 4, accuracy: 0.6)
    }

    /// Actions replay in order, and a tap reads whatever the actions before
    /// it left behind — so the same two taps in the other order land
    /// somewhere different. Guards against any future "optimise by batching
    /// the taps" refactor.
    ///
    /// Deliberately runs at the real 1× radius rather than an oversized one.
    /// The editor can only ever produce `brushRadiusUnit / zoom` for
    /// `zoom` in `1...maxZoom`, so a radius bigger than the canvas is
    /// unreachable in the app — a test that needs one is asserting against a
    /// configuration that cannot occur. Two adjacent taps of *opposite* seed
    /// state are enough to expose the ordering, and the assertion is
    /// inequality rather than two hand-computed pixel counts: the property
    /// under test is that order matters, not what the flood arithmetic sums
    /// to.
    func testActionOrderChangesTheOutcome() throws {
        let mask = try makeTwoBlobMask()
        let radius = MaskCorrection.brushRadiusUnit
        // (0.075, 0.075) is the small blob; (0.115, 0.075) is background just
        // clear of it, close enough that each tap's disc reaches pixels the
        // other one has already flipped.
        let blob = CGPoint(x: 0.075, y: 0.075)
        let background = CGPoint(x: 0.115, y: 0.075)

        let blobFirst = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: mask,
            actions: [.tapFlip(blob, radiusUnit: radius), .tapFlip(background, radiusUnit: radius)],
            originalAreaCm2: twoBlobArea
        ))
        let backgroundFirst = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: mask,
            actions: [.tapFlip(background, radiusUnit: radius), .tapFlip(blob, radiusUnit: radius)],
            originalAreaCm2: twoBlobArea
        ))

        XCTAssertNotEqual(blobFirst.foregroundPixelCount, backgroundFirst.foregroundPixelCount)
        XCTAssertNotEqual(blobFirst.foregroundPixelCount, twoBlobCount)
        XCTAssertNotEqual(backgroundFirst.foregroundPixelCount, twoBlobCount)
    }

    // MARK: - BRUSH through the full pipeline

    /// An INCLUDE dab in empty background adds roughly a brush-sized disc —
    /// asserted as a range, not an exact count, because the stroke is
    /// antialiased (its rim lands either side of the 128 threshold).
    func testIncludeBrushDabAddsRoughlyOneBrushDisc() throws {
        let mask = try makeTwoBlobMask()
        let radius = MaskCorrection.brushRadiusUnit * 100
        let discArea = Double.pi * Double(radius * radius)

        let result = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: mask,
            actions: [.stroke(.init(brush: .include, points: [CGPoint(x: 0.8, y: 0.2)]))],
            originalAreaCm2: twoBlobArea
        ))

        let added = Double(result.foregroundPixelCount - twoBlobCount)
        XCTAssertEqual(added, discArea, accuracy: discArea * 0.35)
        XCTAssertGreaterThan(result.frontalAreaCm2, twoBlobArea)
        XCTAssertEqual(try foregroundCount(ofPNG: result.maskPNGData), result.foregroundPixelCount)
    }

    /// The brush uses the same TOP-left origin as the tap: a dab high on
    /// screen must land in the image's top rows. A missing y-flip would put
    /// it in the bottom rows instead, which is invisible in a pixel count
    /// and only shows up in a positional check like this one.
    func testBrushDabLandsAtTheTopLeftOriginPoint() throws {
        let blank = try makeMask(width: 100, height: 100) { x, y in
            (0 ... 4).contains(x) && (0 ... 4).contains(y) ? 255 : 0
        }
        let corrected = try XCTUnwrap(MaskCorrection.workingMask(
            originalMask: blank,
            actions: [.stroke(.init(brush: .include, points: [CGPoint(x: 0.5, y: 0.1)]))]
        ))
        let context = try XCTUnwrap(MatteRenderer.editableMaskContext(mask: corrected))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)

        XCTAssertGreaterThanOrEqual(bytes[10 * context.bytesPerRow + 50], 128, "dab should sit 10 rows from the top")
        XCTAssertLessThan(bytes[90 * context.bytesPerRow + 50], 128, "nothing should be painted at the mirrored row")
    }

    /// EXCLUDE genuinely erases rather than compositing to a mid grey — the
    /// reason the brush draws in `.copy` blend mode.
    func testExcludeBrushRemovesForegroundPixels() throws {
        let mask = try makeTwoBlobMask()
        let result = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: mask,
            actions: [.stroke(.init(brush: .exclude, points: [CGPoint(x: 0.5, y: 0.5)]))],
            originalAreaCm2: twoBlobArea
        ))
        XCTAssertLessThan(result.foregroundPixelCount, twoBlobCount)
        XCTAssertLessThan(result.frontalAreaCm2, twoBlobArea)
    }

    /// A stroke is a path, not a bag of dabs: dragging across the canvas
    /// must paint a continuous line, so it adds far more than a single dab.
    func testMultiPointStrokePaintsAContinuousPath() throws {
        let blank = try makeMask(width: 100, height: 100) { x, y in
            (0 ... 4).contains(x) && (0 ... 4).contains(y) ? 255 : 0
        }
        let dab = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: blank,
            actions: [.stroke(.init(brush: .include, points: [CGPoint(x: 0.2, y: 0.5)]))],
            originalAreaCm2: 25
        ))
        let drag = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: blank,
            actions: [.stroke(.init(brush: .include, points: [
                CGPoint(x: 0.2, y: 0.5), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.8, y: 0.5),
            ]))],
            originalAreaCm2: 25
        ))
        XCTAssertGreaterThan(drag.foregroundPixelCount, dab.foregroundPixelCount * 2)
    }

    // MARK: - Non-destructiveness

    /// The original mask is never mutated and never accumulated onto: the
    /// same actions always produce the same result, and dropping the last
    /// action (UNDO) reproduces the earlier state exactly rather than
    /// leaving its pixels behind.
    func testReplayIsPureSoUndoTrulyReverts() throws {
        let mask = try makeTwoBlobMask()
        let first: [MaskCorrection.Action] = [
            .tapFlip(CGPoint(x: 0.075, y: 0.075), radiusUnit: MaskCorrection.brushRadiusUnit),
        ]
        let second = first + [.stroke(.init(brush: .include, points: [CGPoint(x: 0.8, y: 0.2)]))]

        let a = try XCTUnwrap(MaskCorrection.corrected(originalMask: mask, actions: first, originalAreaCm2: twoBlobArea))
        _ = try XCTUnwrap(MaskCorrection.corrected(originalMask: mask, actions: second, originalAreaCm2: twoBlobArea))
        let afterUndo = try XCTUnwrap(
            MaskCorrection.corrected(originalMask: mask, actions: first, originalAreaCm2: twoBlobArea)
        )

        XCTAssertEqual(afterUndo.foregroundPixelCount, a.foregroundPixelCount)
        XCTAssertEqual(afterUndo.frontalAreaCm2, a.frontalAreaCm2, accuracy: 1e-9)
        XCTAssertEqual(try foregroundCount(of: mask), twoBlobCount, "the original mask must never be mutated")
    }

    /// A corrected mask is byte-format-identical to an automated one, so
    /// correcting a correction (were it ever re-fed) behaves the same as
    /// correcting an original — and every existing mask reader consumes it
    /// unchanged.
    func testCorrectedPNGIsItselfAValidCorrectionInput() throws {
        let mask = try makeTwoBlobMask()
        let once = try XCTUnwrap(MaskCorrection.corrected(
            originalMask: mask,
            actions: [.tapFlip(CGPoint(x: 0.075, y: 0.075), radiusUnit: MaskCorrection.brushRadiusUnit)],
            originalAreaCm2: twoBlobArea
        ))
        let twice = try XCTUnwrap(MaskCorrection.corrected(
            originalMaskData: once.maskPNGData, actions: [], originalAreaCm2: once.frontalAreaCm2
        ))
        XCTAssertEqual(twice.foregroundPixelCount, once.foregroundPixelCount)
        XCTAssertEqual(twice.frontalAreaCm2, once.frontalAreaCm2, accuracy: 1e-9)
    }

    // MARK: - Read seam

    func testEffectiveAreaFallsBackToTheAutomatedNumber() {
        let metrics = PositionMetrics(
            frontalAreaCm2: 400, frontalAreaUncertainty: 12, pixelsPerCm: 10, foregroundPixelCount: 40_000
        )
        XCTAssertEqual(metrics.effectiveFrontalAreaCm2, 400)
        XCTAssertEqual(metrics.effectiveFrontalAreaUncertainty, 12)
        XCTAssertFalse(metrics.isManuallyCorrected)
    }

    /// The ± band is a fixed fraction of area stored as an absolute, so a
    /// correction has to carry it — otherwise the band silently claims the
    /// automated area's precision against a different number.
    func testEffectiveUncertaintyKeepsTheStoredFractionAcrossACorrection() {
        let metrics = PositionMetrics(
            frontalAreaCm2: 400, frontalAreaUncertainty: 12, pixelsPerCm: 10, foregroundPixelCount: 40_000
        )
        metrics.correctedFrontalAreaCm2 = 380

        XCTAssertTrue(metrics.isManuallyCorrected)
        XCTAssertEqual(metrics.effectiveFrontalAreaCm2, 380)
        XCTAssertEqual(metrics.effectiveFrontalAreaUncertainty, 11.4, accuracy: 1e-9)
        XCTAssertEqual(
            metrics.effectiveFrontalAreaUncertainty / metrics.effectiveFrontalAreaCm2,
            12.0 / 400.0, accuracy: 1e-12
        )
        XCTAssertEqual(metrics.frontalAreaCm2, 400, "the automated number must survive as the audit trail")
    }

    // MARK: - SchemaV11

    /// The standing trap (CLAUDE.md): a schema bump that doesn't reach
    /// `Schema(versionedSchema:)` fatals at launch with "Failed to cast
    /// model", which no other test in this suite would catch. Builds the
    /// container exactly as `GetTuckedApp` does — live schema plus the full
    /// migration plan — and round-trips both new fields through it.
    func testLiveContainerBuildsAndPersistsTheCorrectionFields() throws {
        let schema = Schema(versionedSchema: SchemaV11.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema, migrationPlan: AppMigrationPlan.self, configurations: [configuration]
        )
        let context = ModelContext(container)

        let position = Position(label: "Tuck", bike: nil)
        let metrics = PositionMetrics(
            frontalAreaCm2: 400, frontalAreaUncertainty: 12, pixelsPerCm: 10, foregroundPixelCount: 40_000
        )
        position.metrics = metrics
        position.correctedSubjectMaskData = Data([1, 2, 3])
        metrics.correctedFrontalAreaCm2 = 380
        context.insert(position)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<Position>()).first)
        XCTAssertEqual(fetched.correctedSubjectMaskData, Data([1, 2, 3]))
        XCTAssertEqual(fetched.metrics?.correctedFrontalAreaCm2, 380)
        XCTAssertEqual(fetched.metrics?.effectiveFrontalAreaCm2, 380)
    }
}
