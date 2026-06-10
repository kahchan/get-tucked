import SwiftUI
import SwiftData

struct PositionListView: View {
    @Binding var path: [AppScreen]
    @Query(sort: \Position.capturedAt, order: .reverse) private var positions: [Position]
    @Query private var bikes: [Bike]

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "POSITIONS") {
                    Button {
                        path.append(.setTheScene)
                    } label: {
                        Text("+")
                            .font(Theme.mono(22))
                            .foregroundStyle(bikes.isEmpty ? Theme.Palette.fg4 : Theme.Palette.acc)
                    }
                    .buttonStyle(.plain)
                    .disabled(bikes.isEmpty)
                }

                SectionDivider()

                if positions.isEmpty {
                    EmptySlate(message: "No positions yet.\nPhotograph your riding position to measure frontal area.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(positions) { position in
                                Button {
                                    path.append(.positionDetail(position))
                                } label: {
                                    PositionRow(position: position)
                                }
                                .buttonStyle(.plain)

                                SectionDivider()
                            }
                        }
                    }
                }
            }
        }
        .hideNavBar()
    }
}

private struct PositionRow: View {
    let position: Position

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(position.label)
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundStyle(Theme.Palette.fg)
                Text(position.capturedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
            }
            Spacer()
            if let area = position.metrics?.frontalAreaCm2 {
                Text("\(Int(area)) cm²")
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundStyle(Theme.Palette.acc)
            } else {
                Text("···")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg4)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 60)
    }
}
