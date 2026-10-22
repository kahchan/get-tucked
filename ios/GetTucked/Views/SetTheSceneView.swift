import SwiftUI

/// Coaching screen shown before capture. Explains setup requirements so the
/// user frames the shot correctly before the camera opens.
struct SetTheSceneView: View {
    var onContinue: () -> Void

    private let doItems: [(icon: String, text: String)] = [
        ("↕", "Fill the frame head-to-toe"),
        ("☀", "Even, diffuse light"),
        ("⊡", "Plain, high-contrast background"),
        ("⊙", "Camera at hub height"),
        // Plan W3: shooting from farther away with optical zoom flattens the
        // near-wheel perspective error a close-up shot bakes in. Plan AF1
        // made the 2x actually happen in-app, so this can promise it rather
        // than ask the user to do something the camera had no control for.
        ("↔", "Stand back 5–6m — we zoom to 2× for you"),
    ]

    private let avoidItems: [(icon: String, text: String)] = [
        ("✕", "Cropped feet or head"),
        ("✕", "Backlit or shadows across body"),
        ("✕", "Busy or patterned background"),
        ("✕", "Camera too high or too low"),
        ("✕", "Standing close — inflates the near wheel"),
    ]

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "SET THE SCENE", subtitle: "Good light in, good numbers out.")

                SectionDivider()

                // Column headers
                HStack(spacing: 0) {
                    ColumnHeader(label: "DO", color: Theme.Palette.acc)
                    ColumnHeader(label: "AVOID", color: Theme.Palette.amb)
                }

                SectionDivider()

                HStack(spacing: 0) {
                    ExamplePhoto(
                        name: "SetSceneExample-do",
                        label: "Good example: rider fills the frame head to wheel, against a plain wall."
                    )
                    Rectangle()
                        .fill(Theme.Palette.line)
                        .frame(width: 1)
                    ExamplePhoto(
                        name: "SetSceneExample-avoid",
                        label: "Bad example: small rider in a cluttered street, with a van, bollards and a pram in the shot."
                    )
                }
                .frame(maxWidth: .infinity)

                SectionDivider()

                // Tip rows — interleaved DO/AVOID
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(zip(doItems, avoidItems).enumerated()), id: \.offset) { _, pair in
                            HStack(spacing: 0) {
                                TipCell(icon: pair.0.icon, text: pair.0.text, accent: Theme.Palette.acc)
                                Rectangle()
                                    .fill(Theme.Palette.line)
                                    .frame(width: 1)
                                TipCell(icon: pair.1.icon, text: pair.1.text, accent: Theme.Palette.amb)
                            }
                            SectionDivider()
                        }
                    }
                }

                Spacer(minLength: 0)

                // Same-kit reminder (Plan P1.1) — copy only, no logic. Generic
                // enough to cover both a normal capture and the "match this
                // position" flow, so it needs no second copy path.
                Text("Comparing to an earlier shot? Same kit, same helmet, same bar position — clothing changes your silhouette as much as a small bag does.")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
                    .padding(.horizontal, Theme.Space.screenMargin)
                    .padding(.vertical, Theme.Space.sm)

                AccentButton(label: "GOT IT", action: onContinue)
                    .padding(.horizontal, Theme.Space.screenMargin)
                    .padding(.vertical, Theme.Space.md)
            }
        }
        .hideNavBar()
    }
}

// MARK: - Local sub-views

private struct ColumnHeader: View {
    let label: String
    let color: Color

    var body: some View {
        HStack {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 12)
            Text(label)
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(color)
                .kerning(0.5)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Space.screenMargin)
        .frame(minHeight: 40)
    }
}

private struct ExamplePhoto: View {
    let name: String
    let label: String

    var body: some View {
        // 2:3 matches the asset crop, so head-to-wheel is never trimmed —
        // a cropped DO photo would break its own "fill the frame" rule.
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(Image(name).resizable().scaledToFill())
            .clipped()
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
    }
}

private struct TipCell: View {
    let icon: String
    let text: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.sm) {
            Text(icon)
                .font(Theme.mono(11))
                .foregroundStyle(accent)
                .frame(width: 16)
                // Decorative — the adjoining sentence already says it (Plan
                // AK9); without this VoiceOver reads an odd glyph name
                // ("up down arrow", "cross mark"…) before every tip.
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.mono(12))
                .foregroundStyle(Theme.Palette.fg2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
    }
}
