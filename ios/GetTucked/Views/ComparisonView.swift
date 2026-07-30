import SwiftUI
import CoreGraphics

struct ComparisonView: View {
    let positionA: Position   // first selected — the reference
    let positionB: Position   // second selected
    @Binding var path: [AppScreen]

    // Panels/table cascade in quickly on appear (N6) — the delta hero below
    // is the deliberate second wow moment and manages its own timing instead.
    @State private var appeared = false
    private let cascadeStagger: Double = 0.025

    // Ghost-compare overlay (frontal only, v1) — built once, off-main, from
    // each position's already-persisted mask/taps. Either side independently
    // degrades to nil (no mask, no handlebar taps, or no usable ground
    // reference), in which case the whole section just doesn't appear —
    // never blocks the numeric comparison above/below it.
    @State private var overlayLayerA: GhostCompareLayer?
    @State private var overlayLayerB: GhostCompareLayer?
    // Bike coverage diagnostic (Plan Z4) — subject-minus-person pixel share
    // of the subject mask, per side; nil when that position has no subject
    // mask (old positions).
    @State private var bikeCoverageA: Double?
    @State private var bikeCoverageB: Double?
    // Collapses the reserved overlay section in the rare case the async
    // build fails despite `overlaySectionExpected` passing.
    @State private var overlayBuildFailed = false
    @State private var showOutline = true
    // Independent per-position visibility — lets you isolate one silhouette
    // at a time rather than always looking at both overlaid.
    @State private var showLayerA = true
    @State private var showLayerB = true
    // AE3: OUTLINE-only underlay, off by default (today's look) — dims each
    // visible layer's photo in behind its own outline, so it follows that
    // layer's own A/B chip rather than getting a chip of its own to hide.
    @State private var showPhotoUnderlay = false

    // R1: the outline draw-in ceremony. A then B, staggered ~0.2s apart
    // (Plan AI5 — tightened from 0.35s); plays once per screen visit
    // (toggling PHOTO/OUTLINE or A/B never replays it — that's inspection,
    // not ceremony, same rule Plan P set for the capture ghost).
    // `layerXArmed` is completion-driven (not derived from progress==1,
    // which updates instantly under withAnimation) — Plan AI5 dropped it as
    // a gate on the A/B chips (they now read `showLayerX` directly so
    // they're correct from frame one), kept here for any future consumer
    // that genuinely needs "the draw has finished" rather than "the layer
    // is toggled on".
    @State private var drawInProgressA: Double = 0
    @State private var drawInProgressB: Double = 0
    @State private var layerAArmed = false
    @State private var layerBArmed = false
    @State private var hasPlayedDrawIn = false
    @State private var drawInCancelled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var metricsA: PositionMetrics? { positionA.metrics }
    private var metricsB: PositionMetrics? { positionB.metrics }

    private var areaA: Double? { metricsA?.frontalAreaCm2 }
    private var areaB: Double? { metricsB?.frontalAreaCm2 }
    private var uncertaintyA: Double? { metricsA?.frontalAreaUncertainty }
    private var uncertaintyB: Double? { metricsB?.frontalAreaUncertainty }

    // % change from A to B (positive = B is larger)
    private var deltaPct: Double? {
        guard let a = areaA, let b = areaB, a > 0 else { return nil }
        return ((b - a) / a) * 100
    }

    // A delta smaller than the combined measurement noise can't be told apart
    // from jitter (Plan A4) — default to "distinguishable" when uncertainty
    // isn't available rather than silently hiding a real delta.
    private var isDistinguishable: Bool {
        guard let a = areaA, let b = areaB, let uA = uncertaintyA, let uB = uncertaintyB else { return true }
        return AnalysisMath.isDistinguishable(areaA: a, areaB: b, uncertaintyA: uA, uncertaintyB: uB)
    }

    private var noisePct: Double {
        guard let a = areaA, a > 0, let uA = uncertaintyA, let uB = uncertaintyB else { return 0 }
        return AnalysisMath.combinedNoiseCm2(uncertaintyA: uA, uncertaintyB: uB) / a * 100
    }

    private var isCrossBike: Bool {
        positionA.bike?.id != positionB.bike?.id
    }

    // MARK: - Pose delta (Plan P1.3) — is this even the same position?

    private func shoulderTiltDeg(from points: [Double]?) -> Double? {
        guard let points, points.count == 4 else { return nil }
        return AnalysisMath.shoulderTiltDeg(
            leftShoulder: CGPoint(x: points[0], y: points[1]),
            rightShoulder: CGPoint(x: points[2], y: points[3])
        )
    }

    private var poseDeltaWarning: (text: String, severity: AnalysisMath.PoseDeltaSeverity)? {
        let delta = AnalysisMath.poseAngleDelta(
            shoulderTiltDegA: shoulderTiltDeg(from: metricsA?.headOnSkeletonPoints),
            shoulderTiltDegB: shoulderTiltDeg(from: metricsB?.headOnSkeletonPoints),
            torsoAngleDegA: metricsA?.torsoAngleDeg, torsoAngleDegB: metricsB?.torsoAngleDeg,
            hipAngleDegA: metricsA?.hipAngleDeg, hipAngleDegB: metricsB?.hipAngleDeg
        )
        guard let delta else { return nil }
        return AnalysisMath.poseDeltaWarning(angleDeltaDeg: delta)
    }

    // MARK: - Wheel check / shoulder width advisories (Plan T tier 3)
    //
    // Both signals are per-side and independent of each other and of
    // deltaPct — a failing wheel check or an implausible shoulder width on
    // either position is worth flagging even if the area delta itself
    // can't be shown. Un-warned values still render as rows in the
    // measurement-detail disclosure (ComparisonMeasurementDetail).

    private func wheelCheckAdvisory(_ metrics: PositionMetrics?) -> String? {
        guard let fraction = metrics?.wheelCheckDisagreementFraction else { return nil }
        return AnalysisMath.wheelCheckWarning(fraction)
    }

    private func shoulderWidthAdvisory(_ metrics: PositionMetrics?) -> String? {
        guard let cm = metrics?.shoulderWidthCm else { return nil }
        return AnalysisMath.shoulderWidthWarning(cm)
    }

    // Plan AI3: identical A/B advisories (the common case — the same taps
    // usually mis-measure the same way on both sides) collapse into one "A
    // and B: …" line via AnalysisMath.mergedAdvisories instead of printing
    // the same sentence twice.
    private var advisoryLines: [String] {
        let sided: [(side: String, text: String)] = [
            shoulderWidthAdvisory(metricsA).map { (side: "A", text: $0) },
            shoulderWidthAdvisory(metricsB).map { (side: "B", text: $0) },
            wheelCheckAdvisory(metricsA).map { (side: "A", text: $0) },
            wheelCheckAdvisory(metricsB).map { (side: "B", text: $0) },
        ].compactMap { $0 }
        return AnalysisMath.mergedAdvisories(sided)
    }

    private var hasAnyAdvisory: Bool {
        isCrossBike || poseDeltaWarning != nil || !advisoryLines.isEmpty
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "COMPARE")
                SectionDivider()

