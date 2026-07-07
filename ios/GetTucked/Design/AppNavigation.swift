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
    // No UI entry point since the hamburger index was removed (Plan E1) — reach it
    // by temporarily seeding `path` with `[.matteCheck]` in AppNavigationView.
    #if DEBUG
    case matteCheck
    #endif
}

// MARK: - Root navigation

/// Single NavigationStack driving the whole app. No tab bar.
struct AppNavigationView: View {
    @State private var path: [AppScreen] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack(path: $path) {
                PositionListView(path: $path)
                    .navigationDestination(for: AppScreen.self) { screen in
                        switch screen {
                        case .positionList:
                            PositionListView(path: $path)
                        case .positionDetail(let id):
                            PositionDetailWrapper(id: id)
                        case .setTheScene:
                            SetTheSceneView { path.append(.capture) }
                        case .capture:
                            #if canImport(UIKit)
                            CaptureView()
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
                            ComparisonWrapper(idA: idA, idB: idB)
                        #if DEBUG
                        case .matteCheck:
                            MatteCheckView()
                        #endif
                        }
                    }
            }
            .tint(Theme.Palette.acc)

            // Back caret — top-left on any pushed screen (except capture, which
            // owns its own X dismiss and hides all overlay chrome).
            if !path.isEmpty && path.last != .capture {
                BackButton { path.removeLast() }
                    .padding(.leading, Theme.Space.lg)
                    .padding(.top, Theme.Space.sm + 6)
            }
        }
    }
}

// MARK: - Back button

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("←")
                .font(Theme.mono(24, weight: .bold))
                .foregroundStyle(Theme.Palette.fg2)
                .frame(width: 44, height: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SwiftData model lookup wrappers

private struct PositionDetailWrapper: View {
    let id: PersistentIdentifier
    @Query private var positions: [Position]

    var body: some View {
        if let position = positions.first(where: { $0.persistentModelID == id }) {
            PositionDetailView(position: position)
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
    @Query private var positions: [Position]

    var body: some View {
        let a = positions.first(where: { $0.persistentModelID == idA })
        let b = positions.first(where: { $0.persistentModelID == idB })
        if let a, let b {
            ComparisonView(positionA: a, positionB: b)
        } else {
            Text("Positions not found")
                .foregroundStyle(Theme.Palette.fg2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Palette.bg0)
        }
    }
}
