import SwiftUI

// MARK: - AccentButton

/// Full-width primary CTA. Acid-yellow fill, Space Mono bold uppercase, arrow suffix.
struct AccentButton: View {
    let label: String
    let action: () -> Void
    var enabled: Bool = true

    var body: some View {
        Button(action: action) {
            Color.clear
        }
        .disabled(!enabled)
        .buttonStyle(AccentButtonStyle(title: label, enabled: enabled))
        .accessibilityLabel(label)
    }
}

/// Custom style (not `.plain`) so the pressed state can reach the arrow
/// glyph specifically (N8) — `configuration.label` is unused; the style
/// builds the row itself from `title`/`enabled` so `isPressed` can nudge
/// just the arrow. Hard-edged: darken + nudge only, no scale change.
private struct AccentButtonStyle: ButtonStyle {
    let title: String
    let enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Text(title.uppercased())
                .font(Theme.mono(14, weight: .bold))
                .kerning(0.5)
            Spacer()
            Text("→")
                .font(Theme.mono(14, weight: .bold))
                .offset(x: configuration.isPressed ? 3 : 0)
        }
        .foregroundStyle(enabled ? Color.black : Theme.Palette.fg4)
        .padding(.horizontal, Theme.Space.md)
        .frame(maxWidth: .infinity)
        .frame(height: Theme.Control.accentButtonHeight)
        .background(enabled ? Theme.Palette.acc : Theme.Palette.line)
        .overlay(configuration.isPressed ? Color.black.opacity(0.12) : Color.clear)
        .animation(Theme.Motion.press(configuration.isPressed), value: configuration.isPressed)
        .animation(Theme.Motion.entrance(), value: enabled)
    }
}

// MARK: - GhostButton

/// Full-width secondary action. 1px border, transparent fill.
struct GhostButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
        }
        .buttonStyle(GhostButtonStyle(title: label))
        .accessibilityLabel(label)
    }
}

private struct GhostButtonStyle: ButtonStyle {
    let title: String

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Text(title.uppercased())
                .font(Theme.mono(13, weight: .regular))
                .kerning(0.5)
            Spacer()
        }
        .foregroundStyle(Theme.Palette.fg)
        .padding(.horizontal, Theme.Space.md)
        .frame(maxWidth: .infinity)
        .frame(height: Theme.Control.ghostButtonHeight)
        .overlay(
            Rectangle()
                .stroke(Theme.Palette.line, lineWidth: Theme.Control.hairline)
        )
        .overlay(configuration.isPressed ? Color.black.opacity(0.12) : Color.clear)
        .animation(Theme.Motion.press(configuration.isPressed), value: configuration.isPressed)
    }
}

// MARK: - MetricRow

/// Key / value row. Space Mono throughout, 1px line2 below.
struct MetricRow: View {
    let key: String
    let value: String
    var valueColor: Color = Theme.Palette.fg

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(key.uppercased())
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.Palette.fg2)
                    .kerning(0.3)
                Spacer()
                Text(value)
                    .font(Theme.mono(15, weight: .bold))
                    .foregroundStyle(valueColor)
            }
            .frame(height: Theme.Control.metricRowHeight)

            Rectangle()
                .fill(Theme.Palette.line2)
                .frame(height: Theme.Control.hairline)
        }
    }
}

// MARK: - SectionDivider

/// 1px full-width line separator.
struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Palette.line)
            .frame(height: Theme.Control.hairline)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - FieldLabel / MonoField

/// Uppercase field label above a `MonoField`. Q8.2: no internal horizontal
/// padding — screen-level margin is the caller's container's job, not a
/// field component's, so every call site gets exactly one margin instead of
/// stacking its own on top of this.
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.mono(11, weight: .bold))
            .foregroundStyle(Theme.Palette.fg2)
            .kerning(0.8)
    }
}

/// Underlined mono text field — the app's single text-entry style.
struct MonoField: View {
    let placeholder: String
    @Binding var text: String
    var numericOnly: Bool = false

    // Own, private focus state (independent of whatever FocusState a call
    // site may also bind for its own commit-on-blur logic — SwiftUI allows
    // multiple independent `.focused()` bindings on the same responder).
    // Scopes the Done button to *this* field: when several numeric fields
    // share a screen, only the one actually focused contributes toolbar
    // content, so the keyboard accessory bar never shows more than one.
    #if canImport(UIKit)
    @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Theme.mono(18))
            .foregroundStyle(Theme.Palette.fg)
            #if canImport(UIKit)
            // .decimalPad, not .numberPad — tire width in inches (e.g. "2.1")
            // needs a decimal point; whole-number fields work fine on it too.
            .keyboardType(numericOnly ? .decimalPad : .default)
            .focused($isFocused)
            // decimalPad has no Return key, so without this a numeric field
            // has no way to dismiss its own keyboard (Kah, on-device) — every
            // numeric field gets this for free rather than each call site
            // wiring its own FocusState just to add a Done button.
            .toolbar {
                if numericOnly && isFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isFocused = false }
                            .font(Theme.mono(14, weight: .bold))
                            .foregroundStyle(Theme.Palette.acc)
                    }
                }
            }
            #endif
            .padding(.top, Theme.Space.xs)
            .padding(.bottom, Theme.Space.sm)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.Palette.line)
                    .frame(height: 1)
            }
    }
}

