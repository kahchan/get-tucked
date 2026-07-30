import SwiftUI

// MARK: - Accessibility number formatting (Plan AK9)
//
// A hero number like "7488 cm²" is read by VoiceOver as bare digits plus a
// glyph — this builds the spoken sentence a sighted user gets from the
// visual instead. Free functions, not part of AnalysisMath (Plan AK's Part 1
// is off limits here) — purely a display-string concern.

/// Thousands-grouped whole number for speech — VoiceOver reads digit groups
/// the same either way, but this keeps every spoken number's rounding rule
/// identical to its on-screen counterpart (`Int(_.rounded())`).
func accessibilityGroupedNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
}

/// Shared by every hero frontal-area number (RevealStep, PositionDetailView's
/// MetricsSection) so the spoken form can't drift between screens.
func frontalAreaAccessibilityLabel(_ cm2: Double) -> String {
    "Frontal area, \(accessibilityGroupedNumber(cm2)) square centimetres"
}

extension View {
    /// Hides the system navigation bar. iOS-only; no-op on macOS.
    func hideNavBar() -> some View {
        #if canImport(UIKit)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Drop shadow for HUD glyphs sitting directly over the live camera feed,
    /// where palette contrast against a scrim is meaningless against a bright
    /// or cluttered scene (Plan AI4) — a shadow holds legibility regardless
    /// of what's behind it.
    func hudText() -> some View {
        shadow(color: .black.opacity(0.6), radius: 2, y: 1)
    }
}

/// Standard in-app nav header row (not system NavigationView title).
struct NavHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center) {
            // Both sides of the row reserve the same minimum height
            // (iconTapTarget), top-anchored — so the title sits at a fixed
            // offset from the row's top whether or not a subtitle is
            // present, and whether trailing() is an icon or empty. Without
            // this, a taller trailing icon (or a missing subtitle) shifts
            // the title's own position, which the floating BackButton
            // (positioned independently, per screen) can't track.
            // AK8 on-device finding (AX5, not fixed here — see report): the
            // subtitle truncates with "…" past ~4 wrapped lines instead of
            // showing in full. `.fixedSize(vertical: true)` stops the
            // truncation but this VStack sits in a non-scrolling column
            // ahead of a ScrollView (BikeSetupView and others); when forced
            // to its full ideal height it overflows into that ScrollView's
            // content instead of pushing it down — an unclipped-overflow
            // regression worse than the truncation it replaces. Left as
            // graceful truncation pending a real structural fix (NavHeader
            // subtitles kept short, or the whole header made part of the
            // scroll region) — a bigger change than this sweep's scope.
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.heading(19))
                    .foregroundStyle(Theme.Palette.fg)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.Palette.fg3)
                }
            }
            .frame(minHeight: Theme.Control.iconTapTarget, alignment: .top)
            Spacer()
            trailing()
                .frame(minHeight: Theme.Control.iconTapTarget)
        }
        .padding(.leading, Theme.Control.headerTitleInset)
        .padding(.trailing, Theme.Space.screenMargin)
        .padding(.top, Theme.Space.sm)
        .padding(.bottom, Theme.Control.headerBottomPad)
        .frame(maxWidth: .infinity)
    }
}

extension NavHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
    }
}

/// `.hdr-link` — small acid-yellow text link for a NavHeader's trailing slot,
/// e.g. "LEADERBOARD →". The only persistent cross-screen affordance left
/// once the hamburger index is gone (Plan E1).
struct HeaderLink: View {
    let label: String
    let action: () -> Void

    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text("\(label.uppercased()) →")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.Palette.acc)
                .kerning(0.8)
        }
        .buttonStyle(PressedOpacityButtonStyle())
        // The visible glyph is "LABEL →" as one string — without this,
        // VoiceOver reads the trailing arrow character aloud too.
        .accessibilityLabel(label)
    }
}

/// "HOW THE NUMBER IS MADE →" — appears on every screen that shows a computed
/// number (Reveal, Detail, Comparison), linking to `HowItWorksView` (Plan A2).
/// Built on `HeaderLink` (Q8.7) rather than re-implementing its look, so the
/// two acid text-links can't drift again. Self-centering (Kah, on-device:
/// it was left-aligned on some screens and centered on others, since
/// `HeaderLink` has no frame of its own and just inherits whatever
/// alignment its parent VStack happens to use) — always centered here so
/// call sites can't drift into that inconsistency again either.
struct HowItWorksLink: View {
    @Binding var path: [AppScreen]

