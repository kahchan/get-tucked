import SwiftUI
import SwiftData
import PhotosUI
import Photos

struct CaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var bikes: [Bike]

    @State private var step: CaptureStep = .selectBike
    @State private var selectedBike: Bike?
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var assetIdentifier: String?
    @State private var tapPoints: [CGPoint] = []
    @State private var pendingResult: AnalysisResult?
    // Side-on state
    @State private var sideOnPickerItem: PhotosPickerItem?
    @State private var sideOnImage: UIImage?
    @State private var sideOnAssetIdentifier: String?
    @State private var pendingSideOnPose: SideOnPoseMetrics?
    @State private var analysisError: AnalysisError?
    @State private var showingError = false

    enum CaptureStep: Equatable {
        case selectBike
        case pickPhoto          // head-on · 1 OF 2
        case calibrate          // head-on calibration
        case analysing          // head-on analysis
        case pickSideOnPhoto    // side-on · 2 OF 2
        case analysingSideOn    // side-on analysis
        case reveal             // frontal-area result reveal
        case namePosition
        case done
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(spacing: 0) {
                if step != .pickPhoto {
                    NavHeader(title: stepTitle) {
                        Button {
                            dismiss()
                        } label: {
                            Text("✕")
                                .font(Theme.mono(18))
                                .foregroundStyle(Theme.Palette.fg3)
                        }
                        .buttonStyle(.plain)
                    }
                    SectionDivider()
                }

                stepContent
            }
            .alert("Capture failed", isPresented: $showingError, presenting: analysisError) { _ in
                Button("Try again") { step = .pickPhoto }
                Button("Cancel", role: .cancel) { dismiss() }
            } message: { error in
                Text(error.errorDescription ?? "Unknown error.")
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch step {
            case .selectBike:
                BikePickerStep(bikes: bikes, selected: $selectedBike) {
                    step = .pickPhoto
                }
            case .pickPhoto:
                if let bike = selectedBike {
                    LiveCameraView(bike: bike, onCapture: { image in
                        selectedImage = image  // already normalised in photoOutput delegate
                        assetIdentifier = nil  // live capture has no PHAsset identifier
                        tapPoints = []
                        step = .calibrate
                        Task { await saveToCameraRoll(image) }
                    }, onCancel: { dismiss() })
                }
            case .calibrate:
                if let image = selectedImage {
                    HandlebarCalibrationStep(
                        image: image,
                        tapPoints: $tapPoints
                    ) {
                        step = .analysing
                        Task { await runAnalysis() }
                    }
                }
            case .analysing:
                AnalysingView(label: "ANALYSING…")
            case .pickSideOnPhoto:
                PhotoPickStep(
                    pickerItem: $sideOnPickerItem,
                    instructions: "Stand beside your bike and photograph from directly side-on at hub height.",
                    stepLabel: "SIDE-ON · 2 OF 2"
                ) { image, identifier in
                    sideOnImage = image
                    sideOnAssetIdentifier = identifier
                    step = .analysingSideOn
                    Task { await runSideOnAnalysis() }
                }
            case .analysingSideOn:
                AnalysingView(label: "ANALYSING POSTURE…")
            case .reveal:
                if let result = pendingResult {
                    RevealStep(result: result, sideOnPose: pendingSideOnPose) {
                        step = .namePosition
                    }
                }
            case .namePosition:
                if let result = pendingResult {
                    NamePositionStep(result: result) { label in
                        savePosition(label: label)
                    }
                }
            case .done:
                Text("SAVED")
                    .font(Theme.heading(28))
                    .foregroundStyle(Theme.Palette.acc)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
                    }
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case .selectBike:       "Select bike"
        case .pickPhoto:        "FRONTAL · 1 OF 2"
        case .calibrate:        "Calibrate scale"
        case .analysing:        "Analysing"
        case .pickSideOnPhoto:  "SIDE-ON · 2 OF 2"
        case .analysingSideOn:  "Analysing"
        case .reveal:           "Result"
        case .namePosition:     "Name position"
        case .done:             "Done"
        }
    }

    private func runAnalysis() async {
        guard
            let image = selectedImage,
            let bike = selectedBike,
            tapPoints.count == 2
        else { return }

        do {
            let result = try await AnalysisEngine.analyse(
                image: image,
                handlebarWidthMm: bike.handlebarWidthMm,
                tapPoint0: tapPoints[0],
                tapPoint1: tapPoints[1]
            )
            pendingResult = result
            step = .pickSideOnPhoto   // head-on done → proceed to side-on
        } catch let error as AnalysisError {
            analysisError = error
            showingError = true
            step = .calibrate
        } catch {
            analysisError = .segmentationFailed
            showingError = true
            step = .calibrate
        }
    }

    private func runSideOnAnalysis() async {
        guard let image = sideOnImage,
              let pixelsPerCm = pendingResult?.pixelsPerCm else {
            // Side-on failed or skipped — reveal the frontal-area result anyway
            step = .reveal
            return
        }
        // Pose failure is non-fatal: we still save the position, just without posture metrics.
        pendingSideOnPose = try? await AnalysisEngine.analyseSideOn(
            image: image,
            pixelsPerCm: pixelsPerCm
        )
        step = .reveal
    }

    /// Spec §PhotoKit: source photos belong in the user's Photo Library. Live
    /// capture bypasses PhotosPicker (no PHAsset), so write it there ourselves —
    /// fire-and-forget, since a save failure shouldn't block the capture flow.
    private func saveToCameraRoll(_ image: UIImage) async {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        guard status == .authorized || status == .limited else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: image.jpegData(compressionQuality: 0.9) ?? Data(), options: nil)
        }
    }

    private func savePosition(label: String) {
        guard let result = pendingResult, let bike = selectedBike else { return }
        let position = Position(label: label, bike: bike)
        position.headOnPhotoIdentifier = assetIdentifier
        // Live capture has no PHAsset identifier — persist the image bytes so the
        // detail view can display the frontal photo.
        position.photosData = selectedImage?.compressedForStorage()
        position.handlebarTapPoints = [
            tapPoints[0].x, tapPoints[0].y,
            tapPoints[1].x, tapPoints[1].y,
        ]
        let metrics = PositionMetrics(
            frontalAreaCm2: result.frontalAreaCm2,
            frontalAreaUncertainty: result.frontalAreaUncertaintyCm2,
            pixelsPerCm: result.pixelsPerCm,
            foregroundPixelCount: result.foregroundPixelCount
        )
        metrics.shoulderWidthCm = result.headOnPose?.shoulderWidthCm
        if let pose = pendingSideOnPose {
            metrics.torsoAngleDeg = pose.torsoAngleDeg
            metrics.hipAngleDeg   = pose.hipAngleDeg
            metrics.headDropCm    = pose.headDropCm
        }
        position.sideOnPhotoIdentifier = sideOnAssetIdentifier
        position.metrics = metrics
        context.insert(position)
        step = .done
    }
}

