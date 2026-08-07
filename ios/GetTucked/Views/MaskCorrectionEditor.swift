import SwiftUI
#if canImport(UIKit)
import UIKit

/// Rider-assisted matte correction (Plan AK5) — the rider fixes regions the
/// automated matte got wrong, and SAVE recomputes the position's frontal
/// area from the result. Two tools over one pipeline: TAP flips the whole
/// contiguous region under the finger, BRUSH paints freehand for the edges
/// TAP is too coarse for.
///
/// Presented as a full-screen cover rather than inline on the MASK tab: the
/// detail screen's photo already carries a pinch-zoom and a paging swipe,
/// and a freehand drag can't share a hit region with either without one of
/// the three losing. A dedicated surface also gives the brush a full-width
/// canvas, which a 0.03-of-long-edge brush needs to be usable at all.
///
/// The preview is the pipeline's own output, re-rendered after every
/// committed action (`MaskCorrection.workingMask`), not a separate
/// approximation — a flood fill has no cheap vector equivalent to fake, and
/// a preview that could disagree with the measurement is exactly the kind of
/// number this app isn't allowed to show. Only the in-flight brush stroke is
/// drawn as vectors, since it isn't committed yet.
struct MaskCorrectionEditor: View {
    let photo: UIImage?
    let originalMaskData: Data
    let originalAreaCm2: Double
    let aspectRatio: CGFloat
    let hasExistingCorrection: Bool
    let onSave: (MaskCorrection.Result) -> Void
    let onReset: () -> Void

    enum Tool: Equatable {
        case tap
        case brush
    }

    @Environment(\.dismiss) private var dismiss
    @State private var actions: [MaskCorrection.Action] = []
    @State private var activePoints: [CGPoint] = []
    @State private var tool: Tool = .tap
    @State private var brush: MaskCorrection.Brush = .include
    @State private var previewOverlay: UIImage?
    @State private var canvasSize: CGSize = .zero
    @State private var showResetConfirm = false

    private var toolBinding: Binding<Int> {
        Binding(
            get: { tool == .tap ? 0 : 1 },
            set: { tool = $0 == 0 ? .tap : .brush }
        )
    }

    private var brushBinding: Binding<Int> {
        Binding(
            get: { brush == .include ? 0 : 1 },
            set: { brush = $0 == 0 ? .include : .exclude }
        )
    }

    private var toolHint: String {
        tool == .tap
            ? "Tap a region to flip it in or out of the subject. Good for a whole chunk the matte got wrong."
            : "Drag to paint. Good for an edge the tap tool is too coarse for."
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "CORRECT THE MATTE") {
                    HeaderLink("CANCEL") { dismiss() }
                }

                SectionDivider()

