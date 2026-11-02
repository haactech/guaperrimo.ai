//
//  TexturedBackground.swift
//  guaperrimo.ai
//

import SwiftUI

/// The app's background: obsidiana with a very faint linen weave in hueso.
/// Static on purpose: a texture, not an effect.
struct TexturedBackground: View {
    var body: some View {
        ZStack {
            DS.bg
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                let weave: CGFloat = 3
                var warp = Path()
                var x: CGFloat = 0.5
                while x < size.width {
                    warp.move(to: CGPoint(x: x, y: 0))
                    warp.addLine(to: CGPoint(x: x, y: size.height))
                    x += weave
                }
                context.stroke(warp, with: .color(DS.textPrimary.opacity(0.022)), lineWidth: 1)

                var weft = Path()
                var y: CGFloat = 0.5
                while y < size.height {
                    weft.move(to: CGPoint(x: 0, y: y))
                    weft.addLine(to: CGPoint(x: size.width, y: y))
                    y += weave
                }
                context.stroke(weft, with: .color(DS.textPrimary.opacity(0.014)), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
