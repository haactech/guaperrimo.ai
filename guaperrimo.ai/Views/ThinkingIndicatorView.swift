//
//  ThinkingIndicatorView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

/// Three pulsing dots with a short status line underneath, centered in its container.
/// Pass a different `message` per phase ("Mirando tu outfit…", "Pensando…").
struct ThinkingIndicatorView: View {
    var message: String = String(localized: "thinking")

    @State private var dotScale: [CGFloat] = [0.5, 0.5, 0.5]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(DS.textSecondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotScale[index])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.m).stroke(DS.stroke, lineWidth: 1))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(DS.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.2)
            ) {
                dotScale[i] = 1.0
            }
        }
    }
}
#endif