// MARK: - Step views

private struct BikePickerStep: View {
    let bikes: [Bike]
    @Binding var selected: Bike?
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(bikes, id: \.id) { bike in
                        Button {
                            selected = bike
                        } label: {
                            BikePickerRow(bike: bike, isSelected: selected?.id == bike.id)
                        }
                        .buttonStyle(.plain)
                        SectionDivider()
                    }
                }
            }
            AccentButton(label: "NEXT", action: onNext, enabled: selected != nil)
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.md)
                .background(Theme.Palette.bg0)
        }
        .onAppear {
            if bikes.count == 1 { selected = bikes[0] }
        }
    }
}

private struct BikePickerRow: View {
    let bike: Bike
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.md) {
            ZStack {
                Rectangle()
                    .stroke(isSelected ? Theme.Palette.acc : Theme.Palette.line, lineWidth: 1)
                    .frame(width: 18, height: 18)
                if isSelected {
                    Rectangle()
                        .fill(Theme.Palette.acc)
                        .frame(width: 10, height: 10)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(bike.nickname)
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundStyle(Theme.Palette.fg)
                Text("\(Int(bike.handlebarWidthMm)) MM · \(bike.bikeType.displayName.uppercased())")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 60)
        .contentShape(Rectangle())
    }
}

private struct AnalysingView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Theme.mono(12))
            .foregroundStyle(Theme.Palette.fg3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PhotoPickStep: View {
    @Binding var pickerItem: PhotosPickerItem?
    var instructions: String = "The rider should fill most of the frame, facing the camera directly."
    var stepLabel: String = "FRONTAL · 1 OF 2"
    let onPicked: (UIImage, String?) -> Void
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()
            Text(stepLabel)
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.fg3)
                .kerning(0.5)
            Text(instructions)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.Palette.fg2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Text("CHOOSE FROM LIBRARY")
                        .font(Theme.mono(13, weight: .regular))
                        .kerning(0.5)
                    Spacer()
                }
                .foregroundStyle(Theme.Palette.fg)
                .padding(.horizontal, Theme.Space.md)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Control.ghostButtonHeight)
                .overlay(
                    Rectangle()
                        .stroke(Theme.Palette.line, lineWidth: Theme.Control.hairline)
                )
            }
            .allowsHitTesting(!isLoading)
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                isLoading = true
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        let identifier = newItem.itemIdentifier
                        onPicked(image, identifier)
                    }
                    isLoading = false
                }
            }
            .padding(.horizontal, Theme.Space.lg)
            if isLoading {
                Text("LOADING…")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
            }
            Spacer()
        }
    }
}

