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
    // Uncertainty model: 3% of computed area, reflecting segmentation + scale noise.
    private static let uncertaintyFraction = 0.03

    // MARK: - Head-on analysis (frontal area + head-on pose)

    static func analyse(
        image: UIImage,
        handlebarWidthMm: Double,
        tapPoint0: CGPoint,
        tapPoint1: CGPoint
    ) async throws -> AnalysisResult {
        let handlebarWidthCm = handlebarWidthMm / 10.0
        guard let cgImage = image.cgImage else { throw AnalysisError.segmentationFailed }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Scale: tap points are in unit coords (0–1); convert to pixels.
        let p0 = CGPoint(x: tapPoint0.x * imageSize.width, y: tapPoint0.y * imageSize.height)
        let p1 = CGPoint(x: tapPoint1.x * imageSize.width, y: tapPoint1.y * imageSize.height)
        let handlebarPixels = hypot(p1.x - p0.x, p1.y - p0.y)
        guard handlebarPixels > 1 else { throw AnalysisError.scaleNotCalibrated }
        let pixelsPerCm = handlebarPixels / handlebarWidthCm

        try await validatePerson(cgImage: cgImage, imageSize: imageSize)

        let mask = try await segmentPerson(cgImage: cgImage)
        let foregroundCount = countForegroundPixels(mask: mask)

        // §2.2 fix: Vision mask resolution ≠ source resolution in general.
        // pixelsPerCm was derived from source image pixel coords; rescale it
        // to mask space before computing area so both quantities are in the same
        // pixel coordinate system.
        let maskPixelsPerCm = pixelsPerCm * (Double(mask.width) / Double(cgImage.width))
        let areaCm2 = Double(foregroundCount) / (maskPixelsPerCm * maskPixelsPerCm)
        let uncertainty = areaCm2 * uncertaintyFraction
        let maskUI = UIImage(cgImage: mask)

        let headOnPose = try? await estimateHeadOnPose(cgImage: cgImage, pixelsPerCm: pixelsPerCm)

        return AnalysisResult(
            frontalAreaCm2: areaCm2,
            frontalAreaUncertaintyCm2: uncertainty,
            pixelsPerCm: pixelsPerCm,
            foregroundPixelCount: foregroundCount,
            maskImage: maskUI,
            headOnPose: headOnPose
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

        guard let observations = request.results, !observations.isEmpty else {
            throw AnalysisError.noPersonDetected
        }
        guard observations.count == 1 else {
            throw AnalysisError.multiplePersonsDetected
        }
        let box = observations[0].boundingBox // normalised, origin bottom-left

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

        let shoulderWidthNorm = abs(leftShoulder.location.x - rightShoulder.location.x)
        // Convert: norm units × image pixel width → pixels → cm
        let shoulderWidthPx = shoulderWidthNorm * Double(cgImage.width)
        let shoulderWidthCm = shoulderWidthPx / pixelsPerCm

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

        // Torso angle: angle of (shoulder - hip) vector from vertical (0° = upright).
        // In normalised coords y increases upward, so shoulder.y > hip.y when upright.
        let torsoVec = CGPoint(
            x: shoulder.location.x - hip.location.x,
            y: shoulder.location.y - hip.location.y
        )
        // atan2(x, y) gives angle from the +y axis (vertical) clockwise.
        let torsoAngleDeg = abs(atan2(torsoVec.x, torsoVec.y) * 180 / .pi)

        // Hip angle: interior angle at hip between torso line (hip→shoulder) and thigh (hip→knee).
        let toShoulder = CGPoint(
            x: shoulder.location.x - hip.location.x,
            y: shoulder.location.y - hip.location.y
        )
        let toKnee = CGPoint(
            x: knee.location.x - hip.location.x,
            y: knee.location.y - hip.location.y
        )
        let dot = toShoulder.x * toKnee.x + toShoulder.y * toKnee.y
        let magA = hypot(toShoulder.x, toShoulder.y)
        let magB = hypot(toKnee.x, toKnee.y)
        let hipAngleDeg = acos(max(-1, min(1, dot / (magA * magB)))) * 180 / .pi

        // Head drop: positive distance ear is below the shoulder in cm.
        // In normalised coords y increases upward, so negative dy means ear is lower.
        let earDropNorm = shoulder.location.y - ear.location.y
        let headDropCm = earDropNorm * Double(cgImage.height) / pixelsPerCm

        return SideOnPoseMetrics(
            torsoAngleDeg: torsoAngleDeg,
            hipAngleDeg: hipAngleDeg,
            headDropCm: headDropCm
        )
    }
}
