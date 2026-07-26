import CoreGraphics
import CoreImage
import SwiftUI
#if canImport(UIKit)
import UIKit

/// Composites a segmentation mask as a transparent-background tinted overlay,
/// instead of `.renderingMode(.template)` which stencils on alpha and tints
/// the whole frame for a no-alpha grayscale mask.
enum MatteRenderer {
    /// AD5a-tuned defaults (plan-ad-subject-mask-formats.md): swept rider
    /// threshold {128, 160, 200, 230} x person-mask erosion radius {0, 0.25%,
    /// 0.5%, 1.0% of subject width} against the four Part-1 fixtures in
    /// tools/matte-lab. Raising the threshold to 200 clears bike-contact
    /// halos (grips/hoods, saddle/top tube between the thighs, cranks at the
    /// feet) with no visible new overshoot on thin rider parts; 230 starts
    /// nibbling fingertips/helmet edge. Erosion overshot at EVERY nonzero
    /// radius tested — a uniform amber ring around the whole rider
    /// silhouette (person and subject masks agree almost exactly at the
    /// true body/background edge, so shrinking person there, not just at
    /// bike contact, immediately shows) — so it stays wired up via
    /// `CIMorphologyMinimum` for future re-tuning but defaults to a no-op.
    static let ad5aRiderThreshold: UInt8 = 200
    static let ad5aPersonErosionFraction: CGFloat = 0

