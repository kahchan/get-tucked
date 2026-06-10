import SwiftUI
import SwiftData

struct LeaderboardView: View {
    @Binding var path: [AppScreen]
    @Query(sort: \Position.capturedAt, order: .reverse) private var allPositions: [Position]
    @State private var bikeFilter: BikeType? = nil  // nil = ALL

    private var filtered: [Position] {
        let withMetrics = allPositions.filter { $0.metrics != nil }
        guard let filter = bikeFilter else { return withMetrics }
        return withMetrics.filter { $0.bike?.bikeType == filter }
    }

    private var ranked: [Position] {
        filtered.sorted { ($0.metrics?.frontalAreaCm2 ?? .infinity) < ($1.metrics?.frontalAreaCm2 ?? .infinity) }
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "LEADERBOARD")
                SectionDivider()

                // Bike type filter
                FilterBar(selection: $bikeFilter)
                SectionDivider()

                if ranked.isEmpty {
                    EmptySlate(message: "No positions yet.\nCapture a position to see it ranked here.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(ranked.enumerated()), id: \.element.id) { index, position in
                                Button {
                                    path.append(.positionDetail(position))
                                } label: {
                                    RankRow(rank: index + 1, position: position, best: ranked.first)
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

// MARK: - Filter bar

private struct FilterBar: View {
    @Binding var selection: BikeType?

    private let options: [(label: String, value: BikeType?)] = [
        ("ALL", nil),
        ("ROAD", .road),
        ("GRAVEL", .gravel),
        ("MTB", .mtb),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.label) { option in
                let selected = selection == option.value
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(Theme.mono(10, weight: selected ? .bold : .regular))
                        .foregroundStyle(selected ? Theme.Palette.acc : Theme.Palette.fg4)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .overlay(alignment: .bottom) {
                            if selected {
                                Rectangle().fill(Theme.Palette.acc).frame(height: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Rank row

private struct RankRow: View {
    let rank: Int
    let position: Position
    let best: Position?

    private var area: Double? { position.metrics?.frontalAreaCm2 }
    private var bestArea: Double? { best?.metrics?.frontalAreaCm2 }

    private var deltaText: String? {
        guard let a = area, let b = bestArea, rank > 1 else { return nil }
        let pct = ((a - b) / b) * 100
        return "+\(String(format: "%.1f", pct))%"
    }

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            // Rank number
            Text("\(rank)")
                .font(Theme.mono(11))
                .foregroundStyle(rank == 1 ? Theme.Palette.acc : Theme.Palette.fg4)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(position.label)
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundStyle(Theme.Palette.fg)
                if let bike = position.bike {
                    Text(bike.nickname.uppercased())
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.Palette.fg4)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let a = area {
                    Text("\(Int(a)) cm²")
                        .font(Theme.mono(13, weight: .bold))
                        .foregroundStyle(rank == 1 ? Theme.Palette.acc : Theme.Palette.fg)
                }
                if let d = deltaText {
                    Text(d)
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.Palette.amb)
                }
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 64)
    }
}
