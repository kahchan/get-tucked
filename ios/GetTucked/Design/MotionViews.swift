import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Shared motion primitives for Plan N. Hard-edged in form, eased in timing —
// see Theme.Motion. Every component here degrades under Reduce Motion so
// call sites get that for free.

// MARK: - RollingNumberText

/// Animatable count-up for hero numbers. Starts at ~88% of the final value
/// (not 0 — a from-zero roll reads as a slot machine and implies precision
/// theater) and settles on `value`, rendered through the same `format`
/// closure the static display would use so the rolled value can never
/// disagree with the final displayed one.
struct RollingNumberText: View {
    let value: Double
    let format: (Double) -> String
    let font: Font
    let color: Color
    var duration: Double = Theme.Motion.roll
    var delay: Double = 0
    /// Fires when the number reaches its final value — the hook RevealStep
    /// uses to time the "number lands" haptic (Plan N2).
    var onComplete: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue: Double?

    var body: some View {
        let displayed = animatedValue ?? (reduceMotion ? value : value * 0.88)
        AnimatableRollingNumber(value: displayed, format: format, font: font, color: color)
            .onAppear {
                guard animatedValue == nil else { return }
                if reduceMotion {
                    animatedValue = value
                    onComplete?()
                } else {
                    animatedValue = value * 0.88
                    withAnimation(Theme.Motion.travel(duration).delay(delay)) {
                        animatedValue = value
                    } completion: {
                        onComplete?()
                    }
                }
            }
    }
}

/// SwiftUI interpolates `animatableData` frame-by-frame during a
/// `withAnimation` transaction, re-invoking `body` at each intermediate
/// value — that's what makes the digits actually roll, not just jump.
private struct AnimatableRollingNumber: View, Animatable {
    var value: Double
    let format: (Double) -> String
    let font: Font
    let color: Color

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
    }
}

// MARK: - ScanReveal

extension View {
    /// `progress` 0→1 reveals the content top-to-bottom; a 1px acid scan
    /// line rides the reveal edge and fades out once progress reaches 1.
    /// The caller drives `progress` with `Theme.Motion.travel(Theme.Motion.sweep)`.
    func scanReveal(progress: Double) -> some View {
        modifier(ScanRevealModifier(progress: progress))
    }
}

private struct ScanRevealModifier: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .mask(alignment: .top) {
                GeometryReader { proxy in
                    Rectangle().frame(height: max(0, proxy.size.height * progress))
                }
            }
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Theme.Palette.acc)
                        .frame(height: 1)
                        .offset(y: max(0, proxy.size.height * progress - 0.5))
                        .opacity(progress >= 1 ? 0 : 1)
                        .animation(Theme.Motion.entrance(Theme.Motion.fast), value: progress >= 1)
                }
            }
    }
}

// MARK: - Cascade

extension View {
    /// Opacity 0→1 + 8pt upward settle, `entrance(duration)`, delayed
    /// `index * stagger` after `trigger` becomes true — the per-row entrance
    /// cascade for stacked lists. Defaults match the reveal ceremony's rows;
    /// pass tighter values for a quicker cascade (e.g. Comparison's panels/
    /// table). Note: this modifier carries its own local `.animation`, which
    /// takes precedence over an ambient `withAnimation(...).delay()` around
    /// the call that flips `trigger` — flip it at the real moment the
    /// cascade should start, not via an outer delayed animation.
    func cascadeIn(index: Int, trigger: Bool, duration: Double = Theme.Motion.gentle, stagger: Double = Theme.Motion.stagger) -> some View {
        modifier(CascadeModifier(index: index, trigger: trigger, duration: duration, stagger: stagger))
    }
}

private struct CascadeModifier: ViewModifier {
    let index: Int
    let trigger: Bool
    var duration: Double = Theme.Motion.gentle
    var stagger: Double = Theme.Motion.stagger

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(trigger ? 1 : 0)
            .offset(y: trigger || reduceMotion ? 0 : 8)
            .animation(
                reduceMotion
                    ? Theme.Motion.entrance(duration)
                    : Theme.Motion.entrance(duration).delay(Double(index) * stagger),
                value: trigger
            )
    }
}

// MARK: - Haptics

/// Thin wrapper so call sites are one-liners. No-op off UIKit platforms.
enum Haptics {
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func confirm() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func select() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

// MARK: - MotionSettings

/// `@Environment(\.accessibilityReduceMotion)` covers per-view reads; this
/// is the one place imperative call sites (outside a View's body) check the
/// same setting.
enum MotionSettings {
    static var reduceMotionEnabled: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }
}

// MARK: - Previews

#Preview("RollingNumberText") {
    RollingNumberText(
        value: 4512,
        format: { AnalysisMath.areaDisplay($0) },
        font: Theme.mono(60, weight: .bold),
        color: Theme.Palette.acc
    )
    .padding()
    .background(Theme.Palette.bg0)
}

#Preview("ScanReveal") {
    struct Demo: View {
        @State private var progress: Double = 0
        var body: some View {
            Rectangle()
                .fill(Theme.Palette.acc.opacity(0.5))
                .frame(width: 240, height: 240)
                .scanReveal(progress: progress)
                .background(Theme.Palette.bg1)
                .onAppear {
                    withAnimation(Theme.Motion.travel(Theme.Motion.sweep)) { progress = 1 }
                }
        }
    }
    return Demo().padding().background(Theme.Palette.bg0)
}

#Preview("Cascade") {
    struct Demo: View {
        @State private var trigger = false
        var body: some View {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                ForEach(0..<5, id: \.self) { i in
                    Text("ROW \(i)")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.Palette.fg)
                        .cascadeIn(index: i, trigger: trigger)
                }
            }
            .padding()
            .background(Theme.Palette.bg0)
            .onAppear { trigger = true }
        }
    }
    return Demo()
}
