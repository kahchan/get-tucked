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
    // The proposed production pipeline (Plan A1): rider instance + whatever's
    // spatially connected to it (bike/bags), dropping unconnected clutter —
    // unlike FOREGROUND, which unions every instance including a coat on the
    // wall or a leaning spare wheel.
    case subject = "SUBJECT"
    // Plan AG retired this split from the shipping UI (structurally
    // untrustworthy — the bike colour is an absence, subject minus person),
    // but it's still the reference implementation, so DEBUG keeps it
    // inspectable here rather than only in tools/matte-lab.
    case twoTone = "TWO-TONE"
}

struct MatteCheckView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var personMatte: UIImage?
    @State private var personCoverage: Double?
    @State private var foregroundMatte: UIImage?
    @State private var foregroundCoverage: Double?
    @State private var subjectMatte: UIImage?
    @State private var subjectCoverage: Double?
    @State private var twoToneMatte: UIImage?
    @State private var mode: SegMode = .person
    @State private var showingMatte = false
    @State private var running = false
    @State private var failed = false

    private var matte: UIImage? {
        switch mode {
        case .person: personMatte
        case .foreground: foregroundMatte
        case .subject: subjectMatte
        case .twoTone: twoToneMatte
        }
    }

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
                        if let subjectCoverage {
                            MetricRow(key: "Subject coverage",
                                      value: String(format: "%.1f%%", subjectCoverage * 100))
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
        subjectMatte = nil
        subjectCoverage = nil
        twoToneMatte = nil
        showingMatte = false
        failed = false
        running = true
        let personFailed = await segmentPerson(image)
        let foregroundFailed = await segmentForeground(image)
        let subjectFailed = await segmentSubject(image)
        buildTwoToneMatte(photo: image)
        failed = personFailed && foregroundFailed && subjectFailed
        running = false
    }

    /// Composites the retired rider/bike split (Plan AG) onto the source
    /// photo for DEBUG inspection only — `MatteRenderer.twoToneOverlay`
    /// already resamples the person mask to the subject mask's resolution,
    /// so the only new work here is flattening overlay onto photo for
    /// display. No-op (silently) when either mask failed to segment.
    private func buildTwoToneMatte(photo: UIImage) {
        guard let subjectCG = subjectMatte?.cgImage, let personCG = personMatte?.cgImage,
              let overlay = MatteRenderer.twoToneOverlay(
                  subjectMask: subjectCG, personMask: personCG,
                  riderColor: UIColor(Theme.Palette.acc), bikeColor: UIColor(Theme.Palette.amb), alpha: 0.5
              ) else { return }
        let renderer = UIGraphicsImageRenderer(size: photo.size)
        twoToneMatte = renderer.image { _ in
            photo.draw(in: CGRect(origin: .zero, size: photo.size))
            overlay.draw(in: CGRect(origin: .zero, size: photo.size))
        }
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

    /// The proposed production pipeline (Plan A1): pick the foreground instance
    /// that overlaps the detected rider rectangle, then union in whatever else
    /// is spatially connected to it (the bike/bags the rider is on) — dropping
    /// disconnected clutter (a coat on the wall, a leaning spare wheel) that
    /// FOREGROUND's blanket union would also pick up.
    private func segmentSubject(_ image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let instanceRequest = VNGenerateForegroundInstanceMaskRequest()
        let rectRequest = VNDetectHumanRectanglesRequest()
        rectRequest.upperBodyOnly = false
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([instanceRequest, rectRequest])
        } catch {
            return true
        }
        guard let result = instanceRequest.results?.first, !result.allInstances.isEmpty else { return true }
        guard let instanceBoxes = instanceBoundingBoxes(mask: result.instanceMask), !instanceBoxes.isEmpty else {
            return true
        }

        // Rider anchor: the largest detected human rectangle, or frame-centre
        // if Vision found none (e.g. a badly occluded shot) — both boxes are
        // in Vision's normalised bottom-left-origin convention.
        let riderBox: CGRect
        if let rects = rectRequest.results,
           let largest = rects.max(by: { $0.boundingBox.width * $0.boundingBox.height
                                        < $1.boundingBox.width * $1.boundingBox.height }) {
            riderBox = largest.boundingBox
        } else {
            riderBox = CGRect(x: 0.35, y: 0.25, width: 0.3, height: 0.5)
        }

        guard let riderInstance = instanceBoxes.max(by: {
            overlapArea($0.value, riderBox) < overlapArea($1.value, riderBox)
        })?.key else { return true }
        let riderInstanceBox = instanceBoxes[riderInstance]!

        // "Connected" = the instance's box falls within a small margin of the
        // rider's box — the bike/bags the rider is on. A margin, not exact
        // pixel-adjacency, since a bike frame/wheel often doesn't touch the
        // rider's silhouette bounding box exactly.
        let margin: CGFloat = 0.06
        let expandedRiderBox = riderInstanceBox.insetBy(dx: -margin, dy: -margin)
        var selected = IndexSet([riderInstance])
        for (index, box) in instanceBoxes where index != riderInstance && expandedRiderBox.intersects(box) {
            selected.insert(index)
        }

        guard let buffer = try? result.generateScaledMaskForImage(forInstances: selected, from: handler) else {
            return true
        }
        let (matteImage, coverage) = renderMatte(buffer)
        subjectMatte = matteImage
        subjectCoverage = coverage
        return matteImage == nil
    }

    /// Scans the (low-res) per-instance mask once and returns each instance's
    /// bounding box, converted to Vision's normalised bottom-left-origin
    /// convention so it's directly comparable to `VNDetectedObjectObservation.boundingBox`.
    private func instanceBoundingBoxes(mask: CVPixelBuffer) -> [Int: CGRect]? {
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

    private func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
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
