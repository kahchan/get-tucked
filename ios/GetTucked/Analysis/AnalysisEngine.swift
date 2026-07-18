import UIKit
import Vision

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
        case .personTooSmallInFrame: "You're too far away. Step closer so your body fills the frame."
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
        // person-only mask exactly as they did before this existed.
        let subjectMask = await segmentSubject(cgImage: cgImage)

        // Area drives off the subject mask (rider+bike+bags — what the wind
        // actually sees, spec §2) when available, else the person mask —
        // same fallback shape as every other optional enhancement here.
        let areaMask = subjectMask ?? mask
        let foregroundCount = countForegroundPixels(mask: areaMask)

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
        let maskImage = (try? await segmentPerson(cgImage: cgImage)).map(UIImage.init(cgImage:))
        return SideOnAnalysis(pose: pose, maskImage: maskImage)
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

        // Spec §3: rider should fill the frame. Require bbox height > 50% of frame.
        // This is a DIFFERENT physical problem from clipping below — too small
        // means too far away (fix: step closer), not too close (fix: step back).
        // Conflating the two under one message told "too far away" users to do
        // the opposite of what would fix it.
        if box.height < 0.5 {
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

    private static func cgImageFromPixelBuffer(_ buffer: CVPixelBuffer, sourceSize: CGSize) throws -> CGImage {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw AnalysisError.segmentationFailed
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let colorSpace = CGColorSpaceCreateDeviceGray()
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
    private static func segmentSubject(cgImage: CGImage) async -> CGImage? {
        let instanceRequest = VNGenerateForegroundInstanceMaskRequest()
        let rectRequest = VNDetectHumanRectanglesRequest()
        rectRequest.upperBodyOnly = false
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([instanceRequest, rectRequest])
        } catch {
            return nil
        }
        guard let result = instanceRequest.results?.first, !result.allInstances.isEmpty else { return nil }
        guard let instanceBoxes = instanceBoundingBoxes(mask: result.instanceMask), !instanceBoxes.isEmpty else {
            return nil
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
            return nil
        }
        let selected = AnalysisMath.connectedInstances(riderInstance: riderInstance, instanceBoxes: instanceBoxes)

        guard let buffer = try? result.generateScaledMaskForImage(forInstances: selected, from: handler) else {
            return nil
        }
        return try? cgImageFromPixelBuffer(buffer, sourceSize: CGSize(width: cgImage.width, height: cgImage.height))
    }

    /// Scans the (low-res) per-instance mask once and returns each instance's
    /// bounding box, converted to Vision's normalised bottom-left-origin
    /// convention so it's directly comparable to
    /// `VNDetectedObjectObservation.boundingBox`.
    private static func instanceBoundingBoxes(mask: CVPixelBuffer) -> [Int: CGRect]? {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let w = CVPixelBufferGetWidth(mask)
        let h = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
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
        guard !minX.isEmpty else { return nil }

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
        return boxes
    }

    // MARK: - Pixel count

    private static func countForegroundPixels(mask: CGImage) -> Int {
        guard let dataProvider = mask.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        // Vision person segmentation: 255 = foreground, 0 = background.
        // Threshold of 128 tolerates soft edges. Must stride by mask.bytesPerRow,
        // not scan the buffer linearly — see AnalysisMath.countForegroundPixels.
        return AnalysisMath.countForegroundPixels(
            bytes: bytes, width: mask.width, height: mask.height, bytesPerRow: mask.bytesPerRow
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
        return HeadOnPoseMetrics(
            shoulderWidthCm: shoulderWidthCm,
            leftShoulder: leftShoulder.location,
            rightShoulder: rightShoulder.location,
            armPoints: armPoints(from: observation),
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
