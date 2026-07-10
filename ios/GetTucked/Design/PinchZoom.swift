import SwiftUI

/// Pinch-to-zoom + pan-once-zoomed for analysis images (Kah, on-device
/// follow-up to Plan O) — the whole photo/matte/skeleton composite zooms as
/// one aligned unit so a rider can inspect matte/skeleton quality up close.
/// Panning is clamped so the image can never be dragged fully out of view;
/// zoom is capped at `maxZoom`. The pan gesture only engages once zoomed in
/// (`GestureMask.none` otherwise) so an unzoomed image never steals the
/// enclosing ScrollView's vertical drag. Double-tap resets.
private struct PinchZoomModifier: ViewModifier {
    var maxZoom: CGFloat

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
                MagnificationGesture()
                    .updating($pinchDelta) { value, state, _ in state = value }
                    .onEnded { value in
                        let newZoom = min(maxZoom, max(1, zoomScale * value))
                        withAnimation(Theme.Motion.travel(Theme.Motion.fast)) {
                            zoomScale = newZoom
                            panOffset = clampedOffset(panOffset, zoom: newZoom, containerSize: containerSize)
                        }
                    }
            )
            .highPriorityGesture(
                DragGesture()
                    .updating($panDelta) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        let candidate = CGSize(
                            width: panOffset.width + value.translation.width,
                            height: panOffset.height + value.translation.height
                        )
                        withAnimation(Theme.Motion.travel(Theme.Motion.fast)) {
                            panOffset = clampedOffset(candidate, zoom: zoomScale, containerSize: containerSize)
                        }
                    },
                including: isZoomed ? .all : .none
            )
            .onTapGesture(count: 2) {
                withAnimation(Theme.Motion.travel()) {
                    zoomScale = 1
                    panOffset = .zero
                }
            }
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
    func pinchZoomable(maxZoom: CGFloat = 4) -> some View {
        modifier(PinchZoomModifier(maxZoom: maxZoom))
    }
}
