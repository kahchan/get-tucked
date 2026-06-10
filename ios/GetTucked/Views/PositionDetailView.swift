import SwiftUI
import SwiftData
import PhotosUI

struct PositionDetailView: View {
    @Bindable var position: Position
    @State private var uiImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let image = uiImage {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if let metrics = position.metrics {
                    MetricsCard(metrics: metrics)
                } else {
                    Text("No metrics computed.")
                        .foregroundStyle(.secondary)
                }

                if let bike = position.bike {
                    LabeledContent("Bike", value: bike.nickname)
                }

                if let packing = position.packingList, !packing.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Packing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(packing)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(position.label)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPhoto() }
    }

    private func loadPhoto() async {
        guard let identifier = position.headOnPhotoIdentifier else { return }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else { return }
        let size = CGSize(width: 800, height: 800)
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { image, _ in
                uiImage = image
                continuation.resume()
            }
        }
    }
}

struct MetricsCard: View {
    let metrics: PositionMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frontal area")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(metrics.frontalAreaCm2, specifier: "%.0f")")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                Text("cm²")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Text("±\(metrics.frontalAreaUncertainty, specifier: "%.1f") cm²")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Divider()
            LabeledContent("Scale", value: "\(metrics.pixelsPerCm, specifier: "%.1f") px/cm")
            LabeledContent("Foreground pixels", value: "\(metrics.foregroundPixelCount)")
            LabeledContent("Computed", value: metrics.computedAt.formatted(date: .abbreviated, time: .shortened))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
