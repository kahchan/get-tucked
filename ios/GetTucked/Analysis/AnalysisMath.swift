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

    // MARK: - Area

    /// Frontal area in cm² from a foreground pixel count and the mask-space scale.
    static func frontalAreaCm2(foregroundPixelCount: Int, maskPixelsPerCm: Double) -> Double {
        Double(foregroundPixelCount) / (maskPixelsPerCm * maskPixelsPerCm)
    }

    static func uncertaintyCm2(areaCm2: Double) -> Double {
        areaCm2 * uncertaintyFraction
    }

    // MARK: - Pose geometry (inputs are normalised landmark points, origin bottom-left)

    static func shoulderWidthCm(
        leftShoulderX: Double, rightShoulderX: Double,
        imageWidthPx: Int, pixelsPerCm: Double
    ) -> Double {
        let widthPx = abs(leftShoulderX - rightShoulderX) * Double(imageWidthPx)
        return widthPx / pixelsPerCm
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
}
