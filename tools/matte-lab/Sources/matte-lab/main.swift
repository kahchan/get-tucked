import Foundation
import Vision
import CoreImage
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

// matte-lab: diagnostic harness for Plan AD. Runs Apple Vision's subject-lift
// (VNGenerateForegroundInstanceMaskRequest), human-rectangles, and person
// segmentation on a photo, and dumps pixel-format ground truth + instance
// selection + PNG artifacts so H1–H4 can be settled empirically.
//
// The selection helpers (overlapArea/riderInstance/connectedInstances) and the
// Float32 instance-box read are COPIED verbatim from the production
// AnalysisMath.swift / AnalysisEngine.swift so the harness demonstrates the
// production behaviour, not a paraphrase of it.

// MARK: - FourCC / format helpers

func fourCCString(_ code: OSType) -> String {
    let bytes = [
        UInt8((code >> 24) & 0xff),
        UInt8((code >> 16) & 0xff),
        UInt8((code >> 8) & 0xff),
        UInt8(code & 0xff),
    ]
    // Printable FourCC codes decode to ASCII (e.g. 'L008'); non-printable ones
    // (rare) fall back to hex so the output is never garbage.
    if bytes.allSatisfy({ $0 >= 0x20 && $0 < 0x7f }) {
        return String(bytes: bytes, encoding: .ascii) ?? "----"
    }
    return "----"
}

func describePixelBuffer(_ label: String, _ buffer: CVPixelBuffer) {
    let fmt = CVPixelBufferGetPixelFormatType(buffer)
    let w = CVPixelBufferGetWidth(buffer)
    let h = CVPixelBufferGetHeight(buffer)
    let bpr = CVPixelBufferGetBytesPerRow(buffer)
    let hex = String(format: "0x%08X", fmt)
    let known: String
    switch fmt {
    case kCVPixelFormatType_OneComponent8: known = "kCVPixelFormatType_OneComponent8"
    case kCVPixelFormatType_OneComponent32Float: known = "kCVPixelFormatType_OneComponent32Float"
    case kCVPixelFormatType_OneComponent16Half: known = "kCVPixelFormatType_OneComponent16Half"
    default: known = "(other)"
    }
    print("  \(label): format=\(hex) fourCC='\(fourCCString(fmt))' \(known)  \(w)x\(h)  bytesPerRow=\(bpr)")
}

// MARK: - Image loading (bake EXIF orientation so masks/boxes/photo all align)

func loadUprightCGImage(path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
    let orientationRaw = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
    let orientation = CGImagePropertyOrientation(rawValue: orientationRaw) ?? .up
    return upright(cg, orientation: orientation)
}

func upright(_ image: CGImage, orientation: CGImagePropertyOrientation) -> CGImage {
    if orientation == .up { return image }
    let ci = CIImage(cgImage: image).oriented(orientation)
    let ctx = CIContext(options: nil)
    let rect = ci.extent
    return ctx.createCGImage(ci, from: rect) ?? image
}

// MARK: - PNG writers

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("  ! failed to create PNG destination at \(path)")
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

func rgbaToCGImage(_ rgba: [UInt8], width: Int, height: Int) -> CGImage? {
    var data = rgba
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGImageAlphaInfo.premultipliedLast.rawValue
    return data.withUnsafeMutableBytes { ptr -> CGImage? in
        guard let ctx = CGContext(
            data: ptr.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: cs, bitmapInfo: info
        ) else { return nil }
        return ctx.makeImage()
    }
}

func grayToCGImage(_ gray: [UInt8], width: Int, height: Int) -> CGImage? {
    var data = gray
    let cs = CGColorSpaceCreateDeviceGray()
    let info = CGImageAlphaInfo.none.rawValue
    return data.withUnsafeMutableBytes { ptr -> CGImage? in
        guard let ctx = CGContext(
            data: ptr.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width, space: cs, bitmapInfo: info
        ) else { return nil }
        return ctx.makeImage()
    }
}

// MARK: - Production selection math (COPIED from AnalysisMath.swift, verbatim)

func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
    let intersection = a.intersection(b)
    return intersection.isNull ? 0 : intersection.width * intersection.height
}

func riderInstance(instanceBoxes: [Int: CGRect], riderBox: CGRect) -> Int? {
    instanceBoxes.max { overlapArea($0.value, riderBox) < overlapArea($1.value, riderBox) }?.key
}

func connectedInstances(riderInstance: Int, instanceBoxes: [Int: CGRect], margin: CGFloat = 0.06) -> IndexSet {
    guard let riderBox = instanceBoxes[riderInstance] else { return IndexSet() }
    let expandedRiderBox = riderBox.insetBy(dx: -margin, dy: -margin)
    var selected = IndexSet([riderInstance])
    for (index, box) in instanceBoxes where index != riderInstance && expandedRiderBox.intersects(box) {
        selected.insert(index)
    }
    return selected
}

// MARK: - Instance-box decode, TWO ways

/// Production replica: reads instanceMask as Float32 exactly as
/// AnalysisEngine.instanceBoundingBoxes does (assumingMemoryBound Float32,
/// floatsPerRow = bytesPerRow/4, Int(value.rounded())).
func instanceBoxesFloat32(mask: CVPixelBuffer) -> [Int: CGRect] {
    CVPixelBufferLockBaseAddress(mask, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
    let w = CVPixelBufferGetWidth(mask)
    let h = CVPixelBufferGetHeight(mask)
    let rowBytes = CVPixelBufferGetBytesPerRow(mask)
    guard let base = CVPixelBufferGetBaseAddress(mask) else { return [:] }
    let floats = base.assumingMemoryBound(to: Float32.self)
    let floatsPerRow = rowBytes / MemoryLayout<Float32>.size

    var minX: [Int: Int] = [:], maxX: [Int: Int] = [:], minY: [Int: Int] = [:], maxY: [Int: Int] = [:]
    for y in 0 ..< h {
        let row = y * floatsPerRow
        for x in 0 ..< w {
            let value = Int(floats[row + x].rounded())
            guard value != 0 else { continue }
            minX[value] = min(minX[value] ?? x, x)
            maxX[value] = max(maxX[value] ?? x, x)
            minY[value] = min(minY[value] ?? y, y)
            maxY[value] = max(maxY[value] ?? y, y)
        }
    }
    return boxesFromBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY, w: w, h: h)
}

