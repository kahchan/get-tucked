import SwiftUI
import SwiftData

@main
struct GetTuckedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: AppSchema.models)
    }
}