                canvas
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)

                SegmentedToggleBar(labels: ["TAP", "BRUSH"], selectedIndex: toolBinding)

                if tool == .brush {
                    SegmentedToggleBar(labels: ["INCLUDE", "EXCLUDE"], selectedIndex: brushBinding)
                        .transition(.opacity)
                }

                SectionDivider()

                Text(toolHint)
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg3)
                    .padding(.horizontal, Theme.Space.screenMargin)
                    .padding(.vertical, Theme.Space.md)

                Spacer(minLength: 0)

                VStack(spacing: Theme.Space.sm) {
                    GhostButton(label: "UNDO") { undo() }
                        .disabled(actions.isEmpty)
                        .opacity(actions.isEmpty ? 0.4 : 1)

                    if hasExistingCorrection {
                        GhostButton(label: "REMOVE CORRECTION") { showResetConfirm = true }
                    }

                    AccentButton(label: "SAVE CORRECTION", action: save, enabled: !actions.isEmpty)
                }
                .padding(.horizontal, Theme.Space.screenMargin)
                .padding(.bottom, Theme.Space.lg)
            }
        }
        .hideNavBar()
        .animation(Theme.Motion.entrance(Theme.Motion.fast), value: tool)
        .task { await refreshPreview() }
        .confirmationDialog(
            "Remove the manual correction?", isPresented: $showResetConfirm, titleVisibility: .visible
        ) {
            Button("Remove correction", role: .destructive) {
                onReset()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This position goes back to its automated measurement.")
        }
    }

    private var canvas: some View {
        ZStack {
            Theme.Palette.bg1

            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
            }

            // The committed preview and the in-flight stroke share one
            // `Canvas` layer so an EXCLUDE stroke can erase through
            // `.destinationOut` — a preview that actually subtracts, rather
            // than a differently-coloured overlay that only implies it. The
            // photo above stays outside the layer, so erasing reveals the
            // photo rather than a hole.
            Canvas { context, size in
                if let previewOverlay {
                    context.draw(Image(uiImage: previewOverlay), in: CGRect(origin: .zero, size: size))
                }
                guard !activePoints.isEmpty else { return }
                let radius = MaskCorrection.brushRadiusUnit * max(size.width, size.height)
                var path = Path()
                if activePoints.count == 1, let point = activePoints.first {
                    path.addEllipse(in: CGRect(
                        x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2
                    ))
                } else {
                    path.addLines(activePoints)
                }
                if brush == .exclude {
                    context.blendMode = .destinationOut
                }
                let color: Color = brush == .include ? Theme.Palette.acc.opacity(0.5) : .black
                if activePoints.count == 1 {
                    context.fill(path, with: .color(color))
                } else {
                    context.stroke(path, with: .color(color), style: StrokeStyle(
                        lineWidth: radius * 2, lineCap: .round, lineJoin: .round
                    ))
                }
            }
            .accessibilityLabel("Matte correction canvas")
            .accessibilityHint(toolHint)
        }
        .contentShape(Rectangle())
        .gesture(
            // minimumDistance 0 so TAP registers at all, and so a brush
            // tap-and-release dabs rather than doing nothing. This is the
            // screen's only gesture, so unlike the detail screen's photo
            // there's nothing here to disambiguate against.
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard tool == .brush else { return }
                    activePoints.append(value.location)
                }
                .onEnded { value in
                    if tool == .tap {
                        commitTap(at: value.location)
                    } else {
                        commitStroke()
                    }
                }
        )
        .onGeometryChange(for: CGSize.self) { $0.size } action: { canvasSize = $0 }
    }

    /// Points arrive in the canvas's own point space; actions are stored in
    /// unit coordinates so they survive the jump to the stored mask's pixel
    /// resolution, which is unrelated to whatever size the canvas is on screen.
    private func unitPoint(_ point: CGPoint) -> CGPoint? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        return CGPoint(
            x: min(max(point.x / canvasSize.width, 0), 1),
            y: min(max(point.y / canvasSize.height, 0), 1)
        )
    }

    private func commitTap(at location: CGPoint) {
        guard let point = unitPoint(location) else { return }
        actions.append(.tapFlip(point))
        Task { await refreshPreview() }
    }

    private func commitStroke() {
        defer { activePoints = [] }
        guard !activePoints.isEmpty else { return }
        let points = activePoints.compactMap(unitPoint)
        guard !points.isEmpty else { return }
        actions.append(.stroke(MaskCorrection.Stroke(brush: brush, points: points)))
        Task { await refreshPreview() }
    }

    private func undo() {
        guard actions.popLast() != nil else { return }
        Task { await refreshPreview() }
    }

    /// Replay + tint off-main: a full-resolution flood fill plus a tinted
    /// RGBA rebuild is far too much to run on the main actor between
    /// touches.
    private func refreshPreview() async {
        let maskData = originalMaskData
        let replayed = actions
        let overlay = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let mask = MaskCorrection.workingMask(originalMaskData: maskData, actions: replayed) else {
                return nil
            }
            return MatteRenderer.tintedOverlay(mask: mask, color: UIColor(Theme.Palette.acc), alpha: 0.5)
        }.value
        previewOverlay = overlay
    }

    private func save() {
        guard let result = MaskCorrection.corrected(
            originalMaskData: originalMaskData, actions: actions, originalAreaCm2: originalAreaCm2
        ) else { return }
        onSave(result)
        dismiss()
    }
}
#endif