/// The correct read for a UInt8 label buffer: each byte is an instance label
/// (0 = background). Same bottom-left-origin box convention as production.
func instanceBoxesUInt8(mask: CVPixelBuffer) -> [Int: CGRect] {
    CVPixelBufferLockBaseAddress(mask, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
    let w = CVPixelBufferGetWidth(mask)
    let h = CVPixelBufferGetHeight(mask)
    let rowBytes = CVPixelBufferGetBytesPerRow(mask)
    guard let base = CVPixelBufferGetBaseAddress(mask) else { return [:] }
    let bytes = base.assumingMemoryBound(to: UInt8.self)

    var minX: [Int: Int] = [:], maxX: [Int: Int] = [:], minY: [Int: Int] = [:], maxY: [Int: Int] = [:]
    for y in 0 ..< h {
        let row = y * rowBytes
        for x in 0 ..< w {
            let value = Int(bytes[row + x])
            guard value != 0 else { continue }
            minX[value] = min(minX[value] ?? x, x)
            maxX[value] = max(maxX[value] ?? x, x)
            minY[value] = min(minY[value] ?? y, y)
            maxY[value] = max(maxY[value] ?? y, y)
        }
    }
    return boxesFromBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY, w: w, h: h)
}

func boxesFromBounds(minX: [Int: Int], maxX: [Int: Int], minY: [Int: Int], maxY: [Int: Int], w: Int, h: Int) -> [Int: CGRect] {
    var boxes: [Int: CGRect] = [:]
    for (instance, x0) in minX {
        guard let x1 = maxX[instance], let y0 = minY[instance], let y1 = maxY[instance] else { continue }
        let xFrac0 = CGFloat(x0) / CGFloat(w)
        let xFrac1 = CGFloat(x1 + 1) / CGFloat(w)
        let yTopFrac0 = CGFloat(y0) / CGFloat(h)
        let yTopFrac1 = CGFloat(y1 + 1) / CGFloat(h)
        boxes[instance] = CGRect(x: xFrac0, y: 1 - yTopFrac1, width: xFrac1 - xFrac0, height: yTopFrac1 - yTopFrac0)
    }
    return boxes
}

// MARK: - Buffer -> gray CGImage (correct decode for either format)

/// Decodes a Vision mask buffer to an 8-bit gray CGImage. OneComponent8 is a
/// straight copy; OneComponent32Float (soft 0.0–1.0 mask) is converted
/// per-pixel to 0–255 — the conversion the production fix (H2) needs.
func maskBufferToGray(_ buffer: CVPixelBuffer) -> (image: CGImage?, foregroundCount: Int, format: OSType) {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let w = CVPixelBufferGetWidth(buffer)
    let h = CVPixelBufferGetHeight(buffer)
    let bpr = CVPixelBufferGetBytesPerRow(buffer)
    let fmt = CVPixelBufferGetPixelFormatType(buffer)
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return (nil, 0, fmt) }

    var gray = [UInt8](repeating: 0, count: w * h)
    var fg = 0
    if fmt == kCVPixelFormatType_OneComponent32Float {
        let floats = base.assumingMemoryBound(to: Float32.self)
        let fpr = bpr / MemoryLayout<Float32>.size
        for y in 0 ..< h {
            for x in 0 ..< w {
                let v = floats[y * fpr + x]
                let byte = UInt8(max(0, min(1, v)) * 255)
                gray[y * w + x] = byte
                if v >= 0.5 { fg += 1 }
            }
        }
    } else {
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        for y in 0 ..< h {
            for x in 0 ..< w {
                let byte = bytes[y * bpr + x]
                gray[y * w + x] = byte
                if byte >= 128 { fg += 1 }
            }
        }
    }
    return (grayToCGImage(gray, width: w, height: h), fg, fmt)
}

// MARK: - Person mask decode (OneComponent8) — mirrors cgImageFromPixelBuffer
// but reads bytes into our own array (independent of any 8-bit-context bug).

func personMaskGray(_ buffer: CVPixelBuffer) -> (gray: [UInt8], w: Int, h: Int, fg: Int)? {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let w = CVPixelBufferGetWidth(buffer)
    let h = CVPixelBufferGetHeight(buffer)
    let bpr = CVPixelBufferGetBytesPerRow(buffer)
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
    let bytes = base.assumingMemoryBound(to: UInt8.self)
    var gray = [UInt8](repeating: 0, count: w * h)
    var fg = 0
    for y in 0 ..< h {
        for x in 0 ..< w {
            let b = bytes[y * bpr + x]
            gray[y * w + x] = b
            if b >= 128 { fg += 1 }
        }
    }
    return (gray, w, h, fg)
}

// CGContext .high-interpolation resample of a packed gray buffer — mirrors
// MatteRenderer.resizedMask exactly (production's "current bilinear" path),
// so AE1's comparison is against what the app actually does, not an
// approximation of it.
func resamplePersonBilinear(_ gray: [UInt8], w: Int, h: Int, toW: Int, toH: Int) -> [UInt8] {
    guard w != toW || h != toH else { return gray }
    guard let source = grayToCGImage(gray, width: w, height: h),
          let context = CGContext(
              data: nil, width: toW, height: toH, bitsPerComponent: 8,
              bytesPerRow: toW, space: CGColorSpaceCreateDeviceGray(),
              bitmapInfo: CGImageAlphaInfo.none.rawValue
          )
    else { return gray }
    context.interpolationQuality = .high
    context.draw(source, in: CGRect(x: 0, y: 0, width: toW, height: toH))
    guard let resized = context.makeImage(),
          let data = resized.dataProvider?.data, let bytes = CFDataGetBytePtr(data)
    else { return gray }
    var out = [UInt8](repeating: 0, count: toW * toH)
    let bpr = resized.bytesPerRow
    for y in 0 ..< toH {
        for x in 0 ..< toW {
            out[y * toW + x] = bytes[y * bpr + x]
        }
    }
    return out
}