                ScrollView {
                    VStack(spacing: 0) {
                        // 2-up panels
                        HStack(spacing: 0) {
                            PositionPanel(position: positionA, side: "A")
                            Rectangle().fill(Theme.Palette.line).frame(width: 1)
                            PositionPanel(position: positionB, side: "B")
                        }
                        .frame(minHeight: 130)
                        .cascadeIn(index: 0, trigger: appeared, duration: Theme.Motion.base, stagger: cascadeStagger)

                        SectionDivider()

                        // Ghost-compare overlay (frontal only) — the visual
                        // complement to the numbers below. The section's
                        // chrome and height are reserved *immediately* when a
                        // cheap sync precondition says layers will build
                        // (both positions have a mask + bar taps) — the async
                        // build then lands its content inside a box that
                        // already exists, so nothing below ever shifts and
                        // the draw-in ceremony is the arrival, not a late
                        // pop-in of the whole block. Collapses only in the
                        // rare case the build actually fails.
                        if overlaySectionExpected && !overlayBuildFailed {
                            SegmentedToggleBar(labels: ["PHOTO", "OUTLINE"], selectedIndex: showOutlineBinding)
                            Group {
                                if let overlayLayerA, let overlayLayerB {
                                    GhostCompareOverlay(
                                        layerA: overlayLayerA, layerB: overlayLayerB, showOutline: showOutline,
                                        showLayerA: showLayerA, showLayerB: showLayerB,
                                        showPhotoUnderlay: showPhotoUnderlay,
                                        drawInProgressA: reduceMotion ? 1 : drawInProgressA,
                                        drawInProgressB: reduceMotion ? 1 : drawInProgressB,
                                        onGestureBegan: cancelDrawInIfNeeded,
                                        onSwipeCycle: cycleOutlineSegment
                                    )
                                    // Decorative silhouette comparison — the numeric
                                    // delta above/below already states the comparison;
                                    // this graphic has no content a VoiceOver user can
                                    // act on (Plan AK9). The toggle chips overlaid on
                                    // top stay accessible: this only hides the layer
                                    // it's attached to, not the sibling overlay content.
                                    .accessibilityHidden(true)
                                    .overlay(alignment: .topTrailing) {
                                        // Row is trailing-anchored (.overlay(alignment: .topTrailing)
                                        // below) with A/B as the last two children — the PHOTO
                                        // chip leads the row, so appearing/disappearing only grows
                                        // or shrinks the row from its leading edge and never moves
                                        // A/B, which stay pinned to the trailing edge either way.
                                        HStack(spacing: Theme.Space.xs) {
                                            // AE3: only meaningful on the OUTLINE tab — PHOTO tab
                                            // already shows the photo as the primary content.
                                            if showOutline {
                                                LayerToggleChip(
                                                    label: "PHOTO", color: Theme.Palette.fg2,
                                                    isOn: showPhotoUnderlay, width: 54
                                                ) {
                                                    cancelDrawInIfNeeded()
                                                    withAnimation(reduceMotion ? nil : Theme.Motion.entrance()) {
                                                        showPhotoUnderlay.toggle()
                                                    }
                                                }
                                            }
                                            LayerToggleChip(label: "A", color: Theme.Palette.acc, isOn: showLayerA) {
                                                cancelDrawInIfNeeded()
                                                showLayerA.toggle()
                                            }
                                            LayerToggleChip(label: "B", color: Theme.Palette.amb, isOn: showLayerB) {
                                                cancelDrawInIfNeeded()
                                                showLayerB.toggle()
                                            }
                                        }
                                        .padding(Theme.Space.sm)
                                    }
                                } else {
                                    // Same quiet placeholder PositionDetailView
                                    // uses while a photo decodes.
                                    ZStack {
                                        Theme.Palette.bg1
                                        Text("···")
                                            .font(Theme.mono(20))
                                            .foregroundStyle(Theme.Palette.fg4)
                                    }
                                }
                            }
                            .frame(height: 300)
                            SectionDivider()
                        }

                        // Tier 1 (Plan S2): the "so what" moment — only
                        // offered when there's an area to compare at all.
                        if let areaA, let areaB {
                            TimeImpactSection(areaA: areaA, areaB: areaB, isDistinguishable: isDistinguishable)
                            SectionDivider()
                        }

                        // Delta hero (tier 2) — the deliberate secondary wow
                        // moment; manages its own roll/fade timing, not the cascade.
                        if let delta = deltaPct, let a = areaA, let b = areaB {
                            DeltaHero(delta: delta, winner: a < b ? "A" : "B", absoluteDeltaCm2: abs(b - a),
                                      isDistinguishable: isDistinguishable, noisePct: noisePct)
                        }

                        // Tier 3 (Plan T): every advisory in one place,
                        // exception-based — none of this is a standing
                        // number, it's a reason to look twice. Independent
                        // of the delta hero above (cross-bike, in
                        // particular, is meaningful even with no metrics on
                        // either side yet).
                        if hasAnyAdvisory {
                            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                                if isCrossBike {
                                    CrossBikeWarning()
                                }
                                if let poseDeltaWarning {
                                    PoseDeltaAdvisory(warning: poseDeltaWarning)
                                    PoseEvidenceRows(metricsA: metricsA, metricsB: metricsB)
                                }
                                ForEach(advisoryLines, id: \.self) { line in
                                    AdvisoryLine(text: line)
                                }
                            }
                            .padding(.bottom, Theme.Space.sm)
                        }

                        // One divider closing out tiers 2+3, whichever of
                        // them actually rendered anything — mirrors the
                        // original guarantee that the table never abuts the
                        // delta hero without a line between them.
                        if deltaPct != nil || hasAnyAdvisory {
                            SectionDivider()
                        }

                        // Metric diff table (tier 4) — reduced to standing
                        // rows only; everything else moved to the
                        // measurement-detail disclosure below (tier 5).
                        DiffTable(metricsA: metricsA, metricsB: metricsB, appeared: appeared, cascadeStagger: cascadeStagger)

                        DetailDisclosure(label: "Measurement detail") {
                            ComparisonMeasurementDetail(
                                metricsA: metricsA, metricsB: metricsB,
                                includePoseRows: poseDeltaWarning == nil,
                                bikeCoverageA: bikeCoverageA, bikeCoverageB: bikeCoverageB
                            )
                        }
                        .padding(.horizontal, Theme.Space.screenMargin)
                        .padding(.vertical, Theme.Space.md)

                        HowItWorksLink(path: $path)
                            .padding(.horizontal, Theme.Space.screenMargin)
                            .padding(.vertical, Theme.Space.lg)
                    }
                }
            }
        }
        .hideNavBar()
        .onAppear { appeared = true }
        .task { await loadOverlayLayers() }
    }

    /// Sync mirror of `buildGhostCompareLayer`'s own guard — cheap enough to
    /// answer on the first frame, so the section's space can be reserved
    /// before the async build finishes.
    private var overlaySectionExpected: Bool {
        (positionA.subjectMaskData ?? positionA.maskData) != nil && positionA.metrics != nil && positionA.handlebarTapPoints?.count == 4
            && (positionB.subjectMaskData ?? positionB.maskData) != nil && positionB.metrics != nil && positionB.handlebarTapPoints?.count == 4
    }

    private var showOutlineBinding: Binding<Int> {
        Binding(
            get: { showOutline ? 1 : 0 },
            set: { newValue in
                cancelDrawInIfNeeded()
                showOutline = newValue == 1
            }
        )
    }

    /// AB11: routes the overlay's swipe gesture through the same binding the
    /// PHOTO/OUTLINE toggle uses (so `cancelDrawInIfNeeded` fires identically
    /// either way) — no wraparound: an out-of-range index is simply dropped.
    private func cycleOutlineSegment(delta: Int) {
        let newIndex = showOutlineBinding.wrappedValue + delta
        guard (0...1).contains(newIndex) else { return }
        showOutlineBinding.wrappedValue = newIndex
    }

    /// Off-main, once — mirrors the pattern `CaptureView.buildGhosts()` uses
    /// for Plan P2's ghost: read the SwiftData-backed values on the main
    /// actor first (models aren't safe to touch off it), then hand only
    /// plain values into the detached work.
    private func loadOverlayLayers() async {
        // Traces whichever mask actually drove each position's area (Plan
        // W2 audit) — subjectMaskData once adopted, falling back to the
        // person-only maskData for positions captured before W2.
        async let a = buildGhostCompareLayer(
            maskData: positionA.subjectMaskData ?? positionA.maskData, photosData: positionA.photosData,
            frontalAreaCm2: positionA.metrics?.frontalAreaCm2,
            handlebarTapPoints: positionA.handlebarTapPoints, wheelTapPoints: positionA.wheelTapPoints,
            tintColor: UIColor(Theme.Palette.acc), strokeColor: Theme.Palette.acc
        )
        async let b = buildGhostCompareLayer(
            maskData: positionB.subjectMaskData ?? positionB.maskData, photosData: positionB.photosData,
            frontalAreaCm2: positionB.metrics?.frontalAreaCm2,
            handlebarTapPoints: positionB.handlebarTapPoints, wheelTapPoints: positionB.wheelTapPoints,
            tintColor: UIColor(Theme.Palette.amb), strokeColor: Theme.Palette.amb
        )
        async let coverageA = Self.bikeCoverageFraction(
            subjectMaskData: positionA.subjectMaskData, personMaskData: positionA.maskData
        )
        async let coverageB = Self.bikeCoverageFraction(
            subjectMaskData: positionB.subjectMaskData, personMaskData: positionB.maskData
        )
        (overlayLayerA, overlayLayerB) = await (a, b)
        (bikeCoverageA, bikeCoverageB) = await (coverageA, coverageB)
        if overlayLayerA == nil || overlayLayerB == nil {
            overlayBuildFailed = true
        }
        beginDrawInIfNeeded()
    }

    /// Off-main pixel arithmetic (Plan Z4) — pure mask-vs-mask comparison,
    /// shared shape with `PositionDetailView`'s own private copy (no common
    /// SwiftUI-view base to hang a shared helper off).
    private static func bikeCoverageFraction(subjectMaskData: Data?, personMaskData: Data?) async -> Double? {
        guard let subjectMaskData else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> Double? in
            guard let subjectMask = UIImage(data: subjectMaskData)?.cgImage else { return nil }
            let personMask = personMaskData.flatMap { UIImage(data: $0)?.cgImage }
            return MatteRenderer.bikeCoverageFraction(subjectMask: subjectMask, personMask: personMask)
        }.value
    }

    /// R1.3: A draws over `Motion.sweep`, B starts ~0.2s in (Plan AI5 —
    /// tightened from 0.35s alongside the shorter sweep) — overlapping,
    /// not sequential (§8), so the pair reads as being laid over each other
    /// rather than a slideshow. Plays once per screen visit (`hasPlayedDrawIn`).
    private func beginDrawInIfNeeded() {
        guard !hasPlayedDrawIn, overlayLayerA != nil, overlayLayerB != nil else { return }
        hasPlayedDrawIn = true
        guard !reduceMotion else {
            layerAArmed = true
            layerBArmed = true
            return
        }
        withAnimation(Theme.Motion.travel(Theme.Motion.sweep)) {
            drawInProgressA = 1
        } completion: {
            layerAArmed = true
        }
        withAnimation(Theme.Motion.travel(Theme.Motion.sweep).delay(0.2)) {
            drawInProgressB = 1
        } completion: {
            layerBArmed = true
        }
    }

    /// R1.4: the ceremony must never gate the screen — PHOTO/OUTLINE and the
    /// A/B chips stay live throughout, and using any of them mid-draw snaps
    /// straight to the settled state (RevealStep's `cancelCeremony` is the
    /// same shape). A plain assignment outside `withAnimation`, so it's an
    /// instant cut, not an animated jump.
    private func cancelDrawInIfNeeded() {
        guard !drawInCancelled else { return }
        drawInCancelled = true
        hasPlayedDrawIn = true
        drawInProgressA = 1
        drawInProgressB = 1
        layerAArmed = true
        layerBArmed = true
    }

    private func buildGhostCompareLayer(
        maskData: Data?, photosData: Data?, frontalAreaCm2: Double?,
        handlebarTapPoints: [Double]?, wheelTapPoints: [Double]?, tintColor: UIColor, strokeColor: Color
    ) async -> GhostCompareLayer? {
        guard let maskData,
              let frontalAreaCm2,
              let handlebarTapPoints, handlebarTapPoints.count == 4
        else { return nil }

        return await Task.detached(priority: .userInitiated) { () -> GhostCompareLayer? in
            // Decode inside the detached task — mask PNG decode and photo
            // JPEG decode both ran on the main actor here previously, which
            // is what made the section land late. `preparingForDisplay()`
            // forces the photo's pixel decode now, off-main, instead of
            // lazily at first render (which would hitch scrolling).
            guard let cgMask = UIImage(data: maskData)?.cgImage else { return nil }
            let photoImage = photosData.flatMap { UIImage(data: $0) }.map { $0.preparingForDisplay() ?? $0 }
            guard let data = cgMask.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
            let width = cgMask.width, height = cgMask.height, bytesPerRow = cgMask.bytesPerRow

            let foregroundCount = AnalysisMath.countForegroundPixels(
                bytes: bytes, width: width, height: height, bytesPerRow: bytesPerRow
            )
            let maskPixelsPerCm = AnalysisMath.maskPixelsPerCm(
                foregroundPixelCount: foregroundCount, areaCm2: frontalAreaCm2
            )
            guard maskPixelsPerCm > 0 else { return nil }

            // Ground reference: the wheel-check tap when present (precise),
            // else the mask's own lowest foreground pixel (always
            // available, noisier — same graceful-degrade shape as every
            // other optional ruler in this app).
            let groundUnitY: Double?
            if let wheelTapPoints, wheelTapPoints.count == 4 {
                groundUnitY = wheelTapPoints[1]
            } else {
                groundUnitY = MatteRenderer.lowestForegroundUnitY(
                    bytes: bytes, width: width, height: height, bytesPerRow: bytesPerRow
                )
            }
            guard let groundUnitY else { return nil }

            let handlebarMidUnitX = (handlebarTapPoints[0] + handlebarTapPoints[2]) / 2
            let maskSize = CGSize(width: width, height: height)
            let anchorCm = AnalysisMath.anchorCm(
                handlebarMidUnitX: handlebarMidUnitX, groundUnitY: groundUnitY,
                maskSize: maskSize, maskPixelsPerCm: maskPixelsPerCm
            )

            var outlineImage: UIImage?
            if let ring = MatteRenderer.outlineMask(mask: cgMask, strokeWidthPx: 4) {
                outlineImage = MatteRenderer.tintedOverlay(mask: ring, color: tintColor, alpha: 0.85)
            }
            let contours = MatteRenderer.contourPaths(mask: cgMask)

            return GhostCompareLayer(
                maskSize: maskSize, maskPixelsPerCm: maskPixelsPerCm, anchorCm: anchorCm,
                outlineImage: outlineImage, photoImage: photoImage, contours: contours, strokeColor: strokeColor
            )
        }.value
    }
}

