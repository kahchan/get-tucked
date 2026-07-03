import SwiftUI
import SwiftData
#if canImport(UIKit)
import PhotosUI
import Photos
#endif

struct PositionDetailView: View {
    @Bindable var position: Position
    #if canImport(UIKit)
    @State private var headOnImage: UIImage?
    @State private var sideOnImage: UIImage?
    #endif
    @State private var showingSideOn = false

    private var hasSideOn: Bool { position.sideOnPhotoIdentifier != nil }

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
                            PhotoToggle(showingSideOn: $showingSideOn)
                            SectionDivider()
                        }

                        // Photo
                        #if canImport(UIKit)
                        let displayImage = showingSideOn ? sideOnImage : headOnImage
                        if let image = displayImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .background(Theme.Palette.bg1)
                        } else {
                            photoPlaceholder
                        }
                        #else
                        photoPlaceholder
                        #endif

                        SectionDivider()

                        if let metrics = position.metrics {
                            MetricsSection(metrics: metrics)
                        } else {
                            Text("No metrics computed.")
                                .font(Theme.mono(13))
                                .foregroundStyle(Theme.Palette.fg3)
                                .padding(Theme.Space.lg)
                        }

                        SectionDivider()

                        if let bike = position.bike {
                            MetricRow(key: "Bike", value: bike.nickname)
                                .padding(.horizontal, Theme.Space.lg)
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
                            .padding(Theme.Space.lg)
                        }
                    }
                }
            }
        }
        .hideNavBar()
        #if canImport(UIKit)
        .task { await loadPhotos() }
        #endif
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
        sideOnImage = await loadAsset(identifier: position.sideOnPhotoIdentifier)
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

// MARK: - Photo toggle

private struct PhotoToggle: View {
    @Binding var showingSideOn: Bool

    var body: some View {
        HStack(spacing: 0) {
            ToggleTab(label: "FRONTAL", selected: !showingSideOn) { showingSideOn = false }
            ToggleTab(label: "SIDE-ON", selected: showingSideOn)  { showingSideOn = true }
        }
        .frame(height: 40)
    }
}

private struct ToggleTab: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(11, weight: selected ? .bold : .regular))
                .foregroundStyle(selected ? Theme.Palette.acc : Theme.Palette.fg3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if selected {
                        Rectangle()
                            .fill(Theme.Palette.acc)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Metrics section

private struct MetricsSection: View {
    let metrics: PositionMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FRONTAL AREA")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.Palette.fg4)
                    .kerning(0.3)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(Int(metrics.frontalAreaCm2))")
                        .font(Theme.mono(60, weight: .bold))
                        .foregroundStyle(Theme.Palette.acc)
                    Text("cm²")
                        .font(Theme.mono(18))
                        .foregroundStyle(Theme.Palette.fg3)
                }

                Text("±\(String(format: "%.1f", metrics.frontalAreaUncertainty)) cm²")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.Palette.fg4)
            }
            .padding(.horizontal, Theme.Space.lg)
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
                if let d = metrics.headDropCm {
                    MetricRow(key: "Head drop", value: "\(String(format: "%.1f", d)) cm")
                }
                MetricRow(
                    key: "Scale",
                    value: "\(String(format: "%.1f", metrics.pixelsPerCm)) px/cm"
                )
                MetricRow(key: "Foreground pixels", value: "\(metrics.foregroundPixelCount)")
                MetricRow(
                    key: "Computed",
                    value: metrics.computedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
            .padding(.horizontal, Theme.Space.lg)
        }
    }
}