private struct RevealStep: View {
    let result: AnalysisResult
    let sideOnPose: SideOnPoseMetrics?
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("FRONTAL AREA")
                            .font(Theme.mono(11, weight: .bold))
                            .foregroundStyle(Theme.Palette.fg3)
                            .kerning(0.8)
                            .padding(.top, Theme.Space.xl)

                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
                            Text("\(Int(result.frontalAreaCm2.rounded()))")
                                .font(Theme.mono(60, weight: .bold))
                                .foregroundStyle(Theme.Palette.acc)
                            Text("cm²")
                                .font(Theme.mono(18))
                                .foregroundStyle(Theme.Palette.fg3)
                        }
                        .padding(.top, Theme.Space.xs)

                        Text(AnalysisMath.uncertaintyDisplay(result.frontalAreaUncertaintyCm2))
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.Palette.fg4)
                            .padding(.top, Theme.Space.xs)
                            .padding(.bottom, Theme.Space.lg)

                        SectionDivider()

                        MetricRow(key: "Scale",
                                  value: String(format: "%.1f px/cm", result.pixelsPerCm))
                        if let shoulder = result.headOnPose?.shoulderWidthCm {
                            MetricRow(key: "Shoulder width",
                                      value: String(format: "%.1f cm", shoulder))
                        }
                        if let pose = sideOnPose {
                            MetricRow(key: "Torso angle",
                                      value: "\(Int(pose.torsoAngleDeg.rounded()))°")
                            MetricRow(key: "Hip angle",
                                      value: "\(Int(pose.hipAngleDeg.rounded()))°")
                            MetricRow(key: "Head drop",
                                      value: String(format: "%.1f cm", pose.headDropCm))
                        }
                    }
                    .padding(.horizontal, Theme.Space.lg)
                }

                AccentButton(label: "NAME POSITION", action: onContinue)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.md)
            }
        }
    }
}

private struct NamePositionStep: View {
    let result: AnalysisResult
    let onSave: (String) -> Void

    @State private var label = ""

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(result.frontalAreaCm2.rounded())) cm² · CAPTURED")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
                    .padding(.top, Theme.Space.xl)
                Text("Name this position.")
                    .font(Theme.heading(24))
                    .foregroundStyle(Theme.Palette.fg)
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.bottom, Theme.Space.lg)

            FieldLabel("POSITION NAME")
            MonoField(placeholder: "Hoods, fully loaded", text: $label)

            Text("You'll compare against this name later.")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.Palette.fg3)
                .padding(.horizontal, Theme.Space.lg)
                .padding(.top, Theme.Space.sm)

            Spacer()

            AccentButton(label: "SAVE POSITION",
                         action: { onSave(label.trimmingCharacters(in: .whitespaces)) },
                         enabled: isValid)
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.md)
        }
    }
}

private struct HandlebarCalibrationStep: View {
    let image: UIImage
    @Binding var tapPoints: [CGPoint]
    let onConfirm: () -> Void

    @State private var zoomPoint: CGPoint?

    var body: some View {
        VStack(spacing: 0) {
            instructionBanner

            GeometryReader { proxy in
                // §2.1 fix: compute the actual displayed image rect (aspect-fit)
                // so taps are measured against the image, not the letterbox container.
                let rect = aspectFitRect(imageSize: image.size, in: proxy.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                    tapOverlay(in: rect)
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleTap(location: location, imageRect: rect)
                }
            }

            if let zp = zoomPoint {
                zoomPreview(center: zp)
                    .frame(height: 120)
                    .padding(.vertical, 8)
            }

            confirmButton
        }
    }

