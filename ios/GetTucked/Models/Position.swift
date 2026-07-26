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

    // Raw person-segmentation mask (grayscale PNG) — stored untinted so a
    // future accent/opacity change never leaves old positions with a stale
    // baked-in tint. Pre-Plan-W this drove frontalAreaCm2 directly; now it's
    // the colour-splitter for the two-tone matte (rider = subjectMaskData ∩
    // maskData) and the area/outline fallback when subjectMaskData is nil
    // (old positions, or a capture where subject-lifting failed).
    var maskData: Data?

    // Subject-lift matte (Plan W2, SchemaV7) — rider+bike+bags as one
    // instance-connected union (VNGenerateForegroundInstanceMaskRequest),
    // downscaled PNG like maskData. Drives frontalAreaCm2 and the ghost/
    // outline consumers when present; nil for positions captured before
    // Plan W2 (subject-lifting unavailable then) or when subject-lifting
    // failed on this capture — both degrade to maskData/person-only exactly
    // as before, single-tone, numbers unchanged.
    var subjectMaskData: Data?

    // Side-on segmentation mask (Plan O), untinted grayscale PNG — mirrors
    // maskData's storage and tint-at-display-time rationale. Presentational
    // only: side-on posture metrics never depended on segmentation, so a
    // nil value here just means the skeleton (if any) draws over the bare
    // photo instead of a matte.
    var sideOnMaskData: Data?

    // Side-on subject-lift matte (Plan AH, SchemaV8) — rider+bike+bags as
    // one instance-connected union, mirroring subjectMaskData's role for the
    // frontal side. Drives the side-on matte's subject-preferred/person-
    // fallback rendering (PositionDetailView.buildMaskOverlay) when present;
    // nil for positions captured before Plan AH or when subject-lifting
    // failed on this capture, both of which degrade to sideOnMaskData/
    // person-only exactly as before. Presentational only (Plan O) — never
    // feeds frontalAreaCm2 or any other number.
    var sideOnSubjectMaskData: Data?

    // Head-on photo asset identifier (PHAsset local ID)
    var headOnPhotoIdentifier: String?

    // Side-on photo asset identifier — populated after Phase 2.5 side-on capture
    var sideOnPhotoIdentifier: String?

    // Side-on photo bytes — populated for live captures (Plan G0), which have
    // no PHAsset identifier, mirroring photosData's head-on handling. Without
    // this a live side-on shot computes posture metrics whose source photo
    // is unviewable forever, and the FRONTAL/SIDE-ON toggle never appears.
    var sideOnPhotoData: Data?

    // Scale calibration: two tap points in unit coordinates (0–1),
    // TOP-left origin, y-down — stored as [x0, y0, x1, y1]. Comes from
    // `CalibrationTransform.unitPoint(forScreen:in:)` (plain screen space,
    // no flip) — NOT the same convention as the Vision-bottom-left pose
    // landmarks on `PositionMetrics` (see that file's fields for the
    // Plan Z1 note on why this distinction matters).
    var handlebarTapPoints: [Double]?

    // Side-on scale calibration (Plan P1.5) — the two wheelbase tap points
    // (front axle, rear axle) in unit coords, mirroring handlebarTapPoints'
    // storage convention. nil when the rider skipped the ruler (or the bike
    // has no wheelbase on record); kept for audit/re-display, not reprocessed.
    var sideOnTapPoints: [Double]?

    // Optional wheel-ruler verification taps (Plan K3) — [groundX, groundY,
    // topX, topY], unit coords, same storage convention. nil unless the
    // rider did the optional wheel check. The ground point doubles as the
    // ghost-compare overlay's Y anchor (a stable physical reference) when
    // present; the top point is kept alongside it for the same
    // audit/consistency reason sideOnTapPoints keeps its pair.
    var wheelTapPoints: [Double]?

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
