import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit

/// Rider-assisted matte correction (Plan AK5) — the pure half of the
/// feature: an ordered list of corrections replayed onto a decoded copy of a
/// position's *original* subject mask, recounted, and re-encoded into the
/// same stored PNG format.
///
/// Two tools, one pipeline: a freehand BRUSH stroke and a TAP that flips the
/// whole contiguous region under the finger. Both are just edits to the same
/// working buffer, applied in the order the rider made them — which matters,
/// since a tap's flood fill reads whatever the strokes before it left behind.
///
/// Deliberately re-derives from the original mask on every replay rather
/// than accumulating onto the previous correction: a correction is then
/// always a pure function of (original mask, actions), so RESET is a true
/// revert, UNDO is just dropping the last action, and a second edit session
/// can't compound rounding from the first.
///
/// Nothing here touches Vision or the camera — it operates entirely on
/// already-persisted `Data`, so the whole path is exercisable in the
/// Simulator and under XCTest.
enum MaskCorrection {
    enum Brush: Equatable {
        case include
        case exclude
    }

    /// One freehand stroke. `points` are unit coordinates in the displayed
    /// mask's frame, TOP-left origin y-down (plain SwiftUI view space, the
    /// same convention as `Position.handlebarTapPoints` — NOT the
    /// bottom-left Vision convention the pose landmarks use).
    ///
    /// `radiusUnit` (AK22) is captured at the zoom the stroke was drawn at,
    /// not read live off the editor's current zoom — so replay is
    /// deterministic and a later zoom change can't retroactively resize an
    /// already-committed stroke.
    struct Stroke: Equatable {
        let brush: Brush
        let points: [CGPoint]
        let radiusUnit: CGFloat

        init(brush: Brush, points: [CGPoint], radiusUnit: CGFloat = MaskCorrection.brushRadiusUnit) {
            self.brush = brush
            self.points = points
            self.radiusUnit = radiusUnit
        }
    }

    /// One undoable correction. `tapFlip`'s point uses the same top-left
    /// unit convention as `Stroke.points`; its radius is the same
    /// zoom-captured value as `Stroke.radiusUnit` (AK22).
    enum Action: Equatable {
        case stroke(Stroke)
        case tapFlip(CGPoint, radiusUnit: CGFloat)
    }

    /// Radius as a fraction of the mask's long edge at 1× zoom, so one
    /// constant covers every stored mask resolution and both orientations.
    /// AK22: both tools bind their radius in *screen* points via
    /// `MaskCorrectionEditor.radiusUnit(atZoom:)`, of which this is the
    /// zoom-1 case — so brush footprint and TAP's flood bound are the same
    /// knob, and existing 1× behaviour is bit-identical.
    static let brushRadiusUnit: CGFloat = 0.03

    struct Result: Equatable {
        let maskPNGData: Data
        let foregroundPixelCount: Int
        let frontalAreaCm2: Double
    }

    // MARK: - Replay

    /// The corrected mask as an image, for preview — same replay the save
    /// path runs, so what the rider sees while editing is literally what
    /// gets measured, not a separate approximation of it.
    static func workingMask(originalMask: CGImage, actions: [Action]) -> CGImage? {
        guard let context = MatteRenderer.editableMaskContext(mask: originalMask) else { return nil }
        apply(actions: actions, to: context)
        return context.makeImage()
    }

