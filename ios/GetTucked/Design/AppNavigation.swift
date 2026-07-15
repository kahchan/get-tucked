import SwiftUI
import SwiftData

// MARK: - Screen enum

// PersistentIdentifier (not Position) in model-carrying cases: SwiftUI's typed
// NavigationStack path does internal type comparison that crashes when SwiftData
// models (PersistentIdentifier-based Hashable) appear directly in the path array.
enum AppScreen: Hashable {
    case positionList
    case positionDetail(PersistentIdentifier)
    // referenceID (Plan P2) — set only via "Match this position", carries the
    // position to align a capture against through to CaptureView. nil for
    // every other entry point. No default: Swift enum cases can't default an
    // associated value cleanly against existing bare-`.capture` call sites,
    // so every call site below passes nil explicitly.
    case setTheScene(referenceID: PersistentIdentifier?)
    case capture(referenceID: PersistentIdentifier?)
    case bikeList
    case bikeSetup
    case leaderboard
    case comparison(PersistentIdentifier, PersistentIdentifier)
    case howItWorks
    // Reachable via a DEBUG-only "TOOLS" section on BikeListView.
    #if DEBUG
    case matteCheck
    // No UI entry point yet (Plan A6 experiment) — reach it by temporarily
    // seeding `path` with `[.poseCheck]` in AppNavigationView.
    case poseCheck
    #endif
}

/// Trims a nav path back to the screen the capture flow was entered from —
/// used by every ✕/cancel inside `CaptureView` (Q1.2). `while`, not
/// `removeLast(n)`, so it stays correct whether or not `.setTheScene` was
/// ever pushed (Q3 skips it on the match flow and once coaching has been
/// seen once).
func trimmedForCaptureExit(_ path: [AppScreen]) -> [AppScreen] {
    var result = path
    while case .capture = result.last { result.removeLast() }
    while case .setTheScene = result.last { result.removeLast() }
    return result
}

// MARK: - Root navigation

/// Single NavigationStack driving the whole app. No tab bar.
struct AppNavigationView: View {
    @State private var path: [AppScreen]
    // Q3.1: same UserDefaults key as PositionListView's copy — GOT IT here
    // is the one place that ever sets it to true.
    @AppStorage("hasSeenSetTheScene") private var hasSeenSetTheScene = false
    // Set when a fresh save lands (CaptureView), consumed by PositionListView
    // once the user is back at root — the newest row gets a brief "here's
    // what you just made" tick (Plan N7).
    @State private var justSavedPositionID: UUID?
    // Q5: the index menu — a root-only overlay, never a path entry (so the
    // back caret's path-emptiness check above stays correct).
    @State private var showingIndex = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Q4: lets ContentView seed the very first launch straight into the
    // capture flow after the first bike saves — read once, at this view's
    // creation, same as any other `@State` initial value.
    init(initialPath: [AppScreen] = []) {
        _path = State(initialValue: initialPath)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack(path: $path) {
                PositionListView(path: $path, highlightID: $justSavedPositionID, showingIndex: $showingIndex)
                    .navigationDestination(for: AppScreen.self) { screen in
                        switch screen {
                        case .positionList:
                            PositionListView(path: $path, highlightID: $justSavedPositionID, showingIndex: $showingIndex)
                        case .positionDetail(let id):
                            PositionDetailWrapper(id: id, path: $path)
                        case .setTheScene(let referenceID):
                            SetTheSceneView {
                                hasSeenSetTheScene = true
                                path.append(.capture(referenceID: referenceID))
                            }
                        case .capture(let referenceID):
                            #if canImport(UIKit)
                            CaptureView(path: $path, referenceID: referenceID, onSaved: { id in justSavedPositionID = id })
                            #else
                            Text("Camera not available on this platform")
                            #endif
                        case .bikeList:
                            BikeListView(path: $path)
                        case .bikeSetup:
                            BikeSetupView()
                        case .leaderboard:
                            LeaderboardView(path: $path)
                        case .comparison(let idA, let idB):
                            ComparisonWrapper(idA: idA, idB: idB, path: $path)
                        case .howItWorks:
                            HowItWorksView()
                        #if DEBUG
                        case .matteCheck:
                            MatteCheckView()
                        case .poseCheck:
                            PoseCheckView()
                        #endif
                        }
                    }
            }
            .tint(Theme.Palette.acc)

            // Back caret — top-left on any pushed screen (except capture, which
            // owns its own X dismiss and hides all overlay chrome). Pattern-
            // matched rather than `!=` since `.capture` now carries an
            // associated referenceID (Plan P2) and any value of it still
            // means "hide the back caret."
            if !path.isEmpty, !isCaptureScreen(path.last) {
                BackButton { path.removeLast() }
                    // Glyph is centred in the tap frame, so inset the frame by
                    // screenMargin minus the frame's half-margin around it —
                    // that puts the glyph itself at screenMargin.
                    .padding(.leading, Theme.Space.screenMargin - (Theme.Control.iconTapTarget - Theme.Control.iconSize) / 2)
                    // Vertically matches NavHeader's title, which always sits
                    // in a fixed-height leading slot (see NavHeader) — tuned
                    // once on-device via pixel measurement, not derived from
                    // a token, since it's centring against a floating overlay
                    // NavHeader has no way to report a position to.
                    .padding(.top, -2)
            }

            // Q5: secondary destinations only — POSITIONS (the root) is
            // never a menu item, and selecting one pushes onto path rather
            // than replacing it, so the back caret always returns here.
            // Never appears in `path` itself.
            if showingIndex {
                IndexOverlay(
                    onSelect: { screen in
                        closeIndex()
                        path.append(screen)
                    },
                    onClose: closeIndex
                )
                .transition(reduceMotion ? .identity : .opacity)
                .zIndex(1)
            }
        }
        // R2: a fast hamburger-tap → destination-tap sequence, or an
        // accidental open/close, should re-target smoothly rather than
        // finish one fade before starting the next. Opacity-only (no
        // directional edge in this presentation), so "exits the way it
        // entered" (§7) holds trivially.
        .animation(reduceMotion ? nil : Theme.Motion.interactive(), value: showingIndex)
    }

    private func closeIndex() {
        showingIndex = false
    }

    private func isCaptureScreen(_ screen: AppScreen?) -> Bool {
        if case .capture = screen { return true }
        return false
    }
}

