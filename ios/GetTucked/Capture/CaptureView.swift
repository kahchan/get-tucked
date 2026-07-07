import SwiftUI
import SwiftData
import PhotosUI
import Photos

struct CaptureView: View {
    @Binding var path: [AppScreen]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var bikes: [Bike]
    @Query(sort: \Position.capturedAt, order: .reverse) private var positions: [Position]

    @State private var step: CaptureStep = .pickPhoto
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
                                .font(Theme.mono(Theme.Control.iconSize))
                                .foregroundStyle(Theme.Palette.fg3)
                                .frame(width: Theme.Control.iconTapTarget, height: Theme.Control.iconTapTarget)
                                .contentShape(Rectangle())
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
        .hideNavBar()
        .onAppear {
            if selectedBike == nil {
                selectedBike = positions.first?.bike ?? bikes.first
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch step {
            case .pickPhoto:
                if let bike = selectedBike {
                    LiveCameraView(bike: bike, bikes: bikes, onBikeChange: { selectedBike = $0 }, onCapture: { image in
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
                    stepLabel: "SIDE-ON · 2 OF 2",
                    onSkip: { step = .reveal }
                ) { image, identifier in
                    sideOnImage = image
                    sideOnAssetIdentifier = identifier
                    step = .analysingSideOn
                    Task { await runSideOnAnalysis() }
                }
            case .analysingSideOn:
                AnalysingView(label: "ANALYSING POSTURE…")
            case .reveal:
                if let result = pendingResult, let photo = selectedImage {
                    RevealStep(result: result, photo: photo, sideOnPose: pendingSideOnPose, path: $path, onContinue: {
                        step = .namePosition
                    }, onRetake: {
                        tapPoints = []
                        pendingResult = nil
                        sideOnImage = nil
                        sideOnAssetIdentifier = nil
                        pendingSideOnPose = nil
                        step = .pickPhoto
                    })
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
        case .pickPhoto:        "FRONTAL · 1 OF 2"
        case .calibrate:        "CALIBRATE SCALE"
        case .analysing:        "ANALYSING"
        case .pickSideOnPhoto:  "SIDE-ON · 2 OF 2"
        case .analysingSideOn:  "ANALYSING"
        case .reveal:           "RESULT"
        case .namePosition:     "NAME POSITION"
        case .done:             "DONE"
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
    var onSkip: (() -> Void)?
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
            if let onSkip {
                GhostButton(label: "SKIP SIDE-ON", action: onSkip)
                    .padding(.horizontal, Theme.Space.lg)
            }
            Spacer()
        }
    }
}

private struct RevealStep: View {
    let result: AnalysisResult
    let photo: UIImage
    let sideOnPose: SideOnPoseMetrics?
    @Binding var path: [AppScreen]
    let onContinue: () -> Void
    let onRetake: () -> Void

    @State private var showingMask = true
    @State private var maskOverlay: UIImage?

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFit()
                            if showingMask, let maskOverlay {
                                Image(uiImage: maskOverlay)
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background(Theme.Palette.bg1)
                        .onAppear {
                            guard let cgMask = result.maskImage.cgImage else { return }
                            maskOverlay = MatteRenderer.tintedOverlay(
                                mask: cgMask, color: UIColor(Theme.Palette.acc), alpha: 0.5
                            )
                        }

                        MaskToggleBar(showingMask: $showingMask)
                        SectionDivider()

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

                            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                                Text(AnalysisMath.uncertaintyDisplay(result.frontalAreaUncertaintyCm2))
                                    .font(Theme.mono(12))
                                    .foregroundStyle(Theme.Palette.fg3)
                                if let scaleWarning = result.scaleWarning {
                                    Text(scaleWarning)
                                        .font(Theme.mono(11))
                                        .foregroundStyle(Theme.Palette.amb)
                                }
                                HowItWorksLink(path: $path)
                                    .padding(.top, Theme.Space.xs)
                            }
                            .padding(.top, Theme.Space.xs)
                            .padding(.bottom, Theme.Space.xl)

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
                }

                GhostButton(label: "RETAKE", action: onRetake)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.sm)

                AccentButton(label: "NAME POSITION", action: onContinue)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.md)
            }
        }
    }
}

