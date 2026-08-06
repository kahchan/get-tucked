import UIKit
import Vision
import os

private let subjectLiftLogger = Logger(subsystem: "com.gettucked.app", category: "SubjectLift")

/// Plan AD3: `segmentSubject` never blocks (always returns an optional mask),
/// but a week of silent nils hid a total feature failure — this pins down
/// *why* on every nil so the failure is diagnosable instead of invisible.
enum SubjectLiftFailure: Error, Equatable {
    case requestFailed
    case noInstances
    case unexpectedMaskFormat(OSType)
    case noRiderInstance
    case scaledMaskFailed
    case decodeFailed

    /// `OSType`/FourCC codes aren't printable by default — spell them out
    /// for the log line (e.g. `kCVPixelFormatType_OneComponent8` -> "L008").
    var logDescription: String {
        switch self {
        case .requestFailed: "requestFailed"
        case .noInstances: "noInstances"
        case .unexpectedMaskFormat(let format): "unexpectedMaskFormat(\(Self.fourCC(format)))"
        case .noRiderInstance: "noRiderInstance"
        case .scaledMaskFailed: "scaledMaskFailed"
        case .decodeFailed: "decodeFailed"
        }
    }

    private static func fourCC(_ type: OSType) -> String {
        let bytes: [UInt8] = [24, 16, 8, 0].map { UInt8((type >> $0) & 0xff) }
        return String(bytes: bytes, encoding: .ascii) ?? String(type)
    }
}

/// `segmentSubject`'s result: `mask` and `failureReason` are mutually
/// exclusive (never both non-nil) — a struct instead of a bare optional so
/// the "why" travels with every nil instead of being discarded at the call site.
struct SubjectLiftOutcome {
    let mask: CGImage?
    let failureReason: SubjectLiftFailure?
}

enum AnalysisError: LocalizedError {
    case noPersonDetected
    case multiplePersonsDetected
    case personClipsFrame
    case personTooSmallInFrame
    case segmentationFailed
    case scaleNotCalibrated
    case poseNotDetected

    var errorDescription: String? {
        switch self {
        case .noPersonDetected: "No rider found. Step back so your full body is visible."
        case .multiplePersonsDetected: "More than one person detected. Ask helpers to step aside."
        case .personClipsFrame: "Part of your body is cut off. Step back or recompose."
        case .personTooSmallInFrame: "You're too far away. Step closer — or tap 2× if you're on 1× — so your body fills the frame."
        case .segmentationFailed: "Couldn't compute a segmentation mask."
        case .scaleNotCalibrated: "Scale reference not set. Tap both ends of your handlebars first."
        case .poseNotDetected: "Couldn't detect body pose. Make sure your full body is visible."
        }
    }
}

struct AnalysisResult {
    let frontalAreaCm2: Double
    let frontalAreaUncertaintyCm2: Double
    let pixelsPerCm: Double
    let foregroundPixelCount: Int
    /// The person-only segmentation mask (unchanged meaning from pre-Plan-W:
    /// what `Position.maskData` stores). Post-W2 this is the colour-splitter
    /// for the two-tone matte, and the area/outline fallback whenever
    /// `subjectMaskImage` is nil.
    let maskImage: UIImage
    /// The subject-lift (rider+bike+bags) mask (Plan W2) — nil when
    /// subject-lifting failed on this capture, which never blocks: `analyse`
    /// falls back to `maskImage`/person-only for `frontalAreaCm2` and every
    /// other consumer exactly as it did before this field existed.
    let subjectMaskImage: UIImage?
    /// Plan AD3: why `subjectMaskImage` is nil, or nil itself when the lift
    /// succeeded. Diagnostic only — transient, never persisted (no SwiftData
    /// field), surfaced only in DEBUG builds' reveal UI and the error log.
    let subjectLiftFailureReason: SubjectLiftFailure?
    let headOnPose: HeadOnPoseMetrics?
    /// Set when the computed shoulder width is outside a plausible human
    /// range — usually a mis-tapped scale reference, not an unusual rider.
    /// Surfaced on the reveal screen; never blocks the save (Plan A3).
    let scaleWarning: String?
    /// Relative disagreement between the bar-tap and wheel-tap rulers — nil
    /// when the wheel check wasn't run (skipped, or the bike has no wheel
    /// size on record). Verification only; the bar taps stay the ruler
    /// (Plan K).
    let wheelCheckDisagreementFraction: Double?
}

