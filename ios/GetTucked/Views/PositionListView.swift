import SwiftUI
import SwiftData

struct PositionListView: View {
    @Binding var path: [AppScreen]
    // Set by CaptureView when a fresh save lands; consumed here once the
    // user is back at root (N7) — then cleared so it doesn't re-fire.
    @Binding var highlightID: UUID?
    @Query(sort: \Position.capturedAt, order: .reverse) private var positions: [Position]
    @Query private var bikes: [Bike]
    @State private var selectMode = false
    @State private var selected: [UUID] = []
    // Captured once from `highlightID` so the tick's own fade isn't cut
    // short when the shared binding gets cleared right after.
    @State private var tickPositionID: UUID?

    // Selection order is preserved: first tapped = A (reference), second = B.
    private var selectedPositions: [Position] {
        selected.compactMap { id in positions.first { $0.id == id } }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Bespoke two-row header, not the shared NavHeader: four distinct
                // controls (select/gear/add on the title row, leaderboard link on
                // the subtitle row) overflow a single trailing slot at this width.
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center) {
                        Text("POSITIONS")
                            .font(Theme.heading(19))
                            .foregroundStyle(Theme.Palette.fg)
                        Spacer()
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
                                path.append(.bikeList)
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: Theme.Control.iconSize, weight: .medium))
                                    .foregroundStyle(Theme.Palette.fg3)
                                    .frame(width: Theme.Control.iconTapTarget, height: Theme.Control.iconTapTarget)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                path.append(.setTheScene)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: Theme.Control.iconSize, weight: .medium))
                                    .foregroundStyle(bikes.isEmpty ? Theme.Palette.fg4 : Theme.Palette.acc)
                                    .frame(width: Theme.Control.iconTapTarget, height: Theme.Control.iconTapTarget)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(bikes.isEmpty)
                        }
                    }
                    HStack(alignment: .center) {
                        Text("Tap two to compare.")
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.Palette.fg3)
                        Spacer()
                        HeaderLink("LEADERBOARD") { path.append(.leaderboard) }
                    }
                }
                // Root screen — no floating back arrow to clear, so the title
                // aligns with body content at the standard margin instead of
                // the wider pushed-screen inset (Plan F1).
                .padding(.leading, Theme.Space.screenMargin)
                .padding(.trailing, Theme.Space.screenMargin)
                .padding(.top, Theme.Space.sm)
                .padding(.bottom, Theme.Control.headerBottomPad)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)

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
                                Button {
                                    if selectMode {
                                        // Only haptic on an actual selection change — a tap
                                        // on an already-at-capacity row is a no-op and
                                        // shouldn't feel like it did something.
                                        if selected.contains(position.id) {
                                            selected.removeAll { $0 == position.id }
                                            Haptics.select()
                                        } else if selected.count < 2 {
                                            selected.append(position.id)
                                            Haptics.select()
                                        }
                                    } else {
                                        path.append(.positionDetail(position.persistentModelID))
                                    }
                                } label: {
                                    // Same row across selectMode toggling (not two
                                    // structurally-different views) so the checkbox
                                    // can slide in/out while content shifts, instead
                                    // of the whole row popping (N7).
                                    PositionRow(
                                        position: position,
                                        isSelected: selected.contains(position.id),
                                        isDisabled: selectMode && selected.count >= 2 && !selected.contains(position.id),
                                        showsCheckbox: selectMode
                                    )
                                }
                                .buttonStyle(.plain)
                                .overlay(alignment: .leading) {
                                    if position.id == tickPositionID {
                                        NewSaveTick()
                                    }
                                }
                                SectionDivider()
                            }
                        }
                        .animation(Theme.Motion.entrance(), value: selectMode)
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
        .animation(Theme.Motion.travel(), value: selected.count)
        .hideNavBar()
        .onChange(of: path) { _, newPath in
            // Root reached (path empty) after a fresh save — capture the
            // highlight locally and clear the shared signal so it can't
            // re-trigger on a later routine visit. No stagger otherwise:
            // the root list always renders instantly.
            guard newPath.isEmpty, let highlightID, positions.first?.id == highlightID else { return }
            tickPositionID = highlightID
            self.highlightID = nil
        }
    }
}

// MARK: - Row

/// One row shape for both browsing and select mode (N7) — `showsCheckbox`
/// toggles the leading indicator in place rather than swapping to a
/// structurally different view, so it can slide in/out while the rest of
/// the row's content shifts right, instead of the whole row popping.
private struct PositionRow: View {
    let position: Position
    var isSelected: Bool = false
    var isDisabled: Bool = false
    var showsCheckbox: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.md) {
            if showsCheckbox {
                ZStack {
                    Rectangle()
                        .stroke(isSelected ? Theme.Palette.acc : Theme.Palette.line, lineWidth: 1)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Rectangle()
                            .fill(Theme.Palette.acc)
                            .frame(width: 10, height: 10)
                            .transition(
                                reduceMotion
                                    ? .opacity.animation(Theme.Motion.entrance(Theme.Motion.fast))
                                    : .scale.animation(Theme.Motion.entrance(Theme.Motion.fast))
                            )
                    }
                }
                .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
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
                Text("\(AnalysisMath.areaDisplay(area)) cm²")
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundStyle(isDisabled ? Theme.Palette.fg4 : Theme.Palette.acc)
            } else {
                Text("···")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg4)
            }
        }
        .padding(.horizontal, Theme.Space.screenMargin)
        .frame(height: 60)
    }
}

/// "Here's what you just made" — a 2px acid left-edge tick on the newest
/// row after a fresh save, present immediately and fading out over 0.6s
/// (N7). Self-contained: once mounted it fades on its own schedule,
/// independent of the parent re-rendering afterward.
private struct NewSaveTick: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(Theme.Palette.acc)
            .frame(width: 2)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(Theme.Motion.entrance(0.6)) {
                    visible = false
                }
            }
    }
}

// MARK: - Compare bar

private struct CompareBar: View {
    let onCompare: () -> Void

    var body: some View {
        AccentButton(label: "COMPARE (2)", action: onCompare)
            .padding(.horizontal, Theme.Space.screenMargin)
            .padding(.bottom, Theme.Space.lg)
            .background(Theme.Palette.bg0.opacity(0.95))
    }
}
