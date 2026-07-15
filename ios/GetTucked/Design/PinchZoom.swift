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
    @GestureState private var pinchDelta: CGFloat = 1
    @GestureState private var panDelta: CGSize = .zero
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

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { containerSize = proxy.size }
                        .onChange(of: proxy.size) { _, newSize in containerSize = newSize }
                }
            )
            .scaleEffect(zoomScale * pinchDelta)
            .offset(x: panOffset.width + panDelta.width, y: panOffset.height + panDelta.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .updating($pinchDelta) { value, state, _ in
                        onGestureBegan()
                        state = resistedZoomDelta(for: value.magnification)
                    }
                    .onEnded { value in
                        let rawZoom = zoomScale * value.magnification
                        let newZoom = min(maxZoom, max(1, rawZoom))
                        let newPan = clampedOffset(panOffset, zoom: newZoom, containerSize: containerSize)
                        let overshoot = rawZoom - newZoom
                        guard overshoot != 0 else {
                            withAnimation(Theme.Motion.interactive(springResponse)) {
                                zoomScale = newZoom
                                panOffset = newPan
                            }
                            return
                        }
                        // Snapping back from a rubber-banded pinch — seed
                        // with the gesture's own velocity so release
                        // doesn't visibly seam (skill §5).
                        let seed = PinchPhysics.normalizedVelocity(
                            gestureVelocity: value.velocity, current: rawZoom, target: newZoom
                        )
                        withAnimation(.interpolatingSpring(duration: springResponse, bounce: 0, initialVelocity: seed)) {
                            zoomScale = newZoom
                            panOffset = newPan
                        }
                    }
            )
            .highPriorityGesture(
                DragGesture()
                    .updating($panDelta) { value, state, _ in
                        onGestureBegan()
                        state = resistedPanDelta(for: value.translation)
                    }
                    .onEnded { value in
                        let rawOffset = CGSize(
                            width: panOffset.width + value.translation.width,
                            height: panOffset.height + value.translation.height
                        )
                        let newOffset = clampedOffset(rawOffset, zoom: zoomScale, containerSize: containerSize)
                        let overshootWidth = rawOffset.width - newOffset.width
                        let overshootHeight = rawOffset.height - newOffset.height
                        guard overshootWidth != 0 || overshootHeight != 0 else {
                            withAnimation(Theme.Motion.interactive(springResponse)) {
                                panOffset = newOffset
                            }
                            return
                        }
                        // One shared curve for both axes (they always settle
                        // together); the seed comes from whichever axis
                        // overshot more — the dominant direction of the flick.
                        let velocity = value.velocity
                        let seed: Double = abs(overshootWidth) >= abs(overshootHeight)
                            ? PinchPhysics.normalizedVelocity(
                                gestureVelocity: velocity.width, current: rawOffset.width, target: newOffset.width
                              )
                            : PinchPhysics.normalizedVelocity(
                                gestureVelocity: velocity.height, current: rawOffset.height, target: newOffset.height
                              )
                        withAnimation(.interpolatingSpring(duration: springResponse, bounce: 0, initialVelocity: seed)) {
                            panOffset = newOffset
                        }
                    },
                including: isZoomed ? .all : .none
            )
            .onTapGesture(count: 2) {
                withAnimation(Theme.Motion.interactive(springResponse)) {
                    zoomScale = 1
                    panOffset = .zero
                }
            }
    }

    /// Live rubber-band resistance while pinching past `1...maxZoom` — the
    /// touch still tracks the finger, just with diminishing returns, rather
    /// than hard-freezing at the boundary (skill §9).
    private func resistedZoomDelta(for magnification: CGFloat) -> CGFloat {
        let candidate = zoomScale * magnification
        let resisted: CGFloat
        if candidate < 1 {
            resisted = 1 + PinchPhysics.rubberband(overshoot: candidate - 1, dimension: 1)
        } else if candidate > maxZoom {
            resisted = maxZoom + PinchPhysics.rubberband(overshoot: candidate - maxZoom, dimension: 1)
        } else {
            resisted = candidate
        }
        return resisted / zoomScale
    }

    /// Live rubber-band resistance while panning past the legal (clamped)
    /// range, same shape as `resistedZoomDelta`.
    private func resistedPanDelta(for translation: CGSize) -> CGSize {
        let candidate = CGSize(
            width: panOffset.width + translation.width, height: panOffset.height + translation.height
        )
        let clamped = clampedOffset(candidate, zoom: zoomScale, containerSize: containerSize)
        let dimensionX = max(containerSize.width, 1)
        let dimensionY = max(containerSize.height, 1)
        let resistedWidth = clamped.width + PinchPhysics.rubberband(overshoot: candidate.width - clamped.width, dimension: dimensionX)
        let resistedHeight = clamped.height + PinchPhysics.rubberband(overshoot: candidate.height - clamped.height, dimension: dimensionY)
        return CGSize(width: resistedWidth - panOffset.width, height: resistedHeight - panOffset.height)
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
