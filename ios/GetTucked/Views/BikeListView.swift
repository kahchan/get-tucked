import SwiftUI
import SwiftData

struct BikeListView: View {
    @Query(sort: \Bike.createdAt, order: .forward) private var bikes: [Bike]
    @Environment(\.modelContext) private var context
    @State private var showingAddBike = false

    var body: some View {
        NavigationStack {
            List(bikes) { bike in
                VStack(alignment: .leading, spacing: 4) {
                    Text(bike.nickname)
                        .font(.headline)
                    Text("\(bike.handlebarWidthMm, specifier: "%.0f") mm · \(bike.bikeType.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Bikes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Bike", systemImage: "plus") {
                        showingAddBike = true
                    }
                }
            }
            .sheet(isPresented: $showingAddBike) {
                BikeFormView()
            }
        }
    }
}
