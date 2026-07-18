import CoreGraphics
import Foundation

/// Pure, deterministic geometry for frontal-area and posture computation.
/// Extracted from `AnalysisEngine` so the math can be unit-tested without Vision
/// (which needs a real person image and can't be exercised deterministically).
enum AnalysisMath {
    /// Uncertainty is modelled as a fixed fraction of the computed area,
    /// reflecting segmentation + scale noise.
    static let uncertaintyFraction = 0.03

    // MARK: - Scale

    /// Pixel distance between two handlebar taps given in unit coords (0–1).
    static func handlebarPixels(tap0: CGPoint, tap1: CGPoint, imageSize: CGSize) -> Double {
        let p0 = CGPoint(x: tap0.x * imageSize.width, y: tap0.y * imageSize.height)
        let p1 = CGPoint(x: tap1.x * imageSize.width, y: tap1.y * imageSize.height)
        return Double(hypot(p1.x - p0.x, p1.y - p0.y))
    }

    /// Source-image pixels per cm, from a known handlebar width.
    static func pixelsPerCm(handlebarPixels: Double, handlebarWidthMm: Double) -> Double {
        handlebarPixels / (handlebarWidthMm / 10.0)
    }

    /// Side-on scale from a wheelbase tap-calibration (Plan P1.5) — same
    /// tap-distance math as the frontal handlebar ruler (`handlebarPixels` +
    /// `pixelsPerCm` above), wheelbase substituted for handlebar width as
    /// the known length. A thin, semantically-named wrapper; no new geometry.
    static func sideOnPixelsPerCm(tap0: CGPoint, tap1: CGPoint, imageSize: CGSize, wheelbaseMm: Double) -> Double {
        pixelsPerCm(
            handlebarPixels: handlebarPixels(tap0: tap0, tap1: tap1, imageSize: imageSize),
            handlebarWidthMm: wheelbaseMm
        )
    }

    /// The side-on wheel-height dimension's full vertical span, as a
    /// fraction of the image height (Plan Z5) — derived purely from the
    /// wheelbase ruler's own geometry (axle taps + the bike's wheelbase and
    /// wheel-diameter specs), no absolute pixel dimensions needed:
    /// `sideOnPixelsPerCm` is pixels-per-cm in the *source* image's own
    /// resolution, and that resolution cancels out of the
    /// wheelDiameterMm/wheelbaseMm ratio the same way any scale-free ratio
    /// cancels — only the image's aspect ratio (not its absolute pixel
    /// count) survives into the unit-space result. `axleFront`/`axleRear`
    /// are top-left unit coords (Plan Z1); `imageAspect` is width/height.
    static func wheelSpanUnitY(
        axleFront: CGPoint, axleRear: CGPoint, imageAspect: Double, wheelbaseMm: Double, wheelDiameterMm: Double
    ) -> Double {
        guard wheelbaseMm > 0 else { return 0 }
        let dx = Double(axleRear.x - axleFront.x) * imageAspect
        let dy = Double(axleRear.y - axleFront.y)
        let wheelbaseUnitLength = (dx * dx + dy * dy).squareRoot()
        return wheelDiameterMm / wheelbaseMm * wheelbaseUnitLength
    }

    /// The segmentation mask resolution differs from the source in general.
    /// Rescale source pixels/cm into mask pixel space so area and scale share units.
    static func maskPixelsPerCm(sourcePixelsPerCm: Double, maskWidth: Int, sourceWidth: Int) -> Double {
        sourcePixelsPerCm * (Double(maskWidth) / Double(sourceWidth))
    }

    /// Alternate derivation of the same quantity as `maskPixelsPerCm` above,
    /// for a *stored* mask whose resolution wasn't tracked through its own
    /// downscale chain (Plan ghost-compare — `downscaledMaskPNGData` and
    /// `compressedForStorage` downscale mask and photo independently, so the
    /// analysis-time source width no longer relates simply to what's on
    /// disk). Self-consistent regardless: area = foregroundPixelCount /
    /// scale², solved for scale, against the one number that's already
    /// resolution-independent and ground-truth — the stored `frontalAreaCm2`.
    static func maskPixelsPerCm(foregroundPixelCount: Int, areaCm2: Double) -> Double {
        guard areaCm2 > 0 else { return 0 }
        return (Double(foregroundPixelCount) / areaCm2).squareRoot()
    }

