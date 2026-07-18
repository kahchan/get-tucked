import SwiftUI
import SwiftData
import PhotosUI
import Photos
import ImageIO

struct CaptureView: View {
    @Binding var path: [AppScreen]
    // Set only via "Match this position" (Plan P2) — the position to align
    // this capture's ghost against. nil for every ordinary capture.
    var referenceID: PersistentIdentifier? = nil
    // Fires once a new position is inserted (Plan N7) — lets the list root
    // give the newest row a brief highlight once the user gets back there.
    var onSaved: (UUID) -> Void = { _ in }
    @Environment(\.modelContext) private var context
    @Query private var bikes: [Bike]
    @Query(sort: \Position.capturedAt, order: .reverse) private var positions: [Position]

    private var referencePosition: Position? {
        guard let referenceID else { return nil }
        return positions.first { $0.persistentModelID == referenceID }
    }

    /// Plan S1: drop bars are tapped at the drop ends (the tappable
    /// feature), flat bars at the plain bar ends — must match whatever
    /// convention BikeSetupView's help text told the rider to measure.
    private var barTapPrompts: (first: String, second: String) {
        switch selectedBike?.effectiveBarType {
        case .drop:
            return ("Tap the outermost point of the LEFT drop", "Now tap the outermost point of the RIGHT drop")
        case .flat, nil:
            return ("Tap the left end of your handlebars", "Now tap the right end")
        }
    }

    /// One-time existing-data caveat (Plan S1) — nil once the bike has an
    /// explicit barType, which dismissing sets, so this can never show twice
    /// for the same bike.
    private var dropBarCaveatBanner: (text: String, onDismiss: () -> Void)? {
        guard let bike = selectedBike, bike.barType == nil, bike.effectiveBarType == .drop else { return nil }
        return (
            "This bike's bar width was entered before drop-bar taps were split out — confirm it was measured at the drop ends, not the hoods.",
            { bike.barType = .drop }
        )
    }

    @State private var step: CaptureStep = .pickPhoto
    @State private var selectedBike: Bike?
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var assetIdentifier: String?
    @State private var tapPoints: [CGPoint] = []
    // Optional cross-scale verification taps (Plan K3) — never gates capture.
    @State private var wheelTapPoints: [CGPoint] = []
    @State private var pendingResult: AnalysisResult?
    // The bar width actually passed to AnalysisEngine.analyse — captured at
    // analysis time, not re-read from selectedBike at save time, so it can't
    // drift from the value that produced pendingResult.
    @State private var usedHandlebarWidthMm: Double?
    // Built off-main as soon as analysis completes (N2) so RevealStep's scan
    // wipe never waits on pixel work — handed to RevealStep once ready.
    @State private var revealMaskOverlay: UIImage?
    // Side-on state
    @State private var sideOnImage: UIImage?
    @State private var sideOnAssetIdentifier: String?
    @State private var pendingSideOnPose: SideOnPoseMetrics?
    // Wheelbase ruler taps (Plan P1.5) — front axle, rear axle, unit coords.
    // Empty when the rider skipped the ruler or the bike has none on file.
    @State private var sideOnTapPoints: [CGPoint] = []
    // The resulting side-on scale, once confirmed — nil means headDropCm (if
    // computed) still borrows the frontal pixelsPerCm and stays hidden.
    @State private var sideOnPixelsPerCmValue: Double?
    // Untinted side-on segmentation matte (Plan O) — nil when segmentation
    // failed at capture, which never blocks save (presentational only).
    @State private var pendingSideOnMask: UIImage?
    @State private var analysisError: AnalysisError?
    @State private var showingError = false
    // Q2: guards against silently discarding a completed analysis — gated
    // off once the position is actually saved (.done) or before any
    // analysis exists yet, where ✕ has nothing meaningful to lose.
    @State private var showingDiscardConfirm = false
    // Set at the end of savePosition — lets the success screen offer a
    // direct link to the position it just created.
    @State private var savedPositionID: PersistentIdentifier?
    // Ghost material (Plan P2) — built once, off-main, when referenceID is
    // set; nil for an ordinary capture, in which case LiveCameraView shows
    // no ghost affordance at all.
    @State private var headOnGhost: GhostReference?
    @State private var sideOnGhost: GhostReference?
    @State private var ghostsBuilt = false

