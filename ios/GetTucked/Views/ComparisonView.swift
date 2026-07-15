import SwiftUI

struct ComparisonView: View {
    let positionA: Position   // first selected — the reference
    let positionB: Position   // second selected
    @Binding var path: [AppScreen]

    // Panels/table cascade in quickly on appear (N6) — the delta hero below
    // is the deliberate second wow moment and manages its own timing instead.
    @State private var appeared = false
    private let cascadeStagger: Double = 0.025

    private var metricsA: PositionMetrics? { positionA.metrics }
    private var metricsB: PositionMetrics? { positionB.metrics }

    private var areaA: Double? { metricsA?.frontalAreaCm2 }
    private var areaB: Double? { metricsB?.frontalAreaCm2 }
    private var uncertaintyA: Double? { metricsA?.frontalAreaUncertainty }
    private var uncertaintyB: Double? { metricsB?.frontalAreaUncertainty }

    // % change from A to B (positive = B is larger)
    private var deltaPct: Double? {
        guard let a = areaA, let b = areaB, a > 0 else { return nil }
        return ((b - a) / a) * 100
    }

    // A delta smaller than the combined measurement noise can't be told apart
    // from jitter (Plan A4) — default to "distinguishable" when uncertainty
    // isn't available rather than silently hiding a real delta.
    private var isDistinguishable: Bool {
        guard let a = areaA, let b = areaB, let uA = uncertaintyA, let uB = uncertaintyB else { return true }
        return AnalysisMath.isDistinguishable(areaA: a, areaB: b, uncertaintyA: uA, uncertaintyB: uB)
    }

    private var noisePct: Double {
        guard let a = areaA, a > 0, let uA = uncertaintyA, let uB = uncertaintyB else { return 0 }
        return AnalysisMath.combinedNoiseCm2(uncertaintyA: uA, uncertaintyB: uB) / a * 100
    }

    private var isCrossBike: Bool {
        positionA.bike?.id != positionB.bike?.id
    }

    // MARK: - Pose delta (Plan P1.3) — is this even the same position?

    private func shoulderTiltDeg(from points: [Double]?) -> Double? {
        guard let points, points.count == 4 else { return nil }
        return AnalysisMath.shoulderTiltDeg(
            leftShoulder: CGPoint(x: points[0], y: points[1]),
            rightShoulder: CGPoint(x: points[2], y: points[3])
        )
    }

    private var poseDeltaWarning: (text: String, severity: AnalysisMath.PoseDeltaSeverity)? {
        let delta = AnalysisMath.poseAngleDelta(
            shoulderTiltDegA: shoulderTiltDeg(from: metricsA?.headOnSkeletonPoints),
            shoulderTiltDegB: shoulderTiltDeg(from: metricsB?.headOnSkeletonPoints),
            torsoAngleDegA: metricsA?.torsoAngleDeg, torsoAngleDegB: metricsB?.torsoAngleDeg,
            hipAngleDegA: metricsA?.hipAngleDeg, hipAngleDegB: metricsB?.hipAngleDeg
        )
        guard let delta else { return nil }
        return AnalysisMath.poseDeltaWarning(angleDeltaDeg: delta)
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "COMPARE", subtitle: "Same kit, same position as the reference shot?")
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
                        .cascadeIn(index: 0, trigger: appeared, duration: Theme.Motion.base, stagger: cascadeStagger)

                        SectionDivider()

                        if isCrossBike {
                            // Appears with the panels, no special motion of
                            // its own — a warning doesn't perform (N6).
                            CrossBikeWarning()
                                .cascadeIn(index: 0, trigger: appeared, duration: Theme.Motion.base, stagger: cascadeStagger)
                        }

                        // Delta hero — the deliberate secondary wow moment;
                        // manages its own roll/fade timing, not the cascade.
                        if let delta = deltaPct, let a = areaA, let b = areaB {
                            DeltaHero(delta: delta, winner: a < b ? "A" : "B", absoluteDeltaCm2: abs(b - a),
                                      isDistinguishable: isDistinguishable, noisePct: noisePct)
                            if let poseDeltaWarning {
                                PoseDeltaAdvisory(warning: poseDeltaWarning)
                            }
                            SectionDivider()
                        }

