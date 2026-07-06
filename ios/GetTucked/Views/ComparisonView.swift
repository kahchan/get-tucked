import SwiftUI

struct ComparisonView: View {
    let positionA: Position   // first selected — the reference
    let positionB: Position   // second selected

    private var metricsA: PositionMetrics? { positionA.metrics }
    private var metricsB: PositionMetrics? { positionB.metrics }

    private var areaA: Double? { metricsA?.frontalAreaCm2 }
    private var areaB: Double? { metricsB?.frontalAreaCm2 }

    // % change from A to B (positive = B is larger)
    private var deltaPct: Double? {
        guard let a = areaA, let b = areaB, a > 0 else { return nil }
        return ((b - a) / a) * 100
    }

    private var isCrossBike: Bool {
        positionA.bike?.id != positionB.bike?.id
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "COMPARE")
                SectionDivider()

                ScrollView {
                    VStack(spacing: 0) {
                        // 2-up panels
                        HStack(spacing: 0) {
                            PositionPanel(position: positionA, side: "A")
                            Rectangle().fill(Theme.Palette.line).frame(width: 1)
                            PositionPanel(position: positionB, side: "B")
                        }
                        .frame(height: 130)

                        SectionDivider()

                        if isCrossBike {
                            CrossBikeWarning()
                        }

                        // Delta hero
                        if let delta = deltaPct, let a = areaA, let b = areaB {
                            DeltaHero(delta: delta, winner: a < b ? "A" : "B", absoluteDeltaCm2: abs(b - a))
                            SectionDivider()
                        }

                        // Metric diff table
                        DiffTable(metricsA: metricsA, metricsB: metricsB)
                    }
                }
            }
        }
        .hideNavBar()
    }
}

// MARK: - Cross-bike warning

private struct CrossBikeWarning: View {
    var body: some View {
        Text("DIFFERENT BIKES — differences may reflect the bikes, not the rider.")
            .font(Theme.mono(11))
            .foregroundStyle(Theme.Palette.amb)
            .padding(Theme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.bg1)
            .overlay(Rectangle().stroke(Theme.Palette.amb, lineWidth: 1))
    }
}

// MARK: - Position panel

private struct PositionPanel: View {
    let position: Position
    let side: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(side)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.Palette.fg3)
            Text(position.label)
                .font(Theme.mono(13, weight: .bold))
                .foregroundStyle(Theme.Palette.fg)
                .lineLimit(2)
            if let area = position.metrics?.frontalAreaCm2 {
                Text("\(Int(area)) cm²")
                    .font(Theme.mono(24, weight: .bold))
                    .foregroundStyle(Theme.Palette.acc)
            }
            if let bike = position.bike {
                Text(bike.nickname)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .lineLimit(1)
            }
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Palette.bg1)
    }
}

// MARK: - Delta hero

private struct DeltaHero: View {
    let delta: Double
    let winner: String            // "A" or "B" — whichever has the smaller area
    let absoluteDeltaCm2: Double

    private var isImprovement: Bool { delta < 0 }
    private var color: Color { isImprovement ? Theme.Palette.acc : Theme.Palette.amb }
    private var sign: String { delta >= 0 ? "+" : "" }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(sign)\(String(format: "%.1f", delta))%")
                .font(Theme.mono(52, weight: .bold))
                .foregroundStyle(color)
            Text("\(winner) IS SMALLER · \(Int(absoluteDeltaCm2.rounded())) cm²")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.Palette.fg3)
                .kerning(0.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.lg)
    }
}

// MARK: - Diff table

private struct DiffTable: View {
    let metricsA: PositionMetrics?
    let metricsB: PositionMetrics?

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("METRIC")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                Spacer()
                Text("A")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .frame(width: 76, alignment: .trailing)
                Text("B")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .frame(width: 76, alignment: .trailing)
                Text("DIFF")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, Theme.Space.lg)
            .frame(height: 36)

            SectionDivider()

            // Frontal area (always present)
            DiffRow(
                key: "Frontal area",
                valA: metricsA.map { "\(Int($0.frontalAreaCm2)) cm²" },
                valB: metricsB.map { "\(Int($0.frontalAreaCm2)) cm²" },
                diff: diff(metricsA?.frontalAreaCm2, metricsB?.frontalAreaCm2, unit: "cm²", fmt: "%.0f")
            )

            // Shoulder width (head-on pose, optional)
            if metricsA?.shoulderWidthCm != nil || metricsB?.shoulderWidthCm != nil {
                DiffRow(
                    key: "Shoulder width",
                    valA: metricsA?.shoulderWidthCm.map { "\(String(format: "%.1f", $0)) cm" },
                    valB: metricsB?.shoulderWidthCm.map { "\(String(format: "%.1f", $0)) cm" },
                    diff: diff(metricsA?.shoulderWidthCm, metricsB?.shoulderWidthCm, unit: "cm", fmt: "%.1f")
                )
            }

            // Torso angle (side-on, optional)
            if metricsA?.torsoAngleDeg != nil || metricsB?.torsoAngleDeg != nil {
                DiffRow(
                    key: "Torso angle",
                    valA: metricsA?.torsoAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    valB: metricsB?.torsoAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    diff: diff(metricsA?.torsoAngleDeg, metricsB?.torsoAngleDeg, unit: "°", fmt: "%.0f")
                )
            }

            // Hip angle (side-on, optional)
            if metricsA?.hipAngleDeg != nil || metricsB?.hipAngleDeg != nil {
                DiffRow(
                    key: "Hip angle",
                    valA: metricsA?.hipAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    valB: metricsB?.hipAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    diff: diff(metricsA?.hipAngleDeg, metricsB?.hipAngleDeg, unit: "°", fmt: "%.0f")
                )
            }

            // Head drop (side-on, optional)
            if metricsA?.headDropCm != nil || metricsB?.headDropCm != nil {
                DiffRow(
                    key: "Head drop",
                    valA: metricsA?.headDropCm.map { "\(String(format: "%.1f", $0)) cm" },
                    valB: metricsB?.headDropCm.map { "\(String(format: "%.1f", $0)) cm" },
                    diff: diff(metricsA?.headDropCm, metricsB?.headDropCm, unit: "cm", fmt: "%.1f")
                )
            }
        }
    }

    private func diff(_ a: Double?, _ b: Double?, unit: String, fmt: String) -> String? {
        guard let a, let b else { return nil }
        let d = b - a
        let sign = d >= 0 ? "+" : ""
        return "\(sign)\(String(format: fmt, d)) \(unit)"
    }
}

private struct DiffRow: View {
    let key: String
    let valA: String?
    let valB: String?
    let diff: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(key.uppercased())
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg2)
                    .kerning(0.2)
                Spacer()
                Text(valA ?? "—")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg)
                    .frame(width: 76, alignment: .trailing)
                Text(valB ?? "—")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg)
                    .frame(width: 76, alignment: .trailing)
                Text(diff ?? "—")
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundStyle(diffColor)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, Theme.Space.lg)
            .frame(height: 44)
            SectionDivider()
        }
    }

    private var diffColor: Color {
        guard let d = diff else { return Theme.Palette.fg4 }
        return d.hasPrefix("+") ? Theme.Palette.amb : Theme.Palette.acc
    }
}
