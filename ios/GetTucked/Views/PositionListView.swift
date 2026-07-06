import SwiftUI
import SwiftData

struct PositionListView: View {
    @Binding var path: [AppScreen]
    @Query(sort: \Position.capturedAt, order: .reverse) private var positions: [Position]
    @Query private var bikes: [Bike]
    @State private var selectMode = false
    @State private var selected: [UUID] = []

    // Selection order is preserved: first tapped = A (reference), second = B.
    private var selectedPositions: [Position] {
        selected.compactMap { id in positions.first { $0.id == id } }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "POSITIONS", subtitle: "Tap two to compare.") {
                    HStack(spacing: Theme.Space.md) {
                        HeaderLink("LEADERBOARD") { path.append(.leaderboard) }
                        if !positions.isEmpty {
                            Button(selectMode ? "DONE" : "SELECT") {
                                selectMode.toggle()
                                if !selectMode { selected.removeAll() }
                            }
                            .font(Theme.mono(11))
                            .foregroundStyle(selectMode ? Theme.Palette.acc : Theme.Palette.fg3)
                        }
                        if !selectMode {
                            Button {
                                path.append(.setTheScene)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(bikes.isEmpty ? Theme.Palette.fg4 : Theme.Palette.acc)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(bikes.isEmpty)
                        }
                    }
                }

                SectionDivider()

                if positions.isEmpty {
                    if bikes.isEmpty {
                        EmptyStateView(
                            message: "No bike yet.\nAdd your bike to start measuring positions.",
                            ctaLabel: "Add your bike",
                            ctaAction: { path.append(.bikeSetup) }
                        )
                    } else {
                        EmptyStateView(
                            message: "No positions yet.\nCapture a position to measure frontal area.",
                            ctaLabel: "Capture a position",
                            ctaAction: { path.append(.setTheScene) }
                        )
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(positions) { position in
                                if selectMode {
                                    Button {
                                        if selected.contains(position.id) {
                                            selected.removeAll { $0 == position.id }
                                        } else if selected.count < 2 {
                                            selected.append(position.id)
                                        }
                                    } label: {
                                        SelectablePositionRow(
                                            position: position,
                                            isSelected: selected.contains(position.id),
                                            isDisabled: selected.count >= 2 && !selected.contains(position.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button {
                                        path.append(.positionDetail(position.persistentModelID))
                                    } label: {
                                        PositionRow(position: position)
                                    }
                                    .buttonStyle(.plain)
                                }
                                SectionDivider()
                            }
                        }
                        // Bottom padding so compare bar doesn't overlap last row
                        if selectMode { Color.clear.frame(height: 72) }
                    }
                }
            }

            // Compare bar — slides up when 2 positions selected
            if selectMode && selected.count == 2 {
                CompareBar {
                    let pair = selectedPositions
                    path.append(.comparison(pair[0].persistentModelID, pair[1].persistentModelID))
                    selectMode = false
                    selected.removeAll()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selected.count)
        .hideNavBar()
    }
}

// MARK: - Row variants

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

private struct SelectablePositionRow: View {
    let position: Position
    let isSelected: Bool
    let isDisabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.md) {
            // Selection indicator
            ZStack {
                Rectangle()
                    .stroke(isSelected ? Theme.Palette.acc : Theme.Palette.line, lineWidth: 1)
                    .frame(width: 18, height: 18)
                if isSelected {
                    Rectangle()
                        .fill(Theme.Palette.acc)
                        .frame(width: 10, height: 10)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(position.label)
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundStyle(isDisabled ? Theme.Palette.fg4 : Theme.Palette.fg)
                Text(position.capturedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
            }

            Spacer()

            if let area = position.metrics?.frontalAreaCm2 {
                Text("\(Int(area)) cm²")
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundStyle(isDisabled ? Theme.Palette.fg4 : Theme.Palette.acc)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 60)
    }
}

// MARK: - Compare bar

private struct CompareBar: View {
    let onCompare: () -> Void

    var body: some View {
        AccentButton(label: "COMPARE (2)", action: onCompare)
            .padding(.horizontal, Theme.Space.lg)
            .padding(.bottom, Theme.Space.lg)
            .background(Theme.Palette.bg0.opacity(0.95))
    }
}
