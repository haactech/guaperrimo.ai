//
//  Shimmer.swift
//  guaperrimo.ai
//

import SwiftUI

/// Single shimmer implementation: a soft highlight sweeping across a placeholder.
/// Apply to a filled placeholder shape; clip the result with the shape you need.
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.15), .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: geo.size.width * phase)
                }
                .clipped()
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

/// A shimmering rounded placeholder.
struct ShimmerPlaceholder: View {
    var cornerRadius: CGFloat = DS.Radius.l

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DS.surfaceRaised)
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
