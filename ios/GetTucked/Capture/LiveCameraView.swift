import SwiftUI
import PhotosUI
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
    // Side-on reuses this view (Plan G1) with the bike already locked in from
    // head-on — showing the switchable chip there would let someone silently
    // desync the scale reference between the two photos in a pair.
    var showsBikeChip: Bool = true
    var stepLabel: String? = nil
    // BG confidence gauges background contrast for the frontal matte — side-on
    // computes no matte, so showing it there would measure something irrelevant.
    var showsBackgroundPill: Bool = true
    var onSkip: (() -> Void)? = nil
    var skipLabel: String = "SKIP"
    var onPickFromLibrary: ((UIImage, String?) -> Void)? = nil
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    // "Match this position" (Plan P2) — nil for every ordinary capture, in
    // which case no ghost affordance appears at all.
    var ghost: GhostReference? = nil

    @StateObject private var session = CameraSession()
    @State private var captureFlash = false
    @State private var showingBikePicker = false
    // Default on (Plan P2.2) — the single show/hide control, no sub-choices.
    @State private var showGhost = true
    // Q3.3: coaching content stays one tap away after it stops being
    // mandatory (Kah's standing preference for explicit, discoverable
    // controls over hidden functionality).
    @State private var showingTips = false

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            if session.permissionDenied {
                PermissionDeniedOverlay(onCancel: onCancel)
            } else {
                // Camera feed
                CameraPreviewLayer(session: session.captureSession, rotationAngle: session.orientationBucket.videoRotationAngle)
                    .ignoresSafeArea()

                // Scrims, not solid fills (Plan AI4) — the feed must stay
                // visible through the HUD, so legibility comes from a
                // gradient plus per-glyph shadow (`hudText()`), never an
                // opaque backdrop.
                CameraScrim(edge: .top)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                CameraScrim(edge: .bottom)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                // Ghost alignment overlay (Plan P2) — capture-time only,
                // never enters the Inspect PHOTO/MASK/BONES ladder. Fades in
                // at Motion.fast; already static so Reduce Motion has
                // nothing to collapse.
                if let ghost, showGhost {
                    GhostOverlay(outlineImage: ghost.outlineImage, skeleton: ghost.skeleton, referenceAspect: ghost.referenceAspect)
                        .ignoresSafeArea()
                        .transition(.opacity.animation(Theme.Motion.entrance(Theme.Motion.fast)))
                }

                // HUD overlay. Branch on layout geometry, not
                // UIDevice.current.orientation (Plan L3) — geometry is
                // synchronised with the actual rotation animation, whereas
                // device-orientation notifications fire before layout
                // settles and can report states like `.faceUp` that don't
                // correspond to any interface orientation at all. When
                // OrientationLock forbids landscape (head-on, or side-on
                // before it's entered) the interface itself can never
                // report landscape geometry, so this always resolves to
                // portraitHUD there regardless of how the phone is held.
                GeometryReader { geo in
                    if geo.size.width > geo.size.height {
                        landscapeHUD
                    } else {
                        portraitHUD
                    }
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
        // Sheet, not a nav push (Q3.3) — pushing would re-enter the
        // .setTheScene route and tangle Q1's path-trim rules. GOT IT just
        // dismisses here; it never sets hasSeenSetTheScene (that only
        // happens the first time, via AppNavigationView).
        .sheet(isPresented: $showingTips) {
            SetTheSceneView { showingTips = false }
        }
    }

    // MARK: - HUD layouts (Plan L3)

    private var portraitHUD: some View {
        VStack(spacing: 0) {
            topBar
            LevelLine(deviationDeg: session.tiltDeg)
                .padding(.top, Theme.Space.sm)
            Spacer()
            VStack(spacing: Theme.Space.lg) {
                blockedReasonSlot
                StatusPillRow(
                    levelOK: session.levelOK,
                    perpOK: session.perpOK,
                    bgOK: session.bgOK,
                    showsBackgroundPill: showsBackgroundPill
                )
                controlStack
            }
            .padding(.bottom, 48)
        }
    }

    /// Only the `showsBikeChip == false` configuration (side-on) can ever
    /// reach this — `OrientationLock` never permits landscape geometry
    /// otherwise, so head-on's `.pickPhoto` call site and `BikePickerSheet`
    /// never need to look right here.
    private var landscapeHUD: some View {
        VStack(spacing: 0) {
            topBar
            LevelLine(deviationDeg: session.tiltDeg)
                .padding(.top, Theme.Space.sm)
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: Theme.Space.lg) {
                    blockedReasonSlot
                    StatusPillRow(
                        levelOK: session.levelOK,
                        perpOK: session.perpOK,
                        bgOK: session.bgOK,
                        showsBackgroundPill: showsBackgroundPill,
                        isVertical: true
                    )
                    controlStack
                }
                .padding(.trailing, Theme.Space.xl)
            }
            .padding(.bottom, Theme.Space.xl)
        }
    }

    private var topBar: some View {
        HStack {
            if showsBikeChip {
                Button {
                    showingBikePicker = true
                } label: {
                    BikeChip(name: bike.nickname)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Shooting on \(bike.nickname), tap to change bike")
            } else if let stepLabel {
                StepLabelChip(label: stepLabel)
            }
            // Head-on only (Q3.3) — side-on's HUD is already busier and the
            // rider has just seen the head-on coaching.
            if showsBikeChip {
                Button {
                    showingTips = true
                } label: {
                    Text("TIPS")
                        .font(Theme.mono(12, weight: .bold))
                        .foregroundStyle(Theme.Palette.fg2)
                        .kerning(0.5)
                        .hudText()
                }
                .buttonStyle(.plain)
                .padding(.leading, Theme.Space.sm)
            }
            Spacer()
            if ghost != nil {
                GhostToggleButton(isOn: showGhost) {
                    withAnimation(Theme.Motion.entrance(Theme.Motion.fast)) {
                        showGhost.toggle()
                    }
                }
            }
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: Theme.Control.iconSize, weight: .medium))
                    .foregroundStyle(Theme.Palette.fg)
                    .frame(width: Theme.Control.iconTapTarget, height: Theme.Control.iconTapTarget)
                    .contentShape(Rectangle())
                    .hudText()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel capture")
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.md)
    }

    /// Why the shutter is greyed out (Plan AI4). It sits ABOVE the status
    /// pills and always occupies a line, visible or not: level/perp flicker
    /// in and out constantly while a rider is lining the shot up, and a row
    /// that appears and disappears below the pills reflowed the whole bottom
    /// stack — moving the shutter out from under a finger already on its way
    /// down (Kah, on-device). The blank string reserves the exact line height
    /// without a magic number, so nothing moves as the reason comes and goes.
    private var blockedReasonSlot: some View {
        let reason = CaptureGate.blockedReason(levelOK: session.levelOK, perpOK: session.perpOK)
        return Text(reason ?? " ")
            .font(Theme.mono(12, weight: .bold))
            .foregroundStyle(Theme.Palette.amb)
            .kerning(0.5)
            .hudText()
            .opacity(reason == nil ? 0 : 1)
            .animation(Theme.Motion.entrance(Theme.Motion.fast), value: reason)
            .accessibilityHidden(reason == nil)
            // A sighted user gets this visually the instant it appears; a
            // VoiceOver user gets nothing unless the shutter is actually
            // tapped and silently fails — post it explicitly (Plan AK9).
            .onChange(of: reason) { _, newReason in
                guard let newReason else { return }
                UIAccessibility.post(notification: .announcement, argument: newReason)
            }
    }

    /// Capture button + optional library/skip links — identical content in
    /// both orientations, just laid out inside a differently-arranged
    /// parent (bottom stack in portrait, trailing rail in landscape).
    private var controlStack: some View {
        Group {
            ZoomToggleChip(isAt2x: session.zoomIsAt2x) {
                session.toggleZoom()
            }
            CaptureButton(enabled: session.allPassed) {
                session.capturePhoto { image in
                    captureFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        captureFlash = false
                        onCapture(image)
                    }
                }
            }
            if let onPickFromLibrary {
                LibraryFallbackLink(onPicked: onPickFromLibrary)
            }
            if let onSkip {
                Button(action: onSkip) {
                    Text(skipLabel.uppercased())
                        .font(Theme.mono(12, weight: .bold))
                        .foregroundStyle(Theme.Palette.fg2)
                        .kerning(0.5)
                        .hudText()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - HUD sub-views

/// A translucent-to-transparent gradient pinned to one edge of the frame —
/// the alternative to a solid backdrop (Plan AI4: Kah explicitly does not
/// want a solid fill over the camera). The feed stays fully visible through
/// the transparent end; only the edge nearest the HUD text darkens.
private struct CameraScrim: View {
    enum Edge { case top, bottom }
    let edge: Edge

    private var startOpacity: Double { 0.75 }
    private var height: CGFloat { edge == .top ? 150 : 240 }

    var body: some View {
        LinearGradient(
            colors: [Theme.Palette.bg0.opacity(startOpacity), Theme.Palette.bg0.opacity(0)],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .frame(height: height)
        .frame(maxHeight: .infinity, alignment: edge == .top ? .top : .bottom)
    }
}

private struct BikeChip: View {
    let name: String

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("SHOOTING ON")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg2)
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
        .hudText()
    }
}

/// Non-interactive stand-in for `BikeChip` — same container, no `▾` picker
/// affordance, single line. Used where the bike is already locked in and
/// switching mid-pair would silently desync the scale reference (Plan G1).
private struct StepLabelChip: View {
    let label: String

    var body: some View {
        Text(label.uppercased())
            .font(Theme.heading(13))
            .foregroundStyle(Theme.Palette.fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.Palette.bg0.opacity(0.72))
            .overlay(Rectangle().stroke(Theme.Palette.line, lineWidth: 1))
            .hudText()
    }
}

/// The ghost's single show/hide affordance (Plan P2.2) — no sub-choices,
/// just on or off. Only ever appears when a reference is actually loaded.
private struct GhostToggleButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isOn ? "GHOST" : "GHOST OFF")
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(isOn ? Theme.Palette.acc : Theme.Palette.fg3)
                .kerning(0.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.Palette.bg0.opacity(0.72))
                .overlay(Rectangle().stroke(isOn ? Theme.Palette.acc : Theme.Palette.line, lineWidth: 1))
                .hudText()
        }
        .buttonStyle(.plain)
    }
}

