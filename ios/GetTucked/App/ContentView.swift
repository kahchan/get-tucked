import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var bikes: [Bike]

    var body: some View {
        if bikes.isEmpty {
            WelcomeView()
        } else {
            AppNavigationView()
        }
    }
}
