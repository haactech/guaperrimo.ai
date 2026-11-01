//
//  Tokens.swift
//  guaperrimo.ai
//
//  Design tokens: the single source of truth for colors, radii and spacing.
//

import SwiftUI

extension Color {
    /// Creates a color from a hex string such as "#7C5CFF" or "7C5CFF".
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
    // MARK: Colors
    static let bg = Color(hex: "#0B0B0F")
    static let surface = Color.white.opacity(0.06)
    static let surfaceRaised = Color.white.opacity(0.10)
    static let stroke = Color.white.opacity(0.12)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textTertiary = Color.white.opacity(0.50)

    static let accentStart = Color(hex: "#7C5CFF")
    static let accentEnd = Color(hex: "#3D8BFF")
    static let accent = LinearGradient(
        colors: [accentStart, accentEnd],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let success = Color(hex: "#4ADE80")
    static let warning = Color(hex: "#F59E0B")
    static let danger = Color(hex: "#F87171")

    // MARK: Radii
    enum Radius {
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
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
