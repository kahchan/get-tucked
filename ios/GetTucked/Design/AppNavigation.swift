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
    #if DEBUG
    case matteCheck
    #endif
}

// MARK: - Root navigation

/// Single NavigationStack driving the whole app. No tab bar.
struct AppNavigationView: View {
    @State private var path: [AppScreen] = []
    @State private var indexOpen = false

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

            // Hamburger — fixed overlay, always top-left regardless of active screen.
            // System nav bar is hidden on all screens, so this is the only nav chrome.
            if !indexOpen {
                HamburgerButton { indexOpen = true }
                    .padding(.leading, Theme.Space.lg)
                    .padding(.top, 6)
            }

            if indexOpen {
                IndexOverlay(path: $path, isOpen: $indexOpen)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: indexOpen)
    }
}

// MARK: - Hamburger button

struct HamburgerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.Palette.fg)
                .frame(width: 44, height: 44)
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

// MARK: - Index overlay

struct IndexOverlay: View {
    @Binding var path: [AppScreen]
    @Binding var isOpen: Bool

    private let items: [(label: String, screen: AppScreen)] = {
        var list: [(String, AppScreen)] = [
            ("POSITIONS", .positionList),
            ("LEADERBOARD", .leaderboard),
            ("BIKES", .bikeList),
        ]
        #if DEBUG
        list.append(("MATTE CHECK", .matteCheck))
        #endif
        return list
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.Palette.bg0
                .ignoresSafeArea()
                .onTapGesture { isOpen = false }

            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack {
                    Text("GET TUCKED")
                        .font(Theme.heading(13))
                        .foregroundStyle(Theme.Palette.acc)
                    Spacer()
                    Button(action: { isOpen = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.Palette.fg2)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Space.lg)
                .frame(height: 56)

                SectionDivider()

                ForEach(items, id: \.label) { item in
                    Button {
                        isOpen = false
                        if item.screen == .positionList {
                            path = []
                        } else {
                            path = [item.screen]
                        }
                    } label: {
                        HStack {
                            Text(item.label)
                                .font(Theme.heading(28))
                                .foregroundStyle(Theme.Palette.fg)
                            Spacer()
                            Text("→")
                                .font(Theme.mono(16))
                                .foregroundStyle(Theme.Palette.fg4)
                        }
                        .padding(.horizontal, Theme.Space.lg)
                        .frame(height: 72)
                    }
                    .buttonStyle(.plain)

                    SectionDivider()
                }

                Spacer()
            }
        }
    }
}
