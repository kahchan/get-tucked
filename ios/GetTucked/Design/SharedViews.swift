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
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(Theme.heading(18))
                .foregroundStyle(Theme.Palette.fg)
            HStack {
                Spacer()
                trailing()
            }
            .padding(.horizontal, Theme.Space.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
    }
}

extension NavHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = { EmptyView() }
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
