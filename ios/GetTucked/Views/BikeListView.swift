import SwiftUI
import SwiftData

struct BikeListView: View {
    @Binding var path: [AppScreen]
    @Query(sort: \Bike.createdAt, order: .forward) private var bikes: [Bike]
    @Environment(\.modelContext) private var context
    @State private var showingAddBike = false
    @State private var editingBike: Bike?
    #if DEBUG
    @State private var showResetConfirm = false
    #endif

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "BIKES") {
                    Button {
                        showingAddBike = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: Theme.Control.iconSize, weight: .medium))
                            .foregroundStyle(Theme.Palette.acc)
                            .frame(width: Theme.Control.iconTapTarget, height: Theme.Control.iconTapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                SectionDivider()

                if bikes.isEmpty {
                    EmptyStateView(message: "No bikes yet.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(bikes) { bike in
                                Button { editingBike = bike } label: {
                                    BikeRow(bike: bike)
                                }
                                .buttonStyle(RowPressStyle())
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
                    HeaderLink("RESET ALL DATA") { showResetConfirm = true }
                }
                .padding(.horizontal, Theme.Space.screenMargin)
                .padding(.vertical, Theme.Space.lg)
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
        #if DEBUG
        .confirmationDialog("Delete all bikes and positions?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset all data", role: .destructive) {
                try? context.delete(model: Position.self)
                try? context.delete(model: Bike.self)
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        }
        #endif
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
        .padding(.horizontal, Theme.Space.screenMargin)
        .frame(height: Theme.Control.listRowHeight)
        .contentShape(Rectangle())
    }
}
