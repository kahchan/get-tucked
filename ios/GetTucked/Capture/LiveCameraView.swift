import SwiftUI
import AVFoundation
import CoreMotion
import Vision

// MARK: - Live camera view (Phase 2.3)

/// Full-screen camera preview with ARKit level/perp enforcement and Vision
/// real-time segmentation confidence. Replaces PhotosPicker for head-on capture.
struct LiveCameraView: View {
    let bike: Bike
    var bikes: [Bike] = []
    var onBikeChange: (Bike) -> Void = { _ in }
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    @StateObject private var session = CameraSession()
    @State private var captureFlash = false
    @State private var showingBikePicker = false

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            if session.permissionDenied {
                PermissionDeniedOverlay(onCancel: onCancel)
            } else {
                // Camera feed
                CameraPreviewLayer(session: session.captureSession)
                    .ignoresSafeArea()

                // HUD overlay
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            showingBikePicker = true
                        } label: {
                            BikeChip(name: bike.nickname)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button(action: onCancel) {
                            Text("✕")
                                .font(Theme.mono(18))
                                .foregroundStyle(Theme.Palette.fg)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.md)

                    LevelLine(deviationDeg: session.tiltDeg)
                        .padding(.top, Theme.Space.sm)

                    Spacer()

                    VStack(spacing: Theme.Space.lg) {
                        StatusPillRow(
                            levelOK: session.levelOK,
                            perpOK: session.perpOK,
                            bgOK: session.bgOK
                        )
                        CaptureButton(enabled: session.allPassed) {
                            session.capturePhoto { image in
                                captureFlash = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    captureFlash = false
                                    onCapture(image)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 48)
                }

                if captureFlash {
                    Color.white.opacity(0.6)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
        }
        .onAppear { session.start(bike: bike) }
        .onDisappear { session.stop() }
        .sheet(isPresented: $showingBikePicker) {
            BikePickerSheet(bikes: bikes, selected: bike) { picked in
                onBikeChange(picked)
                showingBikePicker = false
            }
        }
    }
}

// MARK: - HUD sub-views

private struct BikeChip: View {
    let name: String

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("SHOOTING ON")
                    .font(Theme.mono(8))
                    .foregroundStyle(Theme.Palette.fg4)
                    .kerning(1)
                Text(name.uppercased())
                    .font(Theme.heading(13))
                    .foregroundStyle(Theme.Palette.fg)
            }
            Text("▾")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.Palette.acc)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.Palette.bg0.opacity(0.72))
        .overlay(Rectangle().stroke(Theme.Palette.line, lineWidth: 1))
    }
}

private struct LevelLine: View {
    let deviationDeg: Double

    // Maps ±10° to full left/right; clamp display width.
    private var offsetFraction: Double { max(-1, min(1, deviationDeg / 10.0)) }
    private var color: Color { abs(deviationDeg) < 2 ? Theme.Palette.acc : Theme.Palette.amb }

    var body: some View {
        GeometryReader { geo in
            let centre = geo.size.width / 2
            let offset = offsetFraction * (geo.size.width * 0.35)

            ZStack(alignment: .leading) {
                // Rail
                Rectangle()
                    .fill(Theme.Palette.line)
                    .frame(height: 1)
                // Indicator tick
                Rectangle()
                    .fill(color)
                    .frame(width: 3, height: 16)
                    .offset(x: centre + offset - 1.5)
            }
        }
        .frame(height: 16)
        .padding(.horizontal, Theme.Space.lg)
        .animation(.easeOut(duration: 0.1), value: deviationDeg)
    }
}

private struct StatusPillRow: View {
    let levelOK: Bool
    let perpOK: Bool
    let bgOK: Bool

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            StatusPill(label: "LEVEL", state: levelOK ? .ok : .warning)
            StatusPill(label: "PERP",  state: perpOK  ? .ok : .warning)
            StatusPill(label: "BG",    state: bgOK    ? .ok : .warning)
        }
    }
}

private struct CaptureButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(enabled ? Theme.Palette.acc : Theme.Palette.line, lineWidth: 3)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(enabled ? Theme.Palette.acc : Theme.Palette.line)
                    .frame(width: 56, height: 56)
            }
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }
}

private struct PermissionDeniedOverlay: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()
            Text("CAMERA ACCESS REQUIRED")
                .font(Theme.heading(22))
                .foregroundStyle(Theme.Palette.fg)
            Text("Go to Settings → Get Tucked → Camera and allow access.")
                .font(Theme.mono(13))
                .foregroundStyle(Theme.Palette.fg3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.xl)
            AccentButton(label: "OPEN SETTINGS") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.horizontal, Theme.Space.xl)
            Spacer()
            GhostButton(label: "CANCEL", action: onCancel)
                .padding(.horizontal, Theme.Space.xl)
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AVFoundation preview layer (UIViewRepresentable)

struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        // Lock the preview to portrait — without an explicit rotation angle the
        // back-camera connection defaults to landscape and the feed shows sideways.
        if let conn = view.previewLayer.connection, conn.isVideoRotationAngleSupported(90) {
            conn.videoRotationAngle = 90
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Camera session

// Not @MainActor: AVFoundation requires startRunning() / stopRunning() on a
// background queue. @Published updates are pushed to main explicitly.
final class CameraSession: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()

    @Published var tiltDeg: Double = 0
    @Published var levelOK = false
    @Published var perpOK = false
    @Published var bgOK = false
    @Published var permissionDenied = false

    // LEVEL + PERP are physically enforced and gate the shutter. BG is advisory —
    // a low-contrast background degrades the matte but shouldn't dead-lock capture.
    var allPassed: Bool { levelOK && perpOK }

    private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureVideoDataOutput()
    private let motionManager = CMMotionManager()
    private var captureCompletion: ((UIImage) -> Void)?
    private var bike: Bike?

    // AVFoundation session must be configured and run on a dedicated serial queue.
    private let sessionQueue = DispatchQueue(label: "com.gettucked.camera.session", qos: .userInitiated)
    // Segmentation runs off the video-frame callback; keep it off the session queue.
    private let segmentationQueue = DispatchQueue(label: "com.gettucked.camera.segmentation", qos: .userInitiated)
    // Real-time segmentation is throttled — running it every frame at photo
    // resolution pegs the CPU and freezes the device.
    private var lastSegmentation: CFTimeInterval = 0
    private let segmentationInterval: CFTimeInterval = 0.33

    // Pill thresholds
    private let levelThresholdDeg = 2.0
    private let perpThresholdDeg  = 5.0
    private let bgConfidenceMin   = 0.6

    func start(bike: Bike) {
        self.bike = bike
        sessionQueue.async { [weak self] in self?.configureSession() }
        startMotion()
    }

    func stop() {
        sessionQueue.async { [weak self] in self?.captureSession.stopRunning() }
        motionManager.stopDeviceMotionUpdates()
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Session setup (runs on sessionQueue)

    private func configureSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            DispatchQueue.main.async { self.permissionDenied = true }
            return
        }
        if status == .notDetermined {
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .video) { g in granted = g; semaphore.signal() }
            semaphore.wait()
            guard granted else {
                DispatchQueue.main.async { self.permissionDenied = true }
                return
            }
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        if captureSession.canAddInput(input)  { captureSession.addInput(input) }
        if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }
        videoOutput.setSampleBufferDelegate(self, queue: segmentationQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }

        // Portrait rotation for the captured still, matching the preview.
        if let conn = photoOutput.connection(with: .video), conn.isVideoRotationAngleSupported(90) {
            conn.videoRotationAngle = 90
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    // MARK: - CMMotionManager for level + perp

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else {
            DispatchQueue.main.async { self.levelOK = true; self.perpOK = true }
            return
        }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let g = motion.gravity
            // Roll: phone tilt left/right. 0° = perfectly upright.
            let roll  = atan2(g.x, -g.y) * 180.0 / .pi
            // Pitch: camera tilt up/down from horizontal. 0° = facing straight ahead.
            let pitch = atan2(-g.z, sqrt(g.x * g.x + g.y * g.y)) * 180.0 / .pi
            self.tiltDeg = roll
            self.levelOK = abs(roll)  < self.levelThresholdDeg
            self.perpOK  = abs(pitch) < self.perpThresholdDeg
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (BG confidence via Vision)

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Throttle: segmenting every frame at photo resolution pegs the CPU.
        let now = CACurrentMediaTime()
        guard now - lastSegmentation >= segmentationInterval else { return }
        lastSegmentation = now

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .fast
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([request])

        guard let result = request.results?.first else {
            Task { @MainActor [weak self] in self?.bgOK = false }
            return
        }

        // Confidence proxy: fraction of pixels that are clearly foreground (>200/255)
        // or clearly background (<50/255). Ambiguous pixels (matte edges) hurt
        // confidence. Sample on a stride and honour bytesPerRow (masks are row-padded).
        let mask = result.pixelBuffer
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        let w = CVPixelBufferGetWidth(mask)
        let h = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return }
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let stride = 4
        var decisive = 0
        var sampled = 0
        for y in Swift.stride(from: 0, to: h, by: stride) {
            let row = y * rowBytes
            for x in Swift.stride(from: 0, to: w, by: stride) {
                let v = bytes[row + x]
                if v > 200 || v < 50 { decisive += 1 }
                sampled += 1
            }
        }
        let confidence = Double(decisive) / Double(max(1, sampled))

        Task { @MainActor [weak self] in
            self?.bgOK = confidence >= (self?.bgConfidenceMin ?? 0.6)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)?.normalisedOrientation() else { return }
        Task { @MainActor [weak self] in
            self?.captureCompletion?(image)
            self?.captureCompletion = nil
        }
    }
}
