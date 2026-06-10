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
        static let mono = "Space Mono"
        static let monoBold = "Space Mono"        // bold via weight on the family
        static let heading = "Barlow Condensed"
    }

    /// Monospace — numbers, labels, metric rows.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(FontName.mono, size: size).weight(weight)
    }

    /// Condensed display — headings only.
    static func heading(_ size: CGFloat) -> Font {
        .custom(FontName.heading, size: size).weight(.bold)
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
    }

    enum Control {
        static let accentButtonHeight: CGFloat = 52
        static let ghostButtonHeight: CGFloat = 48
        static let metricRowHeight: CGFloat = 50
        static let hairline: CGFloat = 1
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
