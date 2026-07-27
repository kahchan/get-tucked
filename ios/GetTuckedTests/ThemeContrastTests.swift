import XCTest
import SwiftUI
@testable import GetTucked

/// Plan AI: pins the token contract stated in `Theme.Palette`'s ramp comment —
/// every text token clears WCAG 2.1's 4.5:1 floor against `bg0`, and `fg4`
/// (non-text-only) deliberately does not, so a future edit that quietly
/// promotes `fg4` to body text gets caught here instead of on a screen.
/// Luminance maths lives in this file, not production code, since nothing
/// else in the app needs it.
final class ThemeContrastTests: XCTestCase {
    private let bg0 = Theme.Palette.bg0

    private func components(of color: Color) -> (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    /// WCAG 2.1 relative luminance (§1.4.3): each channel is linearised, then
    /// weighted by human luminance sensitivity.
    private func relativeLuminance(_ color: Color) -> Double {
        let (r, g, b) = components(of: color)
        func linearize(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    /// WCAG 2.1 contrast ratio (§1.4.3): lighter luminance over darker,
    /// each offset by 0.05.
    private func contrastRatio(_ a: Color, _ b: Color) -> Double {
        let lA = relativeLuminance(a)
        let lB = relativeLuminance(b)
        let lighter = max(lA, lB)
        let darker = min(lA, lB)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func assertPassesFloor(_ color: Color, expected: Double, name: String, file: StaticString = #filePath, line: UInt = #line) {
        let ratio = contrastRatio(color, bg0)
        XCTAssertEqual(ratio, expected, accuracy: 0.05, "\(name) ratio drifted from its measured value", file: file, line: line)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name) must clear WCAG 2.1's 4.5:1 floor for text", file: file, line: line)
    }

    func testFgClearsContrastFloor() {
        assertPassesFloor(Theme.Palette.fg, expected: 17.26, name: "fg")
    }

    func testFg2ClearsContrastFloor() {
        assertPassesFloor(Theme.Palette.fg2, expected: 9.23, name: "fg2")
    }

    func testFg3ClearsContrastFloor() {
        assertPassesFloor(Theme.Palette.fg3, expected: 5.80, name: "fg3")
    }

    func testAccClearsContrastFloor() {
        assertPassesFloor(Theme.Palette.acc, expected: 15.67, name: "acc")
    }

    func testAmbClearsContrastFloor() {
        assertPassesFloor(Theme.Palette.amb, expected: 9.04, name: "amb")
    }

    /// `fg4` is documented in `Theme.Palette` as NON-TEXT ONLY — it is
    /// expected to fail the floor. Asserting the failure (rather than
    /// omitting `fg4` from this suite) means a "fix" that quietly raises it
    /// above 4.5:1 for text use gets caught here.
    func testFg4IsBelowFloorByDesign() {
        let ratio = contrastRatio(Theme.Palette.fg4, bg0)
        XCTAssertEqual(ratio, 3.70, accuracy: 0.05, "fg4 ratio drifted from its measured value")
        XCTAssertLessThan(ratio, 4.5, "fg4 is non-text-only and must stay below the text floor")
    }
}
