import SwiftUI

/// Pure geometry/timeline math for `SkeletonOverlay` — kept free of SwiftUI
/// types so it's directly unit-testable (Plan O6).
enum SkeletonTimeline {
    /// Maps a global 0→1 draw progress to one bone's local 0→1 trim. Windows
    /// start `window × stagger` apart and each run for `perBoneDuration`
    /// within the shared timeline — an overlapping cascade (like
    /// `.cascadeIn`), not a strict relay where each bone waits for the last
    /// to finish. Bones sharing a window (e.g. the two frontal upper arms)
    /// share the same start offset and so draw in parallel.
    static func boneTrim(
        window: Int,
        windowCount: Int,
        globalProgress: Double,
        stagger: Double = Theme.Motion.stagger,
        perBoneDuration: Double
    ) -> Double {
        guard windowCount > 0, perBoneDuration > 0 else { return globalProgress }
        let totalDuration = Double(windowCount - 1) * stagger + perBoneDuration
        guard totalDuration > 0 else { return globalProgress }
        let elapsed = min(1, max(0, globalProgress)) * totalDuration
        let boneStart = Double(window) * stagger
        let boneElapsed = elapsed - boneStart
        return min(1, max(0, boneElapsed / perBoneDuration))
    }

    /// A joint's opacity as its bone's trim nears completion — an eased pop
    /// over the last `popFraction` of the bone's own trim window (hard-edged
    /// in form, eased in timing, per Plan N), not a linear reveal across the
    /// whole bone.
    static func jointOpacity(boneTrim: Double, popFraction: Double) -> Double {
        guard popFraction > 0 else { return boneTrim >= 1 ? 1 : 0 }
        // popFraction > 0 guarantees start < 1, so the division below is safe.
        let start = max(0, 1 - popFraction)
        guard boneTrim > start else { return 0 }
        let t = min(1, (boneTrim - start) / (1 - start))
        return t * t * (3 - 2 * t) // smoothstep
    }
}

/// Vision-normalised (0–1, origin bottom-left) → view-space coordinate math.
/// Callers apply the photo's own aspectRatio + scaledToFit first (the same
/// container the photo/matte Image uses), so `SkeletonOverlay`'s own bounds
/// already are the image's fitted rect — no separate letterbox math needed
/// here, unlike `CalibrationTransform`'s aspect-fit.
enum SkeletonGeometry {
    static func point(forUnit unit: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: unit.x * size.width, y: (1 - unit.y) * size.height)
    }
}

/// Hard-edged pose skeleton drawn over the matte (Plan O): 2px straight
/// bones, small square joints — no glow, blur, springs, or scale. Bones draw
/// on via a staggered cascade (`SkeletonTimeline`); callers own the
/// animation by driving `progress` inside `withAnimation`, the same pattern
/// as `.scanReveal`.
struct SkeletonOverlay: View {
    /// `.measured` bones/joints feed a displayed number (spec §3); `.context`
    /// ones (the frontal/side-on arm chains) are explanatory only, so they
    /// draw in a dimmer stroke; `.detail` (torso/legs/shank) is pure
    /// body-shape richness, dimmer still — each step down must be visibly
    /// quieter than the last, so decoration can never read as measurement.
    enum Tier: Equatable {
        case measured
        case context
        case detail

        var color: Color {
            switch self {
            case .measured: Theme.Palette.acc
            case .context: Theme.Palette.fg2
            case .detail: Theme.Palette.fg4
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .measured, .context: 2
            case .detail: 1
            }
        }

        var jointSize: CGFloat {
            switch self {
            case .measured, .context: 8
            case .detail: 6
            }
        }
    }

    struct Bone {
        let from: Int
        let to: Int
        let tier: Tier
        /// Bones sharing a window draw in parallel — the stagger offset is
        /// per-window, not per-bone.
        let window: Int
    }