private struct MaskToggleBar: View {
    @Binding var showingMask: Bool

    var body: some View {
        HStack(spacing: 0) {
            tab("PHOTO", selected: !showingMask) { showingMask = false }
            tab("MASK", selected: showingMask) { showingMask = true }
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

    // Persisted zoom/pan (committed at gesture end) plus the in-flight gesture
    // deltas, combined for the live transform each frame.
    @State private var zoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1
    @GestureState private var panDelta: CGSize = .zero

    // Which point (if any) is being dragged, and its live screen position —
    // drives the floating loupe. `nil` when not dragging.
    @State private var draggingIndex: Int?
    @State private var dragScreenPoint: CGPoint?
    // Captured once per drag gesture: the point's screen position *before*
    // this drag started. `DragGesture.translation` is cumulative from
    // gesture-start, not incremental, so this has to stay fixed for the
    // duration of one drag rather than being re-derived from `tapPoints`
    // (which mutates on every callback).
    @State private var dragStartUnit: CGPoint?

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            instructionBanner

            GeometryReader { proxy in
                // §2.1 fix: compute the actual displayed image rect (aspect-fit)
                // so taps are measured against the image, not the letterbox container.
                let imageRect = CalibrationTransform.aspectFitRect(imageSize: image.size, in: proxy.size)
                let viewport = CalibrationTransform.Viewport(
                    containerSize: proxy.size,
                    imageRect: imageRect,
                    zoomScale: zoomScale * pinchDelta,
                    panOffset: CGSize(width: panOffset.width + panDelta.width,
                                       height: panOffset.height + panDelta.height)
                )
                ZStack {
                    // Visual-only layer: the scale/offset here is a rendering
                    // transform, not a hit-testing one — gestures live on the
                    // untransformed layers above so their locations/deltas are
                    // always in plain container space, with zoom/pan folded in
                    // explicitly via `CalibrationTransform` instead of relying
                    // on how SwiftUI hit-tests through `scaleEffect`.
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(viewport.zoomScale, anchor: .center)
                        .offset(x: viewport.panOffset.width, y: viewport.panOffset.height)
                        .allowsHitTesting(false)

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(backgroundGesture(viewport: viewport))
                        .onTapGesture { location in
                            handleTap(location: location, viewport: viewport)
                        }

                    // Handles + connecting line, positioned via the pure
                    // transform on this same untransformed layer — their own
                    // drag gestures take priority over the background pan
                    // when a touch starts inside a handle.
                    pointOverlay(viewport: viewport)

                    if let dragScreenPoint {
                        loupe(forScreenPoint: dragScreenPoint, in: viewport)
                            .position(x: dragScreenPoint.x, y: max(60, dragScreenPoint.y - 110))
                            .allowsHitTesting(false)
                    }
                }
                .clipped()
            }

            if zoomScale > 1.01 || panOffset != .zero {
                resetViewButton
            }

            confirmButton
        }
    }

