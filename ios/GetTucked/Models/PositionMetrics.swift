import Foundation
import SwiftData

@Model
final class PositionMetrics {
    var frontalAreaCm2: Double
    var frontalAreaUncertainty: Double
    var pixelsPerCm: Double
    var foregroundPixelCount: Int
    var computedAt: Date
    var pipelineVersion: String

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
        self.pipelineVersion = "1.0"
    }
}
