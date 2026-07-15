import SwiftUI
import SwiftData

struct LeaderboardView: View {
    @Binding var path: [AppScreen]
    @Query(sort: \Position.capturedAt, order: .reverse) private var allPositions: [Position]
    @State private var bikeFilter: BikeType? = nil  // nil = ALL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                NavHeader(title: "LEADERBOARD", subtitle: "Your positions, ranked by frontal area.")
                SectionDivider()

                // Bike type filter
                FilterBar(selection: $bikeFilter)
                SectionDivider()

                if ranked.isEmpty {
                    EmptyStateView(message: "No positions yet.\nCapture a position to see it ranked here.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(ranked.enumerated()), id: \.element.id) { index, position in
                                Button {
                                    path.append(.positionDetail(position.persistentModelID))
                                } label: {
                                    RankRow(rank: index + 1, position: position, best: ranked.first)
                                }
                                .buttonStyle(RowPressStyle())
                                SectionDivider()
                            }
                        }
                        // Identity is already \.element.id, so a filter change
                        // reorders existing rows into their new rank position
                        // instead of teleporting (N7).
                        .animation(reduceMotion ? nil : Theme.Motion.travel(), value: bikeFilter)
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

    // Underline slides between tabs (N7) instead of popping.
    @Namespace private var underlineNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        .font(Theme.mono(11, weight: selected ? .bold : .regular))
                        .foregroundStyle(selected ? Theme.Palette.acc : Theme.Palette.fg4)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .overlay(alignment: .bottom) {
                            if selected {
                                Rectangle()
                                    .fill(Theme.Palette.acc)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "filterUnderline", in: underlineNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        // R2: rapid tab-tapping should re-target the live underline
        // position, not cross-fade two fixed-duration eases.
        .animation(reduceMotion ? nil : Theme.Motion.interactive(0.3), value: selection)
    }
}

// MARK: - Rank row

private struct RankRow: View {
    let rank: Int
    let position: Position
    let best: Position?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Rank-1 underline sweep progress (N7) — the small podium moment, once
    // per push into first place.
    @State private var underlineProgress: Double = 0

    private var area: Double? { position.metrics?.frontalAreaCm2 }
    private var bestArea: Double? { best?.metrics?.frontalAreaCm2 }

    private var deltaText: String? {
        guard let a = area, let b = bestArea, rank > 1 else { return nil }
        // A delta smaller than the combined noise floor isn't a real ranking
        // difference — don't claim it as one (Plan A4).
        if let uA = position.metrics?.frontalAreaUncertainty,
           let uB = best?.metrics?.frontalAreaUncertainty,
           !AnalysisMath.isDistinguishable(areaA: a, areaB: b, uncertaintyA: uA, uncertaintyB: uB) {
            return nil
        }
        let pct = ((a - b) / b) * 100
        return "+\(String(format: "%.1f", pct))%"
    }

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            // Rank number
            Text("\(rank)")
                .font(Theme.mono(11))
                .foregroundStyle(rank == 1 ? Theme.Palette.acc : Theme.Palette.fg3)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(position.label)
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundStyle(Theme.Palette.fg)
                if let bike = position.bike {
                    Text(bike.nickname.uppercased())
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.Palette.fg3)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let a = area {
                    Text("\(AnalysisMath.areaDisplay(a)) cm²")
                        .font(Theme.mono(13, weight: .bold))
                        .foregroundStyle(rank == 1 ? Theme.Palette.acc : Theme.Palette.fg)
                }
                if let d = deltaText {
                    Text(d)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.Palette.amb)
                }
            }
        }
        .padding(.horizontal, Theme.Space.screenMargin)
        // Q8.5: stays off Theme.Control.listRowHeight (60) — both sides of
        // this row carry two lines (label+bike, area+delta) rather than
        // PositionRow/BikeRow's one, and need the extra 4pt.
        .frame(height: 64)
        .overlay(alignment: .bottom) {
            if rank == 1 {
                // Sweeps in left→right once each time a position pushes into
                // first place — fires on insertion, so a later re-sort that
                // promotes a different row to rank 1 gets its own sweep too.
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Theme.Palette.acc)
                        .frame(width: proxy.size.width * underlineProgress, height: 2)
                }
                .frame(height: 2)
                .onAppear {
                    if reduceMotion {
                        underlineProgress = 1
                    } else {
                        underlineProgress = 0
                        withAnimation(Theme.Motion.travel(Theme.Motion.gentle)) {
                            underlineProgress = 1
                        }
                    }
                }
            }
        }
    }
}
