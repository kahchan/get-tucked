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
    ]

    private let avoidItems: [(icon: String, text: String)] = [
        ("✕", "Cropped feet or head"),
        ("✕", "Backlit or shadows across body"),
        ("✕", "Busy or patterned background"),
        ("✕", "Camera too high or too low"),
    ]

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "SET THE SCENE", subtitle: "Good light in, good numbers out.")

                SectionDivider()

                // Blob stand-ins + column headers
                HStack(spacing: 0) {
                    ColumnHeader(label: "DO", color: Theme.Palette.acc)
                    ColumnHeader(label: "AVOID", color: Theme.Palette.amb)
                }

                SectionDivider()

                // Silhouette blobs
                HStack(spacing: 0) {
                    BlobStandin(tint: Theme.Palette.acc)
                    Rectangle()
                        .fill(Theme.Palette.line)
                        .frame(width: 1)
                    BlobStandin(tint: Theme.Palette.amb)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)

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
                    .font(Theme.mono(11))
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
        .frame(height: 40)
    }
}

private struct BlobStandin: View {
    let tint: Color

    var body: some View {
        ZStack {
            Theme.Palette.bg1
            // Rough cyclist-in-aero silhouette using layered ellipses
            VStack(spacing: 0) {
                // Head
                Ellipse()
                    .fill(tint.opacity(0.15))
                    .stroke(tint.opacity(0.3), lineWidth: 1)
                    .frame(width: 28, height: 28)
                    .offset(x: 12)
                // Torso + arms stretched forward
                Capsule()
                    .fill(tint.opacity(0.15))
                    .stroke(tint.opacity(0.3), lineWidth: 1)
                    .frame(width: 100, height: 38)
                    .rotationEffect(.degrees(-25))
                    .offset(y: -8)
                // Legs
                HStack(spacing: 6) {
                    Capsule()
                        .fill(tint.opacity(0.12))
                        .stroke(tint.opacity(0.25), lineWidth: 1)
                        .frame(width: 18, height: 55)
                        .rotationEffect(.degrees(8))
                    Capsule()
                        .fill(tint.opacity(0.12))
                        .stroke(tint.opacity(0.25), lineWidth: 1)
                        .frame(width: 18, height: 55)
                        .rotationEffect(.degrees(-8))
                }
                .offset(y: -10)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
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
