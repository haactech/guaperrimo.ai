//
//  StyleMirrorCanvasView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct StyleMirrorCanvasView: View {
    let currentImage: UIImage?
    let neighborImage: UIImage?
    let crossfadeProgress: CGFloat
    let isLoading: Bool

    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Bottom layer: Neighbor image (incoming) — fixed in place
                if let neighbor = neighborImage {
                    Image(uiImage: neighbor)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(Double(crossfadeProgress))
                } else if isLoading && crossfadeProgress > 0 {
                    shimmerPlaceholder(size: geo.size)
                        .opacity(Double(crossfadeProgress))
                }

                // 2. Top layer: Current image (outgoing) — fixed in place
                if let current = currentImage {
                    Image(uiImage: current)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(1.0 - Double(crossfadeProgress))
                } else {
                    shimmerPlaceholder(size: geo.size)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 2
            }
        }
    }

    private func shimmerPlaceholder(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.08))
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .white.opacity(0),
                            .white.opacity(0.15),
                            .white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: geo.size.width * shimmerPhase)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            )
    }
}
#endif