    enum CaptureStep: Equatable {
        case pickPhoto          // head-on · 1 OF 2
        case calibrate          // head-on calibration
        case analysing          // head-on analysis
        case pickSideOnPhoto    // side-on · 2 OF 2
        case calibrateSideOn    // side-on wheelbase ruler (Plan P1.5)
        case analysingSideOn    // side-on analysis
        case reveal             // frontal-area result reveal
        case namePosition
        case done
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(spacing: 0) {
                // Both live-camera steps own their own full-screen HUD chrome
                // (step label/bike chip, ✕) — a NavHeader on top would double
                // up on it (confirmed visually when G2 landed).
                if step != .pickPhoto, step != .pickSideOnPhoto {
                    NavHeader(title: stepTitle) {
                        Button {
                            requestExitCaptureFlow()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: Theme.Control.iconSize, weight: .medium))
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
                Button("Cancel", role: .cancel) { requestExitCaptureFlow() }
            } message: { error in
                Text(error.errorDescription ?? "Unknown error.")
            }
            .confirmationDialog("Discard this capture?", isPresented: $showingDiscardConfirm, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { exitCaptureFlow() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .hideNavBar()
        .onAppear {
            if selectedBike == nil {
                // Matching a position (Plan P2) means staying on the same
                // setup — the reference's own bike takes priority over the
                // usual "whatever was used last" default.
                selectedBike = referencePosition?.bike ?? positions.first?.bike ?? bikes.first
            }
            if !ghostsBuilt, referencePosition != nil {
                ghostsBuilt = true
                buildGhosts()
            }
        }
        // Derived from `step` rather than hand-audited per exit closure, so
        // no path (capture, library-pick, skip, retry, retake) can leave the
        // lock stuck on (Plan L2). Covers every step transition in one place.
        .onChange(of: step) { _, newStep in
            OrientationLock.allowsLandscape = (newStep == .pickSideOnPhoto)
        }
        // Covers exitCaptureFlow() (✕ / cancel) and any other navigation
        // pop, which onChange(of: step) can't see.
        .onDisappear {
            OrientationLock.allowsLandscape = false
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch step {
            case .pickPhoto:
                if let bike = selectedBike {
                    LiveCameraView(bike: bike, bikes: bikes, onBikeChange: { selectedBike = $0 }, onPickFromLibrary: { image, identifier in
                        // Q6: solo library fallback — no saveToCameraRoll
                        // (the photo is already in the library, that's the
                        // point), mirroring the side-on call site exactly.
                        selectedImage = image
                        assetIdentifier = identifier
                        tapPoints = []
                        step = .calibrate
                    }, onCapture: { image in
                        selectedImage = image  // already normalised in photoOutput delegate
                        assetIdentifier = nil  // live capture has no PHAsset identifier
                        tapPoints = []
                        step = .calibrate
                        Task { await saveToCameraRoll(image) }
                    }, onCancel: { requestExitCaptureFlow() }, ghost: headOnGhost)
                    .transition(.identity)
                }
            case .calibrate:
                if let image = selectedImage {
                    TapCalibrationStep(
                        image: image,
                        tapPoints: $tapPoints,
                        wheelTapPoints: $wheelTapPoints,
                        wheelDiameterMm: selectedBike?.wheelDiameterMm,
                        primaryTapPrompts: barTapPrompts,
                        caveatBanner: dropBarCaveatBanner
                    ) {
                        step = .analysing
                        Task { await runAnalysis() }
                    }
                    .transition(.opacity)
                }
            case .analysing:
                AnalysingView(label: "ANALYSING", image: selectedImage)
                    .transition(.opacity)
            case .pickSideOnPhoto:
                if let bike = selectedBike {
                    LiveCameraView(
                        bike: bike,
                        showsBikeChip: false,
                        stepLabel: "SIDE-ON · 2 OF 2",
                        showsBackgroundPill: false,
                        onSkip: { step = .reveal },
                        skipLabel: "SKIP SIDE-ON",
                        onPickFromLibrary: { image, identifier in
                            sideOnImage = image
                            sideOnAssetIdentifier = identifier
                            step = .calibrateSideOn
                        },
                        onCapture: { image in
                            sideOnImage = image
                            sideOnAssetIdentifier = nil  // live capture has no PHAsset identifier
                            step = .calibrateSideOn
                            Task { await saveToCameraRoll(image) }
                        },
                        onCancel: { requestExitCaptureFlow() },
                        ghost: sideOnGhost
                    )
                    .transition(.identity)
                }
            case .calibrateSideOn:
                if let bike = selectedBike, let image = sideOnImage {
                    SideOnCalibrationStep(
                        image: image,
                        bike: bike,
                        tapPoints: $sideOnTapPoints,
                        onConfirm: { pixelsPerCm in
                            sideOnPixelsPerCmValue = pixelsPerCm
                            step = .analysingSideOn
                            Task { await runSideOnAnalysis() }
                        },
                        onSkip: {
                            sideOnTapPoints = []
                            sideOnPixelsPerCmValue = nil
                            step = .analysingSideOn
                            Task { await runSideOnAnalysis() }
                        }
                    )
                    .transition(.opacity)
                }
            case .analysingSideOn:
                AnalysingView(label: "ANALYSING POSTURE", image: sideOnImage)
                    .transition(.opacity)
            case .reveal:
                if let result = pendingResult, let photo = selectedImage {
                    RevealStep(result: result, photo: photo, maskOverlay: revealMaskOverlay, sideOnPose: pendingSideOnPose, hasSideOnRuler: sideOnPixelsPerCmValue != nil, barWidthMm: selectedBike?.handlebarWidthMm, barTapPoints: tapPoints, wheelTapPoints: wheelTapPoints, wheelDiameterMm: selectedBike?.wheelDiameterMm, path: $path, onContinue: {
                        step = .namePosition
                    }, onRetake: {
                        resetForNewCapture()
                    })
                    .transition(.opacity)
                }
            case .namePosition:
                if let result = pendingResult {
                    NamePositionStep(result: result) { label in
                        savePosition(label: label)
                    }
                    .transition(.opacity)
                }
            case .done:
                CaptureSuccessStep(
                    areaCm2: pendingResult?.frontalAreaCm2,
                    onViewAnalysis: {
                        guard let savedPositionID else { return }
                        // Replace, not pop (Q1.1) — whatever got us here
                        // (ordinary capture or a match flow's reference
                        // detail) has served its purpose; the freshly saved
                        // position's own detail is the only thing that
                        // should remain in the stack.
                        path = [.positionDetail(savedPositionID)]
                    },
                    onCaptureAnother: {
                        resetForNewCapture()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(Theme.Motion.entrance(), value: step)
    }

    private var stepTitle: String {
        switch step {
        case .pickPhoto:        "FRONTAL · 1 OF 2"
        case .calibrate:        "CALIBRATE SCALE"
        case .analysing:        "ANALYSING"
        case .pickSideOnPhoto:  "SIDE-ON · 2 OF 2"
        case .calibrateSideOn:  "CONFIRM WHEELBASE"
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

        let stepEnteredAt = Date()
        do {
            let wheelTaps: (ground: CGPoint, top: CGPoint)? =
                wheelTapPoints.count == 2 ? (wheelTapPoints[0], wheelTapPoints[1]) : nil
            let result = try await AnalysisEngine.analyse(
                image: image,
                handlebarWidthMm: bike.handlebarWidthMm,
                tapPoint0: tapPoints[0],
                tapPoint1: tapPoints[1],
                wheelTaps: wheelTaps,
                wheelDiameterMm: bike.wheelDiameterMm
            )
            await waitForMinimumAnalysingDisplay(since: stepEnteredAt)
            pendingResult = result
            usedHandlebarWidthMm = bike.handlebarWidthMm
            buildRevealMaskOverlay(for: result)
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

    /// N3: the analysing scan line needs at least one full sweep (1.2s) to
    /// read as a deliberate scan rather than a flicker — if
    /// `AnalysisEngine` returns before that, hold the step a beat longer
    /// instead of cutting the pass short mid-sweep. No-op under Reduce
    /// Motion (there's no sweep to complete) and never called on the error
    /// path (alert fires immediately).
    private func waitForMinimumAnalysingDisplay(since start: Date) async {
        guard !MotionSettings.reduceMotionEnabled else { return }
        let minimumDuration: TimeInterval = 1.2
        let remaining = minimumDuration - Date().timeIntervalSince(start)
        guard remaining > 0 else { return }
        try? await Task.sleep(for: .seconds(remaining))
    }

    /// Shared by RETAKE (from Reveal) and "CAPTURE ANOTHER POSITION" (from
    /// the success screen) — clears everything from this position's capture
    /// so the next one starts clean. Keeps the same bike selected.
    private func resetForNewCapture() {
        tapPoints = []
        wheelTapPoints = []
        pendingResult = nil
        usedHandlebarWidthMm = nil
        revealMaskOverlay = nil
        sideOnImage = nil
        sideOnAssetIdentifier = nil
        pendingSideOnPose = nil
        pendingSideOnMask = nil
        sideOnTapPoints = []
        sideOnPixelsPerCmValue = nil
        savedPositionID = nil
        step = .pickPhoto
    }

    /// Off-main so RevealStep's scan wipe (N2) never blocks on pixel work —
    /// the mask tint composite is pure CPU work with no main-actor requirement.
    /// Two-tone (Plan W2) when subject-lifting succeeded on this capture —
    /// rider acid-yellow, bike/bags amber; single-tone acid-yellow fallback
    /// otherwise, matching pre-W2 exactly.
    private func buildRevealMaskOverlay(for result: AnalysisResult) {
        guard let personMask = result.maskImage.cgImage else { return }
        let subjectMask = result.subjectMaskImage?.cgImage
        let overlayBinding = $revealMaskOverlay
        let riderColor = UIColor(Theme.Palette.acc)
        let bikeColor = UIColor(Theme.Palette.amb)
        Task.detached(priority: .userInitiated) {
            let overlay: UIImage?
            if let subjectMask {
                overlay = MatteRenderer.twoToneOverlay(
                    subjectMask: subjectMask, personMask: personMask,
                    riderColor: riderColor, bikeColor: bikeColor, alpha: 0.5
                )
            } else {
                overlay = MatteRenderer.tintedOverlay(mask: personMask, color: riderColor, alpha: 0.5)
            }
            await MainActor.run {
                overlayBinding.wrappedValue = overlay
            }
        }
    }

    /// Off-main, once (Plan P2) — builds both orientations' ghost material
    /// from the reference's already-persisted mask + landmarks. Either
    /// orientation independently degrades to nil (no maskData, no stored
    /// landmarks, or no photo to read an aspect ratio from), same
    /// presentational "never blocking" pattern as the side-on matte.
    private func buildGhosts() {
        guard let reference = referencePosition else { return }
        // Ghost outline traces whichever mask actually drove the reference's
        // area (Plan W2 audit) — subjectMaskData once adopted, falling back
        // to the person-only maskData for positions captured before W2.
        let headOnMaskData = reference.subjectMaskData ?? reference.maskData
        let headOnPhotoData = reference.photosData
        let headOnSkeleton = reference.metrics?.headOnSkeletonPoints
            .flatMap {
                SkeletonOverlay.frontal(
                    shoulders: $0,
                    arms: reference.metrics?.headOnArmPoints,
                    hips: reference.metrics?.headOnHipPoints,
                    knees: reference.metrics?.headOnKneePoints
                )
            }
        let sideOnMaskData = reference.sideOnMaskData
        let sideOnPhotoData = reference.sideOnPhotoData
        let sideOnSkeleton = reference.metrics?.sideOnSkeletonPoints
            .flatMap {
                SkeletonOverlay.sideOn(
                    points: $0,
                    arm: reference.metrics?.sideOnArmPoints,
                    ankle: reference.metrics?.sideOnAnklePoint
                )
            }

        Task.detached(priority: .userInitiated) {
            let headOn = Self.buildGhost(maskData: headOnMaskData, photoData: headOnPhotoData, skeleton: headOnSkeleton)
            let sideOn = Self.buildGhost(maskData: sideOnMaskData, photoData: sideOnPhotoData, skeleton: sideOnSkeleton)
            await MainActor.run {
                headOnGhost = headOn
                sideOnGhost = sideOn
            }
        }
    }

    private static func buildGhost(maskData: Data?, photoData: Data?, skeleton: SkeletonOverlay?) -> GhostReference? {
        guard let aspect = peekAspectRatio(from: photoData) else { return nil }
        var outline: UIImage?
        if let maskData, let mask = UIImage(data: maskData)?.cgImage,
           let ring = MatteRenderer.outlineMask(mask: mask, strokeWidthPx: 6) {
            outline = MatteRenderer.tintedOverlay(mask: ring, color: UIColor(Theme.Palette.acc), alpha: 0.6)
        }
        guard outline != nil || skeleton != nil else { return nil }
        return GhostReference(outlineImage: outline, skeleton: skeleton, referenceAspect: aspect)
    }

    /// Header-only peek (no full decode) — same approach
    /// `PositionDetailView` uses to size its placeholder, reused here since
    /// only the aspect ratio is needed, not the pixels.
    private static func peekAspectRatio(from data: Data?) -> CGFloat? {
        guard let data,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              height > 0
        else { return nil }
        return CGFloat(width / height)
    }

    private func runSideOnAnalysis() async {
        // The wheelbase ruler (Plan P1.5) is the defensible scale when
        // present; falls back to the frontal scale otherwise — same
        // unenforced-same-distance assumption as before, just no longer the
        // only option. Either way headDropCm gets computed once, correctly,
        // here — display screens just gate whether to *show* it.
        guard let image = sideOnImage,
              let pixelsPerCm = sideOnPixelsPerCmValue ?? pendingResult?.pixelsPerCm else {
            // Side-on failed or skipped — reveal the frontal-area result anyway
            step = .reveal
            return
        }
        let stepEnteredAt = Date()
        // Pose failure is non-fatal: we still save the position, just without posture metrics.
        if let analysis = try? await AnalysisEngine.analyseSideOn(image: image, pixelsPerCm: pixelsPerCm) {
            pendingSideOnPose = analysis.pose
            pendingSideOnMask = analysis.maskImage
        }
        await waitForMinimumAnalysingDisplay(since: stepEnteredAt)
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

    /// Every ✕/cancel in the capture flow routes through this (Q1.2) instead
    /// of `dismiss()`, which only pops one screen and strands the user on
    /// `.setTheScene` — a screen they only passed through, never a
    /// destination in its own right.
    private func exitCaptureFlow() {
        path = trimmedForCaptureExit(path)
    }

    /// Gates `exitCaptureFlow()` behind a confirmation once there's a
    /// completed analysis to lose (Q2) — before that, or once the position
    /// is actually saved (`.done`), ✕ exits immediately, same as before.
    private func requestExitCaptureFlow() {
        if pendingResult != nil, step != .done {
            showingDiscardConfirm = true
        } else {
            exitCaptureFlow()
        }
    }

    private func savePosition(label: String) {
        guard let result = pendingResult, let bike = selectedBike else { return }
        let position = Position(label: label, bike: bike)
        position.headOnPhotoIdentifier = assetIdentifier
        // Live capture has no PHAsset identifier — persist the image bytes so the
        // detail view can display the frontal photo.
        position.photosData = selectedImage?.compressedForStorage()
        if let cgMask = result.maskImage.cgImage {
            position.maskData = MatteRenderer.downscaledMaskPNGData(mask: cgMask)
        }
        // Plan W2 — nil when subject-lifting failed on this capture; the
        // two-tone renderers and the area/outline consumers all fall back
        // to maskData/person-only in that case, same as an old position.
        if let cgSubjectMask = result.subjectMaskImage?.cgImage {
            position.subjectMaskData = MatteRenderer.downscaledMaskPNGData(mask: cgSubjectMask)
        }
        position.handlebarTapPoints = [
            tapPoints[0].x, tapPoints[0].y,
            tapPoints[1].x, tapPoints[1].y,
        ]
        // Optional wheel-check taps (Plan K3) — nil unless the rider did
        // that step. Previously only fed wheelCheckDisagreementFraction and
        // was discarded; now also doubles as the ghost-compare overlay's
        // ground anchor (the more precise alternative to the mask-bottom
        // fallback) when present.
        if wheelTapPoints.count == 2 {
            position.wheelTapPoints = [
                wheelTapPoints[0].x, wheelTapPoints[0].y,
                wheelTapPoints[1].x, wheelTapPoints[1].y,
            ]
        }
        let metrics = PositionMetrics(
            frontalAreaCm2: result.frontalAreaCm2,
            frontalAreaUncertainty: result.frontalAreaUncertaintyCm2,
            pixelsPerCm: result.pixelsPerCm,
            foregroundPixelCount: result.foregroundPixelCount
        )
        metrics.shoulderWidthCm = result.headOnPose?.shoulderWidthCm
        metrics.handlebarWidthMmUsed = usedHandlebarWidthMm
        metrics.wheelCheckDisagreementFraction = result.wheelCheckDisagreementFraction
        if let headOnPose = result.headOnPose {
            metrics.headOnSkeletonPoints = [
                headOnPose.leftShoulder.x, headOnPose.leftShoulder.y,
                headOnPose.rightShoulder.x, headOnPose.rightShoulder.y,
            ]
            if let arms = headOnPose.armPoints {
                metrics.headOnArmPoints = arms.flatMap { [$0.x, $0.y] }
            }
            if let hips = headOnPose.hipPoints {
                metrics.headOnHipPoints = hips.flatMap { [$0.x, $0.y] }
            }
            if let knees = headOnPose.kneePoints {
                metrics.headOnKneePoints = knees.flatMap { [$0.x, $0.y] }
            }
        }
        if let pose = pendingSideOnPose {
            metrics.torsoAngleDeg = pose.torsoAngleDeg
            metrics.hipAngleDeg   = pose.hipAngleDeg
            metrics.headDropCm    = pose.headDropCm
            metrics.sideOnSkeletonPoints = [
                pose.shoulder.x, pose.shoulder.y,
                pose.hip.x, pose.hip.y,
                pose.knee.x, pose.knee.y,
                pose.ear.x, pose.ear.y,
            ]
            if let arm = pose.armPoints {
                metrics.sideOnArmPoints = arm.flatMap { [$0.x, $0.y] }
            }
            if let ankle = pose.anklePoint {
                metrics.sideOnAnklePoint = [ankle.x, ankle.y]
            }
        }
        // Wheelbase ruler (Plan P1.5) — nil unless the rider confirmed one,
        // in which case headDropCm above was computed from it (runSideOnAnalysis).
        metrics.sideOnPixelsPerCm = sideOnPixelsPerCmValue
        if sideOnTapPoints.count == 2 {
            position.sideOnTapPoints = [
                sideOnTapPoints[0].x, sideOnTapPoints[0].y,
                sideOnTapPoints[1].x, sideOnTapPoints[1].y,
            ]
        }
        if let sideOnMask = pendingSideOnMask?.cgImage {
            position.sideOnMaskData = MatteRenderer.downscaledMaskPNGData(mask: sideOnMask)
        }
        position.sideOnPhotoIdentifier = sideOnAssetIdentifier
        // Always persist the bytes too, not just when there's no PHAsset
        // identifier — mirrors head-on's photosData, which is unconditional.
        // A PHAsset re-fetch needs Photos read authorization and can fail
        // silently; PositionDetailView already prefers the stored bytes over
        // the re-fetch, so this is a reliable fallback for the library-pick
        // path, not just the live-capture one.
        position.sideOnPhotoData = sideOnImage?.compressedForStorage()
        position.metrics = metrics
        context.insert(position)
        savedPositionID = position.persistentModelID
        onSaved(position.id)
        step = .done
    }
}

// MARK: - Step views

/// The captured photo being scanned, not a bare wall (N3): dimmed image with
/// a looping acid scan line, step label with a blinking block cursor. No
/// invented stage names — `AnalysisEngine.analyse` is one opaque call, so
/// this shows the one thing that's actually true: the photo is being read.
private struct AnalysingView: View {
    let label: String
    let image: UIImage?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanProgress: Double = 0
    @State private var cursorVisible = true

    private let sweepDuration: Double = 1.2
    private let holdDuration: Double = 0.25

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()

            ZStack(alignment: .top) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Rectangle().fill(Theme.Palette.bg1)
                    }
                }
                .opacity(0.4)

                if !reduceMotion {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(Theme.Palette.acc)
                            .frame(height: 1)
                            .offset(y: proxy.size.height * scanProgress)
                    }
                }
            }
            .clipped()
            .frame(maxWidth: .infinity)

            HStack(spacing: 3) {
                Text(label)
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
                Text("▮")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
                    .opacity(reduceMotion || cursorVisible ? 1 : 0)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            await runScanLoop()
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            await runCursorBlink()
        }
    }

    /// Sweeps top→bottom on an eased curve, then jumps back to the top and
    /// holds briefly before the next pass — a discrete pass, not a sawtooth.
    private func runScanLoop() async {
        while !Task.isCancelled {
            withAnimation(Theme.Motion.travel(sweepDuration)) {
                scanProgress = 1
            }
            try? await Task.sleep(for: .seconds(sweepDuration))
            guard !Task.isCancelled else { break }
            scanProgress = 0
            try? await Task.sleep(for: .seconds(holdDuration))
        }
    }

    private func runCursorBlink() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { break }
            cursorVisible.toggle()
        }
    }
}

/// Key/value row for the side-on facing correction (Plan P3) — same visual
/// rhythm as `MetricRow` (Components.swift), with `FacingChip` standing in
/// for the plain-text value since this one is tappable.
private struct FacingRow: View {
    let facing: (facing: AnalysisMath.Facing, confidence: Double)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FACING")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg2)
                    .kerning(0.3)
                Spacer()
                FacingChip(derivedFacing: facing.facing, confidence: facing.confidence)
            }
            .frame(height: Theme.Control.metricRowHeight)

            Rectangle()
                .fill(Theme.Palette.line2)
                .frame(height: Theme.Control.hairline)
        }
    }
}

private struct RevealStep: View {
    let result: AnalysisResult
    let photo: UIImage
    // Built off-main by CaptureView as soon as analysis completes (N2) —
    // may still be nil at t=0 if the detached task hasn't finished.
    let maskOverlay: UIImage?
    let sideOnPose: SideOnPoseMetrics?
    // Whether headDropCm (if present) came from a real wheelbase ruler
    // (Plan P1.5), not the borrowed frontal scale — gates whether it's
    // defensible enough to show (spec §3).
    let hasSideOnRuler: Bool
    let barWidthMm: Double?
    // The measured hard points, drawn (Plan X) — the same live tap state
    // CaptureView collected during calibration, in unit coords. wheelTapPoints
    // is empty unless the optional wheel check was done; wheelDiameterMm
    // mirrors barWidthMm's role for that dimension.
    let barTapPoints: [CGPoint]
    let wheelTapPoints: [CGPoint]
    let wheelDiameterMm: Double?
    @Binding var path: [AppScreen]
    let onContinue: () -> Void
    let onRetake: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealSegment: PhotoSegment
    // Reveal ceremony phases — driven entirely by delayed/completion-based
    // withAnimation calls (never DispatchQueue.asyncAfter) so Reduce Motion
    // collapses cleanly and a mid-sequence tap can snap everything forward.
    @State private var sweepProgress: Double = 0
    @State private var sweepStarted = false
    @State private var hasStartedCeremony = false
    @State private var ceremonyCancelled = false
    @State private var labelVisible = false
    @State private var uncertaintyVisible = false
    @State private var rowsVisible = false
    @State private var buttonsVisible = false
    // Frontal skeleton draw-on (Plan O4) — a quiet secondary beat that starts
    // once the sweep completes and finishes well before the number roll.
    @State private var skeletonProgress: Double = 0
    @State private var skeletonVisible = false
    // Dimension draw-on (Plan X3) — one quiet tertiary beat that starts once
    // the skeleton's own draw-in completes, so the box reads as caused by
    // it rather than competing with it.
    @State private var dimensionProgress: Double = 0
    @State private var dimensionsVisible = false

