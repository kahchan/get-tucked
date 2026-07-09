import SwiftUI
import SwiftData
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

    private var hasSideOn: Bool { position.sideOnPhotoIdentifier != nil || position.sideOnPhotoData != nil }

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
                            SegmentedToggleBar(leftLabel: "FRONTAL", rightLabel: "SIDE-ON", selectedRight: $showingSideOn)
                            SectionDivider()
                        }

                        // Photo
                        #if canImport(UIKit)
                        let displayImage = showingSideOn ? sideOnImage : headOnImage
                        if let image = displayImage {
                            ZStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                if !showingSideOn, showingMask, let maskOverlay {
                                    Image(uiImage: maskOverlay)
                                        .resizable()
                                        .scaledToFit()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .background(Theme.Palette.bg1)
                        } else {
                            photoPlaceholder
                        }
                        // MASK toggle only makes sense on the frontal photo — that's
                        // the one the stored mask was computed from.
                        if !showingSideOn, maskOverlay != nil {
                            SegmentedToggleBar(leftLabel: "PHOTO", rightLabel: "MASK", selectedRight: $showingMask)
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

    #if canImport(UIKit)
    private func loadPhotos() async {
        // Head-on is captured live and persisted as bytes; prefer that over any
        // PHAsset re-fetch. Side-on comes from the picker (asset identifier).
        if let data = position.photosData, let image = UIImage(data: data) {
            headOnImage = image
        } else {
            headOnImage = await loadAsset(identifier: position.headOnPhotoIdentifier)
        }
        // Side-on: live capture has no PHAsset identifier — prefer the stored
        // bytes over a re-fetch, same as head-on (Plan G0).
        if let data = position.sideOnPhotoData, let image = UIImage(data: data) {
            sideOnImage = image
        } else {
            sideOnImage = await loadAsset(identifier: position.sideOnPhotoIdentifier)
        }
        buildMaskOverlay()
    }

    /// Builds the PHOTO/MASK overlay once (not per layout pass). Skips
    /// silently — no toggle offered — when there's no stored mask or when
    /// the mask and photo disagree on aspect ratio (Plan I5): a mismatched
    /// composite would tint the wrong region rather than hug the rider.
    private func buildMaskOverlay() {
        guard let maskData = position.maskData,
              let mask = UIImage(data: maskData),
              let cgMask = mask.cgImage,
              let photo = headOnImage,
              let cgPhoto = photo.cgImage else { return }
        guard AnalysisMath.maskMatchesSourceAspect(
            maskWidth: cgMask.width, maskHeight: cgMask.height,
            sourceWidth: cgPhoto.width, sourceHeight: cgPhoto.height
        ) else { return }
        maskOverlay = MatteRenderer.tintedOverlay(mask: cgMask, color: UIColor(Theme.Palette.acc), alpha: 0.5)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FRONTAL AREA")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg3)
                    .kerning(0.3)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(AnalysisMath.areaDisplay(metrics.frontalAreaCm2))
                        .font(Theme.mono(60, weight: .bold))
                        .foregroundStyle(Theme.Palette.acc)
                    Text("cm²")
                        .font(Theme.mono(18))
                        .foregroundStyle(Theme.Palette.fg3)
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