/// Pose metrics computable from the head-on photo.
struct HeadOnPoseMetrics {
    /// Shoulder-to-shoulder distance in cm, derived from VNHumanBodyPoseObservation.
    let shoulderWidthCm: Double
    /// Elbow-to-elbow distance in cm, same ruler as `shoulderWidthCm` (AL11).
    /// Only present when `armPoints` (below) cleared its confidence floor —
    /// arms are symmetric-or-nothing, so this and `armPoints` are nil
    /// together.
    let armWidthCm: Double?
    /// Normalised (0–1, origin bottom-left) shoulder landmarks — the exact
    /// points shoulderWidthCm was computed from, persisted for the skeleton
    /// overlay (Plan O) so it replays what produced the number rather than
    /// re-estimating it.
    let leftShoulder: CGPoint
    let rightShoulder: CGPoint
    /// Elbow/wrist landmarks, both sides — [leftElbow, leftWrist, rightElbow,
    /// rightWrist]. Presentational context only, not a measurement input:
    /// nil unless all four clear the confidence floor, since a one-armed
    /// skeleton reads as broken (arms are symmetric-or-nothing).
    let armPoints: [CGPoint]?
    /// Hip landmarks — [leftHip, rightHip]. Presentational body-shape
    /// richness (Plan V/W4), not a measurement input: nil unless both clear
    /// the confidence floor, all-or-nothing like `armPoints`. Independent of
    /// `kneePoints` — a frontal shot with the knees occluded by bars/frame
    /// must not also lose the torso (Plan W4: the old all-or-nothing
    /// hips+knees gate meant one weak knee killed the torso too).
    let hipPoints: [CGPoint]?
    /// Knee landmarks — [leftKnee, rightKnee]. Only meaningful when
    /// `hipPoints` is also present (upper legs can't attach to nothing);
    /// nil unless both clear the confidence floor.
    let kneePoints: [CGPoint]?
}

/// Pose metrics computable from the side-on photo (Phase 2.5).
struct SideOnPoseMetrics {
    /// Angle of shoulder→hip vector from vertical. 0° = fully upright, 90° = horizontal.
    let torsoAngleDeg: Double
    /// Interior angle at the hip between the torso line (hip→shoulder) and thigh (hip→knee).
    let hipAngleDeg: Double
    /// Vertical distance the ear sits below the shoulder (positive = lower than shoulder).
    let headDropCm: Double
    /// Normalised (0–1, origin bottom-left) landmarks — the same points the
    /// angles above were computed from (Plan O).
    let shoulder: CGPoint
    let hip: CGPoint
    let knee: CGPoint
    let ear: CGPoint
    /// Elbow/wrist landmarks, same detected side as `shoulder`/`hip`/etc —
    /// [elbow, wrist]. Presentational context (Plan V), all-or-nothing;
    /// independent of `anklePoint` (cranks/chainrings occlude ankles often,
    /// and a missing ankle must not cost the arm chain, or vice versa).
    let armPoints: [CGPoint]?
    /// Ankle landmark, same detected side. Presentational body-shape
    /// richness (Plan V); independent of `armPoints`.
    let anklePoint: CGPoint?
}

/// Side-on pose bundled with its segmentation matte (Plan O). Segmentation
/// is presentational only — a nil mask degrades the UI to skeleton-over-photo,
/// it never fails the pose estimate.
struct SideOnAnalysis {
    let pose: SideOnPoseMetrics
    let maskImage: UIImage?
    /// Subject-lift (rider+bike+bags) mask (Plan AH), mirroring the frontal
    /// path's `AnalysisResult.subjectMaskImage` — nil when subject-lifting
    /// failed, in which case the person-only `maskImage` above stays the
    /// fallback exactly as it already was pre-AH.
    let subjectMaskImage: UIImage?
}

struct AnalysisEngine {
    // MARK: - Head-on analysis (frontal area + head-on pose)

