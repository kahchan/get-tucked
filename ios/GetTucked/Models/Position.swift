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

    // Raw segmentation mask (grayscale PNG) that produced frontalAreaCm2 —
    // stored untinted so a future accent/opacity change never leaves old
    // positions with a stale baked-in tint.
    var maskData: Data?

    // Side-on segmentation mask (Plan O), untinted grayscale PNG — mirrors
    // maskData's storage and tint-at-display-time rationale. Presentational
    // only: side-on posture metrics never depended on segmentation, so a
    // nil value here just means the skeleton (if any) draws over the bare
    // photo instead of a matte.
    var sideOnMaskData: Data?

    // Head-on photo asset identifier (PHAsset local ID)
    var headOnPhotoIdentifier: String?

    // Side-on photo asset identifier — populated after Phase 2.5 side-on capture
    var sideOnPhotoIdentifier: String?

    // Side-on photo bytes — populated for live captures (Plan G0), which have
    // no PHAsset identifier, mirroring photosData's head-on handling. Without
    // this a live side-on shot computes posture metrics whose source photo
    // is unviewable forever, and the FRONTAL/SIDE-ON toggle never appears.
    var sideOnPhotoData: Data?

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
