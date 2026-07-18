import SwiftUI

/// Pure geometry for `DimensionOverlay` — kept free of SwiftUI types (beyond
/// `CGPoint`/`CGSize`/`CGRect`, which `SkeletonGeometry` already treats as
/// plain value types) so it's directly unit-testable, mirroring
/// `SkeletonOverlay`'s split (Plan X1).
enum DimensionGeometry {
    struct TickEndpoints: Equatable {
        let a: CGPoint
        let b: CGPoint
    }

    static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Top-left-origin unit coords (0–1, y-down) → view-space point — the
    /// dimension lines' own convention (Plan Z1). `handlebarTapPoints` /
    /// `wheelTapPoints` / `sideOnTapPoints` come from
    /// `CalibrationTransform.unitPoint(forScreen:in:)`, which is already
    /// screen space (no flip) — deliberately NOT `SkeletonGeometry.point
    /// (forUnit:)`, which flips y for Vision's bottom-left pose-landmark
    /// convention. Borrowing that flip here was Plan X's shipped bug: every
    /// dimension line rendered vertically mirrored.
    static func point(forTopLeftUnit unit: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    /// A short tick perpendicular to the `lineFrom`→`lineTo` segment,
    /// centred on `point` (one of the segment's own terminals in practice).
    /// Degenerates to a zero-length tick at `point` if the segment itself
    /// has zero length (can't derive a perpendicular from nothing).
    static func tickEndpoints(at point: CGPoint, lineFrom: CGPoint, lineTo: CGPoint, length: CGFloat) -> TickEndpoints {
        let dx = lineTo.x - lineFrom.x
        let dy = lineTo.y - lineFrom.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0 else { return TickEndpoints(a: point, b: point) }
        let ux = dx / len, uy = dy / len
        let px = -uy, py = ux // perpendicular unit vector
        let half = length / 2
        return TickEndpoints(
            a: CGPoint(x: point.x + px * half, y: point.y + py * half),
            b: CGPoint(x: point.x - px * half, y: point.y - py * half)
        )
    }

    /// The four diagonals a leader line can run along — screen space
    /// (origin top-left, y grows downward), so "up" is negative y.
    enum LeaderDirection: CaseIterable {
        case downRight, downLeft, upRight, upLeft

        var unit: CGPoint {
            let k: CGFloat = 1 / CGFloat(2).squareRoot()
            switch self {
            case .downRight: return CGPoint(x: k, y: k)
            case .downLeft: return CGPoint(x: -k, y: k)
            case .upRight: return CGPoint(x: k, y: -k)
            case .upLeft: return CGPoint(x: -k, y: -k)
            }
        }
    }

    /// The leader's far end — always exactly `runLength` away at 45°
    /// (`|dx| == |dy|` by construction, both derived from the same `k`).
    static func leaderEnd(from point: CGPoint, direction: LeaderDirection, runLength: CGFloat) -> CGPoint {
        CGPoint(x: point.x + direction.unit.x * runLength, y: point.y + direction.unit.y * runLength)
    }

    /// The callout box's top-left origin, given that its corner *nearest*
    /// the leader's start sits at `leaderEnd` and the box extends away from
    /// the leader direction (e.g. `.upLeft` → the box's bottom-right corner
    /// is `leaderEnd`, and the box occupies the rect up-and-left of it).
    static func boxOrigin(leaderEnd: CGPoint, direction: LeaderDirection, boxSize: CGSize) -> CGPoint {
        switch direction {
        case .downRight: return leaderEnd
        case .downLeft: return CGPoint(x: leaderEnd.x - boxSize.width, y: leaderEnd.y)
        case .upRight: return CGPoint(x: leaderEnd.x, y: leaderEnd.y - boxSize.height)
        case .upLeft: return CGPoint(x: leaderEnd.x - boxSize.width, y: leaderEnd.y - boxSize.height)
        }
    }

    static func boxRect(leaderEnd: CGPoint, direction: LeaderDirection, boxSize: CGSize) -> CGRect {
        CGRect(origin: boxOrigin(leaderEnd: leaderEnd, direction: direction, boxSize: boxSize), size: boxSize)
    }

    private static func overflow(_ rect: CGRect, bounds: CGSize) -> CGFloat {
        max(0, -rect.minX) + max(0, -rect.minY) + max(0, rect.maxX - bounds.width) + max(0, rect.maxY - bounds.height)
    }

    /// Picks whichever diagonal keeps the callout box fully inside `bounds`.
    /// When several directions fit, prefers down-right, then down-left,
    /// up-right, up-left — a stable, arbitrary tie-break so the same input
    /// always renders the same way. When none fits exactly (degenerate tiny
    /// bounds), picks whichever overflows least, rather than returning
    /// something undefined.
    static func chooseLeaderDirection(from point: CGPoint, boxSize: CGSize, bounds: CGSize, runLength: CGFloat) -> LeaderDirection {
        let scored = LeaderDirection.allCases.map { direction -> (LeaderDirection, CGFloat) in
            let end = leaderEnd(from: point, direction: direction, runLength: runLength)
            let rect = boxRect(leaderEnd: end, direction: direction, boxSize: boxSize)
            return (direction, overflow(rect, bounds: bounds))
        }
        // `min(by:)` returns the first minimal element, which preserves
        // LeaderDirection.allCases' declared order as the tie-break.
        return scored.min { $0.1 < $1.1 }!.0
    }

    /// "780 MM" — the entered/derived spec value, not a live re-measure.
    static func calloutLabel(mm: Double) -> String {
        "\(Int(mm.rounded())) MM"
    }

    /// A layout-time estimate of the callout box's rendered size, used both
    /// to pick the leader direction and as the box's actual `.frame` (so the
    /// two never disagree) — monospace text at a fixed size makes a
    /// per-character width estimate reliable enough for this purpose.
    static func calloutBoxSize(label: String, fontSize: CGFloat, padding: CGFloat) -> CGSize {
        let charWidth = fontSize * 0.62
        let width = CGFloat(label.count) * charWidth + 2 * padding
        let height = fontSize * 1.35 + 2 * padding
        return CGSize(width: width, height: height)
    }
}

/// Hard-edged engineering-drawing dimension lines over the matte (Plan X):
/// a dotted line between two tapped hard points, short perpendicular end
/// ticks, and a solid 45° leader to an mm callout box. Draws on via
/// `progress` (0→1), the same caller-owned-animation pattern as
/// `SkeletonOverlay` — the dotted line trims across the whole range; the
/// leader + callout box pop together over the tail, via the same
/// `SkeletonTimeline.jointOpacity` smoothstep the skeleton's joints use, so
/// the box reads as *caused by* the line finishing (§13's causality beat).
struct DimensionOverlay: View {
    struct Dimension: Equatable {
        let unitFrom: CGPoint
        let unitTo: CGPoint
        let valueMm: Double
    }

