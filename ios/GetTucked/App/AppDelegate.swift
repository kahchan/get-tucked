import UIKit

/// SwiftUI's App lifecycle has no per-screen orientation override — that
/// hook only exists on UIApplicationDelegate. This is the minimal bridge
/// Plan L needs to allow landscape only while OrientationLock says so.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.allowsLandscape ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
    }
}
