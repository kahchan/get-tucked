import CoreGraphics

/// Which quadrant of physical rotation the device is currently held in —
/// drives both the camera's `videoRotationAngle` and LEVEL's zero-point
/// (Plan L4). Forced to `.portrait` whenever `OrientationLock.allowsLandscape`
/// is false, so head-on's behaviour never changes regardless of how the
/// phone is physically held.
enum OrientationBucket: Equatable {
    case portrait
    case landscapeLeft
    case landscapeRight

    /// Reference roll angle (`atan2(g.x, -g.y)`, degrees) that reads as
    /// "level" in this bucket — LEVEL's zero-point.
    var referenceRollDeg: Double {
        switch self {
        case .portrait: 0
        case .landscapeLeft: -90
        case .landscapeRight: 90
        }
    }

    /// `AVCaptureConnection.videoRotationAngle` for the back camera held
    /// this way. The landscapeLeft/Right assignments are the standard back-
    /// camera mapping but are exactly the kind of thing only a device pass
    /// can confirm — if a captured landscape photo comes out upside-down,
    /// swap these two.
    var videoRotationAngle: CGFloat {
        switch self {
        case .portrait: 90
        case .landscapeLeft: 0
        case .landscapeRight: 180
        }
    }

    /// Picks the bucket from raw gravity, preferring to stay in `current`
    /// unless the other axis now clearly dominates (ratio ≥
    /// `hysteresisRatio`, ≈ deviation past ~50°) — plain nearest-bucket
    /// selection flaps between portrait and landscape right at the 45°
    /// diagonal as gravity readings jitter.
    static func pick(
        gravityX: Double, gravityY: Double, current: OrientationBucket, hysteresisRatio: Double = 1.2
    ) -> OrientationBucket {
        let absX = abs(gravityX)
        let absY = abs(gravityY)
        let stayPortrait: Bool
        if current == .portrait {
            // Currently portrait: only leave it if X now clearly dominates.
            stayPortrait = !(absX > absY * hysteresisRatio)
        } else {
            // Currently landscape: only enter portrait if Y now clearly dominates.
            stayPortrait = absY > absX * hysteresisRatio
        }
        if stayPortrait { return .portrait }
        return gravityX < 0 ? .landscapeLeft : .landscapeRight
    }
}
