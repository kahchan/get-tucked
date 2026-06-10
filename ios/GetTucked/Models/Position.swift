import Foundation
import SwiftData

@Model
final class Position {
    var id: UUID
    var capturedAt: Date
    var label: String
    var packingList: String?

    var bike: Bike?

    // Stored as Data (compact PNG) rather than a separate @Model,
    // since PhotoRef has no identity outside its Position.
    var photosData: Data?

    // Head-on photo asset identifier (PHAsset local ID)
    var headOnPhotoIdentifier: String?

    // Scale calibration: two tap points in unit coordinates (0–1)
    // stored as [x0, y0, x1, y1]
    var handlebarTapPoints: [Double]?

    @Relationship(deleteRule: .cascade)
    var metrics: PositionMetrics?

    var isBaseline: Bool

    init(label: String, bike: Bike?) {
        self.id = UUID()
        self.capturedAt = Date()
        self.label = label
        self.bike = bike
        self.isBaseline = false
    }
}