                        // Metric diff table
                        DiffTable(metricsA: metricsA, metricsB: metricsB, appeared: appeared, cascadeStagger: cascadeStagger)

                        HowItWorksLink(path: $path)
                            .padding(.horizontal, Theme.Space.screenMargin)
                            .padding(.vertical, Theme.Space.lg)
                    }
                }
            }
        }
        .hideNavBar()
        .onAppear { appeared = true }
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

// MARK: - Pose delta advisory (Plan P1.3)

/// Complementary to the ±3% noise floor `DeltaHero` already renders: that
/// answers "is the area delta real?", this answers "is the position even the
/// same?" — plain text, no banner chrome (unlike `CrossBikeWarning`), same
/// quiet surfacing `shoulderWidthWarning` gets elsewhere.
private struct PoseDeltaAdvisory: View {
    let warning: (text: String, severity: AnalysisMath.PoseDeltaSeverity)

    var body: some View {
        Text(warning.text)
            .font(Theme.mono(11))
            .foregroundStyle(warning.severity == .warn ? Theme.Palette.amb : Theme.Palette.fg2)
            .padding(.horizontal, Theme.Space.screenMargin)
            .padding(.bottom, Theme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                Text("\(AnalysisMath.areaDisplay(area)) cm²")
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
    let isDistinguishable: Bool
    let noisePct: Double

    // The subtitle/within-noise block fades in as its own beat (N6) — for
    // the distinguishable case, after the number lands; for within-noise,
    // together as one plain fade (no ceremony — the absence of motion is
    // the message).
    @State private var subtitleVisible = false

    private var isImprovement: Bool { delta < 0 }
    private var color: Color { isImprovement ? Theme.Palette.acc : Theme.Palette.amb }
    private var sign: String { delta >= 0 ? "+" : "" }

    var body: some View {
        VStack(spacing: 4) {
            if isDistinguishable {
                RollingNumberText(
                    value: delta,
                    format: { "\(self.sign)\(String(format: "%.1f", $0))%" },
                    font: Theme.mono(52, weight: .bold),
                    color: color,
                    tracking: Theme.Typography.tracking(forSize: 52),
                    duration: 0.6,
                    onComplete: {
                        if isImprovement { Haptics.confirm() }
                        withAnimation(Theme.Motion.entrance()) { subtitleVisible = true }
                    }
                )
                Text("\(winner) IS SMALLER · \(Int(absoluteDeltaCm2.rounded())) cm²")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .kerning(0.3)
                    .opacity(subtitleVisible ? 1 : 0)
            } else {
                // Spec: a delta smaller than the noise floor must never be
                // presented as real (Plan A4). No ceremony at all — the ≈
                // block and its lines plain-fade in together, no haptic.
                Group {
                    Text("≈")
                        .font(Theme.mono(52, weight: .bold))
                        .foregroundStyle(Theme.Palette.fg3)
                    Text("WITHIN MEASUREMENT NOISE")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.Palette.fg2)
                        .kerning(0.3)
                    Text("raw: \(sign)\(String(format: "%.1f", delta))% · noise: ±\(String(format: "%.1f", noisePct))%")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.Palette.fg4)
                }
                .opacity(subtitleVisible ? 1 : 0)
                .onAppear {
                    withAnimation(Theme.Motion.entrance()) { subtitleVisible = true }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.lg)
    }
}

// MARK: - Diff table

private struct DiffTable: View {
    let metricsA: PositionMetrics?
    let metricsB: PositionMetrics?
    let appeared: Bool
    let cascadeStagger: Double

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
            .padding(.horizontal, Theme.Space.screenMargin)
            .frame(height: 36)

            SectionDivider()

            // Frontal area (always present) — diff-column values never roll
            // (derived, small, numerous); rows just cascade with the table.
            DiffRow(
                key: "Frontal area",
                valA: metricsA.map { "\(AnalysisMath.areaDisplay($0.frontalAreaCm2)) cm²" },
                valB: metricsB.map { "\(AnalysisMath.areaDisplay($0.frontalAreaCm2)) cm²" },
                diff: diff(metricsA?.frontalAreaCm2, metricsB?.frontalAreaCm2, unit: "cm²", fmt: "%.0f")
            )
            .cascadeIn(index: 1, trigger: appeared, duration: Theme.Motion.base, stagger: cascadeStagger)

            // Shoulder width (head-on pose, optional)
            if metricsA?.shoulderWidthCm != nil || metricsB?.shoulderWidthCm != nil {
                DiffRow(
                    key: "Shoulder width",
                    valA: metricsA?.shoulderWidthCm.map { "\(String(format: "%.1f", $0)) cm" },
                    valB: metricsB?.shoulderWidthCm.map { "\(String(format: "%.1f", $0)) cm" },
                    diff: diff(metricsA?.shoulderWidthCm, metricsB?.shoulderWidthCm, unit: "cm", fmt: "%.1f")
                )
                .cascadeIn(index: 2, trigger: appeared, duration: Theme.Motion.base, stagger: cascadeStagger)
            }

            // Torso angle (side-on, optional)
            if metricsA?.torsoAngleDeg != nil || metricsB?.torsoAngleDeg != nil {
                DiffRow(
                    key: "Torso angle",
                    valA: metricsA?.torsoAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    valB: metricsB?.torsoAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    diff: diff(metricsA?.torsoAngleDeg, metricsB?.torsoAngleDeg, unit: "°", fmt: "%.0f")
                )
                .cascadeIn(index: 3, trigger: appeared, duration: Theme.Motion.base, stagger: cascadeStagger)
            }

            // Hip angle (side-on, optional)
            if metricsA?.hipAngleDeg != nil || metricsB?.hipAngleDeg != nil {
                DiffRow(
                    key: "Hip angle",
                    valA: metricsA?.hipAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    valB: metricsB?.hipAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    diff: diff(metricsA?.hipAngleDeg, metricsB?.hipAngleDeg, unit: "°", fmt: "%.0f")
                )
                .cascadeIn(index: 4, trigger: appeared, duration: Theme.Motion.base, stagger: cascadeStagger)
            }

            // Head drop (side-on, optional) — shown per-side only when that
            // position's own headDropCm came from a real wheelbase ruler
            // (Plan P1.5), not the borrowed frontal scale (spec §3). A side
            // without a ruler shows "—", same as any other missing metric;
            // the diff column is naturally "—" too unless both sides qualify.
            if defensibleHeadDropCm(metricsA) != nil || defensibleHeadDropCm(metricsB) != nil {
                DiffRow(
                    key: "Head drop",
                    valA: defensibleHeadDropCm(metricsA).map { "\(String(format: "%.1f", $0)) cm" },
                    valB: defensibleHeadDropCm(metricsB).map { "\(String(format: "%.1f", $0)) cm" },
                    diff: diff(defensibleHeadDropCm(metricsA), defensibleHeadDropCm(metricsB), unit: "cm", fmt: "%.1f")
                )
                .cascadeIn(index: 5, trigger: appeared, duration: Theme.Motion.base, stagger: cascadeStagger)
            }
        }
    }

    /// nil unless this position's headDropCm was computed from a real
    /// wheelbase ruler — the same defensibility gate RevealStep and
    /// PositionDetailView apply, kept local since only DiffTable needs it.
    private func defensibleHeadDropCm(_ metrics: PositionMetrics?) -> Double? {
        guard let metrics, metrics.sideOnPixelsPerCm != nil else { return nil }
        return metrics.headDropCm
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
            .padding(.horizontal, Theme.Space.screenMargin)
            .frame(height: 44)
            SectionDivider()
        }
    }

    private var diffColor: Color {
        guard let d = diff else { return Theme.Palette.fg4 }
        return d.hasPrefix("+") ? Theme.Palette.amb : Theme.Palette.acc
    }
}