// MARK: - Cross-bike warning

private struct CrossBikeWarning: View {
    var body: some View {
        Text("DIFFERENT BIKES. Differences may reflect the bikes, not the rider.")
            .font(Theme.mono(12))
            .foregroundStyle(Theme.Palette.amb)
            .padding(Theme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.bg1)
            .overlay(Rectangle().stroke(Theme.Palette.amb, lineWidth: 1))
    }
}

// MARK: - Pose delta advisory (Plan P1.3)

/// Complementary to the ±3% noise floor `DeltaHero` already renders: that
/// answers "is the area delta real?", this answers "is the position even the
/// same?" — plain text, no banner chrome (unlike `CrossBikeWarning`), same
/// quiet surfacing `shoulderWidthWarning` gets elsewhere.
private struct PoseDeltaAdvisory: View {
    let warning: (text: String, severity: AnalysisMath.PoseDeltaSeverity)

    var body: some View {
        Text(warning.text)
            .font(Theme.mono(12))
            .foregroundStyle(warning.severity == .warn ? Theme.Palette.amb : Theme.Palette.fg2)
            .padding(.horizontal, Theme.Space.screenMargin)
            .padding(.bottom, Theme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Advisory line (Plan T tier 3)

/// One plain amber line — wheel-check/shoulder-width advisories share this
/// shape with `PoseDeltaAdvisory` but are always warning-severity (unlike
/// pose delta's note/warn split), so there's no severity parameter.
private struct AdvisoryLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.mono(12))
            .foregroundStyle(Theme.Palette.amb)
            .padding(.horizontal, Theme.Space.screenMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Torso/hip as evidence beneath the pose-delta advisory (Plan T) — the
/// same `DiffRow` shape the table uses, standalone (no header) since a
/// single evidence pair reads fine without one.
private struct PoseEvidenceRows: View {
    let metricsA: PositionMetrics?
    let metricsB: PositionMetrics?

    var body: some View {
        VStack(spacing: 0) {
            if metricsA?.torsoAngleDeg != nil || metricsB?.torsoAngleDeg != nil {
                DiffRow(
                    key: "Torso angle",
                    valA: metricsA?.torsoAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    valB: metricsB?.torsoAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    diff: formatDiff(metricsA?.torsoAngleDeg, metricsB?.torsoAngleDeg, unit: "°", fmt: "%.0f")
                )
            }
            if metricsA?.hipAngleDeg != nil || metricsB?.hipAngleDeg != nil {
                DiffRow(
                    key: "Hip angle",
                    valA: metricsA?.hipAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    valB: metricsB?.hipAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                    diff: formatDiff(metricsA?.hipAngleDeg, metricsB?.hipAngleDeg, unit: "°", fmt: "%.0f")
                )
            }
        }
        .padding(.horizontal, Theme.Space.screenMargin)
    }
}

// MARK: - Photo underlay visibility (Plan AE3)

/// Pure chip-state → opacity mapping for the OUTLINE tab's dimmed photo
/// underlay — kept free of the view so it's directly testable. Internal
/// (not `private`) so `GetTuckedTests` can reach it via `@testable import`.
enum GhostCompareUnderlay {
    /// 0 unless both the OUTLINE tab and the PHOTO chip are on — the photo
    /// never shows on the PHOTO tab (it's already the primary content
    /// there) or when the underlay chip itself is off (today's default look).
    static func photoOpacity(showOutline: Bool, showPhotoUnderlay: Bool) -> Double {
        showOutline && showPhotoUnderlay ? 0.35 : 0
    }
}

// MARK: - Ghost-compare overlay (frontal only, v1)

/// One position's precomputed overlay material — built once, off-main, by
/// `ComparisonView.buildGhostCompareLayer`. `outlineImage` is already tinted
/// in this position's diff colour (A → `acc`, B → `amb`); `photoImage` is
/// the raw stored photo, tinted only by opacity at render time.
private struct GhostCompareLayer {
    let maskSize: CGSize
    let maskPixelsPerCm: Double
    let anchorCm: CGPoint
    let outlineImage: UIImage?
    let photoImage: UIImage?
    // R1: vector boundary trace for the draw-in ceremony — unit-space
    // (0–1), same top-left-origin convention as outlineImage's own frame
    // (no Vision-style y-flip). Empty when tracing found nothing draw-
    // worthy (fragmented matte); GhostCompareOverlay then falls back to
    // outlineImage's own scanReveal wipe for that layer.
    let contours: [CGPath]
    // This layer's diff colour (A → acc, B → amb) — outlineImage is
    // already tinted with it as a raster; the vector draw needs the same
    // SwiftUI Color directly to stroke the traced contours.
    let strokeColor: Color
}

/// Two positions' silhouettes, scaled to real centimetres and anchored on a
/// shared physical reference (ground + handlebar centreline — see
/// `AnalysisMath.anchorCm`), overlaid in one view. OUTLINE mode is two
/// translucent rings in the app's existing A/B diff colours; PHOTO mode is
/// a soft double-exposure — legible for a glance, OUTLINE is what you'd
/// trust for anything precise (same two-tier legibility PHOTO vs MASK/BONES
/// already has elsewhere in the app).
private struct GhostCompareOverlay: View {
    let layerA: GhostCompareLayer
    let layerB: GhostCompareLayer
    let showOutline: Bool
    let showLayerA: Bool
    let showLayerB: Bool
    // AE3: OUTLINE-only underlay — each visible layer's photo dims in behind
    // its own outline; gated on `showOutline` in `layerView` below, so this
    // has no effect on the PHOTO tab (which already shows the photo itself).
    let showPhotoUnderlay: Bool
    // R1: 0→1 outline draw-in progress, owned and animated by ComparisonView
    // (caller-owned animation, same pattern as SkeletonOverlay's `progress`).
    let drawInProgressA: Double
    let drawInProgressB: Double
    // R1.4: a pinch/pan starting mid-draw snaps the ceremony to done —
    // scrolling/zooming shouldn't compete with an unrelated animation.
    var onGestureBegan: () -> Void = {}
    // AB11: swipe the overlay to cycle PHOTO/OUTLINE — never A/B, which
    // keeps its own chips untouched.
    var onSwipeCycle: (Int) -> Void = { _ in }

    @State private var isZoomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            // Always computed from *both* extents regardless of which
            // layers are currently visible — toggling A/B is a pure
            // visibility switch, never a re-layout, so hiding one silhouette
            // can't make the other jump to a different apparent scale.
            let extentA = AnalysisMath.overlayExtentCm(
                maskSize: layerA.maskSize, maskPixelsPerCm: layerA.maskPixelsPerCm, anchorCm: layerA.anchorCm
            )
            let extentB = AnalysisMath.overlayExtentCm(
                maskSize: layerB.maskSize, maskPixelsPerCm: layerB.maskPixelsPerCm, anchorCm: layerB.anchorCm
            )
            let fit = AnalysisMath.overlayFit(extentA: extentA, extentB: extentB, containerSize: proxy.size)

            ZStack {
                if showLayerA { layerView(layerA, fit: fit, drawInProgress: drawInProgressA) }
                if showLayerB { layerView(layerB, fit: fit, drawInProgress: drawInProgressB) }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            // The whole composite zooms as one aligned unit (same pattern
            // PositionDetailView/RevealStep use) — PHOTO/OUTLINE and the A/B
            // toggles don't reset zoom, since the physical-cm placement puts
            // both modes' content at the identical screen position/scale.
            .pinchZoomable(onGestureBegan: onGestureBegan, onZoomChanged: { isZoomed = $0 })
            // AB11: `.simultaneousGesture` so the swipe never steals the
            // enclosing ScrollView's vertical drag — only `.onEnded` acts,
            // and only for a clearly horizontal drag while unzoomed (a
            // zoomed pan is a different, `.highPriorityGesture`-owned
            // gesture already; `isZoomed` is a defense-in-depth guard here).
            .simultaneousGesture(swipeGesture)
        }
        .background(Theme.Palette.bg1)
        .clipped()
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard !isZoomed else { return }
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 50, abs(horizontal) > abs(vertical) * 1.5 else { return }
                onSwipeCycle(horizontal < 0 ? 1 : -1)
            }
    }

    @ViewBuilder
    private func layerView(
        _ layer: GhostCompareLayer, fit: (screenPointsPerCm: CGFloat, anchorScreenPoint: CGPoint),
        drawInProgress: Double
    ) -> some View {
        let placement = AnalysisMath.overlayPlacement(
            maskSize: layer.maskSize, maskPixelsPerCm: layer.maskPixelsPerCm, anchorCm: layer.anchorCm,
            sharedAnchorScreenPoint: fit.anchorScreenPoint, screenPointsPerCm: fit.screenPointsPerCm
        )
        if placement.frameSize.width > 0, placement.frameSize.height > 0 {
            ZStack {
                // AE3: dimmed photo underlay, OUTLINE tab only — a plain
                // opacity fade (not tied to `drawInProgress`) so it never
                // competes with the R1 draw-in ceremony's outline trim.
                if showOutline, let photo = layer.photoImage {
                    Image(uiImage: photo)
                        .resizable()
                        .frame(width: placement.frameSize.width, height: placement.frameSize.height)
                        .position(placement.center)
                        .opacity(GhostCompareUnderlay.photoOpacity(showOutline: showOutline, showPhotoUnderlay: showPhotoUnderlay))
                        .animation(reduceMotion ? nil : Theme.Motion.entrance(), value: showPhotoUnderlay)
                        .allowsHitTesting(false)
                }
                if showOutline, !layer.contours.isEmpty {
                    // R1.2: the traced boundary draws on, in the same frame the
                    // raster ring would otherwise occupy — SkeletonOverlay is
                    // the in-repo reference for trim+progress, caller-owned
                    // animation.
                    ContourDrawView(contours: layer.contours, color: layer.strokeColor, progress: drawInProgress)
                        .frame(width: placement.frameSize.width, height: placement.frameSize.height)
                        .position(placement.center)
                } else if let image = showOutline ? layer.outlineImage : layer.photoImage {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: placement.frameSize.width, height: placement.frameSize.height)
                        .position(placement.center)
                        // OUTLINE rings don't occlude each other, so full
                        // opacity; PHOTO is a deliberate soft double-exposure.
                        // An untraceable OUTLINE layer (fragmented matte) wipes
                        // in via scanReveal on the same stagger instead of the
                        // vector draw — same graceful-degrade shape as every
                        // other optional visual in this app.
                        .opacity(showOutline ? 1 : 0.55)
                        .scanReveal(progress: showOutline ? drawInProgress : 1)
                }
            }
        }
    }
}

