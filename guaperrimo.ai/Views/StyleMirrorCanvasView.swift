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
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l))
        .padding(.horizontal, DS.Space.m)
    }

    private func shimmerPlaceholder(size: CGSize) -> some View {
        ShimmerPlaceholder(cornerRadius: DS.Radius.l)
    }
}
#endif
