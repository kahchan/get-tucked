import SwiftUI

/// Pure physics for `PinchZoomModifier` (Plan R3) — kept separate so it's
/// directly unit-testable, same split as `CalibrationTransform`.
enum PinchPhysics {
    /// Apple's rubber-band function (the *Designing Fluid Interfaces* /
    /// UIScrollView constant): resists `overshoot` past a legal boundary,
    /// approaching but never reaching `±dimension` as the overshoot grows.
    /// Monotonic, sign-preserving, and ~0 near `overshoot == 0` — the touch
    /// still visibly tracks the finger, just with diminishing returns.
    static func rubberband(overshoot: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
        guard dimension > 0 else { return 0 }
        let sign: CGFloat = overshoot < 0 ? -1 : 1
        let magnitude = abs(overshoot)
        return sign * (magnitude * dimension * constant) / (dimension + constant * magnitude)
    }

    /// A gesture's raw per-second velocity, expressed as a multiple of the
    /// distance still to travel (skill §5) — the unitless form
    /// `Animation.interpolatingSpring(initialVelocity:)` expects. Zero when
    /// there's no distance left to seed (current == target already).
    static func normalizedVelocity(gestureVelocity: CGFloat, current: CGFloat, target: CGFloat) -> Double {
        let distance = Double(target - current)
        guard abs(distance) > 0.001 else { return 0 }
        return Double(gestureVelocity) / distance
    }

    /// The pan offset that keeps the content point under `focal` pinned to the
    /// same screen spot as scale goes `scale0 → newScale` (Plan AA) — this is
    /// what makes a pinch zoom toward the fingers instead of ballooning from
    /// the frame centre. `focal`, `offset0`, and the result are all vectors
    /// relative to the container centre (the anchor `scaleEffect` uses).
    ///
    /// Screen position of a content point q (relative to centre, at scale 1)
    /// is `offset + scale·q`. The focal content point is fixed at
    /// `q = (focal − offset0) / scale0`, so to keep it under `focal` after
    /// scaling: `offset1 = focal − newScale·q`.
    static func focalOffset(scale0: CGFloat, offset0: CGSize, newScale: CGFloat, focal: CGSize) -> CGSize {
        guard scale0 > 0 else { return offset0 }
        let ratio = newScale / scale0
        return CGSize(
            width: focal.width - ratio * (focal.width - offset0.width),
            height: focal.height - ratio * (focal.height - offset0.height)
        )
    }
}

/// Pinch-to-zoom + pan-once-zoomed for analysis images (Kah, on-device
/// follow-up to Plan O) — the whole photo/matte/skeleton composite zooms as
/// one aligned unit so a rider can inspect matte/skeleton quality up close.
/// Panning is clamped so the image can never be dragged fully out of view;
/// zoom is capped at `maxZoom`. The pan gesture only engages once zoomed in
/// (`GestureMask.none` otherwise) so an unzoomed image never steals the
/// enclosing ScrollView's vertical drag. Double-tap resets.
///
/// R3: past a legal boundary, the live gesture resists progressively
/// (`PinchPhysics.rubberband`) rather than hard-clamping or free-running;
/// on release, a snap-back seeds `interpolatingSpring` with the gesture's
/// own velocity (skill §5) so there's no visible seam between finger-driven
/// and animation-driven motion. No momentum-projected panning (skill §6,
/// decided against) — this is an inspection surface, not a scroll surface.
private struct PinchZoomModifier: ViewModifier {
    var maxZoom: CGFloat
    // R1.4: lets a call site (GhostCompareOverlay's draw-in ceremony) know
    // the moment a pinch/pan actually starts, so it can snap its own
    // unrelated ceremony to done rather than let the two motions compete
    // for attention. No-op default — RevealStep/PositionDetailView don't
    // need it.
    var onGestureBegan: () -> Void = {}

