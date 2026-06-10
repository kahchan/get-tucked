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
        HStack {
            Text(title)
                .font(Theme.heading(18))
                .foregroundStyle(Theme.Palette.fg)
            Spacer()
            trailing()
        }
        .padding(.horizontal, Theme.Space.lg)
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
