import SwiftUI

struct ComparisonView: View {
    let positionA: Position   // baseline (lower area, shown left)
    let positionB: Position   // comparison

    private var metricsA: PositionMetrics? { positionA.metrics }
    private var metricsB: PositionMetrics? { positionB.metrics }

    private var areaA: Double? { metricsA?.frontalAreaCm2 }
    private var areaB: Double? { metricsB?.frontalAreaCm2 }

    // % change from A to B (positive = B is larger)
    private var deltaPct: Double? {
        guard let a = areaA, let b = areaB, a > 0 else { return nil }
        return ((b - a) / a) * 100
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

                        // Delta hero
                        if let delta = deltaPct {
                            DeltaHero(delta: delta)
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

// MARK: - Position panel

private struct PositionPanel: View {
    let position: Position
    let side: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(side)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.Palette.fg4)
            Text(position.label)
                .font(Theme.mono(13, weight: .bold))
                .foregroundStyle(Theme.Palette.fg)
                .lineLimit(2)
            if let area = position.metrics?.frontalAreaCm2 {
                Text("\(Int(area)) cm²")
                    .font(Theme.mono(20, weight: .bold))
                    .foregroundStyle(Theme.Palette.acc)
            }
            if let bike = position.bike {
                Text(bike.nickname)
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.Palette.fg4)
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

    private var isImprovement: Bool { delta < 0 }
    private var color: Color { isImprovement ? Theme.Palette.acc : Theme.Palette.amb }
    private var sign: String { delta >= 0 ? "+" : "" }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(sign)\(String(format: "%.1f", delta))%")
                .font(Theme.mono(52, weight: .bold))
                .foregroundStyle(color)
            Text(isImprovement ? "SMALLER FRONTAL AREA" : "LARGER FRONTAL AREA")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.Palette.fg4)
                .kerning(0.5)
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
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.Palette.fg4)
                Spacer()
                Text("A")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.Palette.fg4)
                    .frame(width: 72, alignment: .trailing)
                Text("B")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.Palette.fg4)
                    .frame(width: 72, alignment: .trailing)
                Text("DIFF")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.Palette.fg4)
                    .frame(width: 64, alignment: .trailing)
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
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.Palette.fg3)
                    .kerning(0.2)
                Spacer()
                Text(valA ?? "—")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg2)
                    .frame(width: 72, alignment: .trailing)
                Text(valB ?? "—")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg2)
                    .frame(width: 72, alignment: .trailing)
                Text(diff ?? "—")
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundStyle(diffColor)
                    .frame(width: 64, alignment: .trailing)
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
