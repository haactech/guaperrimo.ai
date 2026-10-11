//
//  LookIndicatorView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct LookIndicatorView: View {
    let lookState: LookCarouselState
    let readyCount: Int
    let totalCount: Int
    let timeoutMessage: String?
    let onTap: () -> Void

    var body: some View {
        if lookState == .hidden { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 12) {
                // Dots indicator
                HStack(spacing: 6) {
                    ForEach(0..<max(totalCount, 3), id: \.self) { index in
                        Circle()
                            .fill(index < readyCount ? Color.green : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                // Status text
                if let timeout = timeoutMessage {
                    Text(timeout)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                } else if lookState == .teaser {
                    Text(String(localized: "looks_preparing"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                } else if lookState == .ready {
                    Text(String(localized: "looks_first_ready"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                // Tap target
                if lookState == .ready {
                    Button {
                        onTap()
                    } label: {
                        Label(String(localized: "looks_carousel_title"), systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                    }
                } else {
                    // Pulsing indicator while generating
                    ProgressView()
                        .tint(.white.opacity(0.5))
                        .scaleEffect(0.8)
                }
            }
            .padding(.top, 16)
            .animation(.easeInOut, value: lookState)
        )
    }
}
#endif