    static func analyse(
        image: UIImage,
        handlebarWidthMm: Double,
        tapPoint0: CGPoint,
        tapPoint1: CGPoint,
        wheelTaps: (ground: CGPoint, top: CGPoint)? = nil,
        wheelDiameterMm: Double? = nil
    ) async throws -> AnalysisResult {
        guard let cgImage = image.cgImage else { throw AnalysisError.segmentationFailed }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Scale: tap points are in unit coords (0–1); convert to pixels.
        let handlebarPixels = AnalysisMath.handlebarPixels(
            tap0: tapPoint0, tap1: tapPoint1, imageSize: imageSize
        )
        guard handlebarPixels > 1 else { throw AnalysisError.scaleNotCalibrated }
        let pixelsPerCm = AnalysisMath.pixelsPerCm(
            handlebarPixels: handlebarPixels, handlebarWidthMm: handlebarWidthMm
        )

        // Plan K: optional independent scale check via the front wheel —
        // verification only, never replaces the bar-tap ruler above.
        var wheelCheckDisagreementFraction: Double?
        if let wheelTaps, let wheelDiameterMm {
            let wheelPixelsPerCm = AnalysisMath.wheelPixelsPerCm(
                groundTap: wheelTaps.ground, topTap: wheelTaps.top,
                imageSize: imageSize, wheelDiameterMm: wheelDiameterMm
            )
            wheelCheckDisagreementFraction = AnalysisMath.rulerDisagreementFraction(
                barPixelsPerCm: pixelsPerCm, wheelPixelsPerCm: wheelPixelsPerCm
            )
        }

        try await validatePerson(cgImage: cgImage, imageSize: imageSize)

        let mask = try await segmentPerson(cgImage: cgImage)
        // Plan W2: subject-lifting is best-effort — nil (never throws) on
        // any failure, in which case area/rendering fall back to the
        // person-only mask exactly as they did before this existed. Plan
        // AD3: the reason travels alongside so a nil is diagnosable, not
        // silent — logged below and threaded into AnalysisResult.
        let subjectLift = await segmentSubject(cgImage: cgImage)
        let subjectMask = subjectLift.mask
        if let reason = subjectLift.failureReason {
            subjectLiftLogger.error("segmentSubject failed: \(reason.logDescription, privacy: .public)")
        }

        // Area drives off the subject mask (rider+bike+bags — what the wind
        // actually sees, spec §2) when available, else the person mask —
        // same fallback shape as every other optional enhancement here.
        // Subject and person masks decode at different thresholds (AE2) —
        // see AnalysisMath.subjectMaskThreshold's why-comment.
        let areaMask = subjectMask ?? mask
        let foregroundCount = countForegroundPixels(
            mask: areaMask, threshold: subjectMask != nil ? AnalysisMath.subjectMaskThreshold : 128
        )

        // §2.2 fix: Vision mask resolution ≠ source resolution in general.
        // Rescale pixelsPerCm into mask space so area and scale share pixel units.
        let maskPixelsPerCm = AnalysisMath.maskPixelsPerCm(
            sourcePixelsPerCm: pixelsPerCm, maskWidth: areaMask.width, sourceWidth: cgImage.width
        )
        let areaCm2 = AnalysisMath.frontalAreaCm2(
            foregroundPixelCount: foregroundCount, maskPixelsPerCm: maskPixelsPerCm
        )
        var uncertainty = AnalysisMath.uncertaintyCm2(areaCm2: areaCm2)
        // Plan I5: maskPixelsPerCm rescales by width ratio only, correct only
        // if the mask preserves the source's aspect ratio. That assumption is
        // unverified in general — when it doesn't hold, the scale is less
        // trustworthy than usual. Widen the uncertainty honestly rather than
        // silently proceeding as if nothing were wrong (spec §3).
        let aspectMatches = AnalysisMath.maskMatchesSourceAspect(
            maskWidth: areaMask.width, maskHeight: areaMask.height,
            sourceWidth: cgImage.width, sourceHeight: cgImage.height
        )
        if !aspectMatches { uncertainty *= 2 }
        let maskUI = UIImage(cgImage: mask)
        let subjectMaskUI = subjectMask.map(UIImage.init(cgImage:))

        let headOnPose = try? await estimateHeadOnPose(cgImage: cgImage, pixelsPerCm: pixelsPerCm)

        let scaleWarning = headOnPose.flatMap { AnalysisMath.shoulderWidthWarning($0.shoulderWidthCm) }

        return AnalysisResult(
            frontalAreaCm2: areaCm2,
            frontalAreaUncertaintyCm2: uncertainty,
            pixelsPerCm: pixelsPerCm,
            foregroundPixelCount: foregroundCount,
            maskImage: maskUI,
            subjectMaskImage: subjectMaskUI,
            subjectLiftFailureReason: subjectLift.failureReason,
            headOnPose: headOnPose,
            scaleWarning: scaleWarning,
            wheelCheckDisagreementFraction: wheelCheckDisagreementFraction
        )
    }

    // MARK: - Side-on analysis (posture metrics, Phase 2.5)

    static func analyseSideOn(
        image: UIImage,
        pixelsPerCm: Double
    ) async throws -> SideOnAnalysis {
        guard let cgImage = image.cgImage else { throw AnalysisError.segmentationFailed }
        let pose = try await estimateSideOnPose(cgImage: cgImage, pixelsPerCm: pixelsPerCm)
        // Side-on matte is presentational (Plan O) — a failure here must not
        // fail the posture metrics, which is why this is the only place in
        // the engine that swallows a segmentPerson error instead of propagating it.
        let coarseMask = try? await segmentPerson(cgImage: cgImage)
        // AD5b: sharpen the soft full-frame silhouette with a crop-and-reseg
        // pass; keep the coarse mask if the refine can't run (nil on the
        // Simulator, where person segmentation returns nothing at all). This
        // stays the fallback below — AH prefers the subject-lift mask, but
        // the crop-refined edge is still what a person-only fallback renders.
        let matteMask = coarseMask.map { cropRefinedPersonMask(source: cgImage, coarseMask: $0) ?? $0 }
        let maskImage = matteMask.map(UIImage.init(cgImage:))
        // Plan AH: side-on now prefers the subject-lift (rider+bike+bags)
        // mask, same as the frontal path — best-effort, never blocks the
        // pose result on failure.
        let subjectMaskImage = await segmentSubject(cgImage: cgImage).mask.map(UIImage.init(cgImage:))
        return SideOnAnalysis(pose: pose, maskImage: maskImage, subjectMaskImage: subjectMaskImage)
    }

    // MARK: - Person validation

