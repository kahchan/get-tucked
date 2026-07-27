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
                    // Plan AB1: one rhythm for the whole page — xl between
                    // sections, lg within a section's groupings, md between
                    // paragraphs — owned here once instead of each section
                    // hand-placing its own top padding.
                    VStack(alignment: .leading, spacing: Theme.Space.xl) {
                        VStack(alignment: .leading, spacing: Theme.Space.lg) {
                            MethodStep(
                                number: "01", title: "Isolate",
                                // Rider+bike+bags system (2026-07-07 product
                                // decision) — not the prototype's
                                // rider-and-bike-only copy.
                                lead: "We separate you, your bike, and your bags from everything behind you.",
                                detail: nil
                            )
                            MethodStep(
                                number: "02", title: "Scale",
                                lead: "Your handlebar width is a known ruler in the frame.",
                                detail: "Pixels become centimetres. No depth sensor needed."
                            )
                            MethodStep(
                                number: "03", title: "Project",
                                lead: "We sum the lit silhouette into one figure: your frontal area, in cm² (the surface the wind actually sees).",
                                detail: nil
                            )
                        }

                        SectionDivider()

                        VStack(alignment: .leading, spacing: Theme.Space.lg) {
                            Text("WHAT THE NUMBER IS, AND ISN'T")
                                .font(Theme.mono(11, weight: .bold))
                                .foregroundStyle(Theme.Palette.fg)
                                .kerning(0.3)

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
                        }
                        .padding(.horizontal, Theme.Space.screenMargin)

                        // Plan AB5: promoted from a bordered card to a full,
                        // acid-led section — this is the payoff/method beat.
                        TimeEstimateSection()
                            .padding(.horizontal, Theme.Space.screenMargin)

                        // Plan AB5: the honest caveat, amber-cued, kept tight
                        // by design — the contrast with the section above it
                        // is the differentiation.
                        NoiseFloorNote()
                            .padding(.horizontal, Theme.Space.screenMargin)

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
                    }
                    .padding(.top, Theme.Space.lg)
                    .padding(.bottom, Theme.Space.xl)
                }
            }
        }
        .hideNavBar()
    }
}

// MARK: - Numbered step

/// Plan AB2: the step number is a large acid eyebrow above its title, with
/// title and body flush left at `screenMargin` — no rail, no indent. Kah,
/// 2026-07-19: "eyebrows only."
private struct MethodStep: View {
    let number: String
    let title: String
    let lead: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(number)
                .font(Theme.mono(28, weight: .bold))
                .foregroundStyle(Theme.Palette.acc)
                .kerning(Theme.Typography.tracking(forSize: 28))
            Text(title.uppercased())
                .font(Theme.heading(17))
                .foregroundStyle(Theme.Palette.fg)
                .kerning(0.2)
            // Plan AB3: lead sentence promoted to `fg`, any secondary
            // sentence stays dimmer — a bright line to open each step, then
            // it settles.
            Text(lead)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.Palette.fg)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg3)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(color)
                .kerning(1.2)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: Theme.Space.sm) {
                    Text(mark)
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundStyle(color)
                    Text(item)
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.Palette.fg2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Noise floor note

/// Stays a compact, amber-cued caveat card (Plan AB5) — tight by design, in
/// deliberate contrast with the full-section treatment above it.
private struct NoiseFloorNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("THE NOISE FLOOR")
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.amb)
                .kerning(1.2)
            // Plan AB9: varied off the "X, not Y" negation used elsewhere.
            Text(
                "Every reading carries a ±\(Int(AnalysisMath.uncertaintyFraction * 100))% margin, so " +
                "re-shoot the same position to tell a real change from ordinary noise."
            )
            .font(Theme.mono(12))
            .foregroundStyle(Theme.Palette.fg2)
            // HANDOFF §2.4: the bar-width ruler sits forward of the torso, so
            // absolute area is slightly underestimated — this mostly cancels
            // out when comparing two positions shot the same way. AI3: moved
            // into TimeEstimateSection's shared Assumptions disclosure.
        }
        .padding(Theme.Space.md)
        .background(Theme.Palette.bg2)
        .overlay(Rectangle().stroke(Theme.Palette.line3, lineWidth: 1))
    }
}

// MARK: - Time estimate section (Plan U, promoted to a full section by AB5)

/// Explains the TIME IMPACT card's "so what" number (ComparisonView) — the
/// one figure on screen that layers assumptions on top of the raw area
/// measurement, so it earns its own defensibility section (spec §3).
private struct TimeEstimateSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            Text("THE TIME ESTIMATE")
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.acc)
                .kerning(0.3)

            FormulaHero()

            Text(
                "We take your flat-road speed, work out the power it implies for the " +
                "larger position, then ask how fast that same power pushes the smaller " +
                "one. The time gap over your distance is the estimate."
            )
            .font(Theme.mono(12))
            .foregroundStyle(Theme.Palette.fg2)

            // AI3: paragraphs 2 and 3 (fixed assumptions, slower-riders-gain-more),
            // plus NoiseFloorNote's handlebar-ruler caveat, live here verbatim —
            // one shared Assumptions disclosure instead of three always-on
            // paragraphs.
            DetailDisclosure(label: "Assumptions") {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    Text(
                        "Fixed assumptions: drag coefficient \(EffortModel.assumedCd), rider + " +
                        "bike + kit \(Int(EffortModel.assumedMassKg)) kg, rolling resistance " +
                        "\(String(format: "%.3f", EffortModel.crr)), sea-level air. Flat course, no wind, equal effort."
                    )
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg2)
                    Text(
                        "Slower riders gain more minutes, not fewer: an area cut buys roughly the " +
                        "same percentage of speed at any pace, and a slower rider spends longer on " +
                        "course for it to add up. Over a fixed distance, aero minutes favour the " +
                        "patient."
                    )
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg2)
                    Text(
                        "The handlebar ruler sits slightly forward of your torso, so the " +
                        "absolute number reads a touch low, though this mostly cancels out when comparing positions."
                    )
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg2)
                }
                .padding(Theme.Space.md)
            }
        }
    }
}

