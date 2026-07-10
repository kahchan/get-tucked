import Foundation
import SwiftData

@Model
final class PositionMetrics {
    // Head-on frontal area (always populated after Phase 1 analysis)
    var frontalAreaCm2: Double
    var frontalAreaUncertainty: Double
    var pixelsPerCm: Double
    var foregroundPixelCount: Int
    var computedAt: Date
    var pipelineVersion: String

    // Head-on pose (populated after Phase 2.4 pose estimation on head-on frame)
    var shoulderWidthCm: Double?

    // The bike's handlebar width at the moment this position was analysed —
    // not a live read of Bike.handlebarWidthMm, which the user can edit later
    // and would otherwise silently orphan this number's ruler (Plan I3).
    var handlebarWidthMmUsed: Double?

    // Wheel-ruler verification (Plan K) — nil unless the optional wheel taps
    // were completed. Stores the raw disagreement fraction, not a formatted
    // string, so the agree/disagree copy recomputes at display time (same
    // pattern as shoulderWidthWarning).
    var wheelCheckDisagreementFraction: Double?

    // Side-on pose (populated after Phase 2.5 side-on capture + analysis)
    // torsoAngleDeg: angle of shoulder→hip vector from vertical, 0° = upright, 90° = horizontal
    var torsoAngleDeg: Double?
    // hipAngleDeg: interior angle at hip between torso line and thigh line
    var hipAngleDeg: Double?
    // headDropCm: vertical distance ear is below shoulder (positive = lower than shoulder)
    var headDropCm: Double?

    // Pose landmarks (Plan O) — the exact points the angle/width math above
    // consumed, persisted so the skeleton overlay replays what produced the
    // numbers rather than re-estimating (and possibly disagreeing with them).
    // Flattened [x0, y0, x1, y1, ...], Vision-normalised coords (0–1, origin
    // bottom-left) — same convention as handlebarTapPoints.
    //
    // headOnSkeletonPoints: [leftShoulderX, leftShoulderY, rightShoulderX, rightShoulderY]
    var headOnSkeletonPoints: [Double]?
    // headOnArmPoints: [leftElbowX, leftElbowY, leftWristX, leftWristY,
    // rightElbowX, rightElbowY, rightWristX, rightWristY]. Separate from
    // headOnSkeletonPoints (not appended) because arms are optional context,
    // not a measurement: all four joints must clear the confidence floor or
    // this stays nil — a one-armed skeleton reads as broken, so arms are
    // symmetric-or-nothing while shoulders stay independently required.
    var headOnArmPoints: [Double]?
    // sideOnSkeletonPoints: [shoulderX, shoulderY, hipX, hipY, kneeX, kneeY, earX, earY]
    var sideOnSkeletonPoints: [Double]?

    init(
        frontalAreaCm2: Double,
        frontalAreaUncertainty: Double,
        pixelsPerCm: Double,
        foregroundPixelCount: Int
    ) {
        self.frontalAreaCm2 = frontalAreaCm2
        self.frontalAreaUncertainty = frontalAreaUncertainty
        self.pixelsPerCm = pixelsPerCm
        self.foregroundPixelCount = foregroundPixelCount
        self.computedAt = Date()
        self.pipelineVersion = "2.0"
    }
}