    init(
        result: AnalysisResult,
        photo: UIImage,
        maskOverlay: UIImage?,
        sideOnPose: SideOnPoseMetrics?,
        hasSideOnRuler: Bool,
        barWidthMm: Double?,
        barTapPoints: [CGPoint],
        wheelTapPoints: [CGPoint],
        wheelDiameterMm: Double?,
        path: Binding<[AppScreen]>,
        onContinue: @escaping () -> Void,
        onRetake: @escaping () -> Void
    ) {
        self.result = result
        self.photo = photo
        self.maskOverlay = maskOverlay
        self.sideOnPose = sideOnPose
        self.hasSideOnRuler = hasSideOnRuler
        self.barWidthMm = barWidthMm
        self.barTapPoints = barTapPoints
        self.wheelTapPoints = wheelTapPoints
        self.wheelDiameterMm = wheelDiameterMm
        self._path = path
        self.onContinue = onContinue
        self.onRetake = onRetake
        // The reveal should land on the richest defensible view (Plan O4):
        // BONES when there's a skeleton to show, else MASK as before.
        self._revealSegment = State(initialValue: result.headOnPose != nil ? .bones : .mask)
    }

    var body: some View {
        GeometryReader { screenProxy in
            ZStack {
                Theme.Palette.bg0.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack {
                                // The photo is on screen the instant this view appears —
                                // no entrance animation (it was already visible during
                                // the N3 analysing scan).
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFit()
                                if let maskOverlay {
                                    Image(uiImage: maskOverlay)
                                        .resizable()
                                        .scaledToFit()
                                        .scanReveal(progress: reduceMotion ? 1 : sweepProgress)
                                        .opacity(revealSegment == .photo ? 0 : 1)
                                }
                                if revealSegment == .bones, let frontalSkeletonOverlay {
                                    frontalSkeletonOverlay
                                        .aspectRatio(photo.size.width / photo.size.height, contentMode: .fit)
                                        .skeletonReveal(visible: skeletonVisible)
                                }
                                if revealSegment == .bones, !frontalDimensions.isEmpty {
                                    DimensionOverlay(dimensions: frontalDimensions, progress: dimensionProgress)
                                        .aspectRatio(photo.size.width / photo.size.height, contentMode: .fit)
                                        .skeletonReveal(visible: dimensionsVisible)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            // Capped (Kah, on-device: a tall portrait photo scaled
                            // to full width pushed the hero number below the
                            // fold entirely) — the ceremony's whole point is the
                            // number rolling while the photo/skeleton are still
                            // visible, so the photo can never own so much height
                            // that the number needs a scroll to see. scaledToFit
                            // still shows the whole photo, just letterboxed
                            // within this cap instead of running to its full
                            // (often much taller) natural height.
                            .frame(maxHeight: screenProxy.size.height * 0.4)
                            .background(Theme.Palette.bg1)
                            .pinchZoomable()
                            .onAppear { beginCeremony() }
                            .onChange(of: maskOverlay) { _, _ in startSweepIfReady() }
                            // `.task` (not a bare `Task { }`) so SwiftUI cancels this
                            // automatically if the user backs out before the hold ends.
                            .task { await revealRowsAfterHold() }

                            SegmentedToggleBar(labels: revealSegmentLabels, selectedIndex: revealSegmentIndexBinding)
                            SectionDivider()

                            VStack(alignment: .leading, spacing: 0) {
                                Text("FRONTAL AREA")
                                    .font(Theme.mono(11, weight: .bold))
                                    .foregroundStyle(Theme.Palette.fg3)
                                    .kerning(0.8)
                                    .padding(.top, Theme.Space.xl)
                                    .opacity(labelVisible ? 1 : 0)

                                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
                                    RollingNumberText(
                                        value: result.frontalAreaCm2,
                                        format: { AnalysisMath.areaDisplay($0) },
                                        font: Theme.mono(60, weight: .bold),
                                        color: Theme.Palette.acc,
                                        tracking: Theme.Typography.tracking(forSize: 60),
                                        delay: 0.7,
                                        onComplete: { Haptics.confirm() }
                                    )
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
                                .opacity(uncertaintyVisible ? 1 : 0)

                                SectionDivider()

                                MetricRow(key: "Scale",
                                          value: String(format: "%.1f px/cm", result.pixelsPerCm))
                                    .cascadeIn(index: 0, trigger: rowsVisible)
                                if let barWidthMm {
                                    MetricRow(key: "Bar width", value: "\(Int(barWidthMm)) mm")
                                        .cascadeIn(index: 1, trigger: rowsVisible)
                                }
                                if let fraction = result.wheelCheckDisagreementFraction {
                                    let check = AnalysisMath.wheelCheckDisplay(fraction)
                                    MetricRow(key: "Wheel check", value: check.text,
                                              valueColor: check.isWarning ? Theme.Palette.amb : Theme.Palette.fg)
                                        .cascadeIn(index: 2, trigger: rowsVisible)
                                }
                                if let shoulder = result.headOnPose?.shoulderWidthCm {
                                    MetricRow(key: "Shoulder width",
                                              value: String(format: "%.1f cm", shoulder))
                                        .cascadeIn(index: 3, trigger: rowsVisible)
                                }
                                if let pose = sideOnPose {
                                    MetricRow(key: "Torso angle",
                                              value: "\(Int(pose.torsoAngleDeg.rounded()))°")
                                        .cascadeIn(index: 4, trigger: rowsVisible)
                                    MetricRow(key: "Hip angle",
                                              value: "\(Int(pose.hipAngleDeg.rounded()))°")
                                        .cascadeIn(index: 5, trigger: rowsVisible)
                                    // Shown only when a real wheelbase ruler produced it
                                    // (Plan P1.5) — otherwise it's still borrowing the
                                    // frontal photo's scale (unenforced same-distance
                                    // assumption) and stays undefendable (spec §3).
                                    if hasSideOnRuler {
                                        MetricRow(key: "Head drop",
                                                  value: String(format: "%.1f cm", pose.headDropCm))
                                            .cascadeIn(index: 6, trigger: rowsVisible)
                                    }
                                    // Correctable at the first moment the rider can see it
                                    // (Plan P3) — no separate ask-once modal, just this same
                                    // always-present chip PositionDetailView shows later.
                                    FacingRow(
                                        facing: AnalysisMath.sideOnFacing(
                                            shoulder: pose.shoulder, hip: pose.hip, knee: pose.knee, ear: pose.ear
                                        )
                                    )
                                    .cascadeIn(index: 7, trigger: rowsVisible)
                                }
                            }
                            .padding(.horizontal, Theme.Space.screenMargin)
                        }
                    }

                    GhostButton(label: "RETAKE", action: onRetake)
                        .padding(.horizontal, Theme.Space.screenMargin)
                        .padding(.top, Theme.Space.sm)
                        .opacity(buttonsVisible ? 1 : 0)

                    AccentButton(label: "NAME POSITION", action: onContinue)
                        .padding(.horizontal, Theme.Space.screenMargin)
                        .padding(.vertical, Theme.Space.md)
                        .opacity(buttonsVisible ? 1 : 0)
                }
            }
        }
    }

