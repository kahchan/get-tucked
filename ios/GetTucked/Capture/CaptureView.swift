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

    enum CaptureStep {
        case selectBike
        case pickPhoto          // head-on · 1 OF 2
        case calibrate          // head-on calibration
        case analysing          // head-on analysis
        case pickSideOnPhoto    // side-on · 2 OF 2
        case analysingSideOn    // side-on analysis
        case namePosition
        case done
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .selectBike:
                    BikePickerStep(bikes: bikes, selected: $selectedBike) {
                        step = .pickPhoto
                    }
                case .pickPhoto:
                    PhotoPickStep(pickerItem: $pickerItem) { image, identifier in
                        selectedImage = image
                        assetIdentifier = identifier
                        tapPoints = []
                        step = .calibrate
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
                    ProgressView("Analysing…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    ProgressView("Analysing posture…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .namePosition:
                    if let result = pendingResult {
                        NamePositionStep(result: result) { label in
                            savePosition(label: label)
                        }
                    }
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
                        }
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Capture failed", isPresented: $showingError, presenting: analysisError) { _ in
                Button("Try again") { step = .pickPhoto }
                Button("Cancel", role: .cancel) { dismiss() }
            } message: { error in
                Text(error.errorDescription ?? "Unknown error.")
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
            // Side-on failed or skipped — go straight to naming
            step = .namePosition
            return
        }
        // Pose failure is non-fatal: we still save the position, just without posture metrics.
        pendingSideOnPose = try? await AnalysisEngine.analyseSideOn(
            image: image,
            pixelsPerCm: pixelsPerCm
        )
        step = .namePosition
    }

    private func savePosition(label: String) {
        guard let result = pendingResult, let bike = selectedBike else { return }
        let position = Position(label: label, bike: bike)
        position.headOnPhotoIdentifier = assetIdentifier
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
        List(bikes, selection: $selected) { bike in
            HStack {
                VStack(alignment: .leading) {
                    Text(bike.nickname).font(.headline)
                    Text("\(bike.handlebarWidthMm, specifier: "%.0f") mm · \(bike.bikeType.displayName)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if selected?.id == bike.id {
                    Image(systemName: "checkmark").foregroundStyle(.accent)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selected = bike }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Next") { onNext() }
                .buttonStyle(.borderedProminent)
                .disabled(selected == nil)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
        }
    }
}

private struct PhotoPickStep: View {
    @Binding var pickerItem: PhotosPickerItem?
    var instructions: String = "The rider should fill most of the frame, facing the camera directly."
    var stepLabel: String = "FRONTAL · 1 OF 2"
    let onPicked: (UIImage, String?) -> Void
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(stepLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(instructions)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Choose from library", systemImage: "photo.badge.plus")
            }
            .buttonStyle(.bordered)
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
            if isLoading { ProgressView() }
            Spacer()
        }
        .padding()
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
                Text("\(result.frontalAreaCm2, specifier: "%.0f") cm² · CAPTURED")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 32)
                Text("Name this position.")
                    .font(.title2.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.bottom, 24)

            Form {
                Section {
                    TextField("Hoods, fully loaded", text: $label)
                        .font(.title3)
                } footer: {
                    Text("You'll compare against this name later.")
                }
            }

            Spacer()

            Button("Save position") { onSave(label.trimmingCharacters(in: .whitespaces)) }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
        }
    }
}

private struct HandlebarCalibrationStep: View {
    let image: UIImage
    @Binding var tapPoints: [CGPoint]
    let onConfirm: () -> Void

    @State private var imageSize: CGSize = .zero
    @State private var zoomPoint: CGPoint?

    var body: some View {
        VStack(spacing: 0) {
            instructionBanner

            GeometryReader { proxy in
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .onAppear { imageSize = proxy.size }
                    tapOverlay(in: proxy.size)
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleTap(location: location, in: proxy.size)
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

    private var instructionBanner: some View {
        Text(tapPoints.count == 0
             ? "Tap the left end of your handlebars"
             : tapPoints.count == 1
             ? "Now tap the right end"
             : "Tap to move a point, or confirm")
            .font(.subheadline)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private func tapOverlay(in size: CGSize) -> some View {
        ForEach(Array(tapPoints.enumerated()), id: \.offset) { index, point in
            let px = point.x * size.width
            let py = point.y * size.height
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .background(Circle().fill(index == 0 ? Color.blue : Color.orange))
                .frame(width: 22, height: 22)
                .position(x: px, y: py)
        }
        if tapPoints.count == 2 {
            Path { path in
                let p0 = CGPoint(x: tapPoints[0].x * size.width, y: tapPoints[0].y * size.height)
                let p1 = CGPoint(x: tapPoints[1].x * size.width, y: tapPoints[1].y * size.height)
                path.move(to: p0)
                path.addLine(to: p1)
            }
            .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
    }

    private func handleTap(location: CGPoint, in size: CGSize) {
        let unit = CGPoint(x: location.x / size.width, y: location.y / size.height)
        zoomPoint = location

        if tapPoints.count < 2 {
            tapPoints.append(unit)
        } else {
            let d0 = hypot(tapPoints[0].x * size.width - location.x, tapPoints[0].y * size.height - location.y)
            let d1 = hypot(tapPoints[1].x * size.width - location.x, tapPoints[1].y * size.height - location.y)
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
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 1))
            .overlay(crosshair)
    }

    private var crosshair: some View {
        ZStack {
            Rectangle().frame(width: 1, height: 20).foregroundStyle(.white)
            Rectangle().frame(width: 20, height: 1).foregroundStyle(.white)
        }
    }

    private var confirmButton: some View {
        Button("Confirm scale →") { onConfirm() }
            .buttonStyle(.borderedProminent)
            .disabled(tapPoints.count < 2)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
    }
}
