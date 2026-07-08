import UIKit

/// Whether the interface is currently allowed to rotate into landscape —
/// true only while `CaptureView` is on the side-on step (Plan L). Every
/// other screen stays portrait-only even if this is ever left in a bad
/// state, since `AppDelegate` defaults to portrait whenever it's false.
enum OrientationLock {
    @MainActor
    static var allowsLandscape = false {
        didSet {
            guard allowsLandscape != oldValue else { return }
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive })
                as? UIWindowScene else { return }
            // Leaving the side-on step while physically holding the phone
            // landscape doesn't rotate the UI back on its own — force it.
            if !allowsLandscape {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
            // Without this, iOS never re-queries supportedInterfaceOrientations,
            // so entering side-on wouldn't start permitting landscape at all.
            scene.keyWindow?.rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