    /// Only the segments that make sense for this capture — BONES is absent
    /// entirely when there's no head-on pose, rather than shown disabled.
    private var revealSegments: [PhotoSegment] {
        result.headOnPose != nil ? [.photo, .mask, .bones] : [.photo, .mask]
    }

    private var revealSegmentLabels: [String] {
        revealSegments.map(\.label)
    }

    /// Intercepts PHOTO/MASK/BONES taps: mid-ceremony, snap everything to its
    /// end state first (no ceremony re-run on toggle), then crossfade normally.
    private var revealSegmentIndexBinding: Binding<Int> {
        Binding(
            get: { revealSegments.firstIndex(of: revealSegment) ?? 0 },
            set: { newIndex in
                guard revealSegments.indices.contains(newIndex) else { return }
                if !sweepStarted || sweepProgress < 1 {
                    cancelCeremony()
                }
                withAnimation(Theme.Motion.travel(Theme.Motion.base)) {
                    revealSegment = revealSegments[newIndex]
                }
            }
        )
    }

    /// Frontal skeleton (Plan O4), progress baked in from `skeletonProgress`
    /// so the call site can just place the view — nil when there's no pose
    /// (mirrors `revealSegments` excluding BONES in that case).
    private var frontalSkeletonOverlay: SkeletonOverlay? {
        guard let headOnPose = result.headOnPose else { return nil }
        let arms = headOnPose.armPoints.map { $0.flatMap { [Double($0.x), Double($0.y)] } }
        let hips = headOnPose.hipPoints.map { $0.flatMap { [Double($0.x), Double($0.y)] } }
        let knees = headOnPose.kneePoints.map { $0.flatMap { [Double($0.x), Double($0.y)] } }
        guard var overlay = SkeletonOverlay.frontal(
            shoulders: [
                headOnPose.leftShoulder.x, headOnPose.leftShoulder.y,
                headOnPose.rightShoulder.x, headOnPose.rightShoulder.y,
            ],
            arms: arms,
            hips: hips,
            knees: knees
        ) else { return nil }
        overlay.progress = skeletonProgress
        return overlay
    }

