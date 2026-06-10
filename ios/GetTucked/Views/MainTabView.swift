import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            PositionListView()
                .tabItem {
                    Label("Positions", systemImage: "figure.outdoor.cycle")
                }
            BikeListView()
                .tabItem {
                    Label("Bikes", systemImage: "bicycle")
                }
        }
    }
}