    /// `maskPixelsPerCm` rescales by width ratio only, which is correct only
    /// if the mask preserves the source's aspect ratio. True for Vision's
    /// person segmentation in practice, but unverified in general — this
    /// predicate lets callers check rather than assume (Plan I5/H5).
    static func maskMatchesSourceAspect(
        maskWidth: Int, maskHeight: Int, sourceWidth: Int, sourceHeight: Int, tolerance: Double = 0.02
    ) -> Bool {
        guard maskHeight > 0, sourceHeight > 0 else { return false }
        let maskAspect = Double(maskWidth) / Double(maskHeight)
        let sourceAspect = Double(sourceWidth) / Double(sourceHeight)
        return abs(maskAspect - sourceAspect) / sourceAspect <= tolerance
    }

    // MARK: - Subject-mask instance selection (Plan W2)

    /// Overlap area (unit²) between two Vision-normalised boxes — 0 for
    /// non-intersecting or degenerate boxes.
    static func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    /// Picks the foreground instance most likely to *be* the rider: the one
    /// whose box overlaps `riderBox` (from `VNDetectHumanRectanglesRequest`,
    /// or a frame-centre fallback) the most. nil when `instanceBoxes` is empty.
    static func riderInstance(instanceBoxes: [Int: CGRect], riderBox: CGRect) -> Int? {
        instanceBoxes.max { overlapArea($0.value, riderBox) < overlapArea($1.value, riderBox) }?.key
    }

    /// The rider instance plus whatever else is spatially connected to it —
    /// the bike/bags the rider is on (Plan A1's proposed production
    /// pipeline): any other instance box that intersects the rider's box
    /// expanded by `margin` on each side. A margin, not exact adjacency,
    /// since a bike frame/wheel often doesn't touch the rider's silhouette
    /// bounding box exactly. Disconnected clutter (a coat on the wall, a
    /// leaning spare wheel, a car behind the rider) stays excluded, unlike a
    /// blanket union of every instance.
    static func connectedInstances(
        riderInstance: Int, instanceBoxes: [Int: CGRect], margin: CGFloat = 0.06
    ) -> IndexSet {
        guard let riderBox = instanceBoxes[riderInstance] else { return IndexSet() }
        let expandedRiderBox = riderBox.insetBy(dx: -margin, dy: -margin)
        var selected = IndexSet([riderInstance])
        for (index, box) in instanceBoxes where index != riderInstance && expandedRiderBox.intersects(box) {
            selected.insert(index)
        }
        return selected
    }

    // MARK: - Area

    /// Frontal area in cm² from a foreground pixel count and the mask-space scale.
    static func frontalAreaCm2(foregroundPixelCount: Int, maskPixelsPerCm: Double) -> Double {
        Double(foregroundPixelCount) / (maskPixelsPerCm * maskPixelsPerCm)
    }

    /// Counts pixels ≥ threshold in a row-major 8-bit buffer, striding by
    /// `bytesPerRow` rather than scanning the buffer linearly. Pixel buffers
    /// are commonly padded to an alignment boundary, so `bytesPerRow` can
    /// exceed `width` — a linear scan over the raw byte count then reads that
    /// trailing padding as if it were pixels. That padding is uninitialised
    /// memory, not zero, so it silently inflates the count.
    static func countForegroundPixels(
        bytes: UnsafePointer<UInt8>, width: Int, height: Int, bytesPerRow: Int, threshold: UInt8 = 128
    ) -> Int {
        var count = 0
        for y in 0 ..< height {
            let row = y * bytesPerRow
            for x in 0 ..< width where bytes[row + x] >= threshold {
                count += 1
            }
        }
        return count
    }

    static func uncertaintyCm2(areaCm2: Double) -> Double {
        areaCm2 * uncertaintyFraction
    }

    /// Single ± cm² voice for a displayed area — rounds like
    /// `uncertaintyDisplay`, not truncates, so the same position can't read
    /// 1 cm² differently depending on which screen shows it (Plan I6).
    /// Callers append their own unit/style (bare hero number vs "N cm²").
    static func areaDisplay(_ cm2: Double) -> String {
        "\(Int(cm2.rounded()))"
    }

    /// Single ± cm² voice shared by every screen that shows uncertainty
    /// (RevealStep, PositionDetailView, …) so the same quantity never reads
    /// as two different numbers depending on where it's displayed.
    static func uncertaintyDisplay(_ cm2: Double) -> String {
        "±\(Int(cm2.rounded())) cm²"
    }

    // MARK: - Wheel-ruler verification (Plan K — optional, never gates capture)

    /// Approximates a tire's overall (inflated) diameter from its rim's ISO
    /// bead-seat diameter and tire width — good to ~±1-2%, plenty for a
    /// mis-entry check at the disagreement threshold below.
    static func overallWheelDiameterMm(beadSeatMm: Double, tireWidthMm: Double) -> Double {
        beadSeatMm + 2 * tireWidthMm
    }