    /// Returns the CGRect (in container coords) where the image is actually drawn
    /// when using `.scaledToFit()`. Outside this rect is letterbox/pillarbox padding.
    private func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / container.height
        if imageAspect > containerAspect {
            // Wider than container → letterboxed top/bottom
            let h = container.width / imageAspect
            return CGRect(x: 0, y: (container.height - h) / 2, width: container.width, height: h)
        } else {
            // Taller than container → pillarboxed left/right
            let w = container.height * imageAspect
            return CGRect(x: (container.width - w) / 2, y: 0, width: w, height: container.height)
        }
    }

    private var instructionBanner: some View {
        Text(tapPoints.count == 0
             ? "Tap the left end of your handlebars"
             : tapPoints.count == 1
             ? "Now tap the right end"
             : "Tap to move a point, or confirm")
            .font(Theme.mono(12))
            .foregroundStyle(Theme.Palette.fg)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Theme.Palette.bg1)
    }

    @ViewBuilder
    private func tapOverlay(in rect: CGRect) -> some View {
        ForEach(Array(tapPoints.enumerated()), id: \.offset) { index, unit in
            // unit is in image-space (0–1); map to container space via imageRect
            let px = rect.minX + unit.x * rect.width
            let py = rect.minY + unit.y * rect.height
            Rectangle()
                .strokeBorder(.white, lineWidth: 2)
                .background(Rectangle().fill(index == 0 ? Theme.Palette.acc : Theme.Palette.amb))
                .frame(width: 18, height: 18)
                .position(x: px, y: py)
        }
        if tapPoints.count == 2 {
            Path { path in
                let p0 = CGPoint(x: rect.minX + tapPoints[0].x * rect.width,
                                 y: rect.minY + tapPoints[0].y * rect.height)
                let p1 = CGPoint(x: rect.minX + tapPoints[1].x * rect.width,
                                 y: rect.minY + tapPoints[1].y * rect.height)
                path.move(to: p0)
                path.addLine(to: p1)
            }
            .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
    }

    private func handleTap(location: CGPoint, imageRect: CGRect) {
        // Ignore taps in the letterbox/pillarbox area outside the image.
        guard imageRect.contains(location) else { return }
        // Store as unit coords within the image (0–1), not within the container.
        let unit = CGPoint(
            x: (location.x - imageRect.minX) / imageRect.width,
            y: (location.y - imageRect.minY) / imageRect.height
        )
        zoomPoint = location

        if tapPoints.count < 2 {
            tapPoints.append(unit)
        } else {
            let d0 = hypot(
                (tapPoints[0].x * imageRect.width + imageRect.minX) - location.x,
                (tapPoints[0].y * imageRect.height + imageRect.minY) - location.y
            )
            let d1 = hypot(
                (tapPoints[1].x * imageRect.width + imageRect.minX) - location.x,
                (tapPoints[1].y * imageRect.height + imageRect.minY) - location.y
            )
            if d0 < d1 { tapPoints[0] = unit } else { tapPoints[1] = unit }
        }
    }

    private func zoomPreview(center: CGPoint) -> some View {
        let cropSize: CGFloat = 80
        let scale: CGFloat = 2.5
        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: cropSize * scale, height: cropSize * scale)
            .offset(
                x: -(center.x - cropSize / 2) * scale,
                y: -(center.y - cropSize / 2) * scale
            )
            .frame(width: cropSize, height: cropSize)
            .clipShape(Rectangle())
            .overlay(Rectangle().stroke(Theme.Palette.line, lineWidth: 1))
            .overlay(crosshair)
    }

    private var crosshair: some View {
        ZStack {
            Rectangle().frame(width: 1, height: 20).foregroundStyle(.white)
            Rectangle().frame(width: 20, height: 1).foregroundStyle(.white)
        }
    }

    private var confirmButton: some View {
        AccentButton(label: "CONFIRM SCALE", action: onConfirm, enabled: tapPoints.count == 2)
            .padding(.horizontal, Theme.Space.lg)
            .padding(.vertical, Theme.Space.md)
            .background(Theme.Palette.bg0)
    }
}

// MARK: - UIImage orientation normalisation (§2.3)

extension UIImage {
    /// Redraws the image into a new bitmap with orientation .up, so that
    /// `cgImage` and the SwiftUI display use the same coordinate space.
    func normalisedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return result
    }

    /// Downscaled JPEG for persisting in SwiftData. Full-res stills are several MB;
    /// the detail view only displays at ~800px, so a 1400px long-edge JPEG is plenty.
    func compressedForStorage(maxDimension: CGFloat = 1400, quality: CGFloat = 0.85) -> Data? {
        let longEdge = max(size.width, size.height)
        let scaleFactor = longEdge > maxDimension ? maxDimension / longEdge : 1
        let target = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: quality)
    }
}
