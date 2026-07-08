import CoreGraphics
import Foundation

/// Pure, deterministic geometry for frontal-area and posture computation.
/// Extracted from `AnalysisEngine` so the math can be unit-tested without Vision
/// (which needs a real person image and can't be exercised deterministically).
enum AnalysisMath {
    /// Uncertainty is modelled as a fixed fraction of the computed area,
    /// reflecting segmentation + scale noise.
    static let uncertaintyFraction = 0.03

    // MARK: - Scale

    /// Pixel distance between two handlebar taps given in unit coords (0–1).
    static func handlebarPixels(tap0: CGPoint, tap1: CGPoint, imageSize: CGSize) -> Double {
        let p0 = CGPoint(x: tap0.x * imageSize.width, y: tap0.y * imageSize.height)
        let p1 = CGPoint(x: tap1.x * imageSize.width, y: tap1.y * imageSize.height)
        return Double(hypot(p1.x - p0.x, p1.y - p0.y))
    }

    /// Source-image pixels per cm, from a known handlebar width.
    static func pixelsPerCm(handlebarPixels: Double, handlebarWidthMm: Double) -> Double {
        handlebarPixels / (handlebarWidthMm / 10.0)
    }

    /// The segmentation mask resolution differs from the source in general.
    /// Rescale source pixels/cm into mask pixel space so area and scale share units.
    static func maskPixelsPerCm(sourcePixelsPerCm: Double, maskWidth: Int, sourceWidth: Int) -> Double {
        sourcePixelsPerCm * (Double(maskWidth) / Double(sourceWidth))
    }

    /// `maskPixelsPerCm` rescales by width ratio only, which is correct only
    /// if the mask preserves the source's aspect ratio. True for Vision's
    /// person segmentation in practice, but unverified in general — this
    /// predicate lets callers check rather than assume (Plan I5/H5).
    static func maskMatchesSourceAspect(
        maskWidth: Int, maskHeight: Int, sourceWidth: Int, sourceHeight: Int, tolerance: Double = 0.02
    ) -> Bool {
        guard maskHeight > 0, sourceHeight > 0 else { return false }
        let maskAspect = Double(maskWidth) / Double(maskHeight)
        let sourceAspect = Double(sourceWidth) / Double(sourceHeight)
        return abs(maskAspect - sourceAspect) / sourceAspect <= tolerance
    }

    // MARK: - Area

    /// Frontal area in cm² from a foreground pixel count and the mask-space scale.
    static func frontalAreaCm2(foregroundPixelCount: Int, maskPixelsPerCm: Double) -> Double {
        Double(foregroundPixelCount) / (maskPixelsPerCm * maskPixelsPerCm)
    }

    /// Counts pixels ≥ threshold in a row-major 8-bit buffer, striding by
    /// `bytesPerRow` rather than scanning the buffer linearly. Pixel buffers
    /// are commonly padded to an alignment boundary, so `bytesPerRow` can
    /// exceed `width` — a linear scan over the raw byte count then reads that
    /// trailing padding as if it were pixels. That padding is uninitialised
    /// memory, not zero, so it silently inflates the count.
    static func countForegroundPixels(
        bytes: UnsafePointer<UInt8>, width: Int, height: Int, bytesPerRow: Int, threshold: UInt8 = 128
    ) -> Int {
        var count = 0
        for y in 0 ..< height {
            let row = y * bytesPerRow
            for x in 0 ..< width where bytes[row + x] >= threshold {
                count += 1
            }
        }
        return count
    }

    static func uncertaintyCm2(areaCm2: Double) -> Double {
        areaCm2 * uncertaintyFraction
    }

    /// Single ± cm² voice shared by every screen that shows uncertainty
    /// (RevealStep, PositionDetailView, …) so the same quantity never reads
    /// as two different numbers depending on where it's displayed.
    static func uncertaintyDisplay(_ cm2: Double) -> String {
        "±\(Int(cm2.rounded())) cm²"
    }

    // MARK: - Noise floor

    /// Two independent measurements' uncertainties combine in quadrature, not
    /// by simple addition — the standard rule for combining independent errors.
    static func combinedNoiseCm2(uncertaintyA: Double, uncertaintyB: Double) -> Double {
        (uncertaintyA * uncertaintyA + uncertaintyB * uncertaintyB).squareRoot()
    }

    /// A delta smaller than the combined noise floor can't be told apart from
    /// measurement jitter — the spec's "single most important honesty feature".
    static func isDistinguishable(
        areaA: Double, areaB: Double, uncertaintyA: Double, uncertaintyB: Double
    ) -> Bool {
        abs(areaB - areaA) > combinedNoiseCm2(uncertaintyA: uncertaintyA, uncertaintyB: uncertaintyB)
    }

