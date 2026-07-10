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
    #endif
    @State private var showingSideOn = false
    @State private var showingMask = false
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
                                    .opacity(showingMask ? 1 : 0)
                            }
                        }
                        .aspectRatio(showingSideOn ? sideOnAspectRatio : headOnAspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        // MASK toggle only makes sense on the frontal photo — that's
                        // the one the stored mask was computed from. Fades in
                        // (rather than popping the layout) once the overlay is
                        // ready — see loadPhotos().
                        if !showingSideOn, maskOverlay != nil {
                            SegmentedToggleBar(labels: ["PHOTO", "MASK"], selectedIndex: maskSegmentBinding)
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

    private var maskSegmentBinding: Binding<Int> {
        Binding(
            get: { showingMask ? 1 : 0 },
            set: { newIndex in
                withAnimation(Theme.Motion.travel(Theme.Motion.base)) {
                    showingMask = newIndex == 1
                }
            }
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

        let overlay = await buildMaskOverlay(maskData: maskData, headOnPhoto: decodedHeadOn)
        withAnimation(Theme.Motion.entrance()) {
            maskOverlay = overlay
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

    /// Builds the PHOTO/MASK overlay off-main (N5) — pure pixel work with no
    /// main-actor requirement. Skips silently — no toggle offered — when
    /// there's no stored mask or when the mask and photo disagree on aspect
    /// ratio (Plan I5): a mismatched composite would tint the wrong region
    /// rather than hug the rider.
    private func buildMaskOverlay(maskData: Data?, headOnPhoto: UIImage?) async -> UIImage? {
        guard let maskData, let cgPhoto = headOnPhoto?.cgImage else { return nil }
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

                if let shoulder = metrics.shoulderWidthCm,
                   let warning = AnalysisMath.shoulderWidthWarning(shoulder) {
                    Text(warning)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.Palette.amb)
                        .padding(.top, Theme.Space.xs)
                }
            }
            .padding(.horizontal, Theme.Space.screenMargin)
            .padding(.top, Theme.Space.lg)
            .padding(.bottom, Theme.Space.md)

            SectionDivider()

            Group {
                if let w = metrics.shoulderWidthCm {
                    MetricRow(key: "Shoulder width", value: "\(String(format: "%.1f", w)) cm")
                }
                if let t = metrics.torsoAngleDeg {
                    MetricRow(key: "Torso angle", value: "\(String(format: "%.0f", t))°")
                }
                if let h = metrics.hipAngleDeg {
                    MetricRow(key: "Hip angle", value: "\(String(format: "%.0f", h))°")
                }
                // Head drop hidden for now (Plan G decision 4) — see RevealStep
                // for why. Still stored on metrics.headDropCm; not shown here.
                MetricRow(
                    key: "Scale",
                    value: "\(String(format: "%.1f", metrics.pixelsPerCm)) px/cm"
                )
                if let barWidth = metrics.handlebarWidthMmUsed {
                    MetricRow(key: "Bar width", value: "\(Int(barWidth)) mm")
                }
                if let fraction = metrics.wheelCheckDisagreementFraction {
                    let check = AnalysisMath.wheelCheckDisplay(fraction)
                    MetricRow(key: "Wheel check", value: check.text,
                              valueColor: check.isWarning ? Theme.Palette.amb : Theme.Palette.fg)
                }
                MetricRow(key: "Foreground pixels", value: "\(metrics.foregroundPixelCount)")
                MetricRow(
                    key: "Computed",
                    value: metrics.computedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
            .padding(.horizontal, Theme.Space.screenMargin)
        }
    }
}