    /// Bar width always (when calibrated); wheel diameter only when the
    /// optional wheel check was done — each degrades independently via
    /// `DimensionOverlay.dimension(points:mm:)`. No side-on dimension here:
    /// RevealStep never renders a side-on photo, so wheelbase stays
    /// detail-only (Plan X3).
    private var frontalDimensions: [DimensionOverlay.Dimension] {
        [
            DimensionOverlay.dimension(points: barTapPoints, mm: barWidthMm),
            DimensionOverlay.dimension(points: wheelTapPoints, mm: wheelDiameterMm),
        ].compactMap { $0 }
    }

    private func beginCeremony() {
        guard !hasStartedCeremony else { return }
        hasStartedCeremony = true
        skeletonVisible = true
        dimensionsVisible = true

        if reduceMotion {
            sweepProgress = 1
            sweepStarted = true
            skeletonProgress = 1
            dimensionProgress = 1
            withAnimation(Theme.Motion.entrance()) {
                labelVisible = true
                uncertaintyVisible = true
                rowsVisible = true
                buttonsVisible = true
            }
            return
        }
        withAnimation(Theme.Motion.entrance().delay(0.5)) { labelVisible = true }
        withAnimation(Theme.Motion.entrance().delay(1.5)) { uncertaintyVisible = true }
        withAnimation(Theme.Motion.entrance().delay(1.9)) { buttonsVisible = true }
        startSweepIfReady()
    }

    /// `cascadeIn` (below) carries its own local `.animation(value:)`, which
    /// takes precedence over an ambient `withAnimation(...).delay()` wrapping
    /// this flip — so the 1.6s hold has to be a real wait, not a delayed
    /// animation, or the rows would cascade in almost immediately. Driven by
    /// the view's `.task` (not a bare `Task { }` from `beginCeremony`) so it's
    /// cancelled automatically if the user backs out mid-hold.
    private func revealRowsAfterHold() async {
        guard !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(1.6))
        guard !ceremonyCancelled else { return }
        rowsVisible = true
    }

    /// The scan wipe never waits on pixel work in the common case (the
    /// overlay is usually ready well before the user reaches this screen),
    /// but if it genuinely isn't at t=0, this fires again from `onChange`
    /// once it lands — never sweep-reveal nothing.
    private func startSweepIfReady() {
        guard !sweepStarted, !ceremonyCancelled, maskOverlay != nil else { return }
        sweepStarted = true
        withAnimation(Theme.Motion.travel(Theme.Motion.sweep)) {
            sweepProgress = 1
        } completion: {
            Haptics.tap()
            startSkeletonDrawOn()
        }
    }

    /// Quiet secondary beat (Plan O4): starts once the sweep completes,
    /// finishes well before the 0.8s number roll it runs alongside — it must
    /// never delay or upstage the roll, which stays the one wow moment.
    private func startSkeletonDrawOn() {
        guard !reduceMotion, let frontalSkeletonOverlay else {
            startDimensionDrawOn()
            return
        }
        withAnimation(Theme.Motion.travel(frontalSkeletonOverlay.totalDrawDuration)) {
            skeletonProgress = 1
        } completion: {
            startDimensionDrawOn()
        }
    }

    /// The tertiary beat (Plan X3): starts only once the skeleton's own
    /// draw-in has fully completed, so the dimensions read as a quieter
    /// layer on top of it rather than competing for attention.
    private func startDimensionDrawOn() {
        guard !reduceMotion, !frontalDimensions.isEmpty else {
            dimensionProgress = 1
            return
        }
        withAnimation(Theme.Motion.travel(Theme.Motion.base)) {
            dimensionProgress = 1
        }
    }

    private func cancelCeremony() {
        guard !ceremonyCancelled else { return }
        ceremonyCancelled = true
        sweepStarted = true
        sweepProgress = 1
        skeletonProgress = 1
        skeletonVisible = true
        dimensionProgress = 1
        dimensionsVisible = true
        labelVisible = true
        uncertaintyVisible = true
        rowsVisible = true
        buttonsVisible = true
    }
}

