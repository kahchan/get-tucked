import CoreGraphics
import CoreImage
#if canImport(UIKit)
import UIKit

/// Composites a segmentation mask as a transparent-background tinted overlay,
/// instead of `.renderingMode(.template)` which stencils on alpha and tints
/// the whole frame for a no-alpha grayscale mask.
enum MatteRenderer {
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

    static func tintedOverlay(mask: CGImage, color: UIColor, alpha: CGFloat) -> UIImage? {
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
            premultipliedForeground: premultiplied
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
