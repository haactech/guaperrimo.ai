//
//  VoiceConfirmView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

/// Shows what the stylist heard and sends it by itself after a short countdown.
/// Tapping the ring cancels the countdown; the transcript then waits for an explicit "Enviar".
struct VoiceConfirmView: View {
    let transcript: String
    var countdown: Duration = .seconds(2)
    let onSend: () -> Void
    let onRepeat: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var isCounting = true

    var body: some View {
        VStack(spacing: 20) {
            Text(transcript)
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
                .padding(.horizontal, 24)

            if isCounting {
                Button {
                    isCounting = false
                    withAnimation(.easeOut(duration: 0.15)) { ringProgress = 0 }
                } label: {
                    ZStack {
                        Circle().stroke(DS.stroke, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: ringProgress)
                            .stroke(DS.success, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "pause.fill")
                            .font(.caption)
                            .foregroundStyle(DS.textSecondary)
                    }
                    .frame(width: 36, height: 36)
                    .frame(minWidth: DS.minTap, minHeight: DS.minTap)
                    .contentShape(Circle())
                }
                .accessibilityLabel(String(localized: "voice_cancel_auto"))
                .transition(.opacity)
            }

            HStack(spacing: 16) {
                SecondaryButton(title: String(localized: "voice_retry"), systemImage: "arrow.counterclockwise") {
                    onRepeat()
                }

                PrimaryButton(
                    title: String(localized: isCounting ? "voice_send_now" : "voice_send"),
                    systemImage: "paperplane.fill",
                    style: .light
                ) {
                    isCounting = false
                    onSend()
                }
            }
        }
        .task {
            withAnimation(.linear(duration: Double(countdown.components.seconds))) { ringProgress = 1 }
            try? await Task.sleep(for: countdown)
            guard !Task.isCancelled, isCounting else { return }
            isCounting = false
            onSend()
        }
    }
}
#endif
