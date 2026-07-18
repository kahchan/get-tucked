import XCTest
import Vision
import UIKit
@testable import GetTucked

/// W1 spike harness (Plan W) — throwaway, not a correctness test. Answers
/// one question: does `VNGenerateForegroundInstanceMaskRequest` (iOS 17
/// subject lifting, `allInstances`) matte rider+bike+bags as one clean
/// subject on the hard case — night shot, white car directly behind, black
/// wall beside — better than today's person-only
/// `VNGeneratePersonSegmentationRequest`?
///
/// Test-target only (see project.yml — `GetTuckedTests/` never ships in the
/// `GetTucked` app target) so this never reaches a release build even though
/// it isn't wrapped in `#if DEBUG`.
///
/// Not part of the normal green suite: it `XCTSkip`s itself when no fixtures
/// are present, so `xcodebuild test` on a clean checkout stays green. To run
/// the actual spike:
///
/// 1. Drop 3-4 JPEGs from the device pass (both frontal night shots, plus a
///    daylight one if available) into `~/Documents/get-tucked-fixtures/` on
///    the Mac — the simulator reads the host filesystem directly, no
///    simulator-side copy needed.
/// 2. Run just this test (Xcode: click the diamond next to the test method,
///    or `xcodebuild test -only-testing:GetTuckedTests/SubjectMaskSpikeHarness`).
/// 3. It writes one side-by-side PNG per fixture (original / person mask /
///    foreground-instance mask, tinted) to the simulator's tmp directory and
///    prints the folder path to the test log.
/// 4. Kah eyeballs the pairs (see plans/open-human-steps.md for the pass/fail
///    call) — that verdict, not this harness, decides whether Plan W2 lands.
final class SubjectMaskSpikeHarness: XCTestCase {
    private enum SpikeError: Error { case noResult, decodeFailed }

    /// `FileManager.homeDirectoryForCurrentUser` is unavailable on iOS (even
    /// in-simulator, where the process technically runs against the host
    /// filesystem) — `SIMULATOR_HOST_HOME` is the documented escape hatch
    /// Xcode sets in every simulated process's environment for exactly this.
    private var fixturesURL: URL {
        let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent("Documents/get-tucked-fixtures", isDirectory: true)
    }

    func testWriteSideBySideMasksForFixtures() throws {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: fixturesURL, includingPropertiesForKeys: nil) else {
            throw XCTSkip("No fixtures directory at \(fixturesURL.path) — drop 3-4 device-pass JPEGs there to run this spike.")
        }
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]
        let files = entries.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        guard !files.isEmpty else {
            throw XCTSkip("\(fixturesURL.path) exists but has no jpg/jpeg/png/heic files.")
        }

        let outputDir = fm.temporaryDirectory.appendingPathComponent("subject-mask-spike", isDirectory: true)
        try? fm.removeItem(at: outputDir)
        try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var written = 0
        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let image = UIImage(data: data)?.normalisedOrientation(),
                  let cgImage = image.cgImage
            else { continue }

            let personMask = try? runPersonSegmentation(cgImage: cgImage)
            let subjectMask = try? runForegroundInstanceMask(cgImage: cgImage)

            let outputURL = outputDir.appendingPathComponent("\(file.deletingPathExtension().lastPathComponent)-compare.png")
            if writeSideBySide(original: image, personMask: personMask, subjectMask: subjectMask, to: outputURL) {
                written += 1
            }
        }

        XCTAssertGreaterThan(written, 0, "found fixture files but none decoded/segmented/wrote successfully")
        // swiftlint:disable:next no_direct_standard_out_logs
        print("W1 spike: wrote \(written) side-by-side comparison(s) to \(outputDir.path)")
    }

    // MARK: - The two requests under comparison

    /// Today's production request (mirrors `AnalysisEngine.segmentPerson`).
    private func runPersonSegmentation(cgImage: CGImage) throws -> CGImage {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        guard let result = request.results?.first else { throw SpikeError.noResult }
        return try grayscaleCGImage(from: result.pixelBuffer)
    }

    /// The candidate under test: plain `allInstances` union — deliberately
    /// the blunt version, not MatteCheckView's smarter "connected to the
    /// rider" heuristic (Plan A1's proposed production pipeline). This spike
    /// asks the simpler question first: does the raw subject-lift matte even
    /// look right on the hard case before layering heuristics on top.
    private func runForegroundInstanceMask(cgImage: CGImage) throws -> CGImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw SpikeError.noResult
        }
        let buffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        return try grayscaleCGImage(from: buffer)
    }

    // MARK: - Pixel plumbing (standalone copy — this harness is throwaway
    // scaffolding, not a place to punch a hole in AnalysisEngine's `private`s)

    private func grayscaleCGImage(from buffer: CVPixelBuffer) throws -> CGImage {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { throw SpikeError.decodeFailed }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(buffer)

        // generateScaledMaskForImage returns one-component float32; the
        // person-segmentation buffer is already 8-bit gray (matches
        // AnalysisEngine's own request configuration) — normalise both to an
        // 8-bit gray CGImage so the side-by-side composite is uniform.
        if pixelFormat == kCVPixelFormatType_OneComponent8 {
            let colorSpace = CGColorSpaceCreateDeviceGray()
            guard let context = CGContext(
                data: baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
            ), let image = context.makeImage() else { throw SpikeError.decodeFailed }
            return image
        }

        // Float32 mask (foreground-instance request): 0 = background, 1 = foreground.
        let floats = baseAddress.assumingMemoryBound(to: Float32.self)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.size
        var gray = [UInt8](repeating: 0, count: width * height)
        for y in 0 ..< height {
            let row = y * floatsPerRow
            for x in 0 ..< width {
                gray[y * width + x] = floats[row + x] > 0.5 ? 255 : 0
            }
        }
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { throw SpikeError.decodeFailed }
        gray.withUnsafeBytes { ptr in
            context.data?.copyMemory(from: ptr.baseAddress!, byteCount: gray.count)
        }
        guard let image = context.makeImage() else { throw SpikeError.decodeFailed }
        return image
    }

    /// Three panels side by side at a common height: original photo, person
    /// mask, foreground-instance mask (either panel is a plain gray fill
    /// reading "N/A" in the console log — not on the image itself, this
    /// harness has no text-drawing needs — when its request failed).
    private func writeSideBySide(original: UIImage, personMask: CGImage?, subjectMask: CGImage?, to url: URL) -> Bool {
        let panelHeight: CGFloat = 900
        let scale = panelHeight / original.size.height
        let panelWidth = original.size.width * scale
        let totalSize = CGSize(width: panelWidth * 3, height: panelHeight)

        let renderer = UIGraphicsImageRenderer(size: totalSize)
        let composed = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: totalSize))

            original.draw(in: CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight))

            if let personMask {
                UIImage(cgImage: personMask).draw(in: CGRect(x: panelWidth, y: 0, width: panelWidth, height: panelHeight))
            }
            if let subjectMask {
                UIImage(cgImage: subjectMask).draw(in: CGRect(x: panelWidth * 2, y: 0, width: panelWidth, height: panelHeight))
            }
        }

        guard let pngData = composed.pngData() else { return false }
        return (try? pngData.write(to: url)) != nil
    }
}
