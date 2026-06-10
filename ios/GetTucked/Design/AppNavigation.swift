import SwiftUI
import SwiftData

// MARK: - Screen enum

enum AppScreen: Hashable {
    case positionList
    case positionDetail(Position)
    case setTheScene
    case capture
    case bikeList
    case bikeSetup
    case leaderboard
    case comparison(Position, Position)
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
                        case .positionDetail(let position):
                            PositionDetailView(position: position)
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
                        case .comparison(let a, let b):
                            ComparisonView(positionA: a, positionB: b)
                        }
                    }
            }
            .tint(Theme.Palette.acc)

            // Hamburger — fixed overlay, always top-left regardless of active screen.
            // System nav bar is hidden on all screens, so this is the only nav chrome.
            if !indexOpen {
                HamburgerButton { indexOpen = true }
                    .padding(.leading, Theme.Space.lg)
                    .padding(.top, 16)
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
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Theme.Palette.fg)
                        .frame(width: 18, height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Index overlay

struct IndexOverlay: View {
    @Binding var path: [AppScreen]
    @Binding var isOpen: Bool

    private let items: [(label: String, screen: AppScreen)] = [
        ("POSITIONS", .positionList),
        ("LEADERBOARD", .leaderboard),
        ("BIKES", .bikeList),
    ]

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
                        Text("✕")
                            .font(Theme.mono(16))
                            .foregroundStyle(Theme.Palette.fg2)
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
