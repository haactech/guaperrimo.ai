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
                            .fill(index < readyCount ? DS.success : DS.textTertiary)
                            .frame(width: 8, height: 8)
                    }
                }

                // Status text
                if let timeout = timeoutMessage {
                    Text(timeout)
                        .font(.caption)
                        .foregroundStyle(DS.warning)
                        .multilineTextAlignment(.center)
                } else if lookState == .teaser {
                    Text(String(localized: "looks_preparing"))
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                } else if lookState == .ready {
                    Text(String(localized: "looks_first_ready"))
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                }

                // Tap target
                if lookState == .ready {
                    PrimaryButton(
                        title: String(localized: "looks_carousel_title"),
                        systemImage: "sparkles",
                        action: onTap
                    )
                    .padding(.horizontal, DS.Space.xl)
                } else {
                    // Pulsing indicator while generating
                    ProgressView()
                        .tint(DS.textTertiary)
                        .scaleEffect(0.8)
                }
            }
            .padding(.top, 16)
            .animation(.easeInOut, value: lookState)
        )
    }
}
#endif
