//
//  SpeakingPillView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

/// Shown over the photo while the stylist's voice plays: animated bars + a skip button.
struct SpeakingPillView: View {
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            WaveformBars()

            Button(action: onSkip) {
                Text(String(localized: "tts_skip"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "tts_skip"))
        }
        .padding(.horizontal, 16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.button))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.button).stroke(DS.strokeStrong, lineWidth: 1))
    }
}

private struct WaveformBars: View {
    @State private var animating = false
    private let durations: [Double] = [0.45, 0.6, 0.38, 0.52]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(durations.indices, id: \.self) { index in
                Capsule()
                    .fill(DS.textPrimary)
                    .frame(width: 3, height: animating ? 18 : 6)
                    .animation(
                        .easeInOut(duration: durations[index])
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.12),
                        value: animating
                    )
            }
        }
        .frame(height: 20)
        .accessibilityHidden(true)
        .onAppear { animating = true }
    }
}
#endif
