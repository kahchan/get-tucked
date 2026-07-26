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

// Nearest-neighbour resample of a packed gray buffer to a new size.
func resampleGray(_ gray: [UInt8], w: Int, h: Int, toW: Int, toH: Int) -> [UInt8] {
    if w == toW && h == toH { return gray }
    var out = [UInt8](repeating: 0, count: toW * toH)
    for y in 0 ..< toH {
        let sy = min(h - 1, y * h / toH)
        for x in 0 ..< toW {
            let sx = min(w - 1, x * w / toW)
            out[y * toW + x] = gray[sy * w + sx]
        }
    }
    return out
}

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
    personGray: [UInt8], width: Int, height: Int, riderThreshold: UInt8
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
            guard subjectBytes[subjectRow + x] >= 128 else { continue }
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

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: matte-lab <image-path> [--sweep]")
    exit(2)
}
let imagePath = args[1]
let sweepMode = args.contains("--sweep")
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
    personR = resampleGray(person.gray, w: person.w, h: person.h, toW: sw, toH: sh)
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