    var body: some View {
        HeaderLink("HOW THE NUMBER IS MADE") { path.append(.howItWorks) }
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// Shared press feedback for plain text links (N8) — opacity dip, 0.1s.
private struct PressedOpacityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(Theme.Motion.press(configuration.isPressed), value: configuration.isPressed)
    }
}

/// Touch-down feedback for `.plain`-style tappable rows (Plan R4, skill §1)
/// — on iOS, `.plain` on custom row content shows nothing at all on touch-
/// down by itself, and that's the foundation everything else sits on. A
/// `bg1` background flash (rows sit on `bg0`) reads as an instant response.
/// Not for the selection checkbox (has its own selection visual) or chips
/// (bordered, already state-ful) — just the open-for-detail row targets.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.Palette.bg1 : Color.clear)
            .animation(Theme.Motion.press(configuration.isPressed), value: configuration.isPressed)
    }
}

/// PHOTO / MASK / BONES segment selection, shared by RevealStep and
/// PositionDetailView (frontal and side-on) so the identical three-way
/// toggle logic (Plan O) doesn't drift between them.
enum PhotoSegment: Equatable {
    case photo, mask, bones

    var label: String {
        switch self {
        case .photo: "PHOTO"
        case .mask: "MASK"
        case .bones: "BONES"
        }
    }
}

/// N-segment tab bar — PHOTO/MASK, FRONTAL/SIDE-ON, PHOTO/MASK/BONES (Plan O)
/// — shared by RevealStep and PositionDetailView's toggles so the
/// near-identical copies (Plan I2) don't drift. Generalised from a two-state
/// bar to N labels/index (Plan O4) when the BONES segment needed a third slot.
struct SegmentedToggleBar: View {
    let labels: [String]
    @Binding var selectedIndex: Int

    // The underline slides between tabs (N7) instead of popping — same
    // namespace shared across every tab so matchedGeometryEffect can
    // interpolate its frame from one to the other, across any number of slots.
    @Namespace private var underlineNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                tab(labels[index], selected: selectedIndex == index) { selectedIndex = index }
            }
        }
        .frame(minHeight: 40)
        // R2: rapid tab-tapping should re-target the live underline
        // position, not cross-fade two fixed-duration eases.
        .animation(reduceMotion ? nil : Theme.Motion.interactive(0.3), value: selectedIndex)
    }

    private func tab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(11, weight: selected ? .bold : .regular))
                .foregroundStyle(selected ? Theme.Palette.acc : Theme.Palette.fg3)
                // Height comes from the label plus this padding, never from the
                // parent: a greedy `maxHeight: .infinity` here used to be
                // clamped by a fixed bar height, so once the bar relaxed to a
                // `minHeight` floor the tabs stretched to fill whatever space
                // the screen had going spare (Kah, on-device: the sort bar ate
                // half the positions list).
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    if selected {
                        Rectangle()
                            .fill(Theme.Palette.acc)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "underline", in: underlineNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        // Selection today is acid colour + a 2pt underline alone — both
        // invisible to VoiceOver and to colourblind users (Plan AK9).
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Full-height empty state with an optional inline CTA button (Q8.6: merged
/// what used to be a separate `EmptySlate` — same component with and
/// without a CTA, so the CTA is simply optional here).
struct EmptyStateView: View {
    let message: String
    var ctaLabel: String? = nil
    var ctaAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Spacer()
            Text(message)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.Palette.fg2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.screenMargin)

            if let ctaLabel, let ctaAction {
                Button(action: ctaAction) {
                    HStack(spacing: Theme.Space.sm) {
                        Text(ctaLabel.uppercased())
                            .font(Theme.mono(14, weight: .bold))
                            .kerning(0.5)
                        Text("→")
                            .font(Theme.mono(14, weight: .bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, Theme.Space.lg)
                    .frame(minHeight: Theme.Control.accentButtonHeight)
                    .background(Theme.Palette.acc)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ctaLabel)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
