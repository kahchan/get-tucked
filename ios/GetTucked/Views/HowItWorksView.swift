import SwiftUI

/// Methodology screen (spec §11 — "How this works", non-negotiable, ships in
/// v1). Matches prototype screen 14 (`inspiration/unpacked/template.html`).
/// Reachable from every screen that shows a computed number via
/// `HowItWorksLink`, not from an index menu — Plan E1 removed the hamburger
/// index this plan's original wiring instructions assumed.
struct HowItWorksView: View {
    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "METHODOLOGY", subtitle: "How the number is made.")
                SectionDivider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MethodStep(
                            number: "01", title: "Isolate",
                            // Rider+bike+bags system (2026-07-07 product decision) —
                            // not the prototype's rider-and-bike-only copy.
                            description: "We separate you, your bike, and your bags from everything behind you. The background is thrown away — only your silhouette survives.",
                            showRail: true
                        )
                        MethodStep(
                            number: "02", title: "Scale",
                            description: "Your handlebar width is a known ruler in the frame. It converts pixels into real centimetres — no depth sensor required.",
                            showRail: true
                        )
                        MethodStep(
                            number: "03", title: "Project",
                            description: "We sum the lit silhouette into one figure: your frontal area, in cm² — the surface the wind actually sees.",
                            showRail: false
                        )

                        SectionDivider()
                            .padding(.top, Theme.Space.sm)
                            .padding(.bottom, Theme.Space.lg)

                        Text("WHAT THE NUMBER IS — AND ISN'T")
                            .font(Theme.mono(11, weight: .bold))
                            .foregroundStyle(Theme.Palette.fg3)
                            .kerning(0.3)
                            .padding(.horizontal, Theme.Space.lg)
                            .padding(.bottom, Theme.Space.sm)

                        HStack(alignment: .top, spacing: 0) {
                            FactColumn(
                                tag: "IT IS", color: Theme.Palette.acc, mark: "+",
                                items: [
                                    "A repeatable proxy for drag",
                                    "Sensitive to position, not weather",
                                    "Comparable shot to shot",
                                ]
                            )
                            FactColumn(
                                tag: "IT ISN'T", color: Theme.Palette.amb, mark: "−",
                                items: [
                                    "A wind-tunnel CdA figure",
                                    "A read on surface or yaw drag",
                                    "A watts-saved promise",
                                ]
                            )
                        }
                        .padding(.horizontal, Theme.Space.lg)

                        NoiseFloorNote()
                            .padding(.horizontal, Theme.Space.lg)
                            .padding(.top, Theme.Space.lg)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Be informed,")
                                .font(Theme.heading(30))
                                .foregroundStyle(Theme.Palette.fg)
                            Text("don't guess.")
                                .font(Theme.heading(30))
                                .foregroundStyle(Theme.Palette.acc)
                        }
                        .padding(.horizontal, Theme.Space.lg)
                        .padding(.top, Theme.Space.xl)
                        .padding(.bottom, Theme.Space.xl)
                    }
                    .padding(.top, Theme.Space.lg)
                }
            }
        }
        .hideNavBar()
    }
}

// MARK: - Numbered rail step

private struct MethodStep: View {
    let number: String
    let title: String
    let description: String
    let showRail: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.bg0)
                        .overlay(Circle().stroke(Theme.Palette.acc.opacity(0.4), lineWidth: 1))
                    Text(number)
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundStyle(Theme.Palette.acc)
                }
                .frame(width: 30, height: 30)
                if showRail {
                    Rectangle()
                        .fill(Theme.Palette.line)
                        .frame(width: 1)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text(title.uppercased())
                    .font(Theme.heading(17))
                    .foregroundStyle(Theme.Palette.fg)
                    .kerning(0.2)
                Text(description)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, Theme.Space.lg)
            .padding(.top, 3)
        }
        .padding(.horizontal, Theme.Space.lg)
    }
}

// MARK: - IT IS / IT ISN'T column

private struct FactColumn: View {
    let tag: String
    let color: Color
    let mark: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(tag)
                .font(Theme.mono(9, weight: .bold))
                .foregroundStyle(color)
                .kerning(1.2)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: Theme.Space.sm) {
                    Text(mark)
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundStyle(color)
                    Text(item)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.Palette.fg2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Noise floor note

private struct NoiseFloorNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("THE NOISE FLOOR")
                .font(Theme.mono(9, weight: .bold))
                .foregroundStyle(Theme.Palette.acc)
                .kerning(1.2)
            Text(
                "Every reading carries a ±\(Int(AnalysisMath.uncertaintyFraction * 100))% margin. " +
                "Re-shoot the same position to confirm a change is real — not measurement jitter."
            )
            .font(Theme.mono(10))
            .foregroundStyle(Theme.Palette.fg2)
            // HANDOFF §2.4: the bar-width ruler sits forward of the torso, so
            // absolute area is slightly underestimated — this mostly cancels
            // out when comparing two positions shot the same way.
            Text(
                "The handlebar ruler sits slightly forward of your torso, so the " +
                "absolute number reads a touch low — this mostly cancels out when comparing positions."
            )
            .font(Theme.mono(10))
            .foregroundStyle(Theme.Palette.fg2)
        }
        .padding(Theme.Space.md)
        .background(Theme.Palette.bg1)
        .overlay(Rectangle().stroke(Theme.Palette.line, lineWidth: 1))
    }
}
