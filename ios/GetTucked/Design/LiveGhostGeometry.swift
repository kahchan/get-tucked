import SwiftUI

/// Vision-normalised (0–1, origin bottom-left) → view-space coordinate math
/// for the live-capture ghost overlay (Plan P2.2). Distinct from
/// `SkeletonGeometry`, which assumes its container *is* the aspect-fit
/// (letterboxed) image rect — `LiveCameraView`'s preview uses
/// `.resizeAspectFill` (scales to cover the container, crops the overflow),
/// so a reference photo's normalised landmark needs a fill-aware transform:
/// scale-to-fill, then centre-crop offset, the same rule AVFoundation's
/// `.resizeAspectFill` itself uses.
enum LiveGhostGeometry {
    /// `referenceAspect` is the reference photo's own width/height — the
    /// landmarks being mapped are normalised against *that* image, not the
    /// live device's current aspect ratio, so the fill transform has to use
    /// the reference's shape, not the container's.
    static func point(forUnit unit: CGPoint, in containerSize: CGSize, referenceAspect: CGFloat) -> CGPoint {
        guard referenceAspect > 0, containerSize.width > 0, containerSize.height > 0 else {
            return CGPoint(x: unit.x * containerSize.width, y: (1 - unit.y) * containerSize.height)
        }
        // Reference size expressed as (referenceAspect, 1) — only the ratio
        // matters for scale-to-fill, so absolute reference pixel dimensions
        // never need to enter this calculation.
        let scale = max(containerSize.width / referenceAspect, containerSize.height)
        let fittedWidth = referenceAspect * scale
        let fittedHeight = scale
        let offsetX = (containerSize.width - fittedWidth) / 2
        let offsetY = (containerSize.height - fittedHeight) / 2
        return CGPoint(
            x: offsetX + unit.x * fittedWidth,
            y: offsetY + (1 - unit.y) * fittedHeight
        )
    }
}

/// A reference position's precomputed ghost material (Plan P2.1) — built
/// once, off-main, by `CaptureView` when a "Match this position" capture
/// starts, then handed down to `LiveCameraView` for as long as the ghost is
/// visible. Both fields are independently optional (presentational,
/// mirroring the side-on matte's "never blocking" pattern): a missing
/// outline degrades to pose-only, missing landmarks degrade to outline-only.
struct GhostReference {
    let outlineImage: UIImage?
    let skeleton: SkeletonOverlay?
    let referenceAspect: CGFloat
}

/// One reference layer — silhouette outline + faint pose, composited
/// together at a single opacity (Plan P2.2's "combined ghost," never split
/// into sub-toggles). Static, no draw-on: it's a guide, not a performance.
/// Lives only inside `LiveCameraView` during a "Match this position"
/// capture — never enters `RevealStep`'s or `PositionDetailView`'s Inspect
/// ladder (Plan P2.3).
struct GhostOverlay: View {
    /// Ring-shaped mask from `MatteRenderer.outlineMask`, already tinted —
    /// nil degrades to pose-only (segmentation can fail; the pose alone is
    /// still a useful guide, same "presentational, never blocking" pattern
    /// as the side-on matte).
    let outlineImage: UIImage?
    /// Reuses `SkeletonOverlay`'s existing bone topology — nil when the
    /// reference has no stored landmarks for this orientation.
    let skeleton: SkeletonOverlay?
    /// The reference photo's own aspect ratio — mask and landmarks are
    /// normalised against it, not the live container's.
    let referenceAspect: CGFloat
    var opacity: Double = 0.45

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if let outlineImage {
                    // A single image layer, so SwiftUI's own `.fill` content
                    // mode already implements the identical scale-to-fill +
                    // centre-crop `LiveGhostGeometry` derives for points below
                    // — no manual positioning needed for this layer.
                    Image(uiImage: outlineImage)
                        .resizable()
                        .aspectRatio(referenceAspect, contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                }
                if let skeleton {
                    ForEach(Array(skeleton.bones.enumerated()), id: \.offset) { _, bone in
                        boneView(bone, joints: skeleton.joints, size: size)
                    }
                }
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        // Framing guidance over the live feed — nothing here is content a
        // VoiceOver user could act on (Plan AK9).
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func boneView(_ bone: SkeletonOverlay.Bone, joints: [CGPoint], size: CGSize) -> some View {
        if joints.indices.contains(bone.from), joints.indices.contains(bone.to) {
            Path { path in
                path.move(to: LiveGhostGeometry.point(forUnit: joints[bone.from], in: size, referenceAspect: referenceAspect))
                path.addLine(to: LiveGhostGeometry.point(forUnit: joints[bone.to], in: size, referenceAspect: referenceAspect))
            }
            .stroke(Theme.Palette.acc, style: StrokeStyle(lineWidth: 2))
        }
    }
}
