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
    @Query(sort: \Bike.createdAt, order: .forward) private var allBikes: [Bike]
    #if canImport(UIKit)
    @State private var headOnImage: UIImage?
    @State private var sideOnImage: UIImage?
    @State private var maskOverlay: UIImage?
    @State private var sideOnMaskOverlay: UIImage?
    #endif
    // Bike coverage diagnostic (Plan Z4) — subject-minus-person pixel share
    // of the subject mask, as a fraction; nil when there's no subject mask
    // (old positions) to measure.
    @State private var bikeCoverageFraction: Double?
    @State private var showingSideOn = false
    @State private var showingWrongBikeSheet = false
    // Remembered per photo side for the session (Plan O5) — not persisted,
    // so a revisit always starts back on PHOTO like it does today.
    @State private var frontalPhotoSegment: PhotoSegment = .photo
    @State private var sideOnPhotoSegment: PhotoSegment = .photo
    @State private var showDeleteConfirm = false
    // AB11: gates the swipe-to-cycle gesture below — a pinch-zoomed pan must
    // never also be read as a tab swipe. Reset per photo via `.id(showingSideOn)`
    // resetting the whole pinch-zoom modifier, same as zoom itself.
    @State private var isPhotoZoomed = false
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
                            // Plan Z6 + Z7: matte → dimensions → skeleton
                            // (skeleton topmost), with a scripted BONES
                            // draw-on that replays every time the segment
                            // becomes .bones.
                            if !showingSideOn {
                                BonesDrawOnOverlay(
                                    maskOverlay: maskOverlay,
                                    skeleton: frontalSkeletonOverlay,
                                    dimensions: frontalDimensions,
                                    spannedDimensions: [],
                                    aspectRatio: headOnAspectRatio,
                                    segment: frontalPhotoSegment
                                )
                            }
                            if showingSideOn {
                                BonesDrawOnOverlay(
                                    maskOverlay: sideOnMaskOverlay,
                                    skeleton: sideOnSkeletonOverlay,
                                    dimensions: sideOnDimensions,
                                    spannedDimensions: sideOnSpannedDimensions,
                                    aspectRatio: sideOnAspectRatio,
                                    segment: sideOnPhotoSegment
                                )
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
                        .pinchZoomable(onZoomChanged: { isPhotoZoomed = $0 })
                        // AB11: swipe the photo itself to cycle PHOTO/MASK/BONES —
                        // `.simultaneousGesture` so it never steals the enclosing
                        // ScrollView's vertical drag (only `.onEnded` acts, and only
                        // once the drag is clearly horizontal); the `isPhotoZoomed`
                        // guard is what keeps a zoomed pan from also being read as a
                        // tab swipe.
                        .simultaneousGesture(photoSwipeGesture)
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
                            MetricsSection(metrics: metrics, bikeCoverageFraction: bikeCoverageFraction)
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

                        // Explicit and discoverable (Kah's stated
                        // preference) — a ghost-link row, not buried in a
                        // menu, same visual weight as HowItWorksLink (Plan
                        // Y2). Only shown when there's actually another bike
                        // to swap to.
                        if BikeSwap.isAvailable(otherBikesCount: otherBikes.count) {
                            HeaderLink("WRONG BIKE?") { showingWrongBikeSheet = true }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal, Theme.Space.screenMargin)
                                .padding(.vertical, Theme.Space.md)
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
                        Text("Same kit, same helmet, same bar position: clothing changes your silhouette as much as a small bag does.")
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
        .sheet(isPresented: $showingWrongBikeSheet) {
            WrongBikeSheet(
                position: position,
                otherBikes: otherBikes,
                imageAspect: CGSize(width: headOnAspectRatio, height: 1)
            )
        }
    }

    private var otherBikes: [Bike] {
        BikeSwap.otherBikes(allBikes: allBikes, excluding: position.bike)
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

    /// AB11: one gesture, one meaning — cycles whichever toggle bar is
    /// currently showing (frontal or side-on), through only its own
    /// available segments. `minimumDistance: 24` keeps an ordinary vertical
    /// scroll from ever registering as a swipe attempt in the first place;
    /// the horizontal-dominance + distance checks in `onEnded` are the
    /// second gate. No wraparound: `frontalPhotoSegmentBinding`/
    /// `sideOnPhotoSegmentBinding` already no-op on an out-of-range index.
    private var photoSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard !isPhotoZoomed else { return }
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 50, abs(horizontal) > abs(vertical) * 1.5 else { return }
                let delta = horizontal < 0 ? 1 : -1
                if showingSideOn {
                    let binding = sideOnPhotoSegmentBinding
                    binding.wrappedValue = binding.wrappedValue + delta
                } else {
                    let binding = frontalPhotoSegmentBinding
                    binding.wrappedValue = binding.wrappedValue + delta
                }
            }
    }

    /// No draw-on here (Plan O5) — `SkeletonOverlay.progress` defaults to 1
    /// (fully drawn); `.skeletonReveal` gives the BONES toggle its
    /// Motion.fast opacity fade instead.
    private var frontalSkeletonOverlay: SkeletonOverlay? {
        guard let shoulders = position.metrics?.headOnSkeletonPoints else { return nil }
        return SkeletonOverlay.frontal(
            shoulders: shoulders,
            arms: position.metrics?.headOnArmPoints,
            hips: position.metrics?.headOnHipPoints,
            knees: position.metrics?.headOnKneePoints
        )
    }

    private var sideOnSkeletonOverlay: SkeletonOverlay? {
        guard let points = position.metrics?.sideOnSkeletonPoints else { return nil }
        return SkeletonOverlay.sideOn(
            points: points,
            arm: position.metrics?.sideOnArmPoints,
            ankle: position.metrics?.sideOnAnklePoint
        )
    }

    /// The measured hard points, drawn (Plan X): bar width + wheel diameter
    /// on the frontal photo, degrading independently — a position missing
    /// the wheel check (or captured before Plan K) just omits that one
    /// dimension rather than hiding both. Wheel diameter reuses
    /// `Bike.wheelDiameterMm`'s derivation (same one the wheel check itself
    /// uses) rather than re-deriving it here.
    private var frontalDimensions: [DimensionOverlay.Dimension] {
        [
            DimensionOverlay.dimension(unitPoints: position.handlebarTapPoints, mm: position.metrics?.handlebarWidthMmUsed, style: .beside),
            DimensionOverlay.dimension(unitPoints: position.wheelTapPoints, mm: position.bike?.wheelDiameterMm),
        ].compactMap { $0 }
    }

    /// Wheelbase, drawn over the side-on photo — nil unless the rider used
    /// the wheelbase ruler (sideOnTapPoints) and the bike has a wheelbase on
    /// record.
    private var sideOnDimensions: [DimensionOverlay.Dimension] {
        [DimensionOverlay.dimension(unitPoints: position.sideOnTapPoints, mm: position.bike?.wheelbaseMm, style: .beside)].compactMap { $0 }
    }

    /// Wheel-height dimensions on both side-on wheels (Plan Z5) — degrades
    /// unless a real wheelbase ruler was used (`sideOnPixelsPerCm != nil`,
    /// the same gate `headDropCm` uses — spec §3), the bike has a wheel
    /// diameter on record, and the axle taps are present. `sideOnTapPoints`
    /// is `[frontX, frontY, rearX, rearY]` (Position's own storage
    /// convention — front axle, rear axle). Both wheels share the bike's
    /// one spec diameter; only which axle and which outward side differ.
    private var sideOnSpannedDimensions: [DimensionOverlay.SpannedDimension] {
        guard position.metrics?.sideOnPixelsPerCm != nil,
              let wheelDiameterMm = position.bike?.wheelDiameterMm,
              let wheelbaseMm = position.bike?.wheelbaseMm,
              let taps = position.sideOnTapPoints, taps.count == 4
        else { return [] }
        let front = CGPoint(x: taps[0], y: taps[1])
        let rear = CGPoint(x: taps[2], y: taps[3])
        let spanUnitY = AnalysisMath.wheelSpanUnitY(
            axleFront: front, axleRear: rear,
            imageAspect: Double(sideOnAspectRatio), wheelbaseMm: wheelbaseMm, wheelDiameterMm: wheelDiameterMm
        )
        guard spanUnitY > 0 else { return [] }
        return [
            DimensionOverlay.SpannedDimension(
                axleUnit: front, spanUnitY: spanUnitY,
                outward: DimensionGeometry.outwardSide(thisAxleX: front.x, otherAxleX: rear.x),
                valueMm: wheelDiameterMm
            ),
            DimensionOverlay.SpannedDimension(
                axleUnit: rear, spanUnitY: spanUnitY,
                outward: DimensionGeometry.outwardSide(thisAxleX: rear.x, otherAxleX: front.x),
                valueMm: wheelDiameterMm
            ),
        ]
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
        let subjectMaskData = position.subjectMaskData
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

        async let maskTask = buildMaskOverlay(maskData: maskData, subjectMaskData: subjectMaskData, photo: decodedHeadOn)
        async let sideOnMaskTask = buildMaskOverlay(maskData: sideOnMaskData, photo: decodedSideOn)
        async let coverageTask = Self.bikeCoverageFraction(subjectMaskData: subjectMaskData, personMaskData: maskData)
        let (overlay, sideOnOverlay, coverage) = await (maskTask, sideOnMaskTask, coverageTask)
        withAnimation(Theme.Motion.entrance()) {
            maskOverlay = overlay
            sideOnMaskOverlay = sideOnOverlay
        }
        bikeCoverageFraction = coverage
    }

    /// Off-main pixel arithmetic (Plan Z4) — pure mask-vs-mask comparison,
    /// no photo decode needed at all. `static` (unlike `buildMaskOverlay`)
    /// since it touches no view state on its way in.
    private static func bikeCoverageFraction(subjectMaskData: Data?, personMaskData: Data?) async -> Double? {
        guard let subjectMaskData else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> Double? in
            guard let subjectMask = UIImage(data: subjectMaskData)?.cgImage else { return nil }
            let personMask = personMaskData.flatMap { UIImage(data: $0)?.cgImage }
            return MatteRenderer.bikeCoverageFraction(subjectMask: subjectMask, personMask: personMask)
        }.value
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
    /// rider. `subjectMaskData` (Plan W2, frontal only) is preferred when
    /// present and its aspect matches the photo — one acid tint over the
    /// whole subject (Plan AG retired the rider/bike two-tone: the bike
    /// colour was an absence, subject minus person, so every person-mask
    /// flaw rendered as a wrong colour somewhere); nil (old positions, or
    /// side-on which has no subject mask at all) renders the same single
    /// tone from the person mask exactly as before.
    private func buildMaskOverlay(maskData: Data?, subjectMaskData: Data? = nil, photo: UIImage?) async -> UIImage? {
        guard let cgPhoto = photo?.cgImage else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
            if let subjectMaskData, let subjectMask = UIImage(data: subjectMaskData)?.cgImage,
               AnalysisMath.maskMatchesSourceAspect(
                   maskWidth: subjectMask.width, maskHeight: subjectMask.height,
                   sourceWidth: cgPhoto.width, sourceHeight: cgPhoto.height
               ) {
                return MatteRenderer.tintedOverlay(mask: subjectMask, color: UIColor(Theme.Palette.acc), alpha: 0.5)
            }
            guard let maskData, let mask = UIImage(data: maskData), let cgMask = mask.cgImage else { return nil }
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

// MARK: - BONES draw-on (Plan Z6 + Z7)

/// Replaces the mask/skeleton/dimension trio for one photo side (frontal or
/// side-on): the matte shows for MASK and BONES alike (a plain crossfade
/// for MASK, unchanged), but only BONES gets the skeleton + dimensions —
/// and only BONES gets a scripted draw-on: a matte wipe-in, the skeleton
/// drawing from the top, then the dimensions growing tap→tap with their box
/// popping on completion. Replayed every time `segment` becomes `.bones`
/// (Plan O5's "no draw-on on the detail screen" rule is deliberately
/// reversed here, per Kah's 2026-07-18 direction) — under ~0.5s total and
/// interruptible: switching to PHOTO/MASK mid-draw snaps everything to its
/// finished state instead of leaving a half-drawn skeleton frozen, so rapid
/// toggling never stacks or drags (an every-tap animation, unlike
/// CaptureView's one-time 0.9s reveal sweep, which this deliberately does
/// NOT reuse). Reduce Motion collapses the draw-on to today's instant fade
/// (each sub-view already clamps its own progress to 1 in that case).
///
/// Z-order (Plan Z6): matte → dimensions → skeleton, skeleton topmost.
private struct BonesDrawOnOverlay: View {
    let maskOverlay: UIImage?
    let skeleton: SkeletonOverlay?
    let dimensions: [DimensionOverlay.Dimension]
    let spannedDimensions: [DimensionOverlay.SpannedDimension]
    let aspectRatio: CGFloat
    let segment: PhotoSegment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var matteProgress: Double = 1
    @State private var skeletonProgress: Double = 1
    @State private var dimensionProgress: Double = 1
    @State private var cancelled = false

    private var isBones: Bool { segment == .bones }
    private var hasDimensions: Bool { !dimensions.isEmpty || !spannedDimensions.isEmpty }

    /// The skeleton with this instance's own draw-on progress baked in —
    /// mirrors `RevealStep.frontalSkeletonOverlay`'s pattern (mutate a copy,
    /// never the stored original).
    private var animatedSkeleton: SkeletonOverlay? {
        guard var overlay = skeleton else { return nil }
        overlay.progress = reduceMotion ? 1 : skeletonProgress
        return overlay
    }

    var body: some View {
        ZStack {
            if let maskOverlay {
                Image(uiImage: maskOverlay)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
                    .opacity(segment == .photo ? 0 : 1)
                    .scanReveal(progress: isBones ? (reduceMotion ? 1 : matteProgress) : 1)
            }
            if hasDimensions {
                DimensionOverlay(
                    dimensions: dimensions,
                    progress: reduceMotion ? 1 : dimensionProgress,
                    spannedDimensions: spannedDimensions
                )
                .aspectRatio(aspectRatio, contentMode: .fit)
                .opacity(isBones ? 1 : 0)
                .animation(Theme.Motion.entrance(Theme.Motion.fast), value: isBones)
            }
            if let animatedSkeleton {
                animatedSkeleton
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .opacity(isBones ? 1 : 0)
                    .animation(Theme.Motion.entrance(Theme.Motion.fast), value: isBones)
            }
        }
        .onChange(of: segment) { _, newValue in
            if newValue == .bones {
                beginDrawOn()
            } else {
                cancelDrawOn()
            }
        }
        .onAppear {
            if isBones { beginDrawOn() }
        }
    }

    /// Matte wipe and skeleton draw start together; the dimensions only
    /// start growing once the skeleton's own draw-in completes, so the box
    /// reads as *caused by* the skeleton finishing (the same causality beat
    /// X3 built for the reveal) — kept brief (`Motion.fast`, not `.base`)
    /// specifically to hold the whole sequence under ~0.5s even when the
    /// skeleton's own cascade runs close to its Plan V2 cap of 3 windows
    /// (~0.35s).
    ///
    /// This fires from `.onChange(of: segment)`, which runs inside whatever
    /// ambient transaction the segment toggle itself used (`Theme.Motion
    /// .travel(Theme.Motion.base)`, from `frontalPhotoSegmentBinding`) — the
    /// reset-to-0 below runs inside `withoutAnimation` so it's a true reset,
    /// not a brief visible "un-draw" borrowing that ambient animation.
    private func beginDrawOn() {
        cancelled = false
        guard !reduceMotion else {
            snapToDone()
            return
        }
        withoutAnimation {
            matteProgress = 0
            skeletonProgress = 0
            dimensionProgress = 0
        }
        withAnimation(Theme.Motion.travel(Theme.Motion.base)) {
            matteProgress = 1
        }
        if let skeleton {
            withAnimation(Theme.Motion.travel(skeleton.totalDrawDuration)) {
                skeletonProgress = 1
            } completion: {
                startDimensionDrawOn()
            }
        } else {
            startDimensionDrawOn()
        }
    }

    private func startDimensionDrawOn() {
        guard !cancelled else { return }
        guard hasDimensions else {
            dimensionProgress = 1
            return
        }
        withAnimation(Theme.Motion.travel(Theme.Motion.fast)) {
            dimensionProgress = 1
        }
    }

    private func snapToDone() {
        matteProgress = 1
        skeletonProgress = 1
        dimensionProgress = 1
    }

    /// Snaps every progress straight to "done" — no animation, even though
    /// this too runs inside the segment toggle's ambient transaction — so a
    /// mid-draw PHOTO/MASK tap never leaves a half-drawn skeleton frozen
    /// mid-crossfade, and a stale `startDimensionDrawOn` completion arriving
    /// after this can't restart anything (`cancelled` gates it).
    private func cancelDrawOn() {
        guard !cancelled else { return }
        cancelled = true
        withoutAnimation { snapToDone() }
    }

    private func withoutAnimation(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }
}

// MARK: - Metrics section

private struct MetricsSection: View {
    let metrics: PositionMetrics
    // Subject-minus-person pixel share of the subject mask (Plan Z4) — nil
    // (displays "—") when there's no subject mask, e.g. positions captured
    // before Plan W2.
    let bikeCoverageFraction: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heroVisible = false

    /// nil when the optional wheel check was never done; otherwise the same
    /// text/warning pair PositionDetailView and ComparisonView have always
    /// shared (Plan I4) — Plan T just changes where a warning displays it.
    private var wheelCheck: (text: String, isWarning: Bool)? {
        metrics.wheelCheckDisagreementFraction.map(AnalysisMath.wheelCheckDisplay)
    }

    /// The direction-aware warning sentence (Plan Z3) — nil when the check
    /// passes or was never done.
    private var wheelCheckWarning: String? {
        metrics.wheelCheckDisagreementFraction.flatMap(AnalysisMath.wheelCheckWarning)
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
                if let wheelCheckWarning {
                    Text(wheelCheckWarning)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.Palette.amb)
                        .padding(.top, Theme.Space.xs)
                }
            }
            .padding(.horizontal, Theme.Space.screenMargin)
            .padding(.top, Theme.Space.lg)
            .padding(.bottom, Theme.Space.md)

            SectionDivider()

            // AB12: the solo "so what" — cost, not impact (spec §3: a lone
            // position has no baseline to diff against, so this is a bare
            // watts figure, never a fake time-over-distance delta).
            SoloEffortRow(areaCm2: metrics.frontalAreaCm2)

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
                    // Diagnostic, not a standing metric (Plan Z4): always
                    // present, "—" when there's no subject mask, so a
                    // near-zero reading on a night shot is legible as "the
                    // lift found no bike" rather than a hidden failure.
                    MetricRow(key: "Bike coverage", value: AnalysisMath.bikeCoverageDisplay(bikeCoverageFraction))
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

// MARK: - Solo effort row (Plan AB12)

/// Standalone watts, not a delta — a lone position has no reference to diff
/// against (spec §3 forbids inventing one), so this states the *cost* of
/// this position's own frontal area at the rider's chosen flat-road speed
/// instead. Shares its `@AppStorage` keys with `ComparisonView`'s
/// `TimeImpactSection` (same speed, same "confirmed vs assumed" framing) so
/// a speed committed on either screen updates both.
private struct SoloEffortRow: View {
    let areaCm2: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Read persisted only to seed the live @State on appear (so the chip and
    // watts reflect a speed committed on Compare); SpeedControl owns writing
    // it back.
    @AppStorage("effortSpeedKmh") private var persistedSpeedKmh: Double = 30
    @AppStorage("effortInputsConfirmed") private var inputsConfirmed = false
    // Live value bound to SpeedControl below — drives both the chip and the
    // watts figure so they update as the slider drags, not just on commit.
    @State private var speedKmh: Double = 30
    // The speed control (a shared value with Compare) is set on the Compare
    // screen too; this chip surfaces it here so the number isn't a dead end
    // (Plan AC3). Collapsed by default.
    @State private var editing = false

    private var watts: Int {
        let speedMS = speedKmh / 3.6
        let cda = EffortModel.assumedCd * areaCm2 / 10_000
        let power = EffortModel.impliedPowerW(speedMS: speedMS, cdaM2: cda, massKg: EffortModel.assumedMassKg)
        return EffortModel.roundedWatts5(power)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack(spacing: Theme.Space.sm) {
                    Text("Holding")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.Palette.fg2)
                    speedChip
                    Text("takes ~\(watts) W")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.Palette.fg2)
                    Spacer(minLength: 0)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minHeight: Theme.Control.metricRowHeight, alignment: .leading)

                if !inputsConfirmed {
                    Text("Assumed — tap the speed to set yours.")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.Palette.fg3)
                }

                if editing {
                    // Same speed control as Compare's TIME IMPACT (typed
                    // field + wide slider), writing the shared value; a commit
                    // on either flips inputsConfirmed, dropping "assumed" here
                    // and on Compare. Label hidden — the chip above already
                    // names it.
                    SpeedControl(speedKmh: $speedKmh, showLabel: false)
                        .padding(.top, Theme.Space.xs)
                }
            }
            .padding(.horizontal, Theme.Space.screenMargin)
            .padding(.bottom, editing ? Theme.Space.sm : 0)
            .onAppear { speedKmh = persistedSpeedKmh }

            Rectangle()
                .fill(Theme.Palette.line2)
                .frame(height: Theme.Control.hairline)
        }
    }

    private var speedChip: some View {
        Button {
            if reduceMotion { editing.toggle() }
            else { withAnimation(Theme.Motion.interactive()) { editing.toggle() } }
        } label: {
            HStack(spacing: 4) {
                Text("\(Int(speedKmh)) km/h")
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundStyle(Theme.Palette.acc)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.Palette.acc)
                    .rotationEffect(.degrees(editing ? 180 : 0))
            }
            .padding(.horizontal, Theme.Space.sm)
            .padding(.vertical, 6)
            .overlay(Rectangle().stroke(Theme.Palette.acc, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
