import CoreGraphics
import Foundation

/// Wrong-bike swap-and-rescale (Plan Y2) — the `Position`/`Bike`-touching
/// wrapper around `AnalysisMath.rescaledMetrics` (Y1). This is a SWAP, not a
/// bike edit: editing a bike's bar width and retro-rescaling its positions
/// is explicitly out of scope (v1 decision, 2026-07-18).
enum BikeSwap {
    /// The affordance only appears with at least one other bike to swap to
    /// (Plan Y2/Y3) — otherwise there's nothing to pick from.
    static func isAvailable(otherBikesCount: Int) -> Bool {
        otherBikesCount > 0
    }

    /// Every bike except the position's current one, in whatever order
    /// `allBikes` arrives in.
    static func otherBikes(allBikes: [Bike], excluding currentBike: Bike?) -> [Bike] {
        allBikes.filter { $0.id != currentBike?.id }
    }

    /// Confirm-state copy: "Rescales this position using BIKE B's 640 mm bars".
    static func confirmMessage(newBike: Bike) -> String {
        "Rescales this position using \(newBike.nickname)'s \(Int(newBike.handlebarWidthMm)) mm bars"
    }

    /// nil unless the swap would actually drop side-on numbers — the amber
    /// warning shown in the confirm state BEFORE the swap applies (Plan Y2):
    /// the position has a real wheelbase-ruler scale today, and the new bike
    /// has no wheelbase on record to replace it with.
    static func noWheelbaseWarning(position: Position, newBike: Bike) -> String? {
        guard position.metrics?.sideOnPixelsPerCm != nil, newBike.wheelbaseMm == nil else { return nil }
        return "Side-on numbers will be removed — \(newBike.nickname) has no wheelbase on record."
    }

    /// Applies Y1's closed-form rescale to `position`'s metrics and
    /// reassigns it to `newBike` — relationship reassignment and field
    /// mutation only, no re-analysis, no schema change. Returns `false` and
    /// leaves everything untouched when there's nothing to rescale from: no
    /// metrics, or a position captured before Plan I3 has no
    /// `handlebarWidthMmUsed` provenance to derive a ratio against.
    @discardableResult
    static func apply(to position: Position, newBike: Bike, imageAspect: CGSize) -> Bool {
        guard let metrics = position.metrics, let oldBarMm = metrics.handlebarWidthMmUsed else { return false }
        let oldBike = position.bike

        let input = AnalysisMath.BikeSwapInput(
            pixelsPerCm: metrics.pixelsPerCm,
            frontalAreaCm2: metrics.frontalAreaCm2,
            frontalAreaUncertainty: metrics.frontalAreaUncertainty,
            shoulderWidthCm: metrics.shoulderWidthCm,
            sideOnPixelsPerCm: metrics.sideOnPixelsPerCm,
            headDropCm: metrics.headDropCm,
            wheelTapPoints: position.wheelTapPoints,
            imageAspect: imageAspect,
            oldHandlebarWidthMm: oldBarMm,
            newHandlebarWidthMm: newBike.handlebarWidthMm,
            oldWheelbaseMm: oldBike?.wheelbaseMm,
            newWheelbaseMm: newBike.wheelbaseMm,
            newWheelDiameterMm: newBike.wheelDiameterMm
        )
        let result = AnalysisMath.rescaledMetrics(input)

        metrics.pixelsPerCm = result.pixelsPerCm
        metrics.frontalAreaCm2 = result.frontalAreaCm2
        metrics.frontalAreaUncertainty = result.frontalAreaUncertainty
        metrics.shoulderWidthCm = result.shoulderWidthCm
        metrics.wheelCheckDisagreementFraction = result.wheelCheckDisagreementFraction
        metrics.sideOnPixelsPerCm = result.sideOnPixelsPerCm
        metrics.headDropCm = result.headDropCm
        metrics.handlebarWidthMmUsed = result.handlebarWidthMmUsed
        // Provenance row on the compare screen then discloses the re-run
        // (Plan Y doc).
        metrics.computedAt = Date()

        position.bike = newBike
        return true
    }
}
