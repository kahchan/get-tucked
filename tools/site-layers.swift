// Bakes the website's photo layers: a cropped web JPEG plus SVG markup for the
// subject matte (traced) and the pose skeleton, in crop-pixel coordinates.
// One-off tool — the markup is pasted into docs/*.html as fixed data.
//
//   swift tools/site-layers.swift <photo> <front|side> <x,y,w,h> <out.jpg> [displayWidthPx]
//
// out.jpg is the full-res crop; docs/img ships it at 720w (sips --resampleWidth 720
// -s format jpeg -s formatOptions 50) plus an AVIF at 2× display width, quality 0.5,
// via ImageIO's public.avif destination. displayWidthPx = the frame's rendered CSS
// width (hero 438, side pair 417) so joints land at the app's 8/6pt.
//
// Vision needs Apple Silicon (never the Simulator). Bone set and tiers mirror
// ios/GetTucked/Design/SkeletonOverlay.swift; confidence floor 0.5 mirrors
// AnalysisEngine.

import AppKit
import CoreImage
import Vision

let args = CommandLine.arguments
guard args.count >= 5 else {
    print("usage: site-layers <photo> <front|side> <x,y,w,h> <out.jpg> [displayWidthPx]"); exit(1)
}
let mode = args[2]
let c = args[3].split(separator: ",").compactMap { Double($0) }
let crop = CGRect(x: c[0], y: c[1], width: c[2], height: c[3])
let displayWidth = args.count > 5 ? Double(args[5])! : 440

guard let src = NSImage(contentsOfFile: args[1])?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("cannot read \(args[1])"); exit(1)
}
let W = Double(src.width), H = Double(src.height)
let handler = VNImageRequestHandler(cgImage: src)

// Vision coords are normalised, origin bottom-left → crop-pixel, origin top-left.
func px(_ p: CGPoint) -> CGPoint {
    CGPoint(x: p.x * W - crop.minX, y: (1 - p.y) * H - crop.minY)
}
func f(_ v: Double) -> String { String(format: "%.1f", v) }

// MARK: - Web JPEG

let out = CIImage(cgImage: src).cropped(to: CGRect(x: crop.minX, y: H - crop.maxY, width: crop.width, height: crop.height))
let ctx = CIContext()
try ctx.writeJPEGRepresentation(
    of: out, to: URL(fileURLWithPath: args[4]), colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.72])

print("<!-- \(args[1]) crop \(args[3]) → viewBox 0 0 \(Int(crop.width)) \(Int(crop.height)) -->")

// MARK: - Matte

if mode == "front" {
    let inst = VNGenerateForegroundInstanceMaskRequest()
    try handler.perform([inst])
    guard let obs = inst.results?.first else { print("no foreground instances"); exit(1) }
    let mask = try obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler)
    // Threshold the soft mask the way the app does (AE2: 0.4) before tracing.
    let gray = CIImage(cvPixelBuffer: mask)
        .applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.4])
    let contours = VNDetectContoursRequest()
    contours.detectsDarkOnLight = false
    contours.maximumImageDimension = Int(max(W, H))
    try VNImageRequestHandler(ciImage: gray).perform([contours])
    guard let co = contours.results?.first else { print("no contours"); exit(1) }

    // Outer contours plus their holes, drawn even-odd; specks under 0.2% of
    // the frame are dropped (weeds, pebbles) — they are noise, not rig.
    var d = ""
    func add(_ contour: VNContour) throws {
        let poly = try contour.polygonApproximation(epsilon: 0.0012)
        let pts = poly.normalizedPoints.map { px(CGPoint(x: Double($0.x), y: Double($0.y))) }
        guard pts.count > 2 else { return }
        d += "M" + pts.map { "\(f($0.x)) \(f($0.y))" }.joined(separator: "L") + "Z"
    }
    func area(_ contour: VNContour) -> Double {
        var a = 0.0
        let p = contour.normalizedPoints
        for i in p.indices {
            let j = (i + 1) % p.count
            a += Double(p[i].x * p[j].y - p[j].x * p[i].y)
        }
        return abs(a) / 2
    }
    for top in co.topLevelContours where area(top) > 0.002 {
        try add(top)
        for hole in top.childContours where area(hole) > 0.0004 { try add(hole) }
    }
    print("<path class=\"matte\" fill-rule=\"evenodd\" d=\"\(d)\"/>")
}

// MARK: - Bones

