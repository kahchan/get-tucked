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
        .animation(Theme.Motion.entrance(Theme.Motion.fast), value: configuration.isPressed)
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
        .animation(Theme.Motion.entrance(Theme.Motion.fast), value: configuration.isPressed)
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

/// Uppercase field label above a `MonoField`.
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.mono(11, weight: .bold))
            .foregroundStyle(Theme.Palette.fg2)
            .kerning(0.8)
            .padding(.horizontal, Theme.Space.lg)
    }
}

/// Underlined mono text field — the app's single text-entry style.
struct MonoField: View {
    let placeholder: String
    @Binding var text: String
    var numericOnly: Bool = false

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Theme.mono(18))
            .foregroundStyle(Theme.Palette.fg)
            #if canImport(UIKit)
            // .decimalPad, not .numberPad — tire width in inches (e.g. "2.1")
            // needs a decimal point; whole-number fields work fine on it too.
            .keyboardType(numericOnly ? .decimalPad : .default)
            #endif
            .padding(.horizontal, Theme.Space.lg)
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
