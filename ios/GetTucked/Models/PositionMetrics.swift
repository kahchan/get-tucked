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

    // Side-on pose (populated after Phase 2.5 side-on capture + analysis)
    // torsoAngleDeg: angle of shoulder→hip vector from vertical, 0° = upright, 90° = horizontal
    var torsoAngleDeg: Double?
    // hipAngleDeg: interior angle at hip between torso line and thigh line
    var hipAngleDeg: Double?
    // headDropCm: vertical distance ear is below shoulder (positive = lower than shoulder)
    var headDropCm: Double?

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
