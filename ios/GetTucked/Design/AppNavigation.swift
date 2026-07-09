import SwiftUI
import SwiftData

// MARK: - Screen enum

// PersistentIdentifier (not Position) in model-carrying cases: SwiftUI's typed
// NavigationStack path does internal type comparison that crashes when SwiftData
// models (PersistentIdentifier-based Hashable) appear directly in the path array.
enum AppScreen: Hashable {
    case positionList
    case positionDetail(PersistentIdentifier)
    case setTheScene
    case capture
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

// MARK: - Root navigation

/// Single NavigationStack driving the whole app. No tab bar.
struct AppNavigationView: View {
    @State private var path: [AppScreen] = []
    // Set when a fresh save lands (CaptureView), consumed by PositionListView
    // once the user is back at root — the newest row gets a brief "here's
    // what you just made" tick (Plan N7).
    @State private var justSavedPositionID: UUID?

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack(path: $path) {
                PositionListView(path: $path, highlightID: $justSavedPositionID)
                    .navigationDestination(for: AppScreen.self) { screen in
                        switch screen {
                        case .positionList:
                            PositionListView(path: $path, highlightID: $justSavedPositionID)
                        case .positionDetail(let id):
                            PositionDetailWrapper(id: id, path: $path)
                        case .setTheScene:
                            SetTheSceneView { path.append(.capture) }
                        case .capture:
                            #if canImport(UIKit)
                            CaptureView(path: $path, onSaved: { id in justSavedPositionID = id })
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
            // owns its own X dismiss and hides all overlay chrome).
            if !path.isEmpty && path.last != .capture {
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
        }
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
            .animation(Theme.Motion.entrance(Theme.Motion.fast), value: configuration.isPressed)
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