    /// Replays `actions` onto `originalMask` and recomputes area at the
    /// scale reconstructed from the original mask/area pair, so the
    /// corrected number shares a ruler with the automated one and differs
    /// only by the pixels the rider added or removed.
    ///
    /// The scale comes from a fresh recount of `originalMask`, never from
    /// the stored `foregroundPixelCount` — that count was taken at full
    /// analysis resolution, while the stored mask has been through
    /// `downscaledMaskPNGData`, so the two don't correspond (the same reason
    /// `AnalysisMath.maskPixelsPerCm(foregroundPixelCount:areaCm2:)` exists
    /// at all).
    ///
    /// Returns nil when there's nothing to measure against: an empty
    /// original mask or a non-positive stored area leaves no derivable
    /// scale.
    static func corrected(originalMask: CGImage, actions: [Action], originalAreaCm2: Double) -> Result? {
        guard originalAreaCm2 > 0,
              let context = MatteRenderer.editableMaskContext(mask: originalMask),
              let buffer = context.data
        else { return nil }

        let width = context.width, height = context.height, bytesPerRow = context.bytesPerRow
        let bytes = buffer.assumingMemoryBound(to: UInt8.self)

        let originalCount = AnalysisMath.countForegroundPixels(
            bytes: bytes, width: width, height: height, bytesPerRow: bytesPerRow
        )
        let maskPixelsPerCm = AnalysisMath.maskPixelsPerCm(
            foregroundPixelCount: originalCount, areaCm2: originalAreaCm2
        )
        guard maskPixelsPerCm > 0 else { return nil }

        apply(actions: actions, to: context)

        let correctedCount = AnalysisMath.countForegroundPixels(
            bytes: bytes, width: width, height: height, bytesPerRow: bytesPerRow
        )
        guard let maskPNGData = MatteRenderer.maskPNGData(from: context) else { return nil }

        return Result(
            maskPNGData: maskPNGData,
            foregroundPixelCount: correctedCount,
            frontalAreaCm2: AnalysisMath.frontalAreaCm2(
                foregroundPixelCount: correctedCount, maskPixelsPerCm: maskPixelsPerCm
            )
        )
    }

    /// `Data`-in convenience over the `CGImage` entry points — what the view
    /// layer actually holds.
    static func corrected(originalMaskData: Data, actions: [Action], originalAreaCm2: Double) -> Result? {
        guard let mask = UIImage(data: originalMaskData)?.cgImage else { return nil }
        return corrected(originalMask: mask, actions: actions, originalAreaCm2: originalAreaCm2)
    }

    static func workingMask(originalMaskData: Data, actions: [Action]) -> CGImage? {
        guard let mask = UIImage(data: originalMaskData)?.cgImage else { return nil }
        return workingMask(originalMask: mask, actions: actions)
    }

    /// In order: a tap reads the buffer state the strokes before it
    /// produced, so replaying out of order would fill a different region.
    private static func apply(actions: [Action], to context: CGContext) {
        for action in actions {
            switch action {
            case .stroke(let stroke):
                draw(stroke: stroke, into: context)
            case .tapFlip(let point, let radiusUnit):
                flipRegion(at: point, radiusUnit: radiusUnit, in: context)
            }
        }
    }

    // MARK: - Brush

    /// Strokes are stored top-left origin y-down; `CGContext` drawing is
    /// y-up, so every point flips here. Fully-opaque white for INCLUDE and
    /// fully-black for EXCLUDE keep the buffer on the same two sides of
    /// `countForegroundPixels`' threshold that segmentation output already
    /// sits on, so a corrected mask has no new intermediate greys to
    /// interpret. `.copy` rather than the default blend for the same reason:
    /// black must actually erase, not composite to a mid grey.
    private static func draw(stroke: Stroke, into context: CGContext) {
        guard !stroke.points.isEmpty else { return }
        let width = CGFloat(context.width), height = CGFloat(context.height)
        let radius = stroke.radiusUnit * max(width, height)
        guard radius > 0 else { return }

        let gray: CGFloat = stroke.brush == .include ? 1 : 0
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(radius * 2)
        context.setBlendMode(.copy)
        context.setStrokeColor(gray: gray, alpha: 1)
        context.setFillColor(gray: gray, alpha: 1)

        let devicePoints = stroke.points.map {
            CGPoint(x: $0.x * width, y: (1 - $0.y) * height)
        }

        // A tap-and-release with the brush is one point, which strokes to
        // nothing — the rider still expects a dab of paint under their finger.
        if devicePoints.count == 1, let point = devicePoints.first {
            context.fillEllipse(in: CGRect(
                x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2
            ))
            return
        }

        context.beginPath()
        context.addLines(between: devicePoints)
        context.strokePath()
    }

