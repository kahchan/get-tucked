import SwiftUI
import SwiftData
import ImageIO
#if canImport(UIKit)
import PhotosUI
import Photos
#endif

struct PositionDetailView: View {
    @Bindable var position: Position
    @Binding var path: [AppScreen]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    #if canImport(UIKit)
    @State private var headOnImage: UIImage?
    @State private var sideOnImage: UIImage?
    @State private var maskOverlay: UIImage?
    @State private var sideOnMaskOverlay: UIImage?
    #endif
    @State private var showingSideOn = false
    // Remembered per photo side for the session (Plan O5) — not persisted,
    // so a revisit always starts back on PHOTO like it does today.
    @State private var frontalPhotoSegment: PhotoSegment = .photo
    @State private var sideOnPhotoSegment: PhotoSegment = .photo
    @State private var showDeleteConfirm = false
    // Peeked from the stored photos' headers (no full decode) so the
    // placeholder box is sized correctly from the very first frame (N5) —
    // the decoded photo then fades in over it with zero layout shift.
    // Side-on is captured in landscape (see OrientationLock.allowsLandscape),
    // so it needs its own aspect ratio — locking the container to headOn's
    // portrait ratio would badly letterbox the side-on photo when toggled.
    private let headOnAspectRatio: CGFloat
    private let sideOnAspectRatio: CGFloat

    init(position: Position, path: Binding<[AppScreen]>) {
        self.position = position
        self._path = path
        self.headOnAspectRatio = Self.peekAspectRatio(from: position.photosData) ?? 4.0 / 3.0
        self.sideOnAspectRatio = Self.peekAspectRatio(from: position.sideOnPhotoData) ?? 4.0 / 3.0
    }

