import SwiftUI

/// The swap-and-rescale sheet (Plan Y2) — a bike list that becomes an
/// inline confirm state on selection, all in the same sheet (not a second
/// alert), so the amber no-wheelbase warning (when it applies) is visible
/// before CONFIRM ever fires.
struct WrongBikeSheet: View {
    @Bindable var position: Position
    let otherBikes: [Bike]
    let imageAspect: CGSize

    @Environment(\.dismiss) private var dismiss
    @State private var selectedBike: Bike?

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(
                    title: "WRONG BIKE?",
                    subtitle: selectedBike == nil
                        ? "Pick the bike this position was actually shot on."
                        : nil
                )
                SectionDivider()

                if let selectedBike {
                    confirmState(for: selectedBike)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(otherBikes) { bike in
                                Button {
                                    self.selectedBike = bike
                                } label: {
                                    WrongBikeRow(bike: bike)
                                }
                                .buttonStyle(RowPressStyle())
                                SectionDivider()
                            }
                        }
                    }
                }
            }
        }
        .hideNavBar()
    }

    @ViewBuilder
    private func confirmState(for bike: Bike) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text(BikeSwap.confirmMessage(newBike: bike))
                .font(Theme.mono(14))
                .foregroundStyle(Theme.Palette.fg)

            if let warning = BikeSwap.noWheelbaseWarning(position: position, newBike: bike) {
                Text(warning)
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.amb)
            }

            AccentButton(label: "CONFIRM") {
                BikeSwap.apply(to: position, newBike: bike, imageAspect: imageAspect)
                dismiss()
            }
            .padding(.top, Theme.Space.sm)

            GhostButton(label: "Choose a different bike") {
                self.selectedBike = nil
            }
        }
        .padding(.horizontal, Theme.Space.screenMargin)
        .padding(.top, Theme.Space.lg)
    }
}

private struct WrongBikeRow: View {
    let bike: Bike

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(bike.nickname)
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundStyle(Theme.Palette.fg)
                Text(bike.hardPointsSummary.uppercased())
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Space.screenMargin)
        .frame(minHeight: Theme.Control.listRowHeight)
        .contentShape(Rectangle())
    }
}