/// AF2's explicit 1×/2× stop — two honest stops, no continuous pinch, so the
/// scale story (and the "we zoom to 2× for you" copy) stays simple and true.
/// Per-capture only, matching `GhostToggleButton`'s chip styling.
private struct ZoomToggleChip: View {
    let isAt2x: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isAt2x ? "2×" : "1×")
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(isAt2x ? Theme.Palette.acc : Theme.Palette.fg3)
                .kerning(0.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.Palette.bg0.opacity(0.72))
                .overlay(Rectangle().stroke(isAt2x ? Theme.Palette.acc : Theme.Palette.line, lineWidth: 1))
                .hudText()
        }
        .buttonStyle(.plain)
    }
}

/// "OR CHOOSE FROM LIBRARY" — a device/lighting problem with live capture
/// shouldn't leave a step with no path forward (Plan G decision 5). Reuses
/// the same PhotosPicker flow `PhotoPickStep` uses.
private struct LibraryFallbackLink: View {
    let onPicked: (UIImage, String?) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            Text(isLoading ? "LOADING…" : "OR CHOOSE FROM LIBRARY")
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(Theme.Palette.fg2)
                .kerning(0.5)
                .hudText()
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isLoading)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            isLoading = true
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onPicked(image, newItem.itemIdentifier)
                }
                isLoading = false
            }
        }
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
                // Rail — white, not `Palette.line` (Plan AI4): `line`
                // #262626 is invisible against a bright scene, and this rail
                // has no scrim of its own to lift it.
                Rectangle()
                    .fill(Color.white.opacity(0.35))
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
        .hudText()
        // Redundant with the LEVEL status pill, which now speaks its own
        // state (Plan AK9) — this bar is a purely visual tilt gauge.
        .accessibilityHidden(true)
        .animation(.easeOut(duration: 0.1), value: deviationDeg)
    }
}

