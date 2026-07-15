import SwiftUI

extension View {
    /// Hides the system navigation bar. iOS-only; no-op on macOS.
    func hideNavBar() -> some View {
        #if canImport(UIKit)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
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
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.heading(19))
                    .foregroundStyle(Theme.Palette.fg)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.mono(11))
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
    }
}

/// "HOW THE NUMBER IS MADE →" — appears on every screen that shows a computed
/// number (Reveal, Detail, Comparison), linking to `HowItWorksView` (Plan A2).
/// Built on `HeaderLink` (Q8.7) rather than re-implementing its look, so the
/// two acid text-links can't drift again.
struct HowItWorksLink: View {
    @Binding var path: [AppScreen]

    var body: some View {
        HeaderLink("HOW THE NUMBER IS MADE") { path.append(.howItWorks) }
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
        .frame(height: 40)
        // R2: rapid tab-tapping should re-target the live underline
        // position, not cross-fade two fixed-duration eases.
        .animation(reduceMotion ? nil : Theme.Motion.interactive(0.3), value: selectedIndex)
    }

    private func tab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
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
                            .matchedGeometryEffect(id: "underline", in: underlineNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(Theme.Palette.fg4)
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
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, Theme.Space.lg)
                    .frame(height: Theme.Control.accentButtonHeight)
                    .background(Theme.Palette.acc)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
