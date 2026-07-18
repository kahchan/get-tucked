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

                        // Every section below owns its own top gap (Theme.Space.lg)
                        // rather than the preceding divider carrying trailing
                        // padding — one consistent rule for the whole screen's
                        // vertical rhythm instead of spacing living on whichever
                        // side of a divider happened to need it.
                        SectionDivider()

                        Text("WHAT THE NUMBER IS — AND ISN'T")
                            .font(Theme.mono(11, weight: .bold))
                            .foregroundStyle(Theme.Palette.fg3)
                            .kerning(0.3)
                            .padding(.horizontal, Theme.Space.screenMargin)
                            .padding(.top, Theme.Space.lg)
                            .padding(.bottom, Theme.Space.sm)

                        // Stacked, not side-by-side (Kah, 2026-07-10) — two
                        // columns at 11pt type left each list cramped.
                        VStack(alignment: .leading, spacing: Theme.Space.lg) {
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
                        .padding(.horizontal, Theme.Space.screenMargin)

                        NoiseFloorNote()
                            .padding(.horizontal, Theme.Space.screenMargin)
                            .padding(.top, Theme.Space.lg)

                        TimeEstimateNote()
                            .padding(.horizontal, Theme.Space.screenMargin)
                            .padding(.top, Theme.Space.lg)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Be informed,")
                                .font(Theme.heading(30))
                                .foregroundStyle(Theme.Palette.fg)
                                .kerning(Theme.Typography.tracking(forSize: 30))
                            Text("don't guess.")
                                .font(Theme.heading(30))
                                .foregroundStyle(Theme.Palette.acc)
                                .kerning(Theme.Typography.tracking(forSize: 30))
                        }
                        .padding(.horizontal, Theme.Space.screenMargin)
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
            // Optical nudge, not rhythm spacing — aligns the title's cap-height
            // with the circle's vertical centre; closest token is xs (4pt vs
            // the hand-tuned 3pt, imperceptible).
            .padding(.top, Theme.Space.xs)
        }
        .padding(.horizontal, Theme.Space.screenMargin)
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

// MARK: - Time estimate note (Plan U)

/// Explains the TIME IMPACT card's "so what" number (ComparisonView) — the
/// one figure on screen that layers assumptions on top of the raw area
/// measurement, so it earns its own defensibility section (spec §3).
private struct TimeEstimateNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("THE TIME ESTIMATE")
                .font(Theme.mono(9, weight: .bold))
                .foregroundStyle(Theme.Palette.acc)
                .kerning(1.2)
            Text("P = v · (½ · ρ · CdA · v² + Crr · m · g)")
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.fg)
            Text(
                "We take your flat-road speed, work out the power it implies for the " +
                "larger position, then ask how fast that same power pushes the smaller " +
                "one. The time gap over your distance is the estimate."
            )
            .font(Theme.mono(10))
            .foregroundStyle(Theme.Palette.fg2)
            Text(
                "Fixed assumptions: drag coefficient \(EffortModel.assumedCd), rider + " +
                "bike + kit \(Int(EffortModel.assumedMassKg)) kg, rolling resistance " +
                "\(String(format: "%.3f", EffortModel.crr)), sea-level air. Flat course, no wind, equal effort."
            )
            .font(Theme.mono(10))
            .foregroundStyle(Theme.Palette.fg2)
            Text(
                "Slower riders gain more minutes, not fewer: an area cut buys roughly the " +
                "same percentage of speed at any pace, and a slower rider spends longer on " +
                "course for it to add up. Over a fixed distance, aero minutes favour the " +
                "patient."
            )
            .font(Theme.mono(10))
            .foregroundStyle(Theme.Palette.fg2)
        }
        .padding(Theme.Space.md)
        .background(Theme.Palette.bg1)
        .overlay(Rectangle().stroke(Theme.Palette.line, lineWidth: 1))
    }
}