let pose = VNDetectHumanBodyPoseRequest()
try handler.perform([pose])
guard let body = pose.results?.first else { print("no pose"); exit(1) }
typealias J = VNHumanBodyPoseObservation.JointName
func joint(_ name: J) -> CGPoint? {
    guard let p = try? body.recognizedPoint(name), p.confidence > 0.5 else { return nil }
    return px(p.location)
}

enum Tier: String { case measured, context, detail
    var joint: Double { self == .detail ? 6 : 8 }
    var rank: Int { [.measured, .context, .detail].firstIndex(of: self)! }
}
struct Bone { let a: J; let b: J; let tier: Tier; let window: Int }

var bones: [Bone] = []
if mode == "front" {
    bones = [Bone(a: .leftShoulder, b: .rightShoulder, tier: .measured, window: 0)]
    if [J.leftElbow, .leftWrist, .rightElbow, .rightWrist].allSatisfy({ joint($0) != nil }) {
        bones += [Bone(a: .leftShoulder, b: .leftElbow, tier: .context, window: 1),
                  Bone(a: .leftElbow, b: .leftWrist, tier: .context, window: 2),
                  Bone(a: .rightShoulder, b: .rightElbow, tier: .context, window: 1),
                  Bone(a: .rightElbow, b: .rightWrist, tier: .context, window: 2)]
    }
    if joint(.leftHip) != nil, joint(.rightHip) != nil {
        bones += [Bone(a: .leftShoulder, b: .leftHip, tier: .detail, window: 1),
                  Bone(a: .rightShoulder, b: .rightHip, tier: .detail, window: 1),
                  Bone(a: .leftHip, b: .rightHip, tier: .detail, window: 1)]
        if joint(.leftKnee) != nil, joint(.rightKnee) != nil {
            bones += [Bone(a: .leftHip, b: .leftKnee, tier: .detail, window: 2),
                      Bone(a: .rightHip, b: .rightKnee, tier: .detail, window: 2)]
        }
    }
} else {
    // Left first, then right — same fallback order as AnalysisEngine.
    let sides: [(J, J, J, J, J, J, J)] = [
        (.leftShoulder, .leftHip, .leftKnee, .leftEar, .leftElbow, .leftWrist, .leftAnkle),
        (.rightShoulder, .rightHip, .rightKnee, .rightEar, .rightElbow, .rightWrist, .rightAnkle)]
    guard let s = sides.first(where: { [$0.0, $0.1, $0.2, $0.3].allSatisfy { joint($0) != nil } }) else {
        print("no side-on chain"); exit(1)
    }
    bones = [Bone(a: s.0, b: s.1, tier: .measured, window: 0),
             Bone(a: s.0, b: s.3, tier: .measured, window: 1),
             Bone(a: s.1, b: s.2, tier: .measured, window: 2)]
    if joint(s.4) != nil, joint(s.5) != nil {
        bones += [Bone(a: s.0, b: s.4, tier: .context, window: 1),
                  Bone(a: s.4, b: s.5, tier: .context, window: 2)]
    }
    if joint(s.6) != nil { bones.append(Bone(a: s.2, b: s.6, tier: .detail, window: 2)) }
}

// Joint squares are sized in viewBox units so they render at the app's 8/6pt
// when the frame is shown at displayWidth CSS px.
let unit = crop.width / displayWidth
var lines: [String] = [], squares: [String: (CGPoint, Tier, Int)] = [:]
for bone in bones {
    guard let a = joint(bone.a), let b = joint(bone.b) else { continue }
    lines.append("<line class=\"bone \(bone.tier.rawValue)\" style=\"--w:\(bone.window)\" pathLength=\"1\" x1=\"\(f(a.x))\" y1=\"\(f(a.y))\" x2=\"\(f(b.x))\" y2=\"\(f(b.y))\"/>")
    for (name, p) in [(bone.a, a), (bone.b, b)] {
        // Higher tier wins a shared joint (Plan V1); earliest window pops it.
        let key = name.rawValue.rawValue
        let old = squares[key]
        let tier = old.map { $0.1.rank < bone.tier.rank ? $0.1 : bone.tier } ?? bone.tier
        squares[key] = (p, tier, min(old?.2 ?? bone.window, bone.window))
    }
}
print("<g class=\"bones\">")
lines.forEach { print("  " + $0) }
for (_, (p, tier, w)) in squares.sorted(by: { $0.key < $1.key }) {
    let s = tier.joint * unit
    print("  <rect class=\"joint \(tier.rawValue)\" style=\"--w:\(w)\" x=\"\(f(p.x - s / 2))\" y=\"\(f(p.y - s / 2))\" width=\"\(f(s))\" height=\"\(f(s))\"/>")
}
print("</g>")
