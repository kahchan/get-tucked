import UIKit
import Vision

enum AnalysisError: LocalizedError {
    case noPersonDetected
    case multiplePersonsDetected
    case personClipsFrame
    case segmentationFailed
    case scaleNotCalibrated

    var errorDescription: String? {
        switch self {
        case .noPersonDetected: "No rider found. Step back so your full body is visible."
        case .multiplePersonsDetected: "More than one person detected. Ask helpers to step aside."
        case .personClipsFrame: "Part of your body is cut off. Step back or recompose."
        case .segmentationFailed: "Couldn't compute a segmentation mask."
        case .scaleNotCalibrated: "Scale reference not set. Tap both ends of your handlebars first."
        }
    }
}

struct AnalysisResult {
    let frontalAreaCm2: Double
    let frontalAreaUncertaintyCm2: Double
    let pixelsPerCm: Double
    let foregroundPixelCount: Int
    let maskImage: UIImage
}

struct AnalysisEngine {
    // Uncertainty model: 3% of computed area, reflecting segmentation + scale noise.
    // Revisit with empirical data in Phase 2.
    private static let uncertaintyFraction = 0.03

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

        // Validate person presence and framing.
        try await validatePerson(cgImage: cgImage, imageSize: imageSize)

        // Segment person.
        let mask = try await segmentPerson(cgImage: cgImage)
        let foregroundCount = countForegroundPixels(mask: mask)

        // cm² = pixel count / pixelsPerCm²
        let areaCm2 = Double(foregroundCount) / (pixelsPerCm * pixelsPerCm)
        let uncertainty = areaCm2 * uncertaintyFraction

        let maskUI = UIImage(cgImage: mask)
        return AnalysisResult(
            frontalAreaCm2: areaCm2,
            frontalAreaUncertaintyCm2: uncertainty,
            pixelsPerCm: pixelsPerCm,
            foregroundPixelCount: foregroundCount,
            maskImage: maskUI
        )
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
        // Reject if the box clips any edge (5 px margin).
        let margin = 5.0 / min(imageSize.width, imageSize.height)
        if box.minX < margin || box.minY < margin ||
           box.maxX > 1 - margin || box.maxY > 1 - margin {
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

        guard let result = request.results?.first,
              let maskBuffer = result.pixelBuffer.map({ $0 }) else {
            throw AnalysisError.segmentationFailed
        }

        return try cgImageFromPixelBuffer(maskBuffer, sourceSize: CGSize(width: cgImage.width, height: cgImage.height))
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
}
