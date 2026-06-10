import SwiftUI
import SwiftData
#if canImport(UIKit)
import PhotosUI
import Photos
#endif

struct PositionDetailView: View {
    @Bindable var position: Position
    #if canImport(UIKit)
    @State private var uiImage: UIImage?
    #endif

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: position.label.uppercased())

                SectionDivider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Photo
                        #if canImport(UIKit)
                        if let image = uiImage {
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
        .task { await loadPhoto() }
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
    private func loadPhoto() async {
        guard let identifier = position.headOnPhotoIdentifier else { return }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else { return }
        let size = CGSize(width: 800, height: 800)
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            PHImageManager.default().requestImage(
                for: asset, targetSize: size,
                contentMode: .aspectFit, options: options
            ) { image, _ in
                uiImage = image
                continuation.resume()
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
