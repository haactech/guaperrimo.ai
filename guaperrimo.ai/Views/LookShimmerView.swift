//
//  LookShimmerView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct LookShimmerView: View {
    let lookName: String
    let originalImageUrl: String

    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        VStack(spacing: 16) {
            // Original photo with shimmer
            AsyncImage(url: URL(string: originalImageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(shimmerOverlay)
                default:
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.08))
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay(shimmerOverlay)
                }
            }

            Text(lookName)
                .font(.headline)
                .foregroundStyle(.white)

            Text(String(localized: "looks_generating"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 2
            }
        }
    }

    private var shimmerOverlay: some View {
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
    }
}
#endif