    private static func validatePerson(cgImage: CGImage, imageSize: CGSize) async throws {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = false
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        // Drop low-confidence detections first (a coat, a poster) before counting.
        let confidenceFloor: VNConfidence = 0.5
        guard let results = request.results else {
            throw AnalysisError.noPersonDetected
        }
        let observations = results.filter { $0.confidence >= confidenceFloor }
        guard !observations.isEmpty else {
            throw AnalysisError.noPersonDetected
        }

        // Spec §3: the rider fills the frame, so their box dwarfs incidental
        // detections — a coat on the wall, a person printed on the rider's shirt.
        // Pick the dominant (largest) box as the rider instead of hard-rejecting
        // on `count != 1`, which refused perfectly good solo shots.
        let sorted = observations.sorted {
            $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height
        }
        let dominant = sorted[0]

        // Only flag a genuine second person: a box that's also large — nearly
        // as big as the dominant one, and tall enough to be a real human in
        // frame — not decor.
        if sorted.count > 1 {
            let second = sorted[1]
            let dominantArea = dominant.boundingBox.width * dominant.boundingBox.height
            let secondArea = second.boundingBox.width * second.boundingBox.height
            if secondArea >= 0.6 * dominantArea, second.boundingBox.height >= 0.5 {
                throw AnalysisError.multiplePersonsDetected
            }
        }

        let box = dominant.boundingBox // normalised, origin bottom-left

        // Spec §3: rider should fill the frame. Require bbox height > 35% of
        // frame — relaxed from 50% (Plan W3): the front wheel sits well
        // forward of the handlebar scale plane and reads oversized up close;
        // shooting from farther away with optical zoom flattens that
        // single-plane error, so the coaching copy (SetTheSceneView) now
        // actively encourages standing back and zooming in rather than
        // walking up close. This floor still catches a genuinely-too-far
        // shot, just without punishing the smaller rider that better
        // technique produces. This is a DIFFERENT physical problem from
        // clipping below — too small means too far away (fix: step closer
        // or zoom in), not too close (fix: step back). Conflating the two
        // under one message told "too far away" users to do the opposite of
        // what would fix it.
        if box.height < 0.35 {
            throw AnalysisError.personTooSmallInFrame
        }

        // Do NOT reject for touching the bottom edge — full-body cycling shots
        // routinely have feet at the frame bottom. Only reject if the top, left, or
        // right clips significantly (rider is too close / poorly framed).
        let clipMargin = 5.0 / min(imageSize.width, imageSize.height)
        if box.minX < clipMargin || box.maxX > 1 - clipMargin || box.maxY > 1 - clipMargin {
            throw AnalysisError.personClipsFrame
        }
    }

    // MARK: - Segmentation

    private static func segmentPerson(cgImage: CGImage) async throws -> CGImage {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let result = request.results?.first else {
            throw AnalysisError.segmentationFailed
        }
        let maskBuffer = result.pixelBuffer

        return try cgImageFromPixelBuffer(
            maskBuffer,
            sourceSize: CGSize(width: cgImage.width, height: cgImage.height)
        )
    }

    // MARK: - AD5b: crop-refined side-on matte

    /// Best-effort crisper side-on person matte, ported from the matte-lab
    /// AFCROP path (Plan AD5b) that produced the silhouettes Kah signed off
    /// on. `VNGeneratePersonSegmentation` runs at a fixed input resolution;
    /// over a whole frame the rider occupies few of those pixels, so the body
    /// edge upsamples soft — the halo that makes the single-tone side-on matte
    /// look mushy. Re-running the request on a tight crop around the rider
    /// spends that fixed budget on the body alone, for a crisp edge, then
    /// pastes the crop mask back into a full-frame buffer. Presentational only
    /// (Plan O — the side-on matte feeds no number), so this returns nil on any
    /// failure and the caller keeps the coarse full-frame mask.
    static func cropRefinedPersonMask(source cgImage: CGImage, coarseMask: CGImage) -> CGImage? {
        guard let tight = maskForegroundBBox(coarseMask, threshold: 128) else { return nil }
        // Pad the bbox so the model sees a little context around the rider,
        // not a silhouette flush to the crop edge (matches the harness 3%).
        let pad: CGFloat = 0.03
        let bbox = (x0: max(0, tight.x0 - pad), y0: max(0, tight.y0 - pad),
                    x1: min(1, tight.x1 + pad), y1: min(1, tight.y1 + pad))
        let srcW = cgImage.width, srcH = cgImage.height
        let cropRect = CGRect(x: bbox.x0 * CGFloat(srcW), y: bbox.y0 * CGFloat(srcH),
                              width: (bbox.x1 - bbox.x0) * CGFloat(srcW),
                              height: (bbox.y1 - bbox.y0) * CGFloat(srcH)).integral
        guard cropRect.width >= 1, cropRect.height >= 1,
              let cropped = cgImage.cropping(to: cropRect) else { return nil }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: cropped)
        guard (try? handler.perform([request])) != nil,
              let result = request.results?.first,
              let cropMaskImage = try? cgImageFromPixelBuffer(
                  result.pixelBuffer,
                  sourceSize: CGSize(width: cropped.width, height: cropped.height)),
              let crop = grayBytes(from: cropMaskImage) else { return nil }

