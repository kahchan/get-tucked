import Foundation
import SwiftData

/// Which unit system positions display in. Ships metric-only (Plan AL5) —
/// the field exists so a future picker doesn't need another schema bump,
/// but no UI writes anything other than `.metric` today.
enum PreferredUnits: String, Codable {
    case metric = "METRIC"
}

/// Single-row app-wide settings (Plan AL5, SchemaV9) — spec §6. Fetched-or-
/// created once at launch (`GetTuckedApp.swift`); every other call site
/// reads the one row via `@Query`, never inserts a second.
@Model
final class UserSettings {
    // Measured noise floor (spec §8/§9) — nil until a D2-gated feature
    // (AL6/AL10, not yet built) populates it. `AnalysisMath.uncertaintyCm2`
    // stays on the hardcoded 0.03 fallback until this is real (AL2).
    var noiseFloorPct: Double?
    var noiseFloorLastCalibrated: Date?

    var preferredUnits: PreferredUnits

    var hasCompletedOnboarding: Bool

    // Set by the one-time consent reminder before first capture (Plan AL7).
    var consentToCaptureOthers: Bool

    init() {
        self.preferredUnits = .metric
        self.hasCompletedOnboarding = false
        self.consentToCaptureOthers = false
    }

    /// Fetch the single settings row, inserting one on first launch — called
    /// once from `GetTuckedApp` at container build time. Every other call
    /// site reads the row via `@Query` instead of calling this again.
    @discardableResult
    static func fetchOrCreate(in context: ModelContext) -> UserSettings {
        if let existing = try? context.fetch(FetchDescriptor<UserSettings>()).first {
            return existing
        }
        let settings = UserSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }
}
