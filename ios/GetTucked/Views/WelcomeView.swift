import SwiftUI
import SwiftData

/// First-run screen shown when the user has no bikes yet.
struct WelcomeView: View {
    var onFirstBikeSaved: () -> Void = {}
    @State private var showingSetup = false

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Hero wordmark. Q8.1: moved from `lg` to `screenMargin` to
                // match every other screen edge in the app — Kah verifies
                // this reads right on device before it commits; if it reads
                // worse, revert this one padding back to `lg` with a note
                // that it's a deliberate composition choice, not drift.
                Text("GET\nTUCKED")
                    .font(Theme.heading(88))
                    .foregroundStyle(Theme.Palette.fg)
                    .kerning(Theme.Typography.tracking(forSize: 88))
                    .lineSpacing(-4)
                    .padding(.horizontal, Theme.Space.screenMargin)
                    .padding(.bottom, Theme.Space.xl)

                // Strapline
                Text("Measure your frontal area.\nIterate your position.")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg3)
                    .padding(.horizontal, Theme.Space.screenMargin)
                    .padding(.bottom, Theme.Space.xl)

                SectionDivider()

                AccentButton(label: "BEGIN SETUP") {
                    showingSetup = true
                }
                .padding(.horizontal, Theme.Space.screenMargin)
                .padding(.top, Theme.Space.lg)

                Spacer()
            }
        }
        .sheet(isPresented: $showingSetup) {
            BikeSetupSheet(onSaved: onFirstBikeSaved)
        }
    }
}

/// Sheet wrapper: sets up the first bike, then dismisses.
private struct BikeSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void

    var body: some View {
        BikeSetupView(onSave: {
            onSaved()
            dismiss()
        })
    }
}