        let full = pasteMaskFullFrame(
            cropGray: crop.gray, cropW: crop.w, cropH: crop.h,
            bbox: bbox, fullW: coarseMask.width, fullH: coarseMask.height
        )
        return grayCGImage(full, width: coarseMask.width, height: coarseMask.height)
    }

    /// Top-left-origin foreground bbox (fractions of the frame) of an 8-bit
    /// gray mask — the tight box of every pixel at/above `threshold`.
    static func maskForegroundBBox(
        _ mask: CGImage, threshold: UInt8
    ) -> (x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat)? {
        guard let decoded = grayBytes(from: mask) else { return nil }
        let (gray, w, h) = (decoded.gray, decoded.w, decoded.h)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0 ..< h {
            let row = y * w
            for x in 0 ..< w where gray[row + x] >= threshold {
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
            }
        }
        guard maxX >= 0 else { return nil }
        return (CGFloat(minX) / CGFloat(w), CGFloat(minY) / CGFloat(h),
                CGFloat(maxX + 1) / CGFloat(w), CGFloat(maxY + 1) / CGFloat(h))
    }

    /// Pastes a crop-space gray mask into a full-frame buffer at `bbox`
    /// (top-left fractions), resampling the crop to the bbox's pixel size
    /// first. Everything outside the bbox stays background (0).
    static func pasteMaskFullFrame(
        cropGray: [UInt8], cropW: Int, cropH: Int,
        bbox: (x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat),
        fullW: Int, fullH: Int
    ) -> [UInt8] {
        var full = [UInt8](repeating: 0, count: fullW * fullH)
        let ox = Int((bbox.x0 * CGFloat(fullW)).rounded())
        let oy = Int((bbox.y0 * CGFloat(fullH)).rounded())
        let bw = Int((bbox.x1 * CGFloat(fullW)).rounded()) - ox
        let bh = Int((bbox.y1 * CGFloat(fullH)).rounded()) - oy
        guard bw > 0, bh > 0 else { return full }
        let resized = resampleGray(cropGray, w: cropW, h: cropH, toW: bw, toH: bh)
        for y in 0 ..< bh {
            let fy = oy + y
            if fy < 0 || fy >= fullH { continue }
            for x in 0 ..< bw {
                let fx = ox + x
                if fx < 0 || fx >= fullW { continue }
                full[fy * fullW + fx] = resized[y * bw + x]
            }
        }
        return full
    }

    /// Bilinear resample of a packed gray buffer via a gray `CGContext`.
    /// Returns the input unchanged if already the target size or on failure.
    static func resampleGray(_ gray: [UInt8], w: Int, h: Int, toW: Int, toH: Int) -> [UInt8] {
        guard w != toW || h != toH else { return gray }
        guard toW > 0, toH > 0,
              let source = grayCGImage(gray, width: w, height: h),
              let context = CGContext(
                  data: nil, width: toW, height: toH, bitsPerComponent: 8,
                  bytesPerRow: toW, space: CGColorSpaceCreateDeviceGray(),
                  bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else { return gray }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: toW, height: toH))
        guard let resized = context.makeImage(), let bytes = grayBytes(from: resized) else { return gray }
        return bytes.gray
    }

    /// Decodes an 8-bit gray `CGImage` to a packed (row-padding stripped)
    /// byte array so downstream index math can stride by width alone.
    static func grayBytes(from image: CGImage) -> (gray: [UInt8], w: Int, h: Int)? {
        guard let data = image.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return nil }
        let w = image.width, h = image.height, bpr = image.bytesPerRow
        var out = [UInt8](repeating: 0, count: w * h)
        for y in 0 ..< h {
            let row = y * bpr
            for x in 0 ..< w { out[y * w + x] = ptr[row + x] }
        }
        return (out, w, h)
    }

    /// Builds an 8-bit gray `CGImage` from a packed byte buffer.
    static func grayCGImage(_ gray: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, gray.count == width * height else { return nil }
        var data = gray
        return data.withUnsafeMutableBytes { raw -> CGImage? in
            guard let base = raw.baseAddress,
                  let ctx = CGContext(
                      data: base, width: width, height: height, bitsPerComponent: 8,
                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                      bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else { return nil }
            return ctx.makeImage()
        }
    }

    /// Decodes a Vision mask buffer to an 8-bit gray `CGImage`. Plan AD2 (H2):
    /// the two Vision requests this engine uses hand back two different
    /// pixel formats — `segmentPerson`'s `OneComponent8` is already an 8-bit
    /// gray byte-per-pixel layout, but `segmentSubject`'s
    /// `generateScaledMaskForImage` is `OneComponent32Float` (0.0–1.0 soft
    /// mask); reading that through an 8-bit `CGContext` (the pre-AD2 bug)
    /// reads one byte in four of a float, i.e. byte-salad. Branch on the
    /// buffer's actual format instead of assuming.
    static func cgImageFromPixelBuffer(_ buffer: CVPixelBuffer, sourceSize: CGSize) throws -> CGImage {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw AnalysisError.segmentationFailed
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        switch CVPixelBufferGetPixelFormatType(buffer) {
        case kCVPixelFormatType_OneComponent8:
            // segmentPerson's output — already 8-bit gray, byte layout
            // matches a CGContext directly, no conversion needed.
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ), let image = context.makeImage() else {
                throw AnalysisError.segmentationFailed
            }
            return image

        case kCVPixelFormatType_OneComponent32Float:
            // generateScaledMaskForImage's output — one Float32 (0.0–1.0)
            // per pixel. Convert into a fresh 8-bit buffer rather than
            // pointing a CGContext at the float bytes directly.
            let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.size
            let floats = baseAddress.assumingMemoryBound(to: Float32.self)
            var gray = [UInt8](repeating: 0, count: width * height)
            for y in 0 ..< height {
                let row = y * floatsPerRow
                for x in 0 ..< width {
                    let clamped = min(max(floats[row + x], 0), 1)
                    gray[y * width + x] = UInt8((clamped * 255).rounded())
                }
            }
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                throw AnalysisError.segmentationFailed
            }
            gray.withUnsafeBytes { ptr in
                context.data?.copyMemory(from: ptr.baseAddress!, byteCount: gray.count)
            }
            guard let image = context.makeImage() else {
                throw AnalysisError.segmentationFailed
            }
            return image

        default:
            throw AnalysisError.segmentationFailed
        }
    }

    /// Subject-lift matte (Plan W2): the foreground-instance ("subject
    /// lifting") request's rider-connected union — rider+bike+bags, not
    /// `segmentPerson`'s person-only silhouette. Best-effort: returns nil
    /// (never throws) on any failure, since this is an area/rendering
    /// enhancement, not a hard requirement — `analyse` falls back to the
    /// person mask exactly like pre-W2 when this comes back nil. Deliberately
    /// the rider-anchored connected union (Plan A1), not a blanket union of
    /// every instance — a disconnected car/coat/spare-wheel in frame must
    /// stay excluded.
    static func segmentSubject(cgImage: CGImage) async -> SubjectLiftOutcome {
        let instanceRequest = VNGenerateForegroundInstanceMaskRequest()
        let rectRequest = VNDetectHumanRectanglesRequest()
        rectRequest.upperBodyOnly = false
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([instanceRequest, rectRequest])
        } catch {
            return SubjectLiftOutcome(mask: nil, failureReason: .requestFailed)
        }
        guard let result = instanceRequest.results?.first, !result.allInstances.isEmpty else {
            return SubjectLiftOutcome(mask: nil, failureReason: .noInstances)
        }

        let instanceBoxes: [Int: CGRect]
        switch instanceBoundingBoxes(mask: result.instanceMask) {
        case .success(let boxes) where !boxes.isEmpty:
            instanceBoxes = boxes
        case .success:
            return SubjectLiftOutcome(mask: nil, failureReason: .noInstances)
        case .failure(let reason):
            return SubjectLiftOutcome(mask: nil, failureReason: reason)
        }

        // Rider anchor: the largest detected human rectangle, or frame-centre
        // if Vision found none (e.g. a badly occluded shot) — both boxes are
        // in Vision's normalised bottom-left-origin convention.
        let riderBox: CGRect
        if let rects = rectRequest.results,
           let largest = rects.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
            riderBox = largest.boundingBox
        } else {
            riderBox = CGRect(x: 0.35, y: 0.25, width: 0.3, height: 0.5)
        }

        guard let riderInstance = AnalysisMath.riderInstance(instanceBoxes: instanceBoxes, riderBox: riderBox) else {
            return SubjectLiftOutcome(mask: nil, failureReason: .noRiderInstance)
        }
        let selected = AnalysisMath.connectedInstances(riderInstance: riderInstance, instanceBoxes: instanceBoxes)

        guard let buffer = try? result.generateScaledMaskForImage(forInstances: selected, from: handler) else {
            return SubjectLiftOutcome(mask: nil, failureReason: .scaledMaskFailed)
        }
        guard let mask = try? cgImageFromPixelBuffer(buffer, sourceSize: CGSize(width: cgImage.width, height: cgImage.height)) else {
            return SubjectLiftOutcome(mask: nil, failureReason: .decodeFailed)
        }
        return SubjectLiftOutcome(mask: mask, failureReason: nil)
    }

    /// Scans the per-instance label mask once and returns each instance's
    /// bounding box, converted to Vision's normalised bottom-left-origin
    /// convention so it's directly comparable to
    /// `VNDetectedObjectObservation.boundingBox`. Plan AD2 (H1): the real
    /// buffer is a UInt8 label map (0 = background, N = instance), not the
    /// Float32 this used to (wrongly) assume — reading label bytes as floats
    /// packs 4 bytes into 1 denormal that rounds to 0, so every pixel read as
    /// background and this returned nil on every image. `.failure` carries
    /// the reason for AD3 instead of a bare nil.
    static func instanceBoundingBoxes(mask: CVPixelBuffer) -> Result<[Int: CGRect], SubjectLiftFailure> {
        let format = CVPixelBufferGetPixelFormatType(mask)
        guard format == kCVPixelFormatType_OneComponent8 else {
            return .failure(.unexpectedMaskFormat(format))
        }

        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let w = CVPixelBufferGetWidth(mask)
        let h = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        guard let base = CVPixelBufferGetBaseAddress(mask) else {
            return .failure(.noInstances)
        }
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
        guard !minX.isEmpty else { return .success([:]) }

        var boxes: [Int: CGRect] = [:]
        for (instance, x0) in minX {
            guard let x1 = maxX[instance], let y0 = minY[instance], let y1 = maxY[instance] else { continue }
            let xFrac0 = CGFloat(x0) / CGFloat(w)
            let xFrac1 = CGFloat(x1 + 1) / CGFloat(w)
            // y0/y1 are top-down row indices; flip to bottom-left-origin
            // fractional coords to match Vision's boundingBox convention.
            let yTopFrac0 = CGFloat(y0) / CGFloat(h)
            let yTopFrac1 = CGFloat(y1 + 1) / CGFloat(h)
            boxes[instance] = CGRect(
                x: xFrac0, y: 1 - yTopFrac1,
                width: xFrac1 - xFrac0, height: yTopFrac1 - yTopFrac0
            )
        }
        return .success(boxes)
    }

    // MARK: - Pixel count

    private static func countForegroundPixels(mask: CGImage, threshold: UInt8 = 128) -> Int {
        guard let dataProvider = mask.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        // Vision person segmentation: 255 = foreground, 0 = background.
        // Threshold of 128 tolerates soft edges (102 for the subject mask —
        // AE2, see AnalysisMath.subjectMaskThreshold). Must stride by
        // mask.bytesPerRow, not scan the buffer linearly — see
        // AnalysisMath.countForegroundPixels.
        return AnalysisMath.countForegroundPixels(
            bytes: bytes, width: mask.width, height: mask.height, bytesPerRow: mask.bytesPerRow, threshold: threshold
        )
    }

    // MARK: - Head-on pose estimation

    private static func estimateHeadOnPose(
        cgImage: CGImage,
        pixelsPerCm: Double
    ) async throws -> HeadOnPoseMetrics {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw AnalysisError.poseNotDetected
        }

        // Shoulder width: distance between left and right shoulder landmarks in image coords.
        // VNHumanBodyPoseObservation returns normalised points (0–1, origin bottom-left).
        let leftShoulder = try observation.recognizedPoint(.leftShoulder)
        let rightShoulder = try observation.recognizedPoint(.rightShoulder)

        guard leftShoulder.confidence > 0.5, rightShoulder.confidence > 0.5 else {
            throw AnalysisError.poseNotDetected
        }

        let shoulderWidthCm = AnalysisMath.shoulderWidthCm(
            leftShoulderX: leftShoulder.location.x,
            rightShoulderX: rightShoulder.location.x,
            imageWidthPx: cgImage.width,
            pixelsPerCm: pixelsPerCm
        )

        let hips = hipPoints(from: observation)
        let arms = armPoints(from: observation)
        // arms[0] = leftElbow, arms[2] = rightElbow (see armPoints(from:)).
        let armWidthCm = arms.map {
            AnalysisMath.armWidthCm(
                leftElbowX: $0[0].x, rightElbowX: $0[2].x,
                imageWidthPx: cgImage.width, pixelsPerCm: pixelsPerCm
            )
        }
        return HeadOnPoseMetrics(
            shoulderWidthCm: shoulderWidthCm,
            armWidthCm: armWidthCm,
            leftShoulder: leftShoulder.location,
            rightShoulder: rightShoulder.location,
            armPoints: arms,
            hipPoints: hips,
            kneePoints: kneePoints(from: observation, hipsPresent: hips != nil)
        )
    }

    /// Never throws — arms are presentational context (Plan O), not a
    /// measurement input, so any joint missing or below the confidence floor
    /// just omits the whole set rather than failing head-on analysis.
    private static func armPoints(from observation: VNHumanBodyPoseObservation) -> [CGPoint]? {
        let joints: [VNHumanBodyPoseObservation.JointName] = [.leftElbow, .leftWrist, .rightElbow, .rightWrist]
        var points: [CGPoint] = []
        for joint in joints {
            guard let point = try? observation.recognizedPoint(joint), point.confidence > 0.5 else {
                return nil
            }
            points.append(point.location)
        }
        return points
    }

    /// Never throws — body-shape richness (Plan V), not a measurement input,
    /// all-or-nothing for the pair. Split from knees (Plan W4): a frontal
    /// shot with bars/frame occluding the knees must still grow the torso.
    private static func hipPoints(from observation: VNHumanBodyPoseObservation) -> [CGPoint]? {
        let joints: [VNHumanBodyPoseObservation.JointName] = [.leftHip, .rightHip]
        var points: [CGPoint] = []
        for joint in joints {
            guard let point = try? observation.recognizedPoint(joint), point.confidence > 0.5 else {
                return nil
            }
            points.append(point.location)
        }
        return points
    }

    /// Never throws, same all-or-nothing pattern as `hipPoints(from:)` —
    /// but only meaningful once hips are already present, since the upper
    /// legs this feeds have nothing to attach to otherwise.
    private static func kneePoints(from observation: VNHumanBodyPoseObservation, hipsPresent: Bool) -> [CGPoint]? {
        guard hipsPresent else { return nil }
        let joints: [VNHumanBodyPoseObservation.JointName] = [.leftKnee, .rightKnee]
        var points: [CGPoint] = []
        for joint in joints {
            guard let point = try? observation.recognizedPoint(joint), point.confidence > 0.5 else {
                return nil
            }
            points.append(point.location)
        }
        return points
    }

    // MARK: - Side-on pose estimation

    private static func estimateSideOnPose(
        cgImage: CGImage,
        pixelsPerCm: Double
    ) async throws -> SideOnPoseMetrics {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw AnalysisError.poseNotDetected
        }

        // A profile shot only exposes ONE anatomical side to the camera — the
        // far side is self-occluded, so its joints read low-confidence or
        // undetectable. Which side that is depends purely on which way the
        // rider happens to face; try left first (arbitrary), fall back to
        // right, rather than hardcoding left and silently failing whenever
        // the rider faces the other way. Torso/hip angle and head drop are
        // symmetric quantities — either side yields an equivalent measurement.
        guard let matched = sideOnJoints(from: observation, side: .left)
            ?? sideOnJoints(from: observation, side: .right)
        else {
            throw AnalysisError.poseNotDetected
        }
        let side = matched.side
        let shoulder = matched.shoulder
        let hip = matched.hip
        let knee = matched.knee
        let ear = matched.ear

        let torsoAngleDeg = AnalysisMath.torsoAngleDeg(
            shoulder: shoulder, hip: hip
        )
        let hipAngleDeg = AnalysisMath.hipAngleDeg(
            shoulder: shoulder, hip: hip, knee: knee
        )
        let headDropCm = AnalysisMath.headDropCm(
            shoulderY: shoulder.y, earY: ear.y,
            imageHeightPx: cgImage.height, pixelsPerCm: pixelsPerCm
        )

        return SideOnPoseMetrics(
            torsoAngleDeg: torsoAngleDeg,
            hipAngleDeg: hipAngleDeg,
            headDropCm: headDropCm,
            shoulder: shoulder,
            hip: hip,
            knee: knee,
            ear: ear,
            armPoints: sideOnArmPoints(from: observation, side: side),
            anklePoint: sideOnAnklePoint(from: observation, side: side)
        )
    }

    private enum BodySide {
        case left, right

        var joints: (shoulder: VNHumanBodyPoseObservation.JointName, hip: VNHumanBodyPoseObservation.JointName,
                     knee: VNHumanBodyPoseObservation.JointName, ear: VNHumanBodyPoseObservation.JointName) {
            switch self {
            case .left: (.leftShoulder, .leftHip, .leftKnee, .leftEar)
            case .right: (.rightShoulder, .rightHip, .rightKnee, .rightEar)
            }
        }

        var armJoints: (elbow: VNHumanBodyPoseObservation.JointName, wrist: VNHumanBodyPoseObservation.JointName) {
            switch self {
            case .left: (.leftElbow, .leftWrist)
            case .right: (.rightElbow, .rightWrist)
            }
        }

        var ankleJoint: VNHumanBodyPoseObservation.JointName {
            switch self {
            case .left: .leftAnkle
            case .right: .rightAnkle
            }
        }
    }

    private static func sideOnJoints(
        from observation: VNHumanBodyPoseObservation, side: BodySide
    ) -> (side: BodySide, shoulder: CGPoint, hip: CGPoint, knee: CGPoint, ear: CGPoint)? {
        let joints = side.joints
        guard let shoulder = try? observation.recognizedPoint(joints.shoulder), shoulder.confidence > 0.5,
              let hip = try? observation.recognizedPoint(joints.hip), hip.confidence > 0.5,
              let knee = try? observation.recognizedPoint(joints.knee), knee.confidence > 0.5,
              let ear = try? observation.recognizedPoint(joints.ear), ear.confidence > 0.5
        else { return nil }
        return (side, shoulder.location, hip.location, knee.location, ear.location)
    }

    /// Never throws — the reach line to the bars is presentational context
    /// (Plan V), not a measurement input: all-or-nothing (elbow+wrist
    /// together), independent of the ankle (see `sideOnAnklePoint`).
    private static func sideOnArmPoints(
        from observation: VNHumanBodyPoseObservation, side: BodySide
    ) -> [CGPoint]? {
        let joints = side.armJoints
        guard let elbow = try? observation.recognizedPoint(joints.elbow), elbow.confidence > 0.5,
              let wrist = try? observation.recognizedPoint(joints.wrist), wrist.confidence > 0.5
        else { return nil }
        return [elbow.location, wrist.location]
    }

    /// Never throws — cranks/chainrings occlude ankles often, so a missing
    /// ankle must not cost the arm chain (Plan V); independent of
    /// `sideOnArmPoints`.
    private static func sideOnAnklePoint(
        from observation: VNHumanBodyPoseObservation, side: BodySide
    ) -> CGPoint? {
        guard let ankle = try? observation.recognizedPoint(side.ankleJoint), ankle.confidence > 0.5 else {
            return nil
        }
        return ankle.location
    }
}
