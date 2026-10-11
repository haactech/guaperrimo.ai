//
//  LookFailedView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct LookFailedView: View {
    let lookName: String
    let originalImageUrl: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Original photo with dark overlay + warning
            ZStack {
                AsyncImage(url: URL(string: originalImageUrl)) { phase in
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
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.5))
                )

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
            }

            Text(lookName)
                .font(.headline)
                .foregroundStyle(.white)

            Text(String(localized: "looks_failed_message"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                onRetry()
            } label: {
                Text(String(localized: "looks_retry"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.15), in: Capsule())
            }
        }
    }
}
#endif