// MARK: - Formula hero (Plan AB6)

/// Dedicated panel for the power equation — the single most
/// technically-reassuring element on the screen, and one of the ~2–3
/// deliberate acid pops for the page (Plan AB4). The glossary shows every
/// symbol's plain meaning outright; tapping a legend row lights that symbol's
/// place(s) in the equation above (Plan AC2), the tap-driven analog of the
/// web formula's hover-link.
private struct FormulaHero: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTerm: String?

    // AI3: two-column grid (three rows of two) instead of six stacked rows,
    // so pairing order still reads glyph-by-glyph left to right, top to bottom.
    private static let legendRows: [[(glyph: String, meaning: String)]] = [
        [("v", "your speed"), ("ρ", "air density")],
        [("CdA", "frontal area × drag"), ("Crr", "rolling resistance")],
        [("m", "you + bike + kit"), ("g", "gravity")],
    ]

    /// A glyph lights to `fg` when its term is selected; otherwise it keeps its
    /// resting color (the aero/rolling color-split).
    private func lit(_ term: String, resting: Color) -> Color {
        selectedTerm == term ? Theme.Palette.fg : resting
    }

    /// One glyph/meaning cell of the legend grid. Shrinks the visible stack
    /// to fit two per row; `contentShape` keeps the HIG tap target at
    /// `Theme.Control.iconTapTarget` regardless of how tight the row reads.
    @ViewBuilder
    private func legendCell(_ symbol: (glyph: String, meaning: String)) -> some View {
        Button {
            let next: String? = selectedTerm == symbol.glyph ? nil : symbol.glyph
            if reduceMotion {
                selectedTerm = next
            } else {
                withAnimation(Theme.Motion.interactive()) { selectedTerm = next }
            }
        } label: {
            HStack(spacing: Theme.Space.sm) {
                // Leading rule marks the selected row; always 2pt so the row
                // doesn't shift when it lights.
                Rectangle()
                    .fill(selectedTerm == symbol.glyph ? Theme.Palette.acc : Color.clear)
                    .frame(width: 2)
                Text(symbol.glyph)
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundStyle(Theme.Palette.acc)
                    .frame(width: 40, alignment: .leading)
                Text(symbol.meaning)
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // HIG minimum tap target, not the glyph's visual size.
            .frame(minHeight: Theme.Control.iconTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Power = speed × (air drag + rolling drag)")
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(Theme.Palette.fg2)
                .kerning(0.2)

            // Color-split teaches the thesis: the aero term (acid) is the half
            // you can change by position; rolling drag (grey) is fixed. Each
            // decodable glyph is its own run so a selected term can light to fg
            // (AC2); v lights in both places it appears.
            (
                Text("P = ").foregroundStyle(Theme.Palette.fg3)
                + Text("v").foregroundStyle(lit("v", resting: Theme.Palette.fg3))
                + Text(" × (½ × ").foregroundStyle(Theme.Palette.fg3)
                + Text("ρ").foregroundStyle(lit("ρ", resting: Theme.Palette.fg3))
                + Text(" × ").foregroundStyle(Theme.Palette.fg3)
                + Text("CdA").foregroundStyle(lit("CdA", resting: Theme.Palette.acc)).underline(true, color: Theme.Palette.acc)
                + Text(" × ").foregroundStyle(Theme.Palette.acc)
                + Text("v²").foregroundStyle(lit("v", resting: Theme.Palette.acc))
                + Text(" + ").foregroundStyle(Theme.Palette.fg3)
                + Text("Crr").foregroundStyle(lit("Crr", resting: Theme.Palette.fg3))
                + Text(" × ").foregroundStyle(Theme.Palette.fg3)
                + Text("m").foregroundStyle(lit("m", resting: Theme.Palette.fg3))
                + Text(" × ").foregroundStyle(Theme.Palette.fg3)
                + Text("g").foregroundStyle(lit("g", resting: Theme.Palette.fg3))
                + Text(")").foregroundStyle(Theme.Palette.fg3)
            )
            .font(Theme.mono(26, weight: .bold))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)

            Text("CdA: your frontal area, the one thing you change.")
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(Theme.Palette.acc)

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                ForEach(Self.legendRows.indices, id: \.self) { row in
                    HStack(spacing: Theme.Space.md) {
                        ForEach(Self.legendRows[row], id: \.glyph) { symbol in
                            legendCell(symbol)
                        }
                    }
                }
            }

            // The real interactive lives in Comparison (real photos, real
            // time impact) — this just hands off to it.
            Button {
                dismiss()
            } label: {
                Text("see it on your own positions →")
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundStyle(Theme.Palette.acc)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Space.lg)
        .background(Theme.Palette.bg2)
        .overlay(Rectangle().stroke(Theme.Palette.line3, lineWidth: 1))
    }
}
