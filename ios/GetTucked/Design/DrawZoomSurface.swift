import SwiftUI
#if canImport(UIKit)
import UIKit

/// Pure geometry for a drawing surface that zooms (Plan AK21) — split out
/// for the same reason as `PinchPhysics` and `CalibrationTransform`: this is
/// the part that silently ships wrong. A stroke painted at 6× that lands
/// 40pt from the finger looks like a brush bug, not a coordinate bug, and
/// nothing in a gesture test can catch it. These two functions can be tested
/// in the Simulator, and are.
enum CanvasZoom {
    /// Matches the calibration surface's ceiling (`CaptureView`), which is
    /// the app's other precision-tapping screen.
    static let maxZoom: CGFloat = 8

    /// Container-space point → content-space point.
    ///
    /// The content is rendered `.scaleEffect(zoom, anchor: .center)` then
    /// `.offset(pan)`, so a content point `q` lands at
    /// `centre + (q − centre)·zoom + pan`. This inverts that, and it must
    /// stay the exact inverse of how the view applies the two modifiers —
    /// including their order, since scaling an already-offset view is not
    /// the same transform.
    static func contentPoint(
        container: CGPoint, containerSize: CGSize, zoom: CGFloat, pan: CGSize
    ) -> CGPoint {
        guard zoom > 0 else { return container }
        let centreX = containerSize.width / 2
        let centreY = containerSize.height / 2
        return CGPoint(
            x: (container.x - pan.width - centreX) / zoom + centreX,
            y: (container.y - pan.height - centreY) / zoom + centreY
        )
    }

    /// Pan clamped so the scaled content always covers the container — the
    /// photo can't be dragged off far enough to leave a gutter, and can't be
    /// lost entirely. At zoom 1 the only legal pan is zero.
    static func clampedPan(_ pan: CGSize, zoom: CGFloat, containerSize: CGSize) -> CGSize {
        let limitX = max(0, (containerSize.width * zoom - containerSize.width) / 2)
        let limitY = max(0, (containerSize.height * zoom - containerSize.height) / 2)
        return CGSize(
            width: min(max(pan.width, -limitX), limitX),
            height: min(max(pan.height, -limitY), limitY)
        )
    }
}

/// Touch routing for a surface that both draws and zooms (Plan AK21):
/// **one finger draws, two fingers pinch and pan.**
///
/// UIKit rather than composed SwiftUI gestures, deliberately. Every gesture
/// failure in this project has been a SwiftUI composition failure — AK13,
/// AK14, AK17, and AK20, the last of which silently ate every brush stroke
/// for two days. `UIGestureRecognizer` has a real `minimumNumberOfTouches`
/// and explicit simultaneity, so "two fingers never paint" is enforced by
/// the framework rather than hoped for. That matters more than usual here:
/// none of it can be falsified without a device (standing trap).
///
/// Reports container-space points; the caller maps them through
/// `CanvasZoom.contentPoint`.
struct DrawZoomTouchSurface: UIViewRepresentable {
    var onDrawChanged: (CGPoint) -> Void
    var onDrawEnded: (CGPoint) -> Void
    var onDrawCancelled: () -> Void
    /// Incremental scale factor and the pinch focal point, container-space.
    var onPinch: (CGFloat, CGPoint) -> Void
    /// Incremental translation, container-space.
    var onPan: (CGSize) -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        // The SwiftUI `Canvas` underneath carries the accessibility label and
        // hint; this is a bare touch target and must not shadow it.
        view.isAccessibilityElement = false

        let pinch = UIPinchGestureRecognizer(
            target: view, action: #selector(TouchView.handlePinch(_:))
        )
        let pan = UIPanGestureRecognizer(
            target: view, action: #selector(TouchView.handlePan(_:))
        )
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pinch.delegate = view
        pan.delegate = view
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(pan)

        view.apply(self)
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.apply(self)
    }

    final class TouchView: UIView, UIGestureRecognizerDelegate {
        private var onDrawChanged: (CGPoint) -> Void = { _ in }
        private var onDrawEnded: (CGPoint) -> Void = { _ in }
        private var onDrawCancelled: () -> Void = {}
        private var onPinch: (CGFloat, CGPoint) -> Void = { _, _ in }
        private var onPan: (CGSize) -> Void = { _ in }

        /// The one touch allowed to draw. Held by identity so a second
        /// finger landing later can't be mistaken for it.
        private var drawingTouch: UITouch?
        /// Latched for the whole life of a two-finger gesture. A pinch that
        /// ends with one finger still down must not silently resume drawing
        /// with that finger — it clears on the last touch up, not on
        /// recognizer end.
        private var isTransforming = false

        func apply(_ surface: DrawZoomTouchSurface) {
            onDrawChanged = surface.onDrawChanged
            onDrawEnded = surface.onDrawEnded
            onDrawCancelled = surface.onDrawCancelled
            onPinch = surface.onPinch
            onPan = surface.onPan
        }

        // MARK: Drawing — single touch only

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            // A second finger anywhere abandons the stroke in progress. The
            // rider is starting a pinch; whatever they had drawn was not
            // meant as paint.
            if (event?.allTouches?.count ?? touches.count) > 1 {
                abandonStroke()
                return
            }
            guard !isTransforming, drawingTouch == nil, let touch = touches.first else { return }
            drawingTouch = touch
            onDrawChanged(touch.location(in: self))
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard !isTransforming, let touch = drawingTouch, touches.contains(touch) else { return }
            onDrawChanged(touch.location(in: self))
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            defer { clearTransformIfIdle(event) }
            guard let touch = drawingTouch, touches.contains(touch) else { return }
            drawingTouch = nil
            if isTransforming {
                onDrawCancelled()
            } else {
                onDrawEnded(touch.location(in: self))
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            abandonStroke()
            clearTransformIfIdle(event)
        }

        private func abandonStroke() {
            guard drawingTouch != nil else { return }
            drawingTouch = nil
            onDrawCancelled()
        }

        private func clearTransformIfIdle(_ event: UIEvent?) {
            let remaining = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled } ?? []
            if remaining.isEmpty { isTransforming = false }
        }

        // MARK: Transform — two touches

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                isTransforming = true
                abandonStroke()
                recognizer.scale = 1
            case .changed:
                onPinch(recognizer.scale, recognizer.location(in: self))
                // Report incrementally so the caller never has to hold a
                // per-gesture baseline of its own.
                recognizer.scale = 1
            default:
                break
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                isTransforming = true
                abandonStroke()
                recognizer.setTranslation(.zero, in: self)
            case .changed:
                let translation = recognizer.translation(in: self)
                onPan(CGSize(width: translation.x, height: translation.y))
                recognizer.setTranslation(.zero, in: self)
            default:
                break
            }
        }

        /// Pinch and pan must run together — zooming while repositioning is
        /// one motion to the hand, and requiring them to take turns is what
        /// makes a zoom UI feel sticky.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
#endif