/// Renders a layer's traced contours with a shared 0→1 trim progress — all
/// of a layer's contours share one progress, no per-contour ceremony (R1.2).
private struct ContourDrawView: View {
    let contours: [CGPath]
    let color: Color
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(contours.indices, id: \.self) { index in
                    scaledPath(contours[index], in: proxy.size)
                        .trim(from: 0, to: progress)
                        // 1pt, not 2 (Kah, on-device): the raster ring this
                        // replaced was 4px in stored-mask space ≈ 0.7pt at
                        // this display scale — the finer line is the look.
                        .stroke(color, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .opacity(0.85) // matches the raster ring's own tint alpha
        .allowsHitTesting(false)
    }

    /// contours are unit-space (0–1), top-left origin, y-down — scaling by
    /// this view's own pixel size lines them up with the frame the raster
    /// `outlineImage` would otherwise occupy, no further offset needed.
    private func scaledPath(_ cgPath: CGPath, in size: CGSize) -> Path {
        var transform = CGAffineTransform(scaleX: size.width, y: size.height)
        let scaled = cgPath.copy(using: &transform) ?? cgPath
        return Path(scaled)
    }
}

/// One position's visibility switch (Plan ghost-compare follow-up) — lets
/// you isolate a single silhouette instead of always seeing both overlaid.
private struct LayerToggleChip: View {
    let label: String
    let color: Color
    let isOn: Bool
    // AE3: the PHOTO chip's label doesn't fit the original 28pt square, so
    // width is overridable — everything else (stroke, mono label, fill
    // logic) stays identical across every chip.
    var width: CGFloat = 28
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(isOn ? color : Theme.Palette.fg3)
                .frame(width: width, height: 28)
                .background(Theme.Palette.bg0.opacity(0.72))
                .overlay(Rectangle().stroke(isOn ? color : Theme.Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        // A bare "A"/"B"/"PHOTO" is ambiguous read alone (Plan AK9).
        .accessibilityLabel("\(label) layer, \(isOn ? "shown" : "hidden")")
    }
}

// MARK: - Position panel

private struct PositionPanel: View {
    let position: Position
    let side: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(side)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.Palette.fg3)
            Text(position.label)
                .font(Theme.mono(13, weight: .bold))
                .foregroundStyle(Theme.Palette.fg)
                .lineLimit(2)
            if let area = position.metrics?.frontalAreaCm2 {
                Text("\(AnalysisMath.areaDisplay(area)) cm²")
                    .font(Theme.mono(24, weight: .bold))
                    .foregroundStyle(Theme.Palette.acc)
            }
            if let bike = position.bike {
                Text(bike.nickname)
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
                    .lineLimit(1)
            }
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Palette.bg1)
    }
}