    private var hasSideOn: Bool { position.sideOnPhotoIdentifier != nil || position.sideOnPhotoData != nil }

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

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: position.label.uppercased())

                SectionDivider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Photo view toggle (only shown when side-on exists)
                        if hasSideOn {
                            SegmentedToggleBar(labels: ["FRONTAL", "SIDE-ON"], selectedIndex: sideOnSegmentBinding)
                            SectionDivider()
                        }

                        // Photo
                        #if canImport(UIKit)
                        ZStack {
                            // Aspect-matched placeholder, present from the first
                            // frame — the decoded photo(s) fade in over it below,
                            // so there's never a size jump (N5).
                            Theme.Palette.bg1

                            if let image = headOnImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .transition(.opacity)
                                    .opacity(showingSideOn ? 0 : 1)
                            }
                            if let image = sideOnImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .transition(.opacity)
                                    .opacity(showingSideOn ? 1 : 0)
                            }
                            if !showingSideOn, let maskOverlay {
                                Image(uiImage: maskOverlay)
                                    .resizable()
                                    .scaledToFit()
                                    .transition(.opacity)
                                    .opacity(frontalPhotoSegment == .photo ? 0 : 1)
                            }
                            if !showingSideOn, let frontalSkeletonOverlay {
                                frontalSkeletonOverlay
                                    .aspectRatio(headOnAspectRatio, contentMode: .fit)
                                    .skeletonReveal(visible: frontalPhotoSegment == .bones)
                            }
                            if showingSideOn, let sideOnMaskOverlay {
                                Image(uiImage: sideOnMaskOverlay)
                                    .resizable()
                                    .scaledToFit()
                                    .transition(.opacity)
                                    .opacity(sideOnPhotoSegment == .photo ? 0 : 1)
                            }
                            if showingSideOn, let sideOnSkeletonOverlay {
                                sideOnSkeletonOverlay
                                    .aspectRatio(sideOnAspectRatio, contentMode: .fit)
                                    .skeletonReveal(visible: sideOnPhotoSegment == .bones)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if showingSideOn, let sideOnFacing {
                                FacingChip(derivedFacing: sideOnFacing.facing, confidence: sideOnFacing.confidence)
                                    .padding(Theme.Space.sm)
                            }
                        }
                        .aspectRatio(showingSideOn ? sideOnAspectRatio : headOnAspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        // Keyed on showingSideOn so switching photos resets zoom
                        // rather than carrying a now-meaningless offset onto a
                        // different image with a different aspect ratio.
                        .id(showingSideOn)
                        .pinchZoomable()
                        // MASK/BONES only make sense once the overlay they need is
                        // ready — fades in (rather than popping the layout) once it
                        // is, same as the underlying mask fade in loadPhotos().
                        if !showingSideOn, frontalSegments.count > 1 {
                            SegmentedToggleBar(labels: frontalSegments.map(\.label), selectedIndex: frontalPhotoSegmentBinding)
                                .transition(.opacity)
                        }
                        if showingSideOn, sideOnSegments.count > 1 {
                            SegmentedToggleBar(labels: sideOnSegments.map(\.label), selectedIndex: sideOnPhotoSegmentBinding)
                                .transition(.opacity)
                        }
                        #else
                        photoPlaceholder
                        #endif

                        SectionDivider()

                        if let metrics = position.metrics {
                            MetricsSection(metrics: metrics)
                            HowItWorksLink(path: $path)
                                .padding(.horizontal, Theme.Space.screenMargin)
                                .padding(.top, Theme.Space.lg)
                                .padding(.bottom, Theme.Space.md)
                        } else {
                            Text("No metrics computed.")
                                .font(Theme.mono(13))
                                .foregroundStyle(Theme.Palette.fg3)
                                .padding(.horizontal, Theme.Space.screenMargin)
                                .padding(.vertical, Theme.Space.lg)
                        }

                        SectionDivider()

                        if let bike = position.bike {
                            MetricRow(key: "Bike", value: bike.nickname)
                                .padding(.horizontal, Theme.Space.screenMargin)
                        }

                        if let packing = position.packingList, !packing.isEmpty {
                            SectionDivider()
                            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                                Text("PACKING")
                                    .font(Theme.mono(10))
                                    .foregroundStyle(Theme.Palette.fg4)
                                Text(packing)
                                    .font(Theme.mono(13))
                                    .foregroundStyle(Theme.Palette.fg2)
                            }
                            .padding(.horizontal, Theme.Space.screenMargin)
                            .padding(.vertical, Theme.Space.lg)
                        }

                        // Straight into the camera, ghost armed (Q3.2) — by
                        // definition the rider has captured before, and the
                        // ghost overlay itself *is* the framing guidance, so
                        // the coaching interstitial would be redundant here
                        // regardless of the first-time flag.
                        GhostButton(label: "MATCH THIS POSITION") {
                            path.append(.capture(referenceID: position.persistentModelID))
                        }
                        .padding(.horizontal, Theme.Space.screenMargin)
                        .padding(.top, Theme.Space.lg)

                        // Same-kit reminder (Q3.2) — the one piece of
                        // SetTheSceneView's coaching this flow genuinely
                        // needs, since that screen is never shown here.
                        Text("Same kit, same helmet, same bar position — clothing changes your silhouette as much as a small bag does.")
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.Palette.fg3)
                            .padding(.horizontal, Theme.Space.screenMargin)
                            .padding(.top, Theme.Space.sm)

                        GhostButton(label: "DELETE POSITION") { showDeleteConfirm = true }
                            .padding(.horizontal, Theme.Space.screenMargin)
                            .padding(.vertical, Theme.Space.lg)
                    }
                }
            }
        }
        .hideNavBar()
        #if canImport(UIKit)
        .task { await loadPhotos() }
        #endif
        .confirmationDialog("Delete this position?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete position", role: .destructive) {
                context.delete(position)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var photoPlaceholder: some View {
        Rectangle()
            .fill(Theme.Palette.bg1)
            .aspectRatio(4/3, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                Text("···")
                    .font(Theme.mono(20))
                    .foregroundStyle(Theme.Palette.fg4)
            }
    }

    private var sideOnSegmentBinding: Binding<Int> {
        Binding(
            get: { showingSideOn ? 1 : 0 },
            set: { newIndex in
                withAnimation(Theme.Motion.travel(Theme.Motion.base)) {
                    showingSideOn = newIndex == 1
                }
            }
        )
    }

    /// Only the segments that make sense given what's actually available —
    /// BONES is absent for positions captured before Plan O (no stored
    /// landmarks), and MASK is absent if the matte failed to build.
    private var frontalSegments: [PhotoSegment] {
        var segments: [PhotoSegment] = [.photo]
        if maskOverlay != nil { segments.append(.mask) }
        if frontalSkeletonOverlay != nil { segments.append(.bones) }
        return segments
    }

    /// Degrades independently of `frontalSegments`: a side-on capture can
    /// have a skeleton with no matte (segmentation failed at capture) or —
    /// in principle — a matte with no skeleton, so each overlay's presence
    /// is checked on its own rather than assuming both-or-neither.
    private var sideOnSegments: [PhotoSegment] {
        var segments: [PhotoSegment] = [.photo]
        if sideOnMaskOverlay != nil { segments.append(.mask) }
        if sideOnSkeletonOverlay != nil { segments.append(.bones) }
        return segments
    }

    private var frontalPhotoSegmentBinding: Binding<Int> {
        Binding(
            get: { frontalSegments.firstIndex(of: frontalPhotoSegment) ?? 0 },
            set: { newIndex in
                guard frontalSegments.indices.contains(newIndex) else { return }
                withAnimation(Theme.Motion.travel(Theme.Motion.base)) {
                    frontalPhotoSegment = frontalSegments[newIndex]
                }
            }
        )
    }

    private var sideOnPhotoSegmentBinding: Binding<Int> {
        Binding(
            get: { sideOnSegments.firstIndex(of: sideOnPhotoSegment) ?? 0 },
            set: { newIndex in
                guard sideOnSegments.indices.contains(newIndex) else { return }
                withAnimation(Theme.Motion.travel(Theme.Motion.base)) {
                    sideOnPhotoSegment = sideOnSegments[newIndex]
                }
            }
        )
    }

    /// No draw-on here (Plan O5) — `SkeletonOverlay.progress` defaults to 1
    /// (fully drawn); `.skeletonReveal` gives the BONES toggle its
    /// Motion.fast opacity fade instead.
    private var frontalSkeletonOverlay: SkeletonOverlay? {
        guard let shoulders = position.metrics?.headOnSkeletonPoints else { return nil }
        return SkeletonOverlay.frontal(shoulders: shoulders, arms: position.metrics?.headOnArmPoints)
    }

    private var sideOnSkeletonOverlay: SkeletonOverlay? {
        guard let points = position.metrics?.sideOnSkeletonPoints else { return nil }
        return SkeletonOverlay.sideOn(points: points)
    }

    /// Derived fresh from the same stored landmarks every time (Plan P3) —
    /// no persisted guess, so this recomputes on every visit rather than
    /// remembering a past correction (Plan P3.3's schema-free decision).
    private var sideOnFacing: (facing: AnalysisMath.Facing, confidence: Double)? {
        guard let points = position.metrics?.sideOnSkeletonPoints, points.count == 8 else { return nil }
        return AnalysisMath.sideOnFacing(
            shoulder: CGPoint(x: points[0], y: points[1]),
            hip: CGPoint(x: points[2], y: points[3]),
            knee: CGPoint(x: points[4], y: points[5]),
            ear: CGPoint(x: points[6], y: points[7])
        )
    }

    #if canImport(UIKit)
    private func loadPhotos() async {
        // Head-on is captured live and persisted as bytes; prefer that over any
        // PHAsset re-fetch. Side-on comes from the picker (asset identifier).
        // Decode off-main (N5) — a revisit shouldn't block the main actor on
        // JPEG decode any more than it has to.
        let headOnData = position.photosData
        let headOnIdentifier = position.headOnPhotoIdentifier
        let sideOnData = position.sideOnPhotoData
        let sideOnIdentifier = position.sideOnPhotoIdentifier
        let maskData = position.maskData
        let sideOnMaskData = position.sideOnMaskData

        // Independent work — run concurrently so a revisit never waits
        // longer than the slower of the two (Plan N5's own goal: a revisit
        // must never feel slower than today).
        async let headOnTask = decodeOrFetch(data: headOnData, identifier: headOnIdentifier)
        async let sideOnTask = decodeOrFetch(data: sideOnData, identifier: sideOnIdentifier)
        let (decodedHeadOn, decodedSideOn) = await (headOnTask, sideOnTask)

        withAnimation(Theme.Motion.entrance(Theme.Motion.gentle)) {
            headOnImage = decodedHeadOn
        }
        withAnimation(Theme.Motion.entrance(Theme.Motion.gentle)) {
            sideOnImage = decodedSideOn
        }

        async let maskTask = buildMaskOverlay(maskData: maskData, photo: decodedHeadOn)
        async let sideOnMaskTask = buildMaskOverlay(maskData: sideOnMaskData, photo: decodedSideOn)
        let (overlay, sideOnOverlay) = await (maskTask, sideOnMaskTask)
        withAnimation(Theme.Motion.entrance()) {
            maskOverlay = overlay
            sideOnMaskOverlay = sideOnOverlay
        }
    }

    /// Off-main JPEG decode when bytes are already on hand; falls back to
    /// the existing PHAsset fetch (already off-main via `PHImageManager`)
    /// when they aren't.
    private func decodeOrFetch(data: Data?, identifier: String?) async -> UIImage? {
        if let data {
            return await Task.detached(priority: .userInitiated) {
                UIImage(data: data)
            }.value
        }
        return await loadAsset(identifier: identifier)
    }

    /// Builds a PHOTO/MASK overlay off-main (N5) — pure pixel work with no
    /// main-actor requirement. Shared by frontal and side-on (Plan O5).
    /// Skips silently — no toggle offered — when there's no stored mask or
    /// when the mask and photo disagree on aspect ratio (Plan I5): a
    /// mismatched composite would tint the wrong region rather than hug the
    /// rider.
    private func buildMaskOverlay(maskData: Data?, photo: UIImage?) async -> UIImage? {
        guard let maskData, let cgPhoto = photo?.cgImage else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let mask = UIImage(data: maskData), let cgMask = mask.cgImage else { return nil }
            guard AnalysisMath.maskMatchesSourceAspect(
                maskWidth: cgMask.width, maskHeight: cgMask.height,
                sourceWidth: cgPhoto.width, sourceHeight: cgPhoto.height
            ) else { return nil }
            return MatteRenderer.tintedOverlay(mask: cgMask, color: UIColor(Theme.Palette.acc), alpha: 0.5)
        }.value
    }

    private func loadAsset(identifier: String?) async -> UIImage? {
        guard let identifier else { return nil }
        // PHAsset re-fetch needs library read authorization; PhotosPicker itself
        // is permissionless, so without this the saved photo silently won't reload.
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) != .denied else { return nil }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else { return nil }
        let size = CGSize(width: 800, height: 800)
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            PHImageManager.default().requestImage(
                for: asset, targetSize: size,
                contentMode: .aspectFit, options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    #endif
}