    /// Joints in Vision-normalised coords (0–1, origin bottom-left).
    let joints: [CGPoint]
    /// Bones to draw; order doesn't matter for layout, only `window` does.
    let bones: [Bone]
    /// 0→1 draw progress; 1 = fully drawn. Callers own the animation.
    var progress: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Motion.base per bone (Plan O4): with the frontal arm chains' 3 windows
    // that's 2×stagger + base ≈ 0.35s — the "≲0.4s, quiet secondary beat"
    // the reveal ceremony calls for.
    private let perBoneDuration: Double = Theme.Motion.base

    private var windowCount: Int {
        (bones.map(\.window).max() ?? 0) + 1
    }

    /// Total wall-clock duration of the full staggered cascade — what
    /// callers pass to `withAnimation(Theme.Motion.travel(_:))` when driving
    /// `progress` from 0→1.
    var totalDrawDuration: Double {
        Double(max(0, windowCount - 1)) * Theme.Motion.stagger + perBoneDuration
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ForEach(Array(bones.enumerated()), id: \.offset) { _, bone in
                    boneView(bone, size: size)
                }
                ForEach(joints.indices, id: \.self) { index in
                    jointView(at: index, size: size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func boneTrim(for bone: Bone) -> Double {
        reduceMotion ? 1 : SkeletonTimeline.boneTrim(
            window: bone.window, windowCount: windowCount,
            globalProgress: progress, perBoneDuration: perBoneDuration
        )
    }

    @ViewBuilder
    private func boneView(_ bone: Bone, size: CGSize) -> some View {
        if joints.indices.contains(bone.from), joints.indices.contains(bone.to) {
            let from = SkeletonGeometry.point(forUnit: joints[bone.from], in: size)
            let to = SkeletonGeometry.point(forUnit: joints[bone.to], in: size)
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .trim(from: 0, to: boneTrim(for: bone))
            .stroke(bone.tier.color, style: StrokeStyle(lineWidth: bone.tier.lineWidth))
        }
    }

    /// Higher tiers must never be visually demoted by a lower-tier bone
    /// sharing their joint (Plan V1).
    private static func tierPriority(_ tier: Tier) -> Int {
        switch tier {
        case .measured: 0
        case .context: 1
        case .detail: 2
        }
    }

    /// A joint pops the moment the first bone touching it reaches it, so a
    /// joint shared by two bones (e.g. the frontal shoulder, which anchors
    /// both the shoulder bar and an arm chain) doesn't wait on the slower
    /// one. When a detail-tier bone shares a joint with a higher tier, the
    /// higher tier wins the joint's size/color — the detail tier can never
    /// visually outrank what it's attached to.
    @ViewBuilder
    private func jointView(at index: Int, size: CGSize) -> some View {
        let touching = bones.filter { $0.from == index || $0.to == index }
            .sorted { Self.tierPriority($0.tier) < Self.tierPriority($1.tier) }
        if !touching.isEmpty {
            let opacity = reduceMotion
                ? 1
                : touching.map {
                    SkeletonTimeline.jointOpacity(boneTrim: boneTrim(for: $0), popFraction: Theme.Motion.fast / perBoneDuration)
                }.max() ?? 0
            if opacity > 0 {
                let tier = touching.first?.tier ?? .measured
                let point = SkeletonGeometry.point(forUnit: joints[index], in: size)
                Rectangle()
                    .fill(tier.color)
                    .frame(width: tier.jointSize, height: tier.jointSize)
                    .overlay(Rectangle().stroke(Theme.Palette.bg0, lineWidth: 1))
                    .position(point)
                    .opacity(opacity)
            }
        }
    }
}

// MARK: - Convenience constructors

extension SkeletonOverlay {
    /// Frontal: shoulder bar (`.measured`, always) plus both arm chains
    /// (`.context`) when `arms` is present — upper arms share window 1,
    /// forearms window 2, so the two sides draw in parallel. `body`
    /// (`.detail`) adds torso sides + pelvis bar to window 1 and upper legs
    /// to window 2, sharing the arm windows deliberately — the cascade gets
    /// denser, not longer (Plan V2); `windowCount` stays 3 either way.
    /// `shoulders` is `[leftShoulderX, leftShoulderY, rightShoulderX,
    /// rightShoulderY]`; `arms` is `[leftElbowX, leftElbowY, leftWristX,
    /// leftWristY, rightElbowX, rightElbowY, rightWristX, rightWristY]`
    /// (matching `PositionMetrics.headOnSkeletonPoints`/`headOnArmPoints`);
    /// `body` is `[leftHipX, leftHipY, rightHipX, rightHipY, leftKneeX,
    /// leftKneeY, rightKneeX, rightKneeY]` (matching `headOnBodyPoints`).
    /// Returns nil on malformed counts — no partial skeletons; a nil `arms`
    /// or `body` simply omits that tier.
    static func frontal(shoulders: [Double], arms: [Double]?, body: [Double]? = nil) -> SkeletonOverlay? {
        guard let shoulderPoints = points(from: shoulders), shoulderPoints.count == 2 else { return nil }

        var joints = shoulderPoints
        var bones = [Bone(from: 0, to: 1, tier: .measured, window: 0)]

        if let arms {
            guard let armPoints = points(from: arms), armPoints.count == 4 else { return nil }
            // joints: 0 leftShoulder, 1 rightShoulder, 2 leftElbow, 3 leftWrist, 4 rightElbow, 5 rightWrist
            joints.append(contentsOf: armPoints)
            bones.append(contentsOf: [
                Bone(from: 0, to: 2, tier: .context, window: 1), // left upper arm
                Bone(from: 2, to: 3, tier: .context, window: 2), // left forearm
                Bone(from: 1, to: 4, tier: .context, window: 1), // right upper arm
                Bone(from: 4, to: 5, tier: .context, window: 2), // right forearm
            ])
        }

        if let body {
            guard let bodyPoints = points(from: body), bodyPoints.count == 4 else { return nil }
            // Indices shift depending on whether arms were appended — compute
            // from joints.count rather than hardcoding.
            let leftHip = joints.count
            let rightHip = joints.count + 1
            let leftKnee = joints.count + 2
            let rightKnee = joints.count + 3
            joints.append(contentsOf: bodyPoints)
            bones.append(contentsOf: [
                Bone(from: 0, to: leftHip, tier: .detail, window: 1), // left torso side
                Bone(from: 1, to: rightHip, tier: .detail, window: 1), // right torso side
                Bone(from: leftHip, to: rightHip, tier: .detail, window: 1), // pelvis bar
                Bone(from: leftHip, to: leftKnee, tier: .detail, window: 2), // left upper leg
                Bone(from: rightHip, to: rightKnee, tier: .detail, window: 2), // right upper leg
            ])
        }

        return SkeletonOverlay(joints: joints, bones: bones)
    }

    /// Side-on: shoulder–hip, hip–knee, shoulder–ear, all `.measured`, each
    /// its own window (no parallel bones). `arm` (`.context` — the reach
    /// line to the bars, explanatory like the frontal arm chains) adds
    /// shoulder→elbow to window 1 and elbow→wrist to window 2. `ankle`
    /// (`.detail` — continues the leg the hip–knee bone ends at) adds
    /// knee→ankle to window 2. Both share windows with the existing bones
    /// deliberately (Plan V3): `windowCount` stays 3, denser not longer.
    /// `points` is `[shoulderX, shoulderY, hipX, hipY, kneeX, kneeY, earX,
    /// earY]` (matching `PositionMetrics.sideOnSkeletonPoints`); `arm` is
    /// `[elbowX, elbowY, wristX, wristY]` (matching `sideOnArmPoints`);
    /// `ankle` is `[ankleX, ankleY]` (matching `sideOnAnklePoint`). Returns
    /// nil on malformed counts.
    static func sideOn(points sideOnPoints: [Double], arm: [Double]? = nil, ankle: [Double]? = nil) -> SkeletonOverlay? {
        guard var joints = points(from: sideOnPoints), joints.count == 4 else { return nil }
        // joints: 0 shoulder, 1 hip, 2 knee, 3 ear
        var bones = [
            Bone(from: 0, to: 1, tier: .measured, window: 0),
            Bone(from: 1, to: 2, tier: .measured, window: 1),
            Bone(from: 0, to: 3, tier: .measured, window: 2),
        ]

        if let arm {
            guard let armPoints = points(from: arm), armPoints.count == 2 else { return nil }
            let elbow = joints.count
            let wrist = joints.count + 1
            joints.append(contentsOf: armPoints)
            bones.append(contentsOf: [
                Bone(from: 0, to: elbow, tier: .context, window: 1),
                Bone(from: elbow, to: wrist, tier: .context, window: 2),
            ])
        }

        if let ankle {
            guard let anklePoints = points(from: ankle), anklePoints.count == 1 else { return nil }
            let ankleIndex = joints.count
            joints.append(contentsOf: anklePoints)
            bones.append(Bone(from: 2, to: ankleIndex, tier: .detail, window: 2))
        }

        return SkeletonOverlay(joints: joints, bones: bones)
    }

    private static func points(from flat: [Double]) -> [CGPoint]? {
        guard !flat.isEmpty, flat.count.isMultiple(of: 2) else { return nil }
        return stride(from: 0, to: flat.count, by: 2).map { CGPoint(x: flat[$0], y: flat[$0 + 1]) }
    }
}

// MARK: - Reveal helper

extension View {
    /// Fades the skeleton in/out at `Motion.fast` — the no-draw-on
    /// appearance PositionDetailView's BONES toggle uses, and what Reduce
    /// Motion collapses RevealStep's draw-on ceremony to as well
    /// (centralised here so call sites get it free).
    func skeletonReveal(visible: Bool) -> some View {
        modifier(SkeletonRevealModifier(visible: visible))
    }
}

private struct SkeletonRevealModifier: ViewModifier {
    let visible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .animation(Theme.Motion.entrance(Theme.Motion.fast), value: visible)
    }
}

// MARK: - Previews

#Preview("SkeletonOverlay — frontal") {
    struct Demo: View {
        @State private var progress: Double = 0

        private var skeleton: SkeletonOverlay? {
            guard var overlay = SkeletonOverlay.frontal(
                shoulders: [0.35, 0.65, 0.65, 0.65],
                arms: [0.28, 0.45, 0.22, 0.25, 0.72, 0.45, 0.78, 0.25],
                body: [0.38, 0.4, 0.62, 0.4, 0.3, 0.15, 0.7, 0.15]
            ) else { return nil }
            overlay.progress = progress
            return overlay
        }

        var body: some View {
            ZStack {
                Rectangle().fill(Theme.Palette.bg1)
                skeleton
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

#Preview("SkeletonOverlay — side-on") {
    struct Demo: View {
        @State private var progress: Double = 0

        private var skeleton: SkeletonOverlay? {
            guard var overlay = SkeletonOverlay.sideOn(
                points: [0.55, 0.55, 0.5, 0.35, 0.45, 0.15, 0.58, 0.62],
                arm: [0.62, 0.42, 0.68, 0.35],
                ankle: [0.43, 0.03]
            ) else { return nil }
            overlay.progress = progress
            return overlay
        }

        var body: some View {
            ZStack {
                Rectangle().fill(Theme.Palette.bg1)
                skeleton
            }
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .padding()
            .background(Theme.Palette.bg0)
            .onAppear {
                withAnimation(Theme.Motion.travel(0.6)) { progress = 1 }
            }
        }
    }
    return Demo()
}