    // MARK: - Tap flood-fill

    /// Flips the contiguous same-state region touching `point`, bounded to a
    /// disc of `radiusUnit` (AK22) — a mis-included background blob out, a
    /// mis-excluded limb in, in one action, without the unbounded flood
    /// reaching the far side of the frame. Foreground/background is decided
    /// by the same threshold `countForegroundPixels` measures with, so what
    /// the fill treats as one region is exactly what the area math treats as
    /// one region.
    ///
    /// Writes straight into the bitmap rather than going through `CGContext`
    /// drawing, so this is the one edit that reads the buffer in its own
    /// row order: bitmap-context memory is stored TOP row first, while
    /// `CGContext` drawing coordinates are y-up — hence no `1 -` flip here
    /// and one in `draw(stroke:)`.
    private static func flipRegion(at point: CGPoint, radiusUnit: CGFloat, in context: CGContext) {
        guard let buffer = context.data else { return }
        let width = context.width, height = context.height, bytesPerRow = context.bytesPerRow
        let bytes = buffer.assumingMemoryBound(to: UInt8.self)

        let seedX = Int((point.x * CGFloat(width)).rounded(.down))
        let seedY = Int((point.y * CGFloat(height)).rounded(.down))
        guard seedX >= 0, seedX < width, seedY >= 0, seedY < height else { return }

        let radius = radiusUnit * CGFloat(max(width, height))
        let region = connectedRegion(
            bytes: bytes, width: width, height: height, bytesPerRow: bytesPerRow,
            seedX: seedX, seedY: seedY, radius: radius
        )
        let seedIsForeground = bytes[seedY * bytesPerRow + seedX] >= foregroundThreshold
        let flipped: UInt8 = seedIsForeground ? 0 : 255
        for offset in region {
            bytes[offset] = flipped
        }
    }

    /// Matches `AnalysisMath.countForegroundPixels`' default — named here so
    /// the fill and the count can't drift apart silently.
    static let foregroundThreshold: UInt8 = 128

    /// Every buffer offset 4-connected to the seed, on the same side of
    /// `threshold` as it, and within `radius` pixels of the seed (AK22;
    /// `.infinity` — the default — is the pre-AK22 unbounded walk, which the
    /// existing structural tests below still exercise directly). Offsets
    /// (not x/y pairs) because they're what the caller writes through, and
    /// because striding by `bytesPerRow` rather than `width` is the whole
    /// point — a padded row would otherwise let the fill leak from the end
    /// of one row into the start of the next.
    ///
    /// Iterative, with an explicit stack: a recursive fill blows the stack
    /// on a full-height rider silhouette at stored mask resolution.
    static func connectedRegion(
        bytes: UnsafePointer<UInt8>, width: Int, height: Int, bytesPerRow: Int,
        seedX: Int, seedY: Int, threshold: UInt8 = foregroundThreshold, radius: CGFloat = .infinity
    ) -> [Int] {
        guard seedX >= 0, seedX < width, seedY >= 0, seedY < height else { return [] }
        let seedIsForeground = bytes[seedY * bytesPerRow + seedX] >= threshold
        let radiusSquared = radius * radius

        var visited = [Bool](repeating: false, count: width * height)
        var stack = [(x: Int, y: Int)]()
        var region = [Int]()
        stack.append((seedX, seedY))
        visited[seedY * width + seedX] = true

        while let (x, y) = stack.popLast() {
            region.append(y * bytesPerRow + x)
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] {
                guard nx >= 0, nx < width, ny >= 0, ny < height, !visited[ny * width + nx] else { continue }
                guard (bytes[ny * bytesPerRow + nx] >= threshold) == seedIsForeground else { continue }
                if radius.isFinite {
                    let dx = CGFloat(nx - seedX), dy = CGFloat(ny - seedY)
                    guard dx * dx + dy * dy <= radiusSquared else { continue }
                }
                visited[ny * width + nx] = true
                stack.append((nx, ny))
            }
        }
        return region
    }
}
#endif
