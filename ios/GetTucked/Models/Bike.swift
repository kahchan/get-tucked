import Foundation
import SwiftData

enum BikeType: String, Codable, CaseIterable {
    case road = "ROAD"
    case gravel = "GRAVEL"
    case mtb = "MTB"

    var displayName: String { rawValue }
}

/// Which convention the handlebar-width tap-calibration measures against
/// (Plan S1). Drop bars are quoted center-to-center at the hoods but the
/// drop ends — the easiest points to tap in a front-on photo — are 20-60mm
/// wider, so entering the quoted width and tapping the drops silently
/// inflates px/cm and understates area. Flat bars have no such gap.
enum BarType: String, Codable, CaseIterable {
    case drop = "DROP"
    case flat = "FLAT"

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

    /// Road/gravel tires are labelled in mm off the sidewall (e.g. "700x40c");
    /// mountain-bike tires in inches (e.g. "27.5x2.35") — the tire-width field
    /// should read in whichever unit riders actually see on the tire.
    var tireWidthUnit: TireWidthUnit {
        switch self {
        case .c700, .b650: .mm
        case .in26, .in275, .in29: .inches
        }
    }
}

enum TireWidthUnit: Equatable {
    case mm
    case inches

    var fieldLabel: String {
        switch self {
        case .mm: "TIRE WIDTH (MM)"
        case .inches: "TIRE WIDTH (IN)"
        }
    }

    var placeholder: String {
        switch self {
        case .mm: "40"
        case .inches: "2.1"
        }
    }
}

@Model
final class Bike {
    var id: UUID
    var nickname: String
    var handlebarWidthMm: Double
    var bikeType: BikeType
    // nil means never explicitly set — either the bike predates this field
    // (Plan S1) or was created without touching the picker's default.
    // `effectiveBarType` below is the display/behaviour fallback; setting
    // this explicitly (picker or the one-time existing-data caveat) is what
    // permanently dismisses that caveat.
    var barType: BarType?
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

    /// Falls back to bikeType when barType was never explicitly set —
    /// mtb infers flat, road/gravel infer drop (Plan S1).
    var effectiveBarType: BarType { barType ?? (bikeType == .mtb ? .flat : .drop) }

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

    /// "640 mm bars · 1010 mm wheelbase · 622 mm wheel" — the hard points
    /// that become a position's new ruler on a swap (Plan Y2), so the
    /// picker's row shows the numbers the choice is actually made against
    /// rather than just a nickname. Wheelbase/wheel segments are omitted
    /// when not on record, same degrade-gracefully posture as everywhere
    /// else optional hard points are displayed.
    var hardPointsSummary: String {
        var parts = ["\(Int(handlebarWidthMm)) mm bars"]
        if let wheelbaseMm { parts.append("\(Int(wheelbaseMm)) mm wheelbase") }
        if let wheelDiameterMm { parts.append("\(Int(wheelDiameterMm)) mm wheel") }
        return parts.joined(separator: " · ")
    }
}