    /// Pure pixel pass: foreground mask bytes → premultiplied RGBA, background → fully transparent.
    /// Strides by `bytesPerRow` (mirrors `AnalysisMath.countForegroundPixels`) — a linear scan
    /// would read trailing row padding as pixels.
    static func overlayPixels(
        bytes: UnsafePointer<UInt8>, width: Int, height: Int, bytesPerRow: Int,
        premultipliedForeground: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), threshold: UInt8 = 128
    ) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0 ..< height {
            let row = y * bytesPerRow
            for x in 0 ..< width where bytes[row + x] >= threshold {
                let offset = (y * width + x) * 4
                out[offset] = premultipliedForeground.r
                out[offset + 1] = premultipliedForeground.g
                out[offset + 2] = premultipliedForeground.b
                out[offset + 3] = premultipliedForeground.a
            }
        }
        return out
    }

    /// Ground fallback for the ghost-compare overlay's anchor, when no
    /// wheel-check tap exists: the lowest foreground row, expressed as a
    /// Vision-convention unit-y (0 = bottom, 1 = top). Noisier than an
    /// explicit ground tap — it depends on where a foot/pedal happened to be
    /// at the moment of the shot, not a fixed wheel-contact point — but
    /// always available. Strides by `bytesPerRow` for the same row-padding
    /// reason `overlayPixels`/`countForegroundPixels` do.
    static func lowestForegroundUnitY(
        bytes: UnsafePointer<UInt8>, width: Int, height: Int, bytesPerRow: Int, threshold: UInt8 = 128
    ) -> Double? {
        guard height > 1 else { return nil }
        // Pixel buffers are stored top-to-bottom (row 0 = image top); the
        // *last* row (closest to the bottom) containing a foreground pixel
        // is the one Vision's bottom-origin unit-y convention wants.
        for row in stride(from: height - 1, through: 0, by: -1) {
            let rowStart = row * bytesPerRow
            for x in 0 ..< width where bytes[rowStart + x] >= threshold {
                return Double(height - 1 - row) / Double(height - 1)
            }
        }
        return nil
    }

    /// Pure two-mask pass (Plan W2): per pixel, `subjectBytes` foreground
    /// wins the pixel — tinted `riderColor` where `personBytes` also reads
    /// foreground at that pixel (subject ∩ person = rider), `bikeColor`
    /// otherwise (subject − person = bike/bags/wheels). Both buffers must
    /// already be the same `width`/`height` — `twoToneOverlay` below handles
    /// resampling (and, AD5a, eroding) the person mask to the subject mask's
    /// resolution before calling this. Strides each buffer by its own
    /// `bytesPerRow`, same padding-safety reasoning as `overlayPixels`.
    /// `riderThreshold` is the AD5a-tunable knob on the person side of the
    /// split; `subjectThreshold` is AE2's knob on the subject side (see
    /// `AnalysisMath.subjectMaskThreshold`'s why-comment) — it must match
    /// whatever threshold `AnalysisEngine` counted area with, or the matte
    /// shown wouldn't match the cm² displayed.
    static func twoToneOverlayPixels(
        subjectBytes: UnsafePointer<UInt8>, subjectBytesPerRow: Int,
        personBytes: UnsafePointer<UInt8>, personBytesPerRow: Int,
        width: Int, height: Int,
        riderColor: (r: UInt8, g: UInt8, b: UInt8, a: UInt8),
        bikeColor: (r: UInt8, g: UInt8, b: UInt8, a: UInt8),
        riderThreshold: UInt8 = ad5aRiderThreshold,
        subjectThreshold: UInt8 = AnalysisMath.subjectMaskThreshold
    ) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0 ..< height {
            let subjectRow = y * subjectBytesPerRow
            let personRow = y * personBytesPerRow
            for x in 0 ..< width where subjectBytes[subjectRow + x] >= subjectThreshold {
                let isRider = personBytes[personRow + x] >= riderThreshold
                let color = isRider ? riderColor : bikeColor
                let offset = (y * width + x) * 4
                out[offset] = color.r
                out[offset + 1] = color.g
                out[offset + 2] = color.b
                out[offset + 3] = color.a
            }
        }
        return out
    }

    /// Pure two-mask pixel pass (Plan Z4): the "Bike coverage" diagnostic's
    /// source of truth — the fraction of subject-mask foreground pixels
    /// where the person mask reads background (subject − person, the same
    /// set op `twoToneOverlayPixels` tints `bikeColor`), i.e. how much of
    /// what the subject lift is measuring isn't person. nil when the
    /// subject mask has zero foreground pixels — nothing to take a share
    /// of, which reads as "—" rather than a misleading 0%. Strides each
    /// buffer by its own bytesPerRow, same padding-safety reasoning as
    /// `twoToneOverlayPixels`.
    ///
    /// Deliberately NOT AD5a-tuned: stays a plain 128/128 split even though
    /// `twoToneOverlayPixels` hardens the person side to `ad5aRiderThreshold`
    /// for the visual matte. This is a measurement-ish diagnostic number
    /// (Z4) — silently changing what it means to make the pixels prettier
    /// is off-limits.
    static func bikeCoverageFraction(
        subjectBytes: UnsafePointer<UInt8>, subjectBytesPerRow: Int,
        personBytes: UnsafePointer<UInt8>, personBytesPerRow: Int,
        width: Int, height: Int, threshold: UInt8 = 128
    ) -> Double? {
        var subjectCount = 0
        var bikeCount = 0
        for y in 0 ..< height {
            let subjectRow = y * subjectBytesPerRow
            let personRow = y * personBytesPerRow
            for x in 0 ..< width where subjectBytes[subjectRow + x] >= threshold {
                subjectCount += 1
                if personBytes[personRow + x] < threshold {
                    bikeCount += 1
                }
            }
        }
        guard subjectCount > 0 else { return nil }
        return Double(bikeCount) / Double(subjectCount)
    }

    /// CGImage-level wrapper (Plan Z4) — resamples `personMask` to the
    /// subject mask's resolution first, same reason `twoToneOverlay` does
    /// (Vision's person segmentation and the subject lift return different
    /// pixel dimensions). nil when there's no person mask or the
    /// resample/decode fails — same degrade posture as the two-tone matte
    /// itself; the "Bike coverage" row displays "—" via
    /// `AnalysisMath.bikeCoverageDisplay` in that case.
    static func bikeCoverageFraction(subjectMask: CGImage, personMask: CGImage?) -> Double? {
        guard let personMask,
              let resampledPerson = resizedMask(personMask, toWidth: subjectMask.width, height: subjectMask.height),
              let subjectData = subjectMask.dataProvider?.data, let subjectBytes = CFDataGetBytePtr(subjectData),
              let personData = resampledPerson.dataProvider?.data, let personBytes = CFDataGetBytePtr(personData)
        else { return nil }
        return bikeCoverageFraction(
            subjectBytes: subjectBytes, subjectBytesPerRow: subjectMask.bytesPerRow,
            personBytes: personBytes, personBytesPerRow: resampledPerson.bytesPerRow,
            width: subjectMask.width, height: subjectMask.height
        )
    }

    /// Resamples a DeviceGray, alpha-none mask to `width`×`height` — used to
    /// bring the person mask (segmentPerson's model resolution) to the
    /// subject mask's resolution (generateScaledMaskForImage's near-source
    /// resolution) before the per-pixel set-ops in `twoToneOverlayPixels`,
    /// which require both buffers to share dimensions. Returns the input
    /// unchanged when it's already the target size.
    static func resizedMask(_ mask: CGImage, toWidth width: Int, height: Int) -> CGImage? {
        guard mask.width != width || mask.height != height else { return mask }
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Erodes `mask` by `radiusPx` — AD5a's fix for the resampled person
    /// mask's soft halo clearing the rider threshold on bike pixels that
    /// touch the body. `CIMorphologyMinimum` is the inverse of
    /// `outlineMask`'s `CIMorphologyMaximum` dilate, same crop-back-to-extent
    /// pattern. Returns nil (caller falls back to the un-eroded mask) on any
    /// Core Image failure — erosion is a presentation nicety, never a hard
    /// requirement the way the subject mask itself is.
    ///
    /// Empirically, `CIMorphologyMinimum` has a radius cliff on EXTREME
    /// aspect-ratio images (a 20:1 strip can erase to all-background past a
    /// small radius) — irrelevant for real subject/person masks (normal
    /// photo aspect ratios), but worth knowing if `ad5aPersonErosionFraction`
    /// is ever re-tuned upward: sanity-check against a real fixture in
    /// tools/matte-lab, not just a synthetic square.
    private static func erodedMask(_ mask: CGImage, radiusPx: CGFloat) -> CGImage? {
        let ciImage = CIImage(cgImage: mask)
        guard let filter = CIFilter(name: "CIMorphologyMinimum") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(radiusPx, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage else { return nil }
        return CIContext().createCGImage(
            output, from: ciImage.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray()
        )
    }

    /// Two-tone composite (Plan W2): rider pixels (subject ∩ person) tint
    /// `riderColor`, bike/bags pixels (subject − person) tint `bikeColor`.
    /// `personMask` nil, or a decode/resample failure, degrades to a
    /// single-tone `subjectMask` overlay in `riderColor` — old positions
    /// (no stored subject mask at all) never reach this function; they go
    /// straight to `tintedOverlay` at the call site instead. `riderThreshold`
    /// and `personErosionFraction` are the AD5a split-quality knobs (see
    /// `ad5aRiderThreshold`'s why-comment) — `personErosionFraction` is a
    /// fraction of `subjectMask.width`, not an absolute pixel count, because
    /// the person mask has just been upsampled to that (up to ~4032px)
    /// resolution, where a 1-2px radius would do nothing.
    static func twoToneOverlay(
        subjectMask: CGImage, personMask: CGImage?, riderColor: UIColor, bikeColor: UIColor, alpha: CGFloat,
        riderThreshold: UInt8 = ad5aRiderThreshold, personErosionFraction: CGFloat = ad5aPersonErosionFraction,
        subjectThreshold: UInt8 = AnalysisMath.subjectMaskThreshold
    ) -> UIImage? {
        guard let personMask,
              let resampledPerson = resizedMask(personMask, toWidth: subjectMask.width, height: subjectMask.height),
              let subjectData = subjectMask.dataProvider?.data, let subjectBytes = CFDataGetBytePtr(subjectData)
        else {
            return tintedOverlay(mask: subjectMask, color: riderColor, alpha: alpha, threshold: subjectThreshold)
        }

        let width = subjectMask.width
        let height = subjectMask.height

        // Skip the erosion pass entirely at the default (no-op) fraction —
        // no extra full-size intermediate buffer beyond what resizedMask
        // already produced.
        let personForSplit: CGImage
        if personErosionFraction > 0,
           let eroded = erodedMask(resampledPerson, radiusPx: personErosionFraction * CGFloat(width)) {
            personForSplit = eroded
        } else {
            personForSplit = resampledPerson
        }
        guard let personData = personForSplit.dataProvider?.data, let personBytes = CFDataGetBytePtr(personData) else {
            return tintedOverlay(mask: subjectMask, color: riderColor, alpha: alpha, threshold: subjectThreshold)
        }

        var riderR: CGFloat = 0, riderG: CGFloat = 0, riderB: CGFloat = 0
        riderColor.getRed(&riderR, green: &riderG, blue: &riderB, alpha: nil)
        var bikeR: CGFloat = 0, bikeG: CGFloat = 0, bikeB: CGFloat = 0
        bikeColor.getRed(&bikeR, green: &bikeG, blue: &bikeB, alpha: nil)
        let alphaByte = UInt8((alpha * 255).rounded())
        let riderPremultiplied = (
            r: UInt8((riderR * alpha * 255).rounded()), g: UInt8((riderG * alpha * 255).rounded()),
            b: UInt8((riderB * alpha * 255).rounded()), a: alphaByte
        )
        let bikePremultiplied = (
            r: UInt8((bikeR * alpha * 255).rounded()), g: UInt8((bikeG * alpha * 255).rounded()),
            b: UInt8((bikeB * alpha * 255).rounded()), a: alphaByte
        )

        let rgba = twoToneOverlayPixels(
            subjectBytes: subjectBytes, subjectBytesPerRow: subjectMask.bytesPerRow,
            personBytes: personBytes, personBytesPerRow: personForSplit.bytesPerRow,
            width: width, height: height,
            riderColor: riderPremultiplied, bikeColor: bikePremultiplied,
            riderThreshold: riderThreshold, subjectThreshold: subjectThreshold
        )

        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        rgba.withUnsafeBytes { ptr in
            context.data?.copyMemory(from: ptr.baseAddress!, byteCount: rgba.count)
        }

        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func tintedOverlay(mask: CGImage, color: UIColor, alpha: CGFloat, threshold: UInt8 = 128) -> UIImage? {
        guard let data = mask.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
        let width = mask.width
        let height = mask.height

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        let alphaByte = UInt8((alpha * 255).rounded())
        let premultiplied = (
            r: UInt8((r * alpha * 255).rounded()),
            g: UInt8((g * alpha * 255).rounded()),
            b: UInt8((b * alpha * 255).rounded()),
            a: alphaByte
        )

        let rgba = overlayPixels(
            bytes: bytes, width: width, height: height, bytesPerRow: mask.bytesPerRow,
            premultipliedForeground: premultiplied, threshold: threshold
        )

        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        rgba.withUnsafeBytes { ptr in
            context.data?.copyMemory(from: ptr.baseAddress!, byteCount: rgba.count)
        }

        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Traces the foreground boundary as a stroke-width ring (Plan P2.2): a
    /// hollow outline, not a fill, since aligning to the ghost means seeing
    /// the live subject *through* the guide, not occluded by it. Dilates the
    /// mask (`CIMorphologyMaximum` — Core Image is already in the stack),
    /// then a manual byte-level pass keeps only the band that's foreground
    /// in the dilated version but background in the original. Same
    /// DeviceGray/alpha-none convention as the mask it consumes, so the
    /// result feeds straight into `tintedOverlay` like any other mask.
    static func outlineMask(mask: CGImage, strokeWidthPx: Int) -> CGImage? {
        guard strokeWidthPx > 0 else { return nil }

        let ciImage = CIImage(cgImage: mask)
        guard let dilateFilter = CIFilter(name: "CIMorphologyMaximum") else { return nil }
        dilateFilter.setValue(ciImage, forKey: kCIInputImageKey)
        dilateFilter.setValue(Double(strokeWidthPx), forKey: kCIInputRadiusKey)
        guard let dilated = dilateFilter.outputImage else { return nil }

        // Crop back to the mask's own extent — dilation grows the filter's
        // natural output bounds, but the ring only needs to line up with
        // the original mask's pixel dimensions for `tintedOverlay` below.
        let extent = ciImage.extent
        let context = CIContext()
        guard let dilatedCG = context.createCGImage(
            dilated, from: extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray()
        ),
        let dilatedData = dilatedCG.dataProvider?.data,
        let dilatedBytes = CFDataGetBytePtr(dilatedData),
        let originalData = mask.dataProvider?.data,
        let originalBytes = CFDataGetBytePtr(originalData)
        else { return nil }

        let width = mask.width
        let height = mask.height
        let threshold: UInt8 = 128
        var ring = [UInt8](repeating: 0, count: width * height)
        for y in 0 ..< height {
            let dilatedRow = y * dilatedCG.bytesPerRow
            let originalRow = y * mask.bytesPerRow
            for x in 0 ..< width {
                let isDilatedForeground = dilatedBytes[dilatedRow + x] >= threshold
                let isOriginalForeground = originalBytes[originalRow + x] >= threshold
                ring[y * width + x] = (isDilatedForeground && !isOriginalForeground) ? 255 : 0
            }
        }

        guard let ringContext = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        ring.withUnsafeBytes { ptr in
            ringContext.data?.copyMemory(from: ptr.baseAddress!, byteCount: ring.count)
        }
        return ringContext.makeImage()
    }

    /// Contour paths for the outline draw-in ceremony (Plan R1.1) — unit-
    /// space (0–1), same top-left-origin convention as `outlineImage`'s own
    /// frame, so `GhostCompareOverlay` can render them directly into the
    /// same placement rect with no coordinate flip. Empty when the mask has
    /// no foreground pixels at all; individual specks are already filtered
    /// by `ContourTracer`'s own area threshold.
    static func contourPaths(mask: CGImage) -> [CGPath] {
        guard let data = mask.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return [] }
        let width = mask.width, height = mask.height, bytesPerRow = mask.bytesPerRow
        let threshold: UInt8 = 128

        let polygons = ContourTracer.trace(
            isForeground: { x, y in bytes[y * bytesPerRow + x] >= threshold },
            width: width, height: height
        )

        return polygons.compactMap { polygon in
            guard let first = polygon.first else { return nil }
            var path = Path()
            path.move(to: first)
            for point in polygon.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
            return path.cgPath
        }
    }

    /// Encodes a raw segmentation mask as lossless PNG, downscaling (never
    /// upscaling) so its long edge doesn't exceed `maxDimension` — mirrors
    /// `UIImage.compressedForStorage`'s cap on the stored photo. Preserves the
    /// mask's DeviceGray, alpha-none format rather than routing through a
    /// UIGraphicsImageRenderer, which would produce RGBA.
    static func downscaledMaskPNGData(mask: CGImage, maxDimension: CGFloat = 1400) -> Data? {
        let longEdge = CGFloat(max(mask.width, mask.height))
        guard longEdge > maxDimension else {
            return UIImage(cgImage: mask).pngData()
        }
        let scale = maxDimension / longEdge
        let targetWidth = max(1, Int((CGFloat(mask.width) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(mask.height) * scale).rounded()))
        guard let context = CGContext(
            data: nil, width: targetWidth, height: targetHeight, bitsPerComponent: 8,
            bytesPerRow: targetWidth, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(mask, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let scaled = context.makeImage() else { return nil }
        return UIImage(cgImage: scaled).pngData()
    }
}
#endif
