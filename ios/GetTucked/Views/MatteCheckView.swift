#if DEBUG
import SwiftUI
import PhotosUI
import Vision

/// Debug-only harness to eyeball Apple Vision segmentation matte quality on real
/// cyclist photos (HANDOFF §1.2 open risk). Pick a photo, run `.accurate` person
/// segmentation, and toggle between the photo and its raw matte. Not shipped in
/// release builds.
private enum SegMode: String, CaseIterable {
    case person = "PERSON"
    case foreground = "FOREGROUND"
}

struct MatteCheckView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var personMatte: UIImage?
    @State private var personCoverage: Double?
    @State private var foregroundMatte: UIImage?
    @State private var foregroundCoverage: Double?
    @State private var mode: SegMode = .person
    @State private var showingMatte = false
    @State private var running = false
    @State private var failed = false

    private var matte: UIImage? { mode == .person ? personMatte : foregroundMatte }

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "MATTE CHECK")
                SectionDivider()

                if photo != nil {
                    ModeToggleBar(mode: $mode)
                    SectionDivider()
                    PhotoToggleBar(showingMatte: $showingMatte, hasMatte: matte != nil)
                    SectionDivider()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let display = showingMatte ? matte : photo
                        if let display {
                            Image(uiImage: display)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .background(Theme.Palette.bg1)
                        }

                        if running {
                            Text("SEGMENTING…")
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.Palette.fg3)
                                .padding(Theme.Space.lg)
                        }
                        if failed {
                            Text("No segmentation result — no person detected?")
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.Palette.amb)
                                .padding(Theme.Space.lg)
                        }
                        if let personCoverage {
                            MetricRow(key: "Person coverage",
                                      value: String(format: "%.1f%%", personCoverage * 100))
                                .padding(.horizontal, Theme.Space.lg)
                        }
                        if let foregroundCoverage {
                            MetricRow(key: "Foreground coverage",
                                      value: String(format: "%.1f%%", foregroundCoverage * 100))
                                .padding(.horizontal, Theme.Space.lg)
                        }
                        if let photo {
                            MetricRow(key: "Source",
                                      value: "\(Int(photo.size.width))×\(Int(photo.size.height))")
                                .padding(.horizontal, Theme.Space.lg)
                        }
                    }
                }

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    HStack {
                        Text("PICK A PHOTO")
                            .font(Theme.mono(14, weight: .bold))
                            .kerning(0.5)
                        Spacer()
                        Text("→").font(Theme.mono(14, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, Theme.Space.md)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.Control.accentButtonHeight)
                    .background(Theme.Palette.acc)
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.md)
            }
        }
        .hideNavBar()
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)?.normalisedOrientation() else { return }
        photo = image
        personMatte = nil
        personCoverage = nil
        foregroundMatte = nil
        foregroundCoverage = nil
        showingMatte = false
        failed = false
        running = true
        let personFailed = await segmentPerson(image)
        let foregroundFailed = await segmentForeground(image)
        failed = personFailed && foregroundFailed
        running = false
    }

    private func segmentPerson(_ image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        do {
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
        } catch {
            return true
        }
        guard let result = request.results?.first else { return true }

        let buffer = result.pixelBuffer
        let (image, coverage) = renderMatte(buffer)
        personMatte = image
        personCoverage = coverage
        return image == nil
    }

    private func segmentForeground(_ image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
        } catch {
            return true
        }
        guard let result = request.results?.first, !result.allInstances.isEmpty else { return true }
        guard let buffer = try? result.generateScaledMaskForImage(forInstances: result.allInstances,
                                                                    from: handler) else { return true }

        let (matteImage, coverage) = renderMatte(buffer)
        foregroundMatte = matteImage
        foregroundCoverage = coverage
        return matteImage == nil
    }

    private func renderMatte(_ buffer: CVPixelBuffer) -> (UIImage?, Double?) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return (nil, nil) }
        let bytes = base.assumingMemoryBound(to: UInt8.self)

        var foreground = 0
        for y in 0 ..< h {
            let row = y * rowBytes
            for x in 0 ..< w where bytes[row + x] >= 128 { foreground += 1 }
        }
        let coverage = Double(foreground) / Double(max(1, w * h))

        let space = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(data: base, width: w, height: h, bitsPerComponent: 8,
                                   bytesPerRow: rowBytes, space: space,
                                   bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let cg = ctx.makeImage() else { return (nil, coverage) }
        return (UIImage(cgImage: cg), coverage)
    }
}

private struct ModeToggleBar: View {
    @Binding var mode: SegMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SegMode.allCases, id: \.self) { candidate in
                tab(candidate.rawValue, selected: mode == candidate) { mode = candidate }
            }
        }
        .frame(height: 40)
    }

    private func tab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(11, weight: selected ? .bold : .regular))
                .foregroundStyle(selected ? Theme.Palette.acc : Theme.Palette.fg3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if selected { Rectangle().fill(Theme.Palette.acc).frame(height: 2) }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct PhotoToggleBar: View {
    @Binding var showingMatte: Bool
    let hasMatte: Bool

    var body: some View {
        HStack(spacing: 0) {
            tab("PHOTO", selected: !showingMatte) { showingMatte = false }
            tab("MATTE", selected: showingMatte) { if hasMatte { showingMatte = true } }
        }
        .frame(height: 40)
    }

    private func tab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(11, weight: selected ? .bold : .regular))
                .foregroundStyle(selected ? Theme.Palette.acc : Theme.Palette.fg3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if selected { Rectangle().fill(Theme.Palette.acc).frame(height: 2) }
                }
        }
        .buttonStyle(.plain)
    }
}
#endif
