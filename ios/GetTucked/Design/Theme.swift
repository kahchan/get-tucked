import SwiftUI

// Get Tucked design tokens. Source of truth for the visual system:
// near-black canvas, acid-yellow accent, 0px radius everywhere,
// Space Mono for numbers/labels, Barlow Condensed (bold) for headings.
// Do NOT apply the global mire·studio rounded system here.

enum Theme {
    // MARK: Color tokens

    enum Palette {
        static let bg0 = Color(hex: 0x080808)   // primary canvas
        static let bg1 = Color(hex: 0x101010)   // secondary surface
        static let bg2 = Color(hex: 0x161616)   // tertiary surface
        static let line = Color(hex: 0x262626)   // divider / border
        static let line2 = Color(hex: 0x1A1A1A)  // subtle divider
        static let fg = Color(hex: 0xEEEEEE)     // primary text
        static let fg2 = Color(hex: 0x999999)    // secondary text
        static let fg3 = Color(hex: 0x777777)    // tertiary text
        static let fg4 = Color(hex: 0x555555)    // dim labels
        static let acc = Color(hex: 0xD9F020)    // acid-yellow accent
        static let amb = Color(hex: 0xE8A020)    // amber warning
    }

    // MARK: Typography
    //
    // Custom fonts are bundled in Resources/Fonts and registered via Info.plist
    // (UIAppFonts). Until the TTFs land, `.custom` falls back to the system font,
    // so views built against these helpers compile and render before the binaries
    // are added — the fallback is intentional, not a bug.

    enum FontName {
        static let mono = "SpaceMono-Regular"
        static let monoBold = "SpaceMono-Bold"
        static let heading = "BarlowCondensed-Bold"
    }

    /// Monospace — numbers, labels, metric rows. Scales with Dynamic Type.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = weight == .regular ? FontName.mono : FontName.monoBold
        return .custom(name, size: size, relativeTo: .body)
    }

    /// Condensed display — headings only. Scales with Dynamic Type.
    static func heading(_ size: CGFloat) -> Font {
        .custom(FontName.heading, size: size, relativeTo: .title)
    }

    // MARK: Layout tokens

    enum Radius {
        /// The whole design is hard-edged. There is no non-zero radius token.
        static let none: CGFloat = 0
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 40
        /// Horizontal screen margin — the distance from the screen edge to
        /// any content, used in place of `lg` for that one purpose so the
        /// margin can move independently of general vertical rhythm.
        static let screenMargin: CGFloat = 16
    }

    enum Control {
        static let accentButtonHeight: CGFloat = 52
        static let ghostButtonHeight: CGFloat = 48
        static let metricRowHeight: CGFloat = 50
        static let hairline: CGFloat = 1
        /// Leading title inset for pushed screens (NavHeader), wide enough to
        /// clear the floating BackButton — a centred glyph in its own 44pt
        /// tap target sitting at the screen margin, so this only needs to
        /// clear the tap target plus a real gap.
        static let headerTitleInset: CGFloat = 52
        /// Shared by every bare-icon control (back arrow, close, add, gear) so
        /// icons read as one consistent family across the app, not a mix of
        /// whatever size felt right on each screen.
        static let iconSize: CGFloat = 26
        /// Apple HIG minimum tappable target — applies regardless of how
        /// small the glyph inside it is.
        static let iconTapTarget: CGFloat = 44
        /// Gap between a bespoke or shared header and the SectionDivider
        /// beneath it.
        static let headerBottomPad: CGFloat = 16
    }

    // MARK: Motion tokens
    //
    // Hard-edged in form, eased in timing (Plan N): shapes stay hard-edged —
    // wipes, scan lines, clipped reveals, no springs/bounce/blur/overshoot —
    // but every duration below runs on an easing curve. Nothing is linear.

    enum Motion {
        static let fast: Double = 0.15      // press states, handle pops, banner text
        static let base: Double = 0.25      // step fades, toggles, list changes
        static let gentle: Double = 0.45    // photo fade-in, section entrances
        static let sweep: Double = 0.90     // scan wipe across the matte
        static let roll: Double = 0.80      // hero number count-up
        static let stagger: Double = 0.05   // per-row cascade offset

        /// Entrances: content arriving — decelerate in.
        static func entrance(_ d: Double = base) -> Animation { .easeOut(duration: d) }
        /// Travel: sweeps, slides, reorders — accelerate in, settle out.
        static func travel(_ d: Double = base) -> Animation { .easeInOut(duration: d) }
    }
}

extension Color {
    /// 0xRRGGBB literal → Color (sRGB, opaque).
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