    /// The tire-width field reads in whichever unit matches the rim
    /// standard's convention (mm for road/gravel, inches for MTB) — this
    /// converts what the rider typed into the mm the model stores.
    static func tireWidthMm(fromEntry value: Double, unit: TireWidthUnit) -> Double {
        switch unit {
        case .mm: value
        case .inches: value * 25.4
        }
    }

    /// Inverse of `tireWidthMm(fromEntry:unit:)` — for pre-filling the field
    /// when editing a bike, so a stored mm value redisplays in whichever
    /// unit its rim standard uses.
    static func tireWidthDisplayValue(fromMm mm: Double, unit: TireWidthUnit) -> Double {
        switch unit {
        case .mm: mm
        case .inches: mm / 25.4
        }
    }

    /// Scale derived from tapping the front wheel's ground contact and tire
    /// top (a vertical span, like the handlebar taps) against its known
    /// overall diameter — reuses the same tap-distance-to-scale geometry as
    /// the bar ruler, just with a different known length.
    static func wheelPixelsPerCm(groundTap: CGPoint, topTap: CGPoint, imageSize: CGSize, wheelDiameterMm: Double) -> Double {
        let wheelPixels = handlebarPixels(tap0: groundTap, tap1: topTap, imageSize: imageSize)
        return pixelsPerCm(handlebarPixels: wheelPixels, handlebarWidthMm: wheelDiameterMm)
    }

    /// Amber threshold above which the bar-tap and wheel-tap rulers disagree
    /// enough to flag a likely mis-entry (e.g. a wrong bar width) — advisory
    /// only, same posture as `isShoulderWidthPlausible`.
    static let wheelCheckDisagreementThreshold = 0.10

    /// Relative disagreement between the two independent scale estimates,
    /// expressed against the bar ruler (the ruler that stays authoritative —
    /// spec §3 forbids silent replacement). SIGNED (Plan Z3): positive means
    /// the wheel-tap ruler reads a *larger* scale than the bar ruler —
    /// equivalently, converting the wheel's tapped pixel span through the
    /// bar's scale yields a wheel diameter LARGER than its spec size (the
    /// common close-shot case, where the front wheel sits forward of the
    /// bar's own plane and reads oversized in perspective); negative means
    /// smaller/undersized.
    static func rulerDisagreementFraction(barPixelsPerCm: Double, wheelPixelsPerCm: Double) -> Double {
        (wheelPixelsPerCm - barPixelsPerCm) / barPixelsPerCm
    }

    /// Display copy for the wheel-check MetricRow — "agrees ±3%" or the
    /// amber "disagrees 18%" — shared by the reveal and detail screens so
    /// the two never drift (mirrors `shoulderWidthWarning`'s pattern).
    /// `disagreementFraction` is signed (Plan Z3); the percentage always
    /// displays unsigned.
    static func wheelCheckDisplay(_ disagreementFraction: Double) -> (text: String, isWarning: Bool) {
        let pct = Int((abs(disagreementFraction) * 100).rounded())
        if abs(disagreementFraction) <= wheelCheckDisagreementThreshold {
            return ("agrees ±\(pct)%", false)
        }
        return ("disagrees \(pct)%", true)
    }

    /// Direction-aware advisory sentence for a failing wheel check (Plan
    /// Z3) — the one place this copy lives; PositionDetailView and
    /// ComparisonView both call it rather than composing their own
    /// sentence, so the two can never drift. nil when the check passes
    /// (mirrors `shoulderWidthWarning`'s nil-is-pass shape). Oversized
    /// (measured > spec, `disagreementFraction > 0`) is the common
    /// close-shot case — the wheel sits forward of the bar's own plane, so
    /// perspective alone explains the mismatch without any bad taps.
    /// Undersized keeps a taps/bar-width framing — genuinely the likelier
    /// cause in that direction (a wheel reading smaller than spec isn't
    /// what "camera too close" produces).
    static func wheelCheckWarning(_ disagreementFraction: Double) -> String? {
        guard wheelCheckDisplay(disagreementFraction).isWarning else { return nil }
        let pct = Int((abs(disagreementFraction) * 100).rounded())
        if disagreementFraction > 0 {
            return "Front wheel reads \(pct)% larger than its spec size — usually the camera was too close (the wheel sits forward of the bars). Area may read high; try standing back and zooming."
        }
        return "Front wheel reads \(pct)% smaller than its spec size — check your taps and the bike's bar width."
    }

    // MARK: - Bike coverage (Plan Z4) — subject-lift diagnostic