// MARK: - Metrics section

private struct MetricsSection: View {
    let metrics: PositionMetrics

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heroVisible = false

    /// nil when the optional wheel check was never done; otherwise the same
    /// text/warning pair PositionDetailView and ComparisonView have always
    /// shared (Plan I4) — Plan T just changes where a warning displays it.
    private var wheelCheck: (text: String, isWarning: Bool)? {
        metrics.wheelCheckDisagreementFraction.map(AnalysisMath.wheelCheckDisplay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FRONTAL AREA")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .kerning(0.3)

                // The one flourish on this screen (N5) — a saved number
                // settles, it doesn't perform. Everything else below renders
                // immediately, no animation at all.
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(AnalysisMath.areaDisplay(metrics.frontalAreaCm2))
                        .font(Theme.mono(60, weight: .bold))
                        .foregroundStyle(Theme.Palette.acc)
                        .kerning(Theme.Typography.tracking(forSize: 60))
                    Text("cm²")
                        .font(Theme.mono(18))
                        .foregroundStyle(Theme.Palette.fg3)
                }
                .offset(y: heroVisible || reduceMotion ? 0 : 4)
                .opacity(heroVisible ? 1 : 0)
                .onAppear {
                    withAnimation(Theme.Motion.entrance(Theme.Motion.base)) {
                        heroVisible = true
                    }
                }

                Text(AnalysisMath.uncertaintyDisplay(metrics.frontalAreaUncertainty))
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)