private struct StatusPillRow: View {
    let levelOK: Bool
    let perpOK: Bool
    let bgOK: Bool
    var showsBackgroundPill: Bool = true
    // Landscape's trailing-rail layout (Plan L3) stacks the pills instead
    // of running them in a row — there's no horizontal room for a row once
    // they're sharing a narrow rail with the shutter button.
    var isVertical: Bool = false

    var body: some View {
        let pills = Group {
            StatusPill(label: "LEVEL", state: levelOK ? .ok : .warning)
            StatusPill(label: "PERP",  state: perpOK  ? .ok : .warning)
            if showsBackgroundPill {
                StatusPill(label: "BG", state: bgOK ? .ok : .warning)
            }
        }
        if isVertical {
            VStack(spacing: Theme.Space.sm) { pills }
        } else {
            HStack(spacing: Theme.Space.sm) { pills }
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
        .accessibilityLabel("Capture photo")
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
    // Without an explicit rotation angle the back-camera connection defaults
    // to landscape and the feed shows sideways. Driven by CameraSession's
    // orientationBucket (Plan L4) rather than hardcoded, so the live preview
    // stays upright as the phone rotates during side-on capture.
    let rotationAngle: CGFloat

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        applyRotation(to: view)
        return view
    }

    // Without this, SwiftUI never propagates a changed rotationAngle to the
    // already-created preview layer — makeUIView only runs once, so a
    // mid-capture rotation would show a sideways preview despite the HUD
    // reflowing correctly.
    func updateUIView(_ uiView: PreviewView, context: Context) {
        applyRotation(to: uiView)
    }

    private func applyRotation(to view: PreviewView) {
        if let conn = view.previewLayer.connection, conn.isVideoRotationAngleSupported(rotationAngle) {
            conn.videoRotationAngle = rotationAngle
        }
    }

    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Zoom factor derivation (Plan AF1/AF2)

/// Pure math for turning a *visual* zoom multiplier (1x / 2x, as a user
/// understands "zoom") into the `AVCaptureDevice.videoZoomFactor` that
/// actually produces it — kept free of `AVCaptureDevice` instances so it's
/// unit-testable without hardware.
enum ZoomFactorDerivation {
    /// Tried in order until one exists on the phone. Virtual multi-cam types
    /// first — on those, driving `videoZoomFactor` engages the real
    /// telephoto (or a high-quality sensor crop on 48MP wides) rather than a
    /// naive digital crop of a single fixed lens; the plain wide is the last
    /// resort for older/cheaper devices that have nothing else.
    static let deviceTypeFallbackChain: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera
    ]

    static func preferredDeviceType(from available: Set<AVCaptureDevice.DeviceType>) -> AVCaptureDevice.DeviceType? {
        deviceTypeFallbackChain.first(where: available.contains)
    }

    /// The `videoZoomFactor` for a given *visual* multiplier, on a device
    /// whose constituent lenses are described by `hasUltraWideConstituent`
    /// and `switchOverFactors`.
    ///
    /// On a virtual multi-cam device, `videoZoomFactor == 1.0` always
    /// selects the WIDEST constituent lens. On a triple-camera (or
    /// dual-wide) iPhone that widest lens is the ULTRA-wide — the 0.5x lens
    /// as users understand it — not the "normal" wide. So on those devices
    /// factor 1.0 is already a 0.5x-as-the-user-understands-it shot, and
    /// `virtualDeviceSwitchOverVideoZoomFactors[0]` (the factor at which the
    /// session hands off from ultra-wide to wide) IS "visual 1x". Visual 2x
    /// is always double whatever "visual 1x" resolves to. On a plain dual
    /// (wide+tele) or wide-only device there's no ultra-wide constituent, so
    /// factor 1.0 already means "wide, as the user understands 1x" and
    /// visual 2x is a plain 2.0.
    static func factor(
        forVisualMultiplier multiplier: Double,
        hasUltraWideConstituent: Bool,
        switchOverFactors: [CGFloat]
    ) -> CGFloat {
        let visualOneX: CGFloat = hasUltraWideConstituent ? (switchOverFactors.first ?? 2.0) : 1.0
        return visualOneX * CGFloat(multiplier)
    }

    static func clamped(_ factor: CGFloat, min minFactor: CGFloat, max maxFactor: CGFloat) -> CGFloat {
        Swift.min(Swift.max(factor, minFactor), maxFactor)
    }
}

// MARK: - Blocked-shutter reason (Plan AI4)

/// Pure text for why the shutter is currently disabled — kept free of
/// `CameraSession` so it's unit-testable without AVFoundation/CoreMotion.
/// Explains `CameraSession.allPassed`'s existing level/perp gate; does not
/// change it.
enum CaptureGate {
    static func blockedReason(levelOK: Bool, perpOK: Bool) -> String? {
        switch (levelOK, perpOK) {
        case (true, true):   return nil
        case (false, true):  return "Hold the phone level"
        case (true, false):  return "Tilt the phone upright"
        case (false, false): return "Hold the phone level and upright"
        }
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
    // Which way the phone is physically held — always .portrait unless
    // OrientationLock permits landscape (Plan L4).
    @Published var orientationBucket: OrientationBucket = .portrait
    // AF2: defaults to the visual-2x floor per AF1 — the fallback chain's
    // whole point (flattening near-wheel inflation) only holds if 2x is what
    // most captures actually use.
    @Published var zoomIsAt2x = true

    // LEVEL + PERP are physically enforced and gate the shutter. BG is advisory —
    // a low-contrast background degrades the matte but shouldn't dead-lock capture.
    var allPassed: Bool { levelOK && perpOK }

    private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureVideoDataOutput()
    private let motionManager = CMMotionManager()
    private var captureCompletion: ((UIImage) -> Void)?
    private var bike: Bike?
    private var device: AVCaptureDevice?

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
        // Read on the caller's thread (always main — this is only ever
        // called from a SwiftUI button action) rather than inside the
        // session-queue block below, so a mid-rotation shot uses whichever
        // bucket the gravity read had settled on at the moment of the
        // shutter press, not whatever it drifts to by the time the session
        // queue gets around to it.
        let rotationAngle = orientationBucket.videoRotationAngle
        sessionQueue.async { [weak self] in
            guard let self else { return }
            // Connection configuration belongs on the session queue.
            if let conn = self.photoOutput.connection(with: .video),
               conn.isVideoRotationAngleSupported(rotationAngle) {
                conn.videoRotationAngle = rotationAngle
            }
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

        // Prefer a virtual multi-cam device (Plan AF1) — on those, driving
        // videoZoomFactor engages the real telephoto/quality crop rather than
        // a naive digital crop of a single fixed lens. Discover what this
        // phone actually has rather than assuming, since only some models
        // carry a triple or dual-wide camera.
        let availableTypes = Set(
            AVCaptureDevice.DiscoverySession(
                deviceTypes: ZoomFactorDerivation.deviceTypeFallbackChain,
                mediaType: .video,
                position: .back
            ).devices.map(\.deviceType)
        )
        guard let deviceType = ZoomFactorDerivation.preferredDeviceType(from: availableTypes),
              let device = AVCaptureDevice.default(deviceType, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        self.device = device

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        if captureSession.canAddInput(input)  { captureSession.addInput(input) }
        if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }
        videoOutput.setSampleBufferDelegate(self, queue: segmentationQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }

        // Portrait rotation for the captured still, matching the preview.
        // capturePhoto overrides this per-shot once landscape is possible.
        let angle = OrientationBucket.portrait.videoRotationAngle
        if let conn = photoOutput.connection(with: .video), conn.isVideoRotationAngleSupported(angle) {
            conn.videoRotationAngle = angle
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()

        // AF1's 2x default. Hardcoded rather than reading `zoomIsAt2x` here:
        // this runs once at session start (before the HUD's toggle can have
        // fired), and `zoomIsAt2x` is a `@Published` property that's only
        // safe to read from the main thread, not this session queue.
        applyZoom(visualMultiplier: 2.0, to: device)
    }

    /// `videoZoomFactor` applies at the AVCaptureDevice level, which the
    /// photo-output connection reads from directly — so the captured still
    /// inherits whatever the preview shows. Not yet confirmed on-device.
    private func applyZoom(visualMultiplier: Double, to device: AVCaptureDevice) {
        let hasUltraWide = device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
        let switchOverFactors = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        let raw = ZoomFactorDerivation.factor(
            forVisualMultiplier: visualMultiplier,
            hasUltraWideConstituent: hasUltraWide,
            switchOverFactors: switchOverFactors
        )
        let clamped = ZoomFactorDerivation.clamped(
            raw, min: device.minAvailableVideoZoomFactor, max: device.maxAvailableVideoZoomFactor
        )
        guard (try? device.lockForConfiguration()) != nil else { return }
        device.videoZoomFactor = clamped
        device.unlockForConfiguration()
    }

    /// AF2: the explicit 1×/2× toggle. Per-capture only — no persistence,
    /// so every fresh capture session starts back at the 2× default. Reads
    /// `zoomIsAt2x` here on the caller's thread (always main, from a SwiftUI
    /// button action) rather than inside the dispatched block, for the same
    /// reason `capturePhoto` reads `orientationBucket` up front.
    func toggleZoom() {
        zoomIsAt2x.toggle()
        let multiplier = zoomIsAt2x ? 2.0 : 1.0
        sessionQueue.async { [weak self] in
            guard let self, let device = self.device else { return }
            self.applyZoom(visualMultiplier: multiplier, to: device)
        }
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
            // Raw roll: deviation from PORTRAIT-upright. Held level in
            // landscape this reads ±90°, so it must be re-zeroed against the
            // current bucket below before it means "level" in general
            // (Plan L4 correctness trap 1) — a naive `abs(roll) < 2°` would
            // permanently fail and dead-lock the shutter in landscape.
            let roll  = atan2(g.x, -g.y) * 180.0 / .pi
            // Pitch measures rotation about the screen normal via g.z, which
            // doesn't change as the phone spins within the screen plane —
            // unaffected by orientation, no bucket correction needed.
            let pitch = atan2(-g.z, sqrt(g.x * g.x + g.y * g.y)) * 180.0 / .pi

            // `to: .main` guarantees this closure runs on the main thread;
            // OrientationLock.allowsLandscape is @MainActor-isolated but the
            // compiler can't statically see that guarantee through CoreMotion's
            // callback-based API, hence the explicit assumeIsolated.
            let allowsLandscape = MainActor.assumeIsolated { OrientationLock.allowsLandscape }
            let bucket: OrientationBucket = allowsLandscape
                ? OrientationBucket.pick(gravityX: g.x, gravityY: g.y, current: self.orientationBucket)
                : .portrait
            self.orientationBucket = bucket

            var deviation = roll - bucket.referenceRollDeg
            if deviation > 180 { deviation -= 360 }
            if deviation <= -180 { deviation += 360 }

            self.tiltDeg = deviation
            self.levelOK = abs(deviation) < self.levelThresholdDeg
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
