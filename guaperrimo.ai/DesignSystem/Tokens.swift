//
//  Tokens.swift
//  guaperrimo.ai
//
//  Design tokens: the single source of truth for colors, type, radii and spacing.
//  Direction: "sastrería mexicana" — a warm dark workshop (obsidiana, hueso,
//  piel cognac, nopal), serif for the few words that matter, mono for numbers.
//

import SwiftUI

extension Color {
    /// Creates a color from a hex string such as "#C27A4A" or "C27A4A".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum DS {
    // MARK: Colors (warm dark)

    /// Obsidiana: the screen background.
    static let bg = Color(hex: "#171412")
    /// Cards.
    static let surface = Color(hex: "#211C19")
    /// Raised elements and selected states.
    static let surfaceRaised = Color(hex: "#2A2420")
    /// Hairlines: 1 px borders and dividers.
    static let stroke = Color(hex: "#3A322D")
    /// Outlines that must read as a control (secondary buttons, chips).
    static let strokeStrong = Color(hex: "#5A4E46")

    /// Hueso: primary text.
    static let textPrimary = Color(hex: "#EDE4DC")
    static let textSecondary = Color(hex: "#A69789")
    /// Labels and notes. Lifted slightly from the brief (#7D7068) to keep AA on `surface`.
    static let textTertiary = Color(hex: "#8E8077")

    /// Piel cognac: the one action color. Solid, never a gradient.
    static let accent = Color(hex: "#C27A4A")
    static let accentPressed = Color(hex: "#A86638")
    /// Selected fills (chips, cards): cognac at 12 %.
    static let accentSoft = accent.opacity(0.12)
    /// Text on a cognac fill (obsidiana reads at 5.4:1; hueso would not).
    static let onAccent = Color(hex: "#171412")
    /// Latón: fine details (numerals, ticks). Never a button.
    static let brass = Color(hex: "#B8925A")

    /// Nopal: confirmations and "ready".
    static let success = Color(hex: "#8DA27A")
    static let warning = Color(hex: "#E0A54E")
    static let danger = Color(hex: "#E07A6E")

    // MARK: Type

    enum Font {
        /// Screen titles.
        static let display = SwiftUI.Font.system(.title2, design: .serif)
        /// Key phrases: "Tu colorimetría: Otoño profundo", outfit names, row titles.
        static let heading = SwiftUI.Font.system(.title3, design: .serif)
        /// Smaller serif: row titles inside a screen.
        static let headingSmall = SwiftUI.Font.system(.body, design: .serif)
        /// Numerals drawn as type (steps).
        static let numeral = SwiftUI.Font.system(.title2, design: .serif)
        /// Prices, sizes, totals, distances — like an order ticket.
        static let mono = SwiftUI.Font.system(.subheadline, design: .monospaced).weight(.semibold)
        static let monoLarge = SwiftUI.Font.system(.title2, design: .monospaced).weight(.semibold)
        static let monoSmall = SwiftUI.Font.system(.caption, design: .monospaced)
        /// Small uppercase labels; pair with `.tracking(DS.labelTracking)`.
        static let label = SwiftUI.Font.caption.weight(.medium)
    }

    static let labelTracking: CGFloat = 1.2

    // MARK: Radii (4 / 8 / 12; buttons 6)

    enum Radius {
        /// Chips, thumbnails, swatches.
        static let s: CGFloat = 4
        /// Buttons.
        static let button: CGFloat = 6
        /// Cards.
        static let m: CGFloat = 8
        /// Photos.
        static let l: CGFloat = 12
    }

    // MARK: Spacing (4-pt grid)

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        /// Horizontal inset for screen content.
        static let inset: CGFloat = 20
    }

    /// Minimum tappable size.
    static let minTap: CGFloat = 44
}