    @State private var zoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    // Per-gesture baselines, captured on the first change of a pinch/pan and
    // cleared on end (Plan AA). Continuous @State commits — NOT a GestureState
    // multiplier — because a multiplier that resets to 1 on release while the
    // committed scale animates up from its old value is exactly what made the
    // release visibly jump (the old model's flaw).
    @State private var pinchBaseScale: CGFloat?
    @State private var pinchBaseOffset: CGSize = .zero
    // The pinch focal point, relative to the container centre — the content
    // point here stays under the fingers as the scale changes.
    @State private var pinchFocal: CGSize = .zero
    @State private var panBaseOffset: CGSize?
    // Read passively via a `.background` GeometryReader (below) rather than
    // wrapping `content` in a GeometryReader directly — a GeometryReader has
    // no intrinsic size of its own, so using it as the primary container
    // collapsed the photo to near-zero height inside the enclosing
    // ScrollView. `.background` takes on content's own already-resolved
    // size without influencing it.
    @State private var containerSize: CGSize = .zero

    private var isZoomed: Bool { zoomScale > 1.01 }
    // Response tuned to the skill's own sheet-drawer value (R2's precedent);
    // dampingFraction 1.0 (via Theme.Motion.interactive) stays critically
    // damped even when seeded with velocity — a fast flick settles quickly
    // but never overshoots past the target.
    private let springResponse: Double = 0.35
    private let doubleTapZoom: CGFloat = 2.5

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { containerSize = proxy.size }
                        .onChange(of: proxy.size) { _, newSize in containerSize = newSize }
                }
            )
            .scaleEffect(zoomScale)
            .offset(x: panOffset.width, y: panOffset.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(magnifyGesture)
            .highPriorityGesture(panGesture, including: isZoomed ? .all : .none)
            .gesture(doubleTapGesture)
    }

    // MARK: - Pinch (focal-anchored, continuous commit)

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                onGestureBegan()
                if pinchBaseScale == nil {
                    pinchBaseScale = zoomScale
                    pinchBaseOffset = panOffset
                    pinchFocal = CGSize(
                        width: (value.startAnchor.x - 0.5) * containerSize.width,
                        height: (value.startAnchor.y - 0.5) * containerSize.height
                    )
                }
                let base = pinchBaseScale ?? zoomScale
                let resisted = resistedZoom(base * value.magnification)
                zoomScale = resisted
                let solved = PinchPhysics.focalOffset(
                    scale0: base, offset0: pinchBaseOffset, newScale: resisted, focal: pinchFocal
                )
                panOffset = clampedOffset(solved, zoom: resisted, containerSize: containerSize)
            }
            .onEnded { value in
                let base = pinchBaseScale ?? zoomScale
                pinchBaseScale = nil
                let raw = base * value.magnification
                let target = min(maxZoom, max(1, raw))
                let solved = PinchPhysics.focalOffset(
                    scale0: base, offset0: pinchBaseOffset, newScale: target, focal: pinchFocal
                )
                let targetOffset = clampedOffset(solved, zoom: target, containerSize: containerSize)
                // In-bounds: the finger already placed the image here (the live
                // commit above), so settle instantly — animating from a
                // baseline is what used to make release jump. Only a
                // rubber-banded overshoot springs back, seeded with velocity.
                if raw >= 1, raw <= maxZoom {
                    zoomScale = target
                    panOffset = targetOffset
                } else {
                    let seed = PinchPhysics.normalizedVelocity(
                        gestureVelocity: value.velocity, current: raw, target: target
                    )
                    withAnimation(.interpolatingSpring(duration: springResponse, bounce: 0, initialVelocity: seed)) {
                        zoomScale = target
                        panOffset = targetOffset
                    }
                }
            }
    }

    // MARK: - Pan (continuous commit, only once zoomed)

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                onGestureBegan()
                if panBaseOffset == nil { panBaseOffset = panOffset }
                let base = panBaseOffset ?? panOffset
                let candidate = CGSize(
                    width: base.width + value.translation.width,
                    height: base.height + value.translation.height
                )
                panOffset = resistedPan(candidate)
            }
            .onEnded { value in
                let base = panBaseOffset ?? panOffset
                panBaseOffset = nil
                let raw = CGSize(
                    width: base.width + value.translation.width,
                    height: base.height + value.translation.height
                )
                let clamped = clampedOffset(raw, zoom: zoomScale, containerSize: containerSize)
                let overshootWidth = raw.width - clamped.width
                let overshootHeight = raw.height - clamped.height
                if overshootWidth == 0, overshootHeight == 0 {
                    panOffset = clamped
                } else {
                    // One shared curve for both axes (they always settle
                    // together); the seed comes from whichever axis overshot
                    // more — the dominant direction of the flick.
                    let seed: Double = abs(overshootWidth) >= abs(overshootHeight)
                        ? PinchPhysics.normalizedVelocity(
                            gestureVelocity: value.velocity.width, current: raw.width, target: clamped.width
                          )
                        : PinchPhysics.normalizedVelocity(
                            gestureVelocity: value.velocity.height, current: raw.height, target: clamped.height
                          )
                    withAnimation(.interpolatingSpring(duration: springResponse, bounce: 0, initialVelocity: seed)) {
                        panOffset = clamped
                    }
                }
            }
    }

    // MARK: - Double-tap: zoom in at the tap point, or reset if already zoomed

    private var doubleTapGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                if isZoomed {
                    withAnimation(Theme.Motion.interactive(springResponse)) {
                        zoomScale = 1
                        panOffset = .zero
                    }
                } else {
                    let focal = CGSize(
                        width: value.location.x - containerSize.width / 2,
                        height: value.location.y - containerSize.height / 2
                    )
                    let solved = PinchPhysics.focalOffset(
                        scale0: 1, offset0: .zero, newScale: doubleTapZoom, focal: focal
                    )
                    let target = clampedOffset(solved, zoom: doubleTapZoom, containerSize: containerSize)
                    withAnimation(Theme.Motion.interactive(springResponse)) {
                        zoomScale = doubleTapZoom
                        panOffset = target
                    }
                }
            }
    }

    // MARK: - Physics helpers

    /// Live rubber-band resistance while pinching past `1...maxZoom` — the
    /// touch still tracks the finger, just with diminishing returns, rather
    /// than hard-freezing at the boundary (skill §9). Returns an absolute
    /// scale (not a delta).
    private func resistedZoom(_ candidate: CGFloat) -> CGFloat {
        if candidate < 1 {
            return 1 + PinchPhysics.rubberband(overshoot: candidate - 1, dimension: 1)
        } else if candidate > maxZoom {
            return maxZoom + PinchPhysics.rubberband(overshoot: candidate - maxZoom, dimension: 1)
        }
        return candidate
    }

    /// Live rubber-band resistance while panning past the legal (clamped)
    /// range, same shape as `resistedZoom`. Returns an absolute offset.
    private func resistedPan(_ candidate: CGSize) -> CGSize {
        let clamped = clampedOffset(candidate, zoom: zoomScale, containerSize: containerSize)
        let dimensionX = max(containerSize.width, 1)
        let dimensionY = max(containerSize.height, 1)
        return CGSize(
            width: clamped.width + PinchPhysics.rubberband(overshoot: candidate.width - clamped.width, dimension: dimensionX),
            height: clamped.height + PinchPhysics.rubberband(overshoot: candidate.height - clamped.height, dimension: dimensionY)
        )
    }

    /// Keeps the zoomed image from panning fully out of view — max travel in
    /// each axis is half the extra size the zoom adds over the container.
    private func clampedOffset(_ offset: CGSize, zoom: CGFloat, containerSize: CGSize) -> CGSize {
        guard zoom > 1 else { return .zero }
        let maxX = containerSize.width * (zoom - 1) / 2
        let maxY = containerSize.height * (zoom - 1) / 2
        return CGSize(
            width: min(maxX, max(-maxX, offset.width)),
            height: min(maxY, max(-maxY, offset.height))
        )
    }
}

extension View {
    /// Pinch-to-zoom + pan-once-zoomed, double-tap to reset. See
    /// `PinchZoomModifier`. Give the call site an `.id()` keyed on whatever
    /// distinguishes one photo from another (e.g. FRONTAL vs SIDE-ON) so
    /// switching photos resets zoom instead of carrying over a now-meaningless
    /// offset onto a different image.
    func pinchZoomable(maxZoom: CGFloat = 4, onGestureBegan: @escaping () -> Void = {}) -> some View {
        modifier(PinchZoomModifier(maxZoom: maxZoom, onGestureBegan: onGestureBegan))
    }
}