private struct NamePositionStep: View {
    let result: AnalysisResult
    let onSave: (String) -> Void

    @State private var label = ""
    @FocusState private var nameFieldFocused: Bool

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(AnalysisMath.areaDisplay(result.frontalAreaCm2)) cm² · CAPTURED")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
                    .padding(.top, Theme.Space.xl)
                Text("Name this position.")
                    .font(Theme.heading(24))
                    .foregroundStyle(Theme.Palette.fg)
            }
            .padding(.horizontal, Theme.Space.screenMargin)
            .padding(.bottom, Theme.Space.lg)

            VStack(alignment: .leading, spacing: 0) {
                FieldLabel("POSITION NAME")
                MonoField(placeholder: "Hoods, fully loaded", text: $label)
                    .focused($nameFieldFocused)
            }
            .padding(.horizontal, Theme.Space.screenMargin)

            Text("You'll compare against this name later.")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.Palette.fg3)
                .padding(.horizontal, Theme.Space.screenMargin)
                .padding(.top, Theme.Space.sm)

            Spacer()

            AccentButton(label: "SAVE POSITION",
                         action: {
                             Haptics.confirm()
                             onSave(label.trimmingCharacters(in: .whitespaces))
                         },
                         enabled: isValid)
                .padding(.horizontal, Theme.Space.screenMargin)
                .padding(.vertical, Theme.Space.md)
        }
        // Short delay so the keyboard doesn't rise mid-way through this
        // step's own entrance fade (N4). `.task`, not a bare `Task { }` in
        // `.onAppear`, so it's cancelled automatically on a fast back-out.
        .task {
            try? await Task.sleep(for: .seconds(0.3))
            nameFieldFocused = true
        }
    }
}

private struct CaptureSuccessStep: View {
    let areaCm2: Double?
    let onViewAnalysis: () -> Void
    let onCaptureAnother: () -> Void

    @State private var savedVisible = false
    @State private var buttonsVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("SAVED")
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(Theme.Palette.fg3)
                .kerning(0.8)
                .opacity(savedVisible ? 1 : 0)

            if let areaCm2 {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
                    Text(AnalysisMath.areaDisplay(areaCm2))
                        .font(Theme.mono(52, weight: .bold))
                        .foregroundStyle(Theme.Palette.acc)
                        .kerning(Theme.Typography.tracking(forSize: 52))
                    Text("cm²")
                        .font(Theme.mono(16))
                        .foregroundStyle(Theme.Palette.fg3)
                }
                .padding(.top, Theme.Space.sm)
                .offset(y: savedVisible ? 0 : 8)
                .opacity(savedVisible ? 1 : 0)
            }

            Spacer()

            // Q8.3: AccentButton is always the bottom-most control — primary
            // action at the thumb.
            GhostButton(label: "CAPTURE ANOTHER POSITION", action: onCaptureAnother)
                .padding(.horizontal, Theme.Space.screenMargin)
                .opacity(buttonsVisible ? 1 : 0)
            AccentButton(label: "VIEW ANALYSIS", action: onViewAnalysis)
                .padding(.horizontal, Theme.Space.screenMargin)
                .padding(.top, Theme.Space.sm)
                .padding(.bottom, Theme.Space.md)
                .opacity(buttonsVisible ? 1 : 0)
        }
        .onAppear {
            Haptics.confirm()
            withAnimation(Theme.Motion.entrance(Theme.Motion.gentle)) {
                savedVisible = true
            }
            withAnimation(Theme.Motion.entrance().delay(0.15)) {
                buttonsVisible = true
            }
        }
    }
}

/// Side-on wheelbase ruler entry point (Plan P1.5) — routes to whichever of
/// two sub-steps applies: tap-calibration when the bike already has a
/// wheelbase on file, or a one-time inline entry prompt when it doesn't.
/// Never gates capture (mirrors the wheel-check's rule): either sub-step can
/// skip straight through to analysis, falling back to the borrowed frontal
/// scale exactly as before this plan.
private struct SideOnCalibrationStep: View {
    let image: UIImage
    let bike: Bike
    @Binding var tapPoints: [CGPoint]
    let onConfirm: (Double) -> Void
    let onSkip: () -> Void

    // Seeded from the bike's stored value; once the entry prompt sets one
    // (and persists it to `bike.wheelbaseMm` for future captures), this
    // flips the view to the tap-calibration sub-step for *this* capture too
    // — no need to wait for a re-render from SwiftData.
    @State private var wheelbaseMm: Double?

    init(image: UIImage, bike: Bike, tapPoints: Binding<[CGPoint]>, onConfirm: @escaping (Double) -> Void, onSkip: @escaping () -> Void) {
        self.image = image
        self.bike = bike
        self._tapPoints = tapPoints
        self.onConfirm = onConfirm
        self.onSkip = onSkip
        self._wheelbaseMm = State(initialValue: bike.wheelbaseMm)
    }

    var body: some View {
        if let wheelbaseMm {
            TapCalibrationStep(
                image: image,
                tapPoints: $tapPoints,
                wheelTapPoints: .constant([]),
                wheelDiameterMm: nil,
                primaryTapPrompts: ("Tap the front wheel axle", "Now tap the rear wheel axle"),
                confirmLabel: "CONFIRM WHEELBASE",
                onSkip: onSkip,
                skipLabel: "SKIP RULER",
                onConfirm: {
                    guard tapPoints.count == 2 else { return }
                    let scale = AnalysisMath.sideOnPixelsPerCm(
                        tap0: tapPoints[0], tap1: tapPoints[1],
                        imageSize: image.size, wheelbaseMm: wheelbaseMm
                    )
                    onConfirm(scale)
                }
            )
        } else {
            WheelbaseEntryPrompt(
                image: image,
                onUse: { enteredMm in
                    bike.wheelbaseMm = enteredMm  // on file for every future capture, no re-asking
                    wheelbaseMm = enteredMm
                },
                onSkip: onSkip
            )
        }
    }
}

/// One-time inline prompt (Plan P1.5) shown only when the selected bike has
/// no wheelbase on record — same spirit as `BikePickerSheet`'s inline
/// add-bike form. Optional, like every scale-verification affordance here.
private struct WheelbaseEntryPrompt: View {
    let image: UIImage
    let onUse: (Double) -> Void
    let onSkip: () -> Void

    @State private var wheelbaseText = ""
    @FocusState private var fieldFocused: Bool

    private var enteredValue: Double? { Double(wheelbaseText) }
    private var isValid: Bool { (enteredValue ?? 0) > 0 }

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("Add your bike's wheelbase for a more accurate side-on measurement (optional).")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
                    .padding(.top, Theme.Space.lg)

                FieldLabel("WHEELBASE (MM)")
                MonoField(placeholder: "1050", text: $wheelbaseText, numericOnly: true)
                    .focused($fieldFocused)
            }
            .padding(.horizontal, Theme.Space.screenMargin)

            Spacer(minLength: Theme.Space.lg)

            GhostButton(label: "SKIP RULER", action: onSkip)
                .padding(.horizontal, Theme.Space.screenMargin)
                .padding(.top, Theme.Space.sm)
            AccentButton(
                label: "USE THIS",
                action: {
                    guard let value = enteredValue else { return }
                    onUse(value)
                },
                enabled: isValid
            )
            .padding(.horizontal, Theme.Space.screenMargin)
            .padding(.vertical, Theme.Space.md)
        }
        .task {
            try? await Task.sleep(for: .seconds(0.3))
            fieldFocused = true
        }
    }
}

/// One-time existing-data caveat (Plan S1) — a drop-bar bike whose width was
/// entered before the bar-type split may carry a hood-width number, not a
/// drop-end one. Dismiss is the only action (no forced re-entry); it reads
/// as an acknowledgement, not a correction.
private struct DropBarCaveatBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.sm) {
            Text(text)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.Palette.amb)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("GOT IT", action: onDismiss)
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.amb)
                .buttonStyle(.plain)
        }
        .padding(Theme.Space.md)
        .background(Theme.Palette.bg1)
        .overlay(Rectangle().stroke(Theme.Palette.amb, lineWidth: 1))
    }
}