                // Tier 2 (Plan T): warnings only, exception-based — nothing
                // here is a standing number, it's evidence something needs a
                // second look. A failing wheel check escapes the disclosure
                // below to sit alongside the shoulder-width warning.
                if let shoulder = metrics.shoulderWidthCm,
                   let warning = AnalysisMath.shoulderWidthWarning(shoulder) {
                    Text(warning)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.Palette.amb)
                        .padding(.top, Theme.Space.xs)
                }
                if let wheelCheck, wheelCheck.isWarning {
                    Text("Wheel check \(wheelCheck.text) — check your taps and the bike's bar width.")
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.Palette.amb)
                        .padding(.top, Theme.Space.xs)
                }
            }
            .padding(.horizontal, Theme.Space.screenMargin)
            .padding(.top, Theme.Space.lg)
            .padding(.bottom, Theme.Space.md)

            SectionDivider()

            // Tier 3: the one posture number riders actually talk about
            // (bar drop / head position) — shown only when a real wheelbase
            // ruler produced it (Plan P1.5). Still stored on
            // metrics.headDropCm regardless; the gate is purely display.
            if let d = metrics.headDropCm, metrics.sideOnPixelsPerCm != nil {
                MetricRow(key: "Head drop", value: "\(String(format: "%.1f", d)) cm")
                    .padding(.horizontal, Theme.Space.screenMargin)
            }

            // Tier 4: provenance/diagnostics + the consistency signals that
            // aren't currently firing a warning — audit trail, not content
            // (Plan T). Collapsed by default but visible/discoverable.
            DetailDisclosure(label: "Measurement detail") {
                VStack(spacing: 0) {
                    if let w = metrics.shoulderWidthCm {
                        MetricRow(key: "Shoulder width", value: "\(String(format: "%.1f", w)) cm")
                    }
                    if let t = metrics.torsoAngleDeg {
                        MetricRow(key: "Torso angle", value: "\(String(format: "%.0f", t))°")
                    }
                    if let h = metrics.hipAngleDeg {
                        MetricRow(key: "Hip angle", value: "\(String(format: "%.0f", h))°")
                    }
                    MetricRow(
                        key: "Scale",
                        value: "\(String(format: "%.1f", metrics.pixelsPerCm)) px/cm"
                    )
                    if let barWidth = metrics.handlebarWidthMmUsed {
                        MetricRow(key: "Bar width", value: "\(Int(barWidth)) mm")
                    }
                    if let wheelCheck, !wheelCheck.isWarning {
                        MetricRow(key: "Wheel check", value: wheelCheck.text)
                    }
                    MetricRow(key: "Foreground pixels", value: "\(metrics.foregroundPixelCount)")
                    MetricRow(
                        key: "Computed",
                        value: metrics.computedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
            .padding(.horizontal, Theme.Space.screenMargin)
        }
    }
}
