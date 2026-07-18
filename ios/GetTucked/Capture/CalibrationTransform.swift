import CoreGraphics

/// Pure screen↔unit-image-space coordinate math for the handlebar calibration
/// gesture surface (Plan F3). Kept separate from `AnalysisMath` — this is a
/// viewport/gesture transform, not measurement math.
enum CalibrationTransform {
    /// Everything needed to map a point between the calibration screen's
    /// container space and unit image-space (0–1), given the current
    /// pinch-zoom/pan state.
    struct Viewport {
        /// Size of the GeometryReader container the image is drawn in.
        let containerSize: CGSize
        /// The aspect-fit rect (in container, unzoomed 1x space) the image
        /// actually occupies — see `aspectFitRect`.
        let imageRect: CGRect
        /// Current pinch-zoom scale, anchored at the container's centre.
        let zoomScale: CGFloat
        /// Current pan offset (container points), applied after zoom.
        let panOffset: CGSize

        var anchor: CGPoint {
            CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        }
    }

    /// Unit image-space (0–1) → on-screen container point, given the viewport's
    /// current zoom/pan.
    static func screenPoint(forUnit unit: CGPoint, in viewport: Viewport) -> CGPoint {
        let local = CGPoint(
            x: viewport.imageRect.minX + unit.x * viewport.imageRect.width,
            y: viewport.imageRect.minY + unit.y * viewport.imageRect.height
        )
        let anchor = viewport.anchor
        return CGPoint(
            x: anchor.x + (local.x - anchor.x) * viewport.zoomScale + viewport.panOffset.width,
            y: anchor.y + (local.y - anchor.y) * viewport.zoomScale + viewport.panOffset.height
        )
    }

    /// On-screen container point → unit image-space (0–1), given the viewport's
    /// current zoom/pan. Inverse of `screenPoint(forUnit:in:)`.
    static func unitPoint(forScreen screen: CGPoint, in viewport: Viewport) -> CGPoint {
        let anchor = viewport.anchor
        let local = CGPoint(
            x: anchor.x + (screen.x - viewport.panOffset.width - anchor.x) / viewport.zoomScale,
            y: anchor.y + (screen.y - viewport.panOffset.height - anchor.y) / viewport.zoomScale
        )
        return CGPoint(
            x: (local.x - viewport.imageRect.minX) / viewport.imageRect.width,
            y: (local.y - viewport.imageRect.minY) / viewport.imageRect.height
        )
    }

    /// Returns the CGRect (in container coords) where an image of `imageSize`
    /// is actually drawn under `.scaledToFit()` — outside this rect is
    /// letterbox/pillarbox padding. Shared by the calibration view's tap and
    /// gesture mapping.
    static func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / container.height
        if imageAspect > containerAspect {
            let h = container.width / imageAspect
            return CGRect(x: 0, y: (container.height - h) / 2, width: container.width, height: h)
        } else {
            let w = container.height * imageAspect
            return CGRect(x: (container.width - w) / 2, y: 0, width: w, height: container.height)
        }
    }

    /// Clamps `panOffset` so the zoomed image can never expose a letterbox
    /// gap it didn't already have at 1x (Plan W5): a physical two-finger
    /// pinch always carries some incidental centroid translation, which
    /// `DragGesture` picks up and deposits into `panOffset` — with nothing
    /// clamping it, repeated zoom/adjust cycles accumulate visible drift.
    /// Per axis: if the zoomed image is at least as large as the container,
    /// bound the offset so neither edge retreats past the container's edge;
    /// if it's still smaller than the container in that axis (e.g. the
    /// letterboxed axis at zoomScale close to 1x), no pan can close that gap
    /// — pin to zero (centred), which is also exactly what this reduces to
    /// at zoomScale == 1 on the fitted axis.
    static func clampedPanOffset(
        _ panOffset: CGSize, zoomScale: CGFloat, imageRect: CGRect, containerSize: CGSize
    ) -> CGSize {
        func clampedAxis(pan: CGFloat, imageMin: CGFloat, imageLength: CGFloat, anchor: CGFloat, containerLength: CGFloat) -> CGFloat {
            let scaledMin = anchor + (imageMin - anchor) * zoomScale
            let scaledLength = imageLength * zoomScale
            guard scaledLength >= containerLength else { return 0 }
            let maxPan = -scaledMin
            let minPan = containerLength - scaledMin - scaledLength
            return min(maxPan, max(minPan, pan))
        }

        let anchor = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        return CGSize(
            width: clampedAxis(
                pan: panOffset.width, imageMin: imageRect.minX, imageLength: imageRect.width,
                anchor: anchor.x, containerLength: containerSize.width
            ),
            height: clampedAxis(
                pan: panOffset.height, imageMin: imageRect.minY, imageLength: imageRect.height,
                anchor: anchor.y, containerLength: containerSize.height
            )
        )
    }
}