    // MARK: - Pose geometry (inputs are normalised landmark points, origin bottom-left)

    static func shoulderWidthCm(
        leftShoulderX: Double, rightShoulderX: Double,
        imageWidthPx: Int, pixelsPerCm: Double
    ) -> Double {
        let widthPx = abs(leftShoulderX - rightShoulderX) * Double(imageWidthPx)
        return widthPx / pixelsPerCm
    }

    /// A human shoulder width outside this range means the scale is probably
    /// mis-tapped (or the bike's bar width is wrong), not that the rider is
    /// genuinely that narrow/wide.
    static func isShoulderWidthPlausible(_ cm: Double) -> Bool {
        (30...60).contains(cm)
    }

    /// Copy shown when a computed shoulder width falls outside the plausible
    /// range — shared by the reveal (from a live AnalysisResult) and the
    /// detail screen (recomputed from a stored position) so the two never
    /// drift apart (Plan I4).
    static func shoulderWidthWarning(_ cm: Double) -> String? {
        guard !isShoulderWidthPlausible(cm) else { return nil }
        return "Shoulder width reads \(Int(cm.rounded())) cm — check your taps and the bike's bar width."
    }

    /// Angle of the (shoulder − hip) vector from vertical. 0° = upright, 90° = horizontal.
    static func torsoAngleDeg(shoulder: CGPoint, hip: CGPoint) -> Double {
        let dx = Double(shoulder.x - hip.x)
        let dy = Double(shoulder.y - hip.y)
        return abs(atan2(dx, dy) * 180 / .pi)
    }

    /// Interior angle at the hip between torso (hip→shoulder) and thigh (hip→knee).
    static func hipAngleDeg(shoulder: CGPoint, hip: CGPoint, knee: CGPoint) -> Double {
        let sx = Double(shoulder.x - hip.x), sy = Double(shoulder.y - hip.y)
        let kx = Double(knee.x - hip.x), ky = Double(knee.y - hip.y)
        let dot = sx * kx + sy * ky
        let magA = (sx * sx + sy * sy).squareRoot()
        let magB = (kx * kx + ky * ky).squareRoot()
        guard magA > 0, magB > 0 else { return 0 }
        let cosine = max(-1.0, min(1.0, dot / (magA * magB)))
        return acos(cosine) * 180 / .pi
    }

    /// Vertical distance the ear sits below the shoulder, in cm (positive = lower).
    static func headDropCm(
        shoulderY: Double, earY: Double,
        imageHeightPx: Int, pixelsPerCm: Double
    ) -> Double {
        (shoulderY - earY) * Double(imageHeightPx) / pixelsPerCm
    }

    // MARK: - 3D pose geometry (Plan A6 — DEBUG comparison only; inputs are
    // Vision's root-relative joint positions in metres, (x, y, z) tuples
    // rather than `simd_float4x4` so this stays a pure, framework-light,
    // testable function. Assumes Vision's Y-axis is "up" — verify against a
    // known-upright photo before trusting the number; not wired into the
    // shipping pipeline until that verdict lands.)

    /// 3D analogue of `torsoAngleDeg`: angle of the (shoulder − hip) vector
    /// from vertical, using the full 3D lean (not just the image-plane
    /// projection) — so unlike the 2D version, this is unaffected by camera yaw.
    static func torsoAngleDeg3D(shoulder: (x: Double, y: Double, z: Double),
                                 hip: (x: Double, y: Double, z: Double)) -> Double {
        let dx = shoulder.x - hip.x
        let dy = shoulder.y - hip.y
        let dz = shoulder.z - hip.z
        let horizontal = (dx * dx + dz * dz).squareRoot()
        return abs(atan2(horizontal, dy) * 180 / .pi)
    }

    /// 3D analogue of `hipAngleDeg`: interior angle at the hip between torso
    /// (hip→shoulder) and thigh (hip→knee), generalised from 2D to 3D vectors.
    static func hipAngleDeg3D(shoulder: (x: Double, y: Double, z: Double),
                               hip: (x: Double, y: Double, z: Double),
                               knee: (x: Double, y: Double, z: Double)) -> Double {
        let sx = shoulder.x - hip.x, sy = shoulder.y - hip.y, sz = shoulder.z - hip.z
        let kx = knee.x - hip.x, ky = knee.y - hip.y, kz = knee.z - hip.z
        let dot = sx * kx + sy * ky + sz * kz
        let magA = (sx * sx + sy * sy + sz * sz).squareRoot()
        let magB = (kx * kx + ky * ky + kz * kz).squareRoot()
        guard magA > 0, magB > 0 else { return 0 }
        let cosine = max(-1.0, min(1.0, dot / (magA * magB)))
        return acos(cosine) * 180 / .pi
    }
}
