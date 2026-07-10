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
struct HowItWorksLink: View {
    @Binding var path: [AppScreen]

    var body: some View {
        Button {
            path.append(.howItWorks)
        } label: {
            Text("HOW THE NUMBER IS MADE →")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.Palette.acc)
        }
        .buttonStyle(PressedOpacityButtonStyle())
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

/// Two-state segmented tab bar — e.g. PHOTO/MASK, FRONTAL/SIDE-ON — shared by
/// RevealStep's mask toggle and PositionDetailView's photo/mask toggles so
/// the two near-identical copies (Plan I2) don't drift.
struct SegmentedToggleBar: View {
    let leftLabel: String
    let rightLabel: String
    @Binding var selectedRight: Bool

    // The underline slides between tabs (N7) instead of popping — same
    // namespace shared across both tabs so matchedGeometryEffect can
    // interpolate its frame from one to the other.
    @Namespace private var underlineNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            tab(leftLabel, selected: !selectedRight) { selectedRight = false }
            tab(rightLabel, selected: selectedRight) { selectedRight = true }
        }
        .frame(height: 40)
        .animation(reduceMotion ? nil : Theme.Motion.travel(0.2), value: selectedRight)
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

/// Full-height empty state for list screens.
struct EmptySlate: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.Palette.fg4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.screenMargin)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// Full-height empty state with an optional inline CTA button.
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