    let dimensions: [Dimension]
    /// 0→1 draw progress; 1 = fully drawn (the no-draw-on default, same as
    /// `SkeletonOverlay.progress`, for BONES-toggle call sites that don't
    /// want a ceremony).
    var progress: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let tickLength: CGFloat = 6
    private static let leaderRun: CGFloat = 36
    private static let fontSize: CGFloat = 9
    private static let boxPadding: CGFloat = 4
    // Same ratio SkeletonOverlay's joints use (Motion.fast / a Motion.base
    // travel) — the pop occupies the last ~60% of the line's own trim, a
    // quick eased flourish at the tail rather than a slow simultaneous fade.
    private static let popFraction: Double = Theme.Motion.fast / Theme.Motion.base

    private var trim: Double { reduceMotion ? 1 : progress }

    private var popOpacity: Double {
        reduceMotion ? 1 : SkeletonTimeline.jointOpacity(boneTrim: trim, popFraction: Self.popFraction)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ForEach(dimensions.indices, id: \.self) { index in
                    dimensionView(dimensions[index], size: size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func dimensionView(_ dimension: Dimension, size: CGSize) -> some View {
        let from = DimensionGeometry.point(forTopLeftUnit: dimension.unitFrom, in: size)
        let to = DimensionGeometry.point(forTopLeftUnit: dimension.unitTo, in: size)
        let mid = DimensionGeometry.midpoint(from, to)
        let label = DimensionGeometry.calloutLabel(mm: dimension.valueMm)
        let boxSize = DimensionGeometry.calloutBoxSize(label: label, fontSize: Self.fontSize, padding: Self.boxPadding)
        let direction = DimensionGeometry.chooseLeaderDirection(from: mid, boxSize: boxSize, bounds: size, runLength: Self.leaderRun)
        let leaderEnd = DimensionGeometry.leaderEnd(from: mid, direction: direction, runLength: Self.leaderRun)
        let boxOrigin = DimensionGeometry.boxOrigin(leaderEnd: leaderEnd, direction: direction, boxSize: boxSize)
        let boxCenter = CGPoint(x: boxOrigin.x + boxSize.width / 2, y: boxOrigin.y + boxSize.height / 2)
        let fromTick = DimensionGeometry.tickEndpoints(at: from, lineFrom: from, lineTo: to, length: Self.tickLength)
        let toTick = DimensionGeometry.tickEndpoints(at: to, lineFrom: from, lineTo: to, length: Self.tickLength)

        ZStack {
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .trim(from: 0, to: trim)
            .stroke(Theme.Palette.amb, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

            // The start tick is already "there" the instant the line begins
            // (trim 0 already touches it); the end tick pops as the line
            // reaches it, same tail window as the leader/box.
            if trim > 0 {
                tickPath(fromTick).stroke(Theme.Palette.amb, lineWidth: 1)
            }
            if popOpacity > 0 {
                tickPath(toTick).stroke(Theme.Palette.amb, lineWidth: 1).opacity(popOpacity)

                Path { path in
                    path.move(to: mid)
                    path.addLine(to: leaderEnd)
                }
                .stroke(Theme.Palette.amb, lineWidth: 1)
                .opacity(popOpacity)

                Text(label)
                    .font(Theme.mono(Self.fontSize, weight: .bold))
                    .foregroundStyle(Theme.Palette.amb)
                    .frame(width: boxSize.width, height: boxSize.height)
                    .background(Theme.Palette.bg0.opacity(0.72))
                    .overlay(Rectangle().stroke(Theme.Palette.amb, lineWidth: 1))
                    .position(boxCenter)
                    .opacity(popOpacity)
            }
        }
    }

    private func tickPath(_ endpoints: DimensionGeometry.TickEndpoints) -> Path {
        Path { path in
            path.move(to: endpoints.a)
            path.addLine(to: endpoints.b)
        }
    }
}

// MARK: - Convenience constructors

extension DimensionOverlay {
    /// From a `Position`-style flattened `[x0, y0, x1, y1]` unit-coord array
    /// (`handlebarTapPoints`/`wheelTapPoints`/`sideOnTapPoints`'s storage
    /// convention) plus its mm value. Each dimension degrades independently
    /// — nil unless *both* the points and the mm value are present, per
    /// Plan X's no-partial-annotation rule (never a line with no number, or
    /// a number with no line).
    static func dimension(unitPoints: [Double]?, mm: Double?) -> Dimension? {
        guard let unitPoints, unitPoints.count == 4, let mm else { return nil }
        return Dimension(
            unitFrom: CGPoint(x: unitPoints[0], y: unitPoints[1]),
            unitTo: CGPoint(x: unitPoints[2], y: unitPoints[3]),
            valueMm: mm
        )
    }

    /// From a live two-point `[CGPoint]` (CaptureView's in-flight tap state,
    /// before it's flattened for storage). Same degrade rule.
    static func dimension(points: [CGPoint], mm: Double?) -> Dimension? {
        guard points.count == 2, let mm else { return nil }
        return Dimension(unitFrom: points[0], unitTo: points[1], valueMm: mm)
    }
}

// MARK: - Previews

#Preview("DimensionOverlay") {
    struct Demo: View {
        @State private var progress: Double = 0

        var body: some View {
            ZStack {
                Rectangle().fill(Theme.Palette.bg1)
                DimensionOverlay(
                    dimensions: [
                        DimensionOverlay.Dimension(unitFrom: CGPoint(x: 0.2, y: 0.6), unitTo: CGPoint(x: 0.8, y: 0.6), valueMm: 780),
                        DimensionOverlay.Dimension(unitFrom: CGPoint(x: 0.35, y: 0.05), unitTo: CGPoint(x: 0.35, y: 0.35), valueMm: 622),
                    ],
                    progress: progress
                )
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .padding()
            .background(Theme.Palette.bg0)
            .onAppear {
                withAnimation(Theme.Motion.travel(0.6)) { progress = 1 }
            }
        }
    }
    return Demo()
}
