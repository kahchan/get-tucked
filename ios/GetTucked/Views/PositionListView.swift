import SwiftUI
import SwiftData

struct PositionListView: View {
    @Query(sort: \Position.capturedAt, order: .reverse) private var positions: [Position]
    @Query private var bikes: [Bike]
    @State private var showingCapture = false

    var body: some View {
        NavigationStack {
            Group {
                if positions.isEmpty {
                    ContentUnavailableView(
                        "No positions yet",
                        systemImage: "figure.outdoor.cycle",
                        description: Text("Photograph your riding position to measure frontal area.")
                    )
                } else {
                    List(positions) { position in
                        NavigationLink(destination: PositionDetailView(position: position)) {
                            PositionRowView(position: position)
                        }
                    }
                }
            }
            .navigationTitle("Positions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Position", systemImage: "camera") {
                        showingCapture = true
                    }
                    .disabled(bikes.isEmpty)
                }
            }
            .sheet(isPresented: $showingCapture) {
                CaptureView()
            }
        }
    }
}

struct PositionRowView: View {
    let position: Position

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(position.label)
                .font(.headline)
            if let area = position.metrics?.frontalAreaCm2 {
                Text("\(area, specifier: "%.0f") cm²")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Processing…")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            Text(position.capturedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
