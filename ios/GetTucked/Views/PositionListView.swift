import SwiftUI
import SwiftData

struct PositionListView: View {
    @Binding var path: [AppScreen]
    // Set by CaptureView when a fresh save lands; consumed here once the
    // user is back at root (N7) — then cleared so it doesn't re-fire.
    @Binding var highlightID: UUID?
    @Query(sort: \Position.capturedAt, order: .reverse) private var positions: [Position]
    @Query private var bikes: [Bike]
    // Selection is always available (no separate select mode) — each row's
    // checkbox and its open-for-detail action are independent tap targets,
    // so this can hold state across a trip to a position's detail and back.
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
                // Bespoke two-row header, not the shared NavHeader: gear/add
                // on the title row, leaderboard link on the subtitle row
                // overflow a single trailing slot at this width.
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center) {
                        Text("POSITIONS")
                            .font(Theme.heading(19))
                            .foregroundStyle(Theme.Palette.fg)
                        Spacer()
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
                            path.append(.setTheScene(referenceID: nil))
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
                            ctaAction: { path.append(.setTheScene(referenceID: nil)) }
                        )
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(positions) { position in
                                PositionRow(
                                    position: position,
                                    isSelected: selected.contains(position.id),
                                    isAtCapacity: selected.count >= 2 && !selected.contains(position.id),
                                    onToggleSelect: {
                                        // Only haptic on an actual selection change — a tap
                                        // on an already-at-capacity checkbox is a no-op and
                                        // shouldn't feel like it did something.
                                        if selected.contains(position.id) {
                                            selected.removeAll { $0 == position.id }
                                            Haptics.select()
                                        } else if selected.count < 2 {
                                            selected.append(position.id)
                                            Haptics.select()
                                        }
                                    },
                                    onOpen: { path.append(.positionDetail(position.persistentModelID)) }
                                )
                                .overlay(alignment: .leading) {
                                    if position.id == tickPositionID {
                                        NewSaveTick()
                                    }
                                }
                                SectionDivider()
                            }
                        }
                        // Bottom padding so the compare bar doesn't overlap the last row.
                        if selected.count == 2 { Color.clear.frame(height: 72) }
                    }
                }
            }

            // Compare bar — slides up when 2 positions selected
            if selected.count == 2 {
                CompareBar {
                    let pair = selectedPositions
                    path.append(.comparison(pair[0].persistentModelID, pair[1].persistentModelID))
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

/// Two independent tap targets, not one whose meaning depends on a mode:
/// the checkbox selects for comparison, everything else always opens the
/// position's detail — even once 2 others are already selected elsewhere.
/// Only the checkbox shows the at-capacity dimming; the rest of the row
/// stays fully live.
private struct PositionRow: View {
    let position: Position
    var isSelected: Bool = false
    var isAtCapacity: Bool = false
    let onToggleSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Button(action: onToggleSelect) {
                CheckboxIndicator(isSelected: isSelected, isDisabled: isAtCapacity)
                    .frame(width: Theme.Control.iconTapTarget, height: 60)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isAtCapacity && !isSelected)
            .accessibilityLabel(isSelected ? "Deselect for comparison" : "Select for comparison")
            .padding(.leading, Theme.Space.screenMargin - (Theme.Control.iconTapTarget - 18) / 2)

            Button(action: onOpen) {
                HStack(alignment: .center, spacing: 0) {
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
                        Text("\(AnalysisMath.areaDisplay(area)) cm²")
                            .font(Theme.mono(13, weight: .bold))
                            .foregroundStyle(Theme.Palette.acc)
                    } else {
                        Text("···")
                            .font(Theme.mono(13))
                            .foregroundStyle(Theme.Palette.fg4)
                    }
                }
                .padding(.trailing, Theme.Space.screenMargin)
                .frame(height: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// The checkbox's visual — a small square, drawn inside a much larger
/// (`iconTapTarget`-sized) comfortable hit zone owned by the caller.
private struct CheckboxIndicator: View {
    let isSelected: Bool
    let isDisabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(borderColor, lineWidth: 1)
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
    }

    private var borderColor: Color {
        if isSelected { Theme.Palette.acc }
        else if isDisabled { Theme.Palette.line2 }
        else { Theme.Palette.line }
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