// MARK: - StatusPill

/// Dot + label chip whose border color tracks a state.
enum PillState: Equatable {
    case unknown   // dim
    case warning   // amber border
    case ok        // accent border
}

struct StatusPill: View {
    let label: String
    let state: PillState

    // Blinks once (opacity dip) on transition into .ok (N8).
    @State private var dotOpacity: Double = 1

    private var borderColor: Color {
        switch state {
        case .unknown: Theme.Palette.line
        case .warning: Theme.Palette.amb
        case .ok:      Theme.Palette.acc
        }
    }

    private var dotColor: Color {
        switch state {
        case .unknown: Theme.Palette.fg4
        case .warning: Theme.Palette.amb
        case .ok:      Theme.Palette.acc
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
                .opacity(dotOpacity)
            Text(label.uppercased())
                .font(Theme.mono(11))
                .foregroundStyle(dotColor)
                .kerning(0.3)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .overlay(
            Rectangle()
                .stroke(borderColor, lineWidth: Theme.Control.hairline)
        )
        .animation(Theme.Motion.entrance(), value: state)
        .onChange(of: state) { oldValue, newValue in
            guard newValue == .ok, oldValue != .ok else { return }
            withAnimation(Theme.Motion.entrance(Theme.Motion.fast)) {
                dotOpacity = 0.3
            } completion: {
                withAnimation(Theme.Motion.entrance(Theme.Motion.fast)) {
                    dotOpacity = 1
                }
            }
        }
    }
}

// MARK: - DetailDisclosure (Plan T)

/// Collapsed-by-default "MEASUREMENT DETAIL" disclosure — shared by
/// PositionDetailView and ComparisonView so provenance/diagnostic rows
/// (scale, bar width, foreground pixels, computed-at, and any consistency
/// signal not currently firing as a warning) sit behind one visible,
/// discoverable control instead of sharing altitude with the answer above
/// them (Kah's standing preference: discoverable, not hidden). A drawer the
/// finger can re-trigger mid-flight, hence `Theme.Motion.interactive()`
/// rather than a scripted one-shot curve; Reduce Motion drops straight to
/// the fade.
struct DetailDisclosure<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A bordered, filled row (not plain text) so this reads as a
            // control rather than another eyebrow-style section label like
            // "FRONTAL AREA"/"TIME IMPACT" above it (Kah, on-device) — the
            // acid +/− is the interactivity cue, the box is the tap target.
            Button { toggle() } label: {
                HStack(spacing: Theme.Space.xs) {
                    Text(expanded ? "−" : "+")
                        .font(Theme.mono(14, weight: .bold))
                        .foregroundStyle(Theme.Palette.acc)
                    Text(label.uppercased())
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundStyle(Theme.Palette.fg2)
                        .kerning(0.5)
                    Spacer()
                }
                .padding(.horizontal, Theme.Space.md)
                .frame(height: 40)
                .background(Theme.Palette.bg1)
                .overlay(Rectangle().stroke(Theme.Palette.line, lineWidth: Theme.Control.hairline))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                content
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func toggle() {
        if reduceMotion {
            expanded.toggle()
        } else {
            withAnimation(Theme.Motion.interactive()) { expanded.toggle() }
        }
    }
}

// MARK: - FacingChip (Plan P3)

/// Tappable side-on facing indicator — always present and correctable
/// (never a one-shot modal, never silently locked), styled by confidence: a
/// pronounced lean renders confidently in `acc`; a near-upright/ambiguous
/// read renders muted with a "?", inviting the tap instead of asserting an
/// answer it can't defend (spec §3). A tap here is local state only — it
/// doesn't persist (Plan P3.3's schema-free storage decision), so it resets
/// to the derived guess the next time this view appears.
struct FacingChip: View {
    let derivedFacing: AnalysisMath.Facing
    let confidence: Double

    @State private var override: AnalysisMath.Facing?

    private var facing: AnalysisMath.Facing { override ?? derivedFacing }
    private var isConfident: Bool { confidence >= AnalysisMath.sideOnFacingConfidenceThreshold }

    var body: some View {
        Button {
            override = facing == .left ? .right : .left
            Haptics.select()
        } label: {
            HStack(spacing: 4) {
                if facing == .left {
                    Text("◂").font(Theme.mono(10))
                }
                Text(isConfident ? "FRONT" : "FRONT?")
                    .font(Theme.mono(10, weight: .bold))
                    .kerning(0.5)
                if facing == .right {
                    Text("▸").font(Theme.mono(10))
                }
            }
            .foregroundStyle(isConfident ? Theme.Palette.acc : Theme.Palette.fg3)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Theme.Palette.bg0.opacity(0.72))
            .overlay(Rectangle().stroke(isConfident ? Theme.Palette.acc : Theme.Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
