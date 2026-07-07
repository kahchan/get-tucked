import SwiftUI
import SwiftData

struct BikeListView: View {
    @Binding var path: [AppScreen]
    @Query(sort: \Bike.createdAt, order: .forward) private var bikes: [Bike]
    @State private var showingAddBike = false
    @State private var editingBike: Bike?

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "BIKES") {
                    Button {
                        showingAddBike = true
                    } label: {
                        Text("+")
                            .font(Theme.mono(22))
                            .foregroundStyle(Theme.Palette.acc)
                    }
                    .buttonStyle(.plain)
                }

                SectionDivider()

                if bikes.isEmpty {
                    EmptySlate(message: "No bikes yet.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(bikes) { bike in
                                Button { editingBike = bike } label: {
                                    BikeRow(bike: bike)
                                }
                                .buttonStyle(.plain)
                                SectionDivider()
                            }
                        }
                    }
                }

                #if DEBUG
                SectionDivider()
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("DEBUG")
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundStyle(Theme.Palette.fg4)
                        .kerning(1.2)
                    HeaderLink("MATTE CHECK") { path.append(.matteCheck) }
                }
                .padding(Theme.Space.lg)
                #endif
            }
        }
        .hideNavBar()
        .sheet(isPresented: $showingAddBike) {
            BikeSetupView()
        }
        .sheet(item: $editingBike) { bike in
            BikeSetupView(editing: bike)
        }
    }
}

private struct BikeRow: View {
    let bike: Bike

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(bike.nickname)
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundStyle(Theme.Palette.fg)
                Text("\(Int(bike.handlebarWidthMm)) MM · \(bike.bikeType.displayName.uppercased())")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
            }
            Spacer()
            Text("EDIT")
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.fg3)
                .kerning(0.5)
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 60)
        .contentShape(Rectangle())
    }
}