    /// Display copy for the "Bike coverage" diagnostic row —
    /// `MatteRenderer.bikeCoverageFraction`'s result as a whole percent, or
    /// "—" when there's no subject mask to measure (old positions, or
    /// side-on which never has one). Reading ~0% on a night shot where the
    /// subject lift found no bike is expected and correct (Plan Z8 is the
    /// separate investigation into why), not a bug this row is meant to hide.
    static func bikeCoverageDisplay(_ fraction: Double?) -> String {
        guard let fraction else { return "—" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    // MARK: - Noise floor

    /// Two independent measurements' uncertainties combine in quadrature, not
    /// by simple addition — the standard rule for combining independent errors.
    static func combinedNoiseCm2(uncertaintyA: Double, uncertaintyB: Double) -> Double {
        (uncertaintyA * uncertaintyA + uncertaintyB * uncertaintyB).squareRoot()
    }

    /// A delta smaller than the combined noise floor can't be told apart from
    /// measurement jitter — the spec's "single most important honesty feature".
    static func isDistinguishable(
        areaA: Double, areaB: Double, uncertaintyA: Double, uncertaintyB: Double
    ) -> Bool {
        abs(areaB - areaA) > combinedNoiseCm2(uncertaintyA: uncertaintyA, uncertaintyB: uncertaintyB)
    }

    // MARK: - Pose geometry (inputs are normalised landmark points, origin bottom-left)

    static func shoulderWidthCm(
        leftShoulderX: Double, rightShoulderX: Double,
        imageWidthPx: Int, pixelsPerCm: Double
    ) -> Double {
        let widthPx = abs(leftShoulderX - rightShoulderX) * Double(imageWidthPx)
        return widthPx / pixelsPerCm
    }

    /// A human shoulder width outside this range means the scale is probably
    /// mis-tapped (or the bike's bar width is wrong), not that the rider is
    /// genuinely that narrow/wide.
    static func isShoulderWidthPlausible(_ cm: Double) -> Bool {
        (30...60).contains(cm)
    }

    /// Copy shown when a computed shoulder width falls outside the plausible
    /// range — shared by the reveal (from a live AnalysisResult) and the
    /// detail screen (recomputed from a stored position) so the two never
    /// drift apart (Plan I4).
    static func shoulderWidthWarning(_ cm: Double) -> String? {
        guard !isShoulderWidthPlausible(cm) else { return nil }
        return "Shoulder width reads \(Int(cm.rounded())) cm — check your taps and the bike's bar width."
    }

    /// Angle of the (shoulder − hip) vector from vertical. 0° = upright, 90° = horizontal.
    static func torsoAngleDeg(shoulder: CGPoint, hip: CGPoint) -> Double {
        let dx = Double(shoulder.x - hip.x)
        let dy = Double(shoulder.y - hip.y)
        return abs(atan2(dx, dy) * 180 / .pi)
    }

    /// Interior angle at the hip between torso (hip→shoulder) and thigh (hip→knee).
    static func hipAngleDeg(shoulder: CGPoint, hip: CGPoint, knee: CGPoint) -> Double {
        let sx = Double(shoulder.x - hip.x), sy = Double(shoulder.y - hip.y)
        let kx = Double(knee.x - hip.x), ky = Double(knee.y - hip.y)
        let dot = sx * kx + sy * ky
        let magA = (sx * sx + sy * sy).squareRoot()
        let magB = (kx * kx + ky * ky).squareRoot()
        guard magA > 0, magB > 0 else { return 0 }
        let cosine = max(-1.0, min(1.0, dot / (magA * magB)))
        return acos(cosine) * 180 / .pi
    }

    /// Vertical distance the ear sits below the shoulder, in cm (positive = lower).
    static func headDropCm(
        shoulderY: Double, earY: Double,
        imageHeightPx: Int, pixelsPerCm: Double
    ) -> Double {
        (shoulderY - earY) * Double(imageHeightPx) / pixelsPerCm
    }

    // MARK: - Pose delta (Plan P1) — is this even the same position?

    /// Distinct from the ±3% noise floor (`isDistinguishable`), which asks
    /// "is the *area* delta real?" This asks "is the *position* even the
    /// same?" — a comparison can clear the noise floor yet be untrustworthy
    /// because the rider's pose drifted between shots, not their setup.
    enum PoseDeltaSeverity: Equatable {
        case note
        case warn
    }

    /// Starting points only, human-gated for on-device tuning (like every
    /// threshold in this file) — never ship a guessed number as validated.
    static let poseDeltaNoteThresholdDeg = 4.0
    static let poseDeltaWarnThresholdDeg = 8.0

    /// Angle of the shoulder line from horizontal — the frontal counterpart
    /// to `torsoAngleDeg`'s from-vertical convention, so a frontal delta and
    /// a side-on delta land on the same degree scale and can share one
    /// threshold pair below.
    static func shoulderTiltDeg(leftShoulder: CGPoint, rightShoulder: CGPoint) -> Double {
        let dx = Double(rightShoulder.x - leftShoulder.x)
        let dy = Double(rightShoulder.y - leftShoulder.y)
        return abs(atan2(dy, dx) * 180 / .pi)
    }

    /// Largest angle delta between two captured positions, across whichever
    /// channels both positions actually have (frontal shoulder tilt, torso
    /// angle, hip angle). Head drop is deliberately excluded — it's a cm
    /// figure on a different scale, not degrees. nil when there's no
    /// channel present on both sides to compare.
    static func poseAngleDelta(
        shoulderTiltDegA: Double?, shoulderTiltDegB: Double?,
        torsoAngleDegA: Double?, torsoAngleDegB: Double?,
        hipAngleDegA: Double?, hipAngleDegB: Double?
    ) -> Double? {
        let pairs: [(Double?, Double?)] = [
            (shoulderTiltDegA, shoulderTiltDegB),
            (torsoAngleDegA, torsoAngleDegB),
            (hipAngleDegA, hipAngleDegB),
        ]
        let deltas = pairs.compactMap { a, b -> Double? in
            guard let a, let b else { return nil }
            return abs(b - a)
        }
        return deltas.max()
    }

    /// Advisory copy for a pose delta between two compared positions —
    /// mirrors `shoulderWidthWarning`'s shape: nil is the pass state
    /// (silence), never a "positions match" affirmation. Flags the
    /// confound; doesn't claim to correct it (some of the delta is the
    /// rider, not the setup, and that can't be separated out).
    static func poseDeltaWarning(angleDeltaDeg: Double) -> (text: String, severity: PoseDeltaSeverity)? {
        if angleDeltaDeg >= poseDeltaWarnThresholdDeg {
            return ("Positions look substantially different — some of this delta may be you, not your setup.", .warn)
        } else if angleDeltaDeg >= poseDeltaNoteThresholdDeg {
            return ("Your position shifted a little between shots — some of this delta may be you, not your setup.", .note)
        }
        return nil
    }

    // MARK: - Side-on facing (Plan P3) — which way is the front?

    /// A side-on photo can face either direction; without knowing which,
    /// "front bag" vs "rear bag" is a coin toss (spec §3 forbids shipping
    /// those). Pure and derived from the same landmarks the side-on skeleton
    /// already stores — no new capture, no persisted guess (schema-free).
    enum Facing: Equatable {
        case left
        case right
    }

    /// Starting point only, human-gated for on-device tuning — below this,
    /// the UI shows the guess as uncertain (styled, correctable) rather than
    /// asserting it.
    static let sideOnFacingConfidenceThreshold = 0.5

    /// Three independent x-axis cues vote on facing — torso lean toward the
    /// bars, head reaching forward, knee ahead of hip — all things a riding
    /// position does toward the *front* of the bike. Agreement across the
    /// three, weighted by how large each displacement is relative to the
    /// torso's own vertical span (so it's scale-invariant across photos),
    /// produces a confidence: unanimous + pronounced lean → high; a
    /// near-upright rider (small, noisy displacements) → low, correctly
    /// signalling "don't guess."
    static func sideOnFacing(
        shoulder: CGPoint, hip: CGPoint, knee: CGPoint, ear: CGPoint
    ) -> (facing: Facing, confidence: Double) {
        let torsoLength = max(abs(Double(shoulder.y - hip.y)), 1e-6)
        let cues: [Double] = [
            Double(shoulder.x - hip.x),
            Double(ear.x - shoulder.x),
            Double(knee.x - hip.x),
        ]
        let positiveVotes = cues.filter { $0 >= 0 }.count
        let majoritySign: Double = positiveVotes * 2 >= cues.count ? 1 : -1
        let agreement = Double(cues.filter { ($0 >= 0 ? 1.0 : -1.0) == majoritySign }.count) / Double(cues.count)
        // A cue saturates to full weight once it reaches 30% of the torso's
        // vertical span — a genuinely leaned-forward rider clears this
        // easily; an upright rider (near-zero horizontal displacement) doesn't.
        let magnitudeScale = torsoLength * 0.3
        let avgMagnitude = cues.map { min(abs($0) / magnitudeScale, 1.0) }.reduce(0, +) / Double(cues.count)
        let confidence = agreement * avgMagnitude
        return (majoritySign > 0 ? .right : .left, confidence)
    }

    // MARK: - Physical overlay (ghost-compare) — two positions, one shared scale

    /// This position's physical anchor, in its own mask's cm-space (Vision
    /// convention: origin bottom-left, y increasing upward) — X from the
    /// handlebar-tap midpoint (bike centreline), Y from the ground reference
    /// (wheel-check tap when present, else `MatteRenderer.lowestForegroundUnitY`).
    /// Anchoring on the bike/ground rather than the rider's own shoulders is
    /// deliberate: it keeps bar-height changes and body drift *visible* in
    /// the overlay instead of silently re-centering them away.
    static func anchorCm(
        handlebarMidUnitX: Double, groundUnitY: Double,
        maskSize: CGSize, maskPixelsPerCm: Double
    ) -> CGPoint {
        guard maskPixelsPerCm > 0 else { return .zero }
        let cmPerUnitWidth = Double(maskSize.width) / maskPixelsPerCm
        let cmPerUnitHeight = Double(maskSize.height) / maskPixelsPerCm
        return CGPoint(x: handlebarMidUnitX * cmPerUnitWidth, y: groundUnitY * cmPerUnitHeight)
    }

    /// Where to place a position's image (explicit on-screen frame size +
    /// `.position()` centre) so its own anchor lands at a *shared* screen
    /// point, at a *shared* cm→point scale — this is what makes two
    /// independently-scaled, independently-anchored images land in one
    /// comparable overlay rather than two arbitrarily-sized layers.
    static func overlayPlacement(
        maskSize: CGSize, maskPixelsPerCm: Double, anchorCm: CGPoint,
        sharedAnchorScreenPoint: CGPoint, screenPointsPerCm: CGFloat
    ) -> (frameSize: CGSize, center: CGPoint) {
        guard maskPixelsPerCm > 0 else {
            return (frameSize: .zero, center: sharedAnchorScreenPoint)
        }
        let widthCm = Double(maskSize.width) / maskPixelsPerCm
        let heightCm = Double(maskSize.height) / maskPixelsPerCm
        let frameSize = CGSize(width: widthCm * Double(screenPointsPerCm), height: heightCm * Double(screenPointsPerCm))

        // Offset from this mask's own anchor to its geometric centre, in the
        // same Vision-convention cm space (origin bottom-left, y increasing
        // upward) `anchorCm` is expressed in.
        let centerOffsetCmX = widthCm / 2 - Double(anchorCm.x)
        let centerOffsetCmY = heightCm / 2 - Double(anchorCm.y)

        // Screen space flips y (origin top-left, y increasing downward) —
        // "further up physically" becomes "smaller screen y."
        let center = CGPoint(
            x: sharedAnchorScreenPoint.x + CGFloat(centerOffsetCmX) * screenPointsPerCm,
            y: sharedAnchorScreenPoint.y - CGFloat(centerOffsetCmY) * screenPointsPerCm
        )
        return (frameSize: frameSize, center: center)
    }

    /// This position's physical extent relative to its own anchor (Vision-cm
    /// space, not yet placed on any shared screen) — the rectangle
    /// `overlayPlacement` will draw, expressed anchor-relative so two
    /// positions' extents can be unioned (`overlayFit`) before any shared
    /// screen scale is chosen.
    static func overlayExtentCm(
        maskSize: CGSize, maskPixelsPerCm: Double, anchorCm: CGPoint
    ) -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
        guard maskPixelsPerCm > 0 else { return (0, 0, 0, 0) }
        let widthCm = Double(maskSize.width) / maskPixelsPerCm
        let heightCm = Double(maskSize.height) / maskPixelsPerCm
        return (
            minX: -Double(anchorCm.x), maxX: widthCm - Double(anchorCm.x),
            minY: -Double(anchorCm.y), maxY: heightCm - Double(anchorCm.y)
        )
    }

    /// A shared cm→point scale and shared screen anchor point that fits the
    /// union of two positions' anchor-relative extents into `containerSize`,
    /// centred, with `padding` (0–1) reserved as margin — this is what makes
    /// the overlay fit whatever device/silhouette sizes show up, rather than
    /// a hardcoded scale.
    static func overlayFit(
        extentA: (minX: Double, maxX: Double, minY: Double, maxY: Double),
        extentB: (minX: Double, maxX: Double, minY: Double, maxY: Double),
        containerSize: CGSize, padding: Double = 0.9
    ) -> (screenPointsPerCm: CGFloat, anchorScreenPoint: CGPoint) {
        let minX = min(extentA.minX, extentB.minX), maxX = max(extentA.maxX, extentB.maxX)
        let minY = min(extentA.minY, extentB.minY), maxY = max(extentA.maxY, extentB.maxY)
        let unionWidthCm = maxX - minX
        let unionHeightCm = maxY - minY
        guard unionWidthCm > 0, unionHeightCm > 0, containerSize.width > 0, containerSize.height > 0 else {
            return (1, CGPoint(x: containerSize.width / 2, y: containerSize.height / 2))
        }
        let scale = padding * min(
            Double(containerSize.width) / unionWidthCm,
            Double(containerSize.height) / unionHeightCm
        )
        let centerCmX = (minX + maxX) / 2
        let centerCmY = (minY + maxY) / 2
        // Same offset convention as overlayPlacement: a point above the
        // anchor (larger Vision-y) sits at a smaller screen-y.
        let anchorPoint = CGPoint(
            x: containerSize.width / 2 - CGFloat(centerCmX) * CGFloat(scale),
            y: containerSize.height / 2 + CGFloat(centerCmY) * CGFloat(scale)
        )
        return (CGFloat(scale), anchorPoint)
    }

    // MARK: - 3D pose geometry (Plan A6 — DEBUG comparison only; inputs are
    // Vision's root-relative joint positions in metres, (x, y, z) tuples
    // rather than `simd_float4x4` so this stays a pure, framework-light,
    // testable function. Assumes Vision's Y-axis is "up" — verify against a
    // known-upright photo before trusting the number; not wired into the
    // shipping pipeline until that verdict lands.)

    /// 3D analogue of `torsoAngleDeg`: angle of the (shoulder − hip) vector
    /// from vertical, using the full 3D lean (not just the image-plane
    /// projection) — so unlike the 2D version, this is unaffected by camera yaw.
    static func torsoAngleDeg3D(shoulder: (x: Double, y: Double, z: Double),
                                 hip: (x: Double, y: Double, z: Double)) -> Double {
        let dx = shoulder.x - hip.x
        let dy = shoulder.y - hip.y
        let dz = shoulder.z - hip.z
        let horizontal = (dx * dx + dz * dz).squareRoot()
        return abs(atan2(horizontal, dy) * 180 / .pi)
    }

    /// 3D analogue of `hipAngleDeg`: interior angle at the hip between torso
    /// (hip→shoulder) and thigh (hip→knee), generalised from 2D to 3D vectors.
    static func hipAngleDeg3D(shoulder: (x: Double, y: Double, z: Double),
                               hip: (x: Double, y: Double, z: Double),
                               knee: (x: Double, y: Double, z: Double)) -> Double {
        let sx = shoulder.x - hip.x, sy = shoulder.y - hip.y, sz = shoulder.z - hip.z
        let kx = knee.x - hip.x, ky = knee.y - hip.y, kz = knee.z - hip.z
        let dot = sx * kx + sy * ky + sz * kz
        let magA = (sx * sx + sy * sy + sz * sz).squareRoot()
        let magB = (kx * kx + ky * ky + kz * kz).squareRoot()
        guard magA > 0, magB > 0 else { return 0 }
        let cosine = max(-1.0, min(1.0, dot / (magA * magB)))
        return acos(cosine) * 180 / .pi
    }

    // MARK: - Bike swap rescale (Plan Y) — wrong-bike swap-and-rescale from
    // PositionDetailView. Masks, tap points, and pose landmarks are photo
    // geometry — the bike only enters as the mm behind the rulers, so
    // swapping is exact closed-form arithmetic on stored metrics, no
    // re-analysis. No SwiftData types below (Y1) — `BikeSwap` (Views/) wraps
    // this against the real `Position`/`Bike` models.

    /// Old→new ratio for the bar-tap ruler — `newBarMm / oldBarMm`.
    static func barRescaleRatio(oldBarMm: Double, newBarMm: Double) -> Double {
        newBarMm / oldBarMm
    }

    /// Old→new ratio for the wheelbase ruler (side-on) —
    /// `newWheelbaseMm / oldWheelbaseMm`.
    static func wheelbaseRescaleRatio(oldWheelbaseMm: Double, newWheelbaseMm: Double) -> Double {
        newWheelbaseMm / oldWheelbaseMm
    }

    /// Everything `rescaledMetrics` needs, pulled from the stored
    /// `PositionMetrics`/`Position` plus the old/new `Bike` hard points —
    /// no SwiftData types, so this (and the function below) are unit
    /// testable without a model context.
    struct BikeSwapInput {
        let pixelsPerCm: Double
        let frontalAreaCm2: Double
        let frontalAreaUncertainty: Double
        let shoulderWidthCm: Double?
        let sideOnPixelsPerCm: Double?
        let headDropCm: Double?
        /// `Position.wheelTapPoints` — [groundX, groundY, topX, topY], unit
        /// coords. nil (or not exactly 4 values) skips the wheel-check
        /// recompute entirely, same as the wheel check never having run.
        let wheelTapPoints: [Double]?
        /// Any `CGSize` sharing the source (head-on) photo's aspect ratio —
        /// the wheel-check recompute's absolute scale cancels out of the
        /// bar/wheel disagreement ratio, only the width:height ratio
        /// matters (mirrors how `AnalysisEngine` calls `wheelPixelsPerCm`
        /// with the true pixel `imageSize`, just without needing to decode
        /// the photo here).
        let imageAspect: CGSize

        /// `metrics.handlebarWidthMmUsed` — the bar width the *stored*
        /// numbers were actually derived from (Plan I3), not a live read of
        /// the old bike (which the rider could since have edited).
        let oldHandlebarWidthMm: Double
        let newHandlebarWidthMm: Double
        /// Live reads of the old/new bike are correct here (unlike the bar
        /// width above) — there's no equivalent "wheelbaseMmUsed"
        /// provenance field on `PositionMetrics`.
        let oldWheelbaseMm: Double?
        let newWheelbaseMm: Double?
        let newWheelDiameterMm: Double?
    }

    struct BikeSwapResult {
        let pixelsPerCm: Double
        let frontalAreaCm2: Double
        let frontalAreaUncertainty: Double
        let shoulderWidthCm: Double?
        let wheelCheckDisagreementFraction: Double?
        let sideOnPixelsPerCm: Double?
        let headDropCm: Double?
        let handlebarWidthMmUsed: Double
    }

    /// The closed-form swap: same tapped pixel spans, different physical
    /// hard points behind them. See the Plan Y doc's "why this needs no
    /// re-analysis" for the derivation of each field below.
    static func rescaledMetrics(_ input: BikeSwapInput) -> BikeSwapResult {
        let r = barRescaleRatio(oldBarMm: input.oldHandlebarWidthMm, newBarMm: input.newHandlebarWidthMm)
        let newPixelsPerCm = input.pixelsPerCm / r
        let newFrontalAreaCm2 = input.frontalAreaCm2 * r * r
        let newFrontalAreaUncertainty = input.frontalAreaUncertainty * r * r
        let newShoulderWidthCm = input.shoulderWidthCm.map { $0 * r }

        // Wheel check: recomputed fresh from the stored taps against the
        // NEW bike's wheel diameter (reuses wheelPixelsPerCm +
        // rulerDisagreementFraction exactly, same as AnalysisEngine's
        // capture-time derivation) rather than scaling the old fraction —
        // the stored fraction is unsigned (`abs`), so it can't be
        // algebraically un-rescaled.
        var newWheelCheck: Double?
        if let wheelTapPoints = input.wheelTapPoints, wheelTapPoints.count == 4,
           let newWheelDiameterMm = input.newWheelDiameterMm {
            let groundTap = CGPoint(x: wheelTapPoints[0], y: wheelTapPoints[1])
            let topTap = CGPoint(x: wheelTapPoints[2], y: wheelTapPoints[3])
            let newWheelPixelsPerCm = wheelPixelsPerCm(
                groundTap: groundTap, topTap: topTap,
                imageSize: input.imageAspect, wheelDiameterMm: newWheelDiameterMm
            )
            newWheelCheck = rulerDisagreementFraction(barPixelsPerCm: newPixelsPerCm, wheelPixelsPerCm: newWheelPixelsPerCm)
        }

        // Side-on: only rescales when a real wheelbase ruler produced the
        // old scale AND the new bike has a wheelbase on record — otherwise
        // both nil out (spec §3: can't defend the number, don't show it).
        // When the old scale was already nil, headDropCm (if present)
        // borrowed the frontal scale and is already hidden from display —
        // left untouched here, old-data rules keep applying (Plan Y1).
        var newSideOnPixelsPerCm: Double?
        var newHeadDropCm = input.headDropCm
        if let oldSideOnPixelsPerCm = input.sideOnPixelsPerCm {
            if let oldWheelbaseMm = input.oldWheelbaseMm, let newWheelbaseMm = input.newWheelbaseMm {
                let s = wheelbaseRescaleRatio(oldWheelbaseMm: oldWheelbaseMm, newWheelbaseMm: newWheelbaseMm)
                newSideOnPixelsPerCm = oldSideOnPixelsPerCm / s
                newHeadDropCm = input.headDropCm.map { $0 * s }
            } else {
                newSideOnPixelsPerCm = nil
                newHeadDropCm = nil
            }
        }

        return BikeSwapResult(
            pixelsPerCm: newPixelsPerCm,
            frontalAreaCm2: newFrontalAreaCm2,
            frontalAreaUncertainty: newFrontalAreaUncertainty,
            shoulderWidthCm: newShoulderWidthCm,
            wheelCheckDisagreementFraction: newWheelCheck,
            sideOnPixelsPerCm: newSideOnPixelsPerCm,
            headDropCm: newHeadDropCm,
            handlebarWidthMmUsed: input.newHandlebarWidthMm
        )
    }
}
