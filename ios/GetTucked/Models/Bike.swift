import Foundation
import SwiftData

enum BikeType: String, Codable, CaseIterable {
    case road = "ROAD"
    case gravel = "GRAVEL"
    case mtb = "MTB"

    var displayName: String { rawValue }
}

/// Common rim sizes, mapped to their standardised ISO bead-seat diameter —
/// the fixed part of "wheel diameter" that combines with tire width to
/// approximate the tire's overall (inflated) diameter (Plan K1).
enum RimStandard: String, Codable, CaseIterable {
    case c700 = "700C"
    case b650 = "650B"
    case in26 = "26\""
    case in275 = "27.5\""
    case in29 = "29\""

    var displayName: String { rawValue }

    var beadSeatDiameterMm: Double {
        switch self {
        case .c700: 622
        case .b650: 584
        case .in26: 559
        case .in275: 584
        case .in29: 622
        }
    }
}

@Model
final class Bike {
    var id: UUID
    var nickname: String
    var handlebarWidthMm: Double
    var bikeType: BikeType
    // Optional cross-scale verification metadata (Plan K1). None of these
    // gate capture — they exist to catch a mis-entered handlebarWidthMm.
    var rimStandard: RimStandard?
    var tireWidthMm: Double?
    // Side-on ruler candidate (Plan G decision 4) — was `wheelbaseCm`, never
    // populated anywhere, renamed to match the mm convention every other
    // dimension on this model uses (handlebarWidthMm, tireWidthMm).
    var wheelbaseMm: Double?
    var notes: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Position.bike)
    var positions: [Position]

    init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
        self.id = UUID()
        self.nickname = nickname
        self.handlebarWidthMm = handlebarWidthMm
        self.bikeType = bikeType
        self.createdAt = Date()
        self.positions = []
    }

    var handlebarWidthCm: Double { handlebarWidthMm / 10.0 }

    /// nil unless both rim standard and tire width are set — the wheel
    /// check is skipped entirely (not offered) rather than guessing.
    var wheelDiameterMm: Double? {
        guard let rimStandard, let tireWidthMm else { return nil }
        return AnalysisMath.overallWheelDiameterMm(beadSeatMm: rimStandard.beadSeatDiameterMm, tireWidthMm: tireWidthMm)
    }

    /// Shared by `BikeSetupView` and the capture-time bike picker's inline add form.
    static func isValidInput(nickname: String, handlebarWidthText: String) -> Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty && (Double(handlebarWidthText) ?? 0) > 0
    }
}