    private var instructionBanner: some View {
        Text(tapPoints.count == 0
             ? "Tap the left end of your handlebars"
             : tapPoints.count == 1
             ? "Now tap the right end"
             : "Pinch to zoom, drag a point to fine-tune")
            .font(Theme.mono(12))
            .foregroundStyle(Theme.Palette.fg)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Theme.Palette.bg1)
    }

    private var resetViewButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                zoomScale = 1
                panOffset = .zero
            }
        } label: {
            Text("RESET VIEW")
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.fg2)
                .kerning(0.5)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.bg1)
    }

    @ViewBuilder
    private func pointOverlay(viewport: CalibrationTransform.Viewport) -> some View {
        if tapPoints.count == 2 {
            Path { path in
                path.move(to: CalibrationTransform.screenPoint(forUnit: tapPoints[0], in: viewport))
                path.addLine(to: CalibrationTransform.screenPoint(forUnit: tapPoints[1], in: viewport))
            }
            .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
        ForEach(Array(tapPoints.enumerated()), id: \.offset) { index, unit in
            let screen = CalibrationTransform.screenPoint(forUnit: unit, in: viewport)
            Rectangle()
                .strokeBorder(.white, lineWidth: 2)
                .background(Rectangle().fill(index == 0 ? Theme.Palette.acc : Theme.Palette.amb))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
                .position(screen)
                .gesture(pointDragGesture(index: index, viewport: viewport))
        }
    }

    private func pointDragGesture(index: Int, viewport: CalibrationTransform.Viewport) -> some Gesture {
        // `value.location` is relative to the handle's own small hit frame,
        // not the container — useless as an absolute position. `.translation`
        // is a stable delta since gesture-start regardless of that, so anchor
        // it to the point's screen position captured once at drag-start.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartUnit == nil { dragStartUnit = tapPoints[index] }
                guard let startUnit = dragStartUnit else { return }
                let startScreen = CalibrationTransform.screenPoint(forUnit: startUnit, in: viewport)
                let liveScreen = CGPoint(x: startScreen.x + value.translation.width,
                                          y: startScreen.y + value.translation.height)
                draggingIndex = index
                dragScreenPoint = liveScreen
                tapPoints[index] = CalibrationTransform.unitPoint(forScreen: liveScreen, in: viewport)
            }
            .onEnded { _ in
                dragStartUnit = nil
                draggingIndex = nil
                dragScreenPoint = nil
            }
    }

    /// Pinch-to-zoom + pan on the image itself. A small `minimumDistance` on
    /// the pan drag lets a plain tap (placing the first two points) still
    /// fall through to `.onTapGesture`.
    private func backgroundGesture(viewport: CalibrationTransform.Viewport) -> some Gesture {
        let magnify = MagnificationGesture()
            .updating($pinchDelta) { value, state, _ in state = value }
            .onEnded { value in
                zoomScale = min(maxZoom, max(minZoom, zoomScale * value))
            }
        let pan = DragGesture(minimumDistance: 10)
            .updating($panDelta) { value, state, _ in state = value.translation }
            .onEnded { value in
                panOffset.width += value.translation.width
                panOffset.height += value.translation.height
            }
        return magnify.simultaneously(with: pan)
    }

    private func handleTap(location: CGPoint, viewport: CalibrationTransform.Viewport) {
        guard tapPoints.count < 2 else { return }
        // Ignore taps outside the image — in the letterbox/pillarbox padding,
        // or panned/zoomed off-canvas.
        let unit = CalibrationTransform.unitPoint(forScreen: location, in: viewport)
        guard (0...1).contains(unit.x), (0...1).contains(unit.y) else { return }
        tapPoints.append(unit)
    }

    /// Zoomed crop of the source image centred on the live drag point, shown
    /// floating above the fingertip so the fingertip doesn't occlude it.
    private func loupe(forScreenPoint screen: CGPoint, in viewport: CalibrationTransform.Viewport) -> some View {
        let unit = CalibrationTransform.unitPoint(forScreen: screen, in: viewport)
        return Image(uiImage: loupeCrop(forUnit: unit))
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 110, height: 110)
            .clipShape(Rectangle())
            .overlay(Rectangle().stroke(Theme.Palette.acc, lineWidth: 1.5))
            .overlay(crosshair)
            .shadow(radius: 6)
    }

    private func loupeCrop(forUnit unit: CGPoint) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let windowPx = min(w, h) * 0.08
        let cx = min(max(unit.x, 0), 1) * w
        let cy = min(max(unit.y, 0), 1) * h
        let rect = CGRect(x: cx - windowPx / 2, y: cy - windowPx / 2, width: windowPx, height: windowPx)
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard rect.width > 0, rect.height > 0, let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
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
