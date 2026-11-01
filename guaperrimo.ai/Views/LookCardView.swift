//
//  LookCardView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct LookCardView: View {
    let look: LookItem
    let originalImageUrl: String
    let onCompare: () -> Void
    let onPieces: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch look.status {
            case "generating", "pending":
                LookShimmerView(
                    lookName: look.name,
                    originalImageUrl: originalImageUrl
                )
                .padding(.horizontal, 24)

            case "failed":
                LookFailedView(
                    lookName: look.name,
                    originalImageUrl: originalImageUrl,
                    onRetry: onRetry
                )
                .padding(.horizontal, 24)

            default:
                readyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var readyView: some View {
        VStack(spacing: 16) {
            // Result image
            if let urlStr = look.finalImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    default:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.08))
                            .aspectRatio(3/4, contentMode: .fit)
                            .overlay(ProgressView().tint(.white.opacity(0.5)))
                    }
                }
            }

            // Look info
            Text(look.name)
                .font(.headline)
                .foregroundStyle(.white)

            Text(look.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onCompare()
                } label: {
                    Label(String(localized: "looks_compare"), systemImage: "arrow.left.arrow.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15), in: Capsule())
                }

                if !look.pieces.isEmpty && look.pieces.contains(where: { $0.productName != nil }) {
                    Button {
                        onPieces()
                    } label: {
                        Label(String(localized: "looks_pieces"), systemImage: "tshirt.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}
#endif
