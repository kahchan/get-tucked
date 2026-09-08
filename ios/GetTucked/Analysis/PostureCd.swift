import Foundation

/// Plan AN — posture bin classification only. No Cd ratio, no spread: AN1
/// (literature ingest, `plans/plan-an-posture-cd.md`) hasn't run, so there is
/// nothing to quantify yet, only a name for the bin. Deliberately not read by
/// `EffortModel` — the one-way dependency is the guarantee the estimate can't
/// drift into using these numbers by accident.
enum PostureBin: String {
    case upright
    case tucked
    case aero
}

enum PostureCd {
    // ponytail: boundaries are placeholders, not literature-derived — AN1
    // (plans/plan-an-posture-cd.md) is the gate. Replace with AN1's own
    // position-label boundaries before any numeric Cd ratio ships; until
    // then this only names a bin, it doesn't quantify one.
    private static let uprightUpperBoundDeg = 25.0
    private static let tuckedUpperBoundDeg = 55.0

    /// `torsoDeg` uses `AnalysisMath.torsoAngleDeg`'s convention — from
    /// vertical, 0° upright, 90° horizontal.
    static func bin(torsoDeg: Double) -> PostureBin {
        if torsoDeg < uprightUpperBoundDeg { return .upright }
        if torsoDeg < tuckedUpperBoundDeg { return .tucked }
        return .aero
    }
}