// MARK: - AE1a: edge-preserving upsample, guided by the full-res photo
//
// CIEdgePreserveUpsampleFilter's actual parameter names (confirmed via
// CIFilter.attributes on this Mac, not assumed from docs): `inputImage` is
// the GUIDE (the high-res image whose edges steer the upsample) and
// `inputSmallImage` is the thing being upsampled. Output lands at the
// guide's extent, which is why callers pass the full-res photo as the guide
// — its extent is exactly the subject-mask resolution we need the person
// mask brought up to.
func resamplePersonEdgePreserve(_ gray: [UInt8], w: Int, h: Int, guide: CGImage) -> [UInt8]? {
    guard let smallImage = grayToCGImage(gray, width: w, height: h) else { return nil }
    let smallCI = CIImage(cgImage: smallImage)
    let guideCI = CIImage(cgImage: guide)
    guard let filter = CIFilter(name: "CIEdgePreserveUpsampleFilter") else { return nil }
    filter.setValue(guideCI, forKey: kCIInputImageKey)
    filter.setValue(smallCI, forKey: "inputSmallImage")
    guard let output = filter.outputImage else { return nil }
    let context = CIContext()
    guard let cg = context.createCGImage(
        output, from: guideCI.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray()
    ),
    let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data)
    else { return nil }
    let outW = cg.width, outH = cg.height, bpr = cg.bytesPerRow
    var out = [UInt8](repeating: 0, count: outW * outH)
    for y in 0 ..< outH {
        for x in 0 ..< outW {
            out[y * outW + x] = bytes[y * bpr + x]
        }
    }
    return out
}

/// Mean/min/max of a gray buffer over a square window — used to compare
/// person-mask confidence between the fork-between-legs gap and true torso
/// (AE1b evidence: is the bridged blob mid-confidence, or does it read as
/// confidently as the body?).
func sampleWindowStats(_ gray: [UInt8], w: Int, h: Int, centerX: Int, centerY: Int, radius: Int) -> (min: UInt8, mean: Double, max: UInt8)? {
    let x0 = max(0, centerX - radius), x1 = min(w - 1, centerX + radius)
    let y0 = max(0, centerY - radius), y1 = min(h - 1, centerY + radius)
    guard x0 <= x1, y0 <= y1 else { return nil }
    var minV: UInt8 = 255, maxV: UInt8 = 0
    var sum = 0
    var n = 0
    for y in y0 ... y1 {
        for x in x0 ... x1 {
            let v = gray[y * w + x]
            minV = min(minV, v)
            maxV = max(maxV, v)
            sum += Int(v)
            n += 1
        }
    }
    guard n > 0 else { return nil }
    return (minV, Double(sum) / Double(n), maxV)
}

/// Fork-between-legs vs true-torso sample points, eyeballed off the AD5a
/// composites (fractions of subject-mask width/height, origin top-left) —
/// only defined for the fixtures where the defect is visible; unlisted
/// images skip the AE1b sample dump but still get composites.
let ae1SamplePoints: [String: (forkGap: (CGFloat, CGFloat), torso: (CGFloat, CGFloat))] = [
    "IMG_0674.JPG": (forkGap: (0.49, 0.545), torso: (0.466, 0.365)),
    "IMG_0676.JPG": (forkGap: (0.493, 0.49), torso: (0.466, 0.35)),
]

// MARK: - Person-mask erosion (AD5a) — CIMorphologyMinimum, the inverse of the
// production outlineMask's CIMorphologyMaximum dilate. `radius` is in PIXELS
// at the buffer's own resolution; callers here always pass a buffer already
// resampled to subject-mask resolution, so a radius chosen as a fraction of
// subject width scales correctly across the fixtures' differing source sizes
// (absolute px radii wouldn't survive a resample this large).
func erodeGray(_ gray: [UInt8], w: Int, h: Int, radius: Double) -> [UInt8] {
    guard radius > 0, let image = grayToCGImage(gray, width: w, height: h) else { return gray }
    let ciImage = CIImage(cgImage: image)
    guard let filter = CIFilter(name: "CIMorphologyMinimum") else { return gray }
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(radius, forKey: kCIInputRadiusKey)
    guard let output = filter.outputImage else { return gray }
    let context = CIContext()
    guard let eroded = context.createCGImage(
        output, from: ciImage.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray()
    ),
    let data = eroded.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return gray }
    var out = [UInt8](repeating: 0, count: w * h)
    let bpr = eroded.bytesPerRow
    for y in 0 ..< h {
        for x in 0 ..< w {
            out[y * w + x] = bytes[y * bpr + x]
        }
    }
    return out
}