// MARK: - Time impact (Plan S2)

/// The "so what" moment (Plan S2's own name for the feature) — a felt
/// time-over-distance estimate from the measured area delta, at equal
/// assumed Cd. Deliberately crosses the "no faster/slower verdict" line the
/// raw cm² comparison holds elsewhere (torsten-aero-notes.md §D) because a
/// cm² delta has no felt meaning; the honesty debt is paid with the
/// noise-floor gate below, the conditional "at your usual effort" framing,
/// and an assumptions line that's always attached, never optional (Plan AI3
/// shortens that line but keeps it attached; only the rear-bag/wake caveat
/// moved into the measurement-detail disclosure, since it qualifies the
/// model rather than the estimate itself). No P3 rear-located gate here
/// (dropped for this pass — Plan P3 as built only disambiguates side-on
/// facing, it doesn't localise a frontal silhouette diff; revisit if that
/// ever gets built).
private struct TimeImpactSection: View {
    let areaA: Double
    let areaB: Double
    let isDistinguishable: Bool

    private enum Field: Hashable { case distance }

    private enum DistancePreset: Double, CaseIterable {
        case c100 = 100, c200 = 200, c400 = 400, c1000 = 1000
        var label: String { "\(Int(rawValue)) KM" }
    }

    // Persisted user-level (not per-bike, per Plan S2) so the section works
    // with zero typing on repeat visits — the speed itself lives inside
    // `SpeedControl` (shared with the single screen); this section only
    // reads `inputsConfirmed` to frame the estimate.
    // True once the rider has actually committed a value to the speed field —
    // distinct from the value itself, since a rider could deliberately enter
    // exactly the default and that's still a confirmed number, not a guess.
    // Drives the "using defaults, edit below" call-out in the estimate
    // sentence.
    @AppStorage("effortInputsConfirmed") private var inputsConfirmed = false

    // The one live value driving both the SpeedControl's slider/field and
    // this section's output band. SpeedControl seeds it from the persisted
    // value on appear and writes it live during drag / on commit; the band
    // recompute reads it here so it updates as the slider moves (AB10).
    @State private var speedKmh: Double = 30
    @State private var selectedPreset: DistancePreset? = .c100
    @State private var customDistanceText = ""
    @FocusState private var focusedField: Field?