/// Two-tap distance calibration against a photo — pinch/zoom/pan, drag-to-
/// fine-tune, floating loupe, connecting line. Originally built for the
/// head-on handlebar ruler; generalised (Plan P1.5) to also drive the
/// side-on wheelbase ruler — the gesture/rendering mechanics are identical,
/// only the primary taps' copy and confirm label vary per caller.
private struct TapCalibrationStep: View {
    let image: UIImage
    @Binding var tapPoints: [CGPoint]
    // Optional cross-scale verification taps (Plan K3) — ground contact +
    // tire top. `nil` wheelDiameterMm means the selected bike has no wheel
    // size on record, so the verify affordance never appears.
    @Binding var wheelTapPoints: [CGPoint]
    let wheelDiameterMm: Double?
    // Plan P1.5: the primary tap pair's banner copy and confirm label,
    // defaulted to the original handlebar-ruler copy so the existing
    // head-on call site (trailing-closure `onConfirm`) is unaffected by
    // this generalisation — hence these sit *before* onConfirm below,
    // keeping it the last parameter.
    var primaryTapPrompts: (first: String, second: String) = (
        "Tap the left end of your handlebars", "Now tap the right end"
    )
    var confirmLabel: String = "CONFIRM SCALE"
    // Plan S1: one-time existing-data caveat for a drop-bar bike whose width
    // predates the bar-type split — nil (the default) shows nothing, so the
    // side-on wheelbase call site is unaffected. Dismissing is the
    // acknowledgement (CaptureView's onDismiss sets barType explicitly),
    // there's no separate "confirmed" state to track here.
    var caveatBanner: (text: String, onDismiss: () -> Void)? = nil
    // Never gates confirm (same "advisory only" rule as the wheel check) —
    // nil (the default) omits the affordance entirely, matching the
    // head-on ruler's no-skip behaviour today.
    var onSkip: (() -> Void)? = nil
    var skipLabel: String = "SKIP"
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Persisted zoom/pan (committed at gesture end) plus the in-flight gesture
    // deltas, combined for the live transform each frame.
    @State private var zoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1
    @GestureState private var panDelta: CGSize = .zero

    // Live screen position of whichever point is being dragged (bar or
    // wheel) — drives the floating loupe. `nil` when not dragging.
    @State private var dragScreenPoint: CGPoint?
    // Captured once per drag gesture: the point's screen position *before*
    // this drag started. `DragGesture.translation` is cumulative from
    // gesture-start, not incremental, so this has to stay fixed for the
    // duration of one drag rather than being re-derived from the points
    // array (which mutates on every callback).
    @State private var dragStartUnit: CGPoint?

    // Live finger position while a tap is being *placed* (before it commits on
    // release) — drives the preview loupe so the user sees exactly where the
    // point will land (skill §1/§2/§10). `nil` when not placing, or once the
    // gesture crosses the pan threshold and becomes a pan instead.
    @State private var pendingPlacement: CGPoint?

    // Whether the optional wheel-verification taps are being collected —
    // never gates CONFIRM SCALE (Plan K, explicit directive).
    @State private var verifyingWheel = false

    // Connecting-line draw progress (N4) — 0→1 once each pair's second point
    // lands, independent of the points themselves so dragging afterward
    // doesn't re-trigger the draw.
    @State private var barLineProgress: Double = 0
    @State private var wheelLineProgress: Double = 0

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 8
    // Movement past this (points) reclassifies a placement as a pan — matches
    // the pan gesture's `minimumDistance` so tap-to-place and drag-to-pan share
    // one boundary (skill §10 cancel-by-dragging-away). Raised from 10 to 30
    // (Plan W5) so a pinch's incidental centroid drift (`DragGesture` picks
    // this up too, since pan and pinch run `.simultaneously`) mostly stays
    // under it and never registers as a deliberate pan, while a real
    // two-finger pan — which moves much further — still does. The
    // `clampedPanOffset` commit in `backgroundGesture` is the hard guarantee
    // against drift either way.
    private let panThreshold: CGFloat = 30

    var body: some View {
        VStack(spacing: 0) {
            if let caveatBanner {
                DropBarCaveatBanner(text: caveatBanner.text, onDismiss: caveatBanner.onDismiss)
            }

            instructionBanner

            GeometryReader { proxy in
                // §2.1 fix: compute the actual displayed image rect (aspect-fit)
                // so taps are measured against the image, not the letterbox container.
                let imageRect = CalibrationTransform.aspectFitRect(imageSize: image.size, in: proxy.size)
                // Clamp the live composition too (Plan W5), not just the
                // committed value at gesture end — otherwise a pinch mid-flight
                // can transiently show a gap even though it snaps back on release.
                let liveZoom = zoomScale * pinchDelta
                let livePan = CalibrationTransform.clampedPanOffset(
                    CGSize(width: panOffset.width + panDelta.width, height: panOffset.height + panDelta.height),
                    zoomScale: liveZoom, imageRect: imageRect, containerSize: proxy.size
                )
                let viewport = CalibrationTransform.Viewport(
                    containerSize: proxy.size,
                    imageRect: imageRect,
                    zoomScale: liveZoom,
                    panOffset: livePan
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
                        .gesture(backgroundGesture(viewport: viewport)
                            .simultaneously(with: placementGesture(viewport: viewport)))

                    // Handles + connecting line, positioned via the pure
                    // transform on this same untransformed layer — their own
                    // drag gestures take priority over the background pan
                    // when a touch starts inside a handle.
                    pointOverlay(viewport: viewport)

                    if let dragScreenPoint {
                        loupe(forScreenPoint: dragScreenPoint, in: viewport)
                            .position(x: dragScreenPoint.x, y: max(60, dragScreenPoint.y - 110))
                            .allowsHitTesting(false)
                    } else if let pendingPlacement {
                        loupe(forScreenPoint: pendingPlacement, in: viewport)
                            .position(x: pendingPlacement.x, y: max(60, pendingPlacement.y - 110))
                            .allowsHitTesting(false)
                    }
                }
                .clipped()
            }

            Group {
                if showsResetView {
                    resetViewButton
                        .transition(appearTransition)
                }
            }
            .animation(Theme.Motion.entrance(), value: showsResetView)

            Group {
                if showsWheelVerifyLink {
                    wheelVerifyLink
                        .transition(appearTransition)
                } else if verifyingWheel {
                    wheelSkipLink
                        .transition(appearTransition)
                } else if let onSkip {
                    skipRulerLink(action: onSkip)
                        .transition(appearTransition)
                }
            }
            .animation(Theme.Motion.entrance(), value: verifyingWheel)
            .animation(Theme.Motion.entrance(), value: showsWheelVerifyLink)

            confirmButton
        }
    }