/// Renders the two-tone composite (subject∩person = rider, subject−person =
/// bike) over `baseImage`, at the subject mask's own resolution, with a
/// tunable rider threshold on the (already resampled + possibly eroded)
/// person buffer. Subject threshold stays fixed at 128 — AD5a only tunes the
/// person side of the split.
func buildTwoToneComposite(
    baseImage: CGImage, subjectBytes: UnsafePointer<UInt8>, subjectBytesPerRow: Int,
    personGray: [UInt8], width: Int, height: Int, riderThreshold: UInt8, subjectThreshold: UInt8 = 128
) -> (composite: CGImage?, coverageBike: Int, coverageSubject: Int) {
    var base = [UInt8](repeating: 0, count: width * height * 4)
    if let ctx = CGContext(data: &base, width: width, height: height, bitsPerComponent: 8,
                           bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
        ctx.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    let alpha: Double = 0.55
    var coverageBike = 0
    var coverageSubject = 0
    for y in 0 ..< height {
        let subjectRow = y * subjectBytesPerRow
        let personRow = y * width
        for x in 0 ..< width {
            guard subjectBytes[subjectRow + x] >= subjectThreshold else { continue }
            coverageSubject += 1
            let isRider = personGray[personRow + x] >= riderThreshold
            let color: (Double, Double, Double) = isRider ? (60, 230, 90) : (232, 150, 30)
            if !isRider { coverageBike += 1 }
            let off = (y * width + x) * 4
            for c in 0 ..< 3 {
                let base0 = Double(base[off + c])
                let tint = [color.0, color.1, color.2][c]
                base[off + c] = UInt8(max(0, min(255, base0 * (1 - alpha) + tint * alpha)))
            }
        }
    }
    return (rgbaToCGImage(base, width: width, height: height), coverageBike, coverageSubject)
}

// MARK: - Distinct colours for the instance-label visualisation

let labelPalette: [(UInt8, UInt8, UInt8)] = [
    (217, 240, 32),   // acid
    (232, 160, 32),   // amber
    (64, 160, 255),   // blue
    (255, 96, 160),   // pink
    (96, 255, 160),   // green
    (200, 120, 255),  // purple
    (255, 220, 96),   // yellow
]

// MARK: - Plan AF experiments (root-cause diagnostic + candidate fixes)
//
// All read-only harness work; no production code touched. Three additions:
//   --afdiag        precise person-mask value grid over the fork/head-tube gap
//                   + a silhouette-edge overlay on the photo (alignment check)
//   --afcrop        AD5b: person seg on a tight subject-bbox crop, pasted back
//   --afinstance    VNGeneratePersonInstanceMaskRequest as the person side

/// Subject-mask foreground bbox in TOP-LEFT-origin fractions of the full frame.
/// Walks the decoded subject gray image at the given threshold.
func subjectBBoxFractions(subjectImage: CGImage, threshold: UInt8) -> (x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat)? {
    guard let data = subjectImage.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
    let w = subjectImage.width, h = subjectImage.height, bpr = subjectImage.bytesPerRow
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0 ..< h {
        let row = y * bpr
        for x in 0 ..< w where bytes[row + x] >= threshold {
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
    }
    guard maxX >= 0 else { return nil }
    return (CGFloat(minX) / CGFloat(w), CGFloat(minY) / CGFloat(h),
            CGFloat(maxX + 1) / CGFloat(w), CGFloat(maxY + 1) / CGFloat(h))
}

/// Runs VNGeneratePersonSegmentationRequest(.accurate) on an already-cropped
/// CGImage and returns its native-resolution gray person mask.
func personSegGray(on image: CGImage) -> (gray: [UInt8], w: Int, h: Int)? {
    let h = VNImageRequestHandler(cgImage: image, options: [:])
    let req = VNGeneratePersonSegmentationRequest()
    req.qualityLevel = .accurate
    req.outputPixelFormat = kCVPixelFormatType_OneComponent8
    do { try h.perform([req]) } catch { return nil }
    guard let res = req.results?.first, let pm = personMaskGray(res.pixelBuffer) else { return nil }
    return (pm.gray, pm.w, pm.h)
}

/// Places a crop-space gray mask into a full-frame buffer at subject resolution.
/// bbox is TOP-LEFT-origin fractions; the crop mask is first resampled to the
/// bbox's pixel size at subject resolution, then copied in. Everything outside
/// the bbox stays background (0) — correct, since the subject mask is ~0 there.
func pasteCropMaskFullFrame(cropGray: [UInt8], cropW: Int, cropH: Int,
                            bbox: (x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat),
                            subjW: Int, subjH: Int) -> [UInt8] {
    var full = [UInt8](repeating: 0, count: subjW * subjH)
    let ox = Int((bbox.x0 * CGFloat(subjW)).rounded())
    let oy = Int((bbox.y0 * CGFloat(subjH)).rounded())
    let bw = Int((bbox.x1 * CGFloat(subjW)).rounded()) - ox
    let bh = Int((bbox.y1 * CGFloat(subjH)).rounded()) - oy
    guard bw > 0, bh > 0 else { return full }
    let resized = resamplePersonBilinear(cropGray, w: cropW, h: cropH, toW: bw, toH: bh)
    for y in 0 ..< bh {
        let fy = oy + y
        if fy < 0 || fy >= subjH { continue }
        for x in 0 ..< bw {
            let fx = ox + x
            if fx < 0 || fx >= subjW { continue }
            full[fy * subjW + fx] = resized[y * bw + x]
        }
    }
    return full
}

/// Silhouette-edge overlay: draws the person mask boundary (threshold-crossing
/// at 128) as bright magenta over the photo, so the mask edge can be checked
/// against the true rider silhouette away from the fork (alignment proof).
func silhouetteOverlay(photo: CGImage, personGray: [UInt8], w: Int, h: Int, threshold: UInt8 = 128) -> CGImage? {
    var base = [UInt8](repeating: 0, count: w * h * 4)
    if let ctx = CGContext(data: &base, width: w, height: h, bitsPerComponent: 8,
                           bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
        ctx.draw(photo, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    func fg(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, x < w, y >= 0, y < h else { return false }
        return personGray[y * w + x] >= threshold
    }
    let t = max(1, w / 600)  // edge line thickness, resolution-independent
    for y in 0 ..< h {
        for x in 0 ..< w {
            let here = fg(x, y)
            let edge = here != fg(x + t, y) || here != fg(x, y + t) || here != fg(x - t, y) || here != fg(x, y - t)
            if edge {
                let off = (y * w + x) * 4
                base[off] = 255; base[off + 1] = 0; base[off + 2] = 255; base[off + 3] = 255
            }
        }
    }
    return rgbaToCGImage(base, width: w, height: h)
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: matte-lab <image-path> [--sweep] [--ae1] [--ae2]")
    exit(2)
}
let imagePath = args[1]
let sweepMode = args.contains("--sweep")
let ae1Mode = args.contains("--ae1")
let ae2Mode = args.contains("--ae2")
let afDiagMode = args.contains("--afdiag")
let afCropMode = args.contains("--afcrop")
let afInstanceMode = args.contains("--afinstance")
let imageName = (imagePath as NSString).lastPathComponent
let toolDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let outputDir = toolDir.appendingPathComponent("output").appendingPathComponent(imageName)
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

print("========================================================================")
print("matte-lab  |  \(imageName)")
print("========================================================================")

guard let cgImage = loadUprightCGImage(path: imagePath) else {
    print("FATAL: could not load image at \(imagePath)")
    exit(1)
}
print("source (upright): \(cgImage.width)x\(cgImage.height)")

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

// --- (a) run the three requests ---
let instanceRequest = VNGenerateForegroundInstanceMaskRequest()
let rectRequest = VNDetectHumanRectanglesRequest()
rectRequest.upperBodyOnly = false
let personRequest = VNGeneratePersonSegmentationRequest()
personRequest.qualityLevel = .accurate
personRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8

do {
    try handler.perform([instanceRequest, rectRequest, personRequest])
} catch {
    print("FATAL: handler.perform threw: \(error)")
    exit(1)
}

// --- human rectangles ---
let humanRects = rectRequest.results ?? []
print("\n[human rectangles] count=\(humanRects.count)")
for (i, r) in humanRects.enumerated() {
    print(String(format: "  #%d conf=%.3f box=(x %.3f y %.3f w %.3f h %.3f)",
                 i, r.confidence, r.boundingBox.origin.x, r.boundingBox.origin.y,
                 r.boundingBox.width, r.boundingBox.height))
}

guard let instanceResult = instanceRequest.results?.first else {
    print("\nFATAL: no VNInstanceMaskObservation returned")
    exit(1)
}

// --- (c) allInstances ---
let allInstances = instanceResult.allInstances
print("\n[allInstances] count=\(allInstances.count) indices=\(Array(allInstances).sorted())")

// --- (b) pixel format of instanceMask ---
print("\n[pixel formats]")
describePixelBuffer("instanceMask", instanceResult.instanceMask)

// --- (d) bounding boxes BOTH ways ---
let boxesU8 = instanceBoxesUInt8(mask: instanceResult.instanceMask)
let boxesF32 = instanceBoxesFloat32(mask: instanceResult.instanceMask)
print("\n[instance boxes — UInt8 read (correct for a label buffer)]  count=\(boxesU8.count)")
for k in boxesU8.keys.sorted() {
    let b = boxesU8[k]!
    print(String(format: "  label %d: (x %.3f y %.3f w %.3f h %.3f)", k, b.origin.x, b.origin.y, b.width, b.height))
}
print("[instance boxes — Float32 read (PRODUCTION replica)]  count=\(boxesF32.count)")
if boxesF32.isEmpty {
    print("  <EMPTY> — production instanceBoundingBoxes returns nil/empty -> segmentSubject returns nil")
} else {
    for k in boxesF32.keys.sorted() {
        let b = boxesF32[k]!
        print(String(format: "  value %d: (x %.3f y %.3f w %.3f h %.3f)", k, b.origin.x, b.origin.y, b.width, b.height))
    }
}

// --- (e) replicate the production selection using the CORRECT (UInt8) read ---
print("\n[selection pipeline — using UInt8 boxes]")
let riderBox: CGRect
if let largest = humanRects.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
    riderBox = largest.boundingBox
    print(String(format: "  rider anchor = largest human rect (x %.3f y %.3f w %.3f h %.3f)",
                 riderBox.origin.x, riderBox.origin.y, riderBox.width, riderBox.height))
} else {
    riderBox = CGRect(x: 0.35, y: 0.25, width: 0.3, height: 0.5)
    print("  rider anchor = frame-centre fallback (0.35,0.25,0.3,0.5)")
}

var selectedInstances = IndexSet(allInstances)  // default: everything, if selection can't run
if let rider = riderInstance(instanceBoxes: boxesU8, riderBox: riderBox) {
    let selected = connectedInstances(riderInstance: rider, instanceBoxes: boxesU8)
    selectedInstances = selected
    print("  riderInstance picked = label \(rider)")
    print("  connectedInstances (unioned) = \(Array(selected).sorted())")
    let dropped = Set(boxesU8.keys).subtracting(Array(selected))
    print("  dropped instances = \(dropped.sorted())")
} else {
    print("  ! riderInstance nil (no UInt8 boxes) — falling back to all instances")
}

// --- generateScaledMaskForImage for the selected union ---
var scaledSubjectImage: CGImage?
var subjectFg = 0
do {
    let scaledBuffer = try instanceResult.generateScaledMaskForImage(forInstances: selectedInstances, from: handler)
    describePixelBuffer("generateScaledMaskForImage", scaledBuffer)
    let (img, fg, _) = maskBufferToGray(scaledBuffer)
    scaledSubjectImage = img
    subjectFg = fg
} catch {
    print("  ! generateScaledMaskForImage threw: \(error)")
}

// --- person segmentation ---
guard let personResult = personRequest.results?.first,
      let person = personMaskGray(personResult.pixelBuffer) else {
    print("\nFATAL: no person segmentation result")
    exit(1)
}
print("\n[person segmentation]")
describePixelBuffer("personMask", personResult.pixelBuffer)
print("  foreground(>=128) = \(person.fg)  (\(person.w)x\(person.h))")

// MARK: - PNG artifacts

// (1) instance-label visualisation (distinct colour per label) — decode UInt8.
do {
    CVPixelBufferLockBaseAddress(instanceResult.instanceMask, .readOnly)
    let w = CVPixelBufferGetWidth(instanceResult.instanceMask)
    let h = CVPixelBufferGetHeight(instanceResult.instanceMask)
    let bpr = CVPixelBufferGetBytesPerRow(instanceResult.instanceMask)
    if let base = CVPixelBufferGetBaseAddress(instanceResult.instanceMask) {
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0 ..< h {
            for x in 0 ..< w {
                let label = Int(bytes[y * bpr + x])
                let off = (y * w + x) * 4
                if label == 0 {
                    rgba[off] = 20; rgba[off+1] = 20; rgba[off+2] = 20; rgba[off+3] = 255
                } else {
                    let c = labelPalette[(label - 1) % labelPalette.count]
                    rgba[off] = c.0; rgba[off+1] = c.1; rgba[off+2] = c.2; rgba[off+3] = 255
                }
            }
        }
        if let img = rgbaToCGImage(rgba, width: w, height: h) {
            writePNG(img, to: outputDir.appendingPathComponent("1-instance-labels.png").path)
        }
    }
    CVPixelBufferUnlockBaseAddress(instanceResult.instanceMask, .readOnly)
}

// (2) selected-union scaled subject mask (correctly decoded)
if let subj = scaledSubjectImage {
    writePNG(subj, to: outputDir.appendingPathComponent("2-subject-mask.png").path)
}

// (3) person mask
if let pimg = grayToCGImage(person.gray, width: person.w, height: person.h) {
    writePNG(pimg, to: outputDir.appendingPathComponent("3-person-mask.png").path)
}

// (4) two-tone composite over the photo (subject∩person green, subject−person
// orange), threshold 128 / no erosion — the untuned baseline, kept as-is for
// before/after comparison against the sweep below.
var coverageBike = 0
var coverageSubject = 0
var personR: [UInt8] = []
var subjW = 0, subjH = 0
if let subj = scaledSubjectImage,
   let subjData = subj.dataProvider?.data, let subjBytes = CFDataGetBytePtr(subjData) {
    let sw = subj.width, sh = subj.height, sbpr = subj.bytesPerRow
    subjW = sw; subjH = sh
    // resample person to subject resolution (mirrors MatteRenderer.resizedMask)
    personR = resamplePersonBilinear(person.gray, w: person.w, h: person.h, toW: sw, toH: sh)
    let (comp, bike, subjCount) = buildTwoToneComposite(
        baseImage: cgImage, subjectBytes: subjBytes, subjectBytesPerRow: sbpr,
        personGray: personR, width: sw, height: sh, riderThreshold: 128
    )
    coverageBike = bike
    coverageSubject = subjCount
    if let comp {
        writePNG(comp, to: outputDir.appendingPathComponent("4-twotone-composite.png").path)
    }
}

// (5) AD5a sweep — rider threshold on the resampled person mask x erosion
// radius (proportional to subject width, since the person mask has been
// upsampled to subject resolution by this point) BEFORE the set op. Written
// as separate PNGs named by their parameters for eyeball comparison across
// all four fixtures; see plans/plan-ad-subject-mask-formats.md AD5a.
if sweepMode, let subj = scaledSubjectImage,
   let subjData = subj.dataProvider?.data, let subjBytes = CFDataGetBytePtr(subjData) {
    let sweepDir = outputDir.appendingPathComponent("sweep")
    try? FileManager.default.createDirectory(at: sweepDir, withIntermediateDirectories: true)

    let thresholds: [UInt8] = [128, 160, 200, 230]
    let erosionFractions: [Double] = [0, 0.0025, 0.005, 0.01]  // 0%, 0.25%, 0.5%, 1.0% of subject width

    print("\n[AD5a sweep] subject \(subjW)x\(subjH)")
    for fraction in erosionFractions {
        let radius = fraction * Double(subjW)
        let erodedPerson = erodeGray(personR, w: subjW, h: subjH, radius: radius)
        for threshold in thresholds {
            let (comp, bike, subjCount) = buildTwoToneComposite(
                baseImage: cgImage, subjectBytes: subjBytes, subjectBytesPerRow: subj.bytesPerRow,
                personGray: erodedPerson, width: subjW, height: subjH, riderThreshold: threshold
            )
            let bikeShare = subjCount > 0 ? Double(bike) / Double(subjCount) : 0
            let name = String(format: "sweep-e%04.2fpct-t%03d.png", fraction * 100, threshold)
            print(String(format: "  e=%.2f%% t=%3d  bike share=%.1f%%  -> %@", fraction * 100, threshold, bikeShare * 100, name))
            if let comp {
                writePNG(comp, to: sweepDir.appendingPathComponent(name).path)
            }
        }
    }
}

// (6) AE1a — bilinear vs edge-preserving upsample of the person mask, at the
// current production rider threshold (200). Success = fork/head-tube pixels
// between the legs flip amber; failure signal = wrist/ankle/helmet loss or
// halo artifacts. See plans/plan-ae-matte-refinement-and-calibration-ux.md.
if ae1Mode, let subj = scaledSubjectImage,
   let subjData = subj.dataProvider?.data, let subjBytes = CFDataGetBytePtr(subjData) {
    let ae1Dir = outputDir.appendingPathComponent("ae1")
    try? FileManager.default.createDirectory(at: ae1Dir, withIntermediateDirectories: true)
    let riderThreshold: UInt8 = 200

    let (bilinearComp, bilinearBike, bilinearSubj) = buildTwoToneComposite(
        baseImage: cgImage, subjectBytes: subjBytes, subjectBytesPerRow: subj.bytesPerRow,
        personGray: personR, width: subjW, height: subjH, riderThreshold: riderThreshold
    )
    if let bilinearComp {
        writePNG(bilinearComp, to: ae1Dir.appendingPathComponent("bilinear-t200.png").path)
    }
    print(String(format: "\n[AE1] bilinear      t=200  bike share=%.1f%%", 100 * Double(bilinearBike) / Double(max(1, bilinearSubj))))

    if let personEdge = resamplePersonEdgePreserve(person.gray, w: person.w, h: person.h, guide: cgImage) {
        let (edgeComp, edgeBike, edgeSubj) = buildTwoToneComposite(
            baseImage: cgImage, subjectBytes: subjBytes, subjectBytesPerRow: subj.bytesPerRow,
            personGray: personEdge, width: subjW, height: subjH, riderThreshold: riderThreshold
        )
        if let edgeComp {
            writePNG(edgeComp, to: ae1Dir.appendingPathComponent("edgepreserve-t200.png").path)
        }
        print(String(format: "[AE1] edge-preserve t=200  bike share=%.1f%%", 100 * Double(edgeBike) / Double(max(1, edgeSubj))))

        if args.contains("--ae1debug") {
            let scanX = Int(0.49 * CGFloat(subjW))
            print("[AE1 debug] vertical scanline at x=\(scanX) (fraction 0.49), bilinear person values, y fraction 0.35->0.75")
            for yFrac in stride(from: 0.35, through: 0.75, by: 0.02) {
                let y = Int(yFrac * Double(subjH))
                let vBi = personR[y * subjW + scanX]
                let vEdge = personEdge[y * subjW + scanX]
                print(String(format: "  yFrac=%.2f y=%4d  bilinear=%3d  edgePreserve=%3d", yFrac, y, vBi, vEdge))
            }
        }
        if let points = ae1SamplePoints[imageName] {
            let forkX = Int(points.forkGap.0 * CGFloat(subjW)), forkY = Int(points.forkGap.1 * CGFloat(subjH))
            let torsoX = Int(points.torso.0 * CGFloat(subjW)), torsoY = Int(points.torso.1 * CGFloat(subjH))
            let radius = max(8, subjW / 200)
            print("[AE1b] person-mask confidence (window radius \(radius)px)")
            if let s = sampleWindowStats(personR, w: subjW, h: subjH, centerX: forkX, centerY: forkY, radius: radius) {
                print(String(format: "  fork-gap  bilinear:      min=%3d mean=%6.1f max=%3d", s.min, s.mean, s.max))
            }
            if let s = sampleWindowStats(personEdge, w: subjW, h: subjH, centerX: forkX, centerY: forkY, radius: radius) {
                print(String(format: "  fork-gap  edge-preserve: min=%3d mean=%6.1f max=%3d", s.min, s.mean, s.max))
            }
            if let s = sampleWindowStats(personR, w: subjW, h: subjH, centerX: torsoX, centerY: torsoY, radius: radius) {
                print(String(format: "  torso     bilinear:      min=%3d mean=%6.1f max=%3d", s.min, s.mean, s.max))
            }
            if let s = sampleWindowStats(personEdge, w: subjW, h: subjH, centerX: torsoX, centerY: torsoY, radius: radius) {
                print(String(format: "  torso     edge-preserve: min=%3d mean=%6.1f max=%3d", s.min, s.mean, s.max))
            }
        } else {
            print("[AE1b] no sample points registered for \(imageName) — composite-only eyeball")
        }
    } else {
        print("[AE1] edge-preserve upsample FAILED (filter unavailable or empty output)")
    }
}

// (7) AE2 — subject-mask decode threshold sweep. Subject bytes are already
// the full continuous 0-255 decode (Vision's 0.0-1.0 float × 255, no
// threshold baked in yet — see AnalysisEngine.cgImageFromPixelBuffer), so
// re-thresholding here re-uses the same decoded buffer rather than re-running
// Vision. Person side stays at production's current bilinear resample +
// rider threshold 200 — AE2 isolates the subject-side knob only.
if ae2Mode, let subj = scaledSubjectImage,
   let subjData = subj.dataProvider?.data, let subjBytes = CFDataGetBytePtr(subjData) {
    let ae2Dir = outputDir.appendingPathComponent("ae2")
    try? FileManager.default.createDirectory(at: ae2Dir, withIntermediateDirectories: true)

    func subjectForegroundCount(threshold: UInt8) -> Int {
        var count = 0
        for y in 0 ..< subjH {
            let row = y * subj.bytesPerRow
            for x in 0 ..< subjW where subjBytes[row + x] >= threshold { count += 1 }
        }
        return count
    }

    let subjectThresholds: [(frac: Double, byte: UInt8)] = [(0.2, 51), (0.3, 77), (0.4, 102), (0.5, 128)]
    let baselineCount = subjectForegroundCount(threshold: 128)
    print("\n[AE2] subject-mask threshold sweep (baseline = 0.5 / byte 128, count=\(baselineCount))")
    for (frac, byte) in subjectThresholds {
        let count = subjectForegroundCount(threshold: byte)
        let deltaPct = baselineCount > 0 ? 100 * (Double(count) - Double(baselineCount)) / Double(baselineCount) : 0
        let (comp, bike, subjCount) = buildTwoToneComposite(
            baseImage: cgImage, subjectBytes: subjBytes, subjectBytesPerRow: subj.bytesPerRow,
            personGray: personR, width: subjW, height: subjH, riderThreshold: 200, subjectThreshold: byte
        )
        let name = String(format: "ae2-subj%.1f-byte%03d.png", frac, byte)
        print(String(format: "  threshold=%.1f (byte %3d)  count=%7d  area delta=%+.2f%%  -> %@", frac, byte, count, deltaPct, name))
        if let comp {
            writePNG(comp, to: ae2Dir.appendingPathComponent(name).path)
        }
        _ = (bike, subjCount)  // composite's own bike-share not the AE2 metric of interest; count above is
    }
}

// MARK: - AF experiments (Plan AF root-cause + candidate fixes)

let subjectProdThreshold: UInt8 = 102   // production (AE2) subject decode threshold

// (AFDIAG) precise person-mask value grid over the fork/head-tube gap +
// silhouette-edge alignment overlay. personR is the production bilinear
// resample of the person mask to subject resolution.
if afDiagMode, subjW > 0, !personR.isEmpty {
    let afDir = outputDir.appendingPathComponent("af")
    try? FileManager.default.createDirectory(at: afDir, withIntermediateDirectories: true)

    print("\n[AFDIAG] person-mask (bilinear→subject res) value grid, top-left-origin fractions")
    print("        rows = y frac, cols = x frac; value is resampled person confidence 0-255")
    let xs = stride(from: 0.42, through: 0.58, by: 0.02)
    let ys = stride(from: 0.40, through: 0.64, by: 0.02)
    var header = "  yfrac \\ x:"
    for xf in xs { header += String(format: "  %.2f", xf) }
    print(header)
    for yf in ys {
        let y = Int(yf * Double(subjH))
        var line = String(format: "  %.2f      ", yf)
        for xf in xs {
            let x = Int(xf * Double(subjW))
            line += String(format: "  %3d ", personR[y * subjW + x])
        }
        print(line)
    }

    if let overlay = silhouetteOverlay(photo: cgImage, personGray: personR, w: subjW, h: subjH) {
        writePNG(overlay, to: afDir.appendingPathComponent("silhouette-edge.png").path)
        print("[AFDIAG] wrote silhouette-edge.png (magenta = person>=128 boundary over photo)")
    }
}

// (AFCROP) AD5b — person seg on a tight subject-bbox crop, pasted back.
if afCropMode, let subj = scaledSubjectImage,
   let subjData = subj.dataProvider?.data, let subjBytes = CFDataGetBytePtr(subjData) {
    let afDir = outputDir.appendingPathComponent("af")
    try? FileManager.default.createDirectory(at: afDir, withIntermediateDirectories: true)

    guard let bboxTight = subjectBBoxFractions(subjectImage: subj, threshold: subjectProdThreshold) else {
        print("\n[AFCROP] could not compute subject bbox — skipping")
        exit(0)
    }
    let pad: CGFloat = 0.03
    let bbox = (x0: max(0, bboxTight.x0 - pad), y0: max(0, bboxTight.y0 - pad),
                x1: min(1, bboxTight.x1 + pad), y1: min(1, bboxTight.y1 + pad))
    let srcW = cgImage.width, srcH = cgImage.height
    let cropRect = CGRect(x: bbox.x0 * CGFloat(srcW), y: bbox.y0 * CGFloat(srcH),
                          width: (bbox.x1 - bbox.x0) * CGFloat(srcW),
                          height: (bbox.y1 - bbox.y0) * CGFloat(srcH))
    print(String(format: "\n[AFCROP] subject bbox frac=(%.3f,%.3f)-(%.3f,%.3f) padded, crop=%dx%d px",
                 bbox.x0, bbox.y0, bbox.x1, bbox.y1, Int(cropRect.width), Int(cropRect.height)))

    guard let cropped = cgImage.cropping(to: cropRect),
          let cropSeg = personSegGray(on: cropped) else {
        print("[AFCROP] crop or person seg failed — skipping"); exit(0)
    }
    print("[AFCROP] crop person mask native res = \(cropSeg.w)x\(cropSeg.h)")
    let fullPerson = pasteCropMaskFullFrame(cropGray: cropSeg.gray, cropW: cropSeg.w, cropH: cropSeg.h,
                                            bbox: bbox, subjW: subjW, subjH: subjH)

    for threshold: UInt8 in [128, 200] {
        let (comp, bike, subjCount) = buildTwoToneComposite(
            baseImage: cgImage, subjectBytes: subjBytes, subjectBytesPerRow: subj.bytesPerRow,
            personGray: fullPerson, width: subjW, height: subjH,
            riderThreshold: threshold, subjectThreshold: subjectProdThreshold)
        let share = subjCount > 0 ? 100 * Double(bike) / Double(subjCount) : 0
        print(String(format: "[AFCROP] crop-person t=%3d  bike share=%.1f%%", threshold, share))
        if let comp { writePNG(comp, to: afDir.appendingPathComponent(String(format: "afcrop-t%03d.png", threshold)).path) }
    }
    // fork/head-tube confidence under the crop model (top-left fractions)
    for (label, xf, yf) in [("headtube", 0.49, 0.46), ("forkcrown", 0.49, 0.49), ("upperfork", 0.49, 0.53)] {
        let x = Int(xf * Double(subjW)), y = Int(yf * Double(subjH))
        if let s = sampleWindowStats(fullPerson, w: subjW, h: subjH, centerX: x, centerY: y, radius: max(8, subjW / 200)) {
            print(String(format: "[AFCROP] %@ (%.2f,%.2f) crop-person: min=%3d mean=%6.1f max=%3d", label, xf, yf, s.min, s.mean, s.max))
        }
    }
    if let overlay = silhouetteOverlay(photo: cgImage, personGray: fullPerson, w: subjW, h: subjH) {
        writePNG(overlay, to: afDir.appendingPathComponent("afcrop-silhouette.png").path)
    }
}

// (AFINSTANCE) VNGeneratePersonInstanceMaskRequest as the person side.
if afInstanceMode, let subj = scaledSubjectImage,
   let subjData = subj.dataProvider?.data, let subjBytes = CFDataGetBytePtr(subjData) {
    let afDir = outputDir.appendingPathComponent("af")
    try? FileManager.default.createDirectory(at: afDir, withIntermediateDirectories: true)

    let piRequest = VNGeneratePersonInstanceMaskRequest()
    do { try handler.perform([piRequest]) } catch {
        print("\n[AFINSTANCE] request threw: \(error)"); exit(0)
    }
    guard let piResult = piRequest.results?.first else {
        print("\n[AFINSTANCE] no person-instance observation returned"); exit(0)
    }
    print("\n[AFINSTANCE] allInstances=\(Array(piResult.allInstances).sorted())")
    describePixelBuffer("personInstanceMask", piResult.instanceMask)
    do {
        let scaled = try piResult.generateScaledMaskForImage(forInstances: piResult.allInstances, from: handler)
        let (img, _, _) = maskBufferToGray(scaled)
        guard let img, let data = img.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
            print("[AFINSTANCE] decode failed"); exit(0)
        }
        // to a packed gray at subject res (scaled mask is at source/subject res)
        let pw = img.width, ph = img.height, pbpr = img.bytesPerRow
        var piGray = [UInt8](repeating: 0, count: pw * ph)
        for y in 0 ..< ph { for x in 0 ..< pw { piGray[y * pw + x] = bytes[y * pbpr + x] } }
        let piResampled = resamplePersonBilinear(piGray, w: pw, h: ph, toW: subjW, toH: subjH)
        for threshold: UInt8 in [128, 200] {
            let (comp, bike, subjCount) = buildTwoToneComposite(
                baseImage: cgImage, subjectBytes: subjBytes, subjectBytesPerRow: subj.bytesPerRow,
                personGray: piResampled, width: subjW, height: subjH,
                riderThreshold: threshold, subjectThreshold: subjectProdThreshold)
            let share = subjCount > 0 ? 100 * Double(bike) / Double(subjCount) : 0
            print(String(format: "[AFINSTANCE] instance-person t=%3d  bike share=%.1f%%", threshold, share))
            if let comp { writePNG(comp, to: afDir.appendingPathComponent(String(format: "afinstance-t%03d.png", threshold)).path) }
        }
        for (label, xf, yf) in [("headtube", 0.49, 0.46), ("forkcrown", 0.49, 0.49), ("upperfork", 0.49, 0.53)] {
            let x = Int(xf * Double(subjW)), y = Int(yf * Double(subjH))
            if let s = sampleWindowStats(piResampled, w: subjW, h: subjH, centerX: x, centerY: y, radius: max(8, subjW / 200)) {
                print(String(format: "[AFINSTANCE] %@ (%.2f,%.2f) instance-person: min=%3d mean=%6.1f max=%3d", label, xf, yf, s.min, s.mean, s.max))
            }
        }
        if let overlay = silhouetteOverlay(photo: cgImage, personGray: piResampled, w: subjW, h: subjH) {
            writePNG(overlay, to: afDir.appendingPathComponent("afinstance-silhouette.png").path)
        }
    } catch {
        print("[AFINSTANCE] generateScaledMaskForImage threw: \(error)")
    }
}

// MARK: - (g) pixel counts + ratio

print("\n[pixel counts]")
print("  person mask foreground   = \(person.fg)  (frac \(String(format: "%.4f", Double(person.fg) / Double(person.w * person.h))))")
print("  subject mask foreground  = \(subjectFg)  (frac \(String(format: "%.4f", scaledSubjectImage.map { Double(subjectFg) / Double($0.width * $0.height) } ?? 0)))")
if person.fg > 0 {
    // Raw count ratio is only an area ratio if both masks share resolution; the
    // fraction ratio is resolution-independent (area ∝ foreground fraction).
    let personFrac = Double(person.fg) / Double(person.w * person.h)
    let subjFrac = scaledSubjectImage.map { Double(subjectFg) / Double($0.width * $0.height) } ?? 0
    print("  raw count ratio subject/person       = \(String(format: "%.3f", Double(subjectFg) / Double(person.fg)))")
    print("  fraction ratio subject/person (AREA) = \(String(format: "%.3f", personFrac > 0 ? subjFrac / personFrac : 0))")
}
if coverageSubject > 0 {
    print("  bike coverage (subject−person)/subject = \(String(format: "%.1f%%", 100 * Double(coverageBike) / Double(coverageSubject)))")
}

print("\noutput PNGs -> \(outputDir.path)")
print("done.\n")