    // AI7: collapsed for a returning rider who's already confirmed a speed
    // (straight to the delta hero), expanded for a first-timer who still
    // needs to meet the form. Read straight from UserDefaults rather than
    // through `inputsConfirmed` above — @AppStorage's wrapped value isn't
    // reliably readable this early in a synthesized-adjacent custom init.
    @State private var inputsExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(areaA: Double, areaB: Double, isDistinguishable: Bool) {
        self.areaA = areaA
        self.areaB = areaB
        self.isDistinguishable = isDistinguishable
        _inputsExpanded = State(initialValue: !UserDefaults.standard.bool(forKey: "effortInputsConfirmed"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TIME IMPACT")
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(Theme.Palette.fg3)
                .kerning(0.5)
                .padding(.horizontal, Theme.Space.screenMargin)
                .padding(.top, Theme.Space.lg)

            if isDistinguishable {
                if let outputBand {
                    outputCard(outputBand)
                        .padding(.horizontal, Theme.Space.screenMargin)
                        .padding(.top, Theme.Space.sm)
                }
                inputsDisclosure
                    .padding(.horizontal, Theme.Space.screenMargin)
                    .padding(.top, Theme.Space.md)
            } else {
                // Spec: a delta smaller than the noise floor must never
                // imply a time difference (Plan A4's rule, extended by S2 §2)
                // — DeltaHero below still carries the full "within
                // measurement noise" verdict and raw numbers.
                Text("Too close to call a time difference.")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg3)
                    .padding(.horizontal, Theme.Space.screenMargin)
                    .padding(.top, Theme.Space.sm)
            }
        }
        .padding(.bottom, Theme.Space.lg)
    }

    // MARK: - Output

    private typealias OutputBand = (winnerLabel: String, lowMinutes: Double, highMinutes: Double, speedKmh: Double)