    /// Fade+slide normally; Reduce Motion drops the slide, keeping the fade.
    /// Slides from the BOTTOM edge (skill §7/§8): these affordances live in the
    /// bottom control stack directly above CONFIRM SCALE, so they rise into
    /// place from the action zone rather than dropping in from the top and
    /// pulling the eye away from the CTA.
    private var appearTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom))
    }

    private var showsResetView: Bool { zoomScale > 1.01 || panOffset != .zero }

    private var showsWheelVerifyLink: Bool {
        tapPoints.count == 2 && (wheelDiameterMm ?? 0) > 0 && !verifyingWheel && wheelTapPoints.isEmpty
    }

    private var instructionBanner: some View {
        Text(bannerText)
            .id(bannerText)
            .transition(.opacity)
            .font(Theme.mono(12))
            .foregroundStyle(Theme.Palette.fg)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Theme.Palette.bg1)
            .animation(Theme.Motion.entrance(Theme.Motion.fast), value: bannerText)
    }

    private var bannerText: String {
        if verifyingWheel {
            return wheelTapPoints.isEmpty
                ? "Tap where the front tire touches the ground"
                : wheelTapPoints.count == 1
                ? "Now tap the top of the front tire"
                : "Pinch to zoom, drag a point to fine-tune"
        }
        return tapPoints.count == 0
            ? primaryTapPrompts.first
            : tapPoints.count == 1
            ? primaryTapPrompts.second
            : "Pinch to zoom, drag a point to fine-tune"
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

    /// Ghost link offering the optional wheel check — only shown once the
    /// two bar taps are placed and the selected bike has a wheel size on
    /// record (Plan K3, decision 3).
    private var wheelVerifyLink: some View {
        Button { verifyingWheel = true } label: {
            Text("VERIFY WITH WHEEL (OPTIONAL)")
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.acc)
                .kerning(0.5)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.bg1)
    }

    private var wheelSkipLink: some View {
        Button {
            verifyingWheel = false
            wheelTapPoints = []
            wheelLineProgress = 0
        } label: {
            Text("SKIP WHEEL CHECK")
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.fg3)
                .kerning(0.5)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.bg1)
    }

    /// The ruler-skip affordance (Plan P1.5) — same never-gates-confirm
    /// posture as `wheelSkipLink`, generalised to whatever `skipLabel` the
    /// caller wants (side-on's wheelbase ruler uses "SKIP RULER").
    private func skipRulerLink(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(skipLabel.uppercased())
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.fg3)
                .kerning(0.5)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.bg1)
    }

    @ViewBuilder
    private func pointOverlay(viewport: CalibrationTransform.Viewport) -> some View {
        connectingLine(points: tapPoints, progress: barLineProgress, viewport: viewport)
        handles(points: $tapPoints, colors: (Theme.Palette.acc, Theme.Palette.amb), viewport: viewport)

        if verifyingWheel {
            connectingLine(points: wheelTapPoints, progress: wheelLineProgress, viewport: viewport)
            handles(points: $wheelTapPoints, colors: (Theme.Palette.fg, Theme.Palette.fg), viewport: viewport)
        }
    }

    @ViewBuilder
    private func connectingLine(points: [CGPoint], progress: Double, viewport: CalibrationTransform.Viewport) -> some View {
        if points.count == 2 {
            Path { path in
                path.move(to: CalibrationTransform.screenPoint(forUnit: points[0], in: viewport))
                path.addLine(to: CalibrationTransform.screenPoint(forUnit: points[1], in: viewport))
            }
            .trim(from: 0, to: progress)
            .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
    }

    /// Draggable handles for one tap group (bar or wheel). `colors` picks
    /// the fill for point 0 / point 1 — bar taps keep their original
    /// lime/amber pair, wheel taps use a single white fill so the two
    /// groups read as visually distinct on the same image (Plan K3). Newly
    /// placed handles settle in from a slightly larger scale (N4) — a single
    /// eased ease-out, not a spring, so it doesn't read as a bounce.
    private func handles(
        points: Binding<[CGPoint]>, colors: (first: Color, second: Color), viewport: CalibrationTransform.Viewport
    ) -> some View {
        ForEach(Array(points.wrappedValue.enumerated()), id: \.offset) { index, unit in
            let screen = CalibrationTransform.screenPoint(forUnit: unit, in: viewport)
            Rectangle()
                .strokeBorder(.white, lineWidth: 2)
                .background(Rectangle().fill(index == 0 ? colors.first : colors.second))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
                .position(screen)
                .transition(
                    reduceMotion
                        ? .opacity.animation(Theme.Motion.entrance(Theme.Motion.fast))
                        : .scale(scale: 1.3).combined(with: .opacity).animation(Theme.Motion.entrance(Theme.Motion.fast))
                )
                .gesture(dragGesture(index: index, points: points, viewport: viewport))
        }
    }

    private func dragGesture(
        index: Int, points: Binding<[CGPoint]>, viewport: CalibrationTransform.Viewport
    ) -> some Gesture {
        // `value.location` is relative to the handle's own small hit frame,
        // not the container — useless as an absolute position. `.translation`
        // is a stable delta since gesture-start regardless of that, so anchor
        // it to the point's screen position captured once at drag-start.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartUnit == nil { dragStartUnit = points.wrappedValue[index] }
                guard let startUnit = dragStartUnit else { return }
                let startScreen = CalibrationTransform.screenPoint(forUnit: startUnit, in: viewport)
                let liveScreen = CGPoint(x: startScreen.x + value.translation.width,
                                          y: startScreen.y + value.translation.height)
                dragScreenPoint = liveScreen
                points.wrappedValue[index] = CalibrationTransform.unitPoint(forScreen: liveScreen, in: viewport)
            }
            .onEnded { _ in
                dragStartUnit = nil
                dragScreenPoint = nil
            }
    }

    private var canPlaceMore: Bool {
        verifyingWheel ? wheelTapPoints.count < 2 : tapPoints.count < 2
    }

    /// Placement with forgiveness (skill §10): preview the landing point in the
    /// loupe on touch-down, commit on release, and cancel if the finger crossed
    /// the pan threshold (that gesture was a pan, handled simultaneously by
    /// `backgroundGesture`). Runs simultaneously with pan; for a plain tap
    /// (<`panThreshold`) only this fires, so the point commits on lift.
    private func placementGesture(viewport: CalibrationTransform.Viewport) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard canPlaceMore,
                      hypot(value.translation.width, value.translation.height) <= panThreshold
                else { pendingPlacement = nil; return }
                let unit = CalibrationTransform.unitPoint(forScreen: value.location, in: viewport)
                pendingPlacement = (0...1).contains(unit.x) && (0...1).contains(unit.y) ? value.location : nil
            }
            .onEnded { value in
                defer { pendingPlacement = nil }
                guard canPlaceMore,
                      hypot(value.translation.width, value.translation.height) <= panThreshold
                else { return }
                handleTap(location: value.location, viewport: viewport)
            }
    }

    /// Pinch-to-zoom + pan on the image itself. `panThreshold` as the pan
    /// drag's `minimumDistance` lets a plain tap (placing a point via
    /// `placementGesture`) stay below it and commit as a placement — see
    /// that constant's doc for why it was raised from 10 (Plan W5). The
    /// `clampedPanOffset` commit below is the hard guarantee against drift
    /// either way.
    private func backgroundGesture(viewport: CalibrationTransform.Viewport) -> some Gesture {
        let magnify = MagnificationGesture()
            .updating($pinchDelta) { value, state, _ in state = value }
            .onEnded { value in
                let newZoom = min(maxZoom, max(minZoom, zoomScale * value))
                zoomScale = newZoom
                panOffset = CalibrationTransform.clampedPanOffset(
                    panOffset, zoomScale: newZoom, imageRect: viewport.imageRect, containerSize: viewport.containerSize
                )
            }
        let pan = DragGesture(minimumDistance: panThreshold)
            .updating($panDelta) { value, state, _ in state = value.translation }
            .onEnded { value in
                let newOffset = CGSize(
                    width: panOffset.width + value.translation.width,
                    height: panOffset.height + value.translation.height
                )
                panOffset = CalibrationTransform.clampedPanOffset(
                    newOffset, zoomScale: zoomScale, imageRect: viewport.imageRect, containerSize: viewport.containerSize
                )
            }
        return magnify.simultaneously(with: pan)
    }

    private func handleTap(location: CGPoint, viewport: CalibrationTransform.Viewport) {
        // Ignore taps outside the image — in the letterbox/pillarbox padding,
        // or panned/zoomed off-canvas.
        let unit = CalibrationTransform.unitPoint(forScreen: location, in: viewport)
        guard (0...1).contains(unit.x), (0...1).contains(unit.y) else { return }
        if verifyingWheel {
            guard wheelTapPoints.count < 2 else { return }
            wheelTapPoints.append(unit)
            Haptics.tap()
            if wheelTapPoints.count == 2 {
                drawLine(progress: $wheelLineProgress)
            }
        } else {
            guard tapPoints.count < 2 else { return }
            tapPoints.append(unit)
            Haptics.tap()
            if tapPoints.count == 2 {
                drawLine(progress: $barLineProgress)
            }
        }
    }

    /// Animates the connecting line drawing in; under Reduce Motion it just
    /// appears at full length (no `trim` animation), still with the haptic.
    private func drawLine(progress: Binding<Double>) {
        if reduceMotion {
            progress.wrappedValue = 1
            Haptics.tap()
            return
        }
        progress.wrappedValue = 0
        withAnimation(Theme.Motion.travel(Theme.Motion.base)) {
            progress.wrappedValue = 1
        } completion: {
            Haptics.tap()
        }
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
        AccentButton(label: confirmLabel, action: onConfirm, enabled: tapPoints.count == 2)
            .padding(.horizontal, Theme.Space.screenMargin)
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
