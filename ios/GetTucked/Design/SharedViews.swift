import SwiftUI

extension View {
    /// Hides the system navigation bar. iOS-only; no-op on macOS.
    func hideNavBar() -> some View {
        #if canImport(UIKit)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

/// Standard in-app nav header row (not system NavigationView title).
struct NavHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.heading(19))
                    .foregroundStyle(Theme.Palette.fg)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.Palette.fg3)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.leading, Theme.Control.headerTitleInset)
        .padding(.trailing, Theme.Space.lg)
        .padding(.top, Theme.Space.sm)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 56)
    }
}

extension NavHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
    }
}

/// `.hdr-link` — small acid-yellow text link for a NavHeader's trailing slot,
/// e.g. "LEADERBOARD →". The only persistent cross-screen affordance left
/// once the hamburger index is gone (Plan E1).
struct HeaderLink: View {
    let label: String
    let action: () -> Void

    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text("\(label.uppercased()) →")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.Palette.acc)
                .kerning(0.8)
        }
        .buttonStyle(.plain)
    }
}

/// Full-height empty state for list screens.
struct EmptySlate: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.Palette.fg4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// Full-height empty state with an optional inline CTA button.
struct EmptyStateView: View {
    let message: String
    var ctaLabel: String? = nil
    var ctaAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()
            Text(message)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.Palette.fg4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)

            if let ctaLabel, let ctaAction {
                Button(action: ctaAction) {
                    HStack(spacing: Theme.Space.sm) {
                        Text(ctaLabel.uppercased())
                            .font(Theme.mono(14, weight: .bold))
                            .kerning(0.5)
                        Text("→")
                            .font(Theme.mono(14, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, Theme.Space.lg)
                    .frame(height: Theme.Control.accentButtonHeight)
                    .background(Theme.Palette.acc)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