    @ViewBuilder
    private func outputCard(_ band: OutputBand) -> some View {
        // EST + the sentence + the assumptions line, all inside one bordered
        // card (S2 §5) — a screenshot crop tight enough to isolate a bare
        // number visibly cuts off the border, which is the practical
        // "uncroppable" this can guarantee.
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Text("EST")
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundStyle(Theme.Palette.bg0)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.Palette.acc)
                Text(sentence(band))
                    .font(Theme.mono(15, weight: .bold))
                    .foregroundStyle(Theme.Palette.fg)
            }
            // AB13: same-effort % speed, directly beneath the minutes
            // sentence — `pctBand.winnerLabel == band.winnerLabel` is a
            // defensive check, not a coupling; the two are derived from the
            // same power-balance model and always agree in sign (pinned by
            // `EffortModelTests`), so this should never actually skip.
            if pctBand.winnerLabel == band.winnerLabel {
                Text(pctSentence(band, pctBand))
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg2)
            }
            if !inputsConfirmed {
                Text("Using a default speed. Edit below for yours.")
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundStyle(Theme.Palette.amb)
            }
            Text("Estimate. Equal effort, equal drag coefficient, \(Int(EffortModel.assumedMassKg)) kg rider+bike+kit, flat, no wind.")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.Palette.fg3)
        }
        .padding(Theme.Space.md)
        .overlay(Rectangle().stroke(Theme.Palette.line, lineWidth: 1))
    }

    /// Conditional voice throughout (S2 §5) — while running on unconfirmed
    /// defaults, the values themselves are called out ("an assumed X km/h")
    /// rather than the confident "your usual effort," so the estimate can
    /// never be mistaken for a personalised one.
    private func sentence(_ band: OutputBand) -> String {
        if inputsConfirmed {
            return "At \(Int(band.speedKmh)) km/h, position \(band.winnerLabel) is \(formattedRange(band)) faster over \(distanceLabel)."
        }
        return "At an assumed \(Int(band.speedKmh)) km/h, position \(band.winnerLabel) would be \(formattedRange(band)) faster over \(distanceLabel)."
    }

    /// nil when any input is missing/out of range (Plan S2 edge cases) —
    /// no output card at all in that case, just the bare fields.
    private var outputBand: OutputBand? {
        guard let distanceKm, distanceKm > 0 else { return nil }

        let speedMS = speedKmh / 3.6
        let distanceM = distanceKm * 1000
        let massKg = EffortModel.assumedMassKg
        let point = EffortModel.timeDeltaMinutes(
            areaACm2: areaA, areaBCm2: areaB, speedMS: speedMS, massKg: massKg, distanceM: distanceM
        )
        let band = EffortModel.timeDeltaBandMinutes(
            areaACm2: areaA, areaBCm2: areaB, speedMS: speedMS, massKg: massKg, distanceM: distanceM
        )

        if band.low >= 0 { return ("B", band.low, band.high, speedKmh) }
        if band.high <= 0 { return ("A", -band.high, -band.low, speedKmh) }
        // Band spans zero (S2 §4): the delta cleared the *area* noise floor
        // but the independently-perturbed time band still straddles it —
        // show the honest zero-anchored range rather than clamping the low
        // end away from zero. Direction follows the point estimate's sign.
        let magnitude = max(abs(band.low), abs(band.high))
        return (point >= 0 ? "B" : "A", 0, magnitude, speedKmh)
    }

    private func formattedRange(_ band: OutputBand) -> String {
        let lo = Int(band.lowMinutes.rounded())
        let hi = Int(band.highMinutes.rounded())
        if hi >= 90 {
            return "~\(formattedMinutes(lo))–\(formattedMinutes(hi))"
        }
        return "~\(lo)–\(hi) min"
    }

    /// Whole minutes only, ever (S2 Output framing) — switches to "Xh Ym"
    /// past 90 min.
    private func formattedMinutes(_ minutes: Int) -> String {
        guard minutes >= 90 else { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private var distanceLabel: String {
        guard let distanceKm else { return "" }
        return "\(Int(distanceKm)) km"
    }

    // MARK: - AB13: same-effort % speed

    private typealias PctBand = (winnerLabel: String, lowPct: Double, highPct: Double)

    /// Speed-domain sibling of `outputBand` — same power-balance model, same
    /// area-noise perturbation, so the winner/sign always agree with the
    /// minutes band beside it (pinned by `EffortModelTests`). Unlike
    /// `outputBand`, this never depends on distance, so it's never nil.
    private var pctBand: PctBand {
        let speedMS = speedKmh / 3.6
        let massKg = EffortModel.assumedMassKg
        let point = EffortModel.speedDeltaPercent(areaACm2: areaA, areaBCm2: areaB, speedMS: speedMS, massKg: massKg)
        let band = EffortModel.speedDeltaPercentBand(areaACm2: areaA, areaBCm2: areaB, speedMS: speedMS, massKg: massKg)

        if band.low >= 0 { return ("B", band.low, band.high) }
        if band.high <= 0 { return ("A", -band.high, -band.low) }
        let magnitude = max(abs(band.low), abs(band.high))
        return (point >= 0 ? "B" : "A", 0, magnitude)
    }

    private func pctSentence(_ band: OutputBand, _ pct: PctBand) -> String {
        "Same effort at \(Int(band.speedKmh)) km/h: position \(pct.winnerLabel) is \(formattedPct(pct)) faster."
    }

    /// Never a false three-significant-digit percentage (AB13): a single
    /// figure gets one decimal place; a spread wide enough to matter shows as
    /// a range instead, same honesty shape as `formattedRange`.
    private func formattedPct(_ pct: PctBand) -> String {
        if pct.highPct - pct.lowPct < 0.3 {
            let mid = (pct.lowPct + pct.highPct) / 2
            return "~\(String(format: "%.1f", mid))%"
        }
        return "~\(String(format: "%.1f", pct.lowPct))–\(String(format: "%.1f", pct.highPct))%"
    }

    // MARK: - Inputs disclosure (Plan AI7)

    /// `Components.DetailDisclosure`'s exact visual treatment, inlined —
    /// that component hardcodes `expanded = false` and lives in
    /// Components.swift (out of scope for this change), but this is the one
    /// disclosure on the screen whose *initial* state has to vary
    /// (`inputsExpanded`, set in `init`). Flagged for later unification: if
    /// `DetailDisclosure` ever grows an initial-state parameter, this copy
    /// should be deleted in favour of it.
    private var inputsDisclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { toggleInputs() } label: {
                HStack(spacing: Theme.Space.xs) {
                    Text(inputsExpanded ? "−" : "+")
                        .font(Theme.mono(14, weight: .bold))
                        .foregroundStyle(Theme.Palette.acc)
                    Text("Change speed & distance".uppercased())
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundStyle(Theme.Palette.fg2)
                        .kerning(0.5)
                    Spacer()
                }
                .padding(.horizontal, Theme.Space.md)
                .frame(minHeight: 40)
                .background(Theme.Palette.bg1)
                .overlay(Rectangle().stroke(Theme.Palette.line, lineWidth: Theme.Control.hairline))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if inputsExpanded {
                inputs
                    .padding(.top, Theme.Space.md)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func toggleInputs() {
        if reduceMotion {
            inputsExpanded.toggle()
        } else {
            withAnimation(Theme.Motion.interactive()) { inputsExpanded.toggle() }
        }
    }

    private var inputs: some View {
        // Two distinct field groups (distance / speed), each with a tight
        // `sm` internal rhythm, separated by a larger `md` gap so the
        // DISTANCE selector doesn't crowd the SPEED field — the same
        // group-binding contrast the rest of the app uses (a flat `sm`
        // throughout made the two groups read as one block). The helper text
        // lives inside the second group so it binds to the field it
        // describes rather than floating equidistant between the two.
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                FieldLabel("DISTANCE")
                SegmentedToggleBar(labels: presetLabels, selectedIndex: presetIndexBinding)
                if selectedPreset == nil {
                    MonoField(placeholder: "e.g. 250", text: $customDistanceText, numericOnly: true)
                        .focused($focusedField, equals: .distance)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SpeedControl(speedKmh: $speedKmh)
                Text("Flat, calm road speed. Not your ridden average.")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
            }
        }
    }

    private var presetLabels: [String] { DistancePreset.allCases.map(\.label) + ["CUSTOM"] }

    private var presetIndexBinding: Binding<Int> {
        Binding(
            get: { selectedPreset.flatMap { DistancePreset.allCases.firstIndex(of: $0) } ?? DistancePreset.allCases.count },
            set: { newIndex in
                selectedPreset = DistancePreset.allCases.indices.contains(newIndex) ? DistancePreset.allCases[newIndex] : nil
            }
        )
    }

    private var distanceKm: Double? {
        if let selectedPreset { return selectedPreset.rawValue }
        return Double(customDistanceText)
    }

}

// MARK: - Delta hero

private struct DeltaHero: View {
    let delta: Double
    let winner: String            // "A" or "B" — whichever has the smaller area
    let absoluteDeltaCm2: Double
    let isDistinguishable: Bool
    let noisePct: Double

    // The subtitle/within-noise block fades in as its own beat (N6) — for
    // the distinguishable case, after the number lands; for within-noise,
    // together as one plain fade (no ceremony — the absence of motion is
    // the message).
    @State private var subtitleVisible = false

    private var isImprovement: Bool { delta < 0 }
    private var color: Color { isImprovement ? Theme.Palette.acc : Theme.Palette.amb }
    private var sign: String { delta >= 0 ? "+" : "" }

    /// Spoken form for the whole hero (Plan AK9) — read against the *final*
    /// delta, never the mid-roll animated value the digits pass through.
    private var accessibilityLabelText: String {
        guard isDistinguishable else {
            return "Within measurement noise. Raw difference \(sign)\(String(format: "%.1f", delta)) percent, noise plus or minus \(String(format: "%.1f", noisePct)) percent."
        }
        let deltaPct = "\(sign)\(String(format: "%.1f", delta)) percent"
        let winnerName = winner == "A" ? "Position A" : "Position B"
        return "\(deltaPct) difference. \(winnerName) is smaller by \(accessibilityGroupedNumber(absoluteDeltaCm2)) square centimetres."
    }

    var body: some View {
        VStack(spacing: 4) {
            if isDistinguishable {
                RollingNumberText(
                    value: delta,
                    format: { "\(self.sign)\(String(format: "%.1f", $0))%" },
                    font: Theme.mono(52, weight: .bold),
                    color: color,
                    tracking: Theme.Typography.tracking(forSize: 52),
                    duration: 0.6,
                    onComplete: {
                        if isImprovement { Haptics.confirm() }
                        withAnimation(Theme.Motion.entrance()) { subtitleVisible = true }
                    }
                )
                Text("\(winner) IS SMALLER · \(Int(absoluteDeltaCm2.rounded())) cm²")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .kerning(0.3)
                    .opacity(subtitleVisible ? 1 : 0)
            } else {
                // Spec: a delta smaller than the noise floor must never be
                // presented as real (Plan A4). No ceremony at all — the ≈
                // block and its lines plain-fade in together, no haptic.
                Group {
                    Text("≈")
                        .font(Theme.mono(52, weight: .bold))
                        .foregroundStyle(Theme.Palette.fg3)
                    Text("WITHIN MEASUREMENT NOISE")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.Palette.fg2)
                        .kerning(0.3)
                    Text("raw: \(sign)\(String(format: "%.1f", delta))% · noise: ±\(String(format: "%.1f", noisePct))%")
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.Palette.fg3)
                }
                .opacity(subtitleVisible ? 1 : 0)
                .onAppear {
                    withAnimation(Theme.Motion.entrance()) { subtitleVisible = true }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.lg)
        // One spoken element, not a swipe through a rolling-digit view plus
        // two more Texts (Plan AK9) — "7488 cm²" and "≈" read as glyphs
        // otherwise.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }
}

// MARK: - Diff formatting (shared by the table, pose-evidence rows, and the
// measurement-detail disclosure)

private func formatDiff(_ a: Double?, _ b: Double?, unit: String, fmt: String) -> String? {
    guard let a, let b else { return nil }
    let d = b - a
    let sign = d >= 0 ? "+" : ""
    return "\(sign)\(String(format: fmt, d)) \(unit)"
}

/// nil unless this position's headDropCm was computed from a real
/// wheelbase ruler — the same defensibility gate RevealStep and
/// PositionDetailView apply.
private func defensibleHeadDropCm(_ metrics: PositionMetrics?) -> Double? {
    guard let metrics, metrics.sideOnPixelsPerCm != nil else { return nil }
    return metrics.headDropCm
}

// MARK: - Diff table

/// Tier 4 (Plan T) — reduced to the standing rows every comparison cares
/// about. Everything else (consistency signals, provenance) moved to
/// `ComparisonMeasurementDetail` behind the disclosure, or promoted to a
/// tier-3 advisory when it's actively warning about something.
private struct DiffTable: View {
    let metricsA: PositionMetrics?
    let metricsB: PositionMetrics?
    let appeared: Bool
    let cascadeStagger: Double

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("METRIC")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                Spacer()
                Text("A")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .frame(width: 76, alignment: .trailing)
                Text("B")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .frame(width: 76, alignment: .trailing)
                Text("DIFF")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, Theme.Space.screenMargin)
            .frame(minHeight: 36)

            SectionDivider()

            // Frontal area (always present) — diff-column values never roll
            // (derived, small, numerous); rows just cascade with the table.
            DiffRow(
                key: "Frontal area",
                valA: metricsA.map { "\(AnalysisMath.areaDisplay($0.frontalAreaCm2)) cm²" },
                valB: metricsB.map { "\(AnalysisMath.areaDisplay($0.frontalAreaCm2)) cm²" },
                diff: formatDiff(metricsA?.frontalAreaCm2, metricsB?.frontalAreaCm2, unit: "cm²", fmt: "%.0f")
            )
            .cascadeIn(index: 1, trigger: appeared, duration: Theme.Motion.base, stagger: cascadeStagger)

            // Head drop (side-on, optional) — shown per-side only when that
            // position's own headDropCm came from a real wheelbase ruler
            // (Plan P1.5), not the borrowed frontal scale (spec §3). A side
            // without a ruler shows "—", same as any other missing metric;
            // the diff column is naturally "—" too unless both sides qualify.
            if defensibleHeadDropCm(metricsA) != nil || defensibleHeadDropCm(metricsB) != nil {
                DiffRow(
                    key: "Head drop",
                    valA: defensibleHeadDropCm(metricsA).map { "\(String(format: "%.1f", $0)) cm" },
                    valB: defensibleHeadDropCm(metricsB).map { "\(String(format: "%.1f", $0)) cm" },
                    diff: formatDiff(defensibleHeadDropCm(metricsA), defensibleHeadDropCm(metricsB), unit: "cm", fmt: "%.1f")
                )
                .cascadeIn(index: 2, trigger: appeared, duration: Theme.Motion.base, stagger: cascadeStagger)
            }
        }
    }
}