// MARK: - Index menu (Q5)

/// Secondary-destination menu, reached via the root header's hamburger.
/// Full-screen overlay, never a path entry — POSITIONS (the root) isn't
/// listed since it's where the menu is opened from.
private struct IndexOverlay: View {
    let onSelect: (AppScreen) -> Void
    let onClose: () -> Void

    private let destinations: [(ordinal: String, label: String, screen: AppScreen)] = [
        ("01", "BIKES", .bikeList),
        ("02", "LEADERBOARD", .leaderboard),
        ("03", "HOW IT WORKS", .howItWorks),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: Theme.Space.xl + Theme.Control.iconTapTarget)
                ForEach(destinations, id: \.label) { destination in
                    IndexRow(ordinal: destination.ordinal, label: destination.label) {
                        onSelect(destination.screen)
                    }
                    SectionDivider()
                }
                Spacer()
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: Theme.Control.iconSize, weight: .medium))
                    .foregroundStyle(Theme.Palette.fg3)
                    .frame(width: Theme.Control.iconTapTarget, height: Theme.Control.iconTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, Theme.Space.screenMargin - (Theme.Control.iconTapTarget - Theme.Control.iconSize) / 2)
            .padding(.top, Theme.Space.sm)
        }
    }
}

private struct IndexRow: View {
    let ordinal: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            EmptyView()
        }
        .buttonStyle(IndexRowButtonStyle(ordinal: ordinal, label: label))
    }
}

/// Builds its own content from the style rather than decorating
/// `configuration.label` — the only way for the destination label itself
/// (not just an ancestor tint) to react to `isPressed` with the acid accent.
/// Also carries R4's row-press background flash (same `bg1` treatment as
/// `RowPressStyle`) — this row needs its own style regardless since the
/// text-recolor trick isn't expressible through a wrapping style.
private struct IndexRowButtonStyle: ButtonStyle {
    let ordinal: String
    let label: String

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.md) {
            Text(ordinal)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.Palette.fg4)
            Text(label)
                .font(Theme.heading(32))
                .foregroundStyle(configuration.isPressed ? Theme.Palette.acc : Theme.Palette.fg)
            Spacer()
        }
        .padding(.horizontal, Theme.Space.screenMargin)
        .padding(.vertical, Theme.Space.lg)
        .contentShape(Rectangle())
        .background(configuration.isPressed ? Theme.Palette.bg1 : Color.clear)
        .animation(Theme.Motion.press(configuration.isPressed), value: configuration.isPressed)
    }
}

// MARK: - Back button

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.system(size: Theme.Control.iconSize, weight: .medium))
                .foregroundStyle(Theme.Palette.fg2)
                .frame(width: Theme.Control.iconTapTarget, height: Theme.Control.iconTapTarget, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(BackButtonStyle())
    }
}

/// Pressed state nudges the glyph 2pt leading (N8).
private struct BackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(x: configuration.isPressed ? -2 : 0)
            .animation(Theme.Motion.press(configuration.isPressed), value: configuration.isPressed)
    }
}

// MARK: - SwiftData model lookup wrappers

private struct PositionDetailWrapper: View {
    let id: PersistentIdentifier
    @Binding var path: [AppScreen]
    @Query private var positions: [Position]

    var body: some View {
        if let position = positions.first(where: { $0.persistentModelID == id }) {
            PositionDetailView(position: position, path: $path)
        } else {
            Text("Position not found")
                .foregroundStyle(Theme.Palette.fg2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Palette.bg0)
        }
    }
}

private struct ComparisonWrapper: View {
    let idA: PersistentIdentifier
    let idB: PersistentIdentifier
    @Binding var path: [AppScreen]
    @Query private var positions: [Position]

    var body: some View {
        let a = positions.first(where: { $0.persistentModelID == idA })
        let b = positions.first(where: { $0.persistentModelID == idB })
        if let a, let b {
            ComparisonView(positionA: a, positionB: b, path: $path)
        } else {
            Text("Positions not found")
                .foregroundStyle(Theme.Palette.fg2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Palette.bg0)
        }
    }
}
