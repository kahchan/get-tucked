import UIKit
import Vision

enum AnalysisError: LocalizedError {
    case noPersonDetected
    case multiplePersonsDetected
    case personClipsFrame
    case segmentationFailed
    case scaleNotCalibrated
    case poseNotDetected

    var errorDescription: String? {
        switch self {
        case .noPersonDetected: "No rider found. Step back so your full body is visible."
        case .multiplePersonsDetected: "More than one person detected. Ask helpers to step aside."
        case .personClipsFrame: "Part of your body is cut off. Step back or recompose."
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
    let maskImage: UIImage
    let headOnPose: HeadOnPoseMetrics?
    /// Set when the computed shoulder width is outside a plausible human
    /// range — usually a mis-tapped scale reference, not an unusual rider.
    /// Surfaced on the reveal screen; never blocks the save (Plan A3).
    let scaleWarning: String?
}

/// Pose metrics computable from the head-on photo.
struct HeadOnPoseMetrics {
    /// Shoulder-to-shoulder distance in cm, derived from VNHumanBodyPoseObservation.
    let shoulderWidthCm: Double
}

/// Pose metrics computable from the side-on photo (Phase 2.5).
struct SideOnPoseMetrics {
    /// Angle of shoulder→hip vector from vertical. 0° = fully upright, 90° = horizontal.
    let torsoAngleDeg: Double
    /// Interior angle at the hip between the torso line (hip→shoulder) and thigh (hip→knee).
    let hipAngleDeg: Double
    /// Vertical distance the ear sits below the shoulder (positive = lower than shoulder).
    let headDropCm: Double
}

struct AnalysisEngine {
    // MARK: - Head-on analysis (frontal area + head-on pose)

    static func analyse(
        image: UIImage,
        handlebarWidthMm: Double,
        tapPoint0: CGPoint,
        tapPoint1: CGPoint
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

        try await validatePerson(cgImage: cgImage, imageSize: imageSize)

        let mask = try await segmentPerson(cgImage: cgImage)
        let foregroundCount = countForegroundPixels(mask: mask)

        // §2.2 fix: Vision mask resolution ≠ source resolution in general.
        // Rescale pixelsPerCm into mask space so area and scale share pixel units.
        let maskPixelsPerCm = AnalysisMath.maskPixelsPerCm(
            sourcePixelsPerCm: pixelsPerCm, maskWidth: mask.width, sourceWidth: cgImage.width
        )
        let areaCm2 = AnalysisMath.frontalAreaCm2(
            foregroundPixelCount: foregroundCount, maskPixelsPerCm: maskPixelsPerCm
        )
        let uncertainty = AnalysisMath.uncertaintyCm2(areaCm2: areaCm2)
        let maskUI = UIImage(cgImage: mask)

        let headOnPose = try? await estimateHeadOnPose(cgImage: cgImage, pixelsPerCm: pixelsPerCm)

        var scaleWarning: String?
        if let shoulderCm = headOnPose?.shoulderWidthCm,
           !AnalysisMath.isShoulderWidthPlausible(shoulderCm) {
            scaleWarning = "Shoulder width reads \(Int(shoulderCm.rounded())) cm — check your taps and the bike's bar width."
        }

        return AnalysisResult(
            frontalAreaCm2: areaCm2,
            frontalAreaUncertaintyCm2: uncertainty,
            pixelsPerCm: pixelsPerCm,
            foregroundPixelCount: foregroundCount,
            maskImage: maskUI,
            headOnPose: headOnPose,
            scaleWarning: scaleWarning
        )
    }

    // MARK: - Side-on analysis (posture metrics, Phase 2.5)

    static func analyseSideOn(
        image: UIImage,
        pixelsPerCm: Double
    ) async throws -> SideOnPoseMetrics {
        guard let cgImage = image.cgImage else { throw AnalysisError.segmentationFailed }
        return try await estimateSideOnPose(cgImage: cgImage, pixelsPerCm: pixelsPerCm)
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
        // Do NOT reject for touching the bottom edge — full-body cycling shots
        // routinely have feet at the frame bottom. Only reject if the top, left, or
        // right clips significantly (rider is too close / poorly framed).
        let clipMargin = 5.0 / min(imageSize.width, imageSize.height)
        if box.height < 0.5 {
            throw AnalysisError.personClipsFrame
        }
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

    // MARK: - Pixel count

    private static func countForegroundPixels(mask: CGImage) -> Int {
        guard let dataProvider = mask.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        let count = CFDataGetLength(data)
        var foreground = 0
        // Vision person segmentation: 255 = foreground, 0 = background.
        // Use threshold of 128 to tolerate soft edges.
        for i in 0 ..< count {
            if bytes[i] >= 128 { foreground += 1 }
        }
        return foreground
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

        return HeadOnPoseMetrics(shoulderWidthCm: shoulderWidthCm)
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

        let shoulder = try observation.recognizedPoint(.leftShoulder)
        let hip = try observation.recognizedPoint(.leftHip)
        let knee = try observation.recognizedPoint(.leftKnee)
        let ear = try observation.recognizedPoint(.leftEar)

        guard shoulder.confidence > 0.5, hip.confidence > 0.5,
              knee.confidence > 0.5, ear.confidence > 0.5 else {
            throw AnalysisError.poseNotDetected
        }

        let torsoAngleDeg = AnalysisMath.torsoAngleDeg(
            shoulder: shoulder.location, hip: hip.location
        )
        let hipAngleDeg = AnalysisMath.hipAngleDeg(
            shoulder: shoulder.location, hip: hip.location, knee: knee.location
        )
        let headDropCm = AnalysisMath.headDropCm(
            shoulderY: shoulder.location.y, earY: ear.location.y,
            imageHeightPx: cgImage.height, pixelsPerCm: pixelsPerCm
        )

        return SideOnPoseMetrics(
            torsoAngleDeg: torsoAngleDeg,
            hipAngleDeg: hipAngleDeg,
            headDropCm: headDropCm
        )
    }
}