/// Tier 5 (Plan T) — everything the table used to show that isn't a
/// standing answer: consistency signals not currently firing a warning,
/// plus provenance (scale, bar width). `includePoseRows` is false when
/// torso/hip are already visible as tier-3 evidence under the pose-delta
/// advisory, so they're never shown twice.
private struct ComparisonMeasurementDetail: View {
    let metricsA: PositionMetrics?
    let metricsB: PositionMetrics?
    let includePoseRows: Bool
    // Subject-minus-person pixel share of the subject mask, per side (Plan
    // Z4) — nil (displays "—") when that position has no subject mask.
    let bikeCoverageA: Double?
    let bikeCoverageB: Double?

    var body: some View {
        VStack(spacing: 0) {
            if includePoseRows {
                if metricsA?.torsoAngleDeg != nil || metricsB?.torsoAngleDeg != nil {
                    DiffRow(
                        key: "Torso angle",
                        valA: metricsA?.torsoAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                        valB: metricsB?.torsoAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                        diff: formatDiff(metricsA?.torsoAngleDeg, metricsB?.torsoAngleDeg, unit: "°", fmt: "%.0f")
                    )
                }
                if metricsA?.hipAngleDeg != nil || metricsB?.hipAngleDeg != nil {
                    DiffRow(
                        key: "Hip angle",
                        valA: metricsA?.hipAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                        valB: metricsB?.hipAngleDeg.map { "\(String(format: "%.0f", $0))°" },
                        diff: formatDiff(metricsA?.hipAngleDeg, metricsB?.hipAngleDeg, unit: "°", fmt: "%.0f")
                    )
                }
            }

            if metricsA?.shoulderWidthCm != nil || metricsB?.shoulderWidthCm != nil {
                DiffRow(
                    key: "Shoulder width",
                    valA: metricsA?.shoulderWidthCm.map { "\(String(format: "%.1f", $0)) cm" },
                    valB: metricsB?.shoulderWidthCm.map { "\(String(format: "%.1f", $0)) cm" },
                    diff: formatDiff(metricsA?.shoulderWidthCm, metricsB?.shoulderWidthCm, unit: "cm", fmt: "%.1f")
                )
            }

            if metricsA?.pixelsPerCm != nil || metricsB?.pixelsPerCm != nil {
                DiffRow(
                    key: "Scale",
                    valA: metricsA.map { "\(String(format: "%.1f", $0.pixelsPerCm)) px/cm" },
                    valB: metricsB.map { "\(String(format: "%.1f", $0.pixelsPerCm)) px/cm" },
                    diff: formatDiff(metricsA?.pixelsPerCm, metricsB?.pixelsPerCm, unit: "px/cm", fmt: "%.1f")
                )
            }

            if metricsA?.handlebarWidthMmUsed != nil || metricsB?.handlebarWidthMmUsed != nil {
                DiffRow(
                    key: "Bar width",
                    valA: metricsA?.handlebarWidthMmUsed.map { "\(Int($0)) mm" },
                    valB: metricsB?.handlebarWidthMmUsed.map { "\(Int($0)) mm" },
                    diff: formatDiff(metricsA?.handlebarWidthMmUsed, metricsB?.handlebarWidthMmUsed, unit: "mm", fmt: "%.0f")
                )
            }

            // Wheel check has no meaningful numeric diff between sides — the
            // two text values (agree/disagree, independently) are the whole
            // story, so the diff column stays "—" (DiffRow's own nil case).
            if metricsA?.wheelCheckDisagreementFraction != nil || metricsB?.wheelCheckDisagreementFraction != nil {
                DiffRow(
                    key: "Wheel check",
                    valA: metricsA?.wheelCheckDisagreementFraction.map { AnalysisMath.wheelCheckDisplay($0).text },
                    valB: metricsB?.wheelCheckDisagreementFraction.map { AnalysisMath.wheelCheckDisplay($0).text },
                    diff: nil
                )
            }

            DiffRow(
                key: "Foreground pixels",
                valA: metricsA.map { "\($0.foregroundPixelCount)" },
                valB: metricsB.map { "\($0.foregroundPixelCount)" },
                diff: nil
            )

            // Diagnostic, not a standing metric (Plan Z4): always present,
            // "—" per side when that position has no subject mask.
            DiffRow(
                key: "Bike coverage",
                valA: AnalysisMath.bikeCoverageDisplay(bikeCoverageA),
                valB: AnalysisMath.bikeCoverageDisplay(bikeCoverageB),
                diff: nil
            )

            DiffRow(
                key: "Computed",
                valA: metricsA?.computedAt.formatted(date: .abbreviated, time: .omitted),
                valB: metricsB?.computedAt.formatted(date: .abbreviated, time: .omitted),
                diff: nil
            )

            // Relocated from the always-attached assumptions line (Plan
            // AI3) — the caveat itself is unchanged, just no longer forced
            // onto every glance at the estimate.
            Text("A rear-mounted bag can change drag through wake effects this model doesn't capture.")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.Palette.fg3)
                .padding(.horizontal, Theme.Space.screenMargin)
                .padding(.top, Theme.Space.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DiffRow: View {
    let key: String
    let valA: String?
    let valB: String?
    let diff: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(key.uppercased())
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg2)
                    .kerning(0.2)
                Spacer()
                Text(valA ?? "—")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg)
                    .frame(width: 76, alignment: .trailing)
                Text(valB ?? "—")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg)
                    .frame(width: 76, alignment: .trailing)
                Text(diff ?? "—")
                    .font(Theme.mono(13, weight: .bold))
                    .foregroundStyle(diffColor)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, Theme.Space.screenMargin)
            .frame(minHeight: 44)
            SectionDivider()
        }
    }

    private var diffColor: Color {
        guard let d = diff else { return Theme.Palette.fg4 }
        return d.hasPrefix("+") ? Theme.Palette.amb : Theme.Palette.acc
    }
}
