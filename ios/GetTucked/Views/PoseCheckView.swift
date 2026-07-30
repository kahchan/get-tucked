#if DEBUG
import SwiftUI
import PhotosUI
import Vision

/// Debug-only harness for Plan A6: runs Vision's 2D (`VNDetectHumanBodyPoseRequest`,
/// the request the shipping side-on pipeline already uses) and 3D
/// (`VNDetectHumanBodyPose3DRequest`) pose requests on the same side-on photo
/// and shows both torso/hip angles side by side, so the two can be eyeballed
/// against each other under off-perpendicular framing and bike occlusion —
/// the two stresses 2D is known to struggle with. Does NOT touch
/// `AnalysisEngine`'s shipping pipeline; adopting 3D is gated on that verdict.
struct PoseCheckView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var pose2D: PoseAngles?
    @State private var pose3D: PoseAngles?
    @State private var running = false
    @State private var errorMessage: String?

    struct PoseAngles {
        let torsoAngleDeg: Double
        let hipAngleDeg: Double
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "POSE CHECK", subtitle: "3D vs 2D side-on angles (Plan A6)")
                SectionDivider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let photo {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .background(Theme.Palette.bg1)
                        }

                        if running {
                            Text("ANALYSING…")
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.Palette.fg3)
                                .padding(Theme.Space.lg)
                        }
                        if let errorMessage {
                            Text(errorMessage)
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.Palette.amb)
                                .padding(Theme.Space.lg)
                        }

                        if pose2D != nil || pose3D != nil {
                            HStack(spacing: 0) {
                                AngleColumn(label: "2D (shipping)", angles: pose2D)
                                Rectangle().fill(Theme.Palette.line).frame(width: 1)
                                AngleColumn(label: "3D (experiment)", angles: pose3D)
                            }
                            .padding(.top, Theme.Space.md)
                        }
                    }
                }

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    HStack {
                        Text("PICK A SIDE-ON PHOTO")
                            .font(Theme.mono(14, weight: .bold))
                            .kerning(0.5)
                        Spacer()
                        Text("→").font(Theme.mono(14, weight: .bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, Theme.Space.md)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Theme.Control.accentButtonHeight)
                    .background(Theme.Palette.acc)
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.md)
                .accessibilityLabel("Pick a side-on photo")
            }
        }
        .hideNavBar()
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)?.normalisedOrientation() else { return }
        photo = image
        pose2D = nil
        pose3D = nil
        errorMessage = nil
        running = true
        pose2D = await estimate2D(image)
        pose3D = await estimate3D(image)
        if pose2D == nil && pose3D == nil {
            errorMessage = "No pose detected in either request — try a clearer side-on photo."
        }
        running = false
    }

    /// Mirrors `AnalysisEngine.estimateSideOnPose` exactly (same landmarks,
    /// same confidence floor) so the 2D column reflects the shipping pipeline.
    private func estimate2D(_ image: UIImage) async -> PoseAngles? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectHumanBodyPoseRequest()
        do {
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first else { return nil }
        guard let shoulder = try? observation.recognizedPoint(.leftShoulder),
              let hip = try? observation.recognizedPoint(.leftHip),
              let knee = try? observation.recognizedPoint(.leftKnee),
              shoulder.confidence > 0.5, hip.confidence > 0.5, knee.confidence > 0.5
        else { return nil }

        return PoseAngles(
            torsoAngleDeg: AnalysisMath.torsoAngleDeg(shoulder: shoulder.location, hip: hip.location),
            hipAngleDeg: AnalysisMath.hipAngleDeg(shoulder: shoulder.location, hip: hip.location, knee: knee.location)
        )
    }

    private func estimate3D(_ image: UIImage) async -> PoseAngles? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectHumanBodyPose3DRequest()
        do {
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first else { return nil }
        guard let shoulder = try? observation.recognizedPoint(.leftShoulder),
              let hip = try? observation.recognizedPoint(.leftHip),
              let knee = try? observation.recognizedPoint(.leftKnee)
        else { return nil }

        func xyz(_ point: VNHumanBodyRecognizedPoint3D) -> (x: Double, y: Double, z: Double) {
            let t = point.position.columns.3
            return (x: Double(t.x), y: Double(t.y), z: Double(t.z))
        }

        return PoseAngles(
            torsoAngleDeg: AnalysisMath.torsoAngleDeg3D(shoulder: xyz(shoulder), hip: xyz(hip)),
            hipAngleDeg: AnalysisMath.hipAngleDeg3D(shoulder: xyz(shoulder), hip: xyz(hip), knee: xyz(knee))
        )
    }
}

private struct AngleColumn: View {
    let label: String
    let angles: PoseCheckView.PoseAngles?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(label.uppercased())
                .font(Theme.mono(10, weight: .bold))
                .foregroundStyle(Theme.Palette.fg3)
                .kerning(0.5)
            if let angles {
                Text("Torso \(Int(angles.torsoAngleDeg.rounded()))°")
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundStyle(Theme.Palette.fg)
                Text("Hip \(Int(angles.hipAngleDeg.rounded()))°")
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundStyle(Theme.Palette.fg)
            } else {
                Text("No result")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.Palette.fg4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.lg)
    }
}
#endif
