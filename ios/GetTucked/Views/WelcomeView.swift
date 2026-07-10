import SwiftUI
import SwiftData

/// First-run screen shown when the user has no bikes yet.
struct WelcomeView: View {
    @State private var showingSetup = false

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Hero wordmark
                Text("GET\nTUCKED")
                    .font(Theme.heading(88))
                    .foregroundStyle(Theme.Palette.fg)
                    .kerning(Theme.Typography.tracking(forSize: 88))
                    .lineSpacing(-4)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.bottom, Theme.Space.xl)

                // Strapline
                Text("Measure your frontal area.\nIterate your position.")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg3)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.bottom, Theme.Space.xl)

                SectionDivider()

                AccentButton(label: "BEGIN SETUP") {
                    showingSetup = true
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.top, Theme.Space.lg)

                Spacer()
            }
        }
        .sheet(isPresented: $showingSetup) {
            BikeSetupSheet()
        }
    }
}

/// Sheet wrapper: sets up the first bike, then dismisses.
private struct BikeSetupSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BikeSetupView(onSave: { dismiss() })
    }
}
