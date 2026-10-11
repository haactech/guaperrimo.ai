//
//  TryOnErrorView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct TryOnErrorView: View {
    let action: PriorityAction
    let errorMessage: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text(String(localized: "tryon_error_title"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text(errorMessage)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(action.title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                VStack(spacing: 12) {
                    // Retry (primary)
                    Button {
                        onRetry()
                    } label: {
                        Text(String(localized: "tryon_retry"))
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white, in: Capsule())
                    }

                    // Back (secondary)
                    Button {
                        onDismiss()
                    } label: {
                        Text(String(localized: "tryon_back"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}
#endif
