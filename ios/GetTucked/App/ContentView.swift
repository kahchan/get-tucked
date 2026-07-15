import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var bikes: [Bike]
    // Q4: set once, by WelcomeView's sheet, the moment the first bike
    // saves — read only at the instant AppNavigationView's identity is
    // first created below, so it stays inert after that (deleting the
    // last bike and adding a new one re-arms it via a fresh WelcomeView).
    @State private var launchIntoCapture = false

    var body: some View {
        if bikes.isEmpty {
            WelcomeView(onFirstBikeSaved: { launchIntoCapture = true })
        } else {
            AppNavigationView(initialPath: launchIntoCapture ? [.setTheScene(referenceID: nil)] : [])
        }
    }
}
